import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'core/config/app_config.dart';
import 'core/data/dummy_config.dart';
import 'core/services/firebase_config_service.dart';
import 'core/theme/app_theme.dart';
import 'core/notifications/notification_service.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/admin_mode_selection_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'features/pricing/manager/pricing_manager.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ============================================================
  // 1. INITIALIZE FIREBASE
  // ============================================================

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ============================================================
  // 2. REGISTER FCM BACKGROUND HANDLER
  // ============================================================
  //
  // IMPORTANT:
  // This must be registered before runApp().
  //
  // It allows Firebase Messaging to process messages when the
  // application is:
  //
  //   • In background
  //   • Completely closed
  //   • Running in a background isolate
  //
  // The handler itself is defined in:
  //
  // core/notifications/notification_service.dart
  //
  // @pragma('vm:entry-point') is already present there.
  //

  FirebaseMessaging.onBackgroundMessage(
    firebaseMessagingBackgroundHandler,
  );

  // ============================================================
  // 3. CURRENT WHITE-LABEL TENANT
  // ============================================================
  //
  // For now this is fixed to Rentocar.
  //
  // Later:
  //
  // Rentocar APK       → tenant_001
  // ABC Cars APK       → tenant_002
  // XYZ Rentals APK    → tenant_003
  //
  // The customer will NOT select the tenant.
  // The tenant will be injected into the branded APK.
  //

  const tenantId = 'tenant_001';

  // ============================================================
  // 4. LOAD TENANT CONFIGURATION FROM FIREBASE
  // ============================================================

  final firebaseService = FirebaseConfigService();

  final firebaseConfig =
      await firebaseService.getTenantConfig(
    tenantId,
  );

  // ============================================================
  // 5. INITIALIZE APP CONFIGURATION
  // ============================================================

  if (firebaseConfig != null) {
    AppConfig.initialize(firebaseConfig);
  } else {
    AppConfig.initialize(dummyTenantConfig);
  }

  // ============================================================
  // 6. INITIALIZE PRICING
  // ============================================================
  //
  // Pricing is loaded once and kept in memory.
  //
  // Car:
  //   pricingProfileId
  //          ↓
  // PricingManager
  //          ↓
  // Correct PricingProfile
  //
  // This prevents the PricingEngine / Car Details screen
  // from making repeated Firestore reads.
  //

  await PricingManager.instance.initialize(
    tenantId: tenantId,
  );

  // ============================================================
  // 7. START APPLICATION
  // ============================================================

  runApp(
    const CarRentalApp(),
  );
}

// =================================================================
// APPLICATION
// =================================================================

class CarRentalApp extends StatelessWidget {
  const CarRentalApp({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final config = AppConfig.tenant;

    return MaterialApp(
      // ==========================================================
      // APP SETTINGS
      // ==========================================================

      debugShowCheckedModeBanner: false,

      // Dynamic application name
      title: config.branding.appName,

      // ==========================================================
      // PREMIUM THEMES
      // ==========================================================

      theme: AppTheme.light,

      darkTheme: AppTheme.dark,

      // Rentocar uses premium LIGHT UI
      themeMode: ThemeMode.light,

      // ==========================================================
      // START SCREEN
      // ==========================================================
      //
      // Current customer flow:
      //
      // Login
      //   ↓
      // OTP
      //   ↓
      // Home
      //   ↓
      // Vehicle
      //   ↓
      // Car Details
      //   ↓
      // Date & Time
      //   ↓
      // Booking
      //

      home: const AuthStartupRouter(),
    );
  }
}


// =================================================================
// AUTH STARTUP ROUTER
// =================================================================
//
// FirebaseAuth persists the authenticated session on the device.
//
// App opened
//    ↓
// FirebaseAuth.currentUser?
//    ├── null → LoginScreen
//    └── user → check tenants/{tenantId}/admins/{uid}
//                    ├── admin → AdminModeSelectionScreen
//                    └── customer → HomeScreen
//
// Logout is what sends the user back to LoginScreen.
// =================================================================

class AuthStartupRouter extends StatefulWidget {
  const AuthStartupRouter({super.key});

  @override
  State<AuthStartupRouter> createState() =>
      _AuthStartupRouterState();
}

class _AuthStartupRouterState
    extends State<AuthStartupRouter> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  bool _loading = true;
  Widget? _screen;

  String get _tenantId =>
      AppConfig.tenant.tenantId.trim();

  @override
  void initState() {
    super.initState();
    _resolveStartupRoute();
  }

  Future<void> _resolveStartupRoute() async {
    try {
      final user = _auth.currentUser;

      // ------------------------------------------------------------
      // NOT LOGGED IN
      // ------------------------------------------------------------
      if (user == null) {
        _setScreen(const LoginScreen());
        return;
      }

      final tenantId = _tenantId;

      if (tenantId.isEmpty) {
        await _auth.signOut();
        _setScreen(const LoginScreen());
        return;
      }

      // ------------------------------------------------------------
      // CHECK ADMIN ACCOUNT
      // ------------------------------------------------------------
      final adminDoc = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('admins')
          .doc(user.uid)
          .get();

      // ------------------------------------------------------------
      // CUSTOMER
      // ------------------------------------------------------------
      if (!adminDoc.exists) {
        // Firebase session is already valid.
        // DO NOT ask the customer for OTP again.
        _setScreen(const HomeScreen());
        return;
      }

      final adminData =
          adminDoc.data() ?? <String, dynamic>{};

      final storedTenantId =
          adminData['tenantId']?.toString().trim() ?? '';

      final isActive =
          adminData['isActive'] == true;

      // Tenant security check.
      if (storedTenantId.isNotEmpty &&
          storedTenantId != tenantId) {
        await _auth.signOut();
        _setScreen(const LoginScreen());
        return;
      }

      // Disabled admin must authenticate again after being disabled.
      if (!isActive) {
        await _auth.signOut();
        _setScreen(const LoginScreen());
        return;
      }

      // ------------------------------------------------------------
      // ADMIN
      // ------------------------------------------------------------
      //
      // Keep Firebase authenticated.
      // The existing selection screen decides whether the admin
      // continues as Admin or Customer.
      //
      _setScreen(
        AdminModeSelectionScreen(
          tenantId: tenantId,
        ),
      );
    } catch (error) {
      debugPrint(
        'Auth startup routing error: $error',
      );

      try {
        await _auth.signOut();
      } catch (_) {}

      _setScreen(const LoginScreen());
    }
  }

  void _setScreen(Widget screen) {
    if (!mounted) return;

    setState(() {
      _screen = screen;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _screen == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return _screen!;
  }
}
