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

  DateTime _pickupDate = DateTime.now();
  DateTime _returnDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _pickupTime = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _returnTime = const TimeOfDay(hour: 10, minute: 0);

  List<Car> _availableCars = [];
  Car? _selectedCar;
  AdminAvailabilitySnapshot? _availabilitySnapshot;

  List<Map<String, dynamic>> _branches = [];
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

  int _step = 1;
  bool _loading = false;
  bool _loadingCustomers = false;
  bool _creatingBooking = false;
  String? _error;

  DateTime get _pickupDateTime => DateTime(
        _pickupDate.year,
        _pickupDate.month,
        _pickupDate.day,
        _pickupTime.hour,
        _pickupTime.minute,
      );

  DateTime get _returnDateTime => DateTime(
        _returnDate.year,
        _returnDate.month,
        _returnDate.day,
        _returnTime.hour,
        _returnTime.minute,
      );

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
      setState(() {
        _branches = snapshot.docs.map((doc) {
          final data = doc.data();
          return <String, dynamic>{
            'id': doc.id,
            'name': data['name']?.toString() ?? 'Branch',
            'city': data['city']?.toString() ?? '',
            'address': data['address']?.toString() ?? '',
            'phone': data['phone']?.toString() ?? '',
          };
        }).toList();
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

  Future<void> _selectPickupDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _pickupDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      builder: _pickerTheme,
    );
    if (selected == null) return;
    setState(() {
      _pickupDate = selected;
      if (!_returnDate.isAfter(_pickupDate)) {
        _returnDate = _pickupDate.add(const Duration(days: 1));
      }
      _resetFromAvailability();
    });
  }

  Future<void> _selectReturnDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _returnDate.isAfter(_pickupDate)
          ? _returnDate
          : _pickupDate.add(const Duration(days: 1)),
      firstDate: _pickupDate,
      lastDate: DateTime.now().add(const Duration(days: 730)),
      builder: _pickerTheme,
    );
    if (selected == null) return;
    setState(() {
      _returnDate = selected;
      _resetFromAvailability();
    });
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
    final selected = await showTimePicker(
      context: context,
      initialTime: _pickupTime,
      builder: _pickerTheme,
    );
    if (selected == null) return;
    setState(() {
      _pickupTime = selected;
      _resetFromAvailability();
    });
  }

  Future<void> _selectReturnTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _returnTime,
      builder: _pickerTheme,
    );
    if (selected == null) return;
    setState(() {
      _returnTime = selected;
      _resetFromAvailability();
    });
  }

  void _resetFromAvailability() {
    _availableCars = [];
    _availabilitySnapshot = null;
    _selectedCar = null;
    _selectedBranchId = null;
    _pricingProfile = null;
    _packages = [];
    _selectedPackage = null;
    _pricingResult = null;
    _step = 1;
  }

  Future<void> _searchAvailability() async {
    print('🔥 SEARCH AVAILABILITY CALLED | tenant=$_tenantId | pickup=$_pickupDateTime | return=$_returnDateTime');
    FocusScope.of(context).unfocus();

    final pickup = _pickupDateTime;
    final returnTime = _returnDateTime;

    if (!pickup.isBefore(returnTime)) {
      _showError('Return date and time must be after pickup date and time.');
      return;
    }

    if (pickup.isBefore(DateTime.now())) {
      _showError('Pickup time cannot be in the past.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _availableCars = [];
      _selectedCar = null;
    });

    try {
      // IMPORTANT: availability search starts with dates, not branch.
      // We intentionally search the entire active fleet first.
      final cars = await _carService.getCars(tenantId: _tenantId);
      final snapshot = await _availabilityService.getAvailabilityForRange(
        rangeStart: pickup,
        rangeEnd: returnTime,
        tenantId: _tenantId,
      );

      final available = cars.where((car) {
        return _availabilityService.isCarAvailableForRange(
          car: car,
          start: pickup,
          end: returnTime,
          bookings: snapshot.bookings,
          blocks: snapshot.blocks,
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _availabilitySnapshot = snapshot;
        _availableCars = available;
        _loading = false;
        _step = available.isEmpty ? 1 : 2;
      });

      if (available.isEmpty) {
        _showError('No vehicles are available for the selected rental period.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to check vehicle availability.';
      });
      _showError('Unable to check vehicle availability.');
    }
  }

  Future<void> _selectVehicle(Car car) async {
    print('🔥 SELECT VEHICLE CALLED | car=${car.id} | name=${car.name} | pricingProfileId=${car.pricingProfileId}');
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // SECOND, FRESH CHECK for the exact vehicle and exact rental range.
      final snapshot = await _availabilityService.getAvailabilityForRange(
        rangeStart: _pickupDateTime,
        rangeEnd: _returnDateTime,
        tenantId: _tenantId,
      );

      final freshCar = snapshot.cars.cast<Car?>().firstWhere(
            (candidate) => candidate?.id == car.id,
            orElse: () => null,
          );

      if (freshCar == null) {
        throw Exception('Vehicle no longer exists.');
      }

      final available = _availabilityService.isCarAvailableForRange(
        car: freshCar,
        start: _pickupDateTime,
        end: _returnDateTime,
        bookings: snapshot.bookings,
        blocks: snapshot.blocks,
      );

      if (!available) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _selectedCar = null;
          _availabilitySnapshot = snapshot;
          _availableCars = _availableCars
              .where((item) => item.id != car.id)
              .toList();
        });
        _showError(
          '${car.name} is no longer available for the selected period.',
        );
        return;
      }

      if (!mounted) return;
      setState(() {
        _availabilitySnapshot = snapshot;
        _selectedCar = freshCar;
        _loading = false;
        _step = 3;
      });

      await _prepareBranchesForVehicle(freshCar);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to verify this vehicle.';
      });
      _showError('Unable to verify this vehicle. Please try again.');
    }
  }

  Future<void> _prepareBranchesForVehicle(Car car) async {
    final valid = _branches.where((branch) {
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
    print('🔥 CONTINUE VEHICLE → BRANCH | car=${_selectedCar?.id} | branch=$_selectedBranchId');
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
      setState(() => _step = 4);
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

      developer.log('profile.id = ${profile.id}', name: 'AdminNewBooking');
      developer.log('profile.kmPricingMode = ${profile.kmPricingMode}', name: 'AdminNewBooking');
      developer.log('profile.kmPackages.length = ${profile.kmPackages.length}', name: 'AdminNewBooking');
      print('profile.id = ${profile.id}');
      print('profile.kmPricingMode = ${profile.kmPricingMode}');
      print('profile.kmPackages.length = ${profile.kmPackages.length}');

      for (final package in profile.kmPackages) {
        print('PACKAGE => id=${package.id}, name=${package.name}, includedKm=${package.includedKm}, unlimitedKm=${package.unlimitedKm}, dailyRate=${package.dailyRate}, hourlyRate=${package.hourlyRate}, extraKmRate=${package.extraKmRate}');
        developer.log(
          'PACKAGE => id=${package.id}, name=${package.name}, includedKm=${package.includedKm}, unlimitedKm=${package.unlimitedKm}, dailyRate=${package.dailyRate}, hourlyRate=${package.hourlyRate}, extraKmRate=${package.extraKmRate}',
          name: 'AdminNewBooking',
        );
      }

      // Diagnostic raw Firestore read. This is intentionally only for debugging
      // the exact document and field shape when the parsed package list is empty.
      if (profile.kmPackages.isEmpty) {
        developer.log(
          'Parsed kmPackages is EMPTY. Reading raw Firestore document...',
          name: 'AdminNewBooking',
        );

        print('Parsed kmPackages EMPTY. Reading raw Firestore document...');
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
        print('RAW kmPackages = ${rawData?['kmPackages']}');
        print('RAW packages = ${rawData?['packages']}');
        print('RAW kmPricingMode = ${rawData?['kmPricingMode']}');
        developer.log(
          'RAW pricing document keys = ${rawData?.keys.toList()}',
          name: 'AdminNewBooking',
        );
        developer.log(
          'RAW kmPackages = ${rawData?['kmPackages']}',
          name: 'AdminNewBooking',
        );
        developer.log(
          'RAW packages = ${rawData?['packages']}',
          name: 'AdminNewBooking',
        );
        developer.log(
          'RAW kmPricingMode = ${rawData?['kmPricingMode']}',
          name: 'AdminNewBooking',
        );

        if (!rawDoc.exists || rawData == null) {
          throw Exception(
            'Pricing document does not exist at tenants/$_tenantId/pricingProfiles/${car.pricingProfileId.trim()}.',
          );
        }

        throw Exception(
          'Pricing profile exists, but PricingProfile.fromMap returned 0 KM packages. Check the DEBUG logs for RAW kmPackages field.',
        );
      }

      final packages = profile.kmPackages;

      if (profile.kmPricingMode == KmPricingMode.package &&
          packages.isEmpty) {
        throw Exception(
          'No KM packages were found in pricing profile "${profile.id}".',
        );
      }

      // Prefer a finite KM package as the initial selection.
      // Unlimited remains available in the list and can be selected manually.
      KmPricingPackage? selected;
      if (packages.isNotEmpty) {
        try {
          selected = packages.firstWhere((package) => !package.unlimitedKm);
        } catch (_) {
          selected = packages.first;
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
        _step = 5;
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
      final result = _pricingEngine.calculate(
        config: config,
        pricingProfileId: profile.id,
        pickupDateTime: _pickupDateTime,
        returnDateTime: _returnDateTime,
        actualKm: 0,
        plannedKm: 0,
        selectedKmPackageId: selectedPackage.id,
        selectedKm: selectedPackage.unlimitedKm
            ? null
            : selectedPackage.includedKm,
        unlimitedKm: selectedPackage.unlimitedKm,
        includeSecurityDeposit: true,
      );

      if (!mounted) return;
      setState(() => _pricingResult = result);
    } catch (e) {
      _showError('Unable to calculate pricing.');
    }
  }

  double _packageDisplayRate(KmPricingPackage package) {
    if (package.dailyRate > 0) {
      return package.dailyRate;
    }
    if (package.hourlyRate > 0) {
      return package.hourlyRate;
    }
    if (package.weekendRate > 0) {
      return package.weekendRate;
    }
    if (package.weeklyRate > 0) {
      return package.weeklyRate;
    }
    return package.monthlyRate;
  }

  void _selectPackage(KmPricingPackage package) {
    print('🔥 KM PACKAGE SELECTED | id=${package.id} | name=${package.name} | includedKm=${package.includedKm} | unlimited=${package.unlimitedKm}');
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
        _step = 7;
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
    print('🔥 CREATE BOOKING CALLED | customer=${_selectedCustomer?.customerId} | car=${_selectedCar?.id} | total=${_pricingResult?.total}');
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

    final total = result.total;
    if (_paidAmount < 0 || _paidAmount > total) {
      _showError('Paid amount must be between ₹0 and the total amount.');
      return;
    }

    final paymentStatus = _paidAmount >= total && total > 0
        ? PaymentStatus.paid
        : (_paidAmount > 0 ? PaymentStatus.partiallyPaid : PaymentStatus.pending);

    final pricingSnapshot = BookingPricingSnapshot(
      pricingProfileId: result.pricingProfileId,
      kmPackageId: result.selectedKmPackageId,
      kmPackageName: result.selectedKmPackageName,
      includedKm: result.includedKm,
      unlimitedKm: result.unlimitedKm,
      extraKmRate: result.selectedKmPackageExtraKmRate ?? profile.extraKmRate,
      baseAmount: result.rentalPrice,
      extraKmAmount: result.extraKmCharge,
      extraTimeAmount: result.extraTimeCharge,
      addOnsAmount: result.addOnTotal,
      protectionAmount: result.protectionTotal,
      discountAmount: result.discountAmount,
      taxAmount: result.taxAmount,
      securityDeposit: result.securityDeposit,
      totalAmount: result.total,
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
      extraKmRate: result.selectedKmPackageExtraKmRate ?? profile.extraKmRate,
      pricingProfileId: result.pricingProfileId,
      baseAmount: result.rentalPrice,
      extraKmAmount: result.extraKmCharge,
      extraTimeAmount: result.extraTimeCharge,
      addOnsAmount: result.addOnTotal,
      protectionAmount: result.protectionTotal,
      discountAmount: result.discountAmount,
      taxAmount: result.taxAmount,
      securityDeposit: result.securityDeposit,
      totalAmount: result.total,
      pricing: pricingSnapshot,
      paidAmount: _paidAmount,
      refundAmount: 0,
      paymentMethod: _paymentMethod,
      couponCode: null,
      customerName: customer.fullName,
      customerPhone: customer.phone,
      customerEmail: customer.email,
      customerNote: _bookingNote,
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
      if (_step == 7) {
        _step = 6;
      } else if (_step == 6) {
        _step = 5;
      } else if (_step == 5) {
        _step = 4;
      } else if (_step == 4) {
        _step = 3;
      } else if (_step == 3) {
        _step = 2;
      } else {
        _step = 1;
      }
    });
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
          _step == 5 ? 'Choose KM Package' : 'New Booking',
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
                if (_step != 5) _buildProgress(),
                if (_step != 5) const SizedBox(height: 18),
                _buildStepContent(),
              ],
            ),
            if (_step == 5 && !_loading && !_creatingBooking && _packages.isNotEmpty)
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
                        setState(() => _step = 6);
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
    final labels = const ['Dates', 'Vehicle', 'Branch', 'Customer', 'Package', 'Pricing', 'Confirm'];
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
                'Booking ${_step}/7',
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
              value: _step / 7,
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
        return _buildDates();
      case 2:
        return _buildVehicles();
      case 3:
        return _buildBranch();
      case 4:
        return _buildCustomer();
      case 5:
        return _buildPackage();
      case 6:
        return _buildPricing();
      case 7:
        return _buildReview();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildDates() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heroCard(
          icon: Icons.event_available_rounded,
          title: 'Start with the rental period',
          subtitle: 'Choose the exact pickup and return time. Vehicle availability will be searched across the complete period.',
        ),
        const SizedBox(height: 16),
        _sectionCard(
          title: 'Pickup',
          subtitle: 'When the vehicle leaves the branch',
          child: Row(
            children: [
              Expanded(child: _dateTile('Date', _formatDate(_pickupDate), Icons.calendar_today_rounded, _selectPickupDate)),
              const SizedBox(width: 10),
              Expanded(child: _dateTile('Time', _formatTime(_pickupTime), Icons.schedule_rounded, _selectPickupTime)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'Return',
          subtitle: 'When the vehicle comes back',
          child: Row(
            children: [
              Expanded(child: _dateTile('Date', _formatDate(_returnDate), Icons.event_available_rounded, _selectReturnDate)),
              const SizedBox(width: 10),
              Expanded(child: _dateTile('Time', _formatTime(_returnTime), Icons.access_time_rounded, _selectReturnTime)),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _primaryButton('Search Vehicle Availability', Icons.search_rounded, _searchAvailability),
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
            fontSize: 27,
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
        if (_packages.isEmpty)
          _emptyCard(
            'No KM packages',
            'Pricing will be calculated from the vehicle pricing profile.',
          )
        else
          ..._packages.map(_packageCard),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _packageCard(KmPricingPackage package) {
    final selected = _selectedPackage?.id == package.id;

    print(
      '🔥 RENDER PACKAGE | id=${package.id} | name=${package.name} | '
      'includedKm=${package.includedKm} | selected=$selected | '
      'hourly=${package.hourlyRate} | daily=${package.dailyRate} | '
      'weekend=${package.weekendRate} | extraKm=${package.extraKmRate}',
    );

    return GestureDetector(
      onTap: () => _selectPackage(package),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 15),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: selected ? primary : const Color(0xFFE4E8E7),
            width: selected ? 1.8 : 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(selected ? .06 : .035),
              blurRadius: selected ? 14 : 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: selected ? primary : softAccent,
                    borderRadius: BorderRadius.circular(19),
                  ),
                  child: Icon(
                    Icons.speed_rounded,
                    color: selected ? Colors.white : primary,
                    size: 34,
                  ),
                ),
                const SizedBox(width: 17),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          package.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(
                            color: heading,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          package.unlimitedKm
                              ? 'Unlimited KM'
                              : '${package.includedKm ?? 0} KM included',
                          style: GoogleFonts.manrope(
                            color: primary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: selected ? primary : const Color(0xFFDDE3E1),
                  size: 34,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFFE8FFFC) : const Color(0xFFF6F8F7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  _packageRateColumn('Hourly', package.hourlyRate, true),
                  _packageRateDivider(),
                  _packageRateColumn('Daily', package.dailyRate, false),
                  _packageRateDivider(),
                  _packageRateColumn('Weekend', package.weekendRate, false),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.tune_rounded,
                  color: body,
                  size: 19,
                ),
                const SizedBox(width: 7),
                Text(
                  package.unlimitedKm
                      ? 'Unlimited KM included'
                      : '₹${package.extraKmRate.toStringAsFixed(0)} / extra KM',
                  style: GoogleFonts.manrope(
                    color: body,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
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
        _summaryCard(title: 'Pricing', subtitle: '${_selectedCar?.name ?? ''} • ${_selectedCustomer?.fullName ?? ''}', icon: Icons.receipt_long_rounded, trailing: result == null ? '—' : _money(result.total)),
        const SizedBox(height: 14),
        if (result == null)
          _emptyCard('Pricing unavailable', 'Please return and select a valid package.')
        else ...[
          _priceLine('Rental', result.rentalPrice),
          _priceLine('Extra KM', result.extraKmCharge),
          _priceLine('Extra Time', result.extraTimeCharge),
          _priceLine('Add-ons', result.addOnTotal),
          _priceLine('Protection', result.protectionTotal),
          _priceLine('Discount', -result.discountAmount),
          _priceLine('Tax', result.taxAmount),
          const SizedBox(height: 5),
          _priceLine('Security Deposit', result.securityDeposit),
          const Divider(height: 24, color: border),
          _priceLine('Total', result.total, strong: true),
          const SizedBox(height: 16),
          _sectionCard(
            title: 'Payment collection',
            subtitle: 'Choose how the admin is collecting payment now.',
            child: Column(children: [
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
            ]),
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
        _reviewCard('Rental period', [
          '${_formatDateTime(_pickupDateTime)} → ${_formatDateTime(_returnDateTime)}',
          _durationText(result),
        ]),
        _reviewCard('Vehicle', [car.name, car.registrationNumber.isEmpty ? '${car.type} • ${car.transmission}' : car.registrationNumber]),
        _reviewCard('Pickup branch', [branch['name']?.toString() ?? 'Branch', branch['address']?.toString() ?? '']),
        _reviewCard('Customer', [customer.fullName, customer.phone, customer.email]),
        _reviewCard('KM package', [result.selectedKmPackageName ?? 'Default pricing', result.unlimitedKm ? 'Unlimited KM' : '${result.includedKm ?? 0} KM included']),
        _reviewCard('Payment', [_paymentMethod.toUpperCase(), 'Collected: ${_money(_paidAmount)}', 'Total: ${_money(result.total)}']),
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
              Text(_money(result.total), style: GoogleFonts.manrope(color: heading, fontSize: 24, fontWeight: FontWeight.w900)),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(15), border: Border.all(color: border)),
        child: Row(children: [
          Icon(icon, color: primary, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: GoogleFonts.manrope(color: muted, fontSize: 9, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(value, overflow: TextOverflow.ellipsis, style: GoogleFonts.manrope(color: heading, fontSize: 11.5, fontWeight: FontWeight.w900)),
          ])),
        ]),
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
