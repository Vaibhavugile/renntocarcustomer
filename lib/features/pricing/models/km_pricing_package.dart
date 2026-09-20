/// Simple KM package used by the rental pricing system.
///
/// One package represents a KM allowance and contains:
///   - included KM
///   - hourly price
///   - daily price
///   - extra KM price
///
/// Weekend / holiday / festival changes are NOT stored here.
/// They belong to PricingProfile.specialRates.
///
/// Important:
/// RentalType intentionally is NOT imported here. This keeps this model
/// independent from PricingProfile and avoids circular dependencies.
/// Rental-type helpers therefore accept String values such as "hourly" and
/// "daily".
class KmPricingPackage {
  final String id;
  final String name;

  /// null or unlimitedKm=true means unlimited KM.
  ///
  /// For daily rental, this amount is included PER RENTAL DAY.
  /// For hourly rental, this amount is the included allowance for
  /// the selected hourly package.
  final int? includedKm;

  final bool unlimitedKm;
  final bool isActive;

  /// Normal hourly package price.
  final double hourlyRate;

  /// Normal daily package price.
  final double dailyRate;

  /// Extra KM charge after the included allowance.
  final double extraKmRate;

  const KmPricingPackage({
    required this.id,
    required this.name,
    this.includedKm,
    this.unlimitedKm = false,
    this.isActive = true,
    this.hourlyRate = 0,
    this.dailyRate = 0,
    this.extraKmRate = 0,
  });

  // ===========================================================================
  // SAFE VALUES
  // ===========================================================================

  /// A safe included-KM value.
  ///
  /// Unlimited packages intentionally return 0 because no extra KM should
  /// ever be calculated for them.
  int get safeIncludedKm {
    if (unlimitedKm) {
      return 0;
    }

    final value = includedKm ?? 0;
    return value < 0 ? 0 : value;
  }

  /// A safe normal hourly price.
  double get safeHourlyRate {
    if (!hourlyRate.isFinite || hourlyRate < 0) {
      return 0;
    }
    return hourlyRate;
  }

  /// A safe normal daily price.
  double get safeDailyRate {
    if (!dailyRate.isFinite || dailyRate < 0) {
      return 0;
    }
    return dailyRate;
  }

  /// Extra KM is never negative or non-finite.
  double get safeExtraKmRate {
    if (!extraKmRate.isFinite || extraKmRate < 0) {
      return 0;
    }
    return extraKmRate;
  }

  // ===========================================================================
  // LEGACY DISPLAY-ONLY COMPATIBILITY GETTERS
  // ===========================================================================
  // Weekend / weekly / monthly are not supported by the new pricing engine.
  // These zero-value getters keep older display code compiling during migration.
  double get weekendRate => 0;
  double get weeklyRate => 0;
  double get monthlyRate => 0;

  // ===========================================================================
  // RENTAL TYPE SUPPORT
  // ===========================================================================

  /// Whether this package can be selected for hourly rental.
  bool get supportsHourly =>
      isActive && safeHourlyRate > 0;

  /// Whether this package can be selected for daily rental.
  bool get supportsDaily =>
      isActive && safeDailyRate > 0;

  /// Whether this package supports the requested rental type.
  ///
  /// Supported values:
  ///   hourly
  ///   daily
  bool supportsRentalType(
    String rentalType,
  ) {
    switch (rentalType.trim().toLowerCase()) {
      case 'hourly':
        return supportsHourly;

      case 'daily':
        return supportsDaily;

      default:
        return false;
    }
  }

  /// Return the normal rate for a rental type.
  ///
  /// Unknown rental types return 0.
  double rateFor(
    String rentalType,
  ) {
    switch (rentalType.trim().toLowerCase()) {
      case 'hourly':
        return safeHourlyRate;

      case 'daily':
        return safeDailyRate;

      default:
        return 0;
    }
  }

  /// Whether a usable normal rate exists.
  bool hasRateFor(
    String rentalType,
  ) {
    return isActive &&
        rateFor(rentalType) > 0;
  }

  // ===========================================================================
  // INCLUDED KM
  // ===========================================================================

  /// Calculate included KM for a daily booking.
  ///
  /// Example:
  ///   package = 250 KM/day
  ///   rental  = 4 days
  ///   included = 1000 KM
  int includedKmForDays(
    int rentalDays,
  ) {
    if (unlimitedKm) {
      return 0;
    }

    final days =
        rentalDays < 1 ? 1 : rentalDays;

    return safeIncludedKm * days;
  }

  /// Calculate extra KM from actual KM.
  ///
  /// For daily rental, pass the number of rental days so the package
  /// allowance is multiplied by the number of days.
  int extraKmFor({
    required int actualKm,
    int rentalDays = 1,
    bool dailyRental = false,
  }) {
    if (unlimitedKm) {
      return 0;
    }

    final actual =
        actualKm < 0 ? 0 : actualKm;

    final included = dailyRental
        ? includedKmForDays(rentalDays)
        : safeIncludedKm;

    final extra =
        actual - included;

    return extra > 0 ? extra : 0;
  }

  /// Calculate the monetary charge for extra KM.
  double extraKmChargeFor({
    required int actualKm,
    int rentalDays = 1,
    bool dailyRental = false,
  }) {
    final extraKm = extraKmFor(
      actualKm: actualKm,
      rentalDays: rentalDays,
      dailyRental: dailyRental,
    );

    return extraKm * safeExtraKmRate;
  }

  // ===========================================================================
  // FIRESTORE -> MODEL
  // ===========================================================================

  factory KmPricingPackage.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    final normalizedId =
        id.trim().isEmpty
            ? 'km_package'
            : id.trim();

    return KmPricingPackage(
      id: normalizedId,
      name: _toStringValue(
        map['name'],
        normalizedId,
      ),
      includedKm: _toNullableInt(
        map['includedKm'] ??
            map['includedKmPerDay'] ??
            map['km'],
      ),
      unlimitedKm: _toBool(
        map['unlimitedKm'],
        false,
      ),
      isActive: _toBool(
        map['isActive'],
        true,
      ),
      hourlyRate: _toDouble(
        map['hourlyRate'],
      ),
      dailyRate: _toDouble(
        map['dailyRate'],
      ),
      extraKmRate: _toDouble(
        map['extraKmRate'],
      ),
    );
  }

  // ===========================================================================
  // MODEL -> FIRESTORE
  // ===========================================================================

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'includedKm': includedKm,
      'unlimitedKm': unlimitedKm,
      'isActive': isActive,
      'hourlyRate': safeHourlyRate,
      'dailyRate': safeDailyRate,
      'extraKmRate': safeExtraKmRate,
    };
  }

  // ===========================================================================
  // COPY WITH
  // ===========================================================================

  KmPricingPackage copyWith({
    String? id,
    String? name,
    int? includedKm,
    bool clearIncludedKm = false,
    bool? unlimitedKm,
    bool? isActive,
    double? hourlyRate,
    double? dailyRate,
    double? extraKmRate,
  }) {
    return KmPricingPackage(
      id: id ?? this.id,
      name: name ?? this.name,
      includedKm: clearIncludedKm
          ? null
          : (includedKm ?? this.includedKm),
      unlimitedKm:
          unlimitedKm ?? this.unlimitedKm,
      isActive:
          isActive ?? this.isActive,
      hourlyRate:
          hourlyRate ?? this.hourlyRate,
      dailyRate:
          dailyRate ?? this.dailyRate,
      extraKmRate:
          extraKmRate ?? this.extraKmRate,
    );
  }

  // ===========================================================================
  // VALIDATION
  // ===========================================================================

  /// Returns validation errors without throwing.
  List<String> validate() {
    final errors = <String>[];

    if (id.trim().isEmpty) {
      errors.add(
        'KM package ID is required.',
      );
    }

    if (name.trim().isEmpty) {
      errors.add(
        'KM package name is required.',
      );
    }

    if (includedKm != null &&
        includedKm! < 0) {
      errors.add(
        'Included KM cannot be negative.',
      );
    }

    if (!hourlyRate.isFinite ||
        hourlyRate < 0) {
      errors.add(
        'Hourly rate cannot be negative.',
      );
    }

    if (!dailyRate.isFinite ||
        dailyRate < 0) {
      errors.add(
        'Daily rate cannot be negative.',
      );
    }

    if (!extraKmRate.isFinite ||
        extraKmRate < 0) {
      errors.add(
        'Extra KM rate cannot be negative.',
      );
    }

    if (isActive &&
        !unlimitedKm &&
        hourlyRate <= 0 &&
        dailyRate <= 0) {
      errors.add(
        'An active KM package must have an hourly or daily rate.',
      );
    }

    return List<String>.unmodifiable(
      errors,
    );
  }

  bool get isValid =>
      validate().isEmpty;

  // ===========================================================================
  // PARSING HELPERS
  // ===========================================================================

  static String _toStringValue(
    dynamic value,
    String fallback,
  ) {
    final text =
        value?.toString().trim() ?? '';

    return text.isEmpty
        ? fallback
        : text;
  }

  static double _toDouble(
    dynamic value,
  ) {
    double result;

    if (value is num) {
      result = value.toDouble();
    } else {
      result = double.tryParse(
            value?.toString().trim() ?? '',
          ) ??
          0;
    }

    if (!result.isFinite) {
      return 0;
    }

    return result;
  }

  static int? _toNullableInt(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toInt();
    }

    final parsed = int.tryParse(
      value.toString().trim(),
    );

    return parsed;
  }

  static bool _toBool(
    dynamic value,
    bool fallback,
  ) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    final normalized =
        value
            ?.toString()
            .trim()
            .toLowerCase();

    if (normalized == 'true' ||
        normalized == '1' ||
        normalized == 'yes') {
      return true;
    }

    if (normalized == 'false' ||
        normalized == '0' ||
        normalized == 'no') {
      return false;
    }

    return fallback;
  }

  // ===========================================================================
  // DEBUG
  // ===========================================================================

  @override
  String toString() {
    return 'KmPricingPackage('
        'id: $id, '
        'name: $name, '
        'includedKm: $includedKm, '
        'unlimitedKm: $unlimitedKm, '
        'isActive: $isActive, '
        'hourlyRate: $hourlyRate, '
        'dailyRate: $dailyRate, '
        'extraKmRate: $extraKmRate'
        ')';
  }
}
