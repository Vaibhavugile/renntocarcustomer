import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/booking.dart';
import '../services/booking_service.dart';
import 'customer_booking_details_screen.dart';

class MyBookingsScreen extends StatefulWidget {
  final String tenantId;

  const MyBookingsScreen({
    super.key,
    this.tenantId = 'tenant_001',
  });

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  static const _background = Color(0xFFF8FAF9);
  static const _card = Color(0xFFFFFFFF);
  static const _primary = Color(0xFF0F766E);
  static const _accent = Color(0xFF14B8A6);
  static const _softAccent = Color(0xFFE6FFFB);
  static const _heading = Color(0xFF17201F);
  static const _body = Color(0xFF66706E);
  static const _muted = Color(0xFF94A09D);
  static const _border = Color(0xFFE5EBE9);

  final BookingService _bookingService = BookingService();

  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDate;
  List<Booking> _bookings = [];
  bool _loading = true;
  String? _error;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final bookings = await _bookingService.getCustomerBookings(
        tenantId: widget.tenantId,
      );

      // IMPORTANT:
      // Cancelled/rejected/no-show bookings are historical records only.
      // They NEVER create calendar availability blocks or active booking
      // indicators in this screen.
      bookings.removeWhere(_isNonBlockingBooking);

      if (!mounted) return;

      setState(() {
        _bookings = bookings;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  bool _isNonBlockingBooking(Booking booking) {
    return booking.status == BookingStatus.cancelled ||
        booking.status == BookingStatus.rejected ||
        booking.status == BookingStatus.noShow;
  }

  List<Booking> get _filteredBookings {
    Iterable<Booking> result = _bookings;

    switch (_tabIndex) {
      case 0:
        result = result.where((b) => b.isUpcoming);
        break;
      case 1:
        result = result.where((b) => b.isOngoing);
        break;
      case 2:
        result = result.where((b) => b.isFinished);
        break;
      case 3:
        // Cancellation history is intentionally not shown in the calendar,
        // but is available in this history tab.
        return const [];
    }

    if (_selectedDate != null) {
      result = result.where((b) => _bookingTouchesDate(b, _selectedDate!));
    }

    final list = result.toList()
      ..sort((a, b) => a.pickupDateTime.compareTo(b.pickupDateTime));
    return list;
  }

  List<Booking> get _cancelledBookings {
    final list = _bookings
        .where(_isNonBlockingBooking)
        .toList()
      ..sort((a, b) => b.pickupDateTime.compareTo(a.pickupDateTime));
    return list;
  }

  bool _bookingTouchesDate(Booking booking, DateTime date) {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    // Half-open interval: [pickup, return)
    // A booking returning exactly at midnight does not block the next day.
    return booking.pickupDateTime.isBefore(dayEnd) &&
        booking.returnDateTime.isAfter(dayStart);
  }

  bool _hasBlockingBookingOn(DateTime date) {
    return _bookings.any(
      (booking) =>
          !_isNonBlockingBooking(booking) &&
          _bookingTouchesDate(booking, date),
    );
  }

  void _previousMonth() {
    setState(() {
      _focusedMonth = DateTime(
        _focusedMonth.year,
        _focusedMonth.month - 1,
      );
      _selectedDate = null;
    });
  }

  void _nextMonth() {
    setState(() {
      _focusedMonth = DateTime(
        _focusedMonth.year,
        _focusedMonth.month + 1,
      );
      _selectedDate = null;
    });
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = _isSameDay(_selectedDate, date) ? null : date;
      _tabIndex = 0;
    });
  }

  bool _isSameDay(DateTime? a, DateTime b) {
    if (a == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 20,
        title: const Text(
          'My Bookings',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 23,
            fontWeight: FontWeight.w800,
            color: _heading,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadBookings,
            icon: const Icon(Icons.refresh_rounded, color: _heading),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _primary),
            )
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  color: _primary,
                  onRefresh: _loadBookings,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
                    children: [
                      _buildCalendarCard(),
                      const SizedBox(height: 18),
                      _buildTabs(),
                      const SizedBox(height: 16),
                      if (_tabIndex == 3)
                        _buildCancelledHistory()
                      else
                        _buildBookingList(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 46, color: _muted),
            const SizedBox(height: 14),
            const Text(
              'Unable to load bookings',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _heading,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 13,
                color: _body,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _loadBookings,
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'Try again',
                style: TextStyle(fontFamily: 'Manrope'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarCard() {
    final monthTitle = DateFormat('MMMM yyyy').format(_focusedMonth);
    final firstDay = DateTime(
      _focusedMonth.year,
      _focusedMonth.month,
      1,
    );

    // Monday = 0 ... Sunday = 6
    final leadingDays = firstDay.weekday - 1;
    final daysInMonth = DateTime(
      _focusedMonth.year,
      _focusedMonth.month + 1,
      0,
    ).day;

    final cells = <DateTime?>[
      for (int i = 0; i < leadingDays; i++) null,
      for (int day = 1; day <= daysInMonth; day++)
        DateTime(_focusedMonth.year, _focusedMonth.month, day),
    ];

    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            blurRadius: 20,
            offset: const Offset(0, 7),
            color: Colors.black.withOpacity(.035),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'Booking calendar',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _heading,
                ),
              ),
              const Spacer(),
              _monthButton(Icons.chevron_left_rounded, _previousMonth),
              const SizedBox(width: 4),
              _monthButton(Icons.chevron_right_rounded, _nextMonth),
            ],
          ),
          const SizedBox(height: 5),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              monthTitle,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _body,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: const [
              'Mon',
              'Tue',
              'Wed',
              'Thu',
              'Fri',
              'Sat',
              'Sun',
            ].map(
              (day) => Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _muted,
                    ),
                  ),
                ),
              ),
            ).toList(),
          ),
          const SizedBox(height: 8),
          ...List.generate(
            cells.length ~/ 7,
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: List.generate(
                  7,
                  (column) {
                    final date = cells[row * 7 + column];
                    return Expanded(
                      child: date == null
                          ? const SizedBox(height: 44)
                          : _buildCalendarDay(date),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              _legendDot(_primary, 'Booking'),
              const SizedBox(width: 16),
              _legendDot(_accent, 'Selected'),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Cancelled bookings do not block dates',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 10,
                    color: _muted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _monthButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: _background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(icon, size: 20, color: _heading),
        ),
      ),
    );
  }

  Widget _buildCalendarDay(DateTime date) {
    final isSelected = _isSameDay(_selectedDate, date);
    final isToday = _isSameDay(DateTime.now(), date);
    final hasBooking = _hasBlockingBookingOn(date);

    return GestureDetector(
      onTap: () => _selectDate(date),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 44,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isSelected ? _softAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
          border: isToday && !isSelected
              ? Border.all(color: _accent.withOpacity(.65))
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 12,
                fontWeight: isSelected || isToday
                    ? FontWeight.w800
                    : FontWeight.w600,
                color: isSelected ? _primary : _heading,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: hasBooking ? 5 : 3,
              height: hasBooking ? 5 : 3,
              decoration: BoxDecoration(
                color: hasBooking ? _primary : _border,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 10,
            color: _body,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildTabs() {
    const labels = ['Upcoming', 'Active', 'Completed', 'Cancelled'];

    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: List.generate(
          labels.length,
          (index) => Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _tabIndex = index;
                  if (index == 3) _selectedDate = null;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _tabIndex == index ? _primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  labels[index],
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _tabIndex == index ? Colors.white : _body,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBookingList() {
    final bookings = _filteredBookings;

    if (bookings.isEmpty) {
      return _emptyState(
        icon: Icons.event_available_rounded,
        title: _selectedDate == null
            ? 'No bookings here'
            : 'No booking on this date',
        message: _selectedDate == null
            ? 'Your bookings will appear here once you make a reservation.'
            : 'Choose another date to view your bookings.',
      );
    }

    return Column(
      children: bookings.map(_buildBookingCard).toList(),
    );
  }

  Widget _buildCancelledHistory() {
    if (_cancelledBookings.isEmpty) {
      return _emptyState(
        icon: Icons.event_busy_rounded,
        title: 'No cancelled bookings',
        message: 'Cancelled booking history will appear here.',
      );
    }

    return Column(
      children: _cancelledBookings.map(_buildBookingCard).toList(),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 36),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              color: _softAccent,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _primary, size: 27),
          ),
          const SizedBox(height: 15),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _heading,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12,
              height: 1.5,
              color: _body,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(Booking booking) {
    final car = booking.car;
    final branch = booking.pickupBranch;
    final image = car?.image ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            offset: const Offset(0, 5),
            color: Colors.black.withOpacity(.025),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => _openBookingDetails(booking),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _carImage(image),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  car?.name ?? 'Rental car',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: _heading,
                                  ),
                                ),
                              ),
                              _statusChip(booking),
                            ],
                          ),
                          const SizedBox(height: 7),
                          Text(
                            '${DateFormat('dd MMM, hh:mm a').format(booking.pickupDateTime)}',
                            style: const TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _body,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'to ${DateFormat('dd MMM, hh:mm a').format(booking.returnDateTime)}',
                            style: const TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 11,
                              color: _body,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(height: 1, color: _border),
                const SizedBox(height: 11),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: _primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        branch?.name ?? 'Pickup location',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _body,
                        ),
                      ),
                    ),
                    Text(
                      '₹${_money(booking.totalAmount)}',
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _heading,
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: _muted,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _carImage(String image) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: SizedBox(
        width: 86,
        height: 76,
        child: image.isEmpty
            ? Container(
                color: _background,
                child: const Icon(
                  Icons.directions_car_filled_rounded,
                  color: _muted,
                  size: 30,
                ),
              )
            : Image.network(
                image,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: _background,
                  child: const Icon(
                    Icons.directions_car_filled_rounded,
                    color: _muted,
                    size: 30,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _statusChip(Booking booking) {
    final String label;
    final Color bg;
    final Color fg;

    switch (booking.status) {
      case BookingStatus.pending:
        label = 'Pending';
        bg = const Color(0xFFFFF7E6);
        fg = const Color(0xFF9A6700);
        break;
      case BookingStatus.confirmed:
        label = 'Confirmed';
        bg = _softAccent;
        fg = _primary;
        break;
      case BookingStatus.pickupPending:
        label = 'Pickup';
        bg = _softAccent;
        fg = _primary;
        break;
      case BookingStatus.active:
        label = 'Active';
        bg = const Color(0xFFE9F7EF);
        fg = const Color(0xFF237A4B);
        break;
      case BookingStatus.returnPending:
        label = 'Return';
        bg = const Color(0xFFFFF7E6);
        fg = const Color(0xFF9A6700);
        break;
      case BookingStatus.completed:
        label = 'Completed';
        bg = const Color(0xFFF0F2F1);
        fg = _body;
        break;
      case BookingStatus.cancelled:
        label = 'Cancelled';
        bg = const Color(0xFFFFEEEE);
        fg = const Color(0xFFB42318);
        break;
      case BookingStatus.rejected:
        label = 'Rejected';
        bg = const Color(0xFFFFEEEE);
        fg = const Color(0xFFB42318);
        break;
      case BookingStatus.noShow:
        label = 'No show';
        bg = const Color(0xFFF0F2F1);
        fg = _body;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Manrope',
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }

  String _money(double value) {
    return NumberFormat('#,##0.00').format(value);
  }

  Future<void> _openBookingDetails(Booking booking) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustomerBookingDetailsScreen(
          booking: booking,
          tenantId: widget.tenantId,
        ),
      ),
    );

    if (mounted) {
      await _loadBookings();
    }
  }
}
