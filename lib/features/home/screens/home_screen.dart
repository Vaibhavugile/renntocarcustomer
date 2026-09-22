import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../booking/screens/my_bookings_screen.dart';
import '../../customer/screens/profile_screen.dart';
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
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color background = Color(0xFFF8FAF9);
  static const Color softAccent = Color(0xFFE6FFFB);
  static const Color primary = Color(0xFF0F766E);
  static const Color heading = Color(0xFF17201F);
  static const Color body = Color(0xFF66706E);

  String get _tenantId {
    try {
      return AppConfig.tenant.tenantId.trim();
    } catch (_) {
      return '';
    }
  }

  int _selectedNav = 0;

  // Kept here for the current bottom-nav API.
  // Replace with a live booking-count stream later if desired.
  int _bookingCount = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _selectedNav,
          children: [
            _buildHome(),

            // REAL CUSTOMER EXPLORE
            ExploreScreen(
              tenantId: _tenantId,
            ),

            // REAL CUSTOMER BOOKINGS
            MyBookingsScreen(
              tenantId: _tenantId,
            ),

            // REAL CUSTOMER PROFILE
            const ProfileScreen(),
          ],
        ),
      ),
      bottomNavigationBar: HomeBottomNav(
        selectedIndex: _selectedNav,
        bookingCount: _bookingCount,
        onChanged: _onNavigationChanged,
      ),
    );
  }

  void _onNavigationChanged(int index) {
    if (index < 0 || index > 3) {
      return;
    }

    if (_selectedNav == index) {
      return;
    }

    setState(() {
      _selectedNav = index;
    });
  }

  Widget _buildHome() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: const [
        SliverToBoxAdapter(
          child: HomeHeader(),
        ),
        SliverToBoxAdapter(
          child: HomeHero(),
        ),
        SliverToBoxAdapter(
          child: HomeSearch(),
        ),
        SliverToBoxAdapter(
          child: HomeCategories(),
        ),
        SliverToBoxAdapter(
          child: ActiveBooking(),
        ),
        SliverToBoxAdapter(
          child: FeaturedCars(),
        ),
        SliverToBoxAdapter(
          child: WhyChooseUs(),
        ),
        SliverToBoxAdapter(
          child: SizedBox(height: 32),
        ),
      ],
    );
  }

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
