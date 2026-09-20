import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/config/app_config.dart';
import '../../../cars/models/car.dart';
import '../../../cars/services/car_service.dart';
import '../../../customer/models/customer.dart';
import '../../../customer/services/customer_service.dart';
import '../../../pricing/manager/pricing_manager.dart';
import '../../../pricing/models/km_pricing_package.dart';
import '../../../pricing/models/pricing_config.dart';
import '../../../pricing/models/pricing_profile.dart';
import '../../../pricing/engine/pricing_engine.dart';
import '../../../booking/models/booking.dart';
import '../services/admin_availability_service.dart';
import '../../../booking/services/booking_service.dart';
import '../../customers/screens/admin_add_customer_screen.dart';

enum AdminRentalType {
  hourly,
  daily,
}

/// Complete admin-side rental booking flow.
///
/// Flow:
///   Dates/time -> search availability -> select vehicle ->
///   fresh vehicle availability check -> branch -> customer ->
///   KM package -> pricing -> payment/review -> create booking.
///
/// This screen deliberately does not use the tenant branding colors stored in
/// Firestore. It uses the fixed premium application palette.
class AdminNewBookingScreen extends StatefulWidget {
  const AdminNewBookingScreen({super.key});

  @override
  State<AdminNewBookingScreen> createState() => _AdminNewBookingScreenState();
}

class _AdminNewBookingScreenState extends State<AdminNewBookingScreen> {
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
  final CarService _carService = CarService.instance;
  final CustomerService _customerService = CustomerService.instance;
  final AdminAvailabilityService _availabilityService =
      AdminAvailabilityService.instance;
  final PricingEngine _pricingEngine = const PricingEngine();
  final BookingService _bookingService = BookingService();

  String get _tenantId => AppConfig.tenant.tenantId;

  AdminRentalType? _rentalType;

  DateTime _pickupDate = DateTime.now();
  DateTime _returnDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _pickupTime = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _returnTime = const TimeOfDay(hour: 10, minute: 0);

  // Full active fleet is shown after rental type selection.
  List<Car> _fleetCars = [];
  List<Car> _availableCars = [];
  final Set<DateTime> _blockedFullDays = <DateTime>{};
  bool _loadingCalendar = false;
  Car? _selectedCar;
  AdminAvailabilitySnapshot? _availabilitySnapshot;

  // Every calendar load gets a generation number. Older async requests are
  // ignored so a previous vehicle/month can never overwrite the current one.
  int _availabilityRequestId = 0;

  // Month currently displayed by the premium availability calendar.
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  // Direct in-calendar range selection. No second date-picker is opened.
  DateTime? _calendarSelectionStart;
  DateTime? _calendarSelectionEnd;

  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _allBranches = [];
  String? _selectedBranchId;

  List<Customer> _customers = [];
  Customer? _selectedCustomer;

  PricingProfile? _pricingProfile;
  List<KmPricingPackage> _packages = [];
  KmPricingPackage? _selectedPackage;
  PricingResult? _pricingResult;

  String _customerSearch = '';
  String _paymentMethod = 'cash';
  double _paidAmount = 0;
  String _bookingNote = '';
  String _depositMethod = 'cash';
  double _depositAmount = 0;
  String _depositAssetDetails = '';

  // Booking-level admin pricing overrides. These do not modify the saved
  // vehicle pricing profile.
  double? _adminRentalPrice;
  double? _adminExtraKmCharge;
  double? _adminExtraTimeCharge;
  double? _adminAddOnTotal;
  double? _adminProtectionTotal;
  double? _adminDiscountAmount;
  double? _adminTaxAmount;
  double? _adminTotal;
  bool _adminTotalManuallyEdited = false;

  int _step = 1;
  bool _loading = false;
  bool _loadingCustomers = false;
  bool _creatingBooking = false;
  String? _error;

  DateTime get _pickupDateTime {
    if (_rentalType == AdminRentalType.hourly) {
      return DateTime(
        _pickupDate.year,
        _pickupDate.month,
        _pickupDate.day,
        _pickupTime.hour,
        _pickupTime.minute,
      );
    }

    return DateTime(
      _pickupDate.year,
      _pickupDate.month,
      _pickupDate.day,
      0,
      0,
      0,
    );
  }

  /// Daily bookings occupy the complete return date until 11:59:59.999 PM.
  /// Hourly bookings use the exact selected return time.
  DateTime get _returnDateTime {
    if (_rentalType == AdminRentalType.hourly) {
      return DateTime(
        _returnDate.year,
        _returnDate.month,
        _returnDate.day,
        _returnTime.hour,
        _returnTime.minute,
      );
    }

    return DateTime(
      _returnDate.year,
      _returnDate.month,
      _returnDate.day,
      23,
      59,
      59,
      999,
    );
  }

  // FIRST availability search happens before rental type is selected.
  // At that point we treat the requested dates as whole calendar days so the
  // admin can discover every vehicle that can serve the requested period.
  DateTime get _initialAvailabilityStart => DateTime(
        _pickupDate.year,
        _pickupDate.month,
        _pickupDate.day,
      );

  DateTime get _initialAvailabilityEnd => DateTime(
        _returnDate.year,
        _returnDate.month,
        _returnDate.day,
        23,
        59,
        59,
        999,
      );

  String get _rentalTypeLabel {
    switch (_rentalType) {
      case AdminRentalType.hourly:
        return 'Hourly';
      case AdminRentalType.daily:
        return 'Daily';
      case null:
        return 'Select rental type';
    }
  }

  bool get _isHourly => _rentalType == AdminRentalType.hourly;

  RentalType? get _pricingRentalType {
    switch (_rentalType) {
      case AdminRentalType.hourly:
        return RentalType.hourly;
      case AdminRentalType.daily:
        return RentalType.daily;
      case null:
        return null;
    }
  }

  bool _isCarAssignedToTenant(Car car) {
    return car.tenantId == _tenantId && car.isActive;
  }


  DateTime _dayOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  Map<String, dynamic>? get _selectedBranch {
    if (_selectedBranchId == null) return null;
    try {
      return _branches.firstWhere(
        (branch) => branch['id']?.toString() == _selectedBranchId,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    print('🔥🔥🔥 ADMIN NEW BOOKING SCREEN INIT 🔥🔥🔥');
    print('🔥 Tenant ID: $_tenantId');
    print('🔥 Admin New Booking Screen loaded successfully');
    _loadBranches();
    _loadCustomers();
    _loadFleetCars();
  }

  Future<void> _loadFleetCars() async {
    try {
      final cars = await _carService.getCars(tenantId: _tenantId);
      if (!mounted) return;
      setState(() => _fleetCars = cars);
      print('🔥 FLEET CARS LOADED | count=${cars.length}');
    } catch (e, stackTrace) {
      print('❌ FLEET LOAD ERROR: $e');
      print(stackTrace);
    }
  }

  Future<void> _loadBranches() async {
    try {
      final snapshot = await _firestore
          .collection('tenants')
          .doc(_tenantId)
          .collection('branches')
          .where('isActive', isEqualTo: true)
          .get();

      if (!mounted) return;
      final loadedBranches = snapshot.docs.map((doc) {
        final data = doc.data();
        return <String, dynamic>{
          'id': doc.id,
          'name': data['name']?.toString() ?? 'Branch',
          'city': data['city']?.toString() ?? '',
          'address': data['address']?.toString() ?? '',
          'phone': data['phone']?.toString() ?? '',
        };
      }).toList();

      setState(() {
        _allBranches = loadedBranches;
        _branches = List<Map<String, dynamic>>.from(loadedBranches);
      });
    } catch (_) {}
  }

  Future<void> _loadCustomers() async {
    if (!mounted) return;
    setState(() => _loadingCustomers = true);
    try {
      final customers = await _customerService.getAllCustomers(
        tenantId: _tenantId,
        activeOnly: true,
      );
      if (!mounted) return;
      setState(() {
        _customers = customers;
        _loadingCustomers = false;
      });
    } catch (e, stackTrace) {
      print('❌ ADMIN PRICING ERROR: $e');
      print(stackTrace);
      if (!mounted) return;
      setState(() {
        _loadingCustomers = false;
        _error = 'Unable to load customers.';
      });
    }
  }

  List<Customer> get _filteredCustomers {
    final q = _customerSearch.trim().toLowerCase();
    if (q.isEmpty) return _customers;
    return _customers.where((customer) {
      return customer.fullName.toLowerCase().contains(q) ||
          customer.phone.toLowerCase().contains(q) ||
          customer.email.toLowerCase().contains(q) ||
          customer.customerId.toLowerCase().contains(q);
    }).toList();
  }

  /// Opens one calendar where the admin selects BOTH pickup and return dates.
  /// This fixes the old single-day CalendarDatePicker behaviour.
  Future<void> _selectRentalDateRange() async {
    FocusScope.of(context).unfocus();

    final today = _dayOnly(DateTime.now());
    final maxDate = today.add(const Duration(days: 730));
    var start = _pickupDate.isBefore(today) ? today : _dayOnly(_pickupDate);
    var end = _returnDate.isAfter(start) ? _dayOnly(_returnDate) : start.add(const Duration(days: 1));

    if (end.isAfter(maxDate)) {
      end = maxDate;
    }

    final initialRange = DateTimeRange(start: start, end: end);

    final selected = await showDateRangePicker(
      context: context,
      firstDate: today,
      lastDate: maxDate,
      initialDateRange: initialRange,
      currentDate: start,
      selectableDayPredicate: _isSelectableCalendarDay,
      saveText: 'Apply dates',
      helpText: _isHourly
          ? 'Select pickup and return dates'
          : 'Select daily rental period',
      builder: _pickerTheme,
    );

    if (selected == null) return;

    final pickup = _dayOnly(selected.start);
    final returnDate = _dayOnly(selected.end);

    if (!returnDate.isAfter(pickup)) {
      _showError('Please select a return date after the pickup date.');
      return;
    }

    if (_selectedCar != null && _rangeContainsBlockedDay(pickup, returnDate)) {
      _showError('The selected period contains a day when this vehicle is unavailable.');
      return;
    }

    setState(() {
      _pickupDate = pickup;
      _returnDate = returnDate;
      _resetAfterDateChange(keepVehicle: _selectedCar != null);
    });

    if (_selectedCar != null) {
      await _loadAvailabilityCalendar();
    }
  }

  /// Kept as compatibility methods because existing date tiles may still call them.
  /// Both now open the SAME range calendar instead of a one-day picker.
  Future<void> _selectPickupDate() => _selectRentalDateRange();

  Future<void> _selectReturnDate() => _selectRentalDateRange();

  /// Allows the admin to edit pickup directly from the date tile below the
  /// vehicle calendar without changing the in-calendar range selection UX.
  Future<void> _selectPickupDateOnly() async {
    FocusScope.of(context).unfocus();

    final today = _dayOnly(DateTime.now());
    final maxDate = today.add(const Duration(days: 730));

    final selected = await showDatePicker(
      context: context,
      initialDate: _pickupDate.isBefore(today) ? today : _pickupDate,
      firstDate: today,
      lastDate: maxDate,
      helpText: 'Select pickup date',
      cancelText: 'Cancel',
      confirmText: 'Apply',
      selectableDayPredicate: (day) {
        final normalized = _dayOnly(day);
        if (_blockedFullDays.contains(normalized)) return false;
        return true;
      },
      builder: _pickerTheme,
    );

    if (selected == null || !mounted) return;

    final pickup = _dayOnly(selected);
    var returnDate = _dayOnly(_returnDate);

    if (!returnDate.isAfter(pickup)) {
      returnDate = pickup.add(const Duration(days: 1));
    }

    if (_rangeContainsBlockedDay(pickup, returnDate)) {
      _showError('The selected period contains a booked or blocked day.');
      return;
    }

    setState(() {
      _pickupDate = pickup;
      _returnDate = returnDate;
      _calendarSelectionStart = pickup;
      _calendarSelectionEnd = returnDate;
      _pricingResult = null;
      _resetAfterDateChange(keepVehicle: _selectedCar != null);
    });

    if (_selectedCar != null) {
      await _loadAvailabilityCalendar();
    }
  }

  /// Allows the admin to edit return directly from the date tile below the
  /// vehicle calendar while enforcing return > pickup.
  Future<void> _selectReturnDateOnly() async {
    FocusScope.of(context).unfocus();

    final today = _dayOnly(DateTime.now());
    final minDate = _pickupDate.add(const Duration(days: 1));
    final maxDate = today.add(const Duration(days: 730));

    final safeFirstDate = minDate.isAfter(today) ? minDate : today;
    var initial = _returnDate.isAfter(safeFirstDate)
        ? _returnDate
        : safeFirstDate;

    if (initial.isAfter(maxDate)) initial = maxDate;

    final selected = await showDatePicker(
      context: context,
      initialDate: _dayOnly(initial),
      firstDate: _dayOnly(safeFirstDate),
      lastDate: maxDate,
      helpText: 'Select return date',
      cancelText: 'Cancel',
      confirmText: 'Apply',
      selectableDayPredicate: (day) {
        final normalized = _dayOnly(day);
        if (!normalized.isAfter(_pickupDate)) return false;
        if (_blockedFullDays.contains(normalized)) return false;
        return true;
      },
      builder: _pickerTheme,
    );

    if (selected == null || !mounted) return;

    final returnDate = _dayOnly(selected);

    if (!returnDate.isAfter(_pickupDate)) {
      _showError('Return date must be after pickup date.');
      return;
    }

    if (_rangeContainsBlockedDay(_pickupDate, returnDate)) {
      _showError('The selected period contains a booked or blocked day.');
      return;
    }

    setState(() {
      _returnDate = returnDate;
      _calendarSelectionStart = _dayOnly(_pickupDate);
      _calendarSelectionEnd = returnDate;
      _pricingResult = null;
      _resetAfterDateChange(keepVehicle: _selectedCar != null);
    });

    if (_selectedCar != null) {
      await _loadAvailabilityCalendar();
    }
  }

  bool _rangeContainsBlockedDay(DateTime start, DateTime end) {
    var cursor = _dayOnly(start);
    final last = _dayOnly(end);
    while (!cursor.isAfter(last)) {
      if (_blockedFullDays.contains(cursor)) return true;
      cursor = cursor.add(const Duration(days: 1));
    }
    return false;
  }

  Widget _pickerTheme(BuildContext context, Widget? child) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: const ColorScheme.light(
          primary: primary,
          surface: card,
        ),
      ),
      child: child!,
    );
  }

  Future<void> _selectPickupTime() async {
    if (!_isHourly) return;

    final selected = await showTimePicker(
      context: context,
      initialTime: _pickupTime,
      builder: _pickerTheme,
    );
    if (selected == null) return;

    setState(() {
      _pickupTime = selected;
      _pricingResult = null;

    });
  }

  Future<void> _selectReturnTime() async {
    if (!_isHourly) return;

    final selected = await showTimePicker(
      context: context,
      initialTime: _returnTime,
      builder: _pickerTheme,
    );
    if (selected == null) return;

    setState(() {
      _returnTime = selected;
      _pricingResult = null;

    });
  }

  bool _isSelectableCalendarDay(
    DateTime day,
    DateTime? start,
    DateTime? end,
  ) {
    final normalized = _dayOnly(day);

    // If the vehicle calendar has not loaded yet, do not let the picker
    // assume that a day is available.
    if (_selectedCar != null &&
        (_loadingCalendar || _availabilitySnapshot == null)) {
      return false;
    }

    if (_blockedFullDays.contains(normalized)) return false;

    return true;
  }

  void _invalidateAvailabilityCalendar() {
    // Invalidate every in-flight calendar request.
    _availabilityRequestId++;
    _loadingCalendar = false;
    _availabilitySnapshot = null;
    _blockedFullDays.clear();
  }

  void _resetAfterDateChange({bool keepVehicle = false}) {
    _invalidateAvailabilityCalendar();

    _availableCars = [];
    if (!keepVehicle) _selectedCar = null;
    _selectedBranchId = null;
    _pricingProfile = null;
    _packages = [];
    _selectedPackage = null;
    _pricingResult = null;
    _step = keepVehicle ? 4 : 1;
  }

  Future<void> _loadAvailabilityCalendar() async {
    final car = _selectedCar;
    if (car == null || !mounted) return;

    // Capture every piece of state that this request belongs to.
    final requestId = ++_availabilityRequestId;
    final carId = car.id;
    final calendarMonth = DateTime(
      _calendarMonth.year,
      _calendarMonth.month,
      1,
    );

    setState(() {
      _loadingCalendar = true;
      _blockedFullDays.clear();
      _availabilitySnapshot = null;
    });

    try {
      final monthEnd = DateTime(
        calendarMonth.year,
        calendarMonth.month + 1,
        0,
        23,
        59,
        59,
        999,
      );

      // AdminAvailabilityService reads operational availability from the
      // Firestore server, not a potentially stale local cache.
      final snapshot = await _availabilityService.getAvailabilityForRange(
        rangeStart: calendarMonth,
        rangeEnd: monthEnd,
        tenantId: _tenantId,
      );

      // IMPORTANT:
      // Do not allow an older vehicle/month request to update the UI after a
      // newer request has already started.
      if (!mounted || requestId != _availabilityRequestId) {
        print(
          '⚠️ IGNORING STALE CALENDAR RESPONSE '
          '| request=$requestId '
          '| current=$_availabilityRequestId '
          '| car=$carId '
          '| month=$calendarMonth',
        );
        return;
      }

      // The admin may have selected another vehicle while Firestore was
      // loading. The old response must never be applied to the new vehicle.
      if (_selectedCar?.id != carId) {
        print(
          '⚠️ IGNORING VEHICLE-MISMATCH CALENDAR RESPONSE '
          '| request=$requestId '
          '| responseCar=$carId '
          '| currentCar=${_selectedCar?.id}',
        );
        return;
      }

      // The month can also change while the previous request is in flight.
      final currentMonth = DateTime(
        _calendarMonth.year,
        _calendarMonth.month,
        1,
      );

      if (currentMonth != calendarMonth) {
        print(
          '⚠️ IGNORING MONTH-MISMATCH CALENDAR RESPONSE '
          '| request=$requestId '
          '| responseMonth=$calendarMonth '
          '| currentMonth=$currentMonth',
        );
        return;
      }

      final blocked = <DateTime>{};

      // Daily rentals need complete calendar-day availability. Hourly rentals
      // still use the live snapshot for BOOKED indicators, while their exact
      // time interval is checked again before continuing/creating the booking.
      if (!_isHourly) {
        var cursor = calendarMonth;

        while (!cursor.isAfter(monthEnd)) {
          final dayStart = DateTime(
            cursor.year,
            cursor.month,
            cursor.day,
          );

          final dayEnd = DateTime(
            cursor.year,
            cursor.month,
            cursor.day,
            23,
            59,
            59,
            999,
          );

          final available =
              _availabilityService.isCarAvailableForRange(
            car: car,
            start: dayStart,
            end: dayEnd,
            bookings: snapshot.bookings,
            blocks: snapshot.blocks,
          );

          if (!available) {
            blocked.add(dayStart);
          }

          cursor = cursor.add(const Duration(days: 1));
        }
      }

      if (!mounted || requestId != _availabilityRequestId) return;

      if (_selectedCar?.id != carId) return;

      setState(() {
        _blockedFullDays
          ..clear()
          ..addAll(blocked);

        _availabilitySnapshot = snapshot;
        _loadingCalendar = false;
      });

      print(
        '🔥 CALENDAR REFRESHED '
        '| request=$requestId '
        '| car=$carId '
        '| month=$calendarMonth '
        '| bookings=${snapshot.bookings.length} '
        '| blocks=${snapshot.blocks.length} '
        '| blockedDays=${blocked.length}',
      );
    } catch (e, stackTrace) {
      print('❌ CALENDAR AVAILABILITY ERROR: $e');
      print(stackTrace);

      if (!mounted || requestId != _availabilityRequestId) return;

      setState(() {
        _loadingCalendar = false;
        _availabilitySnapshot = null;
        _blockedFullDays.clear();
      });
    }
  }

  void _resetFromAvailability() {
    _invalidateAvailabilityCalendar();

    _availableCars = [];
    _selectedCar = null;
    _selectedBranchId = null;
    _pricingProfile = null;
    _packages = [];
    _selectedPackage = null;
    _pricingResult = null;
    _step = 2;
  }

  Future<void> _searchAvailability() async {
    print('🔥 SEARCH FULL FLEET | pickup=$_initialAvailabilityStart | return=$_initialAvailabilityEnd');
    FocusScope.of(context).unfocus();

    if (!_initialAvailabilityStart.isBefore(_initialAvailabilityEnd)) {
      _showError('Return date must be after pickup date.');
      return;
    }

    if (_initialAvailabilityStart.isBefore(
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
    )) {
      _showError('Pickup date cannot be in the past.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final snapshot = await _availabilityService.getAvailabilityForRange(
        rangeStart: _initialAvailabilityStart,
        rangeEnd: _initialAvailabilityEnd,
        tenantId: _tenantId,
      );

      final fleet = snapshot.cars.where(_isCarAssignedToTenant).toList();
      final available = fleet.where((car) {
        return _availabilityService.isCarAvailableForRange(
          car: car,
          start: _initialAvailabilityStart,
          end: _initialAvailabilityEnd,
          bookings: snapshot.bookings,
          blocks: snapshot.blocks,
        );
      }).toList();

      available.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      if (!mounted) return;
      setState(() {
        _fleetCars = fleet;
        _availableCars = available;
        _availabilitySnapshot = snapshot;
        _selectedCar = null;
        _selectedBranchId = null;
        _pricingProfile = null;
        _packages = [];
        _selectedPackage = null;
        _pricingResult = null;
        _loading = false;
        _step = 2;
      });

      print('🔥 FULL FLEET AVAILABLE | total=${fleet.length} | available=${available.length}');
    } catch (e, stackTrace) {
      print('❌ FULL FLEET AVAILABILITY ERROR: $e');
      print(stackTrace);
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('Unable to check vehicle availability.');
    }
  }

  Future<void> _confirmVehicleCalendarAvailability() async {
    final car = _selectedCar;
    final type = _rentalType;
    if (car == null) {
      _showError('Please select a vehicle.');
      return;
    }
    if (type == null) {
      _showError('Please select a rental type.');
      return;
    }

    final pickup = _pickupDateTime;
    final returnTime = _returnDateTime;
    if (!pickup.isBefore(returnTime)) {
      _showError('Return date/time must be after pickup date/time.');
      return;
    }

    if (_isHourly && pickup.isBefore(DateTime.now())) {
      _showError('Pickup time cannot be in the past.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final snapshot = await _availabilityService.getAvailabilityForRange(
        rangeStart: pickup,
        rangeEnd: returnTime,
        tenantId: _tenantId,
      );
      final freshCar = snapshot.cars.cast<Car?>().firstWhere(
        (candidate) => candidate?.id == car.id,
        orElse: () => null,
      );
      if (freshCar == null) throw Exception('VEHICLE_UNAVAILABLE');

      final available = _availabilityService.isCarAvailableForRange(
        car: freshCar,
        start: pickup,
        end: returnTime,
        bookings: snapshot.bookings,
        blocks: snapshot.blocks,
      );
      if (!available) throw Exception('VEHICLE_UNAVAILABLE');

      if (!mounted) return;
      setState(() {
        _selectedCar = freshCar;
        _availabilitySnapshot = snapshot;
        _loading = false;
        _step = 5;
      });
      await _prepareBranchesForVehicle(freshCar);
    } catch (e, stackTrace) {
      print('❌ VEHICLE CALENDAR FINAL CHECK ERROR: $e');
      print(stackTrace);
      if (!mounted) return;
      setState(() => _loading = false);
      if (e.toString().contains('VEHICLE_UNAVAILABLE')) {
        _showError('This vehicle is no longer available for the selected period.');
      } else {
        _showError('Unable to confirm vehicle availability.');
      }
    }
  }

  Future<void> _selectVehicle(Car car) async {
    print('🔥 SELECT VEHICLE | car=${car.id} | name=${car.name}');
    FocusScope.of(context).unfocus();

    // This is the second stage: vehicle selection happens BEFORE rental type.
    // Invalidate any previous vehicle's in-flight calendar request immediately.
    _availabilityRequestId++;

    // The exact rental-type availability calendar is loaded only after type selection.
    setState(() {
      _selectedCar = car;
      _availabilitySnapshot = null;
      _blockedFullDays.clear();
      _loadingCalendar = false;
      _selectedBranchId = null;
      _pricingProfile = null;
      _packages = [];
      _selectedPackage = null;
      _pricingResult = null;
      _step = 3;
    });

    await _prepareBranchesForVehicle(car);
  }

  Future<void> _prepareBranchesForVehicle(Car car) async {
    final valid = _allBranches.where((branch) {
      final branchId = branch['id']?.toString() ?? '';
      return car.branchIds.contains(branchId);
    }).toList();

    if (!mounted) return;
    setState(() {
      _branches = valid;
      if (valid.length == 1) {
        _selectedBranchId = valid.first['id']?.toString();
      }
    });
  }

  Future<void> _continueFromVehicle() async {
    print('🔥 CONTINUE BRANCH → CUSTOMER | car=${_selectedCar?.id} | branch=$_selectedBranchId');
    final car = _selectedCar;
    final branchId = _selectedBranchId;

    if (car == null) {
      _showError('Please select a vehicle.');
      return;
    }

    if (_branches.isEmpty) {
      _showError('No active branch is assigned to this vehicle.');
      return;
    }

    if (branchId == null || branchId.trim().isEmpty) {
      _showError('Please select the pickup branch.');
      return;
    }

    final assignedToCar = car.branchIds.contains(branchId);
    if (!assignedToCar) {
      _showError('Selected branch is not assigned to this vehicle.');
      return;
    }

    try {
      final branchDoc = await _firestore
          .collection('tenants')
          .doc(_tenantId)
          .collection('branches')
          .doc(branchId)
          .get();

      if (!branchDoc.exists || branchDoc.data() == null) {
        _showError('Selected branch was not found.');
        return;
      }

      final data = branchDoc.data()!;
      if (data['isActive'] != true) {
        _showError('Selected branch is no longer active.');
        return;
      }

      if (!mounted) return;
      setState(() => _step = 6);
    } catch (_) {
      _showError('Unable to verify the selected branch.');
    }
  }

  Future<void> _selectCustomer() async {
    print('🔥 SELECT CUSTOMER CALLED | customers=${_customers.length}');
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CustomerPickerSheet(
        customers: _filteredCustomers,
        selectedCustomer: _selectedCustomer,
        search: _customerSearch,
        onSearchChanged: (value) {
          setState(() => _customerSearch = value);
        },
        onSelected: (customer) async {
          Navigator.pop(context);

          if (!mounted) return;

          setState(() {
            _selectedCustomer = customer;
            _customerSearch = '';
          });

          print('🔥 CUSTOMER SELECTED');
          print('🔥 Customer ID: ${customer.customerId}');
          print('🔥 Customer Name: ${customer.fullName}');
          print('🔥 Starting pricing load...');

          await _loadPricing();
        },
        onCreateNew: () async {
          Navigator.pop(context);
          final customer = await _createNewCustomerWithOtp();
          if (customer != null && mounted) {
            setState(() {
              _selectedCustomer = customer;
            });

            print('🔥 NEW CUSTOMER CREATED');
            print('🔥 Customer ID: ${customer.customerId}');
            print('🔥 Starting pricing load...');

            await _loadPricing();
          }
        },
      ),
    );
  }

  Future<Customer?> _createNewCustomerWithOtp() async {
    final created = await Navigator.push<Customer>(
      context,
      MaterialPageRoute(
        builder: (_) => const AdminAddCustomerScreen(),
      ),
    );

    if (!mounted || created == null) {
      return null;
    }

    // Reload the canonical Firestore record so the booking always uses
    // customerId == document ID == Firebase UID.
    try {
      final canonical = await _customerService.getCustomer(
        tenantId: _tenantId,
        customerId: created.customerId,
      );

      final selected = canonical ?? created;

      if (!mounted) return selected;

      setState(() {
        _customers = [
          ..._customers.where(
            (item) => item.customerId != selected.customerId,
          ),
          selected,
        ];

        _customers.sort(
          (a, b) => a.fullName.toLowerCase().compareTo(
            b.fullName.toLowerCase(),
          ),
        );
      });

      return selected;
    } catch (_) {
      if (!mounted) return created;

      setState(() {
        _customers = [
          ..._customers.where(
            (item) => item.customerId != created.customerId,
          ),
          created,
        ];

        _customers.sort(
          (a, b) => a.fullName.toLowerCase().compareTo(
            b.fullName.toLowerCase(),
          ),
        );
      });

      return created;
    }
  }

  Future<void> _loadPricing() async {
    print('');
    print('==========================================');
    print('🔥🔥🔥 _loadPricing() CALLED 🔥🔥🔥');
    print('==========================================');
    print('🔥 Tenant ID: $_tenantId');
    print('🔥 Selected Car: ${_selectedCar?.id}');
    print('🔥 Car Name: ${_selectedCar?.name}');
    print('🔥 Pricing Profile ID: ${_selectedCar?.pricingProfileId}');
    print('==========================================');
    final car = _selectedCar;
    if (car == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Always load the vehicle pricing profile directly from Firestore.
      // This prevents an old PricingManager cache from hiding newly-created
      // KM packages such as pricing_seltos/kmPackages.
      developer.log(
        '========== ADMIN BOOKING PRICING DEBUG START ==========',
        name: 'AdminNewBooking',
      );
      print('========== ADMIN BOOKING PRICING DEBUG START ==========');
      print('tenantId = $_tenantId');
      print('car.id = ${car.id}');
      print('car.name = ${car.name}');
      print('car.pricingProfileId = [${car.pricingProfileId}]');
      developer.log('tenantId = $_tenantId', name: 'AdminNewBooking');
      developer.log('car.id = ${car.id}', name: 'AdminNewBooking');
      developer.log('car.name = ${car.name}', name: 'AdminNewBooking');
      developer.log('car.pricingProfileId = [${car.pricingProfileId}]', name: 'AdminNewBooking');

      if (car.pricingProfileId.trim().isEmpty) {
        developer.log(
          'ERROR: selected car has EMPTY pricingProfileId',
          name: 'AdminNewBooking',
        );
        throw Exception('This vehicle has no pricing profile assigned.');
      }

      // Refresh the tenant pricing config first so PricingEngine receives
      // the same simplified pricing profile that was just loaded.
      await PricingManager.instance.initialize(
        tenantId: _tenantId,
      );

      print('🔥 Calling PricingManager.loadPricingForCar...');
      print('🔥 tenantId = $_tenantId');
      print('🔥 pricingProfileId = ${car.pricingProfileId}');
      final profile = await PricingManager.instance.loadPricingForCar(
        tenantId: _tenantId,
        pricingProfileId: car.pricingProfileId.trim(),
      );
      print('🔥 PricingManager.loadPricingForCar returned.');
      print('🔥 Profile is ${profile == null ? 'NULL' : 'NOT NULL'}');

      developer.log(
        'PricingManager returned profile = ${profile == null ? 'NULL' : 'NOT NULL'}',
        name: 'AdminNewBooking',
      );
      print('PricingManager returned profile = ${profile == null ? 'NULL' : 'NOT NULL'}');

      if (profile == null) {
        developer.log(
          'ERROR: No PricingProfile returned for tenant=$_tenantId profileId=${car.pricingProfileId}',
          name: 'AdminNewBooking',
        );
        throw Exception('Pricing is unavailable for this vehicle.');
      }

      developer.log(
        'profile.id = ${profile.id}',
        name: 'AdminNewBooking',
      );

      final rentalType = _pricingRentalType ?? RentalType.daily;
      final packages = profile.packagesFor(rentalType);

      developer.log(
        'profile package count for ${rentalType.value} = ${packages.length}',
        name: 'AdminNewBooking',
      );
      print('profile.id = ${profile.id}');
      print(
        'profile package count for ${rentalType.value} = ${packages.length}',
      );

      for (final package in packages) {
        print(
          'PACKAGE => id=${package.id}, '
          'name=${package.name}, '
          'includedKm=${package.includedKm}, '
          'unlimitedKm=${package.unlimitedKm}, '
          'dailyRate=${package.safeDailyRate}, '
          'hourlyRate=${package.safeHourlyRate}, '
          'extraKmRate=${package.safeExtraKmRate}',
        );
      }

      // Diagnostic raw Firestore read when the selected rental type has no
      // packages. This reads the simplified package fields only.
      if (packages.isEmpty) {
        developer.log(
          'Parsed pricing packages are EMPTY. Reading raw Firestore document...',
          name: 'AdminNewBooking',
        );

        print('Parsed pricing packages EMPTY. Reading raw Firestore document...');
        final rawDoc = await _firestore
            .collection('tenants')
            .doc(_tenantId)
            .collection('pricingProfiles')
            .doc(car.pricingProfileId.trim())
            .get();

        developer.log(
          'RAW pricing doc exists = ${rawDoc.exists}',
          name: 'AdminNewBooking',
        );
        print('RAW pricing doc exists = ${rawDoc.exists}');
        developer.log(
          'RAW pricing doc path = tenants/$_tenantId/pricingProfiles/${car.pricingProfileId.trim()}',
          name: 'AdminNewBooking',
        );

        final rawData = rawDoc.data();
        print('RAW pricing document keys = ${rawData?.keys.toList()}');
        print('RAW hourlyPackages = ${rawData?['hourlyPackages']}');
        print('RAW dailyPackages = ${rawData?['dailyPackages']}');
        print('RAW pricing package fields = ${rawData?['rentalTypePricing']}');
        developer.log(
          'RAW pricing document keys = ${rawData?.keys.toList()}',
          name: 'AdminNewBooking',
        );
        developer.log(
          'RAW hourlyPackages = ${rawData?['hourlyPackages']}',
          name: 'AdminNewBooking',
        );
        developer.log(
          'RAW dailyPackages = ${rawData?['dailyPackages']}',
          name: 'AdminNewBooking',
        );
        developer.log(
          'RAW pricing package fields = ${rawData?['rentalTypePricing']}',
          name: 'AdminNewBooking',
        );

        if (!rawDoc.exists || rawData == null) {
          throw Exception(
            'Pricing document does not exist at tenants/$_tenantId/pricingProfiles/${car.pricingProfileId.trim()}.',
          );
        }

        throw Exception(
          'Pricing profile exists, but PricingProfile.fromMap returned 0 pricing packages. Check the DEBUG logs for RAW hourlyPackages/dailyPackages fields.',
        );
      }

      final typePackages = packages.where((package) {
        if (!package.isActive) return false;
        switch (_rentalType) {
          case AdminRentalType.hourly:
            return package.unlimitedKm || package.safeHourlyRate > 0;
          case AdminRentalType.daily:
            return package.unlimitedKm || package.safeDailyRate > 0;
          case null:
            return true;
        }
      }).toList();

      if (typePackages.isEmpty) {
        throw Exception(
          'No active KM packages are available for ${_rentalTypeLabel.toLowerCase()} rental.',
        );
      }

      // Prefer a finite KM package as the initial selection.
      // Unlimited remains available in the list and can be selected manually.
      KmPricingPackage? selected;
      if (typePackages.isNotEmpty) {
        try {
          selected = typePackages.firstWhere((package) => !package.unlimitedKm);
        } catch (_) {
          selected = typePackages.first;
        }
      }

      if (!mounted) return;
      // IMPORTANT: customer flow shows the KM package screen BEFORE pricing.
      // Do not jump directly to step 6 here.
      setState(() {
        _pricingProfile = profile;
        _packages = List<KmPricingPackage>.from(packages);
        _selectedPackage = selected;
        _pricingResult = null;
        _loading = false;
        _step = 7;
      });
    } catch (e, stackTrace) {
      print('❌❌❌ ADMIN PRICING ERROR ❌❌❌');
      print('❌ Error: $e');
      print('❌ StackTrace:');
      print(stackTrace);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
      _showError('Unable to load pricing for this vehicle.');
    }
  }

  void _calculatePricing() {
    print('🔥 CALCULATE PRICING CALLED | profile=${_pricingProfile?.id} | package=${_selectedPackage?.id}');
    final profile = _pricingProfile;
    if (profile == null) return;

    final config = PricingManager.instance.pricing;
    if (config == null) {
      _showError('Pricing configuration is unavailable.');
      return;
    }

    try {
      final selectedPackage = _selectedPackage;
      if (selectedPackage == null) {
        _showError('Please select a KM package.');
        return;
      }

      // PricingEngine supports the current KmPricingPackage architecture.
      // Do not cast KmPricingPackage to the legacy RentalPackage model.
      // IMPORTANT: use the real operational return time for pricing input.
      // PricingEngine is responsible for minimum billing rules; availability
      // must always use the customer's actual selected interval.
      final result = _pricingEngine.calculate(
        config: config,
        pricingProfileId: profile.id,
        pickupDateTime: _pickupDateTime,
        returnDateTime: _returnDateTime,
        actualKm: 0,
        plannedKm: 0,
        rentalType: _pricingRentalType ?? RentalType.daily,
        selectedKmPackageId: selectedPackage.id,
        selectedKm: selectedPackage.unlimitedKm
            ? null
            : selectedPackage.includedKm,
        unlimitedKm: selectedPackage.unlimitedKm,
        includeSecurityDeposit: true,
      );

      if (!mounted) return;
      setState(() {
        _pricingResult = result;
        _syncPricingOverrides(result);
      });
    } catch (e) {
      _showError('Unable to calculate pricing.');
    }
  }

  double _packageDisplayRate(KmPricingPackage package) {
    if (_rentalType == AdminRentalType.hourly) {
      return package.safeHourlyRate;
    }
    return package.safeDailyRate;
  }

  double _editableAmount(double? overrideValue, double fallback) =>
      overrideValue ?? fallback;

  double get _effectiveRentalPrice =>
      _editableAmount(_adminRentalPrice, _pricingResult?.rentalPrice ?? 0);

  double get _effectiveExtraKmCharge =>
      _editableAmount(_adminExtraKmCharge, _pricingResult?.extraKmCharge ?? 0);

  double get _effectiveExtraTimeCharge =>
      _editableAmount(_adminExtraTimeCharge, _pricingResult?.extraTimeCharge ?? 0);

  double get _effectiveAddOnTotal =>
      _editableAmount(_adminAddOnTotal, _pricingResult?.addOnTotal ?? 0);

  double get _effectiveProtectionTotal =>
      _editableAmount(_adminProtectionTotal, _pricingResult?.protectionTotal ?? 0);

  double get _effectiveDiscountAmount =>
      _editableAmount(_adminDiscountAmount, _pricingResult?.discountAmount ?? 0);

  double get _effectiveTaxAmount =>
      _editableAmount(_adminTaxAmount, _pricingResult?.taxAmount ?? 0);

  double get _calculatedAdminTotal =>
      (_effectiveRentalPrice +
              _effectiveExtraKmCharge +
              _effectiveExtraTimeCharge +
              _effectiveAddOnTotal +
              _effectiveProtectionTotal -
              _effectiveDiscountAmount +
              _effectiveTaxAmount)
          .clamp(0, double.infinity)
          .toDouble();

  double get _effectiveTripTotal =>
      _adminTotalManuallyEdited
          ? (_adminTotal ?? _calculatedAdminTotal)
          : _calculatedAdminTotal;

  bool get _isMonetaryDeposit =>
      _depositMethod == 'cash' ||
      _depositMethod == 'upi' ||
      _depositMethod == 'bank_transfer';

  double get _effectiveDepositAmount =>
      _depositMethod == 'none' || !_isMonetaryDeposit ? 0 : _depositAmount;

  double get _effectiveAmountPayable =>
      _effectiveTripTotal + _effectiveDepositAmount;

  void _syncPricingOverrides(PricingResult result) {
    _adminRentalPrice = result.rentalPrice;
    _adminExtraKmCharge = result.extraKmCharge;
    // Daily rentals are date-based. Their return date already occupies
    // the complete selected day, so the 23:59:59.999 availability boundary
    // must never be interpreted as paid "extra hours".
    _adminExtraTimeCharge =
        (_rentalType == AdminRentalType.hourly) ? result.extraTimeCharge : 0.0;
    _adminAddOnTotal = result.addOnTotal;
    _adminProtectionTotal = result.protectionTotal;
    _adminDiscountAmount = result.discountAmount;
    _adminTaxAmount = result.taxAmount;
    _adminTotal = result.total;
    _adminTotalManuallyEdited = false;
    if (_depositMethod == 'none' ||
        _depositMethod == 'vehicle_asset' ||
        _depositMethod == 'other_asset') {
      _depositAmount = 0;
    } else if (_depositAmount <= 0) {
      _depositAmount = result.securityDeposit;
    }
  }

  void _setEditablePricing(String field, double value) {
    final double safe = value.isFinite && value >= 0 ? value : 0.0;
    setState(() {
      switch (field) {
        case 'rental':
          _adminRentalPrice = safe;
          break;
        case 'extraKm':
          _adminExtraKmCharge = safe;
          break;
        case 'extraTime':
          _adminExtraTimeCharge = safe;
          break;
        case 'addons':
          _adminAddOnTotal = safe;
          break;
        case 'protection':
          _adminProtectionTotal = safe;
          break;
        case 'discount':
          _adminDiscountAmount = safe;
          break;
        case 'tax':
          _adminTaxAmount = safe;
          break;
      }
      if (!_adminTotalManuallyEdited) {
        _adminTotal = _calculatedAdminTotal;
      }
    });
  }

  void _setAdminTotal(String value) {
    final parsed = double.tryParse(value);
    if (parsed == null) return;
    setState(() {
      _adminTotal = parsed.clamp(0, double.infinity).toDouble();
      _adminTotalManuallyEdited = true;
    });
  }

  Widget _editablePriceField({
    required String label,
    required double value,
    required String field,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: GoogleFonts.manrope(
              color: body, fontSize: 12, fontWeight: FontWeight.w700,
            )),
          ),
          SizedBox(
            width: 125,
            child: TextFormField(
              initialValue: value.toStringAsFixed(2),
              textAlign: TextAlign.right,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: _inputDecoration('₹ Amount').copyWith(
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
              onChanged: (text) {
                final parsed = double.tryParse(text);
                if (parsed != null) _setEditablePricing(field, parsed);
              },
            ),
          ),
        ],
      ),
    );
  }

  void _selectPackage(KmPricingPackage package) {
    final rate = _selectedPackageRate(package);
    if (!package.unlimitedKm && rate <= 0) {
      _showError('${package.name} is not available for $_rentalTypeLabel rental.');
      return;
    }
    print('🔥 KM PACKAGE SELECTED | type=$_rentalTypeLabel | id=${package.id} | name=${package.name} | rate=$rate | includedKm=${package.includedKm} | unlimited=${package.unlimitedKm}');
    developer.log('KM PACKAGE SELECTED: id=${package.id}, name=${package.name}, includedKm=${package.includedKm}, unlimited=${package.unlimitedKm}', name: 'AdminNewBooking');
    setState(() {
      _selectedPackage = package;
    });
    _calculatePricing();
  }

  Future<void> _continueToReview() async {
    print('🔥 CONTINUE TO REVIEW | customer=${_selectedCustomer?.customerId} | car=${_selectedCar?.id} | pricing=${_pricingResult?.total}');
    if (_selectedCustomer == null) {
      _showError('Please select a customer.');
      return;
    }
    if (_selectedCar == null) {
      _showError('Please select a vehicle.');
      return;
    }
    if (_selectedBranchId == null) {
      _showError('Please select a pickup branch.');
      return;
    }
    if (_pricingResult == null || _pricingResult!.pricingProfileId.isEmpty) {
      _showError('Pricing could not be calculated.');
      return;
    }

    // One more availability check before entering the final review.
    setState(() => _loading = true);
    try {
      final snapshot = await _availabilityService.getAvailabilityForRange(
        rangeStart: _pickupDateTime,
        rangeEnd: _returnDateTime,
        tenantId: _tenantId,
      );
      final freshCar = snapshot.cars.cast<Car?>().firstWhere(
            (candidate) => candidate?.id == _selectedCar!.id,
            orElse: () => null,
          );

      if (freshCar == null) {
        throw Exception('VEHICLE_UNAVAILABLE');
      }

      final available = _availabilityService.isCarAvailableForRange(
        car: freshCar,
        start: _pickupDateTime,
        end: _returnDateTime,
        bookings: snapshot.bookings,
        blocks: snapshot.blocks,
      );
      if (!available) {
        throw Exception('VEHICLE_UNAVAILABLE');
      }
      if (!mounted) return;
      setState(() {
        _availabilitySnapshot = snapshot;
        _loading = false;
        _step = 9;
        _paidAmount = 0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (e.toString().contains('VEHICLE_UNAVAILABLE')) {
        _showError('This vehicle is no longer available. Please select another vehicle.');
      } else {
        _showError('Unable to recheck vehicle availability.');
      }
    }
  }

  Future<void> _createBooking() async {
    print('🔥 CREATE BOOKING CALLED | type=$_rentalTypeLabel | customer=${_selectedCustomer?.customerId} | car=${_selectedCar?.id} | pickup=$_pickupDateTime | return=$_returnDateTime | total=${_pricingResult?.total}');
    final customer = _selectedCustomer;
    final car = _selectedCar;
    final branch = _selectedBranch;
    final result = _pricingResult;
    final profile = _pricingProfile;

    if (customer == null || car == null || branch == null || result == null || profile == null) {
      _showError('Please complete all booking details.');
      return;
    }

    if (customer.customerId.trim().isEmpty) {
      _showError('Selected customer has no valid Firebase account.');
      return;
    }

    if (result.pricingProfileId.isEmpty) {
      _showError('Pricing is invalid.');
      return;
    }

    if ((_depositMethod == 'vehicle_asset' || _depositMethod == 'other_asset') &&
        _depositAssetDetails.trim().isEmpty) {
      _showError('Please enter the security asset details.');
      return;
    }

    // Re-fetch the selected customer so an inactive/deleted account cannot
    // accidentally be used after this screen has been open for some time.
    try {
      final customerDoc = await _firestore
          .collection('tenants')
          .doc(_tenantId)
          .collection('customers')
          .doc(customer.customerId)
          .get();

      if (!customerDoc.exists || customerDoc.data() == null) {
        _showError('Selected customer no longer exists.');
        return;
      }

      final customerData = customerDoc.data()!;
      if (customerData['tenantId']?.toString() != _tenantId) {
        _showError('Selected customer belongs to another tenant.');
        return;
      }

      if (customerData['isActive'] == false) {
        _showError('Selected customer is inactive.');
        return;
      }

      final storedCustomerId =
          customerData['customerId']?.toString().trim() ?? '';
      final firebaseUid =
          customerData['firebaseUid']?.toString().trim() ?? '';

      if (storedCustomerId.isNotEmpty &&
          storedCustomerId != customer.customerId) {
        _showError('Customer ID does not match the customer document.');
        return;
      }

      if (firebaseUid.isNotEmpty &&
          firebaseUid != customer.customerId) {
        _showError('Customer Firebase UID does not match the customer ID.');
        return;
      }

      if (firebaseUid.isEmpty) {
        _showError('Selected customer does not have a Firebase account.');
        return;
      }
    } catch (_) {
      _showError('Unable to verify the selected customer.');
      return;
    }

    // Monetary deposits are collected separately from the trip total.
    // Asset deposits never increase the payable total.
    final depositAmount = _effectiveDepositAmount;
    final total = _effectiveAmountPayable;
    if (_paidAmount < 0 || _paidAmount > total) {
      _showError('Paid amount must be between ₹0 and the total amount.');
      return;
    }

    final paymentStatus = _paidAmount >= total && total > 0
        ? PaymentStatus.paid
        : (_paidAmount > 0 ? PaymentStatus.partiallyPaid : PaymentStatus.pending);

    final pricingSnapshot = BookingPricingSnapshot(
      pricingProfileId: result.pricingProfileId,
      rentalType: result.rentalType,
      pricingVersion: result.pricingVersion,
      specialPricingRuleId: result.specialPricingRuleId,
      kmPackageId: result.selectedKmPackageId,
      kmPackageName: result.selectedKmPackageName,
      includedKm: result.includedKm,
      unlimitedKm: result.unlimitedKm,
      extraKmRate: result.selectedKmPackageExtraKmRate ?? _selectedPackage?.safeExtraKmRate ?? 0,
      baseAmount: _effectiveRentalPrice,
      extraKmAmount: _effectiveExtraKmCharge,
      extraTimeAmount: _effectiveExtraTimeCharge,
      addOnsAmount: _effectiveAddOnTotal,
      protectionAmount: _effectiveProtectionTotal,
      discountAmount: _effectiveDiscountAmount,
      taxAmount: _effectiveTaxAmount,
      securityDeposit: depositAmount,
      totalAmount: _effectiveTripTotal,
    );

    final booking = Booking(
      bookingId: '',
      tenantId: _tenantId,
      // IMPORTANT: customerId == customer document ID == Firebase UID.
      customerId: customer.customerId,
      carId: car.id,
      branchId: branch['id']?.toString() ?? '',
      status: BookingStatus.pending,
      paymentStatus: paymentStatus,
      pickupDateTime: _pickupDateTime,
      returnDateTime: _returnDateTime,
      pickupBranchId: branch['id']?.toString() ?? '',
      returnBranchId: branch['id']?.toString() ?? '',
      kmPackageId: result.selectedKmPackageId,
      kmPackageName: result.selectedKmPackageName,
      includedKm: result.includedKm,
      unlimitedKm: result.unlimitedKm,
      extraKmRate: result.selectedKmPackageExtraKmRate ?? _selectedPackage?.safeExtraKmRate ?? 0,
      pricingProfileId: result.pricingProfileId,
      baseAmount: _effectiveRentalPrice,
      extraKmAmount: _effectiveExtraKmCharge,
      extraTimeAmount: _effectiveExtraTimeCharge,
      addOnsAmount: _effectiveAddOnTotal,
      protectionAmount: _effectiveProtectionTotal,
      discountAmount: _effectiveDiscountAmount,
      taxAmount: _effectiveTaxAmount,
      securityDeposit: depositAmount,
      totalAmount: _effectiveTripTotal,
      pricing: pricingSnapshot,
      paidAmount: _paidAmount,
      refundAmount: 0,
      paymentMethod: _paymentMethod,
      couponCode: null,
      customerName: customer.fullName,
      customerPhone: customer.phone,
      customerEmail: customer.email,
      customerNote: [
        'Rental Type: $_rentalTypeLabel',
        'Deposit Method: $_depositMethod',
        if (depositAmount > 0) 'Deposit Amount: ${depositAmount.toStringAsFixed(2)}',
        if (_depositAssetDetails.trim().isNotEmpty) 'Deposit Asset: ${_depositAssetDetails.trim()}',
        if (_bookingNote.trim().isNotEmpty) 'Admin Note: ${_bookingNote.trim()}',
      ].join('\n'),
      cancellationReason: '',
      rejectionReason: '',
      expiresAt: null,
      createdAt: null,
      updatedAt: null,
    );

    setState(() {
      _creatingBooking = true;
      _error = null;
    });

    try {
      final created = await _bookingService.createBookingForAdmin(
        tenantId: _tenantId,
        booking: booking,
      );

      if (!mounted) return;
      setState(() => _creatingBooking = false);

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _BookingSuccessDialog(
          booking: created,
          customer: customer,
          car: car,
        ),
      );

      if (mounted) Navigator.pop(context, created);
    } catch (e) {
      if (!mounted) return;
      setState(() => _creatingBooking = false);
      _showError(_cleanError(e));
    }
  }

  String _cleanError(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '').trim();
    return text.isEmpty ? 'Unable to create booking.' : text;
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() => _error = message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
        ),
        backgroundColor: heading,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  void _back() {
    if (_step <= 1) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _step -= 1;
    });
  }

  @override
  void dispose() {
    // Prevent any in-flight availability response from being applied after
    // this screen has been removed.
    _availabilityRequestId++;
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    print('🔥 ADMIN NEW BOOKING BUILD | step=$_step | car=${_selectedCar?.id} | packages=${_packages.length}');
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: _back,
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: heading),
        ),
        title: Text(
          _step == 1 ? 'Rental Dates' :
          (_step == 2 ? 'Available Vehicles' :
          (_step == 3 ? 'Rental Type' :
          (_step == 4 ? 'Vehicle Calendar' :
          (_step == 7 ? 'Choose KM Package' :
          (_step == 8 ? 'Pricing & Payment' :
          (_step == 9 ? 'Final Review' : 'New Booking')))))),
          style: GoogleFonts.manrope(
            color: heading,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 120),
              children: [
                _buildProgress(),
                const SizedBox(height: 18),
                _buildStepContent(),
              ],
            ),
            if (_step == 7 && !_loading && !_creatingBooking && _packages.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
                  decoration: BoxDecoration(
                    color: background.withOpacity(.96),
                    border: const Border(
                      top: BorderSide(color: border),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x12000000),
                        blurRadius: 16,
                        offset: Offset(0, -5),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: _primaryButton(
                      'Continue',
                      Icons.arrow_forward_rounded,
                      () {
                        print('🔥 CONTINUE FROM KM PACKAGE PRESSED');
                        if (_selectedPackage == null) {
                          _showError('Please select a KM package.');
                          return;
                        }
                        _calculatePricing();
                        setState(() => _step = 8);
                      },
                    ),
                  ),
                ),
              ),
            if (_loading || _creatingBooking)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(.08),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: card,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: const [
                          BoxShadow(
                            blurRadius: 28,
                            offset: Offset(0, 10),
                            color: Color(0x18000000),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: primary),
                          const SizedBox(height: 14),
                          Text(
                            _creatingBooking
                                ? 'Creating booking...'
                                : 'Checking availability...',
                            style: GoogleFonts.manrope(
                              color: heading,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgress() {
    final labels = const ['Dates', 'Vehicles', 'Type', 'Vehicle Calendar', 'Branch', 'Customer', 'Package', 'Pricing', 'Confirm'];
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Booking ${_step}/9',
                style: GoogleFonts.manrope(
                  color: primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                labels[_step - 1],
                style: GoogleFonts.manrope(
                  color: heading,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: _step / 9,
              backgroundColor: softAccent,
              color: primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 1:
        return _buildInitialDates();
      case 2:
        return _buildVehicles();
      case 3:
        return _buildRentalType();
      case 4:
        return _buildDates();
      case 5:
        return _buildBranch();
      case 6:
        return _buildCustomer();
      case 7:
        return _buildPackage();
      case 8:
        return _buildPricing();
      case 9:
        return _buildReview();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildInitialDates() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heroCard(
          icon: Icons.calendar_month_rounded,
          title: 'Choose pickup & return dates',
          subtitle: 'Start with the rental period. We will check the entire active fleet before you choose a vehicle.',
        ),
        const SizedBox(height: 14),
        _sectionCard(
          title: 'Rental period',
          subtitle: 'Use the range calendar to select any pickup date and a later return date.',
          child: Column(
            children: [
              Row(children: [
                Expanded(child: _dateTile('Pickup date', _formatDate(_pickupDate), Icons.login_rounded, _selectPickupDate)),
                const SizedBox(width: 10),
                Expanded(child: _dateTile('Return date', _formatDate(_returnDate), Icons.logout_rounded, _selectReturnDate)),
              ]),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(color: softAccent, borderRadius: BorderRadius.circular(16)),
                child: Row(children: [
                  const Icon(Icons.info_outline_rounded, color: primary, size: 20),
                  const SizedBox(width: 9),
                  Expanded(child: Text('Select a complete pickup → return range. Daily rentals can span multiple days; exact hourly availability is checked again after the rental type is selected.', style: GoogleFonts.manrope(color: heading, fontSize: 10.5, height: 1.4, fontWeight: FontWeight.w700))),
                ]),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _primaryButton('Check All Available Vehicles', Icons.directions_car_rounded, _searchAvailability),
      ],
    );
  }


  Widget _buildRentalType() {
    final options = <Map<String, dynamic>>[
      {
        'type': AdminRentalType.hourly,
        'title': 'Hourly',
        'subtitle': 'Exact pickup & return time',
        'icon': Icons.schedule_rounded,
      },
      {
        'type': AdminRentalType.daily,
        'title': 'Daily',
        'subtitle': 'One or multiple calendar days',
        'icon': Icons.calendar_month_rounded,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heroCard(
          icon: Icons.directions_car_filled_rounded,
          title: 'Create a new booking',
          subtitle: 'Vehicle selected: ${_selectedCar?.name ?? 'Vehicle'}. Now choose how this booking should be billed, then confirm the vehicle-specific calendar.',
        ),
        const SizedBox(height: 16),
        _sectionCard(
          title: 'Rental type',
          subtitle: 'Choose how this booking should be billed.',
          child: Column(
            children: options.map((option) {
              final type = option['type'] as AdminRentalType;
              final selected = _rentalType == type;
              return GestureDetector(
                onTap: () async {
                  if (_selectedCar == null) {
                    _showError('Please select a vehicle first.');
                    return;
                  }
                  // Changing rental type changes the availability semantics,
                  // so an in-flight calendar response from the previous type is stale.
                  _availabilityRequestId++;

                  setState(() {
                    _rentalType = type;
                    _blockedFullDays.clear();
                    _availabilitySnapshot = null;
                    _loadingCalendar = false;
                    _selectedBranchId = null;
                    _pricingProfile = null;
                    _packages = [];
                    _selectedPackage = null;
                    _pricingResult = null;
                    _calendarSelectionStart = null;
                    _calendarSelectionEnd = null;
                    _calendarMonth = DateTime(_pickupDate.year, _pickupDate.month, 1);
                    _step = 4;
                  });
                  await _loadAvailabilityCalendar();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: selected ? softAccent : background,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: selected ? primary : border,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: selected ? primary : softAccent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          option['icon'] as IconData,
                          color: selected ? Colors.white : primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              option['title'] as String,
                              style: GoogleFonts.manrope(
                                color: heading,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              option['subtitle'] as String,
                              style: GoogleFonts.manrope(
                                color: body,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        selected
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        color: selected ? primary : muted,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        _sectionCard(
          title: 'Rental rules',
          subtitle: 'The booking system keeps operational availability separate from minimum billing.',
          child: Column(
            children: [
              _ruleRow(
                Icons.timer_outlined,
                'Hourly',
                'Exact availability interval. Minimum billing is applied only to pricing.',
              ),
              _ruleRow(
                Icons.date_range_rounded,
                'Daily',
                'Selected calendar dates are blocked through 11:59:59 PM on the return date.',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _ruleRow(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: primary, size: 19),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.manrope(
                    color: heading,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.manrope(
                    color: body,
                    fontSize: 10,
                    height: 1.35,
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

  Widget _buildVehicleSelection() {
    final activeCars = _fleetCars.where(_isCarAssignedToTenant).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heroCard(
          icon: Icons.directions_car_rounded,
          title: 'Choose vehicle',
          subtitle: 'Select the vehicle first. The availability calendar will then be loaded specifically for that vehicle.',
        ),
        const SizedBox(height: 14),
        _summaryCard(
          title: _rentalTypeLabel,
          subtitle: '${activeCars.length} active vehicle${activeCars.length == 1 ? '' : 's'} in this tenant',
          icon: Icons.tune_rounded,
          trailing: '${activeCars.length}',
        ),
        const SizedBox(height: 14),
        if (activeCars.isEmpty)
          _emptyCard(
            'No active vehicles',
            'Add an active vehicle assigned to this tenant before creating a booking.',
          )
        else
          ...activeCars.map((car) => _vehicleSelectionCard(car)),
      ],
    );
  }

  Widget _vehicleSelectionCard(Car car) {
    final selected = _selectedCar?.id == car.id;
    return GestureDetector(
      onTap: () => _selectVehicle(car),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 11),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? softAccent : card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? primary : border,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x10000000),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            _carImage(car, 88, 70),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    car.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      color: heading,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
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
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: [
                      _tag(Icons.people_outline_rounded, '${car.seats} seats'),
                      _tag(Icons.local_gas_station_outlined, car.fuel),
                      if (car.pricingProfileId.trim().isNotEmpty)
                        _tag(Icons.payments_outlined, 'Pricing'),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.chevron_right_rounded,
              color: selected ? primary : muted,
            ),
          ],
        ),
      ),
    );
  }


  // ============================================================
  // PREMIUM MONTHLY AVAILABILITY CALENDAR
  // ============================================================

  bool _bookingIsVisibleForCalendar(AvailabilityBooking booking) {
    final status = booking.status.toString().toLowerCase();
    // Cancelled/rejected bookings do not block a rental day.
    return !status.contains('cancel') && !status.contains('reject');
  }

  bool _bookingOverlapsDay(AvailabilityBooking booking, DateTime day) {
    if (!_bookingIsVisibleForCalendar(booking)) return false;

    // The availability snapshot contains the tenant's bookings for the
    // requested month. The calendar, however, belongs to ONE selected car.
    // Never mark a day BOOKED because another vehicle has a booking.
    final selectedCarId = _selectedCar?.id;
    if (selectedCarId == null || booking.carId != selectedCarId) {
      return false;
    }

    final start = booking.pickupDateTime;
    final end = booking.returnDateTime;
    final dayStart = _dayOnly(day);
    final dayEnd = DateTime(
      day.year,
      day.month,
      day.day,
      23,
      59,
      59,
      999,
    );

    return start.isBefore(dayEnd) && end.isAfter(dayStart);
  }

  AvailabilityBooking? _bookingForDay(DateTime day) {
    final snapshot = _availabilitySnapshot;
    if (snapshot == null) return null;

    for (final booking in snapshot.bookings) {
      if (_bookingOverlapsDay(booking, day)) return booking;
    }
    return null;
  }

  bool _isDayBooked(DateTime day) => _bookingForDay(day) != null;

  bool _isDayUnavailable(DateTime day) {
    final normalized = _dayOnly(day);
    return _blockedFullDays.contains(normalized);
  }

  Color _calendarDayBackground(DateTime day, bool selected) {
    if (selected) return primary.withOpacity(.12);
    if (_isDayBooked(day)) return const Color(0xFFFFE8E8);
    if (_isDayUnavailable(day)) return const Color(0xFFFFF3E0);
    return const Color(0xFFEAFBF6);
  }

  Color _calendarDayBorder(DateTime day, bool selected) {
    if (selected) return primary;
    if (_isDayBooked(day)) return const Color(0xFFE35D6A);
    if (_isDayUnavailable(day)) return const Color(0xFFE7A23B);
    return const Color(0xFFB8E8D9);
  }

  Color _calendarDayTextColor(DateTime day, bool selected) {
    if (selected) return primary;
    if (_isDayBooked(day)) return const Color(0xFFB42318);
    if (_isDayUnavailable(day)) return const Color(0xFF9A6700);
    return const Color(0xFF08745F);
  }

  String _calendarDayLabel(DateTime day) {
    if (_isDayBooked(day)) return 'BOOKED';
    if (_isDayUnavailable(day)) return 'BLOCKED';
    return 'OPEN';
  }

  bool _calendarDayCanBeSelected(DateTime day) {
    final normalized = _dayOnly(day);
    final today = _dayOnly(DateTime.now());
    if (normalized.isBefore(today)) return false;
    if (_loadingCalendar || _availabilitySnapshot == null) return false;
    if (_isDayBooked(normalized) || _isDayUnavailable(normalized)) return false;
    return true;
  }

  bool _calendarRangeHasUnavailableDay(DateTime start, DateTime end) {
    var cursor = _dayOnly(start);
    final last = _dayOnly(end);
    while (!cursor.isAfter(last)) {
      if (!_calendarDayCanBeSelected(cursor)) return true;
      cursor = cursor.add(const Duration(days: 1));
    }
    return false;
  }

  void _handleCalendarDayTap(DateTime day) {
    if (!_calendarDayCanBeSelected(day)) return;

    final selected = _dayOnly(day);
    final currentStart = _calendarSelectionStart;

    // First tap = pickup.
    if (currentStart == null || _calendarSelectionEnd != null) {
      setState(() {
        _calendarSelectionStart = selected;
        _calendarSelectionEnd = null;
      });
      return;
    }

    // Second tap = return. If tapped before pickup, restart from this day.
    if (selected.isBefore(currentStart)) {
      setState(() {
        _calendarSelectionStart = selected;
        _calendarSelectionEnd = null;
      });
      return;
    }

    if (selected.isAtSameMomentAs(currentStart)) {
      _showError('Please tap a later date for the return date.');
      return;
    }

    if (_calendarRangeHasUnavailableDay(currentStart, selected)) {
      _showError('That range contains a booked or blocked day. Choose another return date.');
      return;
    }

    setState(() {
      _calendarSelectionEnd = selected;
      _pickupDate = currentStart;
      _returnDate = selected;
      _pricingResult = null;
    });
  }

  void _clearCalendarRangeSelection() {
    setState(() {
      _calendarSelectionStart = null;
      _calendarSelectionEnd = null;
    });
  }

  Future<void> _changeCalendarMonth(int delta) async {
    final today = _dayOnly(DateTime.now());
    final minMonth = DateTime(today.year, today.month, 1);
    final maxDate = today.add(const Duration(days: 730));
    final maxMonth = DateTime(maxDate.year, maxDate.month, 1);

    final next = DateTime(
      _calendarMonth.year,
      _calendarMonth.month + delta,
      1,
    );

    if (next.isBefore(minMonth) || next.isAfter(maxMonth)) return;

    // Invalidate the previous month's request BEFORE changing the month.
    // This prevents the old request from winning a race with the new one.
    _availabilityRequestId++;

    setState(() {
      _calendarMonth = next;
      _blockedFullDays.clear();
      _availabilitySnapshot = null;
      _loadingCalendar = true;
    });

    await _loadAvailabilityCalendar();
  }

  Widget _premiumMonthlyAvailabilityCalendar() {
    final month = _calendarMonth;
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

    // Monday = 0 ... Sunday = 6.
    final leadingDays = firstDay.weekday - DateTime.monday;
    final totalCells = ((leadingDays + daysInMonth + 6) ~/ 7) * 7;

    final today = _dayOnly(DateTime.now());
    final selectedStart = _calendarSelectionStart;
    final selectedEnd = _calendarSelectionEnd ?? _calendarSelectionStart;

    final monthTitle = MaterialLocalizations.of(context).formatMonthYear(month);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: softAccent,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: primary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      monthTitle,
                      style: GoogleFonts.manrope(
                        color: heading,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _loadingCalendar
                          ? 'Refreshing vehicle availability…'
                          : 'Monthly booking availability',
                      style: GoogleFonts.manrope(
                        color: muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _calendarNavButton(
                Icons.chevron_left_rounded,
                () => _changeCalendarMonth(-1),
              ),
              const SizedBox(width: 6),
              _calendarNavButton(
                Icons.chevron_right_rounded,
                () => _changeCalendarMonth(1),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Legend.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _calendarLegend(
                  color: const Color(0xFFEAFBF6),
                  borderColor: const Color(0xFFB8E8D9),
                  label: 'Available',
                ),
                const SizedBox(width: 10),
                _calendarLegend(
                  color: const Color(0xFFFFE8E8),
                  borderColor: const Color(0xFFE35D6A),
                  label: 'Booked',
                ),
                const SizedBox(width: 10),
                _calendarLegend(
                  color: const Color(0xFFFFF3E0),
                  borderColor: const Color(0xFFE7A23B),
                  label: 'Blocked',
                ),
                const SizedBox(width: 10),
                _calendarLegend(
                  color: primary.withOpacity(.12),
                  borderColor: primary,
                  label: 'Selected',
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),

          Row(
            children: const [
              _CalendarWeekLabel('MON'),
              _CalendarWeekLabel('TUE'),
              _CalendarWeekLabel('WED'),
              _CalendarWeekLabel('THU'),
              _CalendarWeekLabel('FRI'),
              _CalendarWeekLabel('SAT'),
              _CalendarWeekLabel('SUN'),
            ],
          ),
          const SizedBox(height: 7),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: totalCells,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 5,
              mainAxisSpacing: 5,
              childAspectRatio: .94,
            ),
            itemBuilder: (context, index) {
              final dayNumber = index - leadingDays + 1;

              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const SizedBox.shrink();
              }

              final day = DateTime(month.year, month.month, dayNumber);
              final normalized = _dayOnly(day);
              final inSelectedRange = selectedStart != null &&
                  selectedEnd != null &&
                  !normalized.isBefore(selectedStart) &&
                  !normalized.isAfter(selectedEnd);
              final isToday = normalized == today;
              final booking = _bookingForDay(day);
              final booked = booking != null;
              final blocked = _isDayUnavailable(day);
              final isPast = normalized.isBefore(today);

              return InkWell(
                borderRadius: BorderRadius.circular(13),
                onTap: _loadingCalendar || _availabilitySnapshot == null ||
                        isPast || booked || blocked
                    ? null
                    : () => _handleCalendarDayTap(day),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
                  decoration: BoxDecoration(
                    color: _calendarDayBackground(day, inSelectedRange),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: _calendarDayBorder(day, inSelectedRange),
                      width: isToday || inSelectedRange ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$dayNumber',
                        style: GoogleFonts.manrope(
                          color: _calendarDayTextColor(day, inSelectedRange),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: booked
                              ? const Color(0xFFE35D6A)
                              : blocked
                                  ? const Color(0xFFE7A23B)
                                  : const Color(0xFF159A7A),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          if (_selectedCar != null) ...[
            const SizedBox(height: 13),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: border),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.directions_car_rounded,
                    color: primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_selectedCar!.name} • ${_rentalTypeLabel}',
                      style: GoogleFonts.manrope(
                        color: heading,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    '${_formatDate(_pickupDate)} → ${_formatDate(_returnDate)}',
                    style: GoogleFonts.manrope(
                      color: primary,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _calendarNavButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: Icon(icon, color: heading, size: 21),
        ),
      ),
    );
  }

  Widget _calendarLegend({
    required Color color,
    required Color borderColor,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: borderColor),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.manrope(
            color: body,
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildDates() {
    final durationText = _isHourly
        ? '${_formatTime(_pickupTime)} → ${_formatTime(_returnTime)}'
        : '${_formatDate(_pickupDate)} → ${_formatDate(_returnDate)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heroCard(
          icon: Icons.calendar_month_rounded,
          title: 'Vehicle-specific availability calendar',
          subtitle: _isHourly
              ? 'Now that the vehicle and rental type are selected, choose the exact pickup and return time. The vehicle is checked again for the exact interval.'
              : 'Daily mode supports multiple calendar days and blocks every selected date from 12:00 AM to 11:59 PM.',
        ),
        const SizedBox(height: 14),
        _sectionCard(
          title: '$_rentalTypeLabel rental • ${_selectedCar?.name ?? 'Vehicle'}',
          subtitle: _loadingCalendar ? 'Refreshing vehicle availability…' : 'Selected period: $durationText',
          child: Column(
            children: [
              _premiumMonthlyAvailabilityCalendar(),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                decoration: BoxDecoration(
                  color: softAccent,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: primary.withOpacity(.14)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.touch_app_rounded, color: primary, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _calendarSelectionStart == null
                            ? 'Tap an available day for pickup, then tap a later day for return. Both dates are selected on this calendar.'
                            : _calendarSelectionEnd == null
                                ? 'Pickup selected. Tap a later available day for return.'
                                : 'Pickup and return selected directly on this calendar.',
                        style: GoogleFonts.manrope(
                          color: heading,
                          fontSize: 10.5,
                          height: 1.35,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _dateTile('Pickup date', _formatDate(_pickupDate), Icons.login_rounded, _selectPickupDateOnly)),
                const SizedBox(width: 10),
                Expanded(child: _dateTile('Return date', _formatDate(_returnDate), Icons.logout_rounded, _selectReturnDateOnly)),
              ]),
              if (_isHourly) ...[
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _dateTile('Pickup time', _formatTime(_pickupTime), Icons.schedule_rounded, _selectPickupTime)),
                  const SizedBox(width: 10),
                  Expanded(child: _dateTile('Return time', _formatTime(_returnTime), Icons.access_time_rounded, _selectReturnTime)),
                ]),
              ] else ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(color: softAccent, borderRadius: BorderRadius.circular(16)),
                  child: Row(children: [
                    const Icon(Icons.schedule_rounded, color: primary, size: 20),
                    const SizedBox(width: 9),
                    Expanded(child: Text('Availability: ${_formatDate(_pickupDate)} 12:00 AM → ${_formatDate(_returnDate)} 11:59 PM', style: GoogleFonts.manrope(color: heading, fontSize: 11.5, fontWeight: FontWeight.w800))),
                  ]),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _primaryButton('Confirm Vehicle Availability', Icons.verified_rounded, _confirmVehicleCalendarAvailability),
      ],
    );
  }

  Widget _buildVehicles() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _summaryCard(
          title: 'Vehicles available',
          subtitle: '${_formatDateTime(_pickupDateTime)} → ${_formatDateTime(_returnDateTime)}',
          icon: Icons.directions_car_rounded,
          trailing: '${_availableCars.length}',
        ),
        const SizedBox(height: 14),
        if (_availableCars.isEmpty)
          _emptyCard('No vehicles available', 'Try another rental period.'),
        ..._availableCars.map(_vehicleCard),
      ],
    );
  }

  Widget _vehicleCard(Car car) {
    return GestureDetector(
      onTap: () => _selectVehicle(car),
      child: Container(
        margin: const EdgeInsets.only(bottom: 11),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x10000000),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            _carImage(car, 88, 70),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(car.name, style: GoogleFonts.manrope(color: heading, fontSize: 15, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(
                    car.registrationNumber.isEmpty ? '${car.type} • ${car.transmission}' : car.registrationNumber,
                    style: GoogleFonts.manrope(color: body, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      _tag(Icons.people_outline_rounded, '${car.seats}'),
                      const SizedBox(width: 5),
                      _tag(Icons.local_gas_station_outlined, car.fuel),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: muted),
          ],
        ),
      ),
    );
  }

  Widget _buildBranch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _summaryCard(
          title: _selectedCar?.name ?? 'Vehicle',
          subtitle: 'Vehicle verified for the complete rental period',
          icon: Icons.verified_rounded,
          trailing: '✓',
        ),
        const SizedBox(height: 14),
        _sectionCard(
          title: 'Pickup branch',
          subtitle: 'Only active branches assigned to this vehicle are shown.',
          child: Column(
            children: _branches.map((branch) {
              final id = branch['id']?.toString() ?? '';
              final selected = id == _selectedBranchId;
              return GestureDetector(
                onTap: () => setState(() => _selectedBranchId = id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(bottom: 9),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: selected ? softAccent : background,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: selected ? primary : border, width: selected ? 1.4 : 1),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.storefront_outlined, color: selected ? primary : body),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(branch['name']?.toString() ?? 'Branch', style: GoogleFonts.manrope(color: heading, fontWeight: FontWeight.w800)),
                            if ((branch['city']?.toString() ?? '').isNotEmpty)
                              Text(branch['city'].toString(), style: GoogleFonts.manrope(color: body, fontSize: 11)),
                          ],
                        ),
                      ),
                      Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: selected ? primary : muted),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        _primaryButton('Continue to Customer', Icons.person_search_rounded, _continueFromVehicle),
      ],
    );
  }

  Widget _buildCustomer() {
    final selected = _selectedCustomer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _summaryCard(
          title: 'Customer',
          subtitle: selected == null ? 'Choose an existing customer or create one.' : '${selected.fullName} • ${selected.phone}',
          icon: Icons.person_rounded,
          trailing: selected == null ? '+' : '✓',
        ),
        const SizedBox(height: 14),
        _sectionCard(
          title: selected == null ? 'Select customer' : 'Selected customer',
          subtitle: 'The booking will use the customer Firebase UID as customerId.',
          child: Column(
            children: [
              if (selected != null)
                _selectedCustomerCard(selected)
              else
                _primaryButton('Select Existing / Create Customer', Icons.person_add_alt_1_rounded, _selectCustomer),
              if (selected != null) ...[
                const SizedBox(height: 10),
                _secondaryButton('Change Customer', Icons.swap_horiz_rounded, _selectCustomer),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (selected != null)
          _primaryButton('Continue to KM Package', Icons.arrow_forward_rounded, _loadPricing),
      ],
    );
  }

  Widget _selectedCustomerCard(Customer customer) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: softAccent, borderRadius: BorderRadius.circular(17), border: Border.all(color: primary.withOpacity(.18))),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: primary, foregroundColor: Colors.white, child: Text(customer.fullName.isEmpty ? '?' : customer.fullName[0].toUpperCase())),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(customer.fullName.isEmpty ? 'Customer' : customer.fullName, style: GoogleFonts.manrope(color: heading, fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(customer.phone, style: GoogleFonts.manrope(color: body, fontSize: 11, fontWeight: FontWeight.w600)),
              if (customer.email.isNotEmpty) Text(customer.email, style: GoogleFonts.manrope(color: muted, fontSize: 10)),
            ]),
          ),
          const Icon(Icons.verified_user_rounded, color: primary, size: 20),
        ],
      ),
    );
  }

  List<KmPricingPackage> get _packagesForRentalType {
    switch (_rentalType) {
      case AdminRentalType.hourly:
        return _packages.where((p) => p.unlimitedKm || p.safeHourlyRate > 0).toList();
      case AdminRentalType.daily:
        return _packages.where((p) => p.unlimitedKm || p.safeDailyRate > 0).toList();
      case null:
        return _packages;
    }
  }

  double _selectedPackageRate(KmPricingPackage package) {
    switch (_rentalType) {
      case AdminRentalType.hourly:
        return package.safeHourlyRate;
      case AdminRentalType.daily:
        return package.safeDailyRate;
      case null:
        return _packageDisplayRate(package);
    }
  }

  Widget _buildPackage() {
    print('🔥 BUILD KM PACKAGE SCREEN | packages=${_packages.length} | selected=${_selectedPackage?.id}');
    developer.log(
      'BUILD KM PACKAGE SCREEN: packages=${_packages.length}, selected=${_selectedPackage?.id}',
      name: 'AdminNewBooking',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select your KM package',
          style: GoogleFonts.manrope(
            color: heading,
            fontSize: 23,
            height: 1.08,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose the distance package that best fits your trip.',
          style: GoogleFonts.manrope(
            color: body,
            fontSize: 13,
            height: 1.45,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 22),
        if (_packagesForRentalType.isEmpty)
          _emptyCard(
            'No $_rentalTypeLabel KM packages',
            'This vehicle does not currently have a package for the selected rental type.',
          )
        else
          ..._packagesForRentalType.map(_packageCard),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _packageCard(KmPricingPackage package) {
    final selected = _selectedPackage?.id == package.id;
    final rate = _selectedPackageRate(package);
    final kmText = package.unlimitedKm
        ? 'Unlimited KM'
        : '${package.includedKm ?? 0} KM included';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _selectPackage(package),
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 9),
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFF4FFFD) : card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? primary : border,
              width: selected ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(selected ? .045 : .025),
                blurRadius: selected ? 12 : 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: selected ? primary : softAccent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.speed_rounded,
                  color: selected ? Colors.white : primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      package.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        color: heading,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      kmText,
                      style: GoogleFonts.manrope(
                        color: primary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          '${_rentalTypeLabel} ',
                          style: GoogleFonts.manrope(
                            color: muted,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          _money(rate),
                          style: GoogleFonts.manrope(
                            color: heading,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          width: 1,
                          height: 14,
                          color: border,
                        ),
                        Text(
                          package.unlimitedKm
                              ? 'Unlimited'
                              : '${_money(package.extraKmRate)} / KM',
                          style: GoogleFonts.manrope(
                            color: body,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? primary : Colors.transparent,
                  border: Border.all(
                    color: selected ? primary : const Color(0xFFD8E1DE),
                    width: selected ? 0 : 1.5,
                  ),
                ),
                child: selected
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 16,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _packageRateColumn(String label, double value, bool first) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.manrope(
              color: muted,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _money(value),
            style: GoogleFonts.manrope(
              color: heading,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _packageRateDivider() {
    return Container(
      width: 1,
      height: 38,
      color: const Color(0xFFE4EAE8),
    );
  }

  Widget _buildPricing() {
    final result = _pricingResult;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _summaryCard(
          title: 'Pricing & Payment',
          subtitle: '${_selectedCar?.name ?? ''} • ${_selectedCustomer?.fullName ?? ''}',
          icon: Icons.receipt_long_rounded,
          trailing: result == null ? '—' : _money(_effectiveTripTotal),
        ),
        const SizedBox(height: 14),
        if (result == null)
          _emptyCard('Pricing unavailable', 'Please return and select a valid package.')
        else ...[
          _sectionCard(
            title: 'Admin pricing override',
            subtitle: 'Edit this booking only. Daily rentals do not add extra-time charges from the calendar boundary.',
            child: Column(
              children: [
                _editablePriceField(label: 'Rental', value: _effectiveRentalPrice, field: 'rental'),
                _editablePriceField(label: 'Extra KM', value: _effectiveExtraKmCharge, field: 'extraKm'),
                _editablePriceField(label: 'Extra Time', value: _effectiveExtraTimeCharge, field: 'extraTime'),
                _editablePriceField(label: 'Add-ons', value: _effectiveAddOnTotal, field: 'addons'),
                _editablePriceField(label: 'Protection', value: _effectiveProtectionTotal, field: 'protection'),
                _editablePriceField(label: 'Discount', value: _effectiveDiscountAmount, field: 'discount'),
                _editablePriceField(label: 'Tax', value: _effectiveTaxAmount, field: 'tax'),
                const Divider(height: 22, color: border),
                Row(
                  children: [
                    Expanded(
                      child: Text('Trip Total', style: GoogleFonts.manrope(
                        color: heading, fontSize: 14, fontWeight: FontWeight.w900,
                      )),
                    ),
                    SizedBox(
                      width: 145,
                      child: TextFormField(
                        initialValue: _effectiveTripTotal.toStringAsFixed(2),
                        textAlign: TextAlign.right,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: _inputDecoration('₹ Total').copyWith(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                        ),
                        onChanged: _setAdminTotal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _adminTotalManuallyEdited
                        ? 'Manual total override is active.'
                        : 'Total automatically follows the editable line items.',
                    style: GoogleFonts.manrope(color: muted, fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _sectionCard(
            title: 'Security deposit',
            subtitle: 'Refundable security is tracked separately from the rental total. Asset security never increases the trip total.',
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: _depositMethod,
                  decoration: _inputDecoration('Deposit type'),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                    DropdownMenuItem(value: 'upi', child: Text('UPI / Online')),
                    DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer')),
                    DropdownMenuItem(value: 'vehicle_asset', child: Text('Vehicle / Bike as Security')),
                    DropdownMenuItem(value: 'other_asset', child: Text('Other Asset')),
                    DropdownMenuItem(value: 'none', child: Text('No Deposit')),
                  ],
                  onChanged: (value) {
                    final method = value ?? 'cash';
                    setState(() {
                      _depositMethod = method;
                      if (method == 'none' || method == 'vehicle_asset' || method == 'other_asset') {
                        _depositAmount = 0;
                      } else if (_depositAmount <= 0) {
                        _depositAmount = result.securityDeposit;
                      }
                    });
                  },
                ),
                if (_isMonetaryDeposit) ...[
                  const SizedBox(height: 10),
                  TextFormField(
                    initialValue: _depositAmount.toStringAsFixed(2),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _inputDecoration('Deposit amount (separate from trip total)'),
                    onChanged: (value) => setState(() => _depositAmount = double.tryParse(value) ?? 0),
                  ),
                ],
                if (_depositMethod == 'vehicle_asset' || _depositMethod == 'other_asset') ...[
                  const SizedBox(height: 10),
                  TextFormField(
                    maxLines: 3,
                    decoration: _inputDecoration(
                      _depositMethod == 'vehicle_asset' ? 'Vehicle / bike security details *' : 'Asset security details *',
                    ),
                    onChanged: (value) => _depositAssetDetails = value,
                  ),
                  const SizedBox(height: 7),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Asset security is recorded for reference only and adds ₹0 to the trip total.',
                      style: GoogleFonts.manrope(color: primary, fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          _sectionCard(
            title: 'Payment collection',
            subtitle: 'Choose how much the admin is collecting now. Monetary deposit is added separately; asset deposit is ₹0.',
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: _paymentMethod,
                  decoration: _inputDecoration('Payment method'),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                    DropdownMenuItem(value: 'upi', child: Text('UPI')),
                    DropdownMenuItem(value: 'card', child: Text('Card')),
                    DropdownMenuItem(value: 'online', child: Text('Online')),
                    DropdownMenuItem(value: 'pending', child: Text('Pay later / Pending')),
                  ],
                  onChanged: (value) => setState(() => _paymentMethod = value ?? 'cash'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  initialValue: _paidAmount == 0 ? '' : _paidAmount.toStringAsFixed(2),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: _inputDecoration('Amount collected now'),
                  onChanged: (value) => _paidAmount = double.tryParse(value) ?? 0,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  initialValue: _bookingNote,
                  maxLines: 3,
                  decoration: _inputDecoration('Booking note (optional)'),
                  onChanged: (value) => _bookingNote = value,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: softAccent,
              borderRadius: BorderRadius.circular(19),
              border: Border.all(color: primary.withOpacity(.16)),
            ),
            child: Column(
              children: [
                _priceLine('Trip Total', _effectiveTripTotal, strong: true),
                _priceLine('Security Deposit', _effectiveDepositAmount),
                const Divider(height: 18, color: border),
                _priceLine('Amount Payable Now', _effectiveAmountPayable, strong: true),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _primaryButton('Review Booking', Icons.preview_rounded, _continueToReview),
        ],
      ],
    );
  }

  Widget _buildReview() {
    final result = _pricingResult!;
    final customer = _selectedCustomer!;
    final car = _selectedCar!;
    final branch = _selectedBranch!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heroCard(icon: Icons.fact_check_rounded, title: 'Final booking review', subtitle: 'Everything is checked once more before the booking is written to Firebase.'),
        const SizedBox(height: 14),
        _reviewCard('Rental type & period', [
          _rentalTypeLabel,
          '${_formatDateTime(_pickupDateTime)} → ${_formatDateTime(_returnDateTime)}',
          _durationText(result),
          if (!_isHourly) 'Availability block ends at 11:59 PM on ${_formatDate(_returnDate)}',
        ]),
        _reviewCard('Vehicle', [car.name, car.registrationNumber.isEmpty ? '${car.type} • ${car.transmission}' : car.registrationNumber]),
        _reviewCard('Pickup branch', [branch['name']?.toString() ?? 'Branch', branch['address']?.toString() ?? '']),
        _reviewCard('Customer', [customer.fullName, customer.phone, customer.email]),
        _reviewCard('KM package', [result.selectedKmPackageName ?? 'Default pricing', result.unlimitedKm ? 'Unlimited KM' : '${result.includedKm ?? 0} KM included']),
        _reviewCard('Payment', [_paymentMethod.toUpperCase(), 'Collected: ${_money(_paidAmount)}', 'Trip Total: ${_money(_effectiveTripTotal)}', 'Security Deposit: ${_money(_effectiveDepositAmount)}', 'Amount Payable: ${_money(_effectiveAmountPayable)}']),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: softAccent, borderRadius: BorderRadius.circular(20), border: Border.all(color: primary.withOpacity(.18))),
          child: Row(children: [
            const Icon(Icons.payments_rounded, color: primary, size: 25),
            const SizedBox(width: 11),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Amount payable', style: GoogleFonts.manrope(color: body, fontSize: 11, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(_money(_effectiveAmountPayable), style: GoogleFonts.manrope(color: heading, fontSize: 24, fontWeight: FontWeight.w900)),
            ])),
          ]),
        ),
        const SizedBox(height: 18),
        _primaryButton('Confirm & Create Booking', Icons.check_circle_rounded, _createBooking),
      ],
    );
  }

  Widget _reviewCard(String title, List<String> lines) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(18), border: Border.all(color: border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.manrope(color: muted, fontSize: 10, fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        ...lines.where((line) => line.trim().isNotEmpty).map((line) => Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text(line, style: GoogleFonts.manrope(color: heading, fontSize: 12, fontWeight: FontWeight.w700)),
        )),
      ]),
    );
  }

  Widget _priceLine(String label, double amount, {bool strong = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(child: Text(label, style: GoogleFonts.manrope(color: strong ? heading : body, fontSize: strong ? 14 : 12, fontWeight: strong ? FontWeight.w900 : FontWeight.w600))),
        Text(_money(amount), style: GoogleFonts.manrope(color: strong ? primary : heading, fontSize: strong ? 16 : 12, fontWeight: FontWeight.w900)),
      ]),
    );
  }

  String _durationText(PricingResult result) {
    if (result.durationMinutes < 60) return '${result.durationMinutes} minutes';
    if (result.durationHours < 24) {
      final h = result.durationHours.ceil();
      return '$h ${h == 1 ? 'hour' : 'hours'}';
    }
    return '${result.rentalDays} ${result.rentalDays == 1 ? 'day' : 'days'}';
  }

  Widget _heroCard({required IconData icon, required String title, required String subtitle}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [primary, primary.withOpacity(.88)]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: primary.withOpacity(.14), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Row(children: [
        Container(width: 50, height: 50, decoration: BoxDecoration(color: Colors.white.withOpacity(.15), borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: Colors.white, size: 25)),
        const SizedBox(width: 13),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: GoogleFonts.manrope(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(subtitle, style: GoogleFonts.manrope(color: Colors.white.withOpacity(.78), fontSize: 11, fontWeight: FontWeight.w600, height: 1.4)),
        ])),
      ]),
    );
  }

  Widget _summaryCard({required String title, required String subtitle, required IconData icon, required String trailing}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(20), border: Border.all(color: border)),
      child: Row(children: [
        Container(width: 43, height: 43, decoration: BoxDecoration(color: softAccent, borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: primary, size: 22)),
        const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.manrope(color: heading, fontSize: 14, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.manrope(color: body, fontSize: 10.5, fontWeight: FontWeight.w600)),
        ])),
        Text(trailing, style: GoogleFonts.manrope(color: primary, fontSize: 15, fontWeight: FontWeight.w900)),
      ]),
    );
  }

  Widget _sectionCard({required String title, required String subtitle, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(21), border: Border.all(color: border), boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 16, offset: Offset(0, 6))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.manrope(color: heading, fontSize: 15, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(subtitle, style: GoogleFonts.manrope(color: muted, fontSize: 10.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 14),
        child,
      ]),
    );
  }

  Widget _dateTile(String label, String value, IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x05000000),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: softAccent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: primary, size: 16),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.manrope(
                        color: muted,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        color: heading,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.edit_calendar_rounded, color: muted, size: 14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _primaryButton(String text, IconData icon, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(text, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w900)),
        style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      ),
    );
  }

  Widget _secondaryButton(String text, IconData icon, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 19),
        label: Text(text, style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w800)),
        style: OutlinedButton.styleFrom(foregroundColor: primary, side: const BorderSide(color: border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
      ),
    );
  }

  Widget _emptyCard(String title, String subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(20), border: Border.all(color: border)),
      child: Column(children: [
        const Icon(Icons.info_outline_rounded, color: muted, size: 36),
        const SizedBox(height: 9),
        Text(title, style: GoogleFonts.manrope(color: heading, fontSize: 14, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(subtitle, textAlign: TextAlign.center, style: GoogleFonts.manrope(color: body, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _carImage(Car car, double width, double height) {
    final image = car.image.trim();
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: softAccent, borderRadius: BorderRadius.circular(15)),
      clipBehavior: Clip.antiAlias,
      child: image.isEmpty
          ? const Icon(Icons.directions_car_rounded, color: primary, size: 31)
          : Image.network(image, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.directions_car_rounded, color: primary, size: 31)),
    );
  }

  Widget _tag(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(7)),
      child: Row(children: [Icon(icon, color: muted, size: 12), const SizedBox(width: 4), Text(text, style: GoogleFonts.manrope(color: body, fontSize: 9.5, fontWeight: FontWeight.w700))]),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.manrope(color: muted, fontSize: 11, fontWeight: FontWeight.w600),
      filled: true,
      fillColor: background,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: primary, width: 1.3)),
    );
  }

  String _money(double value) {
    if (value == value.roundToDouble()) return '₹${value.toInt()}';
    return '₹${value.toStringAsFixed(2)}';
  }

  String _formatDate(DateTime date) => '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${time.period == DayPeriod.am ? 'AM' : 'PM'}';
  }

  String _formatDateTime(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} • $hour:$minute $period';
  }
}

class _CalendarWeekLabel extends StatelessWidget {
  static const Color muted = Color(0xFF94A09D);

  final String label;

  const _CalendarWeekLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: GoogleFonts.manrope(
            color: muted,
            fontSize: 7.5,
            fontWeight: FontWeight.w900,
            letterSpacing: .6,
          ),
        ),
      ),
    );
  }
}

class _CustomerPickerSheet extends StatefulWidget {
  final List<Customer> customers;
  final Customer? selectedCustomer;
  final String search;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<Customer> onSelected;
  final VoidCallback onCreateNew;

  const _CustomerPickerSheet({
    required this.customers,
    required this.selectedCustomer,
    required this.search,
    required this.onSearchChanged,
    required this.onSelected,
    required this.onCreateNew,
  });

  @override
  State<_CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends State<_CustomerPickerSheet> {
  static const Color background = Color(0xFFF8FAF9);
  static const Color card = Color(0xFFFFFFFF);
  static const Color primary = Color(0xFF0F766E);
  static const Color heading = Color(0xFF17201F);
  static const Color body = Color(0xFF66706E);
  static const Color muted = Color(0xFF94A09D);
  static const Color border = Color(0xFFE5EBE9);
  late TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: widget.search);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Customer> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return widget.customers;
    return widget.customers.where((customer) {
      return customer.fullName.toLowerCase().contains(q) ||
          customer.phone.toLowerCase().contains(q) ||
          customer.email.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * .84,
      decoration: const BoxDecoration(color: card, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: Column(children: [
        const SizedBox(height: 10),
        Container(width: 42, height: 4, decoration: BoxDecoration(color: border, borderRadius: BorderRadius.circular(10))),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Select customer', style: GoogleFonts.manrope(color: heading, fontSize: 19, fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text('Search an existing customer or create a new account.', style: GoogleFonts.manrope(color: body, fontSize: 11, fontWeight: FontWeight.w600)),
            ])),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: body)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: TextField(
            controller: _search,
            onChanged: widget.onSearchChanged,
            style: GoogleFonts.manrope(color: heading, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              hintText: 'Search name, phone or email',
              hintStyle: GoogleFonts.manrope(color: muted, fontSize: 12),
              prefixIcon: const Icon(Icons.search_rounded, color: primary),
              filled: true,
              fillColor: background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: border)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: widget.onCreateNew,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: Text('Create New Customer', style: GoogleFonts.manrope(fontWeight: FontWeight.w900)),
              style: OutlinedButton.styleFrom(foregroundColor: primary, side: const BorderSide(color: primary), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            ),
          ),
        ),
        const Divider(height: 1, color: border),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
            itemCount: _filtered.length,
            itemBuilder: (_, index) {
              final customer = _filtered[index];
              return ListTile(
                onTap: () => widget.onSelected(customer),
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                leading: CircleAvatar(backgroundColor: const Color(0xFFE6FFFB), foregroundColor: primary, child: Text(customer.fullName.isEmpty ? '?' : customer.fullName[0].toUpperCase())),
                title: Text(customer.fullName.isEmpty ? 'Customer' : customer.fullName, style: GoogleFonts.manrope(color: heading, fontWeight: FontWeight.w800)),
                subtitle: Text('${customer.phone}${customer.email.isEmpty ? '' : ' • ${customer.email}'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.manrope(color: body, fontSize: 10.5)),
                trailing: const Icon(Icons.chevron_right_rounded, color: muted),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _NewCustomerData {
  final String name;
  final String phone;
  final String email;
  const _NewCustomerData({required this.name, required this.phone, required this.email});
}

class _NewCustomerDetailsDialog extends StatefulWidget {
  const _NewCustomerDetailsDialog();
  @override
  State<_NewCustomerDetailsDialog> createState() => _NewCustomerDetailsDialogState();
}

class _NewCustomerDetailsDialogState extends State<_NewCustomerDetailsDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController(text: '+91 ');
  final _email = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFFFFFFFF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text('Create customer', style: GoogleFonts.manrope(fontWeight: FontWeight.w900, color: const Color(0xFF17201F))),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('The customer phone will be verified by OTP so the Firebase UID can be created correctly.', style: GoogleFonts.manrope(color: const Color(0xFF66706E), fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          TextFormField(controller: _name, decoration: _dec('Full name'), validator: (v) => v == null || v.trim().isEmpty ? 'Enter name' : null),
          const SizedBox(height: 10),
          TextFormField(controller: _phone, keyboardType: TextInputType.phone, decoration: _dec('Phone (+91XXXXXXXXXX)'), validator: (v) => v == null || v.replaceAll(RegExp(r'\\D'), '').length < 10 ? 'Enter valid phone' : null),
          const SizedBox(height: 10),
          TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: _dec('Email (optional)')),
        ])),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            var phone = _phone.text.trim().replaceAll(' ', '');
            if (RegExp(r'^\\d{10}$').hasMatch(phone)) phone = '+91$phone';
            Navigator.pop(context, _NewCustomerData(name: _name.text.trim(), phone: phone, email: _email.text.trim()));
          },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F766E), foregroundColor: Colors.white),
          child: const Text('Continue'),
        ),
      ],
    );
  }

  InputDecoration _dec(String label) => InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)));
}

class _OtpDialog extends StatefulWidget {
  final String phone;
  final TextEditingController controller;
  final Future<void> Function(void Function(String), void Function(String)) sendOtp;
  final Future<bool> Function() verifyOtp;

  const _OtpDialog({required this.phone, required this.controller, required this.sendOtp, required this.verifyOtp});

  @override
  State<_OtpDialog> createState() => _OtpDialogState();
}

class _OtpDialogState extends State<_OtpDialog> {
  bool _sending = false;
  bool _verifying = false;
  bool _sent = false;
  String? _error;

  Future<void> _send() async {
    if (_sending) return;
    setState(() { _sending = true; _error = null; });
    try {
      await widget.sendOtp((id) {
        if (!mounted) return;
        setState(() { _sent = true; _sending = false; });
      }, (message) {
        if (!mounted) return;
        setState(() { _error = message; _sending = false; });
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _sending = false; });
    }
  }

  Future<void> _verify() async {
    if (_verifying) return;
    setState(() { _verifying = true; _error = null; });
    final ok = await widget.verifyOtp();
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() { _verifying = false; _error = 'Invalid OTP. Please try again.'; });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _send());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFFFFFFFF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text('Verify customer phone', style: GoogleFonts.manrope(color: const Color(0xFF17201F), fontWeight: FontWeight.w900)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('OTP sent to ${widget.phone}', style: GoogleFonts.manrope(color: const Color(0xFF66706E), fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 15),
        TextField(
          controller: widget.controller,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: InputDecoration(labelText: '6-digit OTP', counterText: '', border: OutlineInputBorder(borderRadius: BorderRadius.circular(13))),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, textAlign: TextAlign.center, style: GoogleFonts.manrope(color: Colors.red.shade700, fontSize: 10, fontWeight: FontWeight.w700)),
        ],
        if (_sending || !_sent) ...[
          const SizedBox(height: 10),
          const LinearProgressIndicator(color: Color(0xFF0F766E)),
        ],
      ]),
      actions: [
        TextButton(onPressed: _sending ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
        ElevatedButton(onPressed: !_sent || _verifying ? null : _verify, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F766E), foregroundColor: Colors.white), child: Text(_verifying ? 'Verifying...' : 'Verify')),
      ],
    );
  }
}

class _BookingSuccessDialog extends StatelessWidget {
  final Booking booking;
  final Customer customer;
  final Car car;
  const _BookingSuccessDialog({required this.booking, required this.customer, required this.car});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFFFFFFFF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const CircleAvatar(radius: 32, backgroundColor: Color(0xFFE6FFFB), child: Icon(Icons.check_rounded, color: Color(0xFF0F766E), size: 35)),
        const SizedBox(height: 14),
        Text('Booking created', style: GoogleFonts.manrope(color: const Color(0xFF17201F), fontSize: 19, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text('Booking ID: ${booking.bookingId}', textAlign: TextAlign.center, style: GoogleFonts.manrope(color: const Color(0xFF66706E), fontSize: 11, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('${customer.fullName} • ${car.name}', textAlign: TextAlign.center, style: GoogleFonts.manrope(color: const Color(0xFF66706E), fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
      actions: [Center(child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F766E), foregroundColor: Colors.white), child: const Text('Done')))],
    );
  }
}
