import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../../customer/models/customer.dart';
import '../../../customer/services/customer_service.dart';
import 'admin_add_customer_screen.dart';
import 'admin_customer_details_screen.dart';

class AdminCustomersScreen extends StatefulWidget {
  const AdminCustomersScreen({super.key});

  @override
  State<AdminCustomersScreen> createState() =>
      _AdminCustomersScreenState();
}

class _AdminCustomersScreenState
    extends State<AdminCustomersScreen> {
  // ============================================================
  // PREMIUM LIGHT PALETTE
  // ============================================================

  static const Color bg = Color(0xFFF8FAF9);
  static const Color card = Color(0xFFFFFFFF);

  static const Color primary = Color(0xFF0F766E);
  static const Color accent = Color(0xFF14B8A6);
  static const Color softAccent = Color(0xFFE6FFFB);

  static const Color heading = Color(0xFF17201F);
  static const Color body = Color(0xFF66706E);
  static const Color muted = Color(0xFF94A09D);
  static const Color border = Color(0xFFE5EBE9);

  // ============================================================
  // SERVICES
  // ============================================================

  final CustomerService _service =
      CustomerService.instance;

  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController _searchController =
      TextEditingController();

  // ============================================================
  // STATE
  // ============================================================

  List<Customer> _customers = [];

  bool _loading = true;
  bool _refreshing = false;

  // ============================================================
  // TENANT
  // ============================================================

  String get _tenantId =>
      AppConfig.tenant.tenantId;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _searchController.addListener(
      _onSearchChanged,
    );

    _loadCustomers();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _searchController.removeListener(
      _onSearchChanged,
    );

    _searchController.dispose();

    super.dispose();
  }

  // ============================================================
  // SEARCH
  // ============================================================

  void _onSearchChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  List<Customer> get _filteredCustomers {
    final query =
        _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      return _customers;
    }

    return _customers.where((customer) {
      final name =
          customer.fullName.toLowerCase();

      final phone =
          customer.phone.toLowerCase();

      final email =
          customer.email.toLowerCase();

      final customerId =
          customer.customerId.toLowerCase();

      return name.contains(query) ||
          phone.contains(query) ||
          email.contains(query) ||
          customerId.contains(query);
    }).toList();
  }

  // ============================================================
  // LOAD CUSTOMERS
  // ============================================================

  Future<void> _loadCustomers({
    bool refresh = false,
  }) async {
    if (refresh) {
      setState(() {
        _refreshing = true;
      });
    } else {
      setState(() {
        _loading = true;
      });
    }

    try {
      final customers =
          await _service.getAllCustomers(
        tenantId: _tenantId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _customers = customers;
        _loading = false;
        _refreshing = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _refreshing = false;
      });

      _showError(
        'Unable to load customers.\n${_cleanError(e)}',
      );
    }
  }

  // ============================================================
  // ERROR CLEANER
  // ============================================================

  String _cleanError(Object error) {
    return error
        .toString()
        .replaceFirst(
          'Exception: ',
          '',
        );
  }

  // ============================================================
  // ADD CUSTOMER
  // ============================================================

  Future<void> _addCustomer() async {
    final created =
        await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const AdminAddCustomerScreen(),
      ),
    );

    if (created == true) {
      await _loadCustomers();
    }
  }

  // ============================================================
  // CUSTOMER DETAILS
  // ============================================================

  Future<void> _openCustomer(
    Customer customer,
  ) async {
    final changed =
        await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AdminCustomerDetailsScreen(
          customer: customer,
        ),
      ),
    );

    if (changed == true) {
      await _loadCustomers();
    }
  }

  // ============================================================
  // REFRESH
  // ============================================================

  Future<void> _refresh() async {
    await _loadCustomers(
      refresh: true,
    );
  }

  // ============================================================
  // SNACKBAR
  // ============================================================

  void _showError(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior:
              SnackBarBehavior.floating,
          margin:
              const EdgeInsets.all(16),
          backgroundColor:
              const Color(0xFFB42318),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(14),
          ),
          content: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style:
                      const TextStyle(
                    color: Colors.white,
                    fontWeight:
                        FontWeight.w600,
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
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final customers =
        _filteredCustomers;

    final total =
        _customers.length;

    final active = _customers
        .where(
          (customer) =>
              customer.isActive,
        )
        .length;

    final inactive =
        total - active;

    final verified =
        _customers.where(
      (customer) =>
          customer.kycStatus ==
          'verified',
    ).length;

    final pending =
        _customers.where(
      (customer) =>
          customer.kycStatus ==
          'pending',
    ).length;

    return Scaffold(
      backgroundColor: bg,

      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        backgroundColor: bg,
        surfaceTintColor: bg,
        elevation: 0,
        titleSpacing: 20,

        title: const Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              'Customers',
              style: TextStyle(
                color: heading,
                fontSize: 20,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Manage rental customers',
              style: TextStyle(
                color: muted,
                fontSize: 11,
                fontWeight:
                    FontWeight.w500,
              ),
            ),
          ],
        ),

        actions: [
          if (_refreshing)
            const Padding(
              padding:
                  EdgeInsets.only(
                right: 20,
              ),
              child:
                  Center(
                child:
                    SizedBox(
                  width: 20,
                  height: 20,
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2,
                    color: primary,
                  ),
                ),
              ),
            )
          else
            IconButton(
              tooltip:
                  'Refresh customers',
              onPressed:
                  _refresh,
              icon:
                  const Icon(
                Icons.refresh_rounded,
                color: heading,
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),

      // ========================================================
      // ADD CUSTOMER
      // ========================================================

      floatingActionButton:
          FloatingActionButton.extended(
        onPressed:
            _addCustomer,
        backgroundColor:
            primary,
        foregroundColor:
            Colors.white,
        elevation: 4,
        icon: const Icon(
          Icons.person_add_alt_1_rounded,
        ),
        label: const Text(
          'Add Customer',
          style: TextStyle(
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ),

      // ========================================================
      // BODY
      // ========================================================

      body: _loading
          ? const Center(
              child:
                  CircularProgressIndicator(
                color: primary,
              ),
            )
          : RefreshIndicator(
              color: primary,
              backgroundColor: card,
              onRefresh:
                  _refresh,
              child:
                  _buildBody(
                customers: customers,
                total: total,
                active: active,
                inactive: inactive,
                verified: verified,
                pending: pending,
              ),
            ),
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody({
    required List<Customer> customers,
    required int total,
    required int active,
    required int inactive,
    required int verified,
    required int pending,
  }) {
    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(),
      padding:
          const EdgeInsets.fromLTRB(
        20,
        8,
        20,
        110,
      ),
      children: [
        _buildOverviewCard(
          total: total,
          active: active,
          verified: verified,
        ),

        const SizedBox(height: 14),

        _buildStats(
          total: total,
          active: active,
          inactive: inactive,
          verified: verified,
          pending: pending,
        ),

        const SizedBox(height: 18),

        _buildSearch(),

        const SizedBox(height: 18),

        if (customers.isEmpty)
          _buildEmptyState()
        else
          ...customers.map(
            _buildCustomerCard,
          ),
      ],
    );
  }

  // ============================================================
  // OVERVIEW CARD
  // ============================================================

  Widget _buildOverviewCard({
    required int total,
    required int active,
    required int verified,
  }) {
    final kycPercentage =
        total == 0
            ? 0
            : ((verified / total) * 100)
                .round();

    return Container(
      padding:
          const EdgeInsets.all(18),
      decoration:
          BoxDecoration(
        color: primary,
        borderRadius:
            BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color:
                Color(0x1A0F766E),
            blurRadius: 22,
            offset:
                Offset(0, 9),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration:
                BoxDecoration(
              color:
                  Colors.white
                      .withValues(
                alpha: 0.14,
              ),
              borderRadius:
                  BorderRadius.circular(
                16,
              ),
            ),
            child:
                const Icon(
              Icons.groups_rounded,
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
                  CrossAxisAlignment
                      .start,
              children: [
                const Text(
                  'Customer base',
                  style: TextStyle(
                    color:
                        Colors.white,
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
                const SizedBox(
                  height: 4,
                ),
                Text(
                  '$total customers',
                  style:
                      const TextStyle(
                    color:
                        Colors.white,
                    fontSize: 22,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(
                  height: 2,
                ),
                Text(
                  '$active active · $kycPercentage% KYC verified',
                  style:
                      TextStyle(
                    color:
                        Colors.white
                            .withValues(
                      alpha: 0.72,
                    ),
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w500,
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
  // STATS
  // ============================================================

  Widget _buildStats({
    required int total,
    required int active,
    required int inactive,
    required int verified,
    required int pending,
  }) {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            label: 'Total',
            value: '$total',
            icon:
                Icons.people_alt_outlined,
            color: primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statCard(
            label: 'Active',
            value: '$active',
            icon:
                Icons.check_circle_outline_rounded,
            color: accent,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statCard(
            label: 'KYC',
            value: '$verified',
            icon:
                Icons.verified_outlined,
            color: primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statCard(
            label: 'Pending',
            value: '$pending',
            icon:
                Icons.pending_actions_rounded,
            color:
                const Color(0xFFCA8A04),
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 13,
      ),
      decoration:
          BoxDecoration(
        color: card,
        borderRadius:
            BorderRadius.circular(16),
        border:
            Border.all(
          color: border,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration:
                BoxDecoration(
              color:
                  color.withValues(
                alpha: 0.09,
              ),
              shape:
                  BoxShape.circle,
            ),
            child:
                Icon(
              icon,
              color: color,
              size: 17,
            ),
          ),
          const SizedBox(
            height: 7,
          ),
          Text(
            value,
            style:
                const TextStyle(
              color: heading,
              fontSize: 17,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
          const SizedBox(
            height: 2,
          ),
          Text(
            label,
            style:
                const TextStyle(
              color: body,
              fontSize: 10,
              fontWeight:
                  FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SEARCH
  // ============================================================

  Widget _buildSearch() {
    return TextField(
      controller:
          _searchController,
      textInputAction:
          TextInputAction.search,
      decoration:
          InputDecoration(
        hintText:
            'Search name, phone, email or ID',
        hintStyle:
            const TextStyle(
          color: muted,
          fontSize: 13,
        ),
        prefixIcon:
            const Icon(
          Icons.search_rounded,
          color: primary,
        ),
        suffixIcon:
            _searchController
                    .text
                    .isEmpty
                ? null
                : IconButton(
                    onPressed:
                        () {
                      _searchController
                          .clear();
                    },
                    icon:
                        const Icon(
                      Icons
                          .close_rounded,
                      color: muted,
                    ),
                  ),
        filled: true,
        fillColor: card,
        contentPadding:
            const EdgeInsets
                .symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            16,
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
            16,
          ),
          borderSide:
              const BorderSide(
            color: border,
          ),
        ),
        focusedBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            16,
          ),
          borderSide:
              const BorderSide(
            color: primary,
            width: 1.5,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CUSTOMER CARD
  // ============================================================

  Widget _buildCustomerCard(
    Customer customer,
  ) {
    final name =
        customer.fullName.trim();

    final initials =
        _initials(name);

    final isActive =
        customer.isActive;

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),
      decoration:
          BoxDecoration(
        color: card,
        borderRadius:
            BorderRadius.circular(20),
        border:
            Border.all(
          color: border,
        ),
        boxShadow: const [
          BoxShadow(
            color:
                Color(0x0A17201F),
            blurRadius: 18,
            offset:
                Offset(0, 7),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () =>
              _openCustomer(
            customer,
          ),
          borderRadius:
              BorderRadius.circular(
            20,
          ),
          child: Padding(
            padding:
                const EdgeInsets.all(
              15,
            ),
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .center,
              children: [
                // ------------------------------------------------
                // AVATAR
                // ------------------------------------------------

                _buildAvatar(
                  customer,
                  initials,
                ),

                const SizedBox(
                  width: 13,
                ),

                // ------------------------------------------------
                // CUSTOMER INFO
                // ------------------------------------------------

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child:
                                Text(
                              name.isEmpty
                                  ? 'Unnamed customer'
                                  : name,
                              maxLines:
                                  1,
                              overflow:
                                  TextOverflow
                                      .ellipsis,
                              style:
                                  const TextStyle(
                                color:
                                    heading,
                                fontSize:
                                    14,
                                fontWeight:
                                    FontWeight
                                        .w800,
                              ),
                            ),
                          ),
                          const SizedBox(
                            width: 7,
                          ),
                          _activeDot(
                            isActive,
                          ),
                        ],
                      ),

                      const SizedBox(
                        height: 5,
                      ),

                      if (customer
                          .phone
                          .isNotEmpty)
                        Row(
                          children: [
                            const Icon(
                              Icons
                                  .phone_outlined,
                              size: 13,
                              color:
                                  muted,
                            ),
                            const SizedBox(
                              width: 5,
                            ),
                            Expanded(
                              child:
                                  Text(
                                customer
                                    .phone,
                                maxLines:
                                    1,
                                overflow:
                                    TextOverflow
                                        .ellipsis,
                                style:
                                    const TextStyle(
                                  color:
                                      body,
                                  fontSize:
                                      12,
                                ),
                              ),
                            ),
                          ],
                        ),

                      if (customer
                          .email
                          .isNotEmpty) ...[
                        const SizedBox(
                          height: 3,
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons
                                  .email_outlined,
                              size: 13,
                              color:
                                  muted,
                            ),
                            const SizedBox(
                              width: 5,
                            ),
                            Expanded(
                              child:
                                  Text(
                                customer
                                    .email,
                                maxLines:
                                    1,
                                overflow:
                                    TextOverflow
                                        .ellipsis,
                                style:
                                    const TextStyle(
                                  color:
                                      muted,
                                  fontSize:
                                      11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(
                        height: 8,
                      ),

                      Row(
                        children: [
                          _kycChip(
                            customer
                                .kycStatus,
                          ),

                          const SizedBox(
                            width: 7,
                          ),

                          if (customer
                                  .totalBookings >
                              0)
                            _bookingChip(
                              customer
                                  .totalBookings,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                  width: 7,
                ),

                const Icon(
                  Icons
                      .chevron_right_rounded,
                  color: muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // AVATAR
  // ============================================================

  Widget _buildAvatar(
    Customer customer,
    String initials,
  ) {
    final imageUrl =
        customer.profileImageUrl
            .trim();

    if (imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius:
            BorderRadius.circular(16),
        child: Image.network(
          imageUrl,
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          errorBuilder:
              (_, __, ___) {
            return _initialAvatar(
              initials,
            );
          },
        ),
      );
    }

    return _initialAvatar(
      initials,
    );
  }

  Widget _initialAvatar(
    String initials,
  ) {
    return Container(
      width: 52,
      height: 52,
      decoration:
          BoxDecoration(
        color: softAccent,
        borderRadius:
            BorderRadius.circular(
          16,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style:
              const TextStyle(
            color: primary,
            fontSize: 16,
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // INITIALS
  // ============================================================

  String _initials(
    String name,
  ) {
    if (name.isEmpty) {
      return '?';
    }

    final parts =
        name.split(RegExp(r'\s+'));

    if (parts.length == 1) {
      return parts.first
          .substring(
            0,
            1,
          )
          .toUpperCase();
    }

    return (
      parts.first
              .substring(
                0,
                1,
              ) +
          parts.last
              .substring(
                0,
                1,
              )
    ).toUpperCase();
  }

  // ============================================================
  // ACTIVE DOT
  // ============================================================

  Widget _activeDot(
    bool active,
  ) {
    return Container(
      width: 7,
      height: 7,
      decoration:
          BoxDecoration(
        color: active
            ? accent
            : muted,
        shape:
            BoxShape.circle,
      ),
    );
  }

  // ============================================================
  // KYC CHIP
  // ============================================================

  Widget _kycChip(
    String status,
  ) {
    final normalized =
        status.toLowerCase();

    String text;
    Color color;
    IconData icon;

    switch (normalized) {
      case 'verified':
        text = 'KYC Verified';
        color = primary;
        icon =
            Icons.verified_rounded;
        break;

      case 'pending':
        text = 'KYC Pending';
        color =
            const Color(0xFFCA8A04);
        icon =
            Icons.schedule_rounded;
        break;

      case 'rejected':
        text = 'KYC Rejected';
        color =
            const Color(0xFFDC2626);
        icon =
            Icons.cancel_outlined;
        break;

      default:
        text = 'KYC Not Started';
        color = muted;
        icon =
            Icons.info_outline_rounded;
    }

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
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: color,
          ),
          const SizedBox(
            width: 4,
          ),
          Text(
            text,
            style:
                TextStyle(
              color: color,
              fontSize: 9.5,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BOOKING CHIP
  // ============================================================

  Widget _bookingChip(
    int count,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration:
          BoxDecoration(
        color:
            const Color(0xFFF1F5F4),
        borderRadius:
            BorderRadius.circular(
          20,
        ),
      ),
      child: Text(
        '$count booking${count == 1 ? '' : 's'}',
        style:
            const TextStyle(
          color: body,
          fontSize: 9.5,
          fontWeight:
              FontWeight.w700,
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    final searching =
        _searchController.text
            .trim()
            .isNotEmpty;

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 25,
        vertical: 42,
      ),
      decoration:
          BoxDecoration(
        color: card,
        borderRadius:
            BorderRadius.circular(22),
        border:
            Border.all(
          color: border,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration:
                const BoxDecoration(
              color: softAccent,
              shape: BoxShape.circle,
            ),
            child:
                Icon(
              searching
                  ? Icons
                      .search_off_rounded
                  : Icons
                      .people_outline_rounded,
              size: 32,
              color: primary,
            ),
          ),

          const SizedBox(
            height: 16,
          ),

          Text(
            searching
                ? 'No customers found'
                : 'No customers yet',
            style:
                const TextStyle(
              color: heading,
              fontSize: 17,
              fontWeight:
                  FontWeight.w800,
            ),
          ),

          const SizedBox(
            height: 6,
          ),

          Text(
            searching
                ? 'Try searching with another name, phone number or email.'
                : 'Create your first customer to start managing rental bookings.',
            textAlign:
                TextAlign.center,
            style:
                const TextStyle(
              color: body,
              fontSize: 12.5,
              height: 1.45,
            ),
          ),

          if (!searching) ...[
            const SizedBox(
              height: 18,
            ),
            OutlinedButton.icon(
              onPressed:
                  _addCustomer,
              style:
                  OutlinedButton
                      .styleFrom(
                foregroundColor:
                    primary,
                side:
                    const BorderSide(
                  color: primary,
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    13,
                  ),
                ),
              ),
              icon:
                  const Icon(
                Icons
                    .person_add_alt_1_rounded,
                size: 18,
              ),
              label:
                  const Text(
                'Add Customer',
                style:
                    TextStyle(
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}