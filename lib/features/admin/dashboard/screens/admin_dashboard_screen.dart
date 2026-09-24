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
  const AdminDashboardScreen({
    super.key,
  });

  @override
  State<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState
    extends State<AdminDashboardScreen> {
  // ============================================================
  // PREMIUM PALETTE
  // ============================================================

  static const Color background =
      Color(0xFFF8FAF9);

  static const Color card =
      Color(0xFFFFFFFF);

  static const Color primary =
      Color(0xFF0F766E);

  static const Color accent =
      Color(0xFF14B8A6);

  static const Color softAccent =
      Color(0xFFE6FFFB);

  static const Color heading =
      Color(0xFF17201F);

  static const Color body =
      Color(0xFF66706E);

  static const Color muted =
      Color(0xFF94A09D);

  static const Color border =
      Color(0xFFE5EBE9);

  // ============================================================
  // FIRESTORE
  // ============================================================

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  // ============================================================
  // DASHBOARD STATE
  // ============================================================

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

  int _admins = 0;
  int _activeAdmins = 0;

  double _revenue = 0;

  List<Map<String, dynamic>> _recentBookings =
      <Map<String, dynamic>>[];

  // ============================================================
  // TENANT
  // ============================================================

  String get tenantId {
    try {
      return AppConfig.tenant.tenantId.trim();
    } catch (_) {
      return '';
    }
  }

  String get businessName {
    try {
      final name =
          AppConfig.tenant.business.name.trim();

      if (name.isNotEmpty) {
        return name;
      }

      final appName =
          AppConfig.tenant.branding.appName.trim();

      if (appName.isNotEmpty) {
        return appName;
      }
    } catch (_) {}

    return 'Admin';
  }

  // ============================================================
  // TENANT COLLECTION
  // ============================================================

  CollectionReference<Map<String, dynamic>>
      _collection(String name) {
    return _firestore
        .collection('tenants')
        .doc(tenantId)
        .collection(name);
  }

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _loadDashboard();
  }

  // ============================================================
  // LOAD DASHBOARD
  // ============================================================

  Future<void> _loadDashboard({
    bool refresh = false,
  }) async {
    if (tenantId.isEmpty) {
      return;
    }

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
        _collection('admins').get(),
      ]);

      final carDocs =
          results[0].docs;

      final customerDocs =
          results[1].docs;

      final bookingDocs =
          results[2].docs;

      final pricingProfileDocs =
          results[3].docs;

      final adminDocs =
          results[4].docs;

      // ========================================================
      // CARS
      // ========================================================

      final activeCars =
          carDocs.where((doc) {
        final data = doc.data();

        return data['isActive'] != false &&
            data['status']
                    ?.toString()
                    .toLowerCase() !=
                'inactive';
      }).length;

      // ========================================================
      // CUSTOMERS
      // ========================================================

      final activeCustomers =
          customerDocs.where((doc) {
        return doc.data()['isActive'] != false;
      }).length;

      // ========================================================
      // ADMINS
      // ========================================================

      final activeAdmins =
          adminDocs.where((doc) {
        return doc.data()['isActive'] == true;
      }).length;

      // ========================================================
      // BOOKINGS
      // ========================================================

      int activeBookings = 0;
      int pendingBookings = 0;
      int completedBookings = 0;
      int pendingPayments = 0;

      double revenue = 0;

      final parsed =
          <Map<String, dynamic>>[];

      for (final doc in bookingDocs) {
        final data = doc.data();

        final status =
            (data['status'] ?? '')
                .toString()
                .toLowerCase();

        final paymentStatus =
            (data['paymentStatus'] ?? '')
                .toString()
                .toLowerCase();

        if (const {
          'active',
          'pickup_pending',
          'pickuppending',
          'return_pending',
          'returnpending',
        }.contains(status)) {
          activeBookings++;
        }

        if (const {
              'pending',
              'payment_pending',
            }.contains(status) ||
            paymentStatus == 'pending') {
          pendingBookings++;
        }

        if (status == 'completed') {
          completedBookings++;
        }

        if (paymentStatus == 'pending' ||
            paymentStatus == 'partiallypaid' ||
            paymentStatus == 'partially_paid' ||
            paymentStatus == 'partiallyrefunded') {
          pendingPayments++;
        }

        final amount = _number(
          data['totalAmount'] ??
              data['total'] ??
              data['pricing']?['total'] ??
              0,
        );

        if (status == 'completed' ||
            paymentStatus == 'paid') {
          revenue += amount;
        }

        parsed.add({
          'id': doc.id,
          ...data,
        });
      }

      // ========================================================
      // SORT RECENT BOOKINGS
      // ========================================================

      parsed.sort((a, b) {
        final aDate = _dateValue(
          a['createdAt'] ??
              a['pickupDateTime'] ??
              a['pickupDate'],
        );

        final bDate = _dateValue(
          b['createdAt'] ??
              b['pickupDateTime'] ??
              b['pickupDate'],
        );

        return bDate.compareTo(aDate);
      });

      // ========================================================
      // UPDATE STATE
      // ========================================================

      if (!mounted) {
        return;
      }

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

        _pricingProfiles =
            pricingProfileDocs
                .where(
                  (doc) =>
                      doc.data()['isActive'] != false,
                )
                .length;

        _admins = adminDocs.length;
        _activeAdmins = activeAdmins;

        _revenue = revenue;

        _recentBookings =
            parsed.take(6).toList();

        _loading = false;
        _refreshing = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _refreshing = false;
      });

      _showError(
        'Unable to load dashboard: '
        '${_cleanError(error)}',
      );
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  double _number(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  DateTime _dateValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return DateTime.tryParse(
          value?.toString() ?? '',
        ) ??
        DateTime.fromMillisecondsSinceEpoch(
          0,
        );
  }

  String _cleanError(Object error) {
    return error
        .toString()
        .replaceFirst(
          'Exception: ',
          '',
        );
  }

  String _bookingCustomer(
    Map<String, dynamic> booking,
  ) {
    return (
      booking['customerName'] ??
      booking['customer']?['fullName'] ??
      'Customer'
    )
        .toString()
        .trim();
  }

  String _bookingCar(
    Map<String, dynamic> booking,
  ) {
    return (
      booking['carName'] ??
      booking['car']?['name'] ??
      booking['carId'] ??
      'Vehicle'
    )
        .toString()
        .trim();
  }

  String _bookingStatus(
    Map<String, dynamic> booking,
  ) {
    return (
      booking['status'] ??
      'pending'
    ).toString();
  }

  String _formatCurrency(
    double amount,
  ) {
    if (amount == amount.roundToDouble()) {
      return '₹${amount.toStringAsFixed(0)}';
    }

    return '₹${amount.toStringAsFixed(2)}';
  }

  // ============================================================
  // ERROR
  // ============================================================

  void _showError(
    String message,
  ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: heading,
          behavior:
              SnackBarBehavior.floating,
          margin:
              const EdgeInsets.fromLTRB(
            20,
            0,
            20,
            20,
          ),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(14),
          ),
          content: Text(
            message,
            style: GoogleFonts.manrope(
              color: Colors.white,
              fontSize: 12,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ),
      );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor: background,

      drawer: _buildDrawer(),

      appBar: _buildAppBar(),

      body: _loading
          ? const Center(
              child:
                  CircularProgressIndicator(
                color: primary,
              ),
            )
          : RefreshIndicator(
              color: primary,
              onRefresh: () =>
                  _loadDashboard(
                refresh: true,
              ),
              child:
                  SingleChildScrollView(
                physics:
                    const AlwaysScrollableScrollPhysics(
                  parent:
                      BouncingScrollPhysics(),
                ),
                padding:
                    const EdgeInsets.fromLTRB(
                  20,
                  24,
                  20,
                  32,
                ),
                child:
                    _buildDashboard(),
              ),
            ),
    );
  }

  // ============================================================
  // APP BAR
  // ============================================================

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: card,
      surfaceTintColor:
          Colors.transparent,
      elevation: 0,

      leading: Builder(
        builder: (context) {
          return IconButton(
            tooltip: 'Open menu',
            onPressed: () =>
                Scaffold.of(context)
                    .openDrawer(),
            icon: const Icon(
              Icons.menu_rounded,
              color: heading,
              size: 25,
            ),
          );
        },
      ),

      titleSpacing: 0,

      title: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            businessName,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style:
                GoogleFonts.manrope(
              fontSize: 16,
              fontWeight:
                  FontWeight.w800,
              color: heading,
            ),
          ),
          Text(
            'Admin Panel',
            style:
                GoogleFonts.manrope(
              fontSize: 10,
              fontWeight:
                  FontWeight.w600,
              color: muted,
            ),
          ),
        ],
      ),

      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: _refreshing
              ? null
              : () =>
                  _loadDashboard(
                    refresh: true,
                  ),
          icon: _refreshing
              ? const SizedBox(
                  width: 19,
                  height: 19,
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2,
                    color: primary,
                  ),
                )
              : const Icon(
                  Icons.refresh_rounded,
                  color: heading,
                ),
        ),

        const SizedBox(width: 8),

        Container(
          width: 40,
          height: 40,
          margin:
              const EdgeInsets.only(
            right: 12,
          ),
          decoration:
              BoxDecoration(
            color: softAccent,
            borderRadius:
                BorderRadius.circular(
              13,
            ),
            border:
                Border.all(
              color: border,
            ),
          ),
          child: const Icon(
            Icons.person_outline_rounded,
            color: primary,
            size: 21,
          ),
        ),
      ],

      bottom: PreferredSize(
        preferredSize:
            const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: border,
        ),
      ),
    );
  }

  // ============================================================
  // DASHBOARD
  // ============================================================

  Widget _buildDashboard() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        _buildWelcome(),

        const SizedBox(
          height: 24,
        ),

        _buildStats(),

        const SizedBox(
          height: 30,
        ),

        _buildSectionHeader(
          'Quick Management',
          'Run your rental operation from one place',
        ),

        const SizedBox(
          height: 14,
        ),

        _buildQuickActions(),

        const SizedBox(
          height: 30,
        ),

        _buildSectionHeader(
          'Recent Bookings',
          'Latest rental activity',
        ),

        const SizedBox(
          height: 14,
        ),

        _buildRecentBookings(),

        const SizedBox(
          height: 30,
        ),

        _buildOperationalSummary(),

        const SizedBox(
          height: 30,
        ),

        _buildTenantInfo(),
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
        Text(
          'Good afternoon 👋',
          style:
              GoogleFonts.manrope(
            fontSize: 13,
            fontWeight:
                FontWeight.w600,
            color: body,
          ),
        ),

        const SizedBox(height: 5),

        Text(
          'Business overview',
          style:
              GoogleFonts.manrope(
            fontSize: 28,
            height: 1.15,
            fontWeight:
                FontWeight.w900,
            letterSpacing: -0.8,
            color: heading,
          ),
        ),

        const SizedBox(height: 7),

        Text(
          'Monitor your fleet, bookings, customers, '
          'payments and administrators from one place.',
          style:
              GoogleFonts.manrope(
            fontSize: 12.5,
            height: 1.45,
            fontWeight:
                FontWeight.w500,
            color: body,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // STATS
  // ============================================================

  Widget _buildStats() {
    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final width =
            (constraints.maxWidth - 12) /
                2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: width,
              child: _StatCard(
                title: 'Cars',
                value: '$_cars',
                subtitle:
                    '$_availableCars available',
                icon:
                    Icons.directions_car_rounded,
                onTap: () {
                  _push(
                    const AdminCarsScreen(),
                  );
                },
              ),
            ),

            SizedBox(
              width: width,
              child: _StatCard(
                title: 'Bookings',
                value: '$_bookings',
                subtitle:
                    '$_activeBookings active',
                icon:
                    Icons.calendar_month_rounded,
                onTap:
                    _openBookings,
              ),
            ),

            SizedBox(
              width: width,
              child: _StatCard(
                title: 'Customers',
                value: '$_customers',
                subtitle:
                    '$_activeCustomers active',
                icon:
                    Icons.people_alt_rounded,
                onTap: () {
                  _push(
                    const AdminCustomersScreen(),
                  );
                },
              ),
            ),

            SizedBox(
              width: width,
              child: _StatCard(
                title: 'Revenue',
                value:
                    _formatCurrency(
                  _revenue,
                ),
                subtitle:
                    'Completed / paid',
                icon:
                    Icons.payments_rounded,
                onTap: () {
                  _showComingSoon(
                    'Payments Report',
                  );
                },
              ),
            ),

            SizedBox(
              width: width,
              child: _StatCard(
                title: 'Pricing Profiles',
                value:
                    '$_pricingProfiles',
                subtitle:
                    'Active pricing setups',
                icon:
                    Icons.price_change_rounded,
                onTap: () {
                  _push(
                    const AdminPricingProfilesScreen(),
                  );
                },
              ),
            ),

            SizedBox(
              width: width,
              child: _StatCard(
                title: 'Admins',
                value: '$_admins',
                subtitle:
                    '$_activeAdmins active',
                icon:
                    Icons.admin_panel_settings_rounded,
                onTap:
                    _openAdmins,
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // SECTION HEADER
  // ============================================================

  Widget _buildSectionHeader(
    String title,
    String subtitle,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style:
              GoogleFonts.manrope(
            fontSize: 18,
            fontWeight:
                FontWeight.w800,
            color: heading,
          ),
        ),

        const SizedBox(height: 3),

        Text(
          subtitle,
          style:
              GoogleFonts.manrope(
            fontSize: 11.5,
            fontWeight:
                FontWeight.w500,
            color: muted,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // QUICK ACTIONS
  // ============================================================

  Widget _buildQuickActions() {
    return Column(
      children: [
        _QuickActionCard(
          icon:
              Icons.add_circle_outline_rounded,
          title:
              'Create New Booking',
          subtitle:
              'Create a walk-in or admin booking',
          onTap: () {
            _push(
              const AdminNewBookingScreen(),
            );
          },
        ),

        const SizedBox(height: 10),

        _QuickActionCard(
          icon:
              Icons.calendar_month_rounded,
          title: 'Bookings',
          subtitle:
              'View, confirm and manage all rentals',
          onTap:
              _openBookings,
        ),

        const SizedBox(height: 10),

        _QuickActionCard(
          icon:
              Icons.people_alt_outlined,
          title: 'Customers',
          subtitle:
              'Manage customer profiles and KYC',
          onTap: () {
            _push(
              const AdminCustomersScreen(),
            );
          },
        ),

        const SizedBox(height: 10),

        _QuickActionCard(
          icon:
              Icons.directions_car_rounded,
          title: 'Manage Cars',
          subtitle:
              'Add, edit and manage your fleet',
          onTap: () {
            _push(
              const AdminCarsScreen(),
            );
          },
        ),

        const SizedBox(height: 10),

        _QuickActionCard(
          icon:
              Icons.admin_panel_settings_outlined,
          title: 'Administrators',
          subtitle:
              'Add, edit and manage admin access',
          onTap:
              _openAdmins,
        ),

        const SizedBox(height: 10),

        _QuickActionCard(
          icon:
              Icons.price_change_rounded,
          title:
              'Pricing Profiles',
          subtitle:
              'Create, edit and assign hourly/daily pricing packages',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const AdminPricingProfilesScreen(),
              ),
            ).then((_) {
              if (mounted) {
                _loadDashboard(
                  refresh: true,
                );
              }
            });
          },
        ),

        const SizedBox(height: 10),

        _QuickActionCard(
          icon:
              Icons.storefront_rounded,
          title: 'Branches',
          subtitle:
              'Manage pickup and return locations',
          onTap: () {
            _push(
              const AdminBranchesScreen(),
            );
          },
        ),

        const SizedBox(height: 10),

        _QuickActionCard(
          icon:
              Icons.event_available_rounded,
          title: 'Availability',
          subtitle:
              'Check vehicle availability by date',
          onTap: () {
            _push(
              const AdminAvailabilityScreen(),
            );
          },
        ),
      ],
    );
  }

  // ============================================================
  // BOOKINGS
  // ============================================================

  Future<void> _openBookings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            const AdminBookingsScreen(),
      ),
    );

    if (!mounted) {
      return;
    }

    await _loadDashboard(
      refresh: true,
    );
  }

  // ============================================================
  // ADMINS
  // ============================================================

  Future<void> _openAdmins() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            const AdminManagementScreen(),
      ),
    );

    if (!mounted) {
      return;
    }

    await _loadDashboard(
      refresh: true,
    );
  }

  // ============================================================
  // RECENT BOOKINGS
  // ============================================================

  Widget _buildRecentBookings() {
    if (_recentBookings.isEmpty) {
      return Container(
        width: double.infinity,
        padding:
            const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: card,
          borderRadius:
              BorderRadius.circular(20),
          border:
              Border.all(color: border),
        ),
        child: Column(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration:
                  BoxDecoration(
                color: softAccent,
                borderRadius:
                    BorderRadius.circular(
                  17,
                ),
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
              style:
                  GoogleFonts.manrope(
                fontSize: 15,
                fontWeight:
                    FontWeight.w800,
                color: heading,
              ),
            ),

            const SizedBox(height: 5),

            Text(
              'Create your first booking to start seeing rental activity here.',
              textAlign:
                  TextAlign.center,
              style:
                  GoogleFonts.manrope(
                fontSize: 11.5,
                fontWeight:
                    FontWeight.w500,
                color: body,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children:
          _recentBookings.map(
        (booking) {
          return GestureDetector(
            behavior:
                HitTestBehavior.opaque,
            onTap:
                _openBookings,
            child:
                _bookingCard(booking),
          );
        },
      ).toList(),
    );
  }

  Widget _bookingCard(
    Map<String, dynamic> booking,
  ) {
    final status =
        _bookingStatus(booking);

    final statusText =
        status.replaceAll(
      '_',
      ' ',
    );

    final amount = _number(
      booking['totalAmount'] ??
          booking['total'] ??
          booking['pricing']?['total'] ??
          0,
    );

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      padding:
          const EdgeInsets.all(14),
      decoration:
          BoxDecoration(
        color: card,
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        border:
            Border.all(
          color: border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration:
                BoxDecoration(
              color: softAccent,
              borderRadius:
                  BorderRadius.circular(
                13,
              ),
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
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  _bookingCustomer(
                    booking,
                  ),
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      GoogleFonts.manrope(
                    fontSize: 12.5,
                    fontWeight:
                        FontWeight.w800,
                    color: heading,
                  ),
                ),

                const SizedBox(
                  height: 3,
                ),

                Text(
                  _bookingCar(
                    booking,
                  ),
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      GoogleFonts.manrope(
                    fontSize: 10.5,
                    fontWeight:
                        FontWeight.w600,
                    color: body,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          Column(
            crossAxisAlignment:
                CrossAxisAlignment.end,
            children: [
              Text(
                _formatCurrency(
                  amount,
                ),
                style:
                    GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight:
                      FontWeight.w800,
                  color: heading,
                ),
              ),

              const SizedBox(
                height: 4,
              ),

              _statusChip(
                statusText,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusChip(
    String status,
  ) {
    final normalized =
        status.toLowerCase();

    final isPositive =
        normalized ==
                'completed' ||
            normalized ==
                'confirmed' ||
            normalized ==
                'active';

    final isDanger =
        normalized.contains(
              'cancel',
            ) ||
            normalized.contains(
              'reject',
            );

    final color = isDanger
        ? const Color(
            0xFFDC2626,
          )
        : isPositive
            ? primary
            : const Color(
                0xFFCA8A04,
              );

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration:
          BoxDecoration(
        color:
            color.withValues(
          alpha: 0.08,
        ),
        borderRadius:
            BorderRadius.circular(
          20,
        ),
      ),
      child: Text(
        status.isEmpty
            ? 'pending'
            : status,
        style:
            GoogleFonts.manrope(
          color: color,
          fontSize: 9,
          fontWeight:
              FontWeight.w800,
        ),
      ),
    );
  }

  // ============================================================
  // OPERATIONAL SUMMARY
  // ============================================================

  Widget _buildOperationalSummary() {
    return Container(
      padding:
          const EdgeInsets.all(17),
      decoration:
          BoxDecoration(
        color: card,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        border:
            Border.all(
          color: border,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            'Operational overview',
            style:
                GoogleFonts.manrope(
              fontSize: 14,
              fontWeight:
                  FontWeight.w800,
              color: heading,
            ),
          ),

          const SizedBox(
            height: 14,
          ),

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

          _summaryRow(
            Icons.admin_panel_settings_outlined,
            'Active administrators',
            '$_activeAdmins',
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(
    IconData icon,
    String title,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 12,
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration:
                BoxDecoration(
              color: softAccent,
              borderRadius:
                  BorderRadius.circular(
                11,
              ),
            ),
            child: Icon(
              icon,
              color: primary,
              size: 17,
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              title,
              style:
                  GoogleFonts.manrope(
                fontSize: 11.5,
                fontWeight:
                    FontWeight.w600,
                color: body,
              ),
            ),
          ),

          Text(
            value,
            style:
                GoogleFonts.manrope(
              fontSize: 13,
              fontWeight:
                  FontWeight.w800,
              color: heading,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TENANT INFO
  // ============================================================

  Widget _buildTenantInfo() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(18),
      decoration:
          BoxDecoration(
        color: softAccent,
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        border:
            Border.all(
          color: border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration:
                BoxDecoration(
              color: card,
              borderRadius:
                  BorderRadius.circular(
                13,
              ),
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
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  businessName,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w800,
                    color: heading,
                  ),
                ),

                const SizedBox(
                  height: 3,
                ),

                Text(
                  tenantId.isEmpty
                      ? 'Tenant configuration'
                      : 'Tenant: $tenantId',
                  style:
                      GoogleFonts.manrope(
                    fontSize: 10.5,
                    fontWeight:
                        FontWeight.w600,
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

  // ============================================================
  // DRAWER
  // ============================================================

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: card,
      child: SafeArea(
        child: Column(
          children: [
            _buildDrawerHeader(),

            const Divider(
              height: 1,
              color: border,
            ),

            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.fromLTRB(
                  12,
                  14,
                  12,
                  20,
                ),
                children: [
                  _drawerItem(
                    icon:
                        Icons.dashboard_rounded,
                    title:
                        'Dashboard',
                    selected:
                        _selectedIndex == 0,
                    onTap:
                        () =>
                            _selectDrawerItem(
                      0,
                    ),
                  ),

                  _drawerSection(
                    'FLEET',
                  ),

                  _drawerItem(
                    icon:
                        Icons.directions_car_rounded,
                    title:
                        'Cars',
                    onTap: () =>
                        _push(
                      const AdminCarsScreen(),
                    ),
                  ),

                  _drawerItem(
                    icon:
                        Icons.storefront_rounded,
                    title:
                        'Branches',
                    onTap: () =>
                        _push(
                      const AdminBranchesScreen(),
                    ),
                  ),

                  _drawerItem(
                    icon:
                        Icons.event_available_rounded,
                    title:
                        'Availability',
                    onTap: () =>
                        _push(
                      const AdminAvailabilityScreen(),
                    ),
                  ),

                  _drawerSection(
                    'OPERATIONS',
                  ),

                  _drawerItem(
                    icon:
                        Icons.add_circle_outline_rounded,
                    title:
                        'New Booking',
                    onTap: () =>
                        _push(
                      const AdminNewBookingScreen(),
                    ),
                  ),

                  _drawerItem(
                    icon:
                        Icons.calendar_month_rounded,
                    title:
                        'Bookings',
                    onTap: () {
                      Navigator.pop(
                        context,
                      );

                      _openBookings();
                    },
                  ),

                  _drawerItem(
                    icon:
                        Icons.people_alt_outlined,
                    title:
                        'Customers',
                    onTap: () =>
                        _push(
                      const AdminCustomersScreen(),
                    ),
                  ),

                  _drawerItem(
                    icon:
                        Icons.verified_user_outlined,
                    title:
                        'KYC',
                    onTap: () =>
                        _showComingSoon(
                      'KYC',
                    ),
                  ),

                  _drawerItem(
                    icon:
                        Icons.payments_outlined,
                    title:
                        'Payments',
                    onTap: () =>
                        _showComingSoon(
                      'Payments',
                    ),
                  ),

                  _drawerItem(
                    icon:
                        Icons.description_outlined,
                    title:
                        'Invoices',
                    onTap: () =>
                        _showComingSoon(
                      'Invoices',
                    ),
                  ),

                  _drawerSection(
                    'PRICING',
                  ),

                  _drawerItem(
                    icon:
                        Icons.price_change_rounded,
                    title:
                        'Pricing Profiles',
                    onTap: () {
                      Navigator.pop(
                        context,
                      );

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const AdminPricingProfilesScreen(),
                        ),
                      ).then((_) {
                        if (mounted) {
                          _loadDashboard(
                            refresh: true,
                          );
                        }
                      });
                    },
                  ),

                  _drawerItem(
                    icon:
                        Icons.speed_rounded,
                    title:
                        'KM Packages',
                    onTap: () =>
                        _showComingSoon(
                      'KM Packages',
                    ),
                  ),

                  _drawerItem(
                    icon:
                        Icons.add_circle_outline_rounded,
                    title:
                        'Add-ons',
                    onTap: () =>
                        _showComingSoon(
                      'Add-ons',
                    ),
                  ),

                  _drawerItem(
                    icon:
                        Icons.local_offer_outlined,
                    title:
                        'Coupons',
                    onTap: () =>
                        _showComingSoon(
                      'Coupons',
                    ),
                  ),

                  // ==================================================
                  // ADMINISTRATION
                  // ==================================================

                  _drawerSection(
                    'ADMINISTRATION',
                  ),

                  _drawerItem(
                    icon:
                        Icons.admin_panel_settings_outlined,
                    title:
                        'Administrators',
                    onTap:
                        _openAdmins,
                  ),

                  _drawerItem(
                    icon:
                        Icons.manage_accounts_outlined,
                    title:
                        'Users',
                    onTap: () =>
                        _showComingSoon(
                      'Users',
                    ),
                  ),

                  _drawerItem(
                    icon:
                        Icons.admin_panel_settings_outlined,
                    title:
                        'Roles',
                    onTap: () =>
                        _showComingSoon(
                      'Roles',
                    ),
                  ),

                  _drawerItem(
                    icon:
                        Icons.settings_outlined,
                    title:
                        'Settings',
                    onTap: () =>
                        _showComingSoon(
                      'Settings',
                    ),
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  _buildDrawerFooter(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DRAWER HEADER
  // ============================================================

  Widget _buildDrawerHeader() {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        20,
        20,
        20,
        18,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration:
                BoxDecoration(
              color: softAccent,
              borderRadius:
                  BorderRadius.circular(
                15,
              ),
              border:
                  Border.all(
                color: border,
              ),
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
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  businessName,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.w900,
                    color: heading,
                  ),
                ),

                Text(
                  'ADMIN PANEL',
                  style:
                      GoogleFonts.manrope(
                    fontSize: 9,
                    fontWeight:
                        FontWeight.w800,
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

  // ============================================================
  // DRAWER SECTION
  // ============================================================

  Widget _drawerSection(
    String title,
  ) {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        14,
        20,
        14,
        7,
      ),
      child: Text(
        title,
        style:
            GoogleFonts.manrope(
          fontSize: 9,
          fontWeight:
              FontWeight.w900,
          letterSpacing: 1.3,
          color: muted,
        ),
      ),
    );
  }

  // ============================================================
  // DRAWER ITEM
  // ============================================================

  Widget _drawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool selected = false,
  }) {
    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 3,
      ),
      decoration:
          BoxDecoration(
        color: selected
            ? softAccent
            : Colors.transparent,
        borderRadius:
            BorderRadius.circular(
          13,
        ),
      ),
      child: ListTile(
        dense: true,
        minLeadingWidth: 20,
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 1,
        ),
        leading: Icon(
          icon,
          size: 20,
          color:
              selected
                  ? primary
                  : body,
        ),
        title: Text(
          title,
          style:
              GoogleFonts.manrope(
            fontSize: 12,
            fontWeight:
                selected
                    ? FontWeight.w800
                    : FontWeight.w600,
            color:
                selected
                    ? primary
                    : heading,
          ),
        ),
        trailing: selected
            ? Container(
                width: 5,
                height: 5,
                decoration:
                    const BoxDecoration(
                  color: accent,
                  shape:
                      BoxShape.circle,
                ),
              )
            : null,
        onTap: onTap,
      ),
    );
  }

  // ============================================================
  // DRAWER FOOTER
  // ============================================================

  Widget _buildDrawerFooter() {
    return Container(
      padding:
          const EdgeInsets.all(14),
      decoration:
          BoxDecoration(
        color: background,
        borderRadius:
            BorderRadius.circular(
          15,
        ),
        border:
            Border.all(
          color: border,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.verified_user_outlined,
            size: 18,
            color: primary,
          ),

          const SizedBox(width: 9),

          Expanded(
            child: Text(
              'Secure admin access',
              style:
                  GoogleFonts.manrope(
                fontSize: 10.5,
                fontWeight:
                    FontWeight.w700,
                color: body,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PUSH
  // ============================================================

  void _push(
    Widget page,
  ) {
    Navigator.pop(context);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => page,
      ),
    );
  }

  // ============================================================
  // SELECT DRAWER
  // ============================================================

  void _selectDrawerItem(
    int index,
  ) {
    Navigator.pop(context);

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  // ============================================================
  // COMING SOON
  // ============================================================

  void _showComingSoon(
    String feature,
  ) {
    Navigator.of(context)
        .maybePop();

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '$feature module will be connected next.',
            style:
                GoogleFonts.manrope(
              fontSize: 12,
              fontWeight:
                  FontWeight.w600,
              color: Colors.white,
            ),
          ),
          backgroundColor:
              heading,
          behavior:
              SnackBarBehavior.floating,
          elevation: 0,
          margin:
              const EdgeInsets.fromLTRB(
            20,
            0,
            20,
            20,
          ),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              14,
            ),
          ),
        ),
      );
  }
}

// ============================================================================
// ADMIN MANAGEMENT SCREEN
// ============================================================================

class AdminManagementScreen
    extends StatefulWidget {
  const AdminManagementScreen({
    super.key,
  });

  @override
  State<AdminManagementScreen>
      createState() =>
          _AdminManagementScreenState();
}

class _AdminManagementScreenState
    extends State<AdminManagementScreen> {
  static const Color background =
      Color(0xFFF8FAF9);

  static const Color card =
      Color(0xFFFFFFFF);

  static const Color primary =
      Color(0xFF0F766E);

  static const Color accent =
      Color(0xFF14B8A6);

  static const Color softAccent =
      Color(0xFFE6FFFB);

  static const Color heading =
      Color(0xFF17201F);

  static const Color body =
      Color(0xFF66706E);

  static const Color muted =
      Color(0xFF94A09D);

  static const Color border =
      Color(0xFFE5EBE9);

  final FirebaseFirestore
      _firestore =
      FirebaseFirestore.instance;

  bool _loading = true;

  bool _saving = false;

  List<Map<String, dynamic>>
      _admins =
      <Map<String, dynamic>>[];

  String get tenantId {
    try {
      return AppConfig.tenant
          .tenantId
          .trim();
    } catch (_) {
      return '';
    }
  }

  CollectionReference<
      Map<String, dynamic>>
      get _adminsCollection {
    return _firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('admins');
  }

  CollectionReference<
      Map<String, dynamic>>
      get _customersCollection {
    return _firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('customers');
  }

  @override
  void initState() {
    super.initState();

    _loadAdmins();
  }

  // ============================================================
  // LOAD ADMINS
  // ============================================================

  Future<void> _loadAdmins() async {
    if (tenantId.isEmpty) {
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final snapshot =
          await _adminsCollection
              .orderBy(
                'createdAt',
                descending: true,
              )
              .get();

      final admins =
          snapshot.docs.map(
        (doc) {
          return {
            'id': doc.id,
            ...doc.data(),
          };
        },
      ).toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _admins = admins;
        _loading = false;
      });
    } catch (_) {
      /*
       * Fallback without orderBy.
       *
       * This also prevents the screen from breaking
       * if the createdAt index is not available yet.
       */

      try {
        final snapshot =
            await _adminsCollection.get();

        final admins =
            snapshot.docs.map(
          (doc) {
            return {
              'id': doc.id,
              ...doc.data(),
            };
          },
        ).toList();

        if (!mounted) {
          return;
        }

        setState(() {
          _admins = admins;
          _loading = false;
        });
      } catch (error) {
        if (!mounted) {
          return;
        }

        setState(() {
          _loading = false;
        });

        _showError(
          'Unable to load administrators.',
        );
      }
    }
  }

  // ============================================================
  // ADD ADMIN
  // ============================================================

  Future<void> _addAdmin() async {
    if (_saving) {
      return;
    }

    final customer =
        await showDialog<
            Map<String, dynamic>?>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _SelectCustomerDialog(
        customersCollection:
            _customersCollection,
      ),
    );

    if (customer == null) {
      return;
    }

    final customerId =
        customer['id']
            ?.toString()
            .trim();

    if (customerId == null ||
        customerId.isEmpty) {
      return;
    }

    final existing =
        await _adminsCollection
            .doc(customerId)
            .get();

    if (existing.exists) {
      _showError(
        'This customer is already an administrator.',
      );

      return;
    }

    final result =
        await showDialog<
            _AdminFormResult?>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _AdminFormDialog(
        title: 'Add Administrator',
        customer: customer,
        initialRole:
            'manager',
        initialActive:
            true,
      ),
    );

    if (result == null) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await _adminsCollection
          .doc(customerId)
          .set({
        'tenantId': tenantId,

        'uid': customerId,

        'customerId': customerId,

        'fullName':
            customer['fullName']
                    ?.toString() ??
                '',

        'phone':
            customer['phone']
                    ?.toString() ??
                '',

        'email':
            customer['email']
                    ?.toString() ??
                '',

        'roleId':
            result.roleId,

        'isActive':
            result.isActive,

        'createdAt':
            FieldValue.serverTimestamp(),

        'updatedAt':
            FieldValue.serverTimestamp(),
      });

      if (!mounted) {
        return;
      }

      _showSuccess(
        'Administrator added successfully.',
      );

      await _loadAdmins();
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showError(
        'Unable to add administrator: '
        '${error.toString()}',
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  // ============================================================
  // EDIT ADMIN
  // ============================================================

  Future<void> _editAdmin(
    Map<String, dynamic> admin,
  ) async {
    final result =
        await showDialog<
            _AdminFormResult?>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _AdminFormDialog(
        title:
            'Edit Administrator',
        customer: admin,
        initialRole:
            admin['roleId']
                    ?.toString() ??
                'manager',
        initialActive:
            admin['isActive'] == true,
      ),
    );

    if (result == null) {
      return;
    }

    final adminId =
        admin['id']
            ?.toString();

    if (adminId == null ||
        adminId.isEmpty) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await _adminsCollection
          .doc(adminId)
          .update({
        'roleId':
            result.roleId,

        'isActive':
            result.isActive,

        'updatedAt':
            FieldValue.serverTimestamp(),
      });

      if (!mounted) {
        return;
      }

      _showSuccess(
        'Administrator updated successfully.',
      );

      await _loadAdmins();
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showError(
        'Unable to update administrator.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  // ============================================================
  // REMOVE ADMIN
  // ============================================================

  Future<void> _removeAdmin(
    Map<String, dynamic> admin,
  ) async {
    final name =
        admin['fullName']
                ?.toString()
                .trim()
                .isNotEmpty ==
            true
            ? admin['fullName']
                .toString()
            : 'this administrator';

    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (_) =>
          AlertDialog(
        title: const Text(
          'Remove Admin Access?',
        ),
        content: Text(
          'This will remove $name from the '
          'administrator collection. The customer account '
          'will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(
              context,
              false,
            ),
            child:
                const Text('Cancel'),
          ),
          FilledButton(
            style:
                FilledButton.styleFrom(
              backgroundColor:
                  const Color(
                0xFFDC2626,
              ),
            ),
            onPressed: () =>
                Navigator.pop(
              context,
              true,
            ),
            child:
                const Text(
              'Remove Access',
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    final adminId =
        admin['id']
            ?.toString();

    if (adminId == null ||
        adminId.isEmpty) {
      return;
    }

    try {
      await _adminsCollection
          .doc(adminId)
          .delete();

      if (!mounted) {
        return;
      }

      _showSuccess(
        'Admin access removed.',
      );

      await _loadAdmins();
    } catch (_) {
      _showError(
        'Unable to remove admin access.',
      );
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor: background,

      appBar: AppBar(
        backgroundColor: card,
        surfaceTintColor:
            Colors.transparent,
        elevation: 0,

        title: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              'Administrators',
              style:
                  GoogleFonts.manrope(
                fontSize: 17,
                fontWeight:
                    FontWeight.w900,
                color: heading,
              ),
            ),
            Text(
              'Manage admin access',
              style:
                  GoogleFonts.manrope(
                fontSize: 10,
                fontWeight:
                    FontWeight.w600,
                color: muted,
              ),
            ),
          ],
        ),

        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed:
                _loading
                    ? null
                    : _loadAdmins,
            icon: const Icon(
              Icons.refresh_rounded,
              color: heading,
            ),
          ),
        ],

        bottom:
            PreferredSize(
          preferredSize:
              const Size.fromHeight(
            1,
          ),
          child: Container(
            height: 1,
            color: border,
          ),
        ),
      ),

      floatingActionButton:
          FloatingActionButton.extended(
        backgroundColor:
            primary,
        foregroundColor:
            Colors.white,
        onPressed:
            _saving
                ? null
                : _addAdmin,
        icon: const Icon(
          Icons.person_add_alt_1_rounded,
        ),
        label: const Text(
          'Add Admin',
        ),
      ),

      body: _loading
          ? const Center(
              child:
                  CircularProgressIndicator(
                color: primary,
              ),
            )
          : RefreshIndicator(
              color: primary,
              onRefresh:
                  _loadAdmins,
              child:
                  _buildAdminBody(),
            ),
    );
  }

  // ============================================================
  // ADMIN BODY
  // ============================================================

  Widget _buildAdminBody() {
    if (_admins.isEmpty) {
      return ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.all(20),
        children: [
          const SizedBox(
            height: 100,
          ),

          Container(
            width: 72,
            height: 72,
            margin:
                const EdgeInsets.symmetric(
              horizontal: 100,
            ),
            decoration:
                BoxDecoration(
              color: softAccent,
              borderRadius:
                  BorderRadius.circular(
                22,
              ),
            ),
            child: const Icon(
              Icons.admin_panel_settings_outlined,
              color: primary,
              size: 34,
            ),
          ),

          const SizedBox(
            height: 20,
          ),

          Center(
            child: Text(
              'No administrators yet',
              style:
                  GoogleFonts.manrope(
                fontSize: 17,
                fontWeight:
                    FontWeight.w900,
                color: heading,
              ),
            ),
          ),

          const SizedBox(
            height: 6,
          ),

          Center(
            child: Text(
              'Select an existing customer and '
              'give them administrator access.',
              textAlign:
                  TextAlign.center,
              style:
                  GoogleFonts.manrope(
                fontSize: 12,
                color: body,
              ),
            ),
          ),
        ],
      );
    }

    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(),
      padding:
          const EdgeInsets.fromLTRB(
        20,
        20,
        20,
        110,
      ),
      children: [
        _buildAdminSummary(),

        const SizedBox(
          height: 18,
        ),

        ..._admins.map(
          _buildAdminCard,
        ),
      ],
    );
  }

  // ============================================================
  // ADMIN SUMMARY
  // ============================================================

  Widget _buildAdminSummary() {
    final activeCount =
        _admins.where(
      (admin) =>
          admin['isActive'] == true,
    ).length;

    return Container(
      padding:
          const EdgeInsets.all(18),
      decoration:
          BoxDecoration(
        color: card,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        border:
            Border.all(
          color: border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration:
                BoxDecoration(
              color: softAccent,
              borderRadius:
                  BorderRadius.circular(
                15,
              ),
            ),
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              color: primary,
              size: 25,
            ),
          ),

          const SizedBox(
            width: 13,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  '${_admins.length} Administrators',
                  style:
                      GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight:
                        FontWeight.w900,
                    color: heading,
                  ),
                ),

                const SizedBox(
                  height: 3,
                ),

                Text(
                  '$activeCount active administrators',
                  style:
                      GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w600,
                    color: body,
                  ),
                ),
              ],
            ),
          ),

          IconButton(
            onPressed:
                _addAdmin,
            icon: const Icon(
              Icons.add_circle_outline_rounded,
              color: primary,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ADMIN CARD
  // ============================================================

  Widget _buildAdminCard(
    Map<String, dynamic> admin,
  ) {
    final name =
        admin['fullName']
                ?.toString()
                .trim()
                .isNotEmpty ==
            true
            ? admin['fullName']
                .toString()
            : 'Administrator';

    final phone =
        admin['phone']
                ?.toString() ??
            '';

    final email =
        admin['email']
                ?.toString() ??
            '';

    final role =
        admin['roleId']
                ?.toString() ??
            'manager';

    final isActive =
        admin['isActive'] == true;

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),
      padding:
          const EdgeInsets.all(16),
      decoration:
          BoxDecoration(
        color: card,
        borderRadius:
            BorderRadius.circular(
          19,
        ),
        border:
            Border.all(
          color: border,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration:
                    BoxDecoration(
                  color: softAccent,
                  borderRadius:
                      BorderRadius.circular(
                    15,
                  ),
                ),
                child:
                    const Icon(
                  Icons.person_rounded,
                  color: primary,
                  size: 25,
                ),
              ),

              const SizedBox(
                width: 12,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight:
                            FontWeight.w900,
                        color: heading,
                      ),
                    ),

                    const SizedBox(
                      height: 3,
                    ),

                    Text(
                      role
                          .replaceAll(
                            '_',
                            ' ',
                          )
                          .toUpperCase(),
                      style:
                          GoogleFonts.manrope(
                        fontSize: 9,
                        fontWeight:
                            FontWeight.w800,
                        letterSpacing:
                            0.8,
                        color: primary,
                      ),
                    ),
                  ],
                ),
              ),

              _activeBadge(
                isActive,
              ),

              PopupMenuButton<
                  String>(
                onSelected:
                    (value) {
                  if (value ==
                      'edit') {
                    _editAdmin(
                      admin,
                    );
                  }

                  if (value ==
                      'remove') {
                    _removeAdmin(
                      admin,
                    );
                  }
                },
                itemBuilder:
                    (_) => [
                  const PopupMenuItem(
                    value:
                        'edit',
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          size: 18,
                        ),
                        SizedBox(
                          width: 10,
                        ),
                        Text(
                          'Edit',
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value:
                        'remove',
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_remove_outlined,
                          size: 18,
                        ),
                        SizedBox(
                          width: 10,
                        ),
                        Text(
                          'Remove Access',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          if (phone.isNotEmpty ||
              email.isNotEmpty) ...[
            const SizedBox(
              height: 13,
            ),

            Container(
              padding:
                  const EdgeInsets.all(
                11,
              ),
              decoration:
                  BoxDecoration(
                color: background,
                borderRadius:
                    BorderRadius.circular(
                  13,
                ),
              ),
              child: Column(
                children: [
                  if (phone.isNotEmpty)
                    _infoLine(
                      Icons.phone_outlined,
                      phone,
                    ),

                  if (phone.isNotEmpty &&
                      email.isNotEmpty)
                    const SizedBox(
                      height: 7,
                    ),

                  if (email.isNotEmpty)
                    _infoLine(
                      Icons.email_outlined,
                      email,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _activeBadge(
    bool active,
  ) {
    final color = active
        ? primary
        : const Color(
            0xFF9CA3AF,
          );

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration:
          BoxDecoration(
        color:
            color.withValues(
          alpha: 0.08,
        ),
        borderRadius:
            BorderRadius.circular(
          20,
        ),
      ),
      child: Text(
        active
            ? 'ACTIVE'
            : 'DISABLED',
        style:
            GoogleFonts.manrope(
          fontSize: 8,
          fontWeight:
              FontWeight.w900,
          color: color,
        ),
      ),
    );
  }

  Widget _infoLine(
    IconData icon,
    String value,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 15,
          color: muted,
        ),

        const SizedBox(
          width: 8,
        ),

        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style:
                GoogleFonts.manrope(
              fontSize: 10.5,
              fontWeight:
                  FontWeight.w600,
              color: body,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SUCCESS
  // ============================================================

  void _showSuccess(
    String message,
  ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor:
              primary,
          behavior:
              SnackBarBehavior.floating,
          margin:
              const EdgeInsets.fromLTRB(
            20,
            0,
            20,
            20,
          ),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              14,
            ),
          ),
          content: Text(
            message,
            style:
                GoogleFonts.manrope(
              color: Colors.white,
              fontSize: 12,
              fontWeight:
                  FontWeight.w700,
            ),
          ),
        ),
      );
  }

  // ============================================================
  // ERROR
  // ============================================================

  void _showError(
    String message,
  ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor:
              const Color(
            0xFFDC2626,
          ),
          behavior:
              SnackBarBehavior.floating,
          margin:
              const EdgeInsets.fromLTRB(
            20,
            0,
            20,
            20,
          ),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              14,
            ),
          ),
          content: Text(
            message,
            style:
                GoogleFonts.manrope(
              color: Colors.white,
              fontSize: 12,
              fontWeight:
                  FontWeight.w700,
            ),
          ),
        ),
      );
  }
}

// ============================================================================
// ADMIN FORM RESULT
// ============================================================================

class _AdminFormResult {
  final String roleId;
  final bool isActive;

  const _AdminFormResult({
    required this.roleId,
    required this.isActive,
  });
}

// ============================================================================
// ADMIN FORM DIALOG
// ============================================================================

class _AdminFormDialog
    extends StatefulWidget {
  final String title;

  final Map<String, dynamic>
      customer;

  final String initialRole;

  final bool initialActive;

  const _AdminFormDialog({
    required this.title,
    required this.customer,
    required this.initialRole,
    required this.initialActive,
  });

  @override
  State<_AdminFormDialog>
      createState() =>
          _AdminFormDialogState();
}

class _AdminFormDialogState
    extends State<_AdminFormDialog> {
  static const Color primary =
      Color(0xFF0F766E);

  static const Color heading =
      Color(0xFF17201F);

  static const Color body =
      Color(0xFF66706E);

  static const Color border =
      Color(0xFFE5EBE9);

  late String _role;

  late bool _active;

  @override
  void initState() {
    super.initState();

    _role =
        widget.initialRole;

    _active =
        widget.initialActive;
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final name =
        widget.customer[
                    'fullName']
                ?.toString() ??
            'Customer';

    final phone =
        widget.customer[
                    'phone']
                ?.toString() ??
            '';

    final email =
        widget.customer[
                    'email']
                ?.toString() ??
            '';

    return AlertDialog(
      title: Text(
        widget.title,
      ),

      content:
          SingleChildScrollView(
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Container(
              padding:
                  const EdgeInsets.all(
                13,
              ),
              decoration:
                  BoxDecoration(
                color:
                    const Color(
                  0xFFE6FFFB,
                ),
                borderRadius:
                    BorderRadius.circular(
                  14,
                ),
                border:
                    Border.all(
                  color: border,
                ),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor:
                        Colors.white,
                    child: Icon(
                      Icons.person_rounded,
                      color: primary,
                    ),
                  ),

                  const SizedBox(
                    width: 11,
                  ),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style:
                              GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight:
                                FontWeight.w800,
                            color:
                                heading,
                          ),
                        ),

                        if (phone
                            .isNotEmpty)
                          Text(
                            phone,
                            style:
                                GoogleFonts.manrope(
                              fontSize:
                                  10,
                              color:
                                  body,
                            ),
                          ),

                        if (email
                            .isNotEmpty)
                          Text(
                            email,
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                            style:
                                GoogleFonts.manrope(
                              fontSize:
                                  10,
                              color:
                                  body,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            const Text(
              'Administrator Role',
              style: TextStyle(
                fontWeight:
                    FontWeight.w700,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            DropdownButtonFormField<
                String>(
              initialValue:
                  _role,
              decoration:
                  const InputDecoration(
                border:
                    OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value:
                      'super_admin',
                  child: Text(
                    'Super Admin',
                  ),
                ),
                DropdownMenuItem(
                  value:
                      'manager',
                  child: Text(
                    'Manager',
                  ),
                ),
                DropdownMenuItem(
                  value:
                      'operations',
                  child: Text(
                    'Operations',
                  ),
                ),
                DropdownMenuItem(
                  value:
                      'finance',
                  child: Text(
                    'Finance',
                  ),
                ),
                DropdownMenuItem(
                  value:
                      'support',
                  child: Text(
                    'Support',
                  ),
                ),
              ],
              onChanged:
                  (value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  _role = value;
                });
              },
            ),

            const SizedBox(
              height: 12,
            ),

            SwitchListTile(
              contentPadding:
                  EdgeInsets.zero,
              title: const Text(
                'Administrator Active',
              ),
              subtitle: const Text(
                'Allow this user to access the admin panel',
              ),
              value: _active,
              activeThumbColor:
                  primary,
              onChanged:
                  (value) {
                setState(() {
                  _active = value;
                });
              },
            ),
          ],
        ),
      ),

      actions: [
        TextButton(
          onPressed: () =>
              Navigator.pop(
            context,
          ),
          child:
              const Text('Cancel'),
        ),

        FilledButton(
          style:
              FilledButton.styleFrom(
            backgroundColor:
                primary,
          ),
          onPressed: () {
            Navigator.pop(
              context,
              _AdminFormResult(
                roleId: _role,
                isActive: _active,
              ),
            );
          },
          child:
              const Text('Save'),
        ),
      ],
    );
  }
}

// ============================================================================
// SELECT CUSTOMER DIALOG
// ============================================================================

class _SelectCustomerDialog
    extends StatefulWidget {
  final CollectionReference<
      Map<String, dynamic>>
      customersCollection;

  const _SelectCustomerDialog({
    required this.customersCollection,
  });

  @override
  State<_SelectCustomerDialog>
      createState() =>
          _SelectCustomerDialogState();
}

class _SelectCustomerDialogState
    extends State<_SelectCustomerDialog> {
  static const Color primary =
      Color(0xFF0F766E);

  static const Color background =
      Color(0xFFF8FAF9);

  static const Color heading =
      Color(0xFF17201F);

  static const Color body =
      Color(0xFF66706E);

  static const Color border =
      Color(0xFFE5EBE9);

  final TextEditingController
      _searchController =
      TextEditingController();

  bool _loading = true;

  List<Map<String, dynamic>>
      _customers =
      <Map<String, dynamic>>[];

  List<Map<String, dynamic>>
      _filtered =
      <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();

    _loadCustomers();

    _searchController
        .addListener(
      _filter,
    );
  }

  @override
  void dispose() {
    _searchController
        .removeListener(
      _filter,
    );

    _searchController.dispose();

    super.dispose();
  }

  Future<void>
      _loadCustomers() async {
    try {
      final snapshot =
          await widget
              .customersCollection
              .orderBy(
                'fullName',
              )
              .get();

      final customers =
          snapshot.docs.map(
        (doc) {
          return {
            'id': doc.id,
            ...doc.data(),
          };
        },
      ).where(
        (customer) {
          return customer[
                  'isActive'] !=
              false;
        },
      ).toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _customers = customers;
        _filtered = customers;
        _loading = false;
      });
    } catch (_) {
      try {
        final snapshot =
            await widget
                .customersCollection
                .get();

        final customers =
            snapshot.docs.map(
          (doc) {
            return {
              'id': doc.id,
              ...doc.data(),
            };
          },
        ).where(
          (customer) {
            return customer[
                    'isActive'] !=
                false;
          },
        ).toList();

        if (!mounted) {
          return;
        }

        setState(() {
          _customers =
              customers;
          _filtered =
              customers;
          _loading = false;
        });
      } catch (_) {
        if (!mounted) {
          return;
        }

        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _filter() {
    final query =
        _searchController.text
            .trim()
            .toLowerCase();

    if (query.isEmpty) {
      setState(() {
        _filtered =
            _customers;
      });

      return;
    }

    setState(() {
      _filtered =
          _customers.where(
        (customer) {
          final name =
              customer[
                        'fullName']
                    ?.toString()
                    .toLowerCase() ??
                '';

          final phone =
              customer[
                        'phone']
                    ?.toString()
                    .toLowerCase() ??
                '';

          final email =
              customer[
                        'email']
                    ?.toString()
                    .toLowerCase() ??
                '';

          return name.contains(
                query,
              ) ||
              phone.contains(
                query,
              ) ||
              email.contains(
                query,
              );
        },
      ).toList();
    });
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return AlertDialog(
      title:
          const Text(
        'Select Customer',
      ),

      content:
          SizedBox(
        width: 520,
        height: 500,
        child: Column(
          children: [
            TextField(
              controller:
                  _searchController,
              decoration:
                  InputDecoration(
                hintText:
                    'Search customer, phone or email',
                prefixIcon:
                    const Icon(
                  Icons.search_rounded,
                ),
                filled: true,
                fillColor:
                    background,
                border:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(
                    13,
                  ),
                  borderSide:
                      const BorderSide(
                    color: border,
                  ),
                ),
                enabledBorder:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(
                    13,
                  ),
                  borderSide:
                      const BorderSide(
                    color: border,
                  ),
                ),
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            Expanded(
              child: _loading
                  ? const Center(
                      child:
                          CircularProgressIndicator(
                        color: primary,
                      ),
                    )
                  : _filtered
                          .isEmpty
                      ? Center(
                          child: Text(
                            'No customers found.',
                            style:
                                GoogleFonts.manrope(
                              fontSize:
                                  12,
                              color:
                                  body,
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount:
                              _filtered
                                  .length,
                          separatorBuilder:
                              (_, __) =>
                                  const Divider(
                            height: 1,
                          ),
                          itemBuilder:
                              (
                            context,
                            index,
                          ) {
                            final customer =
                                _filtered[
                                    index];

                            return ListTile(
                              contentPadding:
                                  const EdgeInsets
                                      .symmetric(
                                horizontal:
                                    4,
                                vertical:
                                    4,
                              ),
                              leading:
                                  const CircleAvatar(
                                backgroundColor:
                                    Color(
                                  0xFFE6FFFB,
                                ),
                                child:
                                    Icon(
                                  Icons
                                      .person_outline_rounded,
                                  color:
                                      primary,
                                ),
                              ),
                              title:
                                  Text(
                                customer[
                                            'fullName']
                                        ?.toString()
                                        .trim()
                                        .isNotEmpty ==
                                    true
                                    ? customer[
                                            'fullName']
                                        .toString()
                                    : 'Customer',
                                style:
                                    GoogleFonts.manrope(
                                  fontSize:
                                      12,
                                  fontWeight:
                                      FontWeight.w800,
                                ),
                              ),
                              subtitle:
                                  Text(
                                _customerSubtitle(
                                  customer,
                                ),
                                maxLines:
                                    1,
                                overflow:
                                    TextOverflow
                                        .ellipsis,
                                style:
                                    GoogleFonts.manrope(
                                  fontSize:
                                      10,
                                  color:
                                      body,
                                ),
                              ),
                              trailing:
                                  const Icon(
                                Icons
                                    .chevron_right_rounded,
                                color:
                                    primary,
                              ),
                              onTap:
                                  () {
                                Navigator.pop(
                                  context,
                                  customer,
                                );
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),

      actions: [
        TextButton(
          onPressed: () =>
              Navigator.pop(
            context,
          ),
          child:
              const Text('Cancel'),
        ),
      ],
    );
  }

  String _customerSubtitle(
    Map<String, dynamic>
        customer,
  ) {
    final phone =
        customer['phone']
                ?.toString()
                .trim() ??
            '';

    final email =
        customer['email']
                ?.toString()
                .trim() ??
            '';

    if (phone.isNotEmpty &&
        email.isNotEmpty) {
      return '$phone • $email';
    }

    if (phone.isNotEmpty) {
      return phone;
    }

    return email;
  }
}

// ============================================================================
// STAT CARD
// ============================================================================

class _StatCard
    extends StatelessWidget {
  final String title;

  final String value;

  final String subtitle;

  final IconData icon;

  final VoidCallback? onTap;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Material(
      color: Colors.white,
      borderRadius:
          BorderRadius.circular(
        19,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(
          19,
        ),
        child: Container(
          padding:
              const EdgeInsets.all(
            16,
          ),
          decoration:
              BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.circular(
              19,
            ),
            border:
                Border.all(
              color:
                  const Color(
                0xFFE5EBE9,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration:
                        BoxDecoration(
                      color:
                          const Color(
                        0xFFE6FFFB,
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        12,
                      ),
                    ),
                    child: Icon(
                      icon,
                      size: 19,
                      color:
                          const Color(
                        0xFF0F766E,
                      ),
                    ),
                  ),

                  const Spacer(),

                  const Icon(
                    Icons
                        .arrow_outward_rounded,
                    size: 15,
                    color:
                        Color(
                      0xFF94A09D,
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 16,
              ),

              Text(
                value,
                style:
                    GoogleFonts.manrope(
                  fontSize: 23,
                  fontWeight:
                      FontWeight.w900,
                  color:
                      const Color(
                    0xFF17201F,
                  ),
                ),
              ),

              const SizedBox(
                height: 2,
              ),

              Text(
                title,
                style:
                    GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight:
                      FontWeight.w800,
                  color:
                      const Color(
                    0xFF17201F,
                  ),
                ),
              ),

              const SizedBox(
                height: 2,
              ),

              Text(
                subtitle,
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style:
                    GoogleFonts.manrope(
                  fontSize: 9.5,
                  fontWeight:
                      FontWeight.w500,
                  color:
                      const Color(
                    0xFF94A09D,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// QUICK ACTION CARD
// ============================================================================

class _QuickActionCard
    extends StatelessWidget {
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
  Widget build(
    BuildContext context,
  ) {
    return Material(
      color: const Color(
        0xFFFFFFFF,
      ),
      borderRadius:
          BorderRadius.circular(
        18,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        child: Container(
          padding:
              const EdgeInsets.all(
            14,
          ),
          decoration:
              BoxDecoration(
            borderRadius:
                BorderRadius.circular(
              18,
            ),
            border:
                Border.all(
              color:
                  const Color(
                0xFFE5EBE9,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration:
                    BoxDecoration(
                  color:
                      const Color(
                    0xFFE6FFFB,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),
                child: Icon(
                  icon,
                  color:
                      const Color(
                    0xFF0F766E,
                  ),
                  size: 22,
                ),
              ),

              const SizedBox(
                width: 13,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style:
                          GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight:
                            FontWeight.w800,
                        color:
                            const Color(
                          0xFF17201F,
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 3,
                    ),

                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          GoogleFonts.manrope(
                        fontSize: 10.5,
                        height: 1.3,
                        fontWeight:
                            FontWeight.w500,
                        color:
                            const Color(
                          0xFF66706E,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                width: 8,
              ),

              const Icon(
                Icons
                    .chevron_right_rounded,
                color:
                    Color(
                  0xFF94A09D,
                ),
                size: 21,
              ),
            ],
          ),
        ),
      ),
    );
  }
}