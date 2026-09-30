import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/app_config.dart';
import '../../../booking/models/booking.dart';
import '../../../booking/services/booking_service.dart';
import '../../../cars/models/car.dart';
import 'admin_booking_details_screen.dart';

class AdminCarBookingsScreen extends StatefulWidget {
  const AdminCarBookingsScreen({
    super.key,
    required this.car,
  });

  final Car car;

  @override
  State<AdminCarBookingsScreen> createState() =>
      _AdminCarBookingsScreenState();
}

class _AdminCarBookingsScreenState
    extends State<AdminCarBookingsScreen> {
  // ============================================================
  // COLORS
  // ============================================================

  static const Color background = Color(0xFFF7F9F8);
  static const Color card = Colors.white;
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

  final BookingService _bookingService =
      BookingService.instance;

  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController _searchController =
      TextEditingController();

  // ============================================================
  // STATE
  // ============================================================

  late DateTime _selectedMonth;

  List<Booking> _bookings = <Booking>[];

  bool _loading = true;
  bool _refreshing = false;

  String _searchQuery = '';

  BookingStatus? _statusFilter;

  // ============================================================
  // TENANT
  // ============================================================

  String get _tenantId {
    return AppConfig.tenant.tenantId;
  }

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();

    _selectedMonth = DateTime(
      now.year,
      now.month,
      1,
    );

    _searchController.addListener(() {
      if (!mounted) return;

      setState(() {
        _searchQuery = _searchController.text
            .trim()
            .toLowerCase();
      });
    });

    _loadBookings();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // MONTH RANGE
  // ============================================================

  DateTime get _monthStart {
    return DateTime(
      _selectedMonth.year,
      _selectedMonth.month,
      1,
    );
  }

  DateTime get _monthEnd {
    return DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
      1,
    );
  }

  // ============================================================
  // LOAD BOOKINGS
  // ============================================================

  Future<void> _loadBookings({
    bool refresh = false,
  }) async {
    if (_loading && !refresh) {
      // Initial load.
    } else if (refresh) {
      if (mounted) {
        setState(() {
          _refreshing = true;
        });
      }
    } else {
      return;
    }

    try {
      final bookings =
          await _bookingService.getBookingsForCarForRange(
        tenantId: _tenantId,
        carId: widget.car.id,
        start: _monthStart,
        end: _monthEnd,
      );

      if (!mounted) return;

      bookings.sort(
        (a, b) => a.pickupDateTime.compareTo(
          b.pickupDateTime,
        ),
      );

      setState(() {
        _bookings = bookings;
        _loading = false;
        _refreshing = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _refreshing = false;
      });

      _showError(
        e.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
    }
  }

  // ============================================================
  // MONTH NAVIGATION
  // ============================================================

  Future<void> _previousMonth() async {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month - 1,
        1,
      );
      _loading = true;
    });

    await _loadBookings();
  }

  Future<void> _nextMonth() async {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + 1,
        1,
      );
      _loading = true;
    });

    await _loadBookings();
  }

  Future<void> _goToCurrentMonth() async {
    final now = DateTime.now();

    final current = DateTime(
      now.year,
      now.month,
      1,
    );

    if (_selectedMonth.year == current.year &&
        _selectedMonth.month == current.month) {
      return;
    }

    setState(() {
      _selectedMonth = current;
      _loading = true;
    });

    await _loadBookings();
  }

  // ============================================================
  // FILTERED BOOKINGS
  // ============================================================

  List<Booking> get _filteredBookings {
    Iterable<Booking> result = _bookings;

    if (_statusFilter != null) {
      result = result.where(
        (booking) =>
            booking.status == _statusFilter,
      );
    }

    if (_searchQuery.isNotEmpty) {
      result = result.where((booking) {
        final bookingId =
            booking.bookingId.toLowerCase();

        final customerName =
            booking.customerName.toLowerCase();

        final customerPhone =
            booking.customerPhone.toLowerCase();

        final customerEmail =
            booking.customerEmail.toLowerCase();

        final registration =
            _bookingRegistration(
          booking,
        ).toLowerCase();

        return bookingId.contains(
              _searchQuery,
            ) ||
            customerName.contains(
              _searchQuery,
            ) ||
            customerPhone.contains(
              _searchQuery,
            ) ||
            customerEmail.contains(
              _searchQuery,
            ) ||
            registration.contains(
              _searchQuery,
            );
      });
    }

    final list = result.toList();

    list.sort(
      (a, b) => a.pickupDateTime.compareTo(
        b.pickupDateTime,
      ),
    );

    return list;
  }

  // ============================================================
  // STATISTICS
  // ============================================================

  double get _totalAmount {
    return _bookings.fold<double>(
      0,
      (sum, booking) =>
          sum + booking.totalAmount,
    );
  }

  double get _paidAmount {
    return _bookings.fold<double>(
      0,
      (sum, booking) =>
          sum + booking.paidAmount,
    );
  }

  double get _pendingAmount {
    return _bookings.fold<double>(
      0,
      (sum, booking) {
        final balance =
            booking.totalAmount -
                booking.paidAmount;

        return sum +
            (balance > 0 ? balance : 0);
      },
    );
  }

  // ============================================================
  // BOOKING REGISTRATION
  // ============================================================

  String _bookingRegistration(
    Booking booking,
  ) {
    final registration =
        booking.car?.registrationNumber ?? '';

    if (registration.trim().isNotEmpty) {
      return registration.trim();
    }

    return widget.car.registrationNumber;
  }

  // ============================================================
  // FORMAT DATE
  // ============================================================

  String _formatDateTime(
    DateTime value,
  ) {
    return DateFormat(
      'dd MMM yyyy • hh:mm a',
    ).format(value);
  }

  String _formatShortDate(
    DateTime value,
  ) {
    return DateFormat(
      'dd MMM',
    ).format(value);
  }

  String _formatTime(
    DateTime value,
  ) {
    return DateFormat(
      'hh:mm a',
    ).format(value);
  }

  String _formatDuration(
    DateTime pickup,
    DateTime returned,
  ) {
    final difference =
        returned.difference(pickup);

    if (difference.isNegative) {
      return '-';
    }

    final totalMinutes =
        difference.inMinutes;

    final days =
        totalMinutes ~/ (24 * 60);

    final remainingAfterDays =
        totalMinutes % (24 * 60);

    final hours =
        remainingAfterDays ~/ 60;

    final minutes =
        remainingAfterDays % 60;

    final parts = <String>[];

    if (days > 0) {
      parts.add('${days}d');
    }

    if (hours > 0) {
      parts.add('${hours}h');
    }

    if (minutes > 0 && days == 0) {
      parts.add('${minutes}m');
    }

    if (parts.isEmpty) {
      return '0m';
    }

    return parts.join(' ');
  }

  String _formatMoney(
    double value,
  ) {
    final formatter = NumberFormat(
      '#,##0.##',
      'en_IN',
    );

    return '₹${formatter.format(value)}';
  }

  // ============================================================
  // STATUS
  // ============================================================

  String _statusLabel(
    BookingStatus status,
  ) {
    switch (status) {
      case BookingStatus.pending:
        return 'Pending';

      case BookingStatus.confirmed:
        return 'Confirmed';

      case BookingStatus.pickupPending:
        return 'Pickup Pending';

      case BookingStatus.active:
        return 'Active';

      case BookingStatus.returnPending:
        return 'Return Pending';

      case BookingStatus.completed:
        return 'Completed';

      case BookingStatus.cancelled:
        return 'Cancelled';

      case BookingStatus.rejected:
        return 'Rejected';

      case BookingStatus.noShow:
        return 'No Show';
    }
  }

  Color _statusColor(
    BookingStatus status,
  ) {
    switch (status) {
      case BookingStatus.pending:
        return const Color(0xFFF59E0B);

      case BookingStatus.confirmed:
        return const Color(0xFF2563EB);

      case BookingStatus.pickupPending:
        return const Color(0xFF7C3AED);

      case BookingStatus.active:
        return const Color(0xFF16A34A);

      case BookingStatus.returnPending:
        return const Color(0xFFEA580C);

      case BookingStatus.completed:
        return const Color(0xFF0F766E);

      case BookingStatus.cancelled:
      case BookingStatus.rejected:
      case BookingStatus.noShow:
        return const Color(0xFFDC2626);
    }
  }

  String _paymentStatusLabel(
    PaymentStatus status,
  ) {
    switch (status) {
      case PaymentStatus.pending:
        return 'Pending';

      case PaymentStatus.partiallyPaid:
        return 'Partial';

      case PaymentStatus.paid:
        return 'Paid';

      case PaymentStatus.failed:
        return 'Failed';

      case PaymentStatus.refunded:
        return 'Refunded';

      case PaymentStatus.partiallyRefunded:
        return 'Partial Refund';
    }
  }

  Color _paymentStatusColor(
    PaymentStatus status,
  ) {
    switch (status) {
      case PaymentStatus.paid:
        return const Color(0xFF16A34A);

      case PaymentStatus.partiallyPaid:
        return const Color(0xFFF59E0B);

      case PaymentStatus.pending:
        return const Color(0xFF64748B);

      case PaymentStatus.failed:
        return const Color(0xFFDC2626);

      case PaymentStatus.refunded:
      case PaymentStatus.partiallyRefunded:
        return const Color(0xFF7C3AED);
    }
  }

  // ============================================================
  // OPEN BOOKING
  // ============================================================

  Future<void> _openBooking(
    Booking booking,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            AdminBookingDetailsScreen(
          booking: booking,
          onBookingChanged: (_) {},
        ),
      ),
    );

    if (!mounted) return;

    await _loadBookings(
      refresh: true,
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  void _showError(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: heading,
        behavior:
            SnackBarBehavior.floating,
        margin:
            const EdgeInsets.all(16),
        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(16),
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
    final width =
        MediaQuery.sizeOf(context).width;

    final isMobile = width < 700;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        surfaceTintColor:
            Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(
            Icons
                .arrow_back_ios_new_rounded,
            color: heading,
            size: 20,
          ),
        ),
        titleSpacing: 0,
        title: Text(
          'Vehicle Bookings',
          style:
              GoogleFonts.manrope(
            color: heading,
            fontSize: 20,
            fontWeight:
                FontWeight.w800,
          ),
        ),
        actions: [
          if (_refreshing)
            const Padding(
              padding:
                  EdgeInsets.symmetric(
                horizontal: 18,
              ),
              child:
                  SizedBox(
                width: 18,
                height: 18,
                child:
                    CircularProgressIndicator(
                  strokeWidth: 2,
                  color: primary,
                ),
              ),
            )
          else
            IconButton(
              tooltip: 'Refresh',
              onPressed: () {
                _loadBookings(
                  refresh: true,
                );
              },
              icon: const Icon(
                Icons.refresh_rounded,
                color: heading,
              ),
            ),
          const SizedBox(
            width: 6,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: primary,
          onRefresh: () =>
              _loadBookings(
            refresh: true,
          ),
          child: CustomScrollView(
            physics:
                const AlwaysScrollableScrollPhysics(
              parent:
                  BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child:
                    _buildVehicleHeader(
                  isMobile: isMobile,
                ),
              ),
              SliverToBoxAdapter(
                child:
                    _buildMonthBar(
                  isMobile: isMobile,
                ),
              ),
              SliverToBoxAdapter(
                child:
                    _buildStats(),
              ),
              SliverToBoxAdapter(
                child:
                    _buildFilters(
                  isMobile: isMobile,
                ),
              ),
              SliverToBoxAdapter(
                child:
                    _buildTableHeader(),
              ),
              if (_loading)
                SliverToBoxAdapter(
                  child:
                      _buildLoading(),
                )
              else if (_filteredBookings
                  .isEmpty)
                SliverToBoxAdapter(
                  child:
                      _buildEmptyState(),
                )
              else
                SliverToBoxAdapter(
                  child:
                      _buildBookingTable(),
                ),
              const SliverToBoxAdapter(
                child:
                    SizedBox(height: 32),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // VEHICLE HEADER
  // ============================================================

  Widget _buildVehicleHeader({
    required bool isMobile,
  }) {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        18,
        6,
        18,
        14,
      ),
      child: Container(
        padding:
            const EdgeInsets.all(16),
        decoration:
            BoxDecoration(
          color: card,
          borderRadius:
              BorderRadius.circular(22),
          border:
              Border.all(
            color: border,
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: 24,
              offset:
                  const Offset(0, 8),
              color: Colors.black
                  .withOpacity(0.035),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration:
                  BoxDecoration(
                color: softAccent,
                borderRadius:
                    BorderRadius.circular(
                  17,
                ),
              ),
              child: const Icon(
                Icons.directions_car_rounded,
                color: primary,
                size: 28,
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
                    widget.car.name,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        GoogleFonts.manrope(
                      fontSize: 17,
                      fontWeight:
                          FontWeight.w800,
                      color: heading,
                    ),
                  ),
                  const SizedBox(
                    height: 4,
                  ),
                  Text(
                    [
                      if (widget.car
                          .registrationNumber
                          .trim()
                          .isNotEmpty)
                        widget.car
                            .registrationNumber
                            .trim(),
                      if (widget.car.type
                          .trim()
                          .isNotEmpty)
                        widget.car.type
                            .trim(),
                      if (widget.car.fuel
                          .trim()
                          .isNotEmpty)
                        widget.car.fuel
                            .trim(),
                    ].join(' • '),
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        GoogleFonts.manrope(
                      fontSize: 11.5,
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
      ),
    );
  }

  // ============================================================
  // MONTH BAR
  // ============================================================

  Widget _buildMonthBar({
    required bool isMobile,
  }) {
    final monthTitle =
        DateFormat(
      'MMMM yyyy',
    ).format(_selectedMonth);

    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        18,
        0,
        18,
        14,
      ),
      child: Container(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        decoration:
            BoxDecoration(
          color: card,
          borderRadius:
              BorderRadius.circular(18),
          border:
              Border.all(
            color: border,
          ),
        ),
        child: Row(
          children: [
            IconButton(
              tooltip:
                  'Previous month',
              onPressed:
                  _previousMonth,
              icon: const Icon(
                Icons
                    .chevron_left_rounded,
                color: heading,
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    monthTitle,
                    textAlign:
                        TextAlign.center,
                    style:
                        GoogleFonts.manrope(
                      fontSize: 17,
                      fontWeight:
                          FontWeight.w800,
                      color: heading,
                    ),
                  ),
                  const SizedBox(
                    height: 2,
                  ),
                  Text(
                    '${_bookings.length} bookings',
                    style:
                        GoogleFonts.manrope(
                      fontSize: 10.5,
                      fontWeight:
                          FontWeight.w600,
                      color: muted,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed:
                  _goToCurrentMonth,
              style:
                  TextButton.styleFrom(
                foregroundColor:
                    primary,
              ),
              child: Text(
                'Today',
                style:
                    GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Next month',
              onPressed:
                  _nextMonth,
              icon: const Icon(
                Icons
                    .chevron_right_rounded,
                color: heading,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // STATS
  // ============================================================

  Widget _buildStats() {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        18,
        0,
        18,
        14,
      ),
      child: Row(
        children: [
          Expanded(
            child: _statCard(
              icon:
                  Icons.calendar_month_rounded,
              title: 'Bookings',
              value:
                  '${_bookings.length}',
            ),
          ),
          const SizedBox(
            width: 8,
          ),
          Expanded(
            child: _statCard(
              icon:
                  Icons.currency_rupee_rounded,
              title: 'Total',
              value:
                  _formatMoney(
                _totalAmount,
              ),
            ),
          ),
          const SizedBox(
            width: 8,
          ),
          Expanded(
            child: _statCard(
              icon:
                  Icons.payments_rounded,
              title: 'Paid',
              value:
                  _formatMoney(
                _paidAmount,
              ),
            ),
          ),
          const SizedBox(
            width: 8,
          ),
          Expanded(
            child: _statCard(
              icon:
                  Icons.account_balance_wallet_rounded,
              title: 'Balance',
              value:
                  _formatMoney(
                _pendingAmount,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding:
          const EdgeInsets.all(12),
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
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 17,
            color: primary,
          ),
          const SizedBox(
            height: 7,
          ),
          Text(
            title,
            style:
                GoogleFonts.manrope(
              fontSize: 9,
              fontWeight:
                  FontWeight.w700,
              color: muted,
            ),
          ),
          const SizedBox(
            height: 2,
          ),
          Text(
            value,
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
        ],
      ),
    );
  }

  // ============================================================
  // FILTERS
  // ============================================================

  Widget _buildFilters({
    required bool isMobile,
  }) {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        18,
        0,
        18,
        14,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 46,
              decoration:
                  BoxDecoration(
                color: card,
                borderRadius:
                    BorderRadius.circular(
                  14,
                ),
                border:
                    Border.all(
                  color: border,
                ),
              ),
              child: TextField(
                controller:
                    _searchController,
                style:
                    GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight:
                      FontWeight.w600,
                  color: heading,
                ),
                decoration:
                    InputDecoration(
                  border:
                      InputBorder.none,
                  prefixIcon:
                      const Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: muted,
                  ),
                  suffixIcon:
                      _searchQuery
                              .isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController
                                    .clear();
                              },
                              icon:
                                  const Icon(
                                Icons
                                    .close_rounded,
                                size: 18,
                                color: muted,
                              ),
                            ),
                  hintText:
                      'Search booking, customer, phone...',
                  hintStyle:
                      GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w500,
                    color: muted,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(
            width: 10,
          ),
          Container(
            height: 46,
            padding:
                const EdgeInsets.symmetric(
              horizontal: 12,
            ),
            decoration:
                BoxDecoration(
              color: card,
              borderRadius:
                  BorderRadius.circular(
                14,
              ),
              border:
                  Border.all(
                color: border,
              ),
            ),
            child:
                DropdownButtonHideUnderline(
              child:
                  DropdownButton<BookingStatus?>(
                value: _statusFilter,
                icon: const Icon(
                  Icons
                      .keyboard_arrow_down_rounded,
                  size: 18,
                  color: muted,
                ),
                style:
                    GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight:
                      FontWeight.w700,
                  color: heading,
                ),
                onChanged:
                    (value) {
                  setState(() {
                    _statusFilter =
                        value;
                  });
                },
                items: [
                  const DropdownMenuItem<
                      BookingStatus?>(
                    value: null,
                    child: Text(
                      'All Status',
                    ),
                  ),
                  ...BookingStatus
                      .values
                      .map(
                    (status) =>
                        DropdownMenuItem<
                            BookingStatus?>(
                      value: status,
                      child: Text(
                        _statusLabel(
                          status,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TABLE HEADER
  // ============================================================

  Widget _buildTableHeader() {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        18,
        0,
        18,
        8,
      ),
      child: Row(
        children: [
          Text(
            'BOOKING LIST',
            style:
                GoogleFonts.manrope(
              fontSize: 10,
              fontWeight:
                  FontWeight.w900,
              letterSpacing: 0.8,
              color: muted,
            ),
          ),
          const SizedBox(
            width: 8,
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 7,
              vertical: 3,
            ),
            decoration:
                BoxDecoration(
              color: softAccent,
              borderRadius:
                  BorderRadius.circular(8),
            ),
            child: Text(
              '${_filteredBookings.length}',
              style:
                  GoogleFonts.manrope(
                fontSize: 9,
                fontWeight:
                    FontWeight.w800,
                color: primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TABLE
  // ============================================================

  Widget _buildBookingTable() {
    final bookings =
        _filteredBookings;

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 18,
      ),
      child: Container(
        decoration:
            BoxDecoration(
          color: card,
          borderRadius:
              BorderRadius.circular(20),
          border:
              Border.all(
            color: border,
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: 20,
              offset:
                  const Offset(0, 6),
              color: Colors.black
                  .withOpacity(0.025),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius:
              BorderRadius.circular(20),
          child: SingleChildScrollView(
            scrollDirection:
                Axis.horizontal,
            child: DataTable(
              headingRowHeight: 50,
              dataRowMinHeight: 72,
              dataRowMaxHeight: 88,
              columnSpacing: 28,
              horizontalMargin: 18,
              headingRowColor:
                  WidgetStateProperty
                      .all(
                background,
              ),
              border:
                  TableBorder(
                horizontalInside:
                    BorderSide(
                  color: border,
                  width: 0.7,
                ),
              ),
              columns: [
                _column(
                  '#',
                ),
                _column(
                  'BOOKING',
                ),
                _column(
                  'CUSTOMER',
                ),
                _column(
                  'PICKUP',
                ),
                _column(
                  'RETURN',
                ),
                _column(
                  'DURATION',
                ),
                _column(
                  'AMOUNT',
                ),
                _column(
                  'PAYMENT',
                ),
                _column(
                  'STATUS',
                ),
                _column(
                  'ACTION',
                ),
              ],
              rows: List.generate(
                bookings.length,
                (index) {
                  final booking =
                      bookings[index];

                  return DataRow(
                    onSelectChanged:
                        (_) {
                      _openBooking(
                        booking,
                      );
                    },
                    cells: [
                      DataCell(
                        Text(
                          '${index + 1}',
                          style:
                              GoogleFonts
                                  .manrope(
                            fontSize: 11,
                            fontWeight:
                                FontWeight
                                    .w800,
                            color: muted,
                          ),
                        ),
                      ),
                      DataCell(
                        _bookingCell(
                          booking,
                        ),
                      ),
                      DataCell(
                        _customerCell(
                          booking,
                        ),
                      ),
                      DataCell(
                        _dateCell(
                          booking
                              .pickupDateTime,
                        ),
                      ),
                      DataCell(
                        _dateCell(
                          booking
                              .returnDateTime,
                        ),
                      ),
                      DataCell(
                        Text(
                          _formatDuration(
                            booking
                                .pickupDateTime,
                            booking
                                .returnDateTime,
                          ),
                          style:
                              GoogleFonts
                                  .manrope(
                            fontSize: 11,
                            fontWeight:
                                FontWeight
                                    .w800,
                            color: heading,
                          ),
                        ),
                      ),
                      DataCell(
                        _amountCell(
                          booking,
                        ),
                      ),
                      DataCell(
                        _paymentBadge(
                          booking
                              .paymentStatus,
                        ),
                      ),
                      DataCell(
                        _statusBadge(
                          booking.status,
                        ),
                      ),
                      DataCell(
                        IconButton(
                          tooltip:
                              'View booking',
                          onPressed: () {
                            _openBooking(
                              booking,
                            );
                          },
                          icon:
                              const Icon(
                            Icons
                                .arrow_forward_ios_rounded,
                            size: 15,
                            color: primary,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  DataColumn _column(
    String text,
  ) {
    return DataColumn(
      label: Text(
        text,
        style:
            GoogleFonts.manrope(
          fontSize: 9,
          fontWeight:
              FontWeight.w900,
          letterSpacing: 0.5,
          color: muted,
        ),
      ),
    );
  }

  // ============================================================
  // BOOKING CELL
  // ============================================================

  Widget _bookingCell(
    Booking booking,
  ) {
    return SizedBox(
      width: 120,
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            '#${booking.bookingId}',
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style:
                GoogleFonts.manrope(
              fontSize: 11,
              fontWeight:
                  FontWeight.w800,
              color: heading,
            ),
          ),
          const SizedBox(
            height: 4,
          ),
          Text(
            booking.rentalType
                .trim()
                .isEmpty
                ? 'Rental'
                : booking.rentalType,
            style:
                GoogleFonts.manrope(
              fontSize: 9.5,
              fontWeight:
                  FontWeight.w600,
              color: muted,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CUSTOMER CELL
  // ============================================================

  Widget _customerCell(
    Booking booking,
  ) {
    return SizedBox(
      width: 170,
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            booking.customerName
                    .trim()
                    .isEmpty
                ? 'Unknown customer'
                : booking.customerName,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style:
                GoogleFonts.manrope(
              fontSize: 11,
              fontWeight:
                  FontWeight.w800,
              color: heading,
            ),
          ),
          if (booking.customerPhone
              .trim()
              .isNotEmpty) ...[
            const SizedBox(
              height: 4,
            ),
            Text(
              booking.customerPhone,
              style:
                  GoogleFonts.manrope(
                fontSize: 9.5,
                fontWeight:
                    FontWeight.w600,
                color: body,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // DATE CELL
  // ============================================================

  Widget _dateCell(
    DateTime value,
  ) {
    return SizedBox(
      width: 145,
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            _formatShortDate(
              value,
            ),
            style:
                GoogleFonts.manrope(
              fontSize: 11,
              fontWeight:
                  FontWeight.w800,
              color: heading,
            ),
          ),
          const SizedBox(
            height: 4,
          ),
          Text(
            _formatTime(value),
            style:
                GoogleFonts.manrope(
              fontSize: 10,
              fontWeight:
                  FontWeight.w600,
              color: body,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // AMOUNT CELL
  // ============================================================

  Widget _amountCell(
    Booking booking,
  ) {
    final balance =
        booking.totalAmount -
            booking.paidAmount;

    return SizedBox(
      width: 120,
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            _formatMoney(
              booking.totalAmount,
            ),
            style:
                GoogleFonts.manrope(
              fontSize: 11,
              fontWeight:
                  FontWeight.w800,
              color: heading,
            ),
          ),
          const SizedBox(
            height: 4,
          ),
          Text(
            balance > 0.009
                ? 'Due ${_formatMoney(balance)}'
                : 'Fully paid',
            style:
                GoogleFonts.manrope(
              fontSize: 9.5,
              fontWeight:
                  FontWeight.w700,
              color: balance > 0.009
                  ? const Color(
                      0xFFEA580C,
                    )
                  : const Color(
                      0xFF16A34A,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PAYMENT BADGE
  // ============================================================

  Widget _paymentBadge(
    PaymentStatus status,
  ) {
    final color =
        _paymentStatusColor(
      status,
    );

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration:
          BoxDecoration(
        color: color.withOpacity(
          0.09,
        ),
        borderRadius:
            BorderRadius.circular(9),
      ),
      child: Text(
        _paymentStatusLabel(
          status,
        ),
        style:
            GoogleFonts.manrope(
          fontSize: 9,
          fontWeight:
              FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  // ============================================================
  // STATUS BADGE
  // ============================================================

  Widget _statusBadge(
    BookingStatus status,
  ) {
    final color =
        _statusColor(status);

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration:
          BoxDecoration(
        color: color.withOpacity(
          0.09,
        ),
        borderRadius:
            BorderRadius.circular(9),
      ),
      child: Text(
        _statusLabel(status),
        style:
            GoogleFonts.manrope(
          fontSize: 9,
          fontWeight:
              FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  // ============================================================
  // LOADING
  // ============================================================

  Widget _buildLoading() {
    return Padding(
      padding:
          const EdgeInsets.all(30),
      child: Column(
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child:
                CircularProgressIndicator(
              strokeWidth: 2.5,
              color: primary,
            ),
          ),
          const SizedBox(
            height: 14,
          ),
          Text(
            'Loading bookings...',
            style:
                GoogleFonts.manrope(
              fontSize: 12,
              fontWeight:
                  FontWeight.w700,
              color: body,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY
  // ============================================================

  Widget _buildEmptyState() {
    final searching =
        _searchQuery.isNotEmpty ||
            _statusFilter != null;

    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        18,
        8,
        18,
        20,
      ),
      child: Container(
        padding:
            const EdgeInsets.all(32),
        decoration:
            BoxDecoration(
          color: card,
          borderRadius:
              BorderRadius.circular(20),
          border:
              Border.all(
            color: border,
          ),
        ),
        child: Center(
          child: Column(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration:
                    BoxDecoration(
                  color: softAccent,
                  borderRadius:
                      BorderRadius.circular(
                    18,
                  ),
                ),
                child: const Icon(
                  Icons
                      .event_busy_rounded,
                  color: primary,
                  size: 29,
                ),
              ),
              const SizedBox(
                height: 14,
              ),
              Text(
                searching
                    ? 'No matching bookings'
                    : 'No bookings this month',
                style:
                    GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight:
                      FontWeight.w800,
                  color: heading,
                ),
              ),
              const SizedBox(
                height: 5,
              ),
              Text(
                searching
                    ? 'Try another search or status filter.'
                    : 'There are no bookings for this vehicle in ${DateFormat('MMMM yyyy').format(_selectedMonth)}.',
                textAlign:
                    TextAlign.center,
                style:
                    GoogleFonts.manrope(
                  fontSize: 11,
                  height: 1.5,
                  fontWeight:
                      FontWeight.w500,
                  color: muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}