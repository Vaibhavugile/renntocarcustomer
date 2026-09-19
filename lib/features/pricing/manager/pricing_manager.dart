import '../models/pricing_config.dart';
import '../models/pricing_profile.dart';
import '../services/pricing_service.dart';

/// Central pricing facade used by customer and admin booking flows.
///
/// Responsibilities:
/// - Load tenant pricing.
/// - Load a vehicle's PricingProfile.
/// - Expose rental-type availability/rules.
/// - Resolve special-date pricing.
/// - Expose pricing version for booking snapshots.
/// - Keep all Firebase access inside PricingService.
///
/// Important:
/// PricingManager does NOT calculate booking totals. PricingEngine remains the
/// single calculation layer. PricingManager only loads/resolves configuration.
class PricingManager {
  PricingManager._();

  static final PricingManager instance = PricingManager._();

  // ===========================================================================
  // PRICING SERVICE
  // ===========================================================================

  final PricingService _service = PricingService.instance;

  // ===========================================================================
  // INITIALIZE
  // ===========================================================================

  Future<PricingConfig> initialize({
    required String tenantId,
  }) async {
    final normalizedTenantId = tenantId.trim();

    if (normalizedTenantId.isEmpty) {
      throw ArgumentError('tenantId cannot be empty.');
    }

    return _service.loadPricing(
      tenantId: normalizedTenantId,
    );
  }

  // ===========================================================================
  // CURRENT PRICING
  // ===========================================================================

  PricingConfig? get pricing {
    return _service.cachedPricing;
  }

  // ===========================================================================
  // LOADED
  // ===========================================================================

  bool get isLoaded {
    return _service.isLoaded;
  }

  // ===========================================================================
  // CACHED TENANT
  // ===========================================================================

  String? get cachedTenantId {
    return _service.cachedTenantId;
  }

  // ===========================================================================
  // GET CAR PRICING FROM CACHE
  // ===========================================================================

  PricingProfile? getPricingForCar(
    String pricingProfileId,
  ) {
    final id = pricingProfileId.trim();

    if (id.isEmpty) return null;

    return _service.getPricingForCar(id);
  }

  // ===========================================================================
  // GET CAR PRICING FROM FIREBASE
  // ===========================================================================

  /// Loads:
  ///
  /// tenants/{tenantId}/pricingProfiles/{pricingProfileId}
  ///
  /// PricingService remains responsible for Firebase access and caching.
  Future<PricingProfile?> loadPricingForCar({
    required String tenantId,
    required String pricingProfileId,
  }) async {
    final normalizedTenantId = tenantId.trim();
    final normalizedProfileId = pricingProfileId.trim();

    if (normalizedTenantId.isEmpty) {
      throw ArgumentError('tenantId cannot be empty.');
    }

    if (normalizedProfileId.isEmpty) {
      throw ArgumentError('pricingProfileId cannot be empty.');
    }

    return _service.getPricingForCarFromFirebase(
      tenantId: normalizedTenantId,
      pricingProfileId: normalizedProfileId,
    );
  }

  // ===========================================================================
  // RENTAL TYPE HELPERS
  // ===========================================================================

  /// Returns whether Hourly/Daily/Weekend is enabled for the profile.
  bool isRentalTypeEnabled(
    PricingProfile profile,
    RentalType type,
  ) {
    return profile.isRentalTypeEnabled(type);
  }

  /// Returns the configured rental-type pricing.
  RentalTypePricing rentalPricingFor(
    PricingProfile profile,
    RentalType type,
  ) {
    return profile.rentalPricingFor(type);
  }

  /// Returns rental types available for a date range.
  ///
  /// Special date rules are evaluated by PricingProfile. The booking UI
  /// should use this before displaying the Hourly/Daily/Weekend cards.
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

  /// Returns the special pricing rule that applies to the selected range.
  SpecialPricingRule? specialRuleForRange(
    PricingProfile profile, {
    required DateTime start,
    required DateTime end,
  }) {
    if (end.isBefore(start)) return null;

    return profile.specialRuleForRange(
      start,
      end,
    );
  }

  /// Gets the applicable profile-level rate.
  ///
  /// KM-package-specific rates must still be resolved by PricingEngine.
  double baseRateFor(
    PricingProfile profile, {
    required RentalType type,
    DateTime? start,
    DateTime? end,
  }) {
    return profile.baseRateFor(
      type,
      start: start,
      end: end,
    );
  }

  /// Gets the applicable extra-KM rate, including special-date overrides.
  double extraKmRateFor(
    PricingProfile profile, {
    DateTime? start,
    DateTime? end,
  }) {
    return profile.extraKmRateFor(
      start: start,
      end: end,
    );
  }

  // ===========================================================================
  // HOURLY HELPERS
  // ===========================================================================

  int minimumHourlyBillingHours(
    PricingProfile profile,
  ) {
    final configured = profile.hourlyPricing.minimumBillingHours;

    return configured > 0 ? configured : 1;
  }

  /// Returns the billable hourly duration.
  ///
  /// Example:
  /// actual = 3 hours
  /// minimum = 5 hours
  /// result = 5
  int billableHourlyHours(
    PricingProfile profile,
    int actualHours,
  ) {
    final safeActual = actualHours < 0 ? 0 : actualHours;
    final minimum = minimumHourlyBillingHours(profile);

    return safeActual < minimum ? minimum : safeActual;
  }

  // ===========================================================================
  // DAILY HELPERS
  // ===========================================================================

  int minimumDailyBillingDays(
    PricingProfile profile,
  ) {
    final configured = profile.dailyPricing.minimumBillingDays;

    return configured > 0 ? configured : 1;
  }

  /// Daily availability is date-based.
  ///
  /// For a selected pickup/return date, the booking availability range should
  /// be normalized by the availability layer to:
  ///
  /// pickupDate 00:00:00
  /// through
  /// returnDate 23:59:59.999
  DateTime dailyAvailabilityStart(DateTime pickupDate) {
    return DateTime(
      pickupDate.year,
      pickupDate.month,
      pickupDate.day,
    );
  }

  DateTime dailyAvailabilityEnd(DateTime returnDate) {
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
  // WEEKEND HELPERS
  // ===========================================================================

  List<int> weekendAllowedWeekdays(
    PricingProfile profile,
  ) {
    final configured = profile.weekendPricing.allowedWeekdays;

    if (configured.isEmpty) {
      return const [DateTime.saturday, DateTime.sunday];
    }

    return List<int>.unmodifiable(configured);
  }

  bool isWeekendEligibleDate(
    PricingProfile profile,
    DateTime date,
  ) {
    return weekendAllowedWeekdays(profile).contains(date.weekday);
  }

  /// Verifies that every selected calendar date is allowed by the weekend
  /// pricing configuration.
  bool isWeekendRangeEligible(
    PricingProfile profile, {
    required DateTime start,
    required DateTime end,
  }) {
    if (end.isBefore(start)) return false;

    var cursor = DateTime(
      start.year,
      start.month,
      start.day,
    );

    final last = DateTime(
      end.year,
      end.month,
      end.day,
    );

    while (!cursor.isAfter(last)) {
      if (!isWeekendEligibleDate(profile, cursor)) {
        return false;
      }

      cursor = cursor.add(
        const Duration(days: 1),
      );
    }

    final totalDays = last.difference(
          DateTime(
            start.year,
            start.month,
            start.day,
          ),
        ).inDays +
        1;

    final config = profile.weekendPricing;

    if (totalDays < config.minimumWeekendDays) {
      return false;
    }

    if (config.maximumWeekendDays > 0 &&
        totalDays > config.maximumWeekendDays) {
      return false;
    }

    return true;
  }

  DateTime weekendAvailabilityStart(DateTime pickupDate) {
    return dailyAvailabilityStart(pickupDate);
  }

  DateTime weekendAvailabilityEnd(DateTime returnDate) {
    return dailyAvailabilityEnd(returnDate);
  }

  // ===========================================================================
  // AVAILABILITY RANGE NORMALIZATION
  // ===========================================================================

  /// Converts a selected rental into the availability interval that should be
  /// sent to AdminAvailabilityService.
  ///
  /// Hourly:
  ///   exact pickup/return timestamps.
  ///
  /// Daily:
  ///   pickup date 00:00 -> return date 23:59:59.999.
  ///
  /// Weekend:
  ///   pickup date 00:00 -> return date 23:59:59.999.
  ///
  /// This method intentionally does not perform the Firestore availability
  /// query. AdminAvailabilityService remains the authority for conflicts.
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
      case RentalType.weekend:
        return DateTimeRangeValue(
          start: dailyAvailabilityStart(pickup),
          end: dailyAvailabilityEnd(returnDateTime),
        );
    }
  }

  // ===========================================================================
  // PRICING VERSION / SNAPSHOT
  // ===========================================================================

  /// Current pricing version saved with a booking.
  int pricingVersion(
    PricingProfile profile,
  ) {
    return profile.pricingVersion;
  }

  /// Builds a serializable configuration snapshot.
  ///
  /// The booking service should save this object into the booking at creation
  /// time. Future pricing edits must never recalculate the old booking.
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
    final package = selectedKmPackageId == null
        ? null
        : profile.getPackage(selectedKmPackageId);

    return {
      'pricingProfileId': profile.id,
      'pricingProfileName': profile.name,
      'pricingVersion': profile.pricingVersion,
      'currency': profile.currency,

      'rentalType': rentalType.value,

      'pickupDateTime': pickup,
      'returnDateTime': returnDateTime,

      'actualKm': actualKm,
      'plannedKm': plannedKm,

      'hourlyRate': profile.hourlyRate,
      'dailyRate': profile.dailyRate,
      'weekendRate': profile.weekendRate,

      'minimumBillingHours':
          profile.hourlyPricing.minimumBillingHours,

      'minimumBillingDays':
          profile.dailyPricing.minimumBillingDays,

      'weekendAllowedWeekdays':
          profile.weekendPricing.allowedWeekdays,

      'selectedKmPackage': package?.toMap(),

      'extraKmRate': profile.extraKmRateFor(
        start: pickup,
        end: returnDateTime,
      ),

      'baseAmount': baseAmount,
      'extraKmAmount': extraKmAmount,
      'addOnAmount': addOnAmount,
      'protectionAmount': protectionAmount,
      'discountAmount': discountAmount,
      'taxAmount': taxAmount,
      'securityDepositAmount': securityDepositAmount,
      'totalAmount': totalAmount,
    };
  }

  /// Builds a separate deposit snapshot.
  ///
  /// Physical/asset security is deliberately stored as an asset, not as money.
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
    return {
      'required': profile.depositConfig.required,
      'type': type.value,
      'amount': amount,
      'status': status,
      'paymentMethod': paymentMethod,
      'transactionId': transactionId,
      'securityAsset': securityAsset,
      'notes': notes,
      'configuredDefaultAmount':
          profile.depositConfig.defaultAmount,
      'minimumAssetValue':
          profile.depositConfig.minimumAssetValue,
    };
  }

  // ===========================================================================
  // SET PRICING
  // ===========================================================================

  /// Compatibility method.
  ///
  /// Accepts pricing already loaded from Firebase.
  /// Does not create or modify dummy pricing.
  void setPricing(
    PricingConfig pricing, {
    String? tenantId,
  }) {
    _service.setPricing(
      pricing,
      tenantId: tenantId?.trim(),
    );
  }

  // ===========================================================================
  // CLEAR
  // ===========================================================================

  void clear() {
    _service.clearCache();
  }
}

/// Normalized availability interval returned by PricingManager.
///
/// Kept as a tiny value object so screens do not have to duplicate the
/// Hourly/Daily/Weekend date normalization logic.
class DateTimeRangeValue {
  final DateTime start;
  final DateTime end;

  const DateTimeRangeValue({
    required this.start,
    required this.end,
  });

  Duration get duration => end.difference(start);
}
