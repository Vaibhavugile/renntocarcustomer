import 'package:cloud_firestore/cloud_firestore.dart';

import '../../cars/models/car.dart';
import '../../pricing/models/pricing_profile.dart';

/// Result returned when the AI needs real vehicle + pricing information.
///
/// This keeps the AI layer independent from Firestore document structures.
class AICarLookupResult {
  final Car car;
  final PricingProfile? pricingProfile;
  final List<dynamic> packages;

  const AICarLookupResult({
    required this.car,
    this.pricingProfile,
    this.packages = const [],
  });

  bool get hasPricingProfile => pricingProfile != null;

  bool get hasPackages => packages.isNotEmpty;
}

/// Service used by the AI booking system to retrieve REAL cars and
/// REAL pricing information from Firestore.
///
/// IMPORTANT:
/// - AI must never invent vehicle availability.
/// - AI must never invent prices.
/// - Car pricing is resolved through pricingProfileId.
/// - Branch filtering uses Car.branchIds.
/// - This service only reads Firestore data.
/// - Actual booking conflict checking should continue to use your
///   existing availability service.
class AICarLookupService {
  AICarLookupService._();

  static final AICarLookupService instance = AICarLookupService._();

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  // ---------------------------------------------------------------------------
  // COLLECTION REFERENCES
  // ---------------------------------------------------------------------------

  CollectionReference<Map<String, dynamic>> _carsCollection(
    String tenantId,
  ) {
    return _firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('cars');
  }

  CollectionReference<Map<String, dynamic>> _pricingProfilesCollection(
    String tenantId,
  ) {
    return _firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('pricingProfiles');
  }

  // ---------------------------------------------------------------------------
  // GET ALL ACTIVE CARS
  // ---------------------------------------------------------------------------

  Future<List<Car>> getActiveCars({
    required String tenantId,
    String? branchId,
  }) async {
    if (tenantId.trim().isEmpty) {
      throw AICarLookupException(
        'Tenant ID is required.',
        code: 'invalid-tenant',
      );
    }

    try {
      Query<Map<String, dynamic>> query =
          _carsCollection(tenantId)
              .where('isActive', isEqualTo: true);

      final snapshot = await query.get();

      final cars = <Car>[];

      for (final document in snapshot.docs) {
        try {
          final car = Car.fromFirestore(document);

          if (!_matchesBranch(
            car: car,
            branchId: branchId,
          )) {
            continue;
          }

          cars.add(car);
        } catch (_) {
          // Do not allow one malformed car document to break
          // the entire AI lookup.
          continue;
        }
      }

      return cars;
    } on FirebaseException catch (e) {
      throw AICarLookupException(
        e.message ?? 'Unable to load cars.',
        code: e.code,
      );
    } catch (e) {
      throw AICarLookupException(
        'Unable to load cars.',
        code: 'cars-load-failed',
        originalError: e,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // GET AVAILABLE CARS
  // ---------------------------------------------------------------------------

  Future<List<Car>> getAvailableCars({
    required String tenantId,
    String? branchId,
  }) async {
    if (tenantId.trim().isEmpty) {
      throw AICarLookupException(
        'Tenant ID is required.',
        code: 'invalid-tenant',
      );
    }

    try {
      Query<Map<String, dynamic>> query =
          _carsCollection(tenantId)
              .where('isActive', isEqualTo: true)
              .where('isAvailable', isEqualTo: true);

      final snapshot = await query.get();

      final cars = <Car>[];

      for (final document in snapshot.docs) {
        try {
          final car = Car.fromFirestore(document);

          if (!_isCarCurrentlyAvailable(car)) {
            continue;
          }

          if (!_matchesBranch(
            car: car,
            branchId: branchId,
          )) {
            continue;
          }

          cars.add(car);
        } catch (_) {
          continue;
        }
      }

      return cars;
    } on FirebaseException catch (e) {
      throw AICarLookupException(
        e.message ?? 'Unable to load available cars.',
        code: e.code,
      );
    } catch (e) {
      throw AICarLookupException(
        'Unable to load available cars.',
        code: 'available-cars-load-failed',
        originalError: e,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // GET CAR BY ID
  // ---------------------------------------------------------------------------

  Future<Car?> getCarById({
    required String tenantId,
    required String carId,
  }) async {
    if (tenantId.trim().isEmpty) {
      throw AICarLookupException(
        'Tenant ID is required.',
        code: 'invalid-tenant',
      );
    }

    if (carId.trim().isEmpty) {
      throw AICarLookupException(
        'Car ID is required.',
        code: 'invalid-car-id',
      );
    }

    try {
      final document = await _carsCollection(tenantId)
          .doc(carId)
          .get();

      if (!document.exists) {
        return null;
      }

      return Car.fromFirestore(document);
    } on FirebaseException catch (e) {
      throw AICarLookupException(
        e.message ?? 'Unable to load car.',
        code: e.code,
      );
    } catch (e) {
      throw AICarLookupException(
        'Unable to load car.',
        code: 'car-load-failed',
        originalError: e,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // GET PRICING PROFILE BY ID
  // ---------------------------------------------------------------------------

  Future<PricingProfile?> getPricingProfile({
    required String tenantId,
    required String pricingProfileId,
  }) async {
    if (tenantId.trim().isEmpty) {
      throw AICarLookupException(
        'Tenant ID is required.',
        code: 'invalid-tenant',
      );
    }

    if (pricingProfileId.trim().isEmpty) {
      return null;
    }

    try {
      final document = await _pricingProfilesCollection(tenantId)
          .doc(pricingProfileId)
          .get();

      if (!document.exists) {
        return null;
      }

      return PricingProfile.fromFirestore(document);
    } on FirebaseException catch (e) {
      throw AICarLookupException(
        e.message ?? 'Unable to load pricing profile.',
        code: e.code,
      );
    } catch (e) {
      throw AICarLookupException(
        'Unable to load pricing profile.',
        code: 'pricing-profile-load-failed',
        originalError: e,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // GET PRICING PROFILE FOR A CAR
  // ---------------------------------------------------------------------------

  Future<PricingProfile?> getPricingProfileForCar({
    required String tenantId,
    required Car car,
  }) async {
    final pricingProfileId =
        car.pricingProfileId?.trim();

    if (pricingProfileId == null ||
        pricingProfileId.isEmpty) {
      return null;
    }

    return getPricingProfile(
      tenantId: tenantId,
      pricingProfileId: pricingProfileId,
    );
  }

  // ---------------------------------------------------------------------------
  // GET PACKAGES FOR CAR
  // ---------------------------------------------------------------------------

  Future<List<dynamic>> getPackagesForCar({
    required String tenantId,
    required Car car,
    required RentalType rentalType,
  }) async {
    final profile = await getPricingProfileForCar(
      tenantId: tenantId,
      car: car,
    );

    if (profile == null) {
      return <dynamic>[];
    }

    return profile.packagesFor(rentalType);
  }

  // ---------------------------------------------------------------------------
  // GET CAR + PRICING
  // ---------------------------------------------------------------------------

  Future<AICarLookupResult> getCarWithPricing({
    required String tenantId,
    required Car car,
    RentalType? rentalType,
  }) async {
    final profile = await getPricingProfileForCar(
      tenantId: tenantId,
      car: car,
    );

    List<dynamic> packages = <dynamic>[];

    if (profile != null && rentalType != null) {
      packages = profile.packagesFor(rentalType);
    }

    return AICarLookupResult(
      car: car,
      pricingProfile: profile,
      packages: packages,
    );
  }

  // ---------------------------------------------------------------------------
  // GET AVAILABLE CARS + PRICING
  // ---------------------------------------------------------------------------

  Future<List<AICarLookupResult>> getAvailableCarsWithPricing({
    required String tenantId,
    String? branchId,
    RentalType? rentalType,
  }) async {
    final cars = await getAvailableCars(
      tenantId: tenantId,
      branchId: branchId,
    );

    final results = <AICarLookupResult>[];

    for (final car in cars) {
      try {
        final result = await getCarWithPricing(
          tenantId: tenantId,
          car: car,
          rentalType: rentalType,
        );

        results.add(result);
      } catch (_) {
        // Keep the car in the result even if pricing fails.
        results.add(
          AICarLookupResult(
            car: car,
          ),
        );
      }
    }

    return results;
  }

  // ---------------------------------------------------------------------------
  // FIND CARS FOR AI CUSTOMER REQUEST
  // ---------------------------------------------------------------------------

  Future<List<AICarLookupResult>> findCars({
    required String tenantId,
    String? branchId,
    String? carType,
    String? transmission,
    String? fuel,
    int? minimumSeats,
    RentalType? rentalType,
  }) async {
    final cars = await getAvailableCars(
      tenantId: tenantId,
      branchId: branchId,
    );

    final results = <AICarLookupResult>[];

    for (final car in cars) {
      if (!_matchesPreferences(
        car: car,
        carType: carType,
        transmission: transmission,
        fuel: fuel,
        minimumSeats: minimumSeats,
      )) {
        continue;
      }

      try {
        final result = await getCarWithPricing(
          tenantId: tenantId,
          car: car,
          rentalType: rentalType,
        );

        results.add(result);
      } catch (_) {
        results.add(
          AICarLookupResult(
            car: car,
          ),
        );
      }
    }

    return results;
  }

  // ---------------------------------------------------------------------------
  // SEARCH BY NAME / TYPE
  // ---------------------------------------------------------------------------

  Future<List<Car>> searchCars({
    required String tenantId,
    required String searchText,
    String? branchId,
  }) async {
    final text = searchText.trim().toLowerCase();

    if (text.isEmpty) {
      return getAvailableCars(
        tenantId: tenantId,
        branchId: branchId,
      );
    }

    final cars = await getAvailableCars(
      tenantId: tenantId,
      branchId: branchId,
    );

    return cars.where((car) {
      final name =
          (car.name ?? '').toLowerCase();

      final type =
          (car.type ?? '').toLowerCase();

      final fuel =
          (car.fuel ?? '').toLowerCase();

      final transmission =
          (car.transmission ?? '').toLowerCase();

      return name.contains(text) ||
          type.contains(text) ||
          fuel.contains(text) ||
          transmission.contains(text);
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // INTERNAL: BRANCH MATCHING
  // ---------------------------------------------------------------------------

  bool _matchesBranch({
    required Car car,
    String? branchId,
  }) {
    if (branchId == null ||
        branchId.trim().isEmpty) {
      return true;
    }

    final branchIds = car.branchIds;

    if (branchIds == null ||
        branchIds.isEmpty) {
      return false;
    }

    return branchIds.contains(branchId);
  }

  // ---------------------------------------------------------------------------
  // INTERNAL: BASIC AVAILABILITY
  // ---------------------------------------------------------------------------

  bool _isCarCurrentlyAvailable(Car car) {
    if (car.isActive != true) {
      return false;
    }

    if (car.isAvailable != true) {
      return false;
    }

    final status =
        car.status?.toString().toLowerCase();

    if (status != null &&
        status.isNotEmpty &&
        status != 'available') {
      return false;
    }

    return true;
  }

  // ---------------------------------------------------------------------------
  // INTERNAL: CUSTOMER PREFERENCES
  // ---------------------------------------------------------------------------

  bool _matchesPreferences({
    required Car car,
    String? carType,
    String? transmission,
    String? fuel,
    int? minimumSeats,
  }) {
    if (carType != null &&
        carType.trim().isNotEmpty) {
      final actual =
          car.type?.toLowerCase().trim();

      final expected =
          carType.toLowerCase().trim();

      if (actual != expected) {
        return false;
      }
    }

    if (transmission != null &&
        transmission.trim().isNotEmpty) {
      final actual =
          car.transmission?.toLowerCase().trim();

      final expected =
          transmission.toLowerCase().trim();

      if (actual != expected) {
        return false;
      }
    }

    if (fuel != null &&
        fuel.trim().isNotEmpty) {
      final actual =
          car.fuel?.toLowerCase().trim();

      final expected =
          fuel.toLowerCase().trim();

      if (actual != expected) {
        return false;
      }
    }

    if (minimumSeats != null) {
      final seats = car.seats ?? 0;

      if (seats < minimumSeats) {
        return false;
      }
    }

    return true;
  }

  // ---------------------------------------------------------------------------
  // AI-FRIENDLY CAR SUMMARY
  // ---------------------------------------------------------------------------

  Map<String, dynamic> carToAIMap(
    Car car,
  ) {
    return <String, dynamic>{
      'id': car.id,
      'name': car.name,
      'type': car.type,
      'fuel': car.fuel,
      'transmission': car.transmission,
      'seats': car.seats,
      'pricePerDay': car.pricePerDay,
      'pricingProfileId': car.pricingProfileId,
      'branchIds': car.branchIds,
      'isActive': car.isActive,
      'isAvailable': car.isAvailable,
      'status': car.status,
      'image': car.image,
      'images': car.images,
      'registrationNumber': car.registrationNumber,
      'currentKm': car.currentKm,
    };
  }

  Map<String, dynamic> pricingProfileToAIMap(
    PricingProfile profile,
  ) {
    return <String, dynamic>{
      'id': profile.id,
      'name': profile.name,
      'description': profile.description,
      'hourlyPackages': profile.hourlyPackages
          .map((package) => _packageToAIMap(package))
          .toList(),
      'dailyPackages': profile.dailyPackages
          .map((package) => _packageToAIMap(package))
          .toList(),
      'minimumHours': profile.minimumHours,
      'minimumDays': profile.minimumDays,
      'extraHourRate': profile.extraHourRate,
      'extraKmRate': profile.extraKmRate,
    };
  }

  Map<String, dynamic> _packageToAIMap(
    dynamic package,
  ) {
    if (package is Map) {
      return Map<String, dynamic>.from(package);
    }

    try {
      return <String, dynamic>{
        'id': package.id,
        'name': package.name,
        'hours': package.hours,
        'days': package.days,
        'includedKm': package.includedKm,
        'price': package.price,
        'extraKmRate': package.extraKmRate,
      };
    } catch (_) {
      return <String, dynamic>{
        'value': package.toString(),
      };
    }
  }
}

// ============================================================================
// EXCEPTION
// ============================================================================

class AICarLookupException implements Exception {
  final String message;
  final String? code;
  final Object? originalError;

  const AICarLookupException(
    this.message, {
    this.code,
    this.originalError,
  });

  @override
  String toString() {
    if (code == null) {
      return message;
    }

    return '$message ($code)';
  }
}