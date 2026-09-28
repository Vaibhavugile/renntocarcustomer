import 'package:flutter/foundation.dart';

import '../../admin/availability/services/admin_availability_service.dart';
import '../../cars/models/car.dart';

/// AI-facing availability result.
///
/// This service does NOT implement a second availability algorithm.
///
/// It delegates availability checking to the existing
/// AdminAvailabilityService so the AI chatbot and admin booking/calendar
/// always use the same availability rules.
class AIBookingAvailabilityResult {
  final bool success;

  final String tenantId;

  final DateTime pickupDateTime;

  final DateTime returnDateTime;

  final DateTime operationalStart;

  final DateTime operationalEnd;

  final List<Car> availableCars;

  final List<Car> unavailableCars;

  final String? branchId;

  final String? message;

  final String? errorCode;

  const AIBookingAvailabilityResult({
    required this.success,
    required this.tenantId,
    required this.pickupDateTime,
    required this.returnDateTime,
    required this.operationalStart,
    required this.operationalEnd,
    required this.availableCars,
    required this.unavailableCars,
    this.branchId,
    this.message,
    this.errorCode,
  });

  int get availableCount => availableCars.length;

  int get unavailableCount => unavailableCars.length;

  bool get hasAvailableCars => availableCars.isNotEmpty;

  bool get hasUnavailableCars => unavailableCars.isNotEmpty;

  bool get hasError =>
      !success || errorCode != null;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'success': success,
      'tenantId': tenantId,
      'pickupDateTime':
          pickupDateTime.toIso8601String(),
      'returnDateTime':
          returnDateTime.toIso8601String(),
      'operationalStart':
          operationalStart.toIso8601String(),
      'operationalEnd':
          operationalEnd.toIso8601String(),
      'branchId': branchId,
      'availableCount': availableCount,
      'unavailableCount': unavailableCount,
      'availableCars': availableCars
          .map(_carToMap)
          .toList(),
      'unavailableCars': unavailableCars
          .map(_carToMap)
          .toList(),
      'message': message,
      'errorCode': errorCode,
    };
  }

  static Map<String, dynamic> _carToMap(
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
      'pricingProfileId':
          car.pricingProfileId,
      'branchIds': car.branchIds,
      'isActive': car.isActive,
      'isAvailable': car.isAvailable,
      'status': car.status,
      'image': car.image,
      'images': car.images,
      'registrationNumber':
          car.registrationNumber,
      'currentKm': car.currentKm,
    };
  }
}


/// AI booking availability service.
///
/// Responsibilities:
///
/// 1. Validate pickup/return date-times.
/// 2. Normalize the requested rental range using the SAME rules as the
///    existing AdminAvailabilityService.
/// 3. Ask AdminAvailabilityService for genuinely available cars.
/// 4. Apply branch filtering using the car's branchIds.
/// 5. Apply optional AI preferences such as:
///      - car type
///      - transmission
///      - fuel
///      - minimum seats
/// 6. Return a structured result to the AI layer.
///
/// IMPORTANT:
///
/// This class intentionally does NOT query bookings directly.
///
/// Your AdminAvailabilityService already handles:
/// - blocking booking statuses
/// - expired pending bookings
/// - vehicle blocks
/// - overlap detection
/// - active/inactive vehicle state
/// - fresh server reads
///
/// Therefore this service delegates to it.
class AIBookingAvailabilityService {
  AIBookingAvailabilityService._();

  static final AIBookingAvailabilityService instance =
      AIBookingAvailabilityService._();

  final AdminAvailabilityService
      _availabilityService =
      AdminAvailabilityService.instance;

  // ---------------------------------------------------------------------------
  // MAIN METHOD
  // ---------------------------------------------------------------------------

  /// Find genuinely available cars for an AI booking request.
  ///
  /// Example:
  ///
  /// pickup:
  /// 2026-09-28 10:00
  ///
  /// return:
  /// 2026-09-30 18:00
  ///
  /// The existing availability service remains the source of truth.
  Future<AIBookingAvailabilityResult>
      findAvailableCars({
    required String tenantId,
    required DateTime pickupDateTime,
    required DateTime returnDateTime,
    String? branchId,
    String? carType,
    String? transmission,
    String? fuel,
    int? minimumSeats,
    dynamic rentalType,
  }) async {
    final normalizedTenantId =
        tenantId.trim();

    debugPrint(
      '[AI_AVAILABILITY] ============================================',
    );

    debugPrint(
      '[AI_AVAILABILITY] 🚀 Availability request started',
    );

    debugPrint(
      '[AI_AVAILABILITY] tenantId=$normalizedTenantId',
    );

    debugPrint(
      '[AI_AVAILABILITY] pickup=$pickupDateTime',
    );

    debugPrint(
      '[AI_AVAILABILITY] return=$returnDateTime',
    );

    debugPrint(
      '[AI_AVAILABILITY] branchId=$branchId',
    );

    debugPrint(
      '[AI_AVAILABILITY] carType=$carType',
    );

    debugPrint(
      '[AI_AVAILABILITY] transmission=$transmission',
    );

    debugPrint(
      '[AI_AVAILABILITY] fuel=$fuel',
    );

    debugPrint(
      '[AI_AVAILABILITY] minimumSeats=$minimumSeats',
    );

    // -----------------------------------------------------------------------
    // VALIDATION
    // -----------------------------------------------------------------------

    if (normalizedTenantId.isEmpty) {
      return _failure(
        tenantId: normalizedTenantId,
        pickupDateTime: pickupDateTime,
        returnDateTime: returnDateTime,
        message: 'Tenant ID is required.',
        errorCode: 'invalid-tenant',
      );
    }

    if (!returnDateTime.isAfter(
      pickupDateTime,
    )) {
      debugPrint(
        '[AI_AVAILABILITY] ❌ Return time is not after pickup time',
      );

      return _failure(
        tenantId: normalizedTenantId,
        pickupDateTime: pickupDateTime,
        returnDateTime: returnDateTime,
        message:
            'Return date and time must be after pickup date and time.',
        errorCode: 'invalid-date-range',
      );
    }

    // -----------------------------------------------------------------------
    // NORMALIZE RENTAL RANGE
    // -----------------------------------------------------------------------
    //
    // We intentionally use the same normalization function already used
    // by AdminAvailabilityService.
    //
    // This is important because your application distinguishes between:
    //
    // HOURLY:
    // exact pickup/return timestamps
    //
    // DAILY:
    // selected calendar days / operational range
    //
    // Pricing minimum hours/days should NOT alter availability.
    //

    try {
      final range =
          _normalizeRentalRange(
        pickupDateTime: pickupDateTime,
        returnDateTime: returnDateTime,
        rentalType: rentalType,
      );

      debugPrint(
        '[AI_AVAILABILITY] 🗓️ Operational range',
      );

      debugPrint(
        '[AI_AVAILABILITY] start=${range.start}',
      );

      debugPrint(
        '[AI_AVAILABILITY] end=${range.end}',
      );

      // ---------------------------------------------------------------------
      // ASK EXISTING AVAILABILITY SERVICE
      // ---------------------------------------------------------------------

      final availableCars =
          await _availabilityService
              .getAvailableCarsForRange(
        rangeStart: range.start,
        rangeEnd: range.end,
        tenantId: normalizedTenantId,
      );

      debugPrint(
        '[AI_AVAILABILITY] 🚗 Raw available cars=${availableCars.length}',
      );

      // ---------------------------------------------------------------------
      // BRANCH FILTER
      // ---------------------------------------------------------------------

      final branchFilteredCars =
          availableCars.where((car) {
        return _matchesBranch(
          car: car,
          branchId: branchId,
        );
      }).toList();

      debugPrint(
        '[AI_AVAILABILITY] 🏢 After branch filter=${branchFilteredCars.length}',
      );

      // ---------------------------------------------------------------------
      // PREFERENCE FILTER
      // ---------------------------------------------------------------------

      final filteredCars =
          branchFilteredCars.where((car) {
        return _matchesPreferences(
          car: car,
          carType: carType,
          transmission: transmission,
          fuel: fuel,
          minimumSeats: minimumSeats,
        );
      }).toList();

      debugPrint(
        '[AI_AVAILABILITY] 🎯 After preference filter=${filteredCars.length}',
      );

      // ---------------------------------------------------------------------
      // LOG FINAL CARS
      // ---------------------------------------------------------------------

      for (final car in filteredCars) {
        debugPrint(
          '[AI_AVAILABILITY] ✅ AVAILABLE CAR',
        );

        debugPrint(
          '[AI_AVAILABILITY]    id=${car.id}',
        );

        debugPrint(
          '[AI_AVAILABILITY]    name=${car.name}',
        );

        debugPrint(
          '[AI_AVAILABILITY]    type=${car.type}',
        );

        debugPrint(
          '[AI_AVAILABILITY]    transmission=${car.transmission}',
        );

        debugPrint(
          '[AI_AVAILABILITY]    seats=${car.seats}',
        );

        debugPrint(
          '[AI_AVAILABILITY]    pricingProfileId=${car.pricingProfileId}',
        );
      }

      debugPrint(
        '[AI_AVAILABILITY] 🏁 FINAL AVAILABLE CARS=${filteredCars.length}',
      );

      debugPrint(
        '[AI_AVAILABILITY] ============================================',
      );

      return AIBookingAvailabilityResult(
        success: true,
        tenantId: normalizedTenantId,
        pickupDateTime: pickupDateTime,
        returnDateTime: returnDateTime,
        operationalStart: range.start,
        operationalEnd: range.end,
        availableCars: filteredCars,
        unavailableCars: const <Car>[],
        branchId: branchId,
        message: filteredCars.isEmpty
            ? 'No vehicles are available for the requested dates and preferences.'
            : '${filteredCars.length} vehicle(s) are available.',
      );
    } catch (e, stackTrace) {
      debugPrint(
        '[AI_AVAILABILITY] ❌ Availability lookup failed',
      );

      debugPrint(
        '[AI_AVAILABILITY] error=$e',
      );

      debugPrint(
        '[AI_AVAILABILITY] stackTrace=$stackTrace',
      );

      return _failure(
        tenantId: normalizedTenantId,
        pickupDateTime: pickupDateTime,
        returnDateTime: returnDateTime,
        message:
            'Unable to check vehicle availability right now.',
        errorCode: 'availability-lookup-failed',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // SIMPLE CAR AVAILABILITY CHECK
  // ---------------------------------------------------------------------------

  /// Checks one particular car.
  ///
  /// Useful when the customer says:
  ///
  /// "Is car2 available?"
  ///
  /// or:
  ///
  /// "Can I book the selected car?"
  Future<bool> isCarAvailable({
    required String tenantId,
    required Car car,
    required DateTime pickupDateTime,
    required DateTime returnDateTime,
    dynamic rentalType,
  }) async {
    if (tenantId.trim().isEmpty) {
      return false;
    }

    if (!returnDateTime.isAfter(
      pickupDateTime,
    )) {
      return false;
    }

    try {
      final range =
          _normalizeRentalRange(
        pickupDateTime: pickupDateTime,
        returnDateTime: returnDateTime,
        rentalType: rentalType,
      );

      final snapshot =
          await _availabilityService
              .getAvailabilityForRange(
        rangeStart: range.start,
        rangeEnd: range.end,
        tenantId: tenantId.trim(),
      );

      final available =
          _availabilityService.isCarAvailableForRange(
        car: car,
        start: range.start,
        end: range.end,
        bookings: snapshot.bookings,
        blocks: snapshot.blocks,
      );

      debugPrint(
        '[AI_AVAILABILITY] car=${car.id} '
        'available=$available',
      );

      return available;
    } catch (e) {
      debugPrint(
        '[AI_AVAILABILITY] ❌ Single car check failed: $e',
      );

      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // GET AVAILABILITY SNAPSHOT
  // ---------------------------------------------------------------------------

  /// Exposes the existing availability snapshot to the AI layer.
  ///
  /// This is useful later when we need to explain WHY a vehicle cannot
  /// be booked.
  Future<AdminAvailabilitySnapshot>
      getAvailabilitySnapshot({
    required String tenantId,
    required DateTime pickupDateTime,
    required DateTime returnDateTime,
    dynamic rentalType,
  }) async {
    final range =
        _normalizeRentalRange(
      pickupDateTime: pickupDateTime,
      returnDateTime: returnDateTime,
      rentalType: rentalType,
    );

    return _availabilityService
        .getAvailabilityForRange(
      rangeStart: range.start,
      rangeEnd: range.end,
      tenantId: tenantId.trim(),
    );
  }

  // ---------------------------------------------------------------------------
  // FIND AVAILABLE CAR IDS
  // ---------------------------------------------------------------------------

  Future<List<String>>
      getAvailableCarIds({
    required String tenantId,
    required DateTime pickupDateTime,
    required DateTime returnDateTime,
    String? branchId,
    String? carType,
    String? transmission,
    String? fuel,
    int? minimumSeats,
    dynamic rentalType,
  }) async {
    final result =
        await findAvailableCars(
      tenantId: tenantId,
      pickupDateTime: pickupDateTime,
      returnDateTime: returnDateTime,
      branchId: branchId,
      carType: carType,
      transmission: transmission,
      fuel: fuel,
      minimumSeats: minimumSeats,
      rentalType: rentalType,
    );

    return result.availableCars
        .map((car) => car.id)
        .toList();
  }

  // ---------------------------------------------------------------------------
  // BRANCH MATCHING
  // ---------------------------------------------------------------------------

  bool _matchesBranch({
    required Car car,
    String? branchId,
  }) {
    final requestedBranch =
        branchId?.trim();

    if (requestedBranch == null ||
        requestedBranch.isEmpty) {
      return true;
    }

    final branchIds =
        car.branchIds;

    if (branchIds.isEmpty) {
      return false;
    }

    final match =
        branchIds.contains(requestedBranch);

    debugPrint(
      '[AI_AVAILABILITY] '
      'branch check car=${car.id} '
      'requested=$requestedBranch '
      'carBranches=$branchIds '
      'match=$match',
    );

    return match;
  }

  // ---------------------------------------------------------------------------
  // PREFERENCE MATCHING
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
      final expected =
          carType.trim().toLowerCase();

      final actual =
          car.type.trim().toLowerCase();

      if (actual != expected) {
        return false;
      }
    }

    if (transmission != null &&
        transmission.trim().isNotEmpty) {
      final expected =
          transmission.trim().toLowerCase();

      final actual =
          car.transmission.trim().toLowerCase();

      if (actual != expected) {
        return false;
      }
    }

    if (fuel != null &&
        fuel.trim().isNotEmpty) {
      final expected =
          fuel.trim().toLowerCase();

      final actual =
          car.fuel.trim().toLowerCase();

      if (actual != expected) {
        return false;
      }
    }

    if (minimumSeats != null) {
      if (car.seats < minimumSeats) {
        return false;
      }
    }

    return true;
  }

  // ---------------------------------------------------------------------------
  // RENTAL RANGE NORMALIZATION
  // ---------------------------------------------------------------------------
  //
  // We deliberately keep this as a small adapter around the existing
  // normalizeRentalRange implementation.
  //
  // The AI does not need to know how your operational availability range
  // is calculated.
  //

  dynamic _normalizeRentalRange({
    required DateTime pickupDateTime,
    required DateTime returnDateTime,
    dynamic rentalType,
  }) {
    if (rentalType == null) {
      return _SimpleRentalRange(
        start: pickupDateTime,
        end: returnDateTime,
      );
    }

    try {
      return normalizeRentalRange(
        pickupDateTime: pickupDateTime,
        returnDateTime: returnDateTime,
        rentalType: rentalType,
      );
    } catch (e) {
      debugPrint(
        '[AI_AVAILABILITY] '
        'Rental range normalization fallback: $e',
      );

      return _SimpleRentalRange(
        start: pickupDateTime,
        end: returnDateTime,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // FAILURE RESULT
  // ---------------------------------------------------------------------------

  AIBookingAvailabilityResult _failure({
    required String tenantId,
    required DateTime pickupDateTime,
    required DateTime returnDateTime,
    required String message,
    required String errorCode,
  }) {
    return AIBookingAvailabilityResult(
      success: false,
      tenantId: tenantId,
      pickupDateTime: pickupDateTime,
      returnDateTime: returnDateTime,
      operationalStart: pickupDateTime,
      operationalEnd: returnDateTime,
      availableCars: const <Car>[],
      unavailableCars: const <Car>[],
      message: message,
      errorCode: errorCode,
    );
  }
}


// ============================================================================
// SIMPLE FALLBACK RANGE
// ============================================================================

class _SimpleRentalRange {
  final DateTime start;
  final DateTime end;

  const _SimpleRentalRange({
    required this.start,
    required this.end,
  });
}