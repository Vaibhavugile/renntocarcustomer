import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../ai_chat/screens/ai_chat_screen.dart';
import '../../booking/screens/my_bookings_screen.dart';
import '../../customer/screens/profile_screen.dart';
import '../../payment/screens/customer_transactions_screen.dart';
import 'explore_screen.dart';

import '../widgets/active_booking.dart';
import '../widgets/featured_cars.dart';
import '../widgets/home_bottom_nav.dart';
import '../widgets/home_categories.dart';
import '../widgets/home_header.dart';
import '../widgets/home_hero.dart';
import '../widgets/home_search.dart';
import '../widgets/why_choose_us.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  // ============================================================
  // FIXED PREMIUM LIGHT PALETTE
  // ============================================================

  static const Color background = Color(0xFFF8FAF9);
  static const Color softAccent = Color(0xFFE6FFFB);
  static const Color primary = Color(0xFF0F766E);
  static const Color heading = Color(0xFF17201F);
  static const Color body = Color(0xFF66706E);

  // ============================================================
  // TENANT
  // ============================================================

  String get _tenantId {
    try {
      return AppConfig.tenant.tenantId.trim();
    } catch (_) {
      return '';
    }
  }

  // ============================================================
  // BOTTOM NAVIGATION
  //
  // 0 = Home
  // 1 = Explore
  // 2 = Bookings
  // 3 = Transactions
  // 4 = Profile
  // ============================================================

  int _selectedNav = 0;

  int _bookingCount = 0;

  // ============================================================
  // AI ANIMATION
  // ============================================================

  late final AnimationController _aiAnimationController;

  late final Animation<double> _aiScaleAnimation;

  late final Animation<double> _aiGlowAnimation;

  @override
  void initState() {
    super.initState();

    _aiAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 2200,
      ),
    );

    _aiScaleAnimation = Tween<double>(
      begin: 0.96,
      end: 1.04,
    ).animate(
      CurvedAnimation(
        parent: _aiAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _aiGlowAnimation = Tween<double>(
      begin: 0.15,
      end: 0.32,
    ).animate(
      CurvedAnimation(
        parent: _aiAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _aiAnimationController.repeat(
      reverse: true,
    );
  }

  @override
  void dispose() {
    _aiAnimationController.dispose();
    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,

      // ========================================================
      // BODY
      // ========================================================

      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _selectedNav,
          children: [
            // ====================================================
            // 0. HOME
            // ====================================================

            _buildHome(),

            // ====================================================
            // 1. EXPLORE
            // ====================================================

            ExploreScreen(
              tenantId: _tenantId,
            ),

            // ====================================================
            // 2. BOOKINGS
            // ====================================================

            MyBookingsScreen(
              tenantId: _tenantId,
            ),

            // ====================================================
            // 3. TRANSACTIONS
            // ====================================================

            CustomerTransactionsScreen(
              tenantId: _tenantId,
            ),

            // ====================================================
            // 4. PROFILE
            // ====================================================

            const ProfileScreen(),
          ],
        ),
      ),

      // ==========================================================
      // BOTTOM NAVIGATION
      // ==========================================================

      bottomNavigationBar: HomeBottomNav(
        selectedIndex: _selectedNav,
        bookingCount: _bookingCount,
        onChanged: _onNavigationChanged,
      ),

      // ==========================================================
      // AI ASSISTANT BUTTON
      // ==========================================================
      //
      // We intentionally put this inside a Stack/Floating layer
      // instead of modifying HomeBottomNav.
      //
      // This means your existing bottom navigation remains
      // completely untouched.
      //
      // ==========================================================

      floatingActionButton: _buildAIButton(),

      floatingActionButtonLocation:
          FloatingActionButtonLocation.endFloat,
    );
  }

  // ============================================================
  // AI ASSISTANT BUTTON
  // ============================================================

  Widget _buildAIButton() {
    return AnimatedBuilder(
      animation: _aiAnimationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _aiScaleAnimation.value,
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,

              // ------------------------------------------------
              // PREMIUM OUTER GLOW
              // ------------------------------------------------

              boxShadow: [
                BoxShadow(
                  color: primary.withValues(
                    alpha: _aiGlowAnimation.value,
                  ),
                  blurRadius: 18,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: _openAIChat,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,

                    // ------------------------------------------------
                    // PREMIUM LIGHT GRADIENT
                    // ------------------------------------------------

                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF19A89B),
                        Color(0xFF0F766E),
                      ],
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // ----------------------------------------------
                      // SUBTLE INNER HIGHLIGHT
                      // ----------------------------------------------

                      Positioned(
                        top: 7,
                        left: 10,
                        child: Container(
                          width: 14,
                          height: 8,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: Colors.white.withValues(
                              alpha: 0.20,
                            ),
                          ),
                        ),
                      ),

                      // ----------------------------------------------
                      // AI ICON
                      // ----------------------------------------------

                      const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 25,
                      ),

                      // ----------------------------------------------
                      // ONLINE DOT
                      // ----------------------------------------------

                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: Container(
                          width: 13,
                          height: 13,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF34D399),
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // OPEN AI CHAT
  // ============================================================

  void _openAIChat() {
    final tenantId = _tenantId;

    if (tenantId.isEmpty) {
      _showAIError(
        'We could not identify your rental account right now.',
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AIChatScreen(
          tenantId: tenantId,
        ),
      ),
    );
  }

  // ============================================================
  // AI ERROR
  // ============================================================

  void _showAIError(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(
            16,
            0,
            16,
            90,
          ),
          elevation: 0,
          backgroundColor: heading,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: primary.withValues(
                    alpha: 0.18,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFF5EEAD4),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  // ============================================================
  // NAVIGATION
  // ============================================================

  void _onNavigationChanged(int index) {
    // We now have 5 tabs:
    //
    // 0 Home
    // 1 Explore
    // 2 Bookings
    // 3 Transactions
    // 4 Profile

    if (index < 0 || index > 4) {
      return;
    }

    if (_selectedNav == index) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedNav = index;
    });
  }

  // ============================================================
  // HOME CONTENT
  // ============================================================

  Widget _buildHome() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: const [
        // --------------------------------------------------------
        // HEADER
        // --------------------------------------------------------

        SliverToBoxAdapter(
          child: HomeHeader(),
        ),

        // --------------------------------------------------------
        // HERO
        // --------------------------------------------------------

        SliverToBoxAdapter(
          child: HomeHero(),
        ),

        // --------------------------------------------------------
        // SEARCH
        // --------------------------------------------------------

        SliverToBoxAdapter(
          child: HomeSearch(),
        ),

        // --------------------------------------------------------
        // CATEGORIES
        // --------------------------------------------------------

        SliverToBoxAdapter(
          child: HomeCategories(),
        ),

        // --------------------------------------------------------
        // ACTIVE BOOKING
        // --------------------------------------------------------

        SliverToBoxAdapter(
          child: ActiveBooking(),
        ),

        // --------------------------------------------------------
        // FEATURED CARS
        // --------------------------------------------------------

        SliverToBoxAdapter(
          child: FeaturedCars(),
        ),

        // --------------------------------------------------------
        // WHY CHOOSE US
        // --------------------------------------------------------

        SliverToBoxAdapter(
          child: WhyChooseUs(),
        ),

        // --------------------------------------------------------
        // BOTTOM SPACING
        // --------------------------------------------------------

        SliverToBoxAdapter(
          child: SizedBox(
            height: 32,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // PLACEHOLDER
  // ============================================================

  Widget _buildPlaceholder({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: softAccent,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                icon,
                size: 34,
                color: primary,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 23,
                fontWeight: FontWeight.w900,
                color: heading,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: body,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}