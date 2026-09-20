import '../models/pricing_config.dart';
import '../models/pricing_profile.dart';
import '../models/km_pricing_package.dart';
import '../services/pricing_service.dart';

/// Central pricing configuration facade.
///
/// PricingManager only loads/resolves pricing configuration.
/// PricingEngine remains the only class responsible for calculating totals.
///
/// Simplified business model:
///   - Hourly
///   - Daily
///   - KM packages
///   - Special date rates
///   - Security deposits
class PricingManager {
  PricingManager._();

  static final PricingManager instance =
      PricingManager._();

  final PricingService _service =
      PricingService.instance;

  // ===========================================================================
  // INITIALIZE
  // ===========================================================================

  Future<PricingConfig> initialize({
    required String tenantId,
  }) async {
    final normalizedTenantId = tenantId.trim();

    if (normalizedTenantId.isEmpty) {
      throw ArgumentError(
        'tenantId cannot be empty.',
      );
    }

    return _service.loadPricing(
      tenantId: normalizedTenantId,
    );
  }

  // ===========================================================================
  // CURRENT PRICING
  // ===========================================================================

  PricingConfig? get pricing =>
      _service.cachedPricing;

  bool get isLoaded =>
      _service.isLoaded;

  String? get cachedTenantId =>
      _service.cachedTenantId;

  // ===========================================================================
  // PROFILE LOOKUP
  // ===========================================================================

  PricingProfile? getPricingForCar(
    String pricingProfileId,
  ) {
    final id = pricingProfileId.trim();

    if (id.isEmpty) return null;

    return _service.getPricingForCar(id);
  }

  Future<PricingProfile?> loadPricingForCar({
    required String tenantId,
    required String pricingProfileId,
  }) async {
    final normalizedTenantId =
        tenantId.trim();
    final normalizedProfileId =
        pricingProfileId.trim();

    if (normalizedTenantId.isEmpty) {
      throw ArgumentError(
        'tenantId cannot be empty.',
      );
    }

    if (normalizedProfileId.isEmpty) {
      throw ArgumentError(
        'pricingProfileId cannot be empty.',
      );
    }

    return _service.getPricingForCarFromFirebase(
      tenantId: normalizedTenantId,
      pricingProfileId: normalizedProfileId,
    );
  }

  // ===========================================================================
  // RENTAL TYPES
  // ===========================================================================

  bool isRentalTypeEnabled(
    PricingProfile profile,
    RentalType type,
  ) {
    return profile.isRentalTypeEnabled(type);
  }

  List<RentalType> availableRentalTypesForRange(
    PricingProfile profile, {
    required DateTime start,
    required DateTime end,
  }) {
    if (end.isBefore(start)) {
      return const [];
    }

    return profile.availableRentalTypesForRange(
      start,
      end,
    );
  }

  // ===========================================================================
  // PACKAGE HELPERS
  // ===========================================================================

  List<KmPricingPackage> packagesFor(
    PricingProfile profile,
    RentalType type,
  ) {
    return List.unmodifiable(
      profile.packagesFor(type),
    );
  }

  KmPricingPackage? getPackage(
    PricingProfile profile, {
    required RentalType type,
    String? packageId,
  }) {
    if (packageId == null ||
        packageId.trim().isEmpty) {
      return null;
    }

    return profile.getPackage(
      packageId.trim(),
      rentalType: type,
    );
  }

  KmPricingPackage? getPackageByKm(
    PricingProfile profile, {
    required RentalType type,
    required int includedKm,
  }) {
    if (includedKm <= 0) return null;

    return profile.getPackageByKm(
      includedKm,
      rentalType: type,
    );
  }

  KmPricingPackage? getUnlimitedPackage(
    PricingProfile profile, {
    required RentalType type,
  }) {
    return profile.getUnlimitedPackage(
      rentalType: type,
    );
  }

  // ===========================================================================
  // SPECIAL RATES
  // ===========================================================================

  SpecialRate? specialRateForDate(
    PricingProfile profile,
    DateTime date,
  ) {
    return profile.specialRateForDate(date);
  }

  SpecialRate? specialRateForRange(
    PricingProfile profile, {
    required DateTime start,
    required DateTime end,
  }) {
    if (end.isBefore(start)) return null;

    return profile.specialRateForRange(
      start,
      end,
    );
  }

  double packagePriceForDate(
    PricingProfile profile, {
    required RentalType type,
    required KmPricingPackage package,
    required DateTime date,
  }) {
    return profile.priceFor(
      rentalType: type,
      package: package,
      date: date,
    );
  }

  double extraKmRateForDate(
    PricingProfile profile, {
    required KmPricingPackage package,
    required DateTime date,
  }) {
    return profile.extraKmRateFor(
      package: package,
      date: date,
    );
  }

  // ===========================================================================
  // HOURLY
  // ===========================================================================

  /// Hourly billing rounds any partial hour up to the next whole hour.
  int billableHourlyHours(
    DateTime start,
    DateTime end,
  ) {
    if (!end.isAfter(start)) return 0;

    final minutes = end.difference(start).inMinutes;

    return (minutes / 60)
        .ceil()
        .clamp(1, 100000);
  }

  // ===========================================================================
  // DAILY
  // ===========================================================================

  /// Daily pricing uses 24-hour billing units.
  ///
  /// Example:
  /// 20 Sep 10:00 -> 25 Sep 10:00 = 5 days.
  ///
  /// Any partial 24-hour period counts as one additional day.
  int billableDailyDays(
    DateTime start,
    DateTime end,
  ) {
    if (!end.isAfter(start)) return 0;

    final minutes =
        end.difference(start).inMinutes;

    return (minutes / (24 * 60))
        .ceil()
        .clamp(1, 100000);
  }

  /// Operational availability for daily rentals is date-based and intentionally
  /// separate from pricing calculation.
  DateTime dailyAvailabilityStart(
    DateTime pickupDate,
  ) {
    return DateTime(
      pickupDate.year,
      pickupDate.month,
      pickupDate.day,
    );
  }

  DateTime dailyAvailabilityEnd(
    DateTime returnDate,
  ) {
    return DateTime(
      returnDate.year,
      returnDate.month,
      returnDate.day,
      23,
      59,
      59,
      999,
    );
  }

  // ===========================================================================
  // AVAILABILITY RANGE
  // ===========================================================================

  DateTimeRangeValue normalizeAvailabilityRange({
    required RentalType type,
    required DateTime pickup,
    required DateTime returnDateTime,
  }) {
    if (returnDateTime.isBefore(pickup)) {
      throw ArgumentError(
        'Return date/time cannot be before pickup date/time.',
      );
    }

    switch (type) {
      case RentalType.hourly:
        return DateTimeRangeValue(
          start: pickup,
          end: returnDateTime,
        );

      case RentalType.daily:
        return DateTimeRangeValue(
          start: dailyAvailabilityStart(pickup),
          end: dailyAvailabilityEnd(
            returnDateTime,
          ),
        );
    }
  }

  // ===========================================================================
  // PRICING SNAPSHOT
  // ===========================================================================

  /// Creates a simple immutable pricing snapshot for a booking.
  ///
  /// A booking should save the values calculated at booking time so later
  /// pricing edits do not change an existing booking.
  Map<String, dynamic> buildPricingSnapshot({
    required PricingProfile profile,
    required RentalType rentalType,
    required DateTime pickup,
    required DateTime returnDateTime,
    String? selectedKmPackageId,
    int actualKm = 0,
    int plannedKm = 0,
    double baseAmount = 0,
    double extraKmAmount = 0,
    double addOnAmount = 0,
    double protectionAmount = 0,
    double discountAmount = 0,
    double taxAmount = 0,
    double securityDepositAmount = 0,
    double totalAmount = 0,
  }) {
    final package =
        selectedKmPackageId == null
            ? null
            : profile.getPackage(
                selectedKmPackageId,
                rentalType: rentalType,
              );

    return {
      'pricingProfileId': profile.id,
      'pricingProfileName': profile.name,
      'currency': profile.currency,

      'rentalType': rentalType.value,

      'pickupDateTime': pickup,
      'returnDateTime': returnDateTime,

      'actualKm': actualKm,
      'plannedKm': plannedKm,

      'selectedKmPackage':
          package?.toMap(),

      'specialRate': profile
          .specialRateForRange(
            pickup,
            returnDateTime,
          )
          ?.toMap(),

      'baseAmount': baseAmount,
      'extraKmAmount': extraKmAmount,
      'addOnAmount': addOnAmount,
      'protectionAmount':
          protectionAmount,
      'discountAmount':
          discountAmount,
      'taxAmount': taxAmount,
      'securityDepositAmount':
          securityDepositAmount,
      'totalAmount': totalAmount,
    };
  }

  // ===========================================================================
  // DEPOSIT SNAPSHOT
  // ===========================================================================

  Map<String, dynamic> buildDepositSnapshot({
    required PricingProfile profile,
    required DepositType type,
    double amount = 0,
    String status = 'pending',
    String paymentMethod = '',
    String transactionId = '',
    Map<String, dynamic>? securityAsset,
    String notes = '',
  }) {
    // Asset deposits are security only; they do not become monetary payable
    // amounts.
    final monetaryAmount =
        type.isMonetary
            ? (amount < 0 ? 0 : amount)
            : 0.0;

    return {
      'required': profile.securityDeposit.required,
      'type': type.value,
      'amount': monetaryAmount,
      'status': status,
      'paymentMethod': paymentMethod,
      'transactionId': transactionId,
      'securityAsset': securityAsset,
      'notes': notes,
      'configuredDefaultAmount':
          profile.securityDepositAmount,
      'minimumAssetValue':
          profile.securityDeposit.minimumAssetValue,
    };
  }

  // ===========================================================================
  // CACHE
  // ===========================================================================

  void setPricing(
    PricingConfig pricing, {
    String? tenantId,
  }) {
    _service.setPricing(
      pricing,
      tenantId: tenantId?.trim(),
    );
  }

  void clear() {
    _service.clearCache();
  }
}

/// Normalized availability interval.
///
/// Hourly:
///   exact pickup/return timestamps.
///
/// Daily:
///   pickup date 00:00 -> return date 23:59:59.999.
class DateTimeRangeValue {
  final DateTime start;
  final DateTime end;

  const DateTimeRangeValue({
    required this.start,
    required this.end,
  });

  Duration get duration =>
      end.difference(start);
}
