
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../admin/dashboard/screens/admin_dashboard_screen.dart';
import '../../home/screens/home_screen.dart';

/// ============================================================
/// APPLICATION MODE
/// ============================================================
///
/// The Firebase user remains authenticated.
///
/// This only represents which experience the admin has chosen
/// to enter after authentication.
///
/// ============================================================

enum AppMode {
  admin,
  customer,
}

/// ============================================================
/// ADMIN MODE SELECTION SCREEN
/// ============================================================
///
/// Shown ONLY after a valid admin has successfully completed OTP.
///
/// Options:
///
/// 1. Continue as Admin
///    -> AdminDashboardScreen
///
/// 2. Continue as Customer
///    -> HomeScreen
///
/// IMPORTANT:
/// - No second Firebase login
/// - No sign out
/// - No Firebase user replacement
/// - Existing admin authentication remains active
/// - tenantId is preserved
///
/// ============================================================

class AdminModeSelectionScreen extends StatefulWidget {
  const AdminModeSelectionScreen({
    super.key,
    required this.tenantId,
  });

  final String tenantId;

  @override
  State<AdminModeSelectionScreen> createState() =>
      _AdminModeSelectionScreenState();
}

class _AdminModeSelectionScreenState
    extends State<AdminModeSelectionScreen> {
  // ============================================================
  // STATE
  // ============================================================

  AppMode? _selectedMode;

  bool _isLoading = false;

  // ============================================================
  // FIREBASE USER
  // ============================================================

  User? get _currentUser =>
      FirebaseAuth.instance.currentUser;

  // ============================================================
  // DISPLAY NAME
  // ============================================================

  String get _displayName {
    final user = _currentUser;

    if (user == null) {
      return 'Admin';
    }

    final name =
        user.displayName?.trim();

    if (name != null &&
        name.isNotEmpty) {
      return name;
    }

    return 'Admin';
  }

  // ============================================================
  // PHONE
  // ============================================================

  String get _displayPhone {
    final phone =
        _currentUser?.phoneNumber?.trim();

    if (phone == null ||
        phone.isEmpty) {
      return 'Authenticated account';
    }

    return phone;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final size =
        MediaQuery.sizeOf(context);

    final isTablet =
        size.width >= 600;

    return Scaffold(
      backgroundColor:
          const Color(0xFFF7F9F8),
      body: SafeArea(
        child: Stack(
          children: [
            // ==================================================
            // BACKGROUND
            // ==================================================

            _buildBackground(),

            // ==================================================
            // CONTENT
            // ==================================================

            Center(
              child: SingleChildScrollView(
                physics:
                    const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal:
                      isTablet ? 40 : 20,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(
                    maxWidth: 720,
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                    children: [
                      // ========================================
                      // HEADER
                      // ========================================

                      _buildHeader(),

                      const SizedBox(
                        height: 44,
                      ),

                      // ========================================
                      // WELCOME
                      // ========================================

                      _buildWelcome(),

                      const SizedBox(
                        height: 30,
                      ),

                      // ========================================
                      // MODE CARDS
                      // ========================================

                      _buildAdminCard(),

                      const SizedBox(
                        height: 16,
                      ),

                      _buildCustomerCard(),

                      const SizedBox(
                        height: 24,
                      ),

                      // ========================================
                      // CONTINUE BUTTON
                      // ========================================

                      _buildContinueButton(),

                      const SizedBox(
                        height: 20,
                      ),

                      // ========================================
                      // ACCOUNT
                      // ========================================

                      _buildAccountCard(),

                      const SizedBox(
                        height: 18,
                      ),

                      // ========================================
                      // SECURITY
                      // ========================================

                      _buildSecurityMessage(),

                      const SizedBox(
                        height: 8,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ==================================================
            // LOADING
            // ==================================================

            if (_isLoading)
              _buildLoadingOverlay(),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BACKGROUND
  // ============================================================

  Widget _buildBackground() {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -120,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration:
                  const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFE7F7F4),
              ),
            ),
          ),

          Positioned(
            bottom: -150,
            left: -130,
            child: Container(
              width: 320,
              height: 320,
              decoration:
                  const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFEEF4FF),
              ),
            ),
          ),

          Positioned(
            top: 260,
            right: -180,
            child: Container(
              width: 280,
              height: 280,
              decoration:
                  const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFF1F5F9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(17),
            gradient:
                const LinearGradient(
              begin:
                  Alignment.topLeft,
              end:
                  Alignment.bottomRight,
              colors: [
                Color(0xFF0F172A),
                Color(0xFF334155),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withValues(
                  alpha: 0.12,
                ),
                blurRadius: 22,
                offset:
                    const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons
                .directions_car_filled_rounded,
            color: Colors.white,
            size: 27,
          ),
        ),

        const SizedBox(
          width: 14,
        ),

        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'RENTAL',
                style:
                    GoogleFonts.manrope(
                  fontSize: 18,
                  fontWeight:
                      FontWeight.w900,
                  letterSpacing: 2.4,
                  color:
                      const Color(
                    0xFF0F172A,
                  ),
                ),
              ),
              const SizedBox(
                height: 2,
              ),
              Text(
                'Management Platform',
                style:
                    GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight:
                      FontWeight.w700,
                  letterSpacing: 0.8,
                  color:
                      const Color(
                    0xFF7B8583,
                  ),
                ),
              ),
            ],
          ),
        ),

        Container(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            color:
                const Color(0xFFE9F8F5),
            borderRadius:
                BorderRadius.circular(100),
            border: Border.all(
              color:
                  const Color(0xFFC9EDE7),
            ),
          ),
          child: Row(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration:
                    const BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      Color(0xFF10B981),
                ),
              ),
              const SizedBox(
                width: 6,
              ),
              Text(
                'SECURE',
                style:
                    GoogleFonts.manrope(
                  fontSize: 9,
                  fontWeight:
                      FontWeight.w800,
                  letterSpacing: 0.7,
                  color:
                      const Color(
                    0xFF047857,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // WELCOME
  // ============================================================

  Widget _buildWelcome() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Container(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 11,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            color:
                const Color(0xFFEFF6FF),
            borderRadius:
                BorderRadius.circular(100),
            border: Border.all(
              color:
                  const Color(0xFFD8E7FF),
            ),
          ),
          child: Row(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              const Icon(
                Icons
                    .admin_panel_settings_rounded,
                size: 15,
                color:
                    Color(0xFF2563EB),
              ),
              const SizedBox(
                width: 6,
              ),
              Text(
                'ADMIN ACCOUNT',
                style:
                    GoogleFonts.manrope(
                  fontSize: 9,
                  fontWeight:
                      FontWeight.w900,
                  letterSpacing: 1.1,
                  color:
                      const Color(
                    0xFF1D4ED8,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(
          height: 17,
        ),

        Text(
          'Welcome back,\n$_displayName',
          style:
              GoogleFonts.manrope(
            fontSize: 32,
            height: 1.12,
            fontWeight:
                FontWeight.w900,
            letterSpacing: -1,
            color:
                const Color(0xFF111827),
          ),
        ),

        const SizedBox(
          height: 11,
        ),

        Text(
          'Choose how you would like to continue.',
          style:
              GoogleFonts.manrope(
            fontSize: 14,
            height: 1.5,
            fontWeight:
                FontWeight.w500,
            color:
                const Color(0xFF697572),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ADMIN CARD
  // ============================================================

  Widget _buildAdminCard() {
    return _buildModeCard(
      mode: AppMode.admin,
      icon:
          Icons.admin_panel_settings_rounded,
      title:
          'Continue as Admin',
      subtitle:
          'Manage cars, bookings, customers, pricing, branches and your entire rental operation.',
      badge:
          'BUSINESS MANAGEMENT',
      gradient: const [
        Color(0xFF0F172A),
        Color(0xFF1E293B),
      ],
      accent:
          const Color(0xFF67E8F9),
      features: const [
        'Manage rental operations',
        'View bookings & customers',
        'Manage cars & pricing',
      ],
    );
  }

  // ============================================================
  // CUSTOMER CARD
  // ============================================================

  Widget _buildCustomerCard() {
    return _buildModeCard(
      mode: AppMode.customer,
      icon:
          Icons.person_rounded,
      title:
          'Continue as Customer',
      subtitle:
          'Use the customer experience to browse vehicles, check availability and make bookings.',
      badge:
          'CUSTOMER EXPERIENCE',
      gradient: const [
        Color(0xFF1D4ED8),
        Color(0xFF2563EB),
      ],
      accent:
          const Color(0xFFBFDBFE),
      features: const [
        'Browse available cars',
        'Check rental availability',
        'Make customer bookings',
      ],
    );
  }

  // ============================================================
  // MODE CARD
  // ============================================================

  Widget _buildModeCard({
    required AppMode mode,
    required IconData icon,
    required String title,
    required String subtitle,
    required String badge,
    required List<Color> gradient,
    required Color accent,
    required List<String> features,
  }) {
    final selected =
        _selectedMode == mode;

    return GestureDetector(
      behavior:
          HitTestBehavior.opaque,
      onTap: _isLoading
          ? null
          : () {
              setState(() {
                _selectedMode = mode;
              });
            },
      child: AnimatedContainer(
        duration:
            const Duration(
          milliseconds: 220,
        ),
        curve:
            Curves.easeOutCubic,
        padding:
            const EdgeInsets.all(21),
        decoration: BoxDecoration(
          gradient:
              LinearGradient(
            begin:
                Alignment.topLeft,
            end:
                Alignment.bottomRight,
            colors:
                gradient,
          ),
          borderRadius:
              BorderRadius.circular(25),
          border:
              Border.all(
            color: selected
                ? accent
                : Colors.white
                    .withValues(
                    alpha: 0.10,
                  ),
            width:
                selected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  gradient.first
                      .withValues(
                alpha:
                    selected
                        ? 0.25
                        : 0.10,
              ),
              blurRadius:
                  selected ? 30 : 20,
              offset:
                  const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            // ================================================
            // ICON + RADIO
            // ================================================

            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration:
                      BoxDecoration(
                    color: Colors.white
                        .withValues(
                      alpha: 0.11,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      17,
                    ),
                    border:
                        Border.all(
                      color: Colors
                          .white
                          .withValues(
                        alpha: 0.13,
                      ),
                    ),
                  ),
                  child: Icon(
                    icon,
                    color:
                        Colors.white,
                    size: 27,
                  ),
                ),

                const Spacer(),

                AnimatedContainer(
                  duration:
                      const Duration(
                    milliseconds: 180,
                  ),
                  width: 28,
                  height: 28,
                  decoration:
                      BoxDecoration(
                    shape:
                        BoxShape.circle,
                    color: selected
                        ? accent
                        : Colors
                            .white
                            .withValues(
                            alpha:
                                0.08,
                          ),
                    border:
                        Border.all(
                      color: selected
                          ? accent
                          : Colors
                              .white
                              .withValues(
                              alpha:
                                  0.30,
                            ),
                      width: 1.5,
                    ),
                  ),
                  child: selected
                      ? const Icon(
                          Icons
                              .check_rounded,
                          size: 17,
                          color:
                              Color(
                            0xFF0F172A,
                          ),
                        )
                      : null,
                ),
              ],
            ),

            const SizedBox(
              height: 20,
            ),

            // ================================================
            // BADGE
            // ================================================

            Container(
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 9,
                vertical: 5,
              ),
              decoration:
                  BoxDecoration(
                color: Colors
                    .white
                    .withValues(
                  alpha: 0.10,
                ),
                borderRadius:
                    BorderRadius.circular(
                  8,
                ),
              ),
              child: Text(
                badge,
                style:
                    GoogleFonts.manrope(
                  fontSize: 8.5,
                  fontWeight:
                      FontWeight.w900,
                  letterSpacing: 1,
                  color:
                      accent,
                ),
              ),
            ),

            const SizedBox(
              height: 10,
            ),

            // ================================================
            // TITLE
            // ================================================

            Text(
              title,
              style:
                  GoogleFonts.manrope(
                fontSize: 21,
                fontWeight:
                    FontWeight.w900,
                letterSpacing:
                    -0.4,
                color:
                    Colors.white,
              ),
            ),

            const SizedBox(
              height: 7,
            ),

            // ================================================
            // DESCRIPTION
            // ================================================

            Text(
              subtitle,
              style:
                  GoogleFonts.manrope(
                fontSize: 12.5,
                height: 1.55,
                fontWeight:
                    FontWeight.w500,
                color: Colors
                    .white
                    .withValues(
                  alpha: 0.70,
                ),
              ),
            ),

            const SizedBox(
              height: 17,
            ),

            // ================================================
            // FEATURES
            // ================================================

            ...features.map(
              (feature) {
                return Padding(
                  padding:
                      const EdgeInsets.only(
                    bottom: 8,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons
                            .check_circle_rounded,
                        size: 15,
                        color:
                            accent,
                      ),
                      const SizedBox(
                        width: 8,
                      ),
                      Expanded(
                        child: Text(
                          feature,
                          style:
                              GoogleFonts
                                  .manrope(
                            fontSize:
                                11,
                            fontWeight:
                                FontWeight.w600,
                            color: Colors
                                .white
                                .withValues(
                              alpha:
                                  0.68,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(
              height: 4,
            ),

            // ================================================
            // SELECT FOOTER
            // ================================================

            Row(
              children: [
                Text(
                  selected
                      ? 'Selected'
                      : 'Select this option',
                  style:
                      GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w800,
                    color: selected
                        ? accent
                        : Colors
                            .white
                            .withValues(
                            alpha:
                                0.50,
                          ),
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons
                      .arrow_forward_rounded,
                  size: 19,
                  color: selected
                      ? accent
                      : Colors
                          .white
                          .withValues(
                          alpha:
                              0.45,
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CONTINUE BUTTON
  // ============================================================

  Widget _buildContinueButton() {
    final hasSelection =
        _selectedMode != null;

    String label;

    if (_selectedMode ==
        AppMode.admin) {
      label =
          'Open Admin Dashboard';
    } else if (_selectedMode ==
        AppMode.customer) {
      label =
          'Continue as Customer';
    } else {
      label =
          'Choose how to continue';
    }

    return AnimatedOpacity(
      duration:
          const Duration(
        milliseconds: 200,
      ),
      opacity:
          hasSelection ? 1 : 0.45,
      child: SizedBox(
        height: 58,
        child: ElevatedButton(
          onPressed:
              !_isLoading &&
                      hasSelection
                  ? _continue
                  : null,
          style:
              ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor:
                const Color(
              0xFF0F172A,
            ),
            disabledBackgroundColor:
                const Color(
              0xFF0F172A,
            ),
            foregroundColor:
                Colors.white,
            shape:
                RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(
                18,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Text(
                label,
                style:
                    GoogleFonts.manrope(
                  fontSize: 13.5,
                  fontWeight:
                      FontWeight.w800,
                  color:
                      Colors.white,
                ),
              ),
              if (hasSelection) ...[
                const SizedBox(
                  width: 9,
                ),
                const Icon(
                  Icons
                      .arrow_forward_rounded,
                  size: 19,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ACCOUNT CARD
  // ============================================================

  Widget _buildAccountCard() {
    return Container(
      padding:
          const EdgeInsets.all(15),
      decoration:
          BoxDecoration(
        color:
            Colors.white,
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        border:
            Border.all(
          color:
              const Color(0xFFE5EAE8),
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(
              alpha: 0.025,
            ),
            blurRadius:
                15,
            offset:
                const Offset(0, 5),
          ),
        ],
      ),
      child:
          Row(
        children: [
          Container(
            width:
                42,
            height:
                42,
            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xFFF1F5F9,
              ),
              borderRadius:
                  BorderRadius.circular(
                13,
              ),
            ),
            child:
                const Icon(
              Icons
                  .phone_rounded,
              size:
                  18,
              color:
                  Color(
                0xFF475569,
              ),
            ),
          ),

          const SizedBox(
            width: 12,
          ),

          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  'Signed in account',
                  style:
                      GoogleFonts.manrope(
                    fontSize:
                        9.5,
                    fontWeight:
                        FontWeight.w700,
                    color:
                        const Color(
                      0xFF9AA5A2,
                    ),
                  ),
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  _displayPhone,
                  maxLines:
                      1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      GoogleFonts.manrope(
                    fontSize:
                        12.5,
                    fontWeight:
                        FontWeight.w800,
                    color:
                        const Color(
                      0xFF1E293B,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Container(
            width:
                30,
            height:
                30,
            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xFFECFDF5,
              ),
              borderRadius:
                  BorderRadius.circular(
                10,
              ),
            ),
            child:
                const Icon(
              Icons
                  .verified_rounded,
              size:
                  16,
              color:
                  Color(
                0xFF16A34A,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SECURITY
  // ============================================================

  Widget _buildSecurityMessage() {
    return Row(
      mainAxisAlignment:
          MainAxisAlignment.center,
      children: [
        const Icon(
          Icons
              .lock_outline_rounded,
          size:
              14,
          color:
              Color(0xFF9AA5A2),
        ),
        const SizedBox(
          width: 6,
        ),
        Flexible(
          child:
              Text(
            'Your secure admin session remains active.',
            textAlign:
                TextAlign.center,
            style:
                GoogleFonts.manrope(
              fontSize:
                  10.5,
              fontWeight:
                  FontWeight.w500,
              color:
                  const Color(
                0xFF9AA5A2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // LOADING OVERLAY
  // ============================================================

  Widget _buildLoadingOverlay() {
    return Positioned.fill(
      child:
          Container(
        color:
            Colors.black.withValues(
          alpha: 0.10,
        ),
        child:
            Center(
          child:
              Container(
            padding:
                const EdgeInsets.all(
              22,
            ),
            decoration:
                BoxDecoration(
              color:
                  Colors.white,
              borderRadius:
                  BorderRadius.circular(
                20,
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      Colors.black.withValues(
                    alpha: 0.12,
                  ),
                  blurRadius:
                      30,
                  offset:
                      const Offset(
                    0,
                    12,
                  ),
                ),
              ],
            ),
            child:
                const SizedBox(
              width:
                  28,
              height:
                  28,
              child:
                  CircularProgressIndicator(
                strokeWidth:
                    2.7,
                color:
                    Color(
                  0xFF0F766E,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CONTINUE
  // ============================================================

  Future<void> _continue() async {
    final mode =
        _selectedMode;

    if (mode == null ||
        _isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Small intentional transition.
    await Future.delayed(
      const Duration(
        milliseconds: 250,
      ),
    );

    if (!mounted) {
      return;
    }

    if (mode ==
        AppMode.admin) {
      _openAdminDashboard();
    } else {
      _openCustomerHome();
    }
  }

  // ============================================================
  // ADMIN DASHBOARD
  // ============================================================

  void _openAdminDashboard() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const AdminDashboardScreen(),
      ),
      (route) => false,
    );
  }

  // ============================================================
  // CUSTOMER HOME
  // ============================================================

  void _openCustomerHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const HomeScreen(),
      ),
      (route) => false,
    );
  }
}

