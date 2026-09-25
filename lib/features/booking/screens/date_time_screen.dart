import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import 'package:customer_app_car_rental/features/cars/models/car.dart';
import 'branch_selection_screen.dart';
import 'package:customer_app_car_rental/features/admin/availability/services/admin_availability_service.dart';
import '../../pricing/models/km_pricing_package.dart';
import '../../pricing/models/pricing_profile.dart';
import '../../pricing/models/pricing_config.dart';

class DateTimeScreen extends StatefulWidget {
  final Car car;
  final PricingProfile pricingProfile;
  final String rentalType;
  final KmPricingPackage selectedPackage;

  const DateTimeScreen({
    super.key,
    required this.car,
    required this.pricingProfile,
    required this.rentalType,
    required this.selectedPackage,
  });

  @override
  State<DateTimeScreen> createState() => _DateTimeScreenState();
}

class _DateTimeScreenState extends State<DateTimeScreen> {
  // ============================================================
  // FIXED PREMIUM PALETTE
  // ============================================================

  static const Color primary = Color(0xFF0F766E);
  static const Color accent = Color(0xFF14B8A6);
  static const Color background = Color(0xFFF8FAF9);
  static const Color card = Color(0xFFFFFFFF);
  static const Color softAccent = Color(0xFFE6FFFB);
  static const Color heading = Color(0xFF17201F);
  static const Color body = Color(0xFF66706E);
  static const Color muted = Color(0xFF94A09D);
  static const Color border = Color(0xFFE5EBE9);

  // ============================================================
  // SHARED AVAILABILITY ENGINE
  // ============================================================

  /// Customer and Admin intentionally use the exact same availability
  /// service. There is no customer-specific availability calculation here.
  final AdminAvailabilityService _availabilityService =
      AdminAvailabilityService.instance;

  String get _tenantId => AppConfig.tenant.tenantId;

  /// Snapshot used by the calendar UI for the currently visible month.
  ///
  /// The actual selected rental range is ALWAYS re-checked with
  /// getAvailabilityForRange(), including cross-month rentals.
  AdminAvailabilitySnapshot? _availabilitySnapshot;

  // ============================================================
  // DATE/TIME STATE
  // ============================================================

  DateTime? _pickupDate;
  TimeOfDay? _pickupTime;

  DateTime? _returnDate;
  TimeOfDay? _returnTime;

  String? _errorMessage;

  bool _loadingAvailability = true;
  bool _checkingAvailability = false;
  bool _refreshingAvailability = false;
  bool _datesConfirmed = false;
  DateTime? _lastAvailabilityCheckedAt;

  // ============================================================
  // PRICING STATE
  // ============================================================

  late PricingProfile _pricingProfile;
  late KmPricingPackage _selectedPackage;
  late RentalType _rentalType;

  bool _pricingReady = false;

  int get _minimumHours =>
      _pricingProfile.minimumHoursFor(_selectedPackage.id);

  int get _minimumDays =>
      _pricingProfile.minimumDaysFor(_selectedPackage.id);

  double get _extraHourRate =>
      _pricingProfile.extraHourRateFor(_selectedPackage.id);

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _pricingProfile = widget.pricingProfile;
    _selectedPackage = widget.selectedPackage;
    _rentalType =
        RentalType.fromString(widget.rentalType) ?? RentalType.daily;

    _pricingReady = _pricingProfile.getPackage(
          _selectedPackage.id,
          rentalType: _rentalType,
        ) !=
        null;

    _setDefaultDateTime();
    _loadAvailability();
  }

  void _setDefaultDateTime() {
    final now = DateTime.now();

    // Default pickup: next full hour.
    final pickup = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour + 1,
    );

    final pickupDate = DateTime(
      pickup.year,
      pickup.month,
      pickup.day,
    );

    final returnDateTime = pickup.add(
      const Duration(days: 1),
    );

    setState(() {
      _pickupDate = pickupDate;
      _pickupTime = TimeOfDay(
        hour: pickup.hour,
        minute: 0,
      );
      _returnDate = DateTime(
        returnDateTime.year,
        returnDateTime.month,
        returnDateTime.day,
      );
      _returnTime = TimeOfDay(
        hour: returnDateTime.hour,
        minute: 0,
      );
      _datesConfirmed = false;
      _calendarMonth = DateTime(
        pickupDate.year,
        pickupDate.month,
        1,
      );
    });
  }

  // ============================================================
  // DATE HELPERS
  // ============================================================

  DateTime get _today {
    final now = DateTime.now();

    return DateTime(
      now.year,
      now.month,
      now.day,
    );
  }

  DateTime _combine(
    DateTime date,
    TimeOfDay time,
  ) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  DateTime? get _pickupDateTime {
    if (_pickupDate == null ||
        _pickupTime == null) {
      return null;
    }

    return _combine(
      _pickupDate!,
      _pickupTime!,
    );
  }

  DateTime? get _returnDateTime {
    if (_returnDate == null ||
        _returnTime == null) {
      return null;
    }

    return _combine(
      _returnDate!,
      _returnTime!,
    );
  }

  Duration? get _rentalDuration {
    final pickup = _pickupDateTime;
    final returnTime = _returnDateTime;

    if (pickup == null ||
        returnTime == null) {
      return null;
    }

    return returnTime.difference(pickup);
  }

  // ============================================================
  // FORMATTERS
  // ============================================================

  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'Select date';
    }

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) {
      return 'Select time';
    }

    return time.format(context);
  }

  String get _durationText {
    final duration = _rentalDuration;

    if (duration == null ||
        duration.inMinutes <= 0) {
      return 'Select pickup and return';
    }

    final totalMinutes = duration.inMinutes;

    final days = totalMinutes ~/ (24 * 60);
    final remaining =
        totalMinutes % (24 * 60);

    final hours = remaining ~/ 60;
    final minutes = remaining % 60;

    final parts = <String>[];

    if (days > 0) {
      parts.add(
        '$days ${days == 1 ? 'day' : 'days'}',
      );
    }

    if (hours > 0) {
      parts.add(
        '$hours ${hours == 1 ? 'hour' : 'hours'}',
      );
    }

    if (minutes > 0) {
      parts.add(
        '$minutes ${minutes == 1 ? 'minute' : 'minutes'}',
      );
    }

    return parts.isEmpty
        ? 'Less than 1 minute'
        : parts.join(' ');
  }

  // ============================================================
  // PRICING HELPERS
  // ============================================================

  String _formatMoney(double value) {
    if (value == value.roundToDouble()) {
      return '₹${value.toInt()}';
    }
    return '₹${value.toStringAsFixed(0)}';
  }

  double _priceForDate(DateTime date) {
    if (!_pricingReady) return 0;
    return _pricingProfile.priceFor(
      rentalType: _rentalType,
      package: _selectedPackage,
      date: date,
    );
  }

  bool _isSpecialPrice(DateTime date) {
    if (!_pricingReady) return false;
    final special = _pricingProfile.specialRateForDate(date);
    if (special == null || !special.isActive) return false;
    return special.priceFor(
          rentalType: _rentalType,
          packageId: _selectedPackage.id,
        ) !=
        null;
  }

  String _calendarPriceText(DateTime date) {
    final price = _priceForDate(date);
    if (price <= 0) return '';
    return _rentalType == RentalType.hourly
        ? '${_formatMoney(price)}/h'
        : _formatMoney(price);
  }

  int _wholeDays(DateTime start, DateTime end) {
    if (!end.isAfter(start)) return 0;
    return end.difference(start).inMinutes ~/ (24 * 60);
  }

  int _billableHourlyHours(DateTime start, DateTime end) {
    if (!end.isAfter(start)) return 0;
    final minutes = end.difference(start).inMinutes;
    return (minutes / 60).ceil();
  }

  bool _meetsMinimumBookingRule(DateTime start, DateTime end) {
    if (!end.isAfter(start)) return false;

    if (_rentalType == RentalType.hourly) {
      final minimum = _minimumHours < 1 ? 1 : _minimumHours;
      return _billableHourlyHours(start, end) >= minimum;
    }

    final minimum = _minimumDays < 1 ? 1 : _minimumDays;
    return _wholeDays(start, end) >= minimum;
  }

  String _minimumRuleText() {
    if (_rentalType == RentalType.hourly) {
      final value = _minimumHours < 1 ? 1 : _minimumHours;
      return 'Min ${value} hour${value == 1 ? '' : 's'}';
    }
    final value = _minimumDays < 1 ? 1 : _minimumDays;
    return 'Min ${value} day${value == 1 ? '' : 's'}';
  }

  String _extraHourText() {
    if (_rentalType != RentalType.daily || _extraHourRate <= 0) {
      return '';
    }
    return 'Extra hour ${_formatMoney(_extraHourRate)}';
  }

  bool _validateMinimumBeforeConfirm() {
    final pickup = _pickupDateTime;
    final returnTime = _returnDateTime;
    if (pickup == null || returnTime == null) return false;

    if (_meetsMinimumBookingRule(pickup, returnTime)) return true;

    setState(() {
      if (_rentalType == RentalType.hourly) {
        final minimum = _minimumHours < 1 ? 1 : _minimumHours;
        _errorMessage =
            'This package requires a minimum booking of $minimum hour${minimum == 1 ? '' : 's'}.';
      } else {
        final minimum = _minimumDays < 1 ? 1 : _minimumDays;
        _errorMessage =
            'This package requires a minimum booking of $minimum day${minimum == 1 ? '' : 's'}.';
      }
    });
    return false;
  }

  Widget _buildPricingRuleCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: softAccent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.sell_rounded,
                  color: primary,
                  size: 17,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_selectedPackage.name} • ${_rentalType.label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: heading,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _rentalType == RentalType.hourly
                          ? '${_formatMoney(_selectedPackage.safeHourlyRate)} / hour'
                          : '${_formatMoney(_selectedPackage.safeDailyRate)} / day',
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _ruleChip(_minimumRuleText()),
              if (_extraHourText().isNotEmpty)
                _ruleChip(_extraHourText()),
              _ruleChip(
                _selectedPackage.unlimitedKm
                    ? 'Unlimited KM'
                    : '${_selectedPackage.safeIncludedKm} KM included',
              ),
              if (!_selectedPackage.unlimitedKm &&
                  _selectedPackage.safeExtraKmRate > 0)
                _ruleChip(
                  '${_formatMoney(_selectedPackage.safeExtraKmRate)} / extra KM',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ruleChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: border),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          color: body,
        ),
      ),
    );
  }

  // ============================================================
  // SHARED AVAILABILITY
  // ============================================================

  /// Loads the visible calendar month through the same availability engine
  /// used by the Admin screens.
  ///
  /// This snapshot is only for rendering day states. Exact booking
  /// availability is checked again against the complete rental range before
  /// the customer continues.
  Future<void> _loadAvailability() async {
    if (!mounted) return;

    setState(() {
      _loadingAvailability = true;
      _errorMessage = null;
    });

    try {
      final snapshot = await _availabilityService.getMonthAvailability(
        month: _calendarMonth,
        tenantId: _tenantId,
      );

      if (!mounted) return;

      setState(() {
        _availabilitySnapshot = snapshot;
        _loadingAvailability = false;
        _lastAvailabilityCheckedAt = DateTime.now();
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _availabilitySnapshot = null;
        _loadingAvailability = false;
        _errorMessage = 'Unable to check vehicle availability.';
      });
    }
  }

  /// Performs a fresh, exact availability check using the shared Admin
  /// availability engine. This intentionally reloads Firebase data so a
  /// recently-created booking/block is not missed.
  Future<bool> _isRangeAvailable(
    DateTime start,
    DateTime end,
  ) async {
    if (!end.isAfter(start)) return false;

    try {
      final snapshot = await _availabilityService.getAvailabilityForRange(
        rangeStart: start,
        rangeEnd: end,
        tenantId: _tenantId,
      );

      final matchingCars = snapshot.cars
          .where((car) => car.id == widget.car.id)
          .toList();
      final freshCar = matchingCars.isEmpty ? null : matchingCars.first;

      if (freshCar == null) return false;

      return _availabilityService.isCarAvailableForRange(
        car: freshCar,
        start: start,
        end: end,
        bookings: snapshot.bookings,
        blocks: snapshot.blocks,
      );
    } catch (_) {
      return false;
    }
  }

  // ============================================================
  // SINGLE RANGE CALENDAR
  // ============================================================

  DateTime _calendarMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );

  bool _selectingPickupDate = true;

  // Calendar range dragging.
  DateTime? _dragAnchorDate;
  DateTime? _dragCurrentDate;
  bool _isDraggingRange = false;
  String _dragMode = 'new';

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  bool _sameDate(DateTime a, DateTime b) {
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day;
  }

  DateTime _monthDate(int year, int month) {
    return DateTime(year, month, 1);
  }

  String _monthTitle(DateTime month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[month.month - 1]} ${month.year}';
  }

  void _previousMonth() {
    final previous = DateTime(
      _calendarMonth.year,
      _calendarMonth.month - 1,
      1,
    );

    final currentMonth = _monthDate(_today.year, _today.month);

    if (previous.isBefore(currentMonth)) {
      return;
    }

    setState(() {
      _calendarMonth = previous;
    });

    _loadAvailability();
  }

  /// Selects a date from the date dropdown/calendar while preserving the
  /// pickup -> return flow used by the two independent date/time popups.
  ///
  /// Pickup selection clears the return endpoint because an old return date
  /// may no longer be valid. Return selection is allowed only on/after pickup.
  void _selectCalendarDate(DateTime date) {
    final selectedDate = _dateOnly(date);
    final state = _getCalendarDayState(selectedDate);

    if (state == _CalendarDayState.past ||
        state == _CalendarDayState.full) {
      return;
    }

    if (!_selectingPickupDate &&
        _pickupDate != null &&
        selectedDate.isBefore(_dateOnly(_pickupDate!))) {
      setState(() {
        _errorMessage = 'Return date cannot be before pickup date.';
      });
      return;
    }

    setState(() {
      _datesConfirmed = false;
      _errorMessage = null;

      if (_selectingPickupDate) {
        _pickupDate = selectedDate;
        _pickupTime = null;
        _returnDate = null;
        _returnTime = null;

        // The next step after choosing pickup is return date.
        _selectingPickupDate = false;
      } else {
        // Keep the already-selected pickup intact and replace only return.
        _returnDate = selectedDate;
        _returnTime = null;
      }

      _calendarMonth = DateTime(
        selectedDate.year,
        selectedDate.month,
        1,
      );
    });
  }

  /// Clears both endpoints and their times so the customer can start again.
  void _resetDateSelection() {
    setState(() {
      _selectingPickupDate = true;
      _datesConfirmed = false;
      _pickupDate = null;
      _pickupTime = null;
      _returnDate = null;
      _returnTime = null;
      _errorMessage = null;
      _calendarMonth = DateTime(
        _today.year,
        _today.month,
        1,
      );
    });
  }

  void _nextMonth() {
    setState(() {
      _calendarMonth = DateTime(
        _calendarMonth.year,
        _calendarMonth.month + 1,
        1,
      );
    });

    _loadAvailability();
  }

  List<DateTime?> _calendarDays(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth =
        DateTime(month.year, month.month + 1, 0).day;

    // Monday = 1 ... Sunday = 7.
    final leadingEmpty = firstDay.weekday - 1;
    final cells = <DateTime?>[];

    for (var i = 0; i < leadingEmpty; i++) {
      cells.add(null);
    }

    for (var day = 1; day <= daysInMonth; day++) {
      cells.add(DateTime(month.year, month.month, day));
    }

    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    return cells;
  }

  _CalendarDayState _getCalendarDayState(DateTime date) {
    final today = _today;

    if (_dateOnly(date).isBefore(today)) {
      return _CalendarDayState.past;
    }

    if (_loadingAvailability) {
      return _CalendarDayState.available;
    }

    final snapshot = _availabilitySnapshot;
    if (snapshot == null) {
      return _CalendarDayState.full;
    }

    final matchingCars = snapshot.cars
        .where((item) => item.id == widget.car.id)
        .toList();
    final car = matchingCars.isEmpty ? null : matchingCars.first;

    if (car == null || !car.isActive || !car.isAvailable) {
      return _CalendarDayState.full;
    }

    final status = car.status.trim().toLowerCase();
    if (status == 'inactive' || status == 'unavailable') {
      return _CalendarDayState.full;
    }

    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    final bookings = _availabilityService.conflictsForCar(
      carId: widget.car.id,
      start: dayStart,
      end: dayEnd,
      bookings: snapshot.bookings,
    );
    final blocks = _availabilityService.blocksForCar(
      carId: widget.car.id,
      start: dayStart,
      end: dayEnd,
      blocks: snapshot.blocks,
    );

    if (bookings.isEmpty && blocks.isEmpty) {
      return _CalendarDayState.available;
    }

    final intervals = <_AvailabilityInterval>[
      ...bookings.map(
        (item) => _AvailabilityInterval(
          item.pickupDateTime,
          item.returnDateTime,
        ),
      ),
      ...blocks.map(
        (item) => _AvailabilityInterval(
          item.startDateTime,
          item.endDateTime,
        ),
      ),
    ]..sort((a, b) => a.start.compareTo(b.start));

    var cursor = dayStart;

    for (final interval in intervals) {
      final start = interval.start.isBefore(dayStart)
          ? dayStart
          : interval.start;
      final end = interval.end.isAfter(dayEnd)
          ? dayEnd
          : interval.end;

      if (start.isAfter(cursor)) {
        return _CalendarDayState.partial;
      }

      if (end.isAfter(cursor)) {
        cursor = end;
      }

      if (!cursor.isBefore(dayEnd)) {
        return _CalendarDayState.full;
      }
    }

    return cursor.isBefore(dayEnd)
        ? _CalendarDayState.partial
        : _CalendarDayState.full;
  }

  List<_AvailabilityInterval> _intervalsForDate(DateTime date) {
    final snapshot = _availabilitySnapshot;
    if (snapshot == null) return const [];

    final dayStart = _dateOnly(date);
    final dayEnd = dayStart.add(const Duration(days: 1));

    final bookings = _availabilityService.conflictsForCar(
      carId: widget.car.id,
      start: dayStart,
      end: dayEnd,
      bookings: snapshot.bookings,
    );
    final blocks = _availabilityService.blocksForCar(
      carId: widget.car.id,
      start: dayStart,
      end: dayEnd,
      blocks: snapshot.blocks,
    );

    final intervals = <_AvailabilityInterval>[
      ...bookings.map(
        (item) => _AvailabilityInterval(
          item.pickupDateTime,
          item.returnDateTime,
        ),
      ),
      ...blocks.map(
        (item) => _AvailabilityInterval(
          item.startDateTime,
          item.endDateTime,
        ),
      ),
    ];

    intervals.sort((a, b) => a.start.compareTo(b.start));
    return intervals;
  }

  List<_AvailabilityInterval> _availableWindowsForDate(DateTime date) {
    final dayStart = _dateOnly(date);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final intervals = _intervalsForDate(date);
    if (intervals.isEmpty) {
      return [
        _AvailabilityInterval(dayStart, dayEnd),
      ];
    }

    final merged = <_AvailabilityInterval>[];
    for (final interval in intervals) {
      final start = interval.start.isBefore(dayStart)
          ? dayStart
          : interval.start;
      final end = interval.end.isAfter(dayEnd) ? dayEnd : interval.end;
      if (!end.isAfter(start)) continue;

      if (merged.isEmpty || start.isAfter(merged.last.end)) {
        merged.add(_AvailabilityInterval(start, end));
      } else if (end.isAfter(merged.last.end)) {
        final previous = merged.removeLast();
        merged.add(_AvailabilityInterval(previous.start, end));
      }
    }

    final windows = <_AvailabilityInterval>[];
    var cursor = dayStart;
    for (final blocked in merged) {
      if (blocked.start.isAfter(cursor)) {
        windows.add(_AvailabilityInterval(cursor, blocked.start));
      }
      if (blocked.end.isAfter(cursor)) cursor = blocked.end;
    }
    if (cursor.isBefore(dayEnd)) {
      windows.add(_AvailabilityInterval(cursor, dayEnd));
    }
    return windows;
  }

  String _intervalText(_AvailabilityInterval interval) {
    return '${_formatTime(TimeOfDay.fromDateTime(interval.start))} - '
        '${_formatTime(TimeOfDay.fromDateTime(interval.end))}';
  }

  Future<void> _showUnavailableDialog({
    required DateTime requestedStart,
    required DateTime requestedEnd,
    String? message,
  }) async {
    if (!mounted) return;

    final date = _dateOnly(requestedStart);
    final booked = _intervalsForDate(date);
    final windows = _availableWindowsForDate(date)
        .where((item) => item.end.difference(item.start).inMinutes >= 30)
        .take(5)
        .toList();

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 22),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: border),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x24000000),
                  blurRadius: 30,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E8),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(
                        Icons.event_busy_rounded,
                        color: Color(0xFFE17B2D),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'This time is not available',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: heading,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  '${message ?? 'The vehicle is already booked or blocked during the selected period.'}\n\nRequested: ${_formatTime(TimeOfDay.fromDateTime(requestedStart))} - ${_formatTime(TimeOfDay.fromDateTime(requestedEnd))}',
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 12,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                    color: body,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAF9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDate(date),
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: heading,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (booked.isNotEmpty) ...[
                        const Text(
                          'Booked / blocked',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: muted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ...booked.take(5).map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 5),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.lock_clock_rounded,
                                      size: 14,
                                      color: Color(0xFFE05252),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _intervalText(item),
                                      style: const TextStyle(
                                        fontFamily: 'Manrope',
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: heading,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                      ] else
                        const Text(
                          'The selected rental range is not available for this vehicle.',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: body,
                          ),
                        ),
                      if (windows.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Available windows',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: muted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ...windows.map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 5),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      size: 14,
                                      color: primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _intervalText(item),
                                      style: const TextStyle(
                                        fontFamily: 'Manrope',
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: heading,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Choose another time',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSelectedDateAvailability() {
    final focusedDate = _selectingPickupDate
        ? _pickupDate
        : (_returnDate ?? _pickupDate);
    if (focusedDate == null || _loadingAvailability) {
      return const SizedBox.shrink();
    }

    final state = _getCalendarDayState(focusedDate);
    if (state == _CalendarDayState.available) {
      return const SizedBox.shrink();
    }

    final booked = _intervalsForDate(focusedDate);
    final windows = _availableWindowsForDate(focusedDate)
        .where((item) => item.end.difference(item.start).inMinutes >= 30)
        .take(4)
        .toList();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3D5AF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 17, color: Color(0xFFE17B2D)),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '${_formatDate(focusedDate)} is partially booked',
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: heading,
                  ),
                ),
              ),
            ],
          ),
          if (booked.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Unavailable: ${booked.map(_intervalText).join(', ')}',
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: body,
              ),
            ),
          ],
          if (windows.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Available: ${windows.map(_intervalText).join(', ')}',
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: primary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<DateTime> _dropdownDates() {
    final first = _calendarMonth.isBefore(_today)
        ? _today
        : _calendarMonth;
    final last = DateTime(
      _calendarMonth.year,
      _calendarMonth.month + 1,
      0,
    );
    final result = <DateTime>[];
    var cursor = DateTime(first.year, first.month, first.day);
    while (!cursor.isAfter(last)) {
      if (!_dateOnly(cursor).isBefore(_today)) {
        result.add(cursor);
      }
      cursor = cursor.add(const Duration(days: 1));
    }

    void addIfMissing(DateTime? value) {
      if (value == null) return;
      final normalized = _dateOnly(value);
      if (!result.any((item) => _sameDate(item, normalized)) &&
          !normalized.isBefore(_today)) {
        result.add(normalized);
      }
    }

    addIfMissing(_pickupDate);
    addIfMissing(_returnDate);
    result.sort();
    return result;
  }

  Widget _dateDropdown({
    required String label,
    required DateTime? value,
    required bool pickup,
  }) {
    final dates = _dropdownDates();
    final validValue = value != null &&
            dates.any((item) => _sameDate(item, value))
        ? dates.firstWhere((item) => _sameDate(item, value))
        : null;

    return DropdownButtonFormField<DateTime>(
      value: validValue,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
        filled: true,
        fillColor: const Color(0xFFF8FAF9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary, width: 1.4),
        ),
      ),
      items: dates.map((date) {
        final state = _getCalendarDayState(date);
        final disabled = state == _CalendarDayState.full ||
            state == _CalendarDayState.past ||
            (!pickup &&
                _pickupDate != null &&
                date.isBefore(_dateOnly(_pickupDate!)));

        return DropdownMenuItem<DateTime>(
          value: date,
          enabled: !disabled,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _formatDate(date),
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: disabled ? muted : heading,
                  ),
                ),
              ),
              if (state == _CalendarDayState.partial)
                const Text(
                  'Partially booked',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFE17B2D),
                  ),
                ),
              if (state == _CalendarDayState.available)
                const Text(
                  'Available',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: primary,
                  ),
                ),
              if (state == _CalendarDayState.full)
                const Text(
                  'Booked',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFE05252),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
      onChanged: _loadingAvailability
          ? null
          : (date) {
              if (date == null) return;
              if (pickup) {
                _selectingPickupDate = true;
                _selectCalendarDate(date);
              } else {
                _selectingPickupDate = false;
                _selectCalendarDate(date);
              }
            },
    );
  }

  Widget _buildDateSelectionCard() {
    final pickupState = _pickupDate == null
        ? null
        : _getCalendarDayState(_pickupDate!);
    final returnState = _returnDate == null
        ? null
        : _getCalendarDayState(_returnDate!);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: softAccent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 9),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rental dates',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: heading,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Tap Pickup or Return to open its calendar and time picker',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (_pickupDate != null || _returnDate != null)
                InkWell(
                  onTap: _resetDateSelection,
                  borderRadius: BorderRadius.circular(10),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(
                      Icons.refresh_rounded,
                      size: 18,
                      color: primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _dateChoiceTile(
                  label: 'Pickup',
                  date: _pickupDate,
                  state: pickupState,
                  active: _selectingPickupDate,
                  icon: Icons.login_rounded,
                  onTap: () => _openDateSelectionSheet(pickup: true),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _dateChoiceTile(
                  label: 'Return',
                  date: _returnDate,
                  state: returnState,
                  active: !_selectingPickupDate && _pickupDate != null,
                  icon: Icons.logout_rounded,
                  onTap: () => _openDateSelectionSheet(pickup: false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dateChoiceTile({
    required String label,
    required DateTime? date,
    required _CalendarDayState? state,
    required bool active,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final available = state == null || state == _CalendarDayState.available;
    final partial = state == _CalendarDayState.partial;
    final full = state == _CalendarDayState.full;

    return Material(
      color: active ? softAccent : background,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: _loadingAvailability ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active
                  ? const Color(0xFF8EDDD4)
                  : border,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 17, color: primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: muted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      date == null ? 'Select date' : _formatDateShort(date),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: heading,
                      ),
                    ),
                    if (date != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        full
                            ? 'Fully booked'
                            : partial
                                ? 'Partially booked'
                                : available
                                    ? 'Available'
                                    : 'Select date',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: full
                              ? const Color(0xFFE05252)
                              : partial
                                  ? const Color(0xFFB7791F)
                                  : primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: muted),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateShort(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }

  Future<void> _openDateSelectionSheet({required bool pickup}) async {
    if (_loadingAvailability) return;

    // Each endpoint gets its OWN popup. The pickup popup never renders the
    // return selector and the return popup never renders the pickup selector.
    final originalCalendarMonth = _calendarMonth;
    final originalPickupDate = _pickupDate;
    final originalPickupTime = _pickupTime;
    final originalReturnDate = _returnDate;
    final originalReturnTime = _returnTime;

    DateTime? draftDate = pickup ? _pickupDate : _returnDate;
    TimeOfDay? draftTime = pickup ? _pickupTime : _returnTime;
    DateTime popupMonth = DateTime(
      (draftDate ?? _today).year,
      (draftDate ?? _today).month,
      1,
    );

    // Keep the parent date temporarily in sync while the popup is open so
    // existing availability helpers can calculate the correct time windows.
    void applyDraftDate(DateTime date, StateSetter sheetSetState) {
      final cleanDate = _dateOnly(date);
      draftDate = cleanDate;
      draftTime = null;

      setState(() {
        if (pickup) {
          _pickupDate = cleanDate;
          _pickupTime = null;
          _datesConfirmed = false;

          // A pickup-date change can invalidate an existing return date.
          if (_returnDate != null &&
              _returnDate!.isBefore(cleanDate)) {
            _returnDate = null;
            _returnTime = null;
          }
        } else {
          _returnDate = cleanDate;
          _returnTime = null;
          _datesConfirmed = false;
        }
        _errorMessage = null;
      });

      sheetSetState(() {});
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.34),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, sheetSetState) {
            final cells = _calendarDays(popupMonth);
            final canGoPrevious = !popupMonth.isAtSameMomentAs(
              _monthDate(_today.year, _today.month),
            );

            final selectedDate = draftDate;
            final selectedTime = draftTime;
            final slots = selectedDate == null
                ? const <TimeOfDay>[]
                : _availableTimeSlots(selectedDate)
                    .where((time) {
                      if (pickup) {
                        return _isTimeSlotValidForDate(
                          selectedDate,
                          time,
                          pickup: true,
                        );
                      }

                      final pickupMoment = _pickupDateTime;
                      if (pickupMoment == null) return false;
                      final candidate = _combine(selectedDate, time);
                      return candidate.isAfter(pickupMoment) &&
                          _meetsMinimumBookingRule(pickupMoment, candidate);
                    })
                    .toList();

            final dayState = selectedDate == null
                ? null
                : _getCalendarDayState(selectedDate);
            final windows = selectedDate == null
                ? const <_AvailabilityInterval>[]
                : _availableWindowsForDate(selectedDate)
                    .where((item) => item.end.isAfter(item.start))
                    .take(5)
                    .toList();

            Future<void> chooseTime(TimeOfDay time) async {
              if (selectedDate == null) return;

              final moment = _combine(selectedDate, time);

              if (pickup) {
                if (!_isTimeSlotValidForDate(
                  selectedDate,
                  time,
                  pickup: true,
                )) {
                  return;
                }

                final available = await _isRangeAvailable(
                  moment,
                  moment.add(const Duration(minutes: 1)),
                );
                if (!mounted) return;

                if (!available) {
                  await _showUnavailableDialog(
                    requestedStart: moment,
                    requestedEnd: moment.add(const Duration(minutes: 1)),
                    message:
                        'This pickup time is already booked or blocked. Choose another available time.',
                  );
                  return;
                }

                setState(() {
                  _pickupDate = selectedDate;
                  _pickupTime = time;
                  _errorMessage = null;
                  _datesConfirmed = false;
                });
                if (mounted) Navigator.pop(sheetContext);
                return;
              }

              final pickupMoment = _pickupDateTime;
              if (pickupMoment == null) return;

              if (!moment.isAfter(pickupMoment)) {
                setState(() {
                  _errorMessage = 'Return time must be after pickup time.';
                });
                return;
              }

              if (!_meetsMinimumBookingRule(pickupMoment, moment)) {
                _validateMinimumBeforeConfirm();
                return;
              }

              final available = await _isRangeAvailable(
                pickupMoment,
                moment,
              );
              if (!mounted) return;

              if (!available) {
                await _showUnavailableDialog(
                  requestedStart: pickupMoment,
                  requestedEnd: moment,
                  message:
                      'The selected rental period overlaps an existing booking or vehicle block. Choose another available return time.',
                );
                return;
              }

              setState(() {
                _returnDate = selectedDate;
                _returnTime = time;
                _errorMessage = null;
                _datesConfirmed = true;
                _selectingPickupDate = false;
              });

              if (mounted) Navigator.pop(sheetContext);
            }

            return SafeArea(
              top: false,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.90,
                ),
                padding: const EdgeInsets.fromLTRB(16, 9, 16, 14),
                decoration: const BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: border,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 11),
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: softAccent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              pickup
                                  ? Icons.login_rounded
                                  : Icons.logout_rounded,
                              color: primary,
                              size: 19,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pickup
                                      ? 'Choose pickup date & time'
                                      : 'Choose return date & time',
                                  style: const TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    color: heading,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  pickup
                                      ? 'Select a date, then choose an available pickup time.'
                                      : 'Select a date, then choose an available return time.',
                                  style: const TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            onPressed: () {
                              _pickupDate = originalPickupDate;
                              _pickupTime = originalPickupTime;
                              _returnDate = originalReturnDate;
                              _returnTime = originalReturnTime;
                              _calendarMonth = originalCalendarMonth;
                              Navigator.pop(sheetContext);
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: pickup ? softAccent : const Color(0xFFF5FAF9),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: pickup
                                ? const Color(0xFFBDEBE5)
                                : border,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              pickup
                                  ? Icons.login_rounded
                                  : Icons.logout_rounded,
                              color: primary,
                              size: 17,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                selectedDate == null
                                    ? (pickup
                                        ? 'Select pickup date'
                                        : 'Select return date')
                                    : '${_formatDateShort(selectedDate)}${selectedTime == null ? '' : ' • ${_formatTime(selectedTime)}'}',
                                style: const TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: heading,
                                ),
                              ),
                            ),
                            if (selectedDate != null && selectedTime != null)
                              const Icon(
                                Icons.check_circle_rounded,
                                color: primary,
                                size: 18,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 13),
                      Row(
                        children: [
                          IconButton(
                            tooltip: 'Previous month',
                            onPressed: canGoPrevious
                                ? () async {
                                    popupMonth = DateTime(
                                      popupMonth.year,
                                      popupMonth.month - 1,
                                      1,
                                    );
                                    _calendarMonth = popupMonth;
                                    await _loadAvailability();
                                    sheetSetState(() {});
                                  }
                                : null,
                            icon: const Icon(Icons.chevron_left_rounded),
                          ),
                          Expanded(
                            child: Text(
                              _monthTitle(popupMonth),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: heading,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Next month',
                            onPressed: () async {
                              popupMonth = DateTime(
                                popupMonth.year,
                                popupMonth.month + 1,
                                1,
                              );
                              _calendarMonth = popupMonth;
                              await _loadAvailability();
                              sheetSetState(() {});
                            },
                            icon: const Icon(Icons.chevron_right_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: const [
                          _WeekdayLabel('MON'),
                          _WeekdayLabel('TUE'),
                          _WeekdayLabel('WED'),
                          _WeekdayLabel('THU'),
                          _WeekdayLabel('FRI'),
                          _WeekdayLabel('SAT'),
                          _WeekdayLabel('SUN'),
                        ],
                      ),
                      const SizedBox(height: 7),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: cells.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 6,
                          crossAxisSpacing: 5,
                          childAspectRatio: 0.92,
                        ),
                        itemBuilder: (context, index) {
                          final date = cells[index];
                          if (date == null) return const SizedBox.shrink();

                          final state = _getCalendarDayState(date);
                          final isSelected = selectedDate != null &&
                              _sameDate(selectedDate, date);
                          final isPickupDate = _pickupDate != null &&
                              _sameDate(_pickupDate!, date);
                          final isReturnDate = _returnDate != null &&
                              _sameDate(_returnDate!, date);
                          final beforePickup = !pickup &&
                              _pickupDate != null &&
                              _dateOnly(date).isBefore(
                                _dateOnly(_pickupDate!),
                              );
                          final canSelect = state != _CalendarDayState.past &&
                              state != _CalendarDayState.full &&
                              !beforePickup;
                          final price = _calendarPriceText(date);

                          Color fill = card;
                          Color outline = border;
                          Color numberColor = heading;

                          if (state == _CalendarDayState.past) {
                            fill = const Color(0xFFF2F5F4);
                            numberColor = muted;
                          } else if (state == _CalendarDayState.full) {
                            fill = const Color(0xFFFFF1F1);
                            outline = const Color(0xFFF1C7C7);
                            numberColor = const Color(0xFFD35454);
                          } else if (state == _CalendarDayState.partial) {
                            fill = const Color(0xFFFFFBF0);
                            outline = const Color(0xFFF1D59A);
                          }

                          if (isSelected) {
                            fill = primary;
                            outline = primary;
                            numberColor = Colors.white;
                          } else if (isPickupDate && !pickup) {
                            outline = primary;
                          } else if (isReturnDate && pickup) {
                            outline = primary;
                          }

                          return InkWell(
                            onTap: canSelect
                                ? () => applyDraftDate(date, sheetSetState)
                                : () {
                                    if (state == _CalendarDayState.full) {
                                      _showUnavailableDialog(
                                        requestedStart: date,
                                        requestedEnd:
                                            date.add(const Duration(days: 1)),
                                        message:
                                            'This date is fully booked or blocked. Choose another available date.',
                                      );
                                    }
                                  },
                            borderRadius: BorderRadius.circular(13),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: fill,
                                borderRadius: BorderRadius.circular(13),
                                border: Border.all(color: outline),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '${date.day}',
                                    style: TextStyle(
                                      fontFamily: 'Manrope',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: numberColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    price,
                                    maxLines: 1,
                                    overflow: TextOverflow.clip,
                                    style: TextStyle(
                                      fontFamily: 'Manrope',
                                      fontSize: 7.5,
                                      fontWeight: FontWeight.w900,
                                      color: isSelected
                                          ? Colors.white
                                          : state == _CalendarDayState.full
                                              ? const Color(0xFFD35454)
                                              : primary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  if (state == _CalendarDayState.partial)
                                    const Text(
                                      'PARTIAL',
                                      style: TextStyle(
                                        fontFamily: 'Manrope',
                                        fontSize: 5.8,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFFB7791F),
                                      ),
                                    )
                                  else if (state == _CalendarDayState.full)
                                    const Text(
                                      'BOOKED',
                                      style: TextStyle(
                                        fontFamily: 'Manrope',
                                        fontSize: 5.8,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFFD35454),
                                      ),
                                    )
                                  else
                                    const SizedBox(height: 6),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 9),
                      Row(
                        children: [
                          const _CalendarLegend(
                            color: accent,
                            label: 'Available',
                          ),
                          const SizedBox(width: 14),
                          const _CalendarLegend(
                            color: Color(0xFFE7B44A),
                            label: 'Partial',
                          ),
                          const SizedBox(width: 14),
                          const _CalendarLegend(
                            color: Color(0xFFD95454),
                            label: 'Booked',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (selectedDate != null) ...[
                        Row(
                          children: [
                            const Icon(
                              Icons.schedule_rounded,
                              size: 17,
                              color: primary,
                            ),
                            const SizedBox(width: 7),
                            const Expanded(
                              child: Text(
                                'Available times',
                                style: TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w900,
                                  color: heading,
                                ),
                              ),
                            ),
                            Text(
                              pickup ? 'Pickup' : 'Return',
                              style: const TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        if (dayState == _CalendarDayState.partial &&
                            windows.isNotEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBF0),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFF1D59A),
                              ),
                            ),
                            child: Text(
                              'Available windows: ${windows.map(_intervalText).join('  •  ')}',
                              style: const TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 9.5,
                                height: 1.35,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF946617),
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        if (slots.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF4F3),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFF1C7C7),
                              ),
                            ),
                            child: Text(
                              pickup
                                  ? 'No available pickup times on this date.'
                                  : 'No return time satisfies availability and the minimum rental rule on this date.',
                              style: const TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFA34444),
                              ),
                            ),
                          )
                        else
                          SizedBox(
                            height: 48,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: slots.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 7),
                              itemBuilder: (context, index) {
                                final time = slots[index];
                                final isSelected = selectedTime != null &&
                                    selectedTime.hour == time.hour &&
                                    selectedTime.minute == time.minute;
                                return InkWell(
                                  onTap: () => chooseTime(time),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    constraints:
                                        const BoxConstraints(minWidth: 76),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? primary
                                          : background,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected
                                            ? primary
                                            : border,
                                      ),
                                    ),
                                    child: Text(
                                      _formatTime(time),
                                      style: TextStyle(
                                        fontFamily: 'Manrope',
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        color: isSelected
                                            ? Colors.white
                                            : heading,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: 9),
                        Text(
                          pickup
                              ? 'Select a pickup time to finish this popup.'
                              : 'Minimum rental rules are applied automatically before selecting a return time.',
                          style: const TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: muted,
                          ),
                        ),
                      ] else
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Text(
                            'Select a date above to see available times.',
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: muted,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    // A popup cancellation should never leave a half-edited endpoint.
    // If a time was not selected, restore the previous values.
    final currentTime = pickup ? _pickupTime : _returnTime;
    if (currentTime == null) {
      setState(() {
        _pickupDate = originalPickupDate;
        _pickupTime = originalPickupTime;
        _returnDate = originalReturnDate;
        _returnTime = originalReturnTime;
        _calendarMonth = originalCalendarMonth;
      });
    }
  }

  bool _isTimeSlotValidForDate(
    DateTime date,
    TimeOfDay time, {
    required bool pickup,
  }) {
    final moment = _combine(date, time);
    if (pickup) {
      return !moment.isBefore(DateTime.now());
    }

    final pickupMoment = _pickupDateTime;
    if (pickupMoment == null || !moment.isAfter(pickupMoment)) {
      return false;
    }

    return _meetsMinimumBookingRule(pickupMoment, moment);
  }

// ============================================================
  // PICKUP TIME
  // ============================================================

  Future<void> _selectPickupTime() async {
    if (_pickupDate == null) {
      setState(() {
        _errorMessage =
            'Please select pickup date first.';
      });

      return;
    }

    if (_loadingAvailability) {
      return;
    }

    final selected =
        await showTimePicker(
      context: context,
      initialTime: _pickupTime ??
          TimeOfDay(
            hour: (DateTime.now().hour + 1) % 24,
            minute: 0,
          ),
      builder: (
        context,
        child,
      ) {
        return Theme(
          data:
              Theme.of(context).copyWith(
            colorScheme:
                const ColorScheme.light(
              primary: primary,
              onPrimary: Colors.white,
              surface: card,
              onSurface: heading,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selected == null ||
        !mounted) {
      return;
    }

    final pickup =
        _combine(
      _pickupDate!,
      selected,
    );

    if (pickup.isBefore(
      DateTime.now(),
    )) {
      setState(() {
        _errorMessage =
            'Pickup time cannot be in the past.';
      });

      return;
    }

    final pickupMomentAvailable = await _isRangeAvailable(
      pickup,
      pickup.add(const Duration(minutes: 1)),
    );

    if (!pickupMomentAvailable) {
      if (mounted) {
        await _showUnavailableDialog(
          requestedStart: pickup,
          requestedEnd: pickup.add(const Duration(minutes: 1)),
          message: 'This pickup time is already booked or blocked. Choose a time before or after the unavailable window.',
        );
      }
      return;
    }

    setState(() {
      _pickupTime = selected;
      _errorMessage = null;

      /*
       * If the new pickup time makes the
       * current return invalid, clear return time.
       */
      final returnDateTime =
          _returnDateTime;

      if (returnDateTime != null &&
          !returnDateTime.isAfter(
            pickup,
          )) {
        _returnTime = null;
      }
    });
  }

  // ============================================================
  // RETURN TIME
  // ============================================================

  Future<void> _selectReturnTime() async {
    if (_returnDate == null) {
      setState(() {
        _errorMessage =
            'Please select return date first.';
      });

      return;
    }

    if (_loadingAvailability) {
      return;
    }

    final selected =
        await showTimePicker(
      context: context,
      initialTime: _returnTime ??
          TimeOfDay(
            hour: (DateTime.now().hour + 1) % 24,
            minute: 0,
          ),
      builder: (
        context,
        child,
      ) {
        return Theme(
          data:
              Theme.of(context).copyWith(
            colorScheme:
                const ColorScheme.light(
              primary: primary,
              onPrimary: Colors.white,
              surface: card,
              onSurface: heading,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selected == null ||
        !mounted) {
      return;
    }

    final returnDateTime =
        _combine(
      _returnDate!,
      selected,
    );

    final pickup =
        _pickupDateTime;

    if (pickup != null &&
        !returnDateTime.isAfter(
          pickup,
        )) {
      setState(() {
        _errorMessage =
            'Return time must be after pickup time.';
      });

      return;
    }

    if (pickup != null) {
      final available = await _isRangeAvailable(
        pickup,
        returnDateTime,
      );

      if (!available) {
        if (mounted) {
          await _showUnavailableDialog(
            requestedStart: pickup,
            requestedEnd: returnDateTime,
            message: 'The selected rental period overlaps an existing booking or vehicle block.',
          );
        }
        return;
      }
    }

    setState(() {
      _returnTime = selected;
      _errorMessage = null;
    });
  }

  Future<void> _refreshAvailability({bool showMessage = false}) async {
    if (_loadingAvailability || _refreshingAvailability || _checkingAvailability) {
      return;
    }

    setState(() {
      _refreshingAvailability = true;
      _errorMessage = null;
    });

    try {
      await _loadAvailability();

      if (!mounted) return;

      if (showMessage && _availabilitySnapshot != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: heading,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            content: const Text(
              'Availability refreshed successfully.',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _refreshingAvailability = false;
        });
      }
    }
  }

  String _lastCheckedText() {
    final checked = _lastAvailabilityCheckedAt;
    if (checked == null) return 'Not checked yet';

    final now = DateTime.now();
    final difference = now.difference(checked);
    if (difference.inSeconds < 10) return 'Checked just now';
    if (difference.inMinutes < 1) return 'Checked ${difference.inSeconds}s ago';
    if (difference.inHours < 1) return 'Checked ${difference.inMinutes}m ago';
    return 'Checked ${difference.inHours}h ago';
  }

  // ============================================================
  // FINAL AVAILABILITY CHECK
  // ============================================================

  Future<bool> _finalAvailabilityCheck() async {
    final pickup = _pickupDateTime;
    final returnDateTime = _returnDateTime;

    if (pickup == null || returnDateTime == null) {
      return false;
    }

    // One authoritative final check. The shared service reloads the car,
    // bookings and vehicle blocks for the COMPLETE requested period.
    return _isRangeAvailable(pickup, returnDateTime);
  }

  // ============================================================
  // CONTINUE
  // ============================================================

  Future<void> _continue() async {
    if (!_datesConfirmed) {
      setState(() {
        _errorMessage = 'Please confirm your pickup and return dates first.';
      });
      return;
    }

    if (_loadingAvailability) {
      return;
    }

    final pickup =
        _pickupDateTime;

    final returnDateTime =
        _returnDateTime;

    if (pickup == null) {
      setState(() {
        _errorMessage =
            'Please select pickup date and time.';
      });

      return;
    }

    if (returnDateTime == null) {
      setState(() {
        _errorMessage =
            'Please select return date and time.';
      });

      return;
    }

    if (pickup.isBefore(
      DateTime.now(),
    )) {
      setState(() {
        _errorMessage =
            'Pickup date and time cannot be in the past.';
      });

      return;
    }

    if (!returnDateTime.isAfter(
      pickup,
    )) {
      setState(() {
        _errorMessage =
            'Return date and time must be after pickup.';
      });

      return;
    }

    
    if (!_meetsMinimumBookingRule(pickup, returnDateTime)) {
      _validateMinimumBeforeConfirm();
      return;
    }

// Final authoritative check. This uses the complete pickup -> return
    // range, so rentals spanning multiple months are handled correctly.
    setState(() {
      _checkingAvailability = true;
      _errorMessage = null;
    });

    final available = await _finalAvailabilityCheck();

    if (!mounted) {
      return;
    }

    if (!available) {
      setState(() {
        _checkingAvailability = false;

        _errorMessage =
            'Sorry, this car is no longer available for the selected time. Please choose another time.';
      });

      await _loadAvailability();

      return;
    }

    setState(() {
      _checkingAvailability = false;
    });

    /*
     * Continue to branch selection.
     *
     * We carry:
     * - car
     * - tenantId
     * - pickupDateTime
     * - returnDateTime
     */
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            BranchSelectionScreen(
  car: widget.car,
  tenantId: _tenantId,
  pickupDateTime: pickup,
  returnDateTime: returnDateTime,
  rentalType: widget.rentalType,
   pricingProfile: widget.pricingProfile,
     selectedPackage: widget.selectedPackage,

),
      ),
    );
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: (_checkingAvailability || _refreshingAvailability)
              ? null
              : () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: heading,
          ),
        ),
        title: const Text(
          'Choose dates & time',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: heading,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Refresh availability',
            onPressed: _refreshingAvailability
                ? null
                : () => _refreshAvailability(showMessage: true),
            icon: _refreshingAvailability
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: primary,
                    ),
                  )
                : const Icon(Icons.refresh_rounded, color: primary, size: 21),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 7, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCarSummary(),
                    const SizedBox(height: 10),
                    _buildPricingRuleCard(),
                    const SizedBox(height: 10),
                    _buildDateSelectionCard(),
                    if (_pickupDateTime != null && _returnDateTime != null) ...[
                      const SizedBox(height: 10),
                      _buildDurationCard(),
                    ],
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 10),
                      _buildError(),
                    ],
                  ],
                ),
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildCarSummary() {
    return Container(
      padding:
          const EdgeInsets.all(12),
      decoration:
          BoxDecoration(
        color: card,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: border,
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius:
                BorderRadius.circular(
              13,
            ),
            child: SizedBox(
              width: 78,
              height: 58,
              child:
                  widget.car.image
                          .isNotEmpty
                      ? Image.network(
                          widget.car.image,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (
                            _,
                            __,
                            ___,
                          ) =>
                                  _carPlaceholder(),
                        )
                      : _carPlaceholder(),
            ),
          ),
          const SizedBox(
            width: 12,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  widget.car.name,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    fontFamily:
                        'Manrope',
                    fontSize: 15,
                    fontWeight:
                        FontWeight.w800,
                    color: heading,
                  ),
                ),
                const SizedBox(
                  height: 4,
                ),
                Text(
                  '${widget.car.type} • ${widget.car.transmission} • ${widget.car.seats} seats',
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    fontFamily:
                        'Manrope',
                    fontSize: 11.5,
                    fontWeight:
                        FontWeight.w500,
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

  Widget _carPlaceholder() {
    return Container(
      color: softAccent,
      child: const Center(
        child: Icon(
          Icons
              .directions_car_rounded,
          color: primary,
          size: 28,
        ),
      ),
    );
  }

  Widget _buildAvailabilityBanner() {
    if (_loadingAvailability) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: primary,
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Checking live availability...',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: body,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(13, 11, 8, 11),
      decoration: BoxDecoration(
        color: softAccent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBDEBE5)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.verified_rounded,
              size: 18,
              color: primary,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Live availability',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: heading,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _lastCheckedText(),
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: body,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Refresh availability',
            onPressed: _refreshingAvailability
                ? null
                : () => _refreshAvailability(showMessage: true),
            icon: _refreshingAvailability
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: primary,
                    ),
                  )
                : const Icon(
                    Icons.refresh_rounded,
                    size: 20,
                    color: primary,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'When do you need the car?',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: heading,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Select your rental dates, then choose the pickup and return times.',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: body,
                    ),
                  ),
                ],
              ),
            ),
            if (_pickupDate != null || _returnDate != null)
              TextButton.icon(
                onPressed: _resetDateSelection,
                icon: const Icon(Icons.restart_alt_rounded, size: 16),
                label: const Text('Reset'),
                style: TextButton.styleFrom(
                  foregroundColor: primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  textStyle: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  List<TimeOfDay> _availableTimeSlots(DateTime date) {
    final windows = _availableWindowsForDate(date);
    final stepMinutes = _rentalType == RentalType.hourly ? 30 : 60;
    final result = <TimeOfDay>[];
    final now = DateTime.now();

    for (final window in windows) {
      var cursor = window.start;
      while (cursor.isBefore(window.end)) {
        final candidate = DateTime(
          date.year,
          date.month,
          date.day,
          cursor.hour,
          cursor.minute,
        );
        if (!candidate.isBefore(now) || !_sameDate(date, _today)) {
          result.add(TimeOfDay(hour: candidate.hour, minute: candidate.minute));
        }
        cursor = cursor.add(Duration(minutes: stepMinutes));
      }
    }

    final unique = <String, TimeOfDay>{};
    for (final item in result) {
      unique['${item.hour}:${item.minute}'] = item;
    }

    return unique.values.toList()
      ..sort((a, b) {
        final am = a.hour * 60 + a.minute;
        final bm = b.hour * 60 + b.minute;
        return am.compareTo(bm);
      });
  }

  bool _isTimeSlotValid(TimeOfDay time, {required bool pickup}) {
    final date = pickup ? _pickupDate : _returnDate;
    if (date == null) return false;

    final moment = _combine(date, time);
    if (pickup && moment.isBefore(DateTime.now())) return false;

    if (!pickup) {
      final pickupDateTime = _pickupDateTime;
      if (pickupDateTime == null || !moment.isAfter(pickupDateTime)) {
        return false;
      }
    }

    return true;
  }

  Future<void> _selectTimeSlot(TimeOfDay time, {required bool pickup}) async {
    final date = pickup ? _pickupDate : _returnDate;
    if (date == null) {
      await _openDateSelectionSheet(pickup: pickup);
      return;
    }

    if (!_isTimeSlotValid(time, pickup: pickup)) return;

    final moment = _combine(date, time);
    final pickupMoment = pickup ? moment : _pickupDateTime;

    if (pickup) {
      final available = await _isRangeAvailable(
        moment,
        moment.add(const Duration(minutes: 1)),
      );
      if (!mounted) return;
      if (!available) {
        await _showUnavailableDialog(
          requestedStart: moment,
          requestedEnd: moment.add(const Duration(minutes: 1)),
          message: 'This pickup time is already booked or blocked. Choose another available time.',
        );
        return;
      }

      setState(() {
        _pickupTime = time;
        _returnTime = _returnDateTime != null &&
                !_returnDateTime!.isAfter(moment)
            ? null
            : _returnTime;
        _errorMessage = null;
        _datesConfirmed = _pickupDate != null && _returnDate != null;
        _selectingPickupDate = false;
      });
    } else {
      final start = pickupMoment;
      if (start == null || !moment.isAfter(start)) return;

      final minimumOk = _meetsMinimumBookingRule(start, moment);
      if (!minimumOk) {
        _validateMinimumBeforeConfirm();
        return;
      }

      final available = await _isRangeAvailable(start, moment);
      if (!mounted) return;
      if (!available) {
        await _showUnavailableDialog(
          requestedStart: start,
          requestedEnd: moment,
          message: 'The selected rental period overlaps an existing booking or vehicle block. Choose another return time.',
        );
        return;
      }

      setState(() {
        _returnTime = time;
        _errorMessage = null;
        _datesConfirmed = true;
      });
    }
  }

  Widget _buildTimeSelection() {
    final pickupSlots = _pickupDate == null
        ? const <TimeOfDay>[]
        : _availableTimeSlots(_pickupDate!);
    final returnSlots = _returnDate == null
        ? const <TimeOfDay>[]
        : _availableTimeSlots(_returnDate!);
    final slots = _selectingPickupDate || _returnTime == null
        ? pickupSlots
        : returnSlots;
    final showingPickup = _selectingPickupDate || _returnDate == null;
    final selectedTime = showingPickup ? _pickupTime : _returnTime;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 18, color: primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Choose time',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: heading,
                  ),
                ),
              ),
              Text(
                _rentalType == RentalType.hourly ? '30 min slots' : '1 hr slots',
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _timeModeButton(
                  label: 'Pickup',
                  value: _pickupDateTime == null
                      ? 'Select date & time'
                      : '${_formatDateShort(_pickupDate!)} • ${_formatTime(_pickupTime)}',
                  active: showingPickup,
                  onTap: () => setState(() => _selectingPickupDate = true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _timeModeButton(
                  label: 'Return',
                  value: _returnDateTime == null
                      ? 'Select date & time'
                      : '${_formatDateShort(_returnDate!)} • ${_formatTime(_returnTime)}',
                  active: !showingPickup,
                  onTap: () {
                    if (_returnDate == null) {
                      _openDateSelectionSheet(pickup: false);
                    } else if (_pickupTime == null) {
                      setState(() {
                        _errorMessage = 'Choose pickup time first.';
                        _selectingPickupDate = true;
                      });
                    } else {
                      setState(() => _selectingPickupDate = false);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Text(
            showingPickup ? 'Available pickup times' : 'Available return times',
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: body,
            ),
          ),
          const SizedBox(height: 7),
          if (slots.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF4D2AA)),
              ),
              child: const Text(
                'No available time slots for this date. Choose another date.',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF9A5B18),
                ),
              ),
            )
          else
            SizedBox(
              height: 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: slots.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final time = slots[index];
                  final selected = selectedTime != null &&
                      selectedTime.hour == time.hour &&
                      selectedTime.minute == time.minute;
                  final valid = _isTimeSlotValid(time, pickup: showingPickup);
                  return _timeSlotChip(
                    time: time,
                    selected: selected,
                    enabled: valid,
                    onTap: valid
                        ? () => _selectTimeSlot(time, pickup: showingPickup)
                        : null,
                  );
                },
              ),
            ),
          const SizedBox(height: 9),
          _buildAvailabilityTimeline(
            showingPickup ? _pickupDate : _returnDate,
          ),
        ],
      ),
    );
  }

  Widget _timeModeButton({
    required String label,
    required String value,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Material(
      color: active ? softAccent : background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? const Color(0xFF8EDDD4) : border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  color: muted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  color: heading,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timeSlotChip({
    required TimeOfDay time,
    required bool selected,
    required bool enabled,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: selected ? primary : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 76,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? primary
                  : enabled
                      ? border
                      : const Color(0xFFE8ECEB),
            ),
          ),
          child: Text(
            _formatTime(time),
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: selected
                  ? Colors.white
                  : enabled
                      ? heading
                      : muted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvailabilityTimeline(DateTime? date) {
    if (date == null) return const SizedBox.shrink();
    final windows = _availableWindowsForDate(date)
        .where((item) => item.end.isAfter(item.start))
        .toList();
    final intervals = _intervalsForDate(date)
        .where((item) => item.end.isAfter(item.start))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Availability',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: muted,
              ),
            ),
            const Spacer(),
            if (intervals.isNotEmpty)
              Text(
                '${intervals.length} booked window${intervals.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  color: muted,
                ),
              ),
          ],
        ),
        const SizedBox(height: 5),
        SizedBox(
          height: 8,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Row(
              children: [
                for (final window in windows)
                  Expanded(
                    flex: window.end.difference(window.start).inMinutes.clamp(1, 1440).toInt(),
                    child: Container(color: accent),
                  ),
                for (final blocked in intervals)
                  Expanded(
                    flex: blocked.end.difference(blocked.start).inMinutes.clamp(1, 1440).toInt(),
                    child: Container(color: const Color(0xFFE7B0A9)),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        if (windows.isNotEmpty)
          Text(
            'Available ${windows.take(2).map(_intervalText).join(' • ')}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              color: primary,
            ),
          )
        else
          const Text(
            'No available window on this date',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFFE05252),
            ),
          ),
      ],
    );
  }



  Widget _smallTimeButton({
    required String label,
    required TimeOfDay? time,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: softAccent,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: _loadingAvailability ? null : onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 11,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: const Color(0xFFBDEBE5)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: primary),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: muted,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      time == null ? 'Select time' : _formatTime(time),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: heading,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.edit_rounded,
                size: 14,
                color: primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDurationCard() {
    final duration =
        _rentalDuration;

    final valid =
        duration != null &&
            duration.inMinutes >
                0;

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets
              .symmetric(
        horizontal: 16,
        vertical: 15,
      ),
      decoration:
          BoxDecoration(
        color:
            valid ? softAccent : card,
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        border: Border.all(
          color: valid
              ? const Color(
                  0xFFBDEBE5,
                )
              : border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration:
                BoxDecoration(
              color: valid
                  ? Colors.white
                  : background,
              shape:
                  BoxShape.circle,
            ),
            child: const Icon(
              Icons
                  .timelapse_rounded,
              color: primary,
              size: 21,
            ),
          ),
          const SizedBox(
            width: 12,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                const Text(
                  'Rental duration',
                  style:
                      TextStyle(
                    fontFamily:
                        'Manrope',
                    fontSize: 11,
                    fontWeight:
                        FontWeight
                            .w600,
                    color: muted,
                  ),
                ),
                const SizedBox(
                  height: 2,
                ),
                Text(
                  _durationText,
                  style:
                      const TextStyle(
                    fontFamily:
                        'Manrope',
                    fontSize: 14,
                    fontWeight:
                        FontWeight
                            .w800,
                    color: heading,
                  ),
                ),
              ],
            ),
          ),
          if (valid)
            const Icon(
              Icons
                  .check_circle_rounded,
              color: primary,
              size: 22,
            ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets
              .symmetric(
        horizontal: 13,
        vertical: 11,
      ),
      decoration:
          BoxDecoration(
        color:
            const Color(
          0xFFFFF4F3,
        ),
        borderRadius:
            BorderRadius.circular(
          13,
        ),
        border: Border.all(
          color:
              const Color(
            0xFFF2C9C5,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment
                .start,
        children: [
          const Icon(
            Icons
                .error_outline_rounded,
            size: 19,
            color:
                Color(0xFFB42318),
          ),
          const SizedBox(
            width: 9,
          ),
          Expanded(
            child: Text(
              _errorMessage!,
              style:
                  const TextStyle(
                fontFamily:
                    'Manrope',
                fontSize: 12,
                fontWeight:
                    FontWeight.w600,
                color:
                    Color(0xFF8E2118),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final ready =
        _pricingReady &&
        !_loadingAvailability &&
            !_checkingAvailability &&
            !_refreshingAvailability &&
            _datesConfirmed &&
            _pickupDateTime !=
                null &&
            _returnDateTime !=
                null &&
            _rentalDuration !=
                null &&
            _rentalDuration!
                    .inMinutes >
                0;

    return Container(
      padding:
          const EdgeInsets
              .fromLTRB(
        20,
        12,
        20,
        16,
      ),
      decoration:
          BoxDecoration(
        color: card,
        border:
            const Border(
          top: BorderSide(
            color: border,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withValues(
              alpha: 0.04,
            ),
            blurRadius: 16,
            offset:
                const Offset(0, -5),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed:
              ready ? _continue : null,
          style:
              ElevatedButton.styleFrom(
            backgroundColor:
                primary,
            disabledBackgroundColor:
                const Color(
              0xFFD9E2E0,
            ),
            foregroundColor:
                Colors.white,
            disabledForegroundColor:
                muted,
            elevation: 0,
            shape:
                RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(
                16,
              ),
            ),
          ),
          child:
              (_checkingAvailability || _refreshingAvailability)
                  ? const SizedBox(
                      width: 21,
                      height: 21,
                      child:
                          CircularProgressIndicator(
                        strokeWidth:
                            2.2,
                        color:
                            Colors.white,
                      ),
                    )
                  : const Text(
                      'Continue',
                      style:
                          TextStyle(
                        fontFamily:
                            'Manrope',
                        fontSize: 14,
                        fontWeight:
                            FontWeight
                                .w800,
                      ),
                    ),
        ),
      ),
    );
  }
}

// ============================================================
// CALENDAR SUPPORT WIDGETS
// ============================================================

enum _CalendarDayState {
  available,
  partial,
  full,
  past,
}

class _WeekdayLabel extends StatelessWidget {
  final String text;

  const _WeekdayLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF94A09D),
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

class _CalendarLegend extends StatelessWidget {
  final Color color;
  final String label;

  const _CalendarLegend({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF66706E),
          ),
        ),
      ],
    );
  }
}

class _SheetHint extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SheetHint({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9E8),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFFF2D48B)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 15,
            color: Color(0xFF8A6100),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: Color(0xFF8A6100),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarDay extends StatelessWidget {
  // Calendar colors are declared locally because this widget is outside
  // _DateTimeScreenState.
  static const Color primary = Color(0xFF0F766E);
  static const Color accent = Color(0xFF14B8A6);
  static const Color softAccent = Color(0xFFE6FFFB);
  static const Color heading = Color(0xFF17201F);
  static const Color border = Color(0xFFE5EBE9);

  final DateTime date;
  final _CalendarDayState state;
  final bool selected;
  final bool inRange;
  final bool pickup;
  final bool returnDate;
  final bool enabled;
  final String priceText;
  final bool specialPrice;
  final VoidCallback? onTap;

  const _CalendarDay({
    required this.date,
    required this.state,
    required this.selected,
    required this.inRange,
    required this.pickup,
    required this.returnDate,
    required this.enabled,
    required this.priceText,
    required this.specialPrice,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color fill;
    Color textColor;
    Color borderColor;

    if (pickup) {
      fill = primary;
      textColor = Colors.white;
      borderColor = primary;
    } else if (returnDate) {
      fill = accent;
      textColor = Colors.white;
      borderColor = accent;
    } else if (inRange) {
      fill = softAccent;
      textColor = primary;
      borderColor = const Color(0xFFBDEBE5);
    } else {
      switch (state) {
        case _CalendarDayState.available:
          fill = Colors.white;
          textColor = heading;
          borderColor = border;
          break;
        case _CalendarDayState.partial:
          fill = const Color(0xFFFFF6DD);
          textColor = const Color(0xFF8A6100);
          borderColor = const Color(0xFFF2D48B);
          break;
        case _CalendarDayState.full:
          fill = const Color(0xFFFFE9E7);
          textColor = const Color(0xFFB42318);
          borderColor = const Color(0xFFF2C9C5);
          break;
        case _CalendarDayState.past:
          fill = const Color(0xFFF3F5F4);
          textColor = const Color(0xFFB0B8B6);
          borderColor = const Color(0xFFE7ECEA);
          break;
      }
    }

    final marker = pickup
        ? 'Pickup date'
        : returnDate
            ? 'Return date'
            : null;

    return Semantics(
      button: enabled,
      enabled: enabled,
      label: '${date.day} ${_monthName(date.month)}'
          '${marker == null ? '' : ', $marker'}'
          '${state == _CalendarDayState.full ? ', fully booked' : ''}'
          '${state == _CalendarDayState.partial ? ', partially booked' : ''}',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 4, 2, 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${date.day}',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                      if (priceText.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          priceText,
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 7.5,
                            fontWeight: FontWeight.w900,
                            color: selected
                                ? Colors.white
                                : specialPrice
                                    ? const Color(0xFFB45309)
                                    : primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (selected && marker != null)
                  Positioned(
                    top: 2,
                    right: 3,
                    child: Text(
                      pickup ? 'P' : 'R',
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 6.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                if (!selected &&
                    state == _CalendarDayState.partial)
                  Positioned(
                    top: 3,
                    right: 4,
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF2B84B),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                if (!selected &&
                    state == _CalendarDayState.full)
                  Positioned(
                    top: 3,
                    right: 4,
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE05252),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _monthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }
}

// ============================================================
// AVAILABILITY INTERVAL
// ============================================================

class _AvailabilityInterval {
  final DateTime start;
  final DateTime end;

  const _AvailabilityInterval(this.start, this.end);
}
