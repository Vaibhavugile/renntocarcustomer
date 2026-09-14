import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/config/app_config.dart';
import '../../cars/screens/admin_cars_screen.dart';

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
  // TENANT
  // ============================================================

  String get tenantId {
    try {
      return AppConfig.tenant.tenantId;
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

      return AppConfig.tenant.branding.appName;
    } catch (_) {
      return 'Admin';
    }
  }

  // ============================================================
  // STATE
  // ============================================================

  int _selectedIndex = 0;

  // ============================================================
  // FIXED PREMIUM PALETTE
  // IMPORTANT:
  // Firebase branding colors are NOT used here.
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
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      drawer: _buildDrawer(),
      appBar: _buildAppBar(),
      body: _buildDashboard(),
    );
  }

  // ============================================================
  // APP BAR
  // ============================================================

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,

      leading: Builder(
        builder: (context) {
          return IconButton(
            tooltip: 'Open menu',
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
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
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: heading,
            ),
          ),

          if (tenantId.isNotEmpty)
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
        _buildNotificationButton(),

        const SizedBox(width: 8),

        _buildProfileButton(),

        const SizedBox(width: 12),
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
  // NOTIFICATION BUTTON
  // ============================================================

  Widget _buildNotificationButton() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: background,
        borderRadius:
            BorderRadius.circular(13),
        border: Border.all(
          color: border,
        ),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        tooltip: 'Notifications',
        onPressed: () {
          _showComingSoon(
            'Notifications',
          );
        },
        icon: const Icon(
          Icons.notifications_none_rounded,
          size: 20,
          color: heading,
        ),
      ),
    );
  }

  // ============================================================
  // PROFILE BUTTON
  // ============================================================

  Widget _buildProfileButton() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: softAccent,
        borderRadius:
            BorderRadius.circular(13),
        border: Border.all(
          color: border,
        ),
      ),
      child: const Icon(
        Icons.person_outline_rounded,
        color: primary,
        size: 21,
      ),
    );
  }

  // ============================================================
  // DASHBOARD
  // ============================================================

  Widget _buildDashboard() {
    return SafeArea(
      child: RefreshIndicator(
        color: primary,
        onRefresh: () async {
          await Future<void>.delayed(
            const Duration(
              milliseconds: 500,
            ),
          );

          if (mounted) {
            setState(() {});
          }
        },
        child: SingleChildScrollView(
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
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              _buildWelcome(),

              const SizedBox(height: 24),

              _buildStats(),

              const SizedBox(height: 30),

              _buildSectionHeader(
                'Quick Management',
                'Manage your rental business',
              ),

              const SizedBox(height: 14),

              _buildQuickActions(),

              const SizedBox(height: 30),

              _buildSectionHeader(
                'Recent Bookings',
                'Latest rental activity',
              ),

              const SizedBox(height: 14),

              _buildEmptyBookings(),

              const SizedBox(height: 30),

              _buildTenantInfo(),
            ],
          ),
        ),
      ),
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
          'Monitor your fleet, bookings and business activity from one place.',
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
            constraints.maxWidth;

        final cardWidth =
            (width - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: cardWidth,
              child: const _StatCard(
                title: 'Cars',
                value: '4',
                subtitle:
                    'Fleet vehicles',
                icon:
                    Icons.directions_car_rounded,
              ),
            ),

            SizedBox(
              width: cardWidth,
              child: const _StatCard(
                title: 'Bookings',
                value: '0',
                subtitle:
                    'Total bookings',
                icon:
                    Icons.calendar_month_rounded,
              ),
            ),

            SizedBox(
              width: cardWidth,
              child: const _StatCard(
                title: 'Active',
                value: '0',
                subtitle:
                    'Active rentals',
                icon:
                    Icons.key_rounded,
              ),
            ),

            SizedBox(
              width: cardWidth,
              child: const _StatCard(
                title: 'Revenue',
                value: '₹0',
                subtitle:
                    'Total revenue',
                icon:
                    Icons.payments_rounded,
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

  // ============================================================
  // QUICK ACTIONS
  // ============================================================

  Widget _buildQuickActions() {
    return Column(
      children: [
        _QuickActionCard(
          icon:
              Icons.directions_car_rounded,
          title: 'Manage Cars',
          subtitle:
              'Add, edit and manage vehicles',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const AdminCarsScreen(),
              ),
            );
          },
        ),

        const SizedBox(height: 10),

        _QuickActionCard(
          icon:
              Icons.price_change_rounded,
          title: 'Pricing',
          subtitle:
              'Manage pricing profiles and KM packages',
          onTap: () {
            _showComingSoon(
              'Pricing',
            );
          },
        ),

        const SizedBox(height: 10),

        _QuickActionCard(
          icon:
              Icons.calendar_month_rounded,
          title: 'Bookings',
          subtitle:
              'View and manage customer bookings',
          onTap: () {
            _showComingSoon(
              'Bookings',
            );
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
            _showComingSoon(
              'Branches',
            );
          },
        ),
      ],
    );
  }

  // ============================================================
  // EMPTY BOOKINGS
  // ============================================================

  Widget _buildEmptyBookings() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(28),
      decoration:
          BoxDecoration(
        color: card,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: border,
        ),
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
                  BorderRadius.circular(17),
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
            'Your latest bookings will appear here.',
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
            BorderRadius.circular(18),
        border: Border.all(
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
                  BorderRadius.circular(13),
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
                    fontWeight: FontWeight.w800,
                    color: heading,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  tenantId.isEmpty
                      ? 'Tenant configuration'
                      : 'Tenant: $tenantId',
                  style:
                      GoogleFonts.manrope(
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
                    title: 'Dashboard',
                    selected:
                        _selectedIndex == 0,
                    onTap: () {
                      _selectDrawerItem(0);
                    },
                  ),

                  _drawerSection(
                    'FLEET',
                  ),

                  // ==================================================
                  // CARS
                  // ==================================================

                  _drawerItem(
                    icon:
                        Icons.directions_car_rounded,
                    title: 'Cars',
                    onTap: () {
                      Navigator.pop(context);

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const AdminCarsScreen(),
                        ),
                      );
                    },
                  ),

                  _drawerItem(
                    icon:
                        Icons.storefront_rounded,
                    title: 'Branches',
                    onTap: () {
                      _showComingSoon(
                        'Branches',
                      );
                    },
                  ),

                  _drawerItem(
                    icon:
                        Icons.block_rounded,
                    title: 'Vehicle Blocks',
                    onTap: () {
                      _showComingSoon(
                        'Vehicle Blocks',
                      );
                    },
                  ),

                  _drawerSection(
                    'PRICING',
                  ),

                  _drawerItem(
                    icon:
                        Icons.price_change_rounded,
                    title: 'Pricing Profiles',
                    onTap: () {
                      _showComingSoon(
                        'Pricing Profiles',
                      );
                    },
                  ),

                  _drawerItem(
                    icon:
                        Icons.route_rounded,
                    title: 'Rental Packages',
                    onTap: () {
                      _showComingSoon(
                        'Rental Packages',
                      );
                    },
                  ),

                  _drawerItem(
                    icon:
                        Icons.speed_rounded,
                    title: 'KM Packages',
                    onTap: () {
                      _showComingSoon(
                        'KM Packages',
                      );
                    },
                  ),

                  _drawerItem(
                    icon:
                        Icons.add_circle_outline_rounded,
                    title: 'Add-ons',
                    onTap: () {
                      _showComingSoon(
                        'Add-ons',
                      );
                    },
                  ),

                  _drawerItem(
                    icon:
                        Icons.shield_outlined,
                    title: 'Protection',
                    onTap: () {
                      _showComingSoon(
                        'Protection',
                      );
                    },
                  ),

                  _drawerItem(
                    icon:
                        Icons.local_offer_outlined,
                    title: 'Coupons',
                    onTap: () {
                      _showComingSoon(
                        'Coupons',
                      );
                    },
                  ),

                  _drawerItem(
                    icon:
                        Icons.receipt_long_outlined,
                    title: 'Extra Charges',
                    onTap: () {
                      _showComingSoon(
                        'Extra Charges',
                      );
                    },
                  ),

                  _drawerSection(
                    'OPERATIONS',
                  ),

                  _drawerItem(
                    icon:
                        Icons.calendar_month_rounded,
                    title: 'Bookings',
                    onTap: () {
                      _showComingSoon(
                        'Bookings',
                      );
                    },
                  ),

                  _drawerItem(
                    icon:
                        Icons.people_alt_outlined,
                    title: 'Customers',
                    onTap: () {
                      _showComingSoon(
                        'Customers',
                      );
                    },
                  ),

                  _drawerItem(
                    icon:
                        Icons.verified_user_outlined,
                    title: 'KYC',
                    onTap: () {
                      _showComingSoon(
                        'KYC',
                      );
                    },
                  ),

                  _drawerItem(
                    icon:
                        Icons.payments_outlined,
                    title: 'Payments',
                    onTap: () {
                      _showComingSoon(
                        'Payments',
                      );
                    },
                  ),

                  _drawerItem(
                    icon:
                        Icons.description_outlined,
                    title: 'Invoices',
                    onTap: () {
                      _showComingSoon(
                        'Invoices',
                      );
                    },
                  ),

                  _drawerSection(
                    'ADMINISTRATION',
                  ),

                  _drawerItem(
                    icon:
                        Icons.manage_accounts_outlined,
                    title: 'Users',
                    onTap: () {
                      _showComingSoon(
                        'Users',
                      );
                    },
                  ),

                  _drawerItem(
                    icon:
                        Icons.admin_panel_settings_outlined,
                    title: 'Roles',
                    onTap: () {
                      _showComingSoon(
                        'Roles',
                      );
                    },
                  ),

                  _drawerItem(
                    icon:
                        Icons.settings_outlined,
                    title: 'Settings',
                    onTap: () {
                      _showComingSoon(
                        'Settings',
                      );
                    },
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
                  BorderRadius.circular(15),
              border: Border.all(
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
                    fontWeight: FontWeight.w900,
                    color: heading,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  'ADMIN PANEL',
                  style:
                      GoogleFonts.manrope(
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
          fontWeight: FontWeight.w900,
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
            BorderRadius.circular(13),
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
          color: selected
              ? primary
              : body,
        ),
        title: Text(
          title,
          style:
              GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: selected
                ? FontWeight.w800
                : FontWeight.w600,
            color: selected
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
                  shape: BoxShape.circle,
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
            BorderRadius.circular(15),
        border: Border.all(
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
                fontWeight: FontWeight.w700,
                color: body,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DRAWER SELECTION
  // ============================================================

  void _selectDrawerItem(
    int index,
  ) {
    Navigator.pop(context);

    if (!mounted) return;

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
    Navigator.of(context).maybePop();

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          '$feature module will be connected next.',
          style:
              GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: heading,
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
              BorderRadius.circular(14),
        ),
      ),
    );
  }
}

// ================================================================
// STAT CARD
// ================================================================

class _StatCard
    extends StatelessWidget {
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
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(16),
      decoration:
          BoxDecoration(
        color:
            const Color(0xFFFFFFFF),
        borderRadius:
            BorderRadius.circular(19),
        border:
            Border.all(
          color:
              const Color(0xFFE5EBE9),
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
                Icons.arrow_outward_rounded,
                size: 15,
                color:
                    Color(0xFF94A09D),
              ),
            ],
          ),

          const SizedBox(height: 16),

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

          const SizedBox(height: 2),

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

          const SizedBox(height: 2),

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
    );
  }
}

// ================================================================
// QUICK ACTION CARD
// ================================================================

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
      color:
          const Color(0xFFFFFFFF),
      borderRadius:
          BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(18),
        child: Container(
          padding:
              const EdgeInsets.all(14),
          decoration:
              BoxDecoration(
            borderRadius:
                BorderRadius.circular(18),
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

              const SizedBox(width: 13),

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

                    const SizedBox(height: 3),

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

              const SizedBox(width: 8),

              const Icon(
                Icons.chevron_right_rounded,
                color:
                    Color(0xFF94A09D),
                size: 21,
              ),
            ],
          ),
        ),
      ),
    );
  }
}