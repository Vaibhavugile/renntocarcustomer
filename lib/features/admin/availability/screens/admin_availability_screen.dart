import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/config/app_config.dart';
import '../../../cars/models/car.dart';
import '../services/admin_availability_service.dart';

class AdminAvailabilityScreen extends StatefulWidget {
  const AdminAvailabilityScreen({super.key});

  @override
  State<AdminAvailabilityScreen> createState() =>
      _AdminAvailabilityScreenState();
}

class _AdminAvailabilityScreenState
    extends State<AdminAvailabilityScreen> {
  static const Color primary = Color(0xFF0F766E);
  static const Color accent = Color(0xFF14B8A6);
  static const Color background = Color(0xFFF8FAF9);
  static const Color card = Color(0xFFFFFFFF);
  static const Color softAccent = Color(0xFFE6FFFB);
  static const Color heading = Color(0xFF17201F);
  static const Color body = Color(0xFF66706E);
  static const Color muted = Color(0xFF94A09D);
  static const Color border = Color(0xFFE5EBE9);

  final _service = AdminAvailabilityService.instance;

  DateTime _visibleMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );
  DateTime _selectedDate = DateTime.now();

  AdminAvailabilitySnapshot? _snapshot;
  bool _isLoading = true;
  String? _error;
  String _search = '';

  String get _tenantId => AppConfig.tenant.tenantId;

  @override
  void initState() {
    super.initState();
    _loadMonth();
  }

  Future<void> _loadMonth() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final snapshot = await _service.getMonthAvailability(
        month: _visibleMonth,
        tenantId: _tenantId,
      );

      if (!mounted) return;

      setState(() {
        _snapshot = snapshot;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _error = 'Unable to load availability. Please try again.';
      });
    }
  }

  void _previousMonth() {
    setState(() {
      _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month - 1,
        1,
      );
      _selectedDate = DateTime(
        _visibleMonth.year,
        _visibleMonth.month,
        1,
      );
    });
    _loadMonth();
  }

  void _nextMonth() {
    setState(() {
      _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + 1,
        1,
      );
      _selectedDate = DateTime(
        _visibleMonth.year,
        _visibleMonth.month,
        1,
      );
    });
    _loadMonth();
  }

  void _today() {
    final now = DateTime.now();

    setState(() {
      _visibleMonth = DateTime(now.year, now.month, 1);
      _selectedDate = DateTime(now.year, now.month, now.day);
    });

    _loadMonth();
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day;
  }

  DateTime get _selectedStart => DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );

  DateTime get _selectedEnd => _selectedStart.add(
        const Duration(days: 1),
      );

  List<Car> get _filteredCars {
    final cars = _snapshot?.cars ?? <Car>[];

    final query = _search.trim().toLowerCase();
    if (query.isEmpty) return cars;

    return cars.where((car) {
      return car.name.toLowerCase().contains(query) ||
          car.registrationNumber.toLowerCase().contains(query) ||
          car.type.toLowerCase().contains(query);
    }).toList();
  }

  bool _availableOnDate(Car car) {
    final snapshot = _snapshot;
    if (snapshot == null) return false;

    return _service.isCarAvailableForRange(
      car: car,
      start: _selectedStart,
      end: _selectedEnd,
      bookings: snapshot.bookings,
      blocks: snapshot.blocks,
    );
  }

  List<AvailabilityBooking> _bookingsForDate(Car car) {
    final snapshot = _snapshot;
    if (snapshot == null) return [];

    return _service.conflictsForCar(
      carId: car.id,
      start: _selectedStart,
      end: _selectedEnd,
      bookings: snapshot.bookings,
    );
  }

  List<AvailabilityBlock> _blocksForDate(Car car) {
    final snapshot = _snapshot;
    if (snapshot == null) return [];

    return _service.blocksForCar(
      carId: car.id,
      start: _selectedStart,
      end: _selectedEnd,
      blocks: snapshot.blocks,
    );
  }

  int _availableCountForDate(DateTime date) {
    final snapshot = _snapshot;
    if (snapshot == null) return 0;

    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));

    return snapshot.cars.where((car) {
      return _service.isCarAvailableForRange(
        car: car,
        start: start,
        end: end,
        bookings: snapshot.bookings,
        blocks: snapshot.blocks,
      );
    }).length;
  }

  int _bookedCountForDate(DateTime date) {
    final snapshot = _snapshot;
    if (snapshot == null) return 0;

    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));

    return snapshot.cars.where((car) {
      final bookings = _service.conflictsForCar(
        carId: car.id,
        start: start,
        end: end,
        bookings: snapshot.bookings,
      );
      return bookings.isNotEmpty;
    }).length;
  }

  int _blockedCountForDate(DateTime date) {
    final snapshot = _snapshot;
    if (snapshot == null) return 0;

    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));

    return snapshot.cars.where((car) {
      final blocks = _service.blocksForCar(
        carId: car.id,
        start: start,
        end: end,
        blocks: snapshot.blocks,
      );
      return blocks.isNotEmpty;
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    final total = snapshot?.cars.length ?? 0;
    final available = _availableCountForDate(_selectedDate);
    final booked = _bookedCountForDate(_selectedDate);
    final blocked = _blockedCountForDate(_selectedDate);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: heading,
          ),
        ),
        title: Text(
          'Vehicle Availability',
          style: GoogleFonts.manrope(
            color: heading,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadMonth,
            icon: const Icon(
              Icons.refresh_rounded,
              color: heading,
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _isLoading && _snapshot == null
          ? const Center(
              child: CircularProgressIndicator(
                color: primary,
              ),
            )
          : _error != null && _snapshot == null
              ? _buildError()
              : RefreshIndicator(
                  color: primary,
                  onRefresh: _loadMonth,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      18,
                      8,
                      18,
                      110,
                    ),
                    children: [
                      _buildHeaderCard(),
                      const SizedBox(height: 14),
                      _buildStats(
                        total: total,
                        available: available,
                        booked: booked,
                        blocked: blocked,
                      ),
                      const SizedBox(height: 14),
                      _buildCalendar(),
                      const SizedBox(height: 14),
                      _buildSearch(),
                      const SizedBox(height: 14),
                      _buildSelectedDateHeader(available),
                      const SizedBox(height: 10),
                      ..._buildVehicleCards(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 46,
              color: muted,
            ),
            const SizedBox(height: 14),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                color: body,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: _loadMonth,
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Try Again',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: softAccent,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.event_available_rounded,
              color: primary,
              size: 25,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fleet availability',
                  style: GoogleFonts.manrope(
                    color: heading,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Select any date to see which vehicles can be booked.',
                  style: GoogleFonts.manrope(
                    color: body,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _today,
            child: Text(
              'Today',
              style: GoogleFonts.manrope(
                color: primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats({
    required int total,
    required int available,
    required int booked,
    required int blocked,
  }) {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            value: '$available',
            label: 'Available',
            icon: Icons.check_circle_rounded,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _statCard(
            value: '$booked',
            label: 'Reserved',
            icon: Icons.event_busy_rounded,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _statCard(
            value: '$blocked',
            label: 'Blocked',
            icon: Icons.build_circle_rounded,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _statCard(
            value: '$total',
            label: 'Fleet',
            icon: Icons.directions_car_filled_rounded,
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required String value,
    required String label,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 13, 10, 12),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Icon(icon, color: primary, size: 19),
          const SizedBox(height: 7),
          Text(
            value,
            style: GoogleFonts.manrope(
              color: heading,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.manrope(
              color: muted,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    final firstDay = DateTime(
      _visibleMonth.year,
      _visibleMonth.month,
      1,
    );

    final daysInMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + 1,
      0,
    ).day;

    final leading = firstDay.weekday - 1;
    final cells = leading + daysInMonth;
    final rows = (cells / 7).ceil();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _previousMonth,
                icon: const Icon(
                  Icons.chevron_left_rounded,
                  color: heading,
                ),
              ),
              Expanded(
                child: Text(
                  _monthName(_visibleMonth.month) +
                      ' ${_visibleMonth.year}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    color: heading,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                onPressed: _nextMonth,
                icon: const Icon(
                  Icons.chevron_right_rounded,
                  color: heading,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              for (final day in const [
                'M',
                'T',
                'W',
                'T',
                'F',
                'S',
                'S',
              ])
                Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: GoogleFonts.manrope(
                        color: muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          for (int row = 0; row < rows; row++)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                children: [
                  for (int column = 0; column < 7; column++)
                    Expanded(
                      child: _calendarCell(
                        dayNumber: row * 7 + column - leading + 1,
                        daysInMonth: daysInMonth,
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          _buildLegend(),
        ],
      ),
    );
  }

  Widget _calendarCell({
    required int dayNumber,
    required int daysInMonth,
  }) {
    if (dayNumber < 1 || dayNumber > daysInMonth) {
      return const SizedBox(height: 52);
    }

    final date = DateTime(
      _visibleMonth.year,
      _visibleMonth.month,
      dayNumber,
    );

    final selected = _sameDay(date, _selectedDate);
    final today = _sameDay(date, DateTime.now());

    final available = _availableCountForDate(date);
    final booked = _bookedCountForDate(date);
    final blocked = _blockedCountForDate(date);

    return GestureDetector(
      onTap: () => _selectDate(date),
      child: Container(
        height: 52,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: selected ? primary : background,
          borderRadius: BorderRadius.circular(13),
          border: today && !selected
              ? Border.all(color: accent, width: 1.4)
              : Border.all(color: Colors.transparent),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$dayNumber',
              style: GoogleFonts.manrope(
                color: selected ? Colors.white : heading,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _dot(
                  selected
                      ? Colors.white
                      : available > 0
                          ? primary
                          : muted,
                ),
                if (booked > 0) ...[
                  const SizedBox(width: 3),
                  _dot(
                    selected
                        ? Colors.white70
                        : Colors.orange.shade700,
                  ),
                ],
                if (blocked > 0) ...[
                  const SizedBox(width: 3),
                  _dot(
                    selected
                        ? Colors.white54
                        : Colors.red.shade400,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dot(Color color) {
    return Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      children: [
        _legendItem(
          color: primary,
          text: 'Available',
        ),
        const SizedBox(width: 12),
        _legendItem(
          color: Colors.orange.shade700,
          text: 'Booked',
        ),
        const SizedBox(width: 12),
        _legendItem(
          color: Colors.red.shade400,
          text: 'Blocked',
        ),
      ],
    );
  }

  Widget _legendItem({
    required Color color,
    required String text,
  }) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: GoogleFonts.manrope(
            color: body,
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildSearch() {
    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: border),
      ),
      child: TextField(
        onChanged: (value) {
          setState(() {
            _search = value;
          });
        },
        style: GoogleFonts.manrope(
          color: heading,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: 'Search vehicle, registration or type...',
          hintStyle: GoogleFonts.manrope(
            color: muted,
            fontSize: 13,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: primary,
          ),
          suffixIcon: _search.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    setState(() {
                      _search = '';
                    });
                  },
                  icon: const Icon(
                    Icons.close_rounded,
                    color: muted,
                  ),
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedDateHeader(int available) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _fullDate(_selectedDate),
                style: GoogleFonts.manrope(
                  color: heading,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '$available vehicles available for the full day',
                style: GoogleFonts.manrope(
                  color: body,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 11,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: softAccent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${_filteredCars.length} vehicles',
            style: GoogleFonts.manrope(
              color: primary,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildVehicleCards() {
    final cars = _filteredCars;

    if (cars.isEmpty) {
      return [
        _emptyCard(
          icon: Icons.directions_car_outlined,
          title: 'No vehicles found',
          subtitle: _search.isEmpty
              ? 'Add active vehicles to see them here.'
              : 'Try another search term.',
        ),
      ];
    }

    return cars.map(_buildVehicleCard).toList();
  }

  Widget _buildVehicleCard(Car car) {
    final available = _availableOnDate(car);
    final bookings = _bookingsForDate(car);
    final blocks = _blocksForDate(car);

    final reason = blocks.isNotEmpty
        ? blocks.first.title
        : bookings.isNotEmpty
            ? _bookingReason(bookings)
            : !car.isAvailable
                ? 'Vehicle marked unavailable'
                : !car.isActive
                    ? 'Vehicle inactive'
                    : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _carImage(car),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      car.name.isEmpty ? 'Vehicle' : car.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        color: heading,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      car.registrationNumber.isEmpty
                          ? '${car.type} • ${car.transmission}'
                          : car.registrationNumber,
                      style: GoogleFonts.manrope(
                        color: body,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        _miniTag(
                          icon: Icons.people_alt_outlined,
                          text: '${car.seats}',
                        ),
                        const SizedBox(width: 5),
                        _miniTag(
                          icon: Icons.local_gas_station_outlined,
                          text: car.fuel,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _availabilityBadge(
                available: available,
                reason: reason,
              ),
            ],
          ),
          if (bookings.isNotEmpty || blocks.isNotEmpty) ...[
            const SizedBox(height: 11),
            const Divider(
              height: 1,
              color: border,
            ),
            const SizedBox(height: 10),
            _conflictSummary(
              bookings: bookings,
              blocks: blocks,
            ),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdminVehicleAvailabilityScreen(
                      car: car,
                      initialMonth: _visibleMonth,
                    ),
                  ),
                );
              },
              icon: const Icon(
                Icons.calendar_month_rounded,
                size: 17,
              ),
              label: Text(
                'Vehicle Calendar',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: primary,
                side: const BorderSide(color: border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _carImage(Car car) {
    return Container(
      width: 67,
      height: 67,
      decoration: BoxDecoration(
        color: softAccent,
        borderRadius: BorderRadius.circular(17),
      ),
      clipBehavior: Clip.antiAlias,
      child: car.image.isNotEmpty
          ? Image.network(
              car.image,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return const Icon(
                  Icons.directions_car_rounded,
                  color: primary,
                  size: 30,
                );
              },
            )
          : const Icon(
              Icons.directions_car_rounded,
              color: primary,
              size: 30,
            ),
    );
  }

  Widget _miniTag({
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: muted,
            size: 12,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.manrope(
              color: body,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _availabilityBadge({
    required bool available,
    required String reason,
  }) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 100),
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: available ? softAccent : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        children: [
          Icon(
            available
                ? Icons.check_circle_rounded
                : Icons.event_busy_rounded,
            color: available
                ? primary
                : Colors.orange.shade800,
            size: 18,
          ),
          const SizedBox(height: 3),
          Text(
            available ? 'Available' : 'Unavailable',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              color: available
                  ? primary
                  : Colors.orange.shade800,
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (!available && reason.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              reason,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                color: body,
                fontSize: 8,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _bookingReason(List<AvailabilityBooking> bookings) {
    if (bookings.isEmpty) return 'Booked';

    final statuses = bookings
        .map((booking) => booking.status.trim().toLowerCase())
        .toSet();

    if (statuses.contains('pending')) return 'Pending / Reserved';
    if (statuses.contains('confirmed')) return 'Confirmed';
    if (statuses.contains('pickup_pending') ||
        statuses.contains('pickuppending')) {
      return 'Pickup Pending';
    }
    if (statuses.contains('active')) return 'On Rent';
    if (statuses.contains('return_pending') ||
        statuses.contains('returnpending')) {
      return 'Return Pending';
    }

    return 'Booked';
  }

  Widget _conflictSummary({
    required List<AvailabilityBooking> bookings,
    required List<AvailabilityBlock> blocks,
  }) {
    return Column(
      children: [
        for (final booking in bookings.take(2))
          _timelineRow(
            icon: Icons.event_rounded,
            title: 'Booking • ${booking.customerName}',
            subtitle:
                '${_time(booking.pickupDateTime)} – ${_time(booking.returnDateTime)} • ${_prettyStatus(booking.status)}',
          ),
        for (final block in blocks.take(2))
          _timelineRow(
            icon: Icons.build_circle_outlined,
            title: block.title,
            subtitle:
                '${_time(block.startDateTime)} – ${_time(block.endDateTime)}',
          ),
      ],
    );
  }

  Widget _timelineRow({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Icon(
            icon,
            color: primary,
            size: 17,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    color: heading,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    color: body,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Icon(icon, color: muted, size: 38),
          const SizedBox(height: 10),
          Text(
            title,
            style: GoogleFonts.manrope(
              color: heading,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              color: body,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _monthName(int month) {
    const names = [
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
    return names[month - 1];
  }

  String _fullDate(DateTime date) {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return '${weekdays[date.weekday - 1]}, ${date.day} ${_monthName(date.month)} ${date.year}';
  }

  String _time(DateTime date) {
    final hour = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:$minute $suffix';
  }

  String _prettyStatus(String status) {
    return status
        .replaceAll('_', ' ')
        .replaceAll('Pending', 'pending')
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }
}

class AdminVehicleAvailabilityScreen extends StatefulWidget {
  final Car car;
  final DateTime initialMonth;

  const AdminVehicleAvailabilityScreen({
    super.key,
    required this.car,
    required this.initialMonth,
  });

  @override
  State<AdminVehicleAvailabilityScreen> createState() =>
      _AdminVehicleAvailabilityScreenState();
}

class _AdminVehicleAvailabilityScreenState
    extends State<AdminVehicleAvailabilityScreen> {
  static const Color primary = Color(0xFF0F766E);
  static const Color accent = Color(0xFF14B8A6);
  static const Color background = Color(0xFFF8FAF9);
  static const Color card = Color(0xFFFFFFFF);
  static const Color softAccent = Color(0xFFE6FFFB);
  static const Color heading = Color(0xFF17201F);
  static const Color body = Color(0xFF66706E);
  static const Color muted = Color(0xFF94A09D);
  static const Color border = Color(0xFFE5EBE9);

  final _service = AdminAvailabilityService.instance;

  late DateTime _month;
  DateTime _selectedDate = DateTime.now();

  AdminAvailabilitySnapshot? _snapshot;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _month = DateTime(
      widget.initialMonth.year,
      widget.initialMonth.month,
      1,
    );
    _selectedDate = DateTime.now().month == _month.month &&
            DateTime.now().year == _month.year
        ? DateTime.now()
        : _month;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final snapshot = await _service.getMonthAvailability(
        month: _month,
        tenantId: AppConfig.tenant.tenantId,
      );

      if (!mounted) return;

      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'Unable to load vehicle calendar.';
      });
    }
  }

  DateTime get _dayStart => DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );

  DateTime get _dayEnd => _dayStart.add(
        const Duration(days: 1),
      );

  bool get _available {
    final s = _snapshot;
    if (s == null) return false;

    return _service.isCarAvailableForRange(
      car: widget.car,
      start: _dayStart,
      end: _dayEnd,
      bookings: s.bookings,
      blocks: s.blocks,
    );
  }

  List<AvailabilityBooking> get _bookings {
    final s = _snapshot;
    if (s == null) return [];

    return _service.conflictsForCar(
      carId: widget.car.id,
      start: _dayStart,
      end: _dayEnd,
      bookings: s.bookings,
    );
  }

  List<AvailabilityBlock> get _blocks {
    final s = _snapshot;
    if (s == null) return [];

    return _service.blocksForCar(
      carId: widget.car.id,
      start: _dayStart,
      end: _dayEnd,
      blocks: s.blocks,
    );
  }

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(
        _month.year,
        _month.month + delta,
        1,
      );
      _selectedDate = _month;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: heading,
          ),
        ),
        title: Text(
          widget.car.name.isEmpty
              ? 'Vehicle Calendar'
              : widget.car.name,
          style: GoogleFonts.manrope(
            color: heading,
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(
              Icons.refresh_rounded,
              color: heading,
            ),
          ),
        ],
      ),
      body: _loading && _snapshot == null
          ? const Center(
              child: CircularProgressIndicator(color: primary),
            )
          : _error != null
              ? Center(
                  child: Text(
                    _error!,
                    style: GoogleFonts.manrope(
                      color: body,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                    18,
                    8,
                    18,
                    100,
                  ),
                  children: [
                    _buildVehicleHeader(),
                    const SizedBox(height: 14),
                    _buildMonthCalendar(),
                    const SizedBox(height: 14),
                    _buildDayStatus(),
                    const SizedBox(height: 14),
                    _buildEvents(),
                  ],
                ),
    );
  }

  Widget _buildVehicleHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: softAccent,
              borderRadius: BorderRadius.circular(17),
            ),
            clipBehavior: Clip.antiAlias,
            child: widget.car.image.isNotEmpty
                ? Image.network(
                    widget.car.image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) {
                      return const Icon(
                        Icons.directions_car_rounded,
                        color: primary,
                        size: 30,
                      );
                    },
                  )
                : const Icon(
                    Icons.directions_car_rounded,
                    color: primary,
                    size: 30,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.car.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    color: heading,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.car.registrationNumber.isEmpty
                      ? widget.car.type
                      : widget.car.registrationNumber,
                  style: GoogleFonts.manrope(
                    color: body,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthCalendar() {
    final firstDay = DateTime(_month.year, _month.month, 1);
    final days = DateTime(
      _month.year,
      _month.month + 1,
      0,
    ).day;
    final leading = firstDay.weekday - 1;
    final rows = ((leading + days) / 7).ceil();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => _changeMonth(-1),
                icon: const Icon(
                  Icons.chevron_left_rounded,
                  color: heading,
                ),
              ),
              Expanded(
                child: Text(
                  '${_monthName(_month.month)} ${_month.year}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    color: heading,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _changeMonth(1),
                icon: const Icon(
                  Icons.chevron_right_rounded,
                  color: heading,
                ),
              ),
            ],
          ),
          Row(
            children: [
              for (final day in const [
                'M',
                'T',
                'W',
                'T',
                'F',
                'S',
                'S',
              ])
                Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: GoogleFonts.manrope(
                        color: muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          for (int row = 0; row < rows; row++)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                children: [
                  for (int column = 0; column < 7; column++)
                    Expanded(
                      child: _vehicleCalendarCell(
                        number:
                            row * 7 + column - leading + 1,
                        days: days,
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 5),
          Row(
            children: [
              _legend(
                color: primary,
                label: 'Available',
              ),
              const SizedBox(width: 12),
              _legend(
                color: Colors.orange.shade700,
                label: 'Reserved',
              ),
              const SizedBox(width: 12),
              _legend(
                color: Colors.red.shade400,
                label: 'Blocked',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _vehicleCalendarCell({
    required int number,
    required int days,
  }) {
    if (number < 1 || number > days) {
      return const SizedBox(height: 48);
    }

    final date = DateTime(
      _month.year,
      _month.month,
      number,
    );
    final selected = date.year == _selectedDate.year &&
        date.month == _selectedDate.month &&
        date.day == _selectedDate.day;

    final start = date;
    final end = start.add(const Duration(days: 1));

    final s = _snapshot!;
    final available = _service.isCarAvailableForRange(
      car: widget.car,
      start: start,
      end: end,
      bookings: s.bookings,
      blocks: s.blocks,
    );

    final hasBooking = _service
        .conflictsForCar(
          carId: widget.car.id,
          start: start,
          end: end,
          bookings: s.bookings,
        )
        .isNotEmpty;

    final hasBlock = _service
        .blocksForCar(
          carId: widget.car.id,
          start: start,
          end: end,
          blocks: s.blocks,
        )
        .isNotEmpty;

    final color = hasBlock
        ? Colors.red.shade400
        : hasBooking
            ? Colors.orange.shade700
            : available
                ? primary
                : muted;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDate = date;
        });
      },
      child: Container(
        height: 48,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: selected ? primary : background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? primary : Colors.transparent,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$number',
              style: GoogleFonts.manrope(
                color: selected ? Colors.white : heading,
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: selected ? Colors.white : color,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayStatus() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _available ? softAccent : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _available ? accent : Colors.orange.shade100,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _available
                ? Icons.check_circle_rounded
                : Icons.event_busy_rounded,
            color: _available
                ? primary
                : Colors.orange.shade800,
            size: 26,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _available
                      ? 'Available for the full day'
                      : 'Unavailable on this date',
                  style: GoogleFonts.manrope(
                    color: heading,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_selectedDate.day} ${_monthName(_selectedDate.month)} ${_selectedDate.year}',
                  style: GoogleFonts.manrope(
                    color: body,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvents() {
    if (_bookings.isEmpty && _blocks.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.event_available_rounded,
              color: primary,
              size: 36,
            ),
            const SizedBox(height: 9),
            Text(
              'No blocking events',
              style: GoogleFonts.manrope(
                color: heading,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'This vehicle has no booking or manual block on the selected date.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                color: body,
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Schedule',
          style: GoogleFonts.manrope(
            color: heading,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        ..._bookings.map(
          (booking) => _eventCard(
            icon: Icons.event_rounded,
            title: booking.customerName,
            subtitle:
                '${_time(booking.pickupDateTime)} – ${_time(booking.returnDateTime)} • ${_prettyStatus(booking.status)}',
            extra: booking.customerPhone,
          ),
        ),
        ..._blocks.map(
          (block) => _eventCard(
            icon: Icons.build_circle_outlined,
            title: block.title,
            subtitle:
                '${_time(block.startDateTime)} – ${_time(block.endDateTime)}',
            extra: block.reason,
          ),
        ),
      ],
    );
  }

  Widget _eventCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String extra,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: softAccent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    color: heading,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.manrope(
                    color: body,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (extra.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    extra,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      color: muted,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend({
    required Color color,
    required String label,
  }) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.manrope(
            color: body,
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  String _monthName(int month) {
    const names = [
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
    return names[month - 1];
  }

  String _time(DateTime date) {
    final hour = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:$minute $suffix';
  }

  String _prettyStatus(String status) {
    return status
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }
}
