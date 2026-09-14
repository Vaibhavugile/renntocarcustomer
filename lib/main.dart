import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/config/app_config.dart';
import 'core/data/dummy_config.dart';
import 'core/services/firebase_config_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/screens/login_screen.dart';
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
  // 2. CURRENT WHITE-LABEL TENANT
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
  // 3. LOAD TENANT CONFIGURATION FROM FIREBASE
  // ============================================================

  final firebaseService = FirebaseConfigService();

  final firebaseConfig =
      await firebaseService.getTenantConfig(
    tenantId,
  );

  // ============================================================
  // 4. INITIALIZE APP CONFIGURATION
  // ============================================================

  if (firebaseConfig != null) {
    AppConfig.initialize(firebaseConfig);
  } else {
    AppConfig.initialize(dummyTenantConfig);
  }

  // ============================================================
  // 5. INITIALIZE PRICING
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
  // 6. START APPLICATION
  // ============================================================

  runApp(const CarRentalApp());
}

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

      home: const LoginScreen(),
    );
  }
}