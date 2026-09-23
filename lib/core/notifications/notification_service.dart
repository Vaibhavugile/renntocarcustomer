import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// ================================================================
/// FIREBASE BACKGROUND MESSAGE HANDLER
/// ================================================================
///
/// IMPORTANT:
/// This must remain a TOP-LEVEL function.
///
/// Do not move this inside NotificationService or another class.
///
/// Firebase can execute this while the application is in the
/// background/terminated state.
///
/// At this stage we do not perform navigation here.
/// We only log/prepare the message.
///
/// Navigation is handled when the user taps the notification.
/// ================================================================

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  try {
    debugPrintNotification(
      '========================================',
    );

    debugPrintNotification(
      'FCM BACKGROUND MESSAGE RECEIVED',
    );

    debugPrintNotification(
      'Message ID: ${message.messageId}',
    );

    debugPrintNotification(
      'Title: ${message.notification?.title}',
    );

    debugPrintNotification(
      'Body: ${message.notification?.body}',
    );

    debugPrintNotification(
      'Data: ${message.data}',
    );

    debugPrintNotification(
      '========================================',
    );
  } catch (error) {
    debugPrintNotification(
      'FCM background handler error: $error',
    );
  }
}

/// Small top-level logger.
///
/// Kept outside NotificationService so the background isolate can
/// safely use it.
void debugPrintNotification(String message) {
  print('[NotificationService] $message');
}

/// ================================================================
/// NOTIFICATION TAP DATA
/// ================================================================

class NotificationTapData {
  final String? type;
  final String? tenantId;
  final String? bookingId;
  final String? status;
  final String? paymentStatus;
  final String? customerId;
  final String? title;
  final String? body;

  final Map<String, dynamic> data;

  const NotificationTapData({
    this.type,
    this.tenantId,
    this.bookingId,
    this.status,
    this.paymentStatus,
    this.customerId,
    this.title,
    this.body,
    this.data = const {},
  });

  factory NotificationTapData.fromRemoteMessage(
    RemoteMessage message,
  ) {
    final rawData = <String, dynamic>{};

    message.data.forEach(
      (key, value) {
        rawData[key] = value;
      },
    );

    String? cleanValue(dynamic value) {
      if (value == null) {
        return null;
      }

      final text = value.toString().trim();

      if (text.isEmpty) {
        return null;
      }

      return text;
    }

    return NotificationTapData(
      type: cleanValue(
        rawData['type'],
      ),
      tenantId: cleanValue(
        rawData['tenantId'],
      ),
      bookingId: cleanValue(
        rawData['bookingId'],
      ),
      status: cleanValue(
        rawData['status'],
      ),
      paymentStatus: cleanValue(
        rawData['paymentStatus'],
      ),
      customerId: cleanValue(
        rawData['customerId'],
      ),
      title: message.notification?.title ??
          cleanValue(
            rawData['title'],
          ),
      body: message.notification?.body ??
          cleanValue(
            rawData['body'],
          ),
      data: rawData,
    );
  }

  @override
  String toString() {
    return 'NotificationTapData('
        'type: $type, '
        'tenantId: $tenantId, '
        'bookingId: $bookingId, '
        'status: $status, '
        'paymentStatus: $paymentStatus, '
        'customerId: $customerId, '
        'title: $title, '
        'body: $body'
        ')';
  }
}

/// ================================================================
/// NOTIFICATION SERVICE
/// ================================================================

class NotificationService {
  NotificationService._();

  static final NotificationService instance =
      NotificationService._();

  final FirebaseMessaging _messaging =
      FirebaseMessaging.instance;

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  final DeviceInfoPlugin _deviceInfo =
      DeviceInfoPlugin();

  String? _deviceId;

  String? _currentTenantId;

  String? _currentUserId;

  bool _isAdmin = false;

  bool _initialized = false;

  /// Prevents two initialize() calls from running simultaneously.
  Future<void>? _initializationFuture;

  /// FCM token refresh listener.
  StreamSubscription<String>? _tokenRefreshSubscription;

  /// Foreground message listener.
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;

  /// Notification opened/tapped listener.
  StreamSubscription<RemoteMessage>? _notificationOpenedSubscription;

  /// Callback fired when a notification is received while the app
  /// is in the foreground.
  ///
  /// Example:
  ///
  /// NotificationService.instance.onForegroundMessage = (message) {
  ///   ...
  /// };
  ///
  void Function(RemoteMessage message)?
      onForegroundMessage;

  /// Callback fired when the user taps a notification.
  ///
  /// This will be used later by the application/router to navigate
  /// to:
  ///
  /// - booking details
  /// - payment
  /// - pickup pending
  /// - return pending
  /// - etc.
  void Function(NotificationTapData data)?
      onNotificationTap;

  // ==============================================================
  // INITIALIZE
  // ==============================================================

  Future<void> initialize({
    required String tenantId,
    required bool isAdmin,
  }) async {
    if (_initializationFuture != null) {
      await _initializationFuture;
      return;
    }

    _initializationFuture = _initializeInternal(
      tenantId: tenantId,
      isAdmin: isAdmin,
    );

    try {
      await _initializationFuture;
    } finally {
      _initializationFuture = null;
    }
  }

  Future<void> _initializeInternal({
    required String tenantId,
    required bool isAdmin,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception(
        'Cannot initialize notifications without an authenticated user.',
      );
    }

    final cleanTenantId = tenantId.trim();

    if (cleanTenantId.isEmpty) {
      throw Exception(
        'Tenant ID is required for notifications.',
      );
    }

    // ------------------------------------------------------------
    // If already initialized for the same session, just update
    // last seen and return.
    // ------------------------------------------------------------

    if (_initialized &&
        _currentTenantId == cleanTenantId &&
        _currentUserId == user.uid &&
        _isAdmin == isAdmin) {
      try {
        await updateLastSeen();
      } catch (error) {
        print(
          'Unable to update notification last seen: $error',
        );
      }

      return;
    }

    _currentTenantId = cleanTenantId;

    _currentUserId = user.uid;

    _isAdmin = isAdmin;

    // ------------------------------------------------------------
    // Request notification permission.
    //
    // Permission failure should not destroy the login session.
    // The caller already catches initialize() failures.
    // ------------------------------------------------------------

    await requestPermission();

    // ------------------------------------------------------------
    // Get device ID.
    // ------------------------------------------------------------

    final deviceId = await getDeviceId();

    if (deviceId.trim().isEmpty) {
      throw Exception(
        'Unable to identify this device.',
      );
    }

    // ------------------------------------------------------------
    // Get FCM token.
    // ------------------------------------------------------------

    final token = await _messaging.getToken();

    if (token == null ||
        token.trim().isEmpty) {
      throw Exception(
        'Unable to obtain Firebase notification token.',
      );
    }

    // ------------------------------------------------------------
    // Save device.
    // ------------------------------------------------------------

    await saveDevice(
      tenantId: cleanTenantId,
      userId: user.uid,
      isAdmin: isAdmin,
      deviceId: deviceId,
      fcmToken: token,
    );

    // ------------------------------------------------------------
    // Register message listeners.
    // ------------------------------------------------------------

    await _registerMessageListeners();

    // ------------------------------------------------------------
    // Token refresh listener.
    // ------------------------------------------------------------

    await _registerTokenRefreshListener();

    // ------------------------------------------------------------
    // Handle notification that opened the app from a terminated
    // state.
    // ------------------------------------------------------------

    await _handleInitialMessage();

    _initialized = true;

    print(
      'NotificationService initialized successfully.',
    );

    print(
      'Tenant: $cleanTenantId',
    );

    print(
      'User: ${user.uid}',
    );

    print(
      'Role: ${isAdmin ? 'admin' : 'customer'}',
    );
  }

  // ==============================================================
  // MESSAGE LISTENERS
  // ==============================================================

  Future<void> _registerMessageListeners() async {
    // ------------------------------------------------------------
    // Cancel old listeners first.
    //
    // This prevents duplicate callbacks if initialize() is called
    // again during the same application session.
    // ------------------------------------------------------------

    await _foregroundMessageSubscription?.cancel();

    await _notificationOpenedSubscription?.cancel();

    // ------------------------------------------------------------
    // FOREGROUND
    // ------------------------------------------------------------

    _foregroundMessageSubscription =
        FirebaseMessaging.onMessage.listen(
      (RemoteMessage message) {
        try {
          print(
            '========================================',
          );

          print(
            'FCM FOREGROUND MESSAGE RECEIVED',
          );

          print(
            'Message ID: ${message.messageId}',
          );

          print(
            'Title: ${message.notification?.title}',
          );

          print(
            'Body: ${message.notification?.body}',
          );

          print(
            'Data: ${message.data}',
          );

          print(
            '========================================',
          );

          final callback =
              onForegroundMessage;

          if (callback != null) {
            callback(message);
          }
        } catch (error) {
          print(
            'Foreground notification callback failed: $error',
          );
        }
      },
    );

    // ------------------------------------------------------------
    // BACKGROUND → USER TAPS NOTIFICATION
    // ------------------------------------------------------------

    _notificationOpenedSubscription =
        FirebaseMessaging.onMessageOpenedApp.listen(
      (RemoteMessage message) {
        try {
          _handleNotificationTap(
            message,
          );
        } catch (error) {
          print(
            'Notification tap handling failed: $error',
          );
        }
      },
    );
  }

  // ==============================================================
  // TOKEN REFRESH LISTENER
  // ==============================================================

  Future<void> _registerTokenRefreshListener() async {
    await _tokenRefreshSubscription?.cancel();

    _tokenRefreshSubscription =
        _messaging.onTokenRefresh.listen(
      (String newToken) async {
        try {
          final activeUser =
              _auth.currentUser;

          final activeTenant =
              _currentTenantId;

          final activeDevice =
              _deviceId;

          if (activeUser == null ||
              activeTenant == null ||
              activeDevice == null) {
            return;
          }

          final cleanToken =
              newToken.trim();

          if (cleanToken.isEmpty) {
            return;
          }

          await saveDevice(
            tenantId: activeTenant,
            userId: activeUser.uid,
            isAdmin: _isAdmin,
            deviceId: activeDevice,
            fcmToken: cleanToken,
          );

          print(
            'FCM token refreshed and saved.',
          );
        } catch (error) {
          // Token refresh must NEVER break the user's session.
          print(
            'FCM token refresh save failed: $error',
          );
        }
      },
    );
  }

  // ==============================================================
  // TERMINATED APP MESSAGE
  // ==============================================================

  Future<void> _handleInitialMessage() async {
    try {
      final RemoteMessage? message =
          await _messaging.getInitialMessage();

      if (message == null) {
        return;
      }

      print(
        '========================================',
      );

      print(
        'FCM INITIAL MESSAGE FOUND',
      );

      print(
        'Message ID: ${message.messageId}',
      );

      print(
        'Title: ${message.notification?.title}',
      );

      print(
        'Body: ${message.notification?.body}',
      );

      print(
        'Data: ${message.data}',
      );

      print(
        '========================================',
      );

      _handleNotificationTap(
        message,
      );
    } catch (error) {
      print(
        'Unable to handle initial FCM message: $error',
      );
    }
  }

  // ==============================================================
  // NOTIFICATION TAP
  // ==============================================================

  void _handleNotificationTap(
    RemoteMessage message,
  ) {
    final notificationData =
        NotificationTapData.fromRemoteMessage(
      message,
    );

    print(
      '========================================',
    );

    print(
      'FCM NOTIFICATION TAPPED',
    );

    print(
      'Type: ${notificationData.type}',
    );

    print(
      'Tenant: ${notificationData.tenantId}',
    );

    print(
      'Booking: ${notificationData.bookingId}',
    );

    print(
      'Status: ${notificationData.status}',
    );

    print(
      'Payment Status: '
      '${notificationData.paymentStatus}',
    );

    print(
      'Data: ${notificationData.data}',
    );

    print(
      '========================================',
    );

    // ------------------------------------------------------------
    // Security check:
    //
    // If the notification contains a tenant ID and it does not
    // match the currently logged-in tenant, do not route it.
    // ------------------------------------------------------------

    final notificationTenant =
        notificationData.tenantId?.trim();

    final currentTenant =
        _currentTenantId?.trim();

    if (notificationTenant != null &&
        notificationTenant.isNotEmpty &&
        currentTenant != null &&
        currentTenant.isNotEmpty &&
        notificationTenant != currentTenant) {
      print(
        'Notification ignored due to tenant mismatch.',
      );

      return;
    }

    // ------------------------------------------------------------
    // Send to application/router.
    // ------------------------------------------------------------

    final callback =
        onNotificationTap;

    if (callback != null) {
      callback(notificationData);
    } else {
      print(
        'No notification tap callback registered.',
      );
    }
  }

  // ==============================================================
  // REQUEST PERMISSION
  // ==============================================================

  Future<NotificationSettings>
      requestPermission() async {
    final settings =
        await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
    );

    print(
      'FCM authorization status: '
      '${settings.authorizationStatus}',
    );

    return settings;
  }

  // ==============================================================
  // DEVICE ID
  // ==============================================================

  Future<String> getDeviceId() async {
    if (_deviceId != null &&
        _deviceId!.trim().isNotEmpty) {
      return _deviceId!;
    }

    try {
      // ----------------------------------------------------------
      // ANDROID
      // ----------------------------------------------------------

      if (Platform.isAndroid) {
        final androidInfo =
            await _deviceInfo.androidInfo;

        final id =
            androidInfo.id.trim();

        if (id.isNotEmpty) {
          _deviceId = id;

          return id;
        }
      }

      // ----------------------------------------------------------
      // IOS
      // ----------------------------------------------------------

      if (Platform.isIOS) {
        final iosInfo =
            await _deviceInfo.iosInfo;

        final id =
            (iosInfo.identifierForVendor ?? '')
                .trim();

        if (id.isNotEmpty) {
          _deviceId = id;

          return id;
        }
      }
    } catch (error) {
      print(
        'Unable to get device ID: $error',
      );
    }

    // ------------------------------------------------------------
    // FALLBACK
    //
    // This should rarely be required.
    // ------------------------------------------------------------

    final fallbackToken =
        await _messaging.getToken();

    if (fallbackToken != null &&
        fallbackToken.trim().isNotEmpty) {
      _deviceId =
          fallbackToken.trim();

      return _deviceId!;
    }

    throw Exception(
      'Unable to generate a device identifier.',
    );
  }

  // ==============================================================
  // SAVE DEVICE
  // ==============================================================

  Future<void> saveDevice({
    required String tenantId,
    required String userId,
    required bool isAdmin,
    required String deviceId,
    required String fcmToken,
  }) async {
    final cleanTenantId =
        tenantId.trim();

    final cleanUserId =
        userId.trim();

    final cleanDeviceId =
        deviceId.trim();

    final cleanToken =
        fcmToken.trim();

    // ------------------------------------------------------------
    // Validate
    // ------------------------------------------------------------

    if (cleanTenantId.isEmpty ||
        cleanUserId.isEmpty ||
        cleanDeviceId.isEmpty ||
        cleanToken.isEmpty) {
      throw Exception(
        'Invalid notification device information.',
      );
    }

    // ------------------------------------------------------------
    // Role
    // ------------------------------------------------------------

    final String role =
        isAdmin ? 'admin' : 'customer';

    // ------------------------------------------------------------
    // Parent collection
    // ------------------------------------------------------------

    final String userCollection =
        isAdmin
            ? 'admins'
            : 'customers';

    // ------------------------------------------------------------
    // User reference
    //
    // tenants/{tenantId}/admins/{uid}
    //
    // OR
    //
    // tenants/{tenantId}/customers/{uid}
    // ------------------------------------------------------------

    final userRef = _firestore
        .collection('tenants')
        .doc(cleanTenantId)
        .collection(userCollection)
        .doc(cleanUserId);

    // ------------------------------------------------------------
    // Device reference
    //
    // tenants/{tenantId}/{admins|customers}/{uid}
    //     /notificationDevices/{deviceId}
    // ------------------------------------------------------------

    final deviceRef = userRef
        .collection('notificationDevices')
        .doc(cleanDeviceId);

    // ------------------------------------------------------------
    // Existing device check
    // ------------------------------------------------------------

    final existingDevice =
        await deviceRef.get();

    // ------------------------------------------------------------
    // Device data
    // ------------------------------------------------------------

    final Map<String, dynamic> deviceData = {
      'deviceId': cleanDeviceId,
      'fcmToken': cleanToken,
      'firebaseUid': cleanUserId,
      'tenantId': cleanTenantId,
      'role': role,
      'isAdmin': isAdmin,
      'isActive': true,
      'platform': _platformName(),

      'updatedAt':
          FieldValue.serverTimestamp(),

      'lastSeenAt':
          FieldValue.serverTimestamp(),
    };

    // ------------------------------------------------------------
    // Only set createdAt once.
    // ------------------------------------------------------------

    if (!existingDevice.exists) {
      deviceData['createdAt'] =
          FieldValue.serverTimestamp();
    }

    // ------------------------------------------------------------
    // Save
    // ------------------------------------------------------------

    await deviceRef.set(
      deviceData,
      SetOptions(
        merge: true,
      ),
    );

    // ------------------------------------------------------------
    // Update local session
    // ------------------------------------------------------------

    _deviceId =
        cleanDeviceId;

    _currentTenantId =
        cleanTenantId;

    _currentUserId =
        cleanUserId;

    _isAdmin =
        isAdmin;

    // ------------------------------------------------------------
    // Debug
    // ------------------------------------------------------------

    print(
      '========================================',
    );

    print(
      'FCM DEVICE REGISTERED',
    );

    print(
      'Tenant: $cleanTenantId',
    );

    print(
      'UID: $cleanUserId',
    );

    print(
      'Role: $role',
    );

    print(
      'Device ID: $cleanDeviceId',
    );

    print(
      'Platform: ${_platformName()}',
    );

    print(
      'Existing Device: '
      '${existingDevice.exists}',
    );

    print(
      'FCM Token: $cleanToken',
    );

    print(
      '========================================',
    );
  }

  // ==============================================================
  // UPDATE LAST SEEN
  // ==============================================================

  Future<void> updateLastSeen() async {
    final tenantId =
        _currentTenantId;

    final userId =
        _currentUserId;

    final deviceId =
        _deviceId;

    if (tenantId == null ||
        userId == null ||
        deviceId == null) {
      return;
    }

    final collection =
        _isAdmin
            ? 'admins'
            : 'customers';

    try {
      await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection(collection)
          .doc(userId)
          .collection('notificationDevices')
          .doc(deviceId)
          .set(
        {
          'lastSeenAt':
              FieldValue.serverTimestamp(),

          'updatedAt':
              FieldValue.serverTimestamp(),

          'isActive': true,
        },
        SetOptions(
          merge: true,
        ),
      );
    } catch (error) {
      print(
        'Unable to update notification last seen: '
        '$error',
      );
    }
  }

  // ==============================================================
  // DEACTIVATE CURRENT DEVICE
  // ==============================================================

  Future<void> deactivateCurrentDevice() async {
    final tenantId =
        _currentTenantId;

    final userId =
        _currentUserId;

    final deviceId =
        _deviceId;

    if (tenantId == null ||
        userId == null ||
        deviceId == null) {
      return;
    }

    try {
      final collection =
          _isAdmin
              ? 'admins'
              : 'customers';

      await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection(collection)
          .doc(userId)
          .collection('notificationDevices')
          .doc(deviceId)
          .set(
        {
          'isActive': false,

          'updatedAt':
              FieldValue.serverTimestamp(),

          'loggedOutAt':
              FieldValue.serverTimestamp(),
        },
        SetOptions(
          merge: true,
        ),
      );
    } catch (error) {
      print(
        'Unable to deactivate notification device: '
        '$error',
      );
    }
  }

  // ==============================================================
  // LOGOUT CLEANUP
  // ==============================================================

  Future<void> clearSession() async {
    // ------------------------------------------------------------
    // Cancel FCM subscriptions.
    // ------------------------------------------------------------

    try {
      await _tokenRefreshSubscription?.cancel();
    } catch (error) {
      print(
        'Token refresh listener cleanup failed: $error',
      );
    }

    try {
      await _foregroundMessageSubscription?.cancel();
    } catch (error) {
      print(
        'Foreground notification listener cleanup failed: '
        '$error',
      );
    }

    try {
      await _notificationOpenedSubscription?.cancel();
    } catch (error) {
      print(
        'Notification opened listener cleanup failed: '
        '$error',
      );
    }

    _tokenRefreshSubscription =
        null;

    _foregroundMessageSubscription =
        null;

    _notificationOpenedSubscription =
        null;

    // ------------------------------------------------------------
    // Clear session data.
    // ------------------------------------------------------------

    _deviceId = null;

    _currentTenantId = null;

    _currentUserId = null;

    _isAdmin = false;

    _initialized = false;

    print(
      'NotificationService session cleared.',
    );
  }

  // ==============================================================
  // PLATFORM
  // ==============================================================

  String _platformName() {
    if (Platform.isAndroid) {
      return 'android';
    }

    if (Platform.isIOS) {
      return 'ios';
    }

    return 'unknown';
  }

  // ==============================================================
  // GETTERS
  // ==============================================================

  String? get currentDeviceId =>
      _deviceId;

  String? get currentTenantId =>
      _currentTenantId;

  String? get currentUserId =>
      _currentUserId;

  bool get isAdmin =>
      _isAdmin;

  bool get isInitialized =>
      _initialized;
}