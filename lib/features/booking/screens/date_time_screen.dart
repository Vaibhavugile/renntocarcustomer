import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import 'package:customer_app_car_rental/features/cars/models/car.dart';
import 'branch_selection_screen.dart';
import 'package:customer_app_car_rental/features/admin/availability/services/admin_availability_service.dart';

class DateTimeScreen extends StatefulWidget {
  final Car car;

  const DateTimeScreen({
    super.key,
    required this.car,
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
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

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

  bool _canSelectCalendarDate(DateTime date) {
    final state = _getCalendarDayState(date);

    if (state == _CalendarDayState.past ||
        state == _CalendarDayState.full) {
      return false;
    }

    // Once pickup is selected, don't allow a return date before pickup.
    if (!_selectingPickupDate && _pickupDate != null &&
        _dateOnly(date).isBefore(_dateOnly(_pickupDate!))) {
      return false;
    }

    return true;
  }

  bool _isDateInSelectedRange(DateTime date) {
    if (_pickupDate == null || _returnDate == null) {
      return false;
    }

    final day = _dateOnly(date);
    return !day.isBefore(_dateOnly(_pickupDate!)) &&
        !day.isAfter(_dateOnly(_returnDate!));
  }

  bool _isSelectableRange(DateTime start, DateTime end) {
    start = _dateOnly(start);
    end = _dateOnly(end);

    if (end.isBefore(start)) {
      final temp = start;
      start = end;
      end = temp;
    }

    var cursor = start;
    while (!cursor.isAfter(end)) {
      if (!_canSelectCalendarDate(cursor)) {
        return false;
      }
      cursor = cursor.add(const Duration(days: 1));
    }

    return true;
  }

  DateTime? _dateAtCalendarPosition(
    Offset position,
    double width,
  ) {
    final cells = _calendarDays(_calendarMonth);
    if (cells.isEmpty || width <= 0) return null;

    const crossSpacing = 5.0;
    const mainSpacing = 7.0;
    final cellWidth = (width - crossSpacing * 6) / 7;
    if (cellWidth <= 0) return null;

    final cellHeight = cellWidth / 0.9;
    final pitchX = cellWidth + crossSpacing;
    final pitchY = cellHeight + mainSpacing;

    final column = (position.dx / pitchX).floor();
    final row = (position.dy / pitchY).floor();

    if (column < 0 || column > 6 || row < 0) return null;

    // Ignore the spacing between cells rather than snapping into it.
    final localX = position.dx - column * pitchX;
    final localY = position.dy - row * pitchY;
    if (localX < 0 ||
        localX > cellWidth ||
        localY < 0 ||
        localY > cellHeight) {
      return null;
    }

    final index = row * 7 + column;
    if (index < 0 || index >= cells.length) return null;

    return cells[index];
  }

  void _startCalendarDrag(Offset position, double width) {
    if (_datesConfirmed || _loadingAvailability) return;

    final date = _dateAtCalendarPosition(position, width);
    if (date == null || !_canSelectCalendarDate(date)) return;

    final selected = _dateOnly(date);
    String mode = 'new';

    // If the user starts on an existing endpoint, drag that endpoint.
    if (_pickupDate != null &&
        _returnDate != null &&
        _sameDate(_pickupDate!, selected)) {
      mode = 'pickup';
    } else if (_pickupDate != null &&
        _returnDate != null &&
        _sameDate(_returnDate!, selected)) {
      mode = 'return';
    }

    setState(() {
      _isDraggingRange = true;
      _dragMode = mode;
      _dragAnchorDate = selected;
      _dragCurrentDate = selected;
      _errorMessage = null;

      if (mode == 'new') {
        _pickupDate = selected;
        _returnDate = null;
        _returnTime = null;
        _selectingPickupDate = false;
      }
    });
  }

  void _updateCalendarDrag(Offset position, double width) {
    if (!_isDraggingRange || _datesConfirmed) return;

    final date = _dateAtCalendarPosition(position, width);
    if (date == null) return;

    final selected = _dateOnly(date);

    if (_dragMode == 'pickup' &&
        _returnDate != null) {
      if (selected.isAfter(_dateOnly(_returnDate!))) {
        // Do not cross the return endpoint. The user can drag the
        // return endpoint instead.
        return;
      }

      if (!_isSelectableRange(selected, _returnDate!)) {
        return;
      }

      setState(() {
        _pickupDate = selected;
        _dragCurrentDate = selected;
        _errorMessage = null;
      });
      return;
    }

    if (_dragMode == 'return' &&
        _pickupDate != null) {
      if (selected.isBefore(_dateOnly(_pickupDate!))) {
        return;
      }

      if (!_isSelectableRange(_pickupDate!, selected)) {
        return;
      }

      setState(() {
        _returnDate = selected;
        _dragCurrentDate = selected;
        _errorMessage = null;
      });
      return;
    }

    // New range: drag from the first touched date to the current date.
    final anchor = _dragAnchorDate ?? selected;
    var start = anchor;
    var end = selected;

    if (end.isBefore(start)) {
      final temp = start;
      start = end;
      end = temp;
    }

    if (!_isSelectableRange(start, end)) {
      return;
    }

    setState(() {
      _pickupDate = start;
      _returnDate = end;
      _dragCurrentDate = selected;
      _errorMessage = null;
    });
  }

  void _finishCalendarDrag() {
    if (!_isDraggingRange) return;

    setState(() {
      _isDraggingRange = false;
      _dragAnchorDate = null;
      _dragCurrentDate = null;
    });
  }

  void _tapCalendarDate(DateTime date) {
    if (!_canSelectCalendarDate(date)) return;

    final selected = _dateOnly(date);

    // When both dates already exist, tapping an endpoint makes that
    // endpoint the one the customer can adjust with a drag.
    if (_pickupDate != null &&
        _returnDate != null) {
      if (_sameDate(_pickupDate!, selected)) {
        setState(() {
          _selectingPickupDate = true;
          _datesConfirmed = false;
          _errorMessage = null;
        });
        return;
      }

      if (_sameDate(_returnDate!, selected)) {
        setState(() {
          _selectingPickupDate = false;
          _datesConfirmed = false;
          _errorMessage = null;
        });
        return;
      }

      // Tapping another date starts a fresh range from that date.
      setState(() {
        _datesConfirmed = false;
        _pickupDate = selected;
        _returnDate = null;
        _returnTime = null;
        _selectingPickupDate = false;
        _errorMessage = null;
      });
      return;
    }

    _selectCalendarDate(selected);
  }

  void _selectCalendarDate(DateTime date) {
    if (!_canSelectCalendarDate(date)) {
      return;
    }

    final selectedDate = _dateOnly(date);

    setState(() {
      _datesConfirmed = false;
      _errorMessage = null;

      if (_selectingPickupDate) {
        _pickupDate = selectedDate;
        _returnDate = null;
        _returnTime = null;
        _selectingPickupDate = false;
      } else {
        if (_pickupDate != null &&
            selectedDate.isBefore(_dateOnly(_pickupDate!))) {
          _pickupDate = selectedDate;
          _returnDate = null;
          _returnTime = null;
        } else {
          _returnDate = selectedDate;
        }
      }

      _calendarMonth = DateTime(
        selectedDate.year,
        selectedDate.month,
        1,
      );
    });
  }

  void _resetDateSelection() {
    setState(() {
      _selectingPickupDate = true;
      _datesConfirmed = false;
      _returnDate = null;
      _returnTime = null;
      _dragAnchorDate = null;
      _dragCurrentDate = null;
      _isDraggingRange = false;
      _dragMode = 'new';
      _errorMessage = null;
    });
  }

  void _confirmDates() {
    if (_pickupDate == null || _returnDate == null) {
      setState(() {
        _errorMessage = 'Please select pickup and return dates.';
      });
      return;
    }

    if (_dateOnly(_returnDate!).isBefore(_dateOnly(_pickupDate!))) {
      setState(() {
        _errorMessage = 'Return date must be on or after pickup date.';
      });
      return;
    }

    setState(() {
      _datesConfirmed = true;
      _selectingPickupDate = false;
      _isDraggingRange = false;
      _dragAnchorDate = null;
      _dragCurrentDate = null;
      _errorMessage = null;
    });
  }

  Widget _buildInlineCalendar() {
    final cells = _calendarDays(_calendarMonth);
    final canGoPrevious = !_calendarMonth.isAtSameMomentAs(
      _monthDate(_today.year, _today.month),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: softAccent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _datesConfirmed
                          ? 'Rental dates selected'
                          : _returnDate == null
                              ? 'Select your rental range'
                              : 'Adjust your rental range',
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: heading,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _datesConfirmed
                          ? '${_formatDate(_pickupDate)}  →  ${_formatDate(_returnDate)}'
                          : _returnDate == null
                              ? 'Tap a start date, then drag to your return date'
                              : 'Drag either endpoint to stretch the range',
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (_datesConfirmed)
                TextButton(
                  onPressed: _resetDateSelection,
                  child: const Text(
                    'Change',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              IconButton(
                tooltip: 'Previous month',
                onPressed: canGoPrevious ? _previousMonth : null,
                icon: const Icon(
                  Icons.chevron_left_rounded,
                  color: heading,
                ),
              ),
              Expanded(
                child: Text(
                  _monthTitle(_calendarMonth),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: heading,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Next month',
                onPressed: _nextMonth,
                icon: const Icon(
                  Icons.chevron_right_rounded,
                  color: heading,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
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
          LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanStart: _datesConfirmed
                    ? null
                    : (details) {
                        _startCalendarDrag(
                          details.localPosition,
                          constraints.maxWidth,
                        );
                      },
                onPanUpdate: _datesConfirmed
                    ? null
                    : (details) {
                        _updateCalendarDrag(
                          details.localPosition,
                          constraints.maxWidth,
                        );
                      },
                onPanEnd: _datesConfirmed
                    ? null
                    : (_) => _finishCalendarDrag(),
                onPanCancel: _datesConfirmed
                    ? null
                    : _finishCalendarDrag,
                child: GridView.builder(
                  shrinkWrap: true,
                  physics:
                      const NeverScrollableScrollPhysics(),
                  itemCount: cells.length,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 7,
                    crossAxisSpacing: 5,
                    childAspectRatio: 0.9,
                  ),
                  itemBuilder: (context, index) {
                    final date = cells[index];
                    if (date == null) {
                      return const SizedBox.shrink();
                    }

                    final state =
                        _getCalendarDayState(date);
                    final isPickup =
                        _pickupDate != null &&
                            _sameDate(_pickupDate!, date);
                    final isReturn =
                        _returnDate != null &&
                            _sameDate(_returnDate!, date);
                    final inRange =
                        _isDateInSelectedRange(date);
                    final canSelect =
                        !_datesConfirmed &&
                            _canSelectCalendarDate(date);

                    return _CalendarDay(
                      date: date,
                      state: state,
                      selected: isPickup || isReturn,
                      inRange: inRange,
                      pickup: isPickup,
                      returnDate: isReturn,
                      enabled: canSelect,
                      onTap: canSelect
                          ? () => _tapCalendarDate(date)
                          : null,
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          if (!_datesConfirmed)
            Row(
              children: [
                const Icon(
                  Icons.touch_app_rounded,
                  size: 15,
                  color: primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _returnDate == null
                        ? 'Tap and drag from pickup to return.'
                        : 'Drag Pickup or Return to stretch your dates.',
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: body,
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 13,
            runSpacing: 7,
            children: const [
              _CalendarLegend(
                color: Color(0xFF14B8A6),
                label: 'Available',
              ),
              _CalendarLegend(
                color: Color(0xFFF2B84B),
                label: 'Partially booked',
              ),
              _CalendarLegend(
                color: Color(0xFFE05252),
                label: 'Fully booked',
              ),
            ],
          ),
          if (!_datesConfirmed) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: _loadingAvailability ||
                        _pickupDate == null ||
                        _returnDate == null
                    ? null
                    : _confirmDates,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  disabledBackgroundColor:
                      const Color(0xFFD9E2E0),
                  foregroundColor: Colors.white,
                  disabledForegroundColor: muted,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Confirm dates',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
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
      setState(() {
        _errorMessage =
            'This pickup time is already unavailable for this car.';
      });

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
        setState(() {
          _errorMessage =
              'This car is already unavailable during the selected time.';
        });

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
          returnDateTime:
              returnDateTime,
        ),
      ),
    );
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        surfaceTintColor:
            Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          onPressed:
              (_checkingAvailability || _refreshingAvailability)
                  ? null
                  : () =>
                      Navigator.pop(
                        context,
                      ),
          icon: const Icon(
            Icons
                .arrow_back_ios_new_rounded,
            size: 20,
            color: heading,
          ),
        ),
        title: const Text(
          'Date & Time',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 18,
            fontWeight:
                FontWeight.w700,
            color: heading,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child:
                  SingleChildScrollView(
                padding:
                    const EdgeInsets
                        .fromLTRB(
                  20,
                  8,
                  20,
                  24,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    _buildCarSummary(),
                    const SizedBox(
                      height: 16,
                    ),
                    _buildAvailabilityBanner(),
                    const SizedBox(
                      height: 20,
                    ),
                    _buildHeading(),
                    const SizedBox(height: 14),
                    _buildInlineCalendar(),
                    if (_datesConfirmed) ...[
                      const SizedBox(height: 14),
                      _buildTimeSelection(),
                      const SizedBox(height: 14),
                      _buildDurationCard(),
                    ],
                    if (_errorMessage !=
                        null) ...[
                      const SizedBox(
                        height: 12,
                      ),
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

  Widget _buildTimeSelection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _smallTimeButton(
              label: 'Pickup',
              time: _pickupTime,
              icon: Icons.login_rounded,
              onTap: _selectPickupTime,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _smallTimeButton(
              label: 'Return',
              time: _returnTime,
              icon: Icons.logout_rounded,
              onTap: _selectReturnTime,
            ),
          ),
        ],
      ),
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
  final VoidCallback? onTap;

  const _CalendarDay({
    required this.date,
    required this.state,
    required this.selected,
    required this.inRange,
    required this.pickup,
    required this.returnDate,
    required this.enabled,
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
                Text(
                  '${date.day}',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
                if (selected && marker != null)
                  Positioned(
                    bottom: 3,
                    child: Text(
                      pickup ? 'P' : 'R',
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 7,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                if (!selected &&
                    state == _CalendarDayState.partial)
                  Positioned(
                    bottom: 4,
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
                    bottom: 4,
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
