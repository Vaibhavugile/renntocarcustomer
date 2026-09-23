import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';


// ================================================================
// GLOBAL FCM BACKGROUND HANDLER
// ================================================================
//
// IMPORTANT:
// This MUST remain a top-level function.
//
// Firebase Messaging can execute this while the application is
// running in a background isolate.
//
// For messages containing a notification payload, Android/iOS can
// display the notification automatically.
//
// This handler is mainly required for data/background processing.
// ================================================================

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  try {
    print(
      '[FCM BACKGROUND] Message ID: '
      '${message.messageId}',
    );

    print(
      '[FCM BACKGROUND] Title: '
      '${message.notification?.title}',
    );

    print(
      '[FCM BACKGROUND] Body: '
      '${message.notification?.body}',
    );

    print(
      '[FCM BACKGROUND] Data: '
      '${message.data}',
    );
  } catch (error) {
    print(
      '[FCM BACKGROUND] Handler error: $error',
    );
  }
}


// ================================================================
// NOTIFICATION TAP DATA
// ================================================================

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
    final rawData =
        <String, dynamic>{};

    message.data.forEach(
      (key, value) {
        rawData[key] = value;
      },
    );

    String? cleanValue(
      dynamic value,
    ) {
      if (value == null) {
        return null;
      }

      final text =
          value.toString().trim();

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
      title:
          message.notification?.title ??
              cleanValue(
                rawData['title'],
              ),
      body:
          message.notification?.body ??
              cleanValue(
                rawData['body'],
              ),
      data: rawData,
    );
  }

  factory NotificationTapData.fromPayload(
    String payload,
  ) {
    try {
      final decoded =
          jsonDecode(payload);

      if (decoded is Map) {
        String? value(
          dynamic item,
        ) {
          if (item == null) {
            return null;
          }

          final text =
              item.toString().trim();

          return text.isEmpty
              ? null
              : text;
        }

        final map =
            Map<String, dynamic>.from(
          decoded,
        );

        return NotificationTapData(
          type: value(
            map['type'],
          ),
          tenantId: value(
            map['tenantId'],
          ),
          bookingId: value(
            map['bookingId'],
          ),
          status: value(
            map['status'],
          ),
          paymentStatus: value(
            map['paymentStatus'],
          ),
          customerId: value(
            map['customerId'],
          ),
          title: value(
            map['title'],
          ),
          body: value(
            map['body'],
          ),
          data: map,
        );
      }
    } catch (error) {
      print(
        'Unable to decode notification payload: '
        '$error',
      );
    }

    return const NotificationTapData();
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


// ================================================================
// NOTIFICATION SERVICE
// ================================================================

class NotificationService {
  NotificationService._();

  static final NotificationService instance =
      NotificationService._();


  // ==============================================================
  // FIREBASE
  // ==============================================================

  final FirebaseMessaging _messaging =
      FirebaseMessaging.instance;

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;


  // ==============================================================
  // DEVICE
  // ==============================================================

  final DeviceInfoPlugin _deviceInfo =
      DeviceInfoPlugin();

  String? _deviceId;

  String? _currentTenantId;

  String? _currentUserId;

  bool _isAdmin = false;

  bool _initialized = false;


  // ==============================================================
  // INITIALIZATION LOCK
  // ==============================================================

  Future<void>? _initializationFuture;


  // ==============================================================
  // STREAM SUBSCRIPTIONS
  // ==============================================================

  StreamSubscription<String>?
      _tokenRefreshSubscription;

  StreamSubscription<RemoteMessage>?
      _foregroundMessageSubscription;

  StreamSubscription<RemoteMessage>?
      _notificationOpenedSubscription;


  // ==============================================================
  // LOCAL NOTIFICATIONS
  // ==============================================================

  final FlutterLocalNotificationsPlugin
      _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _localNotificationsInitialized =
      false;


  // ==============================================================
  // ANDROID CHANNEL
  // ==============================================================

  static const AndroidNotificationChannel
      _bookingChannel =
      AndroidNotificationChannel(
    'booking_notifications',
    'Booking Notifications',
    description:
        'Notifications for new bookings and booking updates.',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );


  // ==============================================================
  // CALLBACKS
  // ==============================================================

  /// Called when an FCM notification arrives while the app is
  /// in the foreground.
  void Function(RemoteMessage message)?
      onForegroundMessage;


  /// Called when the user taps a notification.
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

    _initializationFuture =
        _initializeInternal(
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
    final user =
        _auth.currentUser;

    if (user == null) {
      throw Exception(
        'Cannot initialize notifications without an authenticated user.',
      );
    }

    final cleanTenantId =
        tenantId.trim();

    if (cleanTenantId.isEmpty) {
      throw Exception(
        'Tenant ID is required for notifications.',
      );
    }


    // ------------------------------------------------------------
    // Already initialized
    // ------------------------------------------------------------

    if (_initialized &&
        _currentTenantId ==
            cleanTenantId &&
        _currentUserId ==
            user.uid &&
        _isAdmin ==
            isAdmin) {
      try {
        await updateLastSeen();
      } catch (error) {
        print(
          'Notification last seen update failed: '
          '$error',
        );
      }

      return;
    }


    _currentTenantId =
        cleanTenantId;

    _currentUserId =
        user.uid;

    _isAdmin =
        isAdmin;


    // ------------------------------------------------------------
    // Local notification system
    // ------------------------------------------------------------

    await _initializeLocalNotifications();


    // ------------------------------------------------------------
    // Firebase permission
    // ------------------------------------------------------------

    await requestPermission();


    // ------------------------------------------------------------
    // Get device ID
    // ------------------------------------------------------------

    final deviceId =
        await getDeviceId();

    if (deviceId.trim().isEmpty) {
      throw Exception(
        'Unable to identify this device.',
      );
    }


    // ------------------------------------------------------------
    // Get FCM token
    // ------------------------------------------------------------

    final token =
        await _messaging.getToken();

    if (token == null ||
        token.trim().isEmpty) {
      throw Exception(
        'Unable to obtain Firebase notification token.',
      );
    }


    // ------------------------------------------------------------
    // Save device
    // ------------------------------------------------------------

    await saveDevice(
      tenantId: cleanTenantId,
      userId: user.uid,
      isAdmin: isAdmin,
      deviceId: deviceId,
      fcmToken: token,
    );


    // ------------------------------------------------------------
    // Register FCM listeners
    // ------------------------------------------------------------

    await _registerMessageListeners();


    // ------------------------------------------------------------
    // Register token refresh
    // ------------------------------------------------------------

    await _registerTokenRefreshListener();


    // ------------------------------------------------------------
    // Handle terminated-app notification
    // ------------------------------------------------------------

    await _handleInitialMessage();


    _initialized = true;


    print(
      '========================================',
    );

    print(
      'NotificationService initialized',
    );

    print(
      'Tenant: $cleanTenantId',
    );

    print(
      'UID: ${user.uid}',
    );

    print(
      'Role: '
      '${isAdmin ? 'admin' : 'customer'}',
    );

    print(
      '========================================',
    );
  }


  // ==============================================================
  // LOCAL NOTIFICATIONS INITIALIZATION
  // ==============================================================

  Future<void>
      _initializeLocalNotifications() async {
    if (_localNotificationsInitialized) {
      return;
    }


    // ------------------------------------------------------------
    // Android initialization
    // ------------------------------------------------------------

    const androidSettings =
        AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );


    // ------------------------------------------------------------
    // iOS initialization
    // ------------------------------------------------------------

    final darwinSettings =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );


    // ------------------------------------------------------------
    // Combined settings
    // ------------------------------------------------------------

    final settings =
        InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );


    // ------------------------------------------------------------
    // Initialize plugin
    // ------------------------------------------------------------

    await _localNotifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse:
          _onLocalNotificationTap,
    );


    // ------------------------------------------------------------
    // Android channel
    // ------------------------------------------------------------

    final androidPlugin =
        _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin
          .createNotificationChannel(
        _bookingChannel,
      );

      await androidPlugin
          .requestNotificationsPermission();
    }


    // ------------------------------------------------------------
    // iOS foreground presentation
    // ------------------------------------------------------------

    await _messaging
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );


    _localNotificationsInitialized =
        true;


    print(
      'Local notification system initialized.',
    );
  }


  // ==============================================================
  // LOCAL NOTIFICATION TAP
  // ==============================================================

  void _onLocalNotificationTap(
    NotificationResponse response,
  ) {
    try {
      final payload =
          response.payload;

      if (payload == null ||
          payload.trim().isEmpty) {
        return;
      }

      final data =
          NotificationTapData
              .fromPayload(
        payload,
      );

      _handleNotificationTapData(
        data,
      );
    } catch (error) {
      print(
        'Local notification tap failed: '
        '$error',
      );
    }
  }


  // ==============================================================
  // SHOW FOREGROUND NOTIFICATION
  // ==============================================================

  Future<void> _showForegroundNotification(
    RemoteMessage message,
  ) async {
    if (!_localNotificationsInitialized) {
      await _initializeLocalNotifications();
    }


    final notification =
        message.notification;


    final title =
        notification?.title ??
            _stringValue(
              message.data['title'],
            ) ??
            'Rentocar';


    final body =
        notification?.body ??
            _stringValue(
              message.data['body'],
            ) ??
            'You have a new notification.';


    final notificationData =
        <String, dynamic>{
      ...message.data,
      'title': title,
      'body': body,
    };


    final payload =
        jsonEncode(
      notificationData,
    );


    // ------------------------------------------------------------
    // Generate a unique notification ID
    // ------------------------------------------------------------

    final notificationId =
        DateTime.now()
            .millisecondsSinceEpoch %
            2147483647;


    // ------------------------------------------------------------
    // Android notification details
    // ------------------------------------------------------------

    final androidDetails =
        AndroidNotificationDetails(
      _bookingChannel.id,
      _bookingChannel.name,
      channelDescription:
          _bookingChannel.description,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      showWhen: true,
      ticker: title,
      icon: '@mipmap/ic_launcher',
    );


    // ------------------------------------------------------------
    // iOS notification details
    // ------------------------------------------------------------

    const darwinDetails =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );


    final details =
        NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );


    // ------------------------------------------------------------
    // Display
    // ------------------------------------------------------------

    await _localNotifications.show(
      id: notificationId,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );


    print(
      'Foreground local notification displayed.',
    );
  }


  // ==============================================================
  // REGISTER MESSAGE LISTENERS
  // ==============================================================

  Future<void>
      _registerMessageListeners() async {
    await _foregroundMessageSubscription
        ?.cancel();

    await _notificationOpenedSubscription
        ?.cancel();


    // ------------------------------------------------------------
    // FOREGROUND
    // ------------------------------------------------------------

    _foregroundMessageSubscription =
        FirebaseMessaging.onMessage.listen(
      (RemoteMessage message) async {
        try {
          print(
            '========================================',
          );

          print(
            'FCM FOREGROUND MESSAGE RECEIVED',
          );

          print(
            'Message ID: '
            '${message.messageId}',
          );

          print(
            'Title: '
            '${message.notification?.title}',
          );

          print(
            'Body: '
            '${message.notification?.body}',
          );

          print(
            'Data: '
            '${message.data}',
          );

          print(
            '========================================',
          );


          // ------------------------------------------------------
          // IMPORTANT:
          // FCM does not automatically show a notification while
          // Flutter is in the foreground.
          //
          // Therefore we explicitly display a local notification.
          // ------------------------------------------------------

          await _showForegroundNotification(
            message,
          );


          // ------------------------------------------------------
          // Application callback
          // ------------------------------------------------------

          final callback =
              onForegroundMessage;

          if (callback != null) {
            callback(message);
          }
        } catch (error) {
          print(
            'Foreground notification handling failed: '
            '$error',
          );
        }
      },
    );


    // ------------------------------------------------------------
    // BACKGROUND → USER TAPS NOTIFICATION
    // ------------------------------------------------------------

    _notificationOpenedSubscription =
        FirebaseMessaging.onMessageOpenedApp
            .listen(
      (RemoteMessage message) {
        try {
          print(
            'FCM BACKGROUND NOTIFICATION TAPPED',
          );

          _handleNotificationTap(
            message,
          );
        } catch (error) {
          print(
            'Notification tap handling failed: '
            '$error',
          );
        }
      },
    );
  }


  // ==============================================================
  // TOKEN REFRESH
  // ==============================================================

  Future<void>
      _registerTokenRefreshListener() async {
    await _tokenRefreshSubscription
        ?.cancel();


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
          print(
            'FCM token refresh save failed: '
            '$error',
          );
        }
      },
    );
  }


  // ==============================================================
  // TERMINATED APP
  // ==============================================================

  Future<void>
      _handleInitialMessage() async {
    try {
      final message =
          await _messaging
              .getInitialMessage();


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
        'Message ID: '
        '${message.messageId}',
      );

      print(
        'Title: '
        '${message.notification?.title}',
      );

      print(
        'Body: '
        '${message.notification?.body}',
      );

      print(
        'Data: '
        '${message.data}',
      );

      print(
        '========================================',
      );


      _handleNotificationTap(
        message,
      );
    } catch (error) {
      print(
        'Unable to handle initial FCM message: '
        '$error',
      );
    }
  }


  // ==============================================================
  // FCM NOTIFICATION TAP
  // ==============================================================

  void _handleNotificationTap(
    RemoteMessage message,
  ) {
    final data =
        NotificationTapData
            .fromRemoteMessage(
      message,
    );

    _handleNotificationTapData(
      data,
    );
  }


  // ==============================================================
  // COMMON TAP HANDLER
  // ==============================================================

  void _handleNotificationTapData(
    NotificationTapData data,
  ) {
    print(
      '========================================',
    );

    print(
      'FCM NOTIFICATION TAPPED',
    );

    print(
      'Type: ${data.type}',
    );

    print(
      'Tenant: ${data.tenantId}',
    );

    print(
      'Booking: ${data.bookingId}',
    );

    print(
      'Status: ${data.status}',
    );

    print(
      'Payment Status: '
      '${data.paymentStatus}',
    );

    print(
      '========================================',
    );


    // ------------------------------------------------------------
    // Tenant security
    // ------------------------------------------------------------

    final notificationTenant =
        data.tenantId?.trim();

    final currentTenant =
        _currentTenantId?.trim();


    if (notificationTenant != null &&
        notificationTenant.isNotEmpty &&
        currentTenant != null &&
        currentTenant.isNotEmpty &&
        notificationTenant !=
            currentTenant) {
      print(
        'Notification ignored due to tenant mismatch.',
      );

      return;
    }


    // ------------------------------------------------------------
    // Application callback
    // ------------------------------------------------------------

    final callback =
        onNotificationTap;


    if (callback != null) {
      callback(data);
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
        await _messaging
            .requestPermission(
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
      if (Platform.isAndroid) {
        final androidInfo =
            await _deviceInfo
                .androidInfo;

        final id =
            androidInfo.id.trim();


        if (id.isNotEmpty) {
          _deviceId = id;

          return id;
        }
      }


      if (Platform.isIOS) {
        final iosInfo =
            await _deviceInfo
                .iosInfo;

        final id =
            (iosInfo.identifierForVendor ??
                    '')
                .trim();


        if (id.isNotEmpty) {
          _deviceId = id;

          return id;
        }
      }
    } catch (error) {
      print(
        'Unable to get device ID: '
        '$error',
      );
    }


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


    if (cleanTenantId.isEmpty ||
        cleanUserId.isEmpty ||
        cleanDeviceId.isEmpty ||
        cleanToken.isEmpty) {
      throw Exception(
        'Invalid notification device information.',
      );
    }


    final role =
        isAdmin
            ? 'admin'
            : 'customer';


    final userCollection =
        isAdmin
            ? 'admins'
            : 'customers';


    final userRef =
        _firestore
            .collection('tenants')
            .doc(cleanTenantId)
            .collection(userCollection)
            .doc(cleanUserId);


    final deviceRef =
        userRef
            .collection(
              'notificationDevices',
            )
            .doc(cleanDeviceId);


    final existingDevice =
        await deviceRef.get();


    final Map<String, dynamic>
        deviceData = {
      'deviceId':
          cleanDeviceId,

      'fcmToken':
          cleanToken,

      'firebaseUid':
          cleanUserId,

      'tenantId':
          cleanTenantId,

      'role':
          role,

      'isAdmin':
          isAdmin,

      'isActive':
          true,

      'platform':
          _platformName(),

      'updatedAt':
          FieldValue.serverTimestamp(),

      'lastSeenAt':
          FieldValue.serverTimestamp(),
    };


    if (!existingDevice.exists) {
      deviceData['createdAt'] =
          FieldValue.serverTimestamp();
    }


    await deviceRef.set(
      deviceData,
      SetOptions(
        merge: true,
      ),
    );


    _deviceId =
        cleanDeviceId;

    _currentTenantId =
        cleanTenantId;

    _currentUserId =
        cleanUserId;

    _isAdmin =
        isAdmin;


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
          .collection(
            'notificationDevices',
          )
          .doc(deviceId)
          .set(
        {
          'lastSeenAt':
              FieldValue.serverTimestamp(),

          'updatedAt':
              FieldValue.serverTimestamp(),

          'isActive':
              true,
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

  Future<void>
      deactivateCurrentDevice() async {
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
          .collection(
            'notificationDevices',
          )
          .doc(deviceId)
          .set(
        {
          'isActive':
              false,

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
    try {
      await _tokenRefreshSubscription
          ?.cancel();
    } catch (_) {}


    try {
      await _foregroundMessageSubscription
          ?.cancel();
    } catch (_) {}


    try {
      await _notificationOpenedSubscription
          ?.cancel();
    } catch (_) {}


    _tokenRefreshSubscription =
        null;

    _foregroundMessageSubscription =
        null;

    _notificationOpenedSubscription =
        null;


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
  // HELPERS
  // ==============================================================

  String? _stringValue(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    final text =
        value.toString().trim();

    if (text.isEmpty) {
      return null;
    }

    return text;
  }


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