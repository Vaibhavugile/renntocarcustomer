import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../admin/availability/services/admin_availability_service.dart';
import '../../cars/models/car.dart';
import '../../cars/services/car_service.dart';
import '../widgets/car_card.dart';
import '../../cars/screens/car_details_screen.dart';

/// Customer-facing Explore screen.
///
/// Features:
/// - Loads every active vehicle for the current tenant.
/// - Search by vehicle name / registration / type.
/// - Filter by vehicle type, transmission and fuel.
/// - Select hourly or daily rental.
/// - Select pickup/return dates and times.
/// - Customer enters rental type, pickup/return dates and times.
/// - No availability calendar is shown on Explore. Calendar availability is
///   intentionally handled later on the car-specific DateTimeScreen.
/// - Customer explicitly presses Check availability to search the active fleet.
/// - Only cars available for the exact selected range are shown after the check.
/// - Tapping a car opens the existing CarDetailsScreen.
class ExploreScreen extends StatefulWidget {
  final String? tenantId;

  const ExploreScreen({
    super.key,
    this.tenantId,
  });

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  static const Color background = Color(0xFFF8FAF9);
  static const Color card = Color(0xFFFFFFFF);
  static const Color primary = Color(0xFF0F766E);
  static const Color accent = Color(0xFF14B8A6);
  static const Color softAccent = Color(0xFFE6FFFB);
  static const Color heading = Color(0xFF17201F);
  static const Color body = Color(0xFF66706E);
  static const Color muted = Color(0xFF94A09D);
  static const Color border = Color(0xFFE5EBE9);

  final CarService _carService = CarService.instance;
  final AdminAvailabilityService _availabilityService =
      AdminAvailabilityService.instance;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String get _tenantId =>
      (widget.tenantId ?? AppConfig.tenant.tenantId).trim();

  List<Car> _allCars = <Car>[];
  List<Car> _visibleCars = <Car>[];

  List<Map<String, dynamic>> _branches = <Map<String, dynamic>>[];

  Set<String> _availableCarIds = <String>{};

  String _rentalType = 'daily';
  String _selectedType = 'All';
  String _selectedTransmission = 'All';
  String _selectedFuel = 'All';
  String _selectedBranchId = 'All';

  DateTime _pickupDate = DateTime.now();
  DateTime _returnDate = DateTime.now().add(const Duration(days: 1));

  TimeOfDay _pickupTime = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _returnTime = const TimeOfDay(hour: 10, minute: 0);

  bool _loadingCars = true;
  bool _checkingAvailability = false;
  bool _availabilityChecked = false;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applyFilters);
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_applyFilters)
      ..dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;

    setState(() {
      _loadingCars = true;
      _errorMessage = null;
    });

    try {
      if (_tenantId.isEmpty) {
        throw Exception('Tenant configuration is missing.');
      }

      final results = await Future.wait<dynamic>([
        _carService.getCars(tenantId: _tenantId),
        _loadBranches(),
      ]);

      final cars = (results[0] as List<Car>)
          .where((car) => car.isActive)
          .toList();

      if (!mounted) return;

      setState(() {
        _allCars = cars;
        _loadingCars = false;
        _errorMessage = null;
      });

      _applyFilters();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _allCars = <Car>[];
        _visibleCars = <Car>[];
        _loadingCars = false;
        _errorMessage = _cleanError(e);
      });
    }
  }

  Future<List<Map<String, dynamic>>> _loadBranches() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('tenants')
        .doc(_tenantId)
        .collection('branches')
        .where('isActive', isEqualTo: true)
        .get();

    final branches = snapshot.docs.map((doc) {
      final data = doc.data();

      return <String, dynamic>{
        'id': doc.id,
        'name': data['name']?.toString().trim().isNotEmpty == true
            ? data['name'].toString()
            : 'Branch',
        'city': data['city']?.toString() ?? '',
        'address': data['address']?.toString() ?? '',
      };
    }).toList();

    branches.sort(
      (a, b) => (a['name'] as String).compareTo(
        b['name'] as String,
      ),
    );

    if (mounted) {
      setState(() {
        _branches = branches;
      });
    }

    return branches;
  }

  Future<void> _refresh() async {
    await _loadInitialData();
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();

    final filtered = _allCars.where((car) {
      // Explore is a fleet search screen: once the customer explicitly
      // checks availability, show only cars that can actually be booked
      // for the selected range. Before that check, show the active fleet.
      if (_availabilityChecked && !_availableCarIds.contains(car.id)) {
        return false;
      }

      final matchesSearch = query.isEmpty ||
          car.name.toLowerCase().contains(query) ||
          car.type.toLowerCase().contains(query) ||
          car.fuel.toLowerCase().contains(query) ||
          car.transmission.toLowerCase().contains(query) ||
          car.registrationNumber.toLowerCase().contains(query);

      final matchesType =
          _selectedType == 'All' ||
          car.type.trim().toLowerCase() ==
              _selectedType.trim().toLowerCase();

      final matchesTransmission =
          _selectedTransmission == 'All' ||
          car.transmission.trim().toLowerCase() ==
              _selectedTransmission.trim().toLowerCase();

      final matchesFuel =
          _selectedFuel == 'All' ||
          car.fuel.trim().toLowerCase() ==
              _selectedFuel.trim().toLowerCase();

      final matchesBranch =
          _selectedBranchId == 'All' ||
          car.branchIds.contains(_selectedBranchId);

      return matchesSearch &&
          matchesType &&
          matchesTransmission &&
          matchesFuel &&
          matchesBranch;
    }).toList();

    filtered.sort((a, b) {
      if (_availabilityChecked) {
        final aAvailable = _availableCarIds.contains(a.id);
        final bAvailable = _availableCarIds.contains(b.id);

        if (aAvailable != bAvailable) {
          return aAvailable ? -1 : 1;
        }
      }

      final sortA = a.sortOrder;
      final sortB = b.sortOrder;

      if (sortA != sortB) {
        return sortA.compareTo(sortB);
      }

      return a.name.toLowerCase().compareTo(
            b.name.toLowerCase(),
          );
    });

    if (mounted) {
      setState(() {
        _visibleCars = filtered;
      });
    }
  }

  Future<void> _checkAvailability({
    bool showMessage = true,
  }) async {
    FocusScope.of(context).unfocus();

    final pickup = DateTime(
      _pickupDate.year,
      _pickupDate.month,
      _pickupDate.day,
      _pickupTime.hour,
      _pickupTime.minute,
    );

    final returnTime = DateTime(
      _returnDate.year,
      _returnDate.month,
      _returnDate.day,
      _returnTime.hour,
      _returnTime.minute,
    );

    if (!returnTime.isAfter(pickup)) {
      _showMessage(
        'Return date and time must be after pickup.',
        error: true,
      );
      return;
    }

    if (_tenantId.isEmpty) {
      _showMessage(
        'Tenant configuration is missing.',
        error: true,
      );
      return;
    }

    setState(() {
      _checkingAvailability = true;
      _availabilityChecked = false;
    });

    try {
      final range = _availabilityService.normalizeRentalRange(
        pickupDateTime: pickup,
        returnDateTime: returnTime,
        rentalType: _rentalType,
      );

      final snapshot =
          await _availabilityService.getAvailabilityForRange(
        rangeStart: range.start,
        rangeEnd: range.end,
        tenantId: _tenantId,
      );

      final available = snapshot.cars.where((car) {
        if (_selectedBranchId != 'All' &&
            !car.branchIds.contains(_selectedBranchId)) {
          return false;
        }

        return _availabilityService.isCarAvailableForRange(
          car: car,
          start: range.start,
          end: range.end,
          bookings: snapshot.bookings,
          blocks: snapshot.blocks,
        );
      }).toList();

      if (!mounted) return;

      setState(() {
        _availableCarIds = available.map((car) => car.id).toSet();
        _availabilityChecked = true;
        _checkingAvailability = false;
      });

      _applyFilters();

      if (showMessage) {
        _showMessage(
          '${available.length} car${available.length == 1 ? '' : 's'} available for your selected dates.',
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _checkingAvailability = false;
        _availabilityChecked = false;
        _availableCarIds = <String>{};
      });

      _applyFilters();

      _showMessage(
        _cleanError(e),
        error: true,
      );
    }
  }

  Future<void> _openDateTimePicker({
    required bool pickup,
  }) async {
    DateTime workingDate = pickup ? _pickupDate : _returnDate;
    TimeOfDay workingTime = pickup ? _pickupTime : _returnTime;

    final minDate = DateTime.now();
    final maxDate = DateTime.now().add(const Duration(days: 730));

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final slots = _timeSlotsFor(
              date: workingDate,
              pickup: pickup,
            );

            return SafeArea(
              top: false,
              child: Container(
                decoration: const BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: border,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: softAccent,
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Icon(
                              pickup
                                  ? Icons.login_rounded
                                  : Icons.logout_rounded,
                              color: primary,
                              size: 21,
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pickup
                                      ? 'Pickup date & time'
                                      : 'Return date & time',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    color: heading,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Select a date, then choose a time slot',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: body,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: const Icon(Icons.close_rounded),
                            color: body,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: background,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: border),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: CalendarDatePicker(
                          initialDate: workingDate.isBefore(minDate)
                              ? minDate
                              : workingDate,
                          firstDate: minDate,
                          lastDate: maxDate,
                          currentDate: DateTime.now(),
                          onDateChanged: (value) {
                            var next = DateTime(
                              value.year,
                              value.month,
                              value.day,
                            );

                            if (!pickup &&
                                next.isBefore(_pickupDate)) {
                              next = _pickupDate;
                            }

                            workingDate = next;

                            if (!pickup &&
                                _sameDate(workingDate, _pickupDate) &&
                                !_isTimeAfter(
                                  workingTime,
                                  _pickupTime,
                                )) {
                              workingTime = _nextSlotAfter(_pickupTime);
                            }

                            setSheetState(() {});
                          },
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Available time slots',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: heading,
                              ),
                            ),
                          ),
                          Text(
                            _formatDate(workingDate),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      SizedBox(
                        height: 54,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: slots.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 8),
                          itemBuilder: (_, index) {
                            final slot = slots[index];
                            final selected =
                                slot.hour == workingTime.hour &&
                                    slot.minute == workingTime.minute;

                            return GestureDetector(
                              onTap: () {
                                workingTime = slot;
                                setSheetState(() {});
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                width: 76,
                                decoration: BoxDecoration(
                                  color: selected ? primary : background,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: selected ? primary : border,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.access_time_rounded,
                                      size: 14,
                                      color: selected ? Colors.white : muted,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      _formatTime(slot),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        color: selected
                                            ? Colors.white
                                            : heading,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: softAccent,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.event_available_rounded,
                              size: 17,
                              color: primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${_formatDate(workingDate)} • ${_formatTime(workingTime)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: heading,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            if (!pickup &&
                                !DateTime(
                                  workingDate.year,
                                  workingDate.month,
                                  workingDate.day,
                                  workingTime.hour,
                                  workingTime.minute,
                                ).isAfter(DateTime(
                                  _pickupDate.year,
                                  _pickupDate.month,
                                  _pickupDate.day,
                                  _pickupTime.hour,
                                  _pickupTime.minute,
                                ))) {
                              _showMessage(
                                'Return must be after pickup.',
                                error: true,
                              );
                              return;
                            }

                            setState(() {
                              if (pickup) {
                                _pickupDate = workingDate;
                                _pickupTime = workingTime;

                                final pickupDateTime = DateTime(
                                  _pickupDate.year,
                                  _pickupDate.month,
                                  _pickupDate.day,
                                  _pickupTime.hour,
                                  _pickupTime.minute,
                                );
                                final returnDateTime = DateTime(
                                  _returnDate.year,
                                  _returnDate.month,
                                  _returnDate.day,
                                  _returnTime.hour,
                                  _returnTime.minute,
                                );

                                if (!returnDateTime.isAfter(pickupDateTime)) {
                                  final next = pickupDateTime.add(
                                    const Duration(days: 1),
                                  );
                                  _returnDate = DateTime(
                                    next.year,
                                    next.month,
                                    next.day,
                                  );
                                  _returnTime = TimeOfDay(
                                    hour: next.hour,
                                    minute: next.minute,
                                  );
                                }
                              } else {
                                _returnDate = workingDate;
                                _returnTime = workingTime;
                              }

                              _availabilityChecked = false;
                              _availableCarIds = <String>{};
                            });

                            _applyFilters();
                            Navigator.pop(sheetContext);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: Text(
                            pickup ? 'Confirm pickup' : 'Confirm return',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
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
  }

  List<TimeOfDay> _timeSlotsFor({
    required DateTime date,
    required bool pickup,
  }) {
    final now = DateTime.now();
    final slots = <TimeOfDay>[];

    // Explore is fleet-level, so it does not expose a specific car's
    // availability. It offers the same compact slot-style input used by the
    // booking flow, while the final fleet availability is checked afterwards.
    for (int hour = 0; hour < 24; hour++) {
      for (int minute = 0; minute < 60; minute += 30) {
        final candidate = DateTime(
          date.year,
          date.month,
          date.day,
          hour,
          minute,
        );

        if (pickup && _sameDate(date, now) &&
            candidate.isBefore(now.add(const Duration(minutes: 30)))) {
          continue;
        }

        if (!pickup && _sameDate(date, _pickupDate)) {
          final pickupDateTime = DateTime(
            _pickupDate.year,
            _pickupDate.month,
            _pickupDate.day,
            _pickupTime.hour,
            _pickupTime.minute,
          );
          if (!candidate.isAfter(pickupDateTime)) continue;
        }

        slots.add(TimeOfDay(hour: hour, minute: minute));
      }
    }

    return slots.isEmpty
        ? <TimeOfDay>[const TimeOfDay(hour: 10, minute: 0)]
        : slots;
  }

  bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isTimeAfter(TimeOfDay a, TimeOfDay b) {
    return a.hour > b.hour ||
        (a.hour == b.hour && a.minute > b.minute);
  }

  TimeOfDay _nextSlotAfter(TimeOfDay value) {
    var minutes = value.hour * 60 + value.minute + 30;
    if (minutes >= 24 * 60) {
      minutes = 23 * 60 + 30;
    }
    return TimeOfDay(
      hour: minutes ~/ 60,
      minute: minutes % 60,
    );
  }

  void _openCarDetails(Car car) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CarDetailsScreen(car: car),
      ),
    );
  }

  List<String> _uniqueValues(
    String Function(Car car) getter,
  ) {
    final values = _allCars
        .map(getter)
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();

    values.sort();
    return values;
  }

  String _branchName(String branchId) {
    if (branchId == 'All') return 'All branches';

    for (final branch in _branches) {
      if (branch['id']?.toString() == branchId) {
        return branch['name']?.toString() ?? 'Branch';
      }
    }

    return 'Branch';
  }

  String _cleanError(Object error) {
    final text = error.toString();

    if (text.startsWith('Exception: ')) {
      return text.substring(11);
    }

    return text;
  }

  String _formatDate(DateTime value) {
    const months = <String>[
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

    return '${value.day} ${months[value.month - 1]} ${value.year}';
  }

  String _formatTime(TimeOfDay value) {
    final hour = value.hourOfPeriod == 0 ? 12 : value.hourOfPeriod;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.period == DayPeriod.am ? 'AM' : 'PM';

    return '$hour:$minute $period';
  }

  void _showMessage(
    String message, {
    bool error = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          backgroundColor: error ? const Color(0xFF8B3A3A) : primary,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final typeValues = _uniqueValues((car) => car.type);
    final transmissionValues =
        _uniqueValues((car) => car.transmission);
    final fuelValues = _uniqueValues((car) => car.fuel);

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: RefreshIndicator(
          color: primary,
          onRefresh: _refresh,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: _buildHeader(),
              ),
              SliverToBoxAdapter(
                child: _buildAvailabilityPanel(),
              ),
              SliverToBoxAdapter(
                child: _buildFilterPanel(
                  typeValues,
                  transmissionValues,
                  fuelValues,
                ),
              ),
              SliverToBoxAdapter(
                child: _buildResultHeader(),
              ),
              if (_loadingCars)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: primary,
                      strokeWidth: 2,
                    ),
                  ),
                )
              else if (_errorMessage != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildErrorState(),
                )
              else if (_visibleCars.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    0,
                    16,
                    32,
                  ),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 420,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.72,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final car = _visibleCars[index];

                        return _buildExploreCarCard(car);
                      },
                      childCount: _visibleCars.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: softAccent,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.travel_explore_rounded,
              color: primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Explore cars',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    color: heading,
                    height: 1.05,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Find your next ride and check availability.',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: body,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadingCars ? null : _refresh,
            icon: const Icon(
              Icons.refresh_rounded,
              color: heading,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityPanel() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0717201F),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Check availability',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: heading,
                  ),
                ),
              ),
              if (_availabilityChecked)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: softAccent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'CHECKED',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: primary,
                      letterSpacing: .4,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _buildRentalTypeToggle(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _dateTimeTile(
                  icon: Icons.login_rounded,
                  label: 'Pickup',
                  date: _formatDate(_pickupDate),
                  time: _formatTime(_pickupTime),
                  onDateTap: () => _openDateTimePicker(pickup: true),
                  onTimeTap: () => _openDateTimePicker(pickup: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _dateTimeTile(
                  icon: Icons.logout_rounded,
                  label: 'Return',
                  date: _formatDate(_returnDate),
                  time: _formatTime(_returnTime),
                  onDateTap: () => _openDateTimePicker(pickup: false),
                  onTimeTap: () => _openDateTimePicker(pickup: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _checkingAvailability
                  ? null
                  : () => _checkAvailability(),
              icon: _checkingAvailability
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.search_rounded,
                      size: 18,
                    ),
              label: Text(
                _checkingAvailability
                    ? 'Checking...'
                    : 'Check availability',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: primary.withValues(
                  alpha: .55,
                ),
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRentalTypeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          _rentalTypeButton(
            title: 'Daily',
            subtitle: 'Full-day rental',
            value: 'daily',
          ),
          _rentalTypeButton(
            title: 'Hourly',
            subtitle: 'Short trip',
            value: 'hourly',
          ),
        ],
      ),
    );
  }

  Widget _rentalTypeButton({
    required String title,
    required String subtitle,
    required String value,
  }) {
    final selected = _rentalType == value;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _rentalType = value;
            _availabilityChecked = false;
            _availableCarIds = <String>{};
          });
          _applyFilters();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x0A17201F),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(
                value == 'daily'
                    ? Icons.today_outlined
                    : Icons.schedule_outlined,
                size: 18,
                color: selected ? primary : muted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: selected ? heading : body,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                        color: muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dateTimeTile({
    required IconData icon,
    required String label,
    required String date,
    required String time,
    required VoidCallback onDateTap,
    required VoidCallback onTimeTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: primary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: heading,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          InkWell(
            onTap: onDateTap,
            borderRadius: BorderRadius.circular(9),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 3,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_month_outlined,
                    size: 14,
                    color: muted,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      date,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: heading,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          InkWell(
            onTap: onTimeTap,
            borderRadius: BorderRadius.circular(9),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 3,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    size: 14,
                    color: muted,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    time,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: heading,
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

  Widget _buildFilterPanel(
    List<String> types,
    List<String> transmissions,
    List<String> fuels,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search cars, type, fuel, registration...',
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: muted,
              ),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: _searchController.clear,
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: muted,
                      ),
                    ),
              filled: true,
              fillColor: card,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: primary,
                  width: 1.2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                _filterDropdown(
                  value: _selectedBranchId,
                  label: _branchName(_selectedBranchId),
                  values: <String>[
                    'All',
                    ..._branches.map(
                      (branch) => branch['id'].toString(),
                    ),
                  ],
                  displayValue: _branchName,
                  onChanged: (value) {
                    setState(() {
                      _selectedBranchId = value ?? 'All';
                      _availabilityChecked = false;
                      _availableCarIds = <String>{};
                    });
                    _applyFilters();
                  },
                ),
                const SizedBox(width: 8),
                _filterDropdown(
                  value: _selectedType,
                  label: _selectedType == 'All'
                      ? 'All types'
                      : _selectedType,
                  values: <String>[
                    'All',
                    ...types,
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedType = value ?? 'All';
                    });
                    _applyFilters();
                  },
                ),
                const SizedBox(width: 8),
                _filterDropdown(
                  value: _selectedTransmission,
                  label: _selectedTransmission == 'All'
                      ? 'Transmission'
                      : _selectedTransmission,
                  values: <String>[
                    'All',
                    ...transmissions,
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedTransmission = value ?? 'All';
                    });
                    _applyFilters();
                  },
                ),
                const SizedBox(width: 8),
                _filterDropdown(
                  value: _selectedFuel,
                  label: _selectedFuel == 'All'
                      ? 'Fuel'
                      : _selectedFuel,
                  values: <String>[
                    'All',
                    ...fuels,
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedFuel = value ?? 'All';
                    });
                    _applyFilters();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterDropdown({
    required String value,
    required String label,
    required List<String> values,
    required ValueChanged<String?> onChanged,
    String Function(String value)? displayValue,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: values.contains(value) ? value : values.first,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 17,
            color: muted,
          ),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: heading,
          ),
          items: values.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                displayValue?.call(item) ??
                    (item == 'All' ? 'All' : item),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildResultHeader() {
    final availableCount = _availabilityChecked ? _visibleCars.length : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _availabilityChecked
                  ? '$availableCount available cars'
                  : '${_visibleCars.length} cars',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: heading,
              ),
            ),
          ),
          if (_availabilityChecked)
            TextButton(
              onPressed: () {
                setState(() {
                  _availabilityChecked = false;
                  _availableCarIds = <String>{};
                });
                _applyFilters();
              },
              child: const Text(
                'Clear check',
                style: TextStyle(
                  color: primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExploreCarCard(Car car) {
    return Stack(
      children: [
        Positioned.fill(
          child: CarCard(
            car: car,
            onTap: () => _openCarDetails(car),
          ),
        ),
        if (_availabilityChecked)
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 9,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .95),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 13,
                    color: primary,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'AVAILABLE',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: primary,
                      letterSpacing: .3,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: softAccent,
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.directions_car_outlined,
              color: primary,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Unable to load cars',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: heading,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _errorMessage ?? 'Please try again.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: body,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: _loadInitialData,
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
            child: const Text(
              'Retry',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasFilters = _searchController.text.trim().isNotEmpty ||
        _selectedType != 'All' ||
        _selectedTransmission != 'All' ||
        _selectedFuel != 'All' ||
        _selectedBranchId != 'All';

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: softAccent,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.search_off_rounded,
              color: primary,
              size: 34,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            hasFilters
                ? 'No matching cars'
                : 'No cars available',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: heading,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            hasFilters
                ? 'Try changing your search or filters.'
                : 'There are no active vehicles to show right now.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: body,
              height: 1.4,
            ),
          ),
          if (hasFilters) ...[
            const SizedBox(height: 14),
            TextButton(
              onPressed: () {
                setState(() {
                  _searchController.clear();
                  _selectedType = 'All';
                  _selectedTransmission = 'All';
                  _selectedFuel = 'All';
                  _selectedBranchId = 'All';
                });
                _applyFilters();
              },
              child: const Text(
                'Clear filters',
                style: TextStyle(
                  color: primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
