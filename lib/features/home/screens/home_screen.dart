import 'package:flutter/material.dart';

import '../../booking/screens/my_bookings_screen.dart';
import '../../customer/screens/profile_screen.dart';
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
  // Keep the tenant explicit here for the current white-label prototype.
  // This will later come from the app/bootstrap configuration.
  static const String _tenantId = 'tenant_001';

  static const Color background = Color(0xFFF8FAF9);
  static const Color softAccent = Color(0xFFE6FFFB);
  static const Color primary = Color(0xFF0F766E);
  static const Color heading = Color(0xFF17201F);
  static const Color body = Color(0xFF66706E);

  int _selectedNav = 0;

  // Ready for the real Firebase booking count later.
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

            _buildPlaceholder(
              icon: Icons.directions_car_outlined,
              title: 'Explore',
              subtitle: 'Discover your next ride.',
            ),

            // REAL CUSTOMER BOOKINGS
            const MyBookingsScreen(
              tenantId: _tenantId,
            ),

            // REAL CUSTOMER PROFILE
            const ProfileScreen(),
          ],
        ),
      ),

      // Bottom navigation remains controlled by HomeScreen.
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
