enum KmPackageRentalType {
  hourly,
  daily,
  weekend,
  weekly,
  monthly,
}

class KmPricingPackage {
  final String id;
  final String name;

  /// KM included in this package.
  /// null = unlimited package.
  final int? includedKm;

  /// Whether this is an unlimited KM package.
  final bool unlimitedKm;

  /// Whether this package is active and selectable.
  final bool isActive;

  /// Rental types supported by this package.
  ///
  /// Empty means backward-compatible/default behavior:
  /// hourly, daily, weekend, weekly and monthly can be considered.
  final List<KmPackageRentalType> supportedRentalTypes;

  // ---------------------------------------------------------------------------
  // DURATION PRICES
  // ---------------------------------------------------------------------------

  final double hourlyRate;
  final double dailyRate;
  final double weekendRate;
  final double weeklyRate;
  final double monthlyRate;

  // ---------------------------------------------------------------------------
  // BILLING RULES
  // ---------------------------------------------------------------------------

  /// Minimum billable hours when this package is used for hourly rental.
  ///
  /// Example:
  /// actual = 3 hours
  /// minimum = 5
  /// billable = 5
  final int minimumBillingHours;

  /// Minimum billable days when this package is used for daily rental.
  final int minimumBillingDays;

  /// Minimum number of selected days for a weekend rental.
  final int minimumWeekendDays;

  /// Maximum number of selected days for a weekend rental.
  ///
  /// 0 = no maximum.
  final int maximumWeekendDays;

  // ---------------------------------------------------------------------------
  // EXTRA KM
  // ---------------------------------------------------------------------------

  /// Amount charged for every KM above includedKm.
  final double extraKmRate;

  const KmPricingPackage({
    required this.id,
    required this.name,
    required this.includedKm,
    required this.unlimitedKm,
    this.isActive = true,
    this.supportedRentalTypes = const [],
    required this.hourlyRate,
    required this.dailyRate,
    required this.weekendRate,
    required this.weeklyRate,
    required this.monthlyRate,
    this.minimumBillingHours = 1,
    this.minimumBillingDays = 1,
    this.minimumWeekendDays = 1,
    this.maximumWeekendDays = 0,
    required this.extraKmRate,
  });

  // ===========================================================================
  // RENTAL TYPE HELPERS
  // ===========================================================================

  bool supportsRentalType(KmPackageRentalType type) {
    if (!isActive) {
      return false;
    }

    // Empty list preserves compatibility with existing Firebase packages.
    if (supportedRentalTypes.isEmpty) {
      return true;
    }

    return supportedRentalTypes.contains(type);
  }

  double rateFor(KmPackageRentalType type) {
    switch (type) {
      case KmPackageRentalType.hourly:
        return hourlyRate;
      case KmPackageRentalType.daily:
        return dailyRate;
      case KmPackageRentalType.weekend:
        return weekendRate;
      case KmPackageRentalType.weekly:
        return weeklyRate;
      case KmPackageRentalType.monthly:
        return monthlyRate;
    }
  }

  bool hasRateFor(KmPackageRentalType type) {
    return supportsRentalType(type) && rateFor(type) > 0;
  }

  int get safeMinimumBillingHours {
    return minimumBillingHours > 0 ? minimumBillingHours : 1;
  }

  int get safeMinimumBillingDays {
    return minimumBillingDays > 0 ? minimumBillingDays : 1;
  }

  int get safeMinimumWeekendDays {
    return minimumWeekendDays > 0 ? minimumWeekendDays : 1;
  }

  int get safeMaximumWeekendDays {
    return maximumWeekendDays > 0 ? maximumWeekendDays : 0;
  }

  int billableHourlyHours(int actualHours) {
    final safeActualHours = actualHours < 0 ? 0 : actualHours;

    return safeActualHours < safeMinimumBillingHours
        ? safeMinimumBillingHours
        : safeActualHours;
  }

  int billableDailyDays(int actualDays) {
    final safeActualDays = actualDays < 0 ? 0 : actualDays;

    return safeActualDays < safeMinimumBillingDays
        ? safeMinimumBillingDays
        : safeActualDays;
  }

  bool isWeekendDayCountAllowed(int days) {
    if (days < safeMinimumWeekendDays) {
      return false;
    }

    if (safeMaximumWeekendDays > 0 &&
        days > safeMaximumWeekendDays) {
      return false;
    }

    return true;
  }

  // ===========================================================================
  // FIREBASE → MODEL
  // ===========================================================================

  factory KmPricingPackage.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    return KmPricingPackage(
      id: id,
      name: map['name']?.toString() ?? '',
      includedKm: _toNullableInt(map['includedKm']),
      unlimitedKm: _toBool(map['unlimitedKm'], false),

      isActive: _toBool(
        map['isActive'],
        true,
      ),

      supportedRentalTypes:
          _parseSupportedRentalTypes(
        map['supportedRentalTypes'] ??
            map['rentalTypes'],
      ),

      hourlyRate: _toDouble(
        map['hourlyRate'],
      ),
      dailyRate: _toDouble(
        map['dailyRate'],
      ),
      weekendRate: _toDouble(
        map['weekendRate'],
      ),
      weeklyRate: _toDouble(
        map['weeklyRate'],
      ),
      monthlyRate: _toDouble(
        map['monthlyRate'],
      ),

      minimumBillingHours: _toInt(
        map['minimumBillingHours'],
        1,
      ),

      minimumBillingDays: _toInt(
        map['minimumBillingDays'],
        1,
      ),

      minimumWeekendDays: _toInt(
        map['minimumWeekendDays'],
        1,
      ),

      maximumWeekendDays: _toInt(
        map['maximumWeekendDays'],
        0,
      ),

      extraKmRate: _toDouble(
        map['extraKmRate'],
      ),
    );
  }

  // ===========================================================================
  // MODEL → FIREBASE
  // ===========================================================================

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'includedKm': includedKm,
      'unlimitedKm': unlimitedKm,

      'isActive': isActive,

      'supportedRentalTypes':
          supportedRentalTypes
              .map(
                (type) => type.name,
              )
              .toList(),

      'hourlyRate': hourlyRate,
      'dailyRate': dailyRate,
      'weekendRate': weekendRate,
      'weeklyRate': weeklyRate,
      'monthlyRate': monthlyRate,

      'minimumBillingHours':
          safeMinimumBillingHours,

      'minimumBillingDays':
          safeMinimumBillingDays,

      'minimumWeekendDays':
          safeMinimumWeekendDays,

      'maximumWeekendDays':
          safeMaximumWeekendDays,

      'extraKmRate': extraKmRate,
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
    List<KmPackageRentalType>? supportedRentalTypes,
    double? hourlyRate,
    double? dailyRate,
    double? weekendRate,
    double? weeklyRate,
    double? monthlyRate,
    int? minimumBillingHours,
    int? minimumBillingDays,
    int? minimumWeekendDays,
    int? maximumWeekendDays,
    double? extraKmRate,
  }) {
    return KmPricingPackage(
      id: id ?? this.id,
      name: name ?? this.name,
      includedKm:
          clearIncludedKm
              ? null
              : includedKm ?? this.includedKm,
      unlimitedKm:
          unlimitedKm ?? this.unlimitedKm,
      isActive:
          isActive ?? this.isActive,
      supportedRentalTypes:
          supportedRentalTypes ??
              this.supportedRentalTypes,
      hourlyRate:
          hourlyRate ?? this.hourlyRate,
      dailyRate:
          dailyRate ?? this.dailyRate,
      weekendRate:
          weekendRate ?? this.weekendRate,
      weeklyRate:
          weeklyRate ?? this.weeklyRate,
      monthlyRate:
          monthlyRate ?? this.monthlyRate,
      minimumBillingHours:
          minimumBillingHours ??
              this.minimumBillingHours,
      minimumBillingDays:
          minimumBillingDays ??
              this.minimumBillingDays,
      minimumWeekendDays:
          minimumWeekendDays ??
              this.minimumWeekendDays,
      maximumWeekendDays:
          maximumWeekendDays ??
              this.maximumWeekendDays,
      extraKmRate:
          extraKmRate ?? this.extraKmRate,
    );
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  static int _toInt(
    dynamic value,
    int fallback,
  ) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        fallback;
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

    return int.tryParse(
      value.toString(),
    );
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
        value?.toString().trim().toLowerCase();

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

  static List<KmPackageRentalType>
      _parseSupportedRentalTypes(
    dynamic value,
  ) {
    if (value is! List) {
      return const [];
    }

    final result =
        <KmPackageRentalType>[];

    for (final item in value) {
      final normalized =
          item
              .toString()
              .trim()
              .toLowerCase();

      switch (normalized) {
        case 'hourly':
          result.add(
            KmPackageRentalType.hourly,
          );
          break;

        case 'daily':
          result.add(
            KmPackageRentalType.daily,
          );
          break;

        case 'weekend':
          result.add(
            KmPackageRentalType.weekend,
          );
          break;

        case 'weekly':
          result.add(
            KmPackageRentalType.weekly,
          );
          break;

        case 'monthly':
          result.add(
            KmPackageRentalType.monthly,
          );
          break;
      }
    }

    return List<KmPackageRentalType>.unmodifiable(
      result,
    );
  }

  @override
  String toString() {
    return 'KmPricingPackage('
        'id: $id, '
        'name: $name, '
        'includedKm: $includedKm, '
        'unlimitedKm: $unlimitedKm, '
        'isActive: $isActive, '
        'supportedRentalTypes: $supportedRentalTypes, '
        'hourlyRate: $hourlyRate, '
        'dailyRate: $dailyRate, '
        'weekendRate: $weekendRate, '
        'weeklyRate: $weeklyRate, '
        'monthlyRate: $monthlyRate, '
        'extraKmRate: $extraKmRate'
        ')';
  }
}
