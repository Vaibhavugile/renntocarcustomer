import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/config/app_config.dart';
import '../../cars/screens/admin_cars_screen.dart';
import '../../branches/screens/admin_branches_screen.dart';
import '../../availability/screens/admin_availability_screen.dart';
import '../../customers/screens/admin_customers_screen.dart';
import '../../availability/screens/admin_new_booking_screen.dart';
import '../../booking/screens/admin_bookings_screen.dart';
import '../../pricing/screens/admin_pricing_profiles_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  static const Color background = Color(0xFFF8FAF9);
  static const Color card = Color(0xFFFFFFFF);
  static const Color primary = Color(0xFF0F766E);
  static const Color accent = Color(0xFF14B8A6);
  static const Color softAccent = Color(0xFFE6FFFB);
  static const Color heading = Color(0xFF17201F);
  static const Color body = Color(0xFF66706E);
  static const Color muted = Color(0xFF94A09D);
  static const Color border = Color(0xFFE5EBE9);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int _selectedIndex = 0;
  bool _loading = true;
  bool _refreshing = false;

  int _cars = 0;
  int _availableCars = 0;
  int _customers = 0;
  int _activeCustomers = 0;
  int _bookings = 0;
  int _activeBookings = 0;
  int _pendingBookings = 0;
  int _completedBookings = 0;
  int _pricingProfiles = 0;
  int _pendingPayments = 0;
  double _revenue = 0;
  List<Map<String, dynamic>> _recentBookings = [];

  String get tenantId {
    try {
      return AppConfig.tenant.tenantId.trim();
    } catch (_) {
      return '';
    }
  }

  String get businessName {
    try {
      final name = AppConfig.tenant.business.name.trim();
      if (name.isNotEmpty) return name;
      final appName = AppConfig.tenant.branding.appName.trim();
      if (appName.isNotEmpty) return appName;
    } catch (_) {}
    return 'Admin';
  }

  CollectionReference<Map<String, dynamic>> _collection(String name) =>
      _firestore.collection('tenants').doc(tenantId).collection(name);

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard({bool refresh = false}) async {
    if (tenantId.isEmpty) return;

    if (mounted) {
      setState(() {
        if (refresh) {
          _refreshing = true;
        } else {
          _loading = true;
        }
      });
    }

    try {
      final results = await Future.wait([
        _collection('cars').get(),
        _collection('customers').get(),
        _collection('bookings').get(),
        _collection('pricingProfiles').get(),
      ]);

      final carDocs = results[0].docs;
      final customerDocs = results[1].docs;
      final bookingDocs = results[2].docs;
      final pricingProfileDocs = results[3].docs;

      final activeCars = carDocs.where((d) {
        final m = d.data();
        return m['isActive'] != false &&
            m['status']?.toString().toLowerCase() != 'inactive';
      }).length;

      final activeCustomers = customerDocs.where((d) {
        return d.data()['isActive'] != false;
      }).length;

      int activeBookings = 0;
      int pendingBookings = 0;
      int completedBookings = 0;
      int pendingPayments = 0;
      double revenue = 0;

      final parsed = <Map<String, dynamic>>[];

      for (final doc in bookingDocs) {
        final m = doc.data();
        final status = (m['status'] ?? '').toString().toLowerCase();
        final paymentStatus =
            (m['paymentStatus'] ?? '').toString().toLowerCase();

        if (const {
          'active',
          'pickup_pending',
          'pickupPending',
          'return_pending',
          'returnPending',
        }.contains(status)) {
          activeBookings++;
        }

        if (const {'pending', 'payment_pending'}.contains(status) ||
            paymentStatus == 'pending') {
          pendingBookings++;
        }

        if (status == 'completed') {
          completedBookings++;
        }

        if (paymentStatus == 'pending' ||
            paymentStatus == 'partiallypaid' ||
            paymentStatus == 'partially_paid') {
          pendingPayments++;
        }

        final amount = _number(
          m['totalAmount'] ??
              m['total'] ??
              m['pricing']?['total'] ??
              0,
        );
        if (status == 'completed' || paymentStatus == 'paid') {
          revenue += amount;
        }

        parsed.add({
          'id': doc.id,
          ...m,
        });
      }

      parsed.sort((a, b) {
        final aDate = _dateValue(
          a['createdAt'] ?? a['pickupDateTime'] ?? a['pickupDate'],
        );
        final bDate = _dateValue(
          b['createdAt'] ?? b['pickupDateTime'] ?? b['pickupDate'],
        );
        return bDate.compareTo(aDate);
      });

      if (!mounted) return;

      setState(() {
        _cars = carDocs.length;
        _availableCars = activeCars;
        _customers = customerDocs.length;
        _activeCustomers = activeCustomers;
        _bookings = bookingDocs.length;
        _activeBookings = activeBookings;
        _pendingBookings = pendingBookings;
        _completedBookings = completedBookings;
        _pendingPayments = pendingPayments;
        _pricingProfiles = pricingProfileDocs
            .where((d) => d.data()['isActive'] != false)
            .length;
        _revenue = revenue;
        _recentBookings = parsed.take(6).toList();
        _loading = false;
        _refreshing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshing = false;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            backgroundColor: heading,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            content: Text(
              'Unable to load dashboard: ${_cleanError(e)}',
              style: GoogleFonts.manrope(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
    }
  }

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  DateTime _dateValue(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _cleanError(Object e) =>
      e.toString().replaceFirst('Exception: ', '');

  String _bookingCustomer(Map<String, dynamic> b) =>
      (b['customerName'] ?? b['customer']?['fullName'] ?? 'Customer')
          .toString()
          .trim();

  String _bookingCar(Map<String, dynamic> b) =>
      (b['carName'] ?? b['car']?['name'] ?? b['carId'] ?? 'Vehicle')
          .toString()
          .trim();

  String _bookingStatus(Map<String, dynamic> b) =>
      (b['status'] ?? 'pending').toString();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      drawer: _buildDrawer(),
      appBar: _buildAppBar(),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: primary),
            )
          : RefreshIndicator(
              color: primary,
              onRefresh: () => _loadDashboard(refresh: true),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                child: _buildDashboard(),
              ),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: Builder(
        builder: (context) => IconButton(
          tooltip: 'Open menu',
          onPressed: () => Scaffold.of(context).openDrawer(),
          icon: const Icon(Icons.menu_rounded, color: heading, size: 25),
        ),
      ),
      titleSpacing: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            businessName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: heading,
            ),
          ),
          Text(
            'Admin Panel',
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: muted,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: _refreshing ? null : () => _loadDashboard(refresh: true),
          icon: _refreshing
              ? const SizedBox(
                  width: 19,
                  height: 19,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: primary,
                  ),
                )
              : const Icon(Icons.refresh_rounded, color: heading),
        ),
        const SizedBox(width: 8),
        Container(
          width: 40,
          height: 40,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: softAccent,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: border),
          ),
          child: const Icon(
            Icons.person_outline_rounded,
            color: primary,
            size: 21,
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: border),
      ),
    );
  }

  Widget _buildDashboard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildWelcome(),
        const SizedBox(height: 24),
        _buildStats(),
        const SizedBox(height: 30),
        _buildSectionHeader(
          'Quick Management',
          'Run your rental operation from one place',
        ),
        const SizedBox(height: 14),
        _buildQuickActions(),
        const SizedBox(height: 30),
        _buildSectionHeader(
          'Recent Bookings',
          'Latest rental activity',
        ),
        const SizedBox(height: 14),
        _buildRecentBookings(),
        const SizedBox(height: 30),
        _buildOperationalSummary(),
        const SizedBox(height: 30),
        _buildTenantInfo(),
      ],
    );
  }

  Widget _buildWelcome() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Good afternoon 👋',
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: body,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Business overview',
          style: GoogleFonts.manrope(
            fontSize: 28,
            height: 1.15,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
            color: heading,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'Monitor your fleet, bookings, customers and payments from one place.',
          style: GoogleFonts.manrope(
            fontSize: 12.5,
            height: 1.45,
            fontWeight: FontWeight.w500,
            color: body,
          ),
        ),
      ],
    );
  }

  Widget _buildStats() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: width,
              child: _StatCard(
                title: 'Cars',
                value: '$_cars',
                subtitle: '$_availableCars available',
                icon: Icons.directions_car_rounded,
              ),
            ),
            SizedBox(
              width: width,
              child: _StatCard(
                title: 'Bookings',
                value: '$_bookings',
                subtitle: '$_activeBookings active',
                icon: Icons.calendar_month_rounded,
              ),
            ),
            SizedBox(
              width: width,
              child: _StatCard(
                title: 'Customers',
                value: '$_customers',
                subtitle: '$_activeCustomers active',
                icon: Icons.people_alt_rounded,
              ),
            ),
            SizedBox(
              width: width,
              child: _StatCard(
                title: 'Revenue',
                value: _formatCurrency(_revenue),
                subtitle: 'Completed / paid',
                icon: Icons.payments_rounded,
              ),
            ),
            SizedBox(
              width: width,
              child: _StatCard(
                title: 'Pricing Profiles',
                value: '$_pricingProfiles',
                subtitle: 'Active pricing setups',
                icon: Icons.price_change_rounded,
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatCurrency(double amount) {
    if (amount == amount.roundToDouble()) {
      return '₹${amount.toStringAsFixed(0)}';
    }
    return '₹${amount.toStringAsFixed(2)}';
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: heading,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: GoogleFonts.manrope(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: muted,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      children: [
        _QuickActionCard(
          icon: Icons.add_circle_outline_rounded,
          title: 'Create New Booking',
          subtitle: 'Create a walk-in or admin booking',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AdminNewBookingScreen(),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        _QuickActionCard(
          icon: Icons.calendar_month_rounded,
          title: 'Bookings',
          subtitle: 'View, confirm and manage all rentals',
          onTap: _openBookings,
        ),
        const SizedBox(height: 10),
        _QuickActionCard(
          icon: Icons.people_alt_outlined,
          title: 'Customers',
          subtitle: 'Manage customer profiles and KYC',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AdminCustomersScreen(),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        _QuickActionCard(
          icon: Icons.directions_car_rounded,
          title: 'Manage Cars',
          subtitle: 'Add, edit and manage your fleet',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AdminCarsScreen(),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        _QuickActionCard(
          icon: Icons.price_change_rounded,
          title: 'Pricing Profiles',
          subtitle: 'Create, edit and assign hourly/daily pricing packages',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AdminPricingProfilesScreen(),
              ),
            ).then((_) {
              if (mounted) _loadDashboard(refresh: true);
            });
          },
        ),
        const SizedBox(height: 10),
        _QuickActionCard(
          icon: Icons.storefront_rounded,
          title: 'Branches',
          subtitle: 'Manage pickup and return locations',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AdminBranchesScreen(),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        _QuickActionCard(
          icon: Icons.event_available_rounded,
          title: 'Availability',
          subtitle: 'Check vehicle availability by date',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AdminAvailabilityScreen(),
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _openBookings({bool closeDrawerFirst = false}) async {
    developer.log(
      'BOOKINGS CLICKED | tenant=$tenantId | closeDrawerFirst=$closeDrawerFirst',
      name: 'ADMIN_DASHBOARD',
    );

    if (closeDrawerFirst && mounted) {
      Navigator.of(context).pop();
      await Future<void>.delayed(const Duration(milliseconds: 180));
    }

    if (!mounted) return;

    developer.log(
      'PUSHING AdminBookingsScreen',
      name: 'ADMIN_DASHBOARD',
    );

    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) {
            developer.log(
              'BUILDING AdminBookingsScreen',
              name: 'ADMIN_DASHBOARD',
            );
            return const AdminBookingsScreen();
          },
        ),
      );

      developer.log(
        'RETURNED FROM AdminBookingsScreen',
        name: 'ADMIN_DASHBOARD',
      );

      if (!mounted) return;
      await _loadDashboard(refresh: true);
    } catch (e, stackTrace) {
      developer.log(
        'Bookings navigation failed',
        name: 'ADMIN_DASHBOARD',
        error: e,
        stackTrace: stackTrace,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            backgroundColor: heading,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            content: Text(
              'Unable to open bookings: ${_cleanError(e)}',
              style: GoogleFonts.manrope(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
    }
  }

  Widget _buildRecentBookings() {
    if (_recentBookings.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Column(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: softAccent,
                borderRadius: BorderRadius.circular(17),
              ),
              child: const Icon(
                Icons.calendar_today_outlined,
                color: primary,
                size: 24,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'No bookings yet',
              style: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: heading,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Create your first booking to start seeing rental activity here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: body,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _recentBookings.map((booking) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _openBookings(),
          child: _bookingCard(booking),
        );
      }).toList(),
    );
  }

  Widget _bookingCard(Map<String, dynamic> booking) {
    final status = _bookingStatus(booking);
    final statusText = status.replaceAll('_', ' ');
    final amount = _number(
      booking['totalAmount'] ??
          booking['total'] ??
          booking['pricing']?['total'] ??
          0,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: softAccent,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.directions_car_rounded,
              color: primary,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _bookingCustomer(booking),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: heading,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _bookingCar(booking),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: body,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatCurrency(amount),
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: heading,
                ),
              ),
              const SizedBox(height: 4),
              _statusChip(statusText),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    final normalized = status.toLowerCase();
    final isPositive = normalized == 'completed' ||
        normalized == 'confirmed' ||
        normalized == 'active';
    final isDanger =
        normalized.contains('cancel') || normalized.contains('reject');

    final color = isDanger
        ? const Color(0xFFDC2626)
        : isPositive
            ? primary
            : const Color(0xFFCA8A04);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.isEmpty ? 'pending' : status,
        style: GoogleFonts.manrope(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildOperationalSummary() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Operational overview',
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: heading,
            ),
          ),
          const SizedBox(height: 14),
          _summaryRow(
            Icons.pending_actions_rounded,
            'Pending bookings',
            '$_pendingBookings',
          ),
          _summaryRow(
            Icons.directions_car_filled_rounded,
            'Active rentals',
            '$_activeBookings',
          ),
          _summaryRow(
            Icons.check_circle_outline_rounded,
            'Completed bookings',
            '$_completedBookings',
          ),
          _summaryRow(
            Icons.account_balance_wallet_outlined,
            'Payments needing attention',
            '$_pendingPayments',
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: softAccent,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: primary, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.manrope(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: body,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: heading,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTenantInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: softAccent,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.business_rounded,
              color: primary,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  businessName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: heading,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  tenantId.isEmpty ? 'Tenant configuration' : 'Tenant: $tenantId',
                  style: GoogleFonts.manrope(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: body,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: card,
      child: SafeArea(
        child: Column(
          children: [
            _buildDrawerHeader(),
            const Divider(height: 1, color: border),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 20),
                children: [
                  _drawerItem(
                    icon: Icons.dashboard_rounded,
                    title: 'Dashboard',
                    selected: _selectedIndex == 0,
                    onTap: () => _selectDrawerItem(0),
                  ),
                  _drawerSection('FLEET'),
                  _drawerItem(
                    icon: Icons.directions_car_rounded,
                    title: 'Cars',
                    onTap: () => _push(const AdminCarsScreen()),
                  ),
                  _drawerItem(
                    icon: Icons.storefront_rounded,
                    title: 'Branches',
                    onTap: () => _push(const AdminBranchesScreen()),
                  ),
                  _drawerItem(
                    icon: Icons.event_available_rounded,
                    title: 'Availability',
                    onTap: () => _push(const AdminAvailabilityScreen()),
                  ),
                  _drawerSection('OPERATIONS'),
                  _drawerItem(
                    icon: Icons.add_circle_outline_rounded,
                    title: 'New Booking',
                    onTap: () => _push(const AdminNewBookingScreen()),
                  ),
                  _drawerItem(
                    icon: Icons.calendar_month_rounded,
                    title: 'Bookings',
                    onTap: () => _openBookings(closeDrawerFirst: true),
                  ),
                  _drawerItem(
                    icon: Icons.people_alt_outlined,
                    title: 'Customers',
                    onTap: () => _push(const AdminCustomersScreen()),
                  ),
                  _drawerItem(
                    icon: Icons.verified_user_outlined,
                    title: 'KYC',
                    onTap: () => _showComingSoon('KYC'),
                  ),
                  _drawerItem(
                    icon: Icons.payments_outlined,
                    title: 'Payments',
                    onTap: () => _showComingSoon('Payments'),
                  ),
                  _drawerItem(
                    icon: Icons.description_outlined,
                    title: 'Invoices',
                    onTap: () => _showComingSoon('Invoices'),
                  ),
                  _drawerSection('PRICING'),
                  _drawerItem(
                    icon: Icons.price_change_rounded,
                    title: 'Pricing Profiles',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminPricingProfilesScreen(),
                        ),
                      ).then((_) {
                        if (mounted) _loadDashboard(refresh: true);
                      });
                    },
                  ),
                  _drawerItem(
                    icon: Icons.speed_rounded,
                    title: 'KM Packages',
                    onTap: () => _showComingSoon('KM Packages'),
                  ),
                  _drawerItem(
                    icon: Icons.add_circle_outline_rounded,
                    title: 'Add-ons',
                    onTap: () => _showComingSoon('Add-ons'),
                  ),
                  _drawerItem(
                    icon: Icons.local_offer_outlined,
                    title: 'Coupons',
                    onTap: () => _showComingSoon('Coupons'),
                  ),
                  _drawerSection('ADMINISTRATION'),
                  _drawerItem(
                    icon: Icons.manage_accounts_outlined,
                    title: 'Users',
                    onTap: () => _showComingSoon('Users'),
                  ),
                  _drawerItem(
                    icon: Icons.admin_panel_settings_outlined,
                    title: 'Roles',
                    onTap: () => _showComingSoon('Roles'),
                  ),
                  _drawerItem(
                    icon: Icons.settings_outlined,
                    title: 'Settings',
                    onTap: () => _showComingSoon('Settings'),
                  ),
                  const SizedBox(height: 20),
                  _buildDrawerFooter(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _push(Widget page) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  Widget _buildDrawerHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: softAccent,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: border),
            ),
            child: const Icon(
              Icons.directions_car_filled_rounded,
              color: primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  businessName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: heading,
                  ),
                ),
                Text(
                  'ADMIN PANEL',
                  style: GoogleFonts.manrope(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerSection(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 20, 14, 7),
      child: Text(
        title,
        style: GoogleFonts.manrope(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.3,
          color: muted,
        ),
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool selected = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      decoration: BoxDecoration(
        color: selected ? softAccent : Colors.transparent,
        borderRadius: BorderRadius.circular(13),
      ),
      child: ListTile(
        dense: true,
        minLeadingWidth: 20,
        contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 1),
        leading: Icon(
          icon,
          size: 20,
          color: selected ? primary : body,
        ),
        title: Text(
          title,
          style: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? primary : heading,
          ),
        ),
        trailing: selected
            ? Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              )
            : null,
        onTap: onTap,
      ),
    );
  }

  Widget _buildDrawerFooter() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_user_outlined, size: 18, color: primary),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Secure admin access',
              style: GoogleFonts.manrope(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: body,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _selectDrawerItem(int index) {
    Navigator.pop(context);
    if (!mounted) return;
    setState(() => _selectedIndex = index);
  }

  void _showComingSoon(String feature) {
    Navigator.of(context).maybePop();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '$feature module will be connected next.',
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          backgroundColor: heading,
          behavior: SnackBarBehavior.floating,
          elevation: 0,
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFFE5EBE9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFE6FFFB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 19,
                  color: const Color(0xFF0F766E),
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.arrow_outward_rounded,
                size: 15,
                color: Color(0xFF94A09D),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 23,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF17201F),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF17201F),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.manrope(
              fontSize: 9.5,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF94A09D),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFFFFF),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE5EBE9)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFE6FFFB),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFF0F766E),
                  size: 22,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF17201F),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 10.5,
                        height: 1.3,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF66706E),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF94A09D),
                size: 21,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
