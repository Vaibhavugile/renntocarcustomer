import 'km_pricing_package.dart';

class PricingProfile {
  // ===========================================================================
  // IDENTITY
  // ===========================================================================

  /// Firestore pricing profile document ID.
  final String id;

  /// Tenant that owns this pricing profile.
  final String tenantId;

  /// Vehicle this pricing profile belongs to.
  ///
  /// Example:
  /// car_001
  final String vehicleId;

  /// Human-readable pricing profile name.
  ///
  /// Example:
  /// Hyundai Creta Pricing
  final String name;

  /// Currency used by this pricing profile.
  ///
  /// Example:
  /// INR
  final String currency;

  // ===========================================================================
  // BASIC PRICING
  // ===========================================================================
  //
  // These fields are retained for backwards compatibility.
  //
  // When kmPricingMode == package:
  // the selected KmPricingPackage rates should be used instead.
  //

  final double hourlyRate;

  final double dailyRate;

  final double weekendRate;

  final double weeklyRate;

  final double monthlyRate;

  // ===========================================================================
  // KM SETTINGS
  // ===========================================================================
  //
  // Previous KM pricing system is retained.
  //

  final KmPricingMode kmPricingMode;

  /// Previous included KM per rental day.
  final int includedKmPerDay;

  /// Previous selectable KM options.
  ///
  /// Example:
  /// [150, 250, 500, 750, 1000]
  final List<int> kmOptions;

  /// Previous direct per-KM pricing.
  final double perKmRate;

  /// Previous generic extra KM rate.
  ///
  /// For package mode, the package's own extraKmRate
  /// takes priority.
  final double extraKmRate;

  // ===========================================================================
  // KM PACKAGE SYSTEM
  // ===========================================================================
  //
  // Every package can have its own:
  //
  // - Included KM
  // - Hourly rate
  // - Daily rate
  // - Weekend rate
  // - Weekly rate
  // - Monthly rate
  // - Extra KM rate
  //
  // Example:
  //
  // 150 KM package
  // 250 KM package
  // 500 KM package
  // 750 KM package
  // 1000 KM package
  // 1500 KM package
  // Unlimited package
  //

  final List<KmPricingPackage> kmPackages;

  // ===========================================================================
  // UNLIMITED KM
  // ===========================================================================
  //
  // Previous unlimited system is retained.
  //
  // For the package system, unlimited can also be represented
  // using a KmPricingPackage with unlimitedKm == true.
  //

  final bool unlimitedKmEnabled;

  final double unlimitedKmSurcharge;

  // ===========================================================================
  // TIME SETTINGS
  // ===========================================================================

  /// Grace period before late/extension charges begin.
  final int gracePeriodMinutes;

  /// Charge for an additional rental hour.
  final double extraHourRate;

  /// Charge for an additional rental day.
  final double extraDayRate;

  /// Charge applied for late return.
  final double lateReturnRate;

  // ===========================================================================
  // DEPOSIT
  // ===========================================================================

  /// Security deposit required for this vehicle.
  final double securityDeposit;

  // ===========================================================================
  // STATUS
  // ===========================================================================

  final bool isActive;

  // ===========================================================================
  // CONSTRUCTOR
  // ===========================================================================

  const PricingProfile({
    required this.id,

    // Identity
    required this.tenantId,
    required this.vehicleId,
    required this.name,
    required this.currency,

    // Basic pricing
    required this.hourlyRate,
    required this.dailyRate,
    required this.weekendRate,
    required this.weeklyRate,
    required this.monthlyRate,

    // Previous KM system
    required this.kmPricingMode,
    required this.includedKmPerDay,
    required this.kmOptions,
    required this.perKmRate,
    required this.extraKmRate,

    // Package system
    required this.kmPackages,

    // Unlimited
    required this.unlimitedKmEnabled,
    required this.unlimitedKmSurcharge,

    // Time
    required this.gracePeriodMinutes,
    required this.extraHourRate,
    required this.extraDayRate,
    required this.lateReturnRate,

    // Deposit
    required this.securityDeposit,

    // Status
    required this.isActive,
  });

  // ===========================================================================
  // PACKAGE HELPERS
  // ===========================================================================

  /// Find package by ID.
  KmPricingPackage? getPackage(String packageId) {
    try {
      return kmPackages.firstWhere(
        (package) => package.id == packageId,
      );
    } catch (_) {
      return null;
    }
  }

  /// Find package by included KM.
  KmPricingPackage? getPackageByKm(int km) {
    try {
      return kmPackages.firstWhere(
        (package) =>
            !package.unlimitedKm &&
            package.includedKm == km,
      );
    } catch (_) {
      return null;
    }
  }

  /// Get unlimited package.
  KmPricingPackage? getUnlimitedPackage() {
    try {
      return kmPackages.firstWhere(
        (package) => package.unlimitedKm,
      );
    } catch (_) {
      return null;
    }
  }

  // ===========================================================================
  // FIREBASE → MODEL
  // ===========================================================================

  factory PricingProfile.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    return PricingProfile(
      id: id,

      // -----------------------------------------------------------------------
      // IDENTITY
      // -----------------------------------------------------------------------

      tenantId:
          map['tenantId']?.toString() ?? '',

      vehicleId:
          map['vehicleId']?.toString() ?? '',

      name:
          map['name']?.toString() ?? '',

      currency:
          map['currency']?.toString() ?? 'INR',

      // -----------------------------------------------------------------------
      // BASIC PRICING
      // -----------------------------------------------------------------------

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

      // -----------------------------------------------------------------------
      // KM SETTINGS
      // -----------------------------------------------------------------------

      kmPricingMode: KmPricingMode.fromString(
        map['kmPricingMode'],
      ),

      includedKmPerDay: _toInt(
        map['includedKmPerDay'],
      ),

      kmOptions: _toIntList(
        map['kmOptions'],
      ),

      perKmRate: _toDouble(
        map['perKmRate'],
      ),

      extraKmRate: _toDouble(
        map['extraKmRate'],
      ),

      // -----------------------------------------------------------------------
      // KM PACKAGES
      // -----------------------------------------------------------------------

      kmPackages: _toPackageList(
        map['kmPackages'],
      ),

      // -----------------------------------------------------------------------
      // UNLIMITED KM
      // -----------------------------------------------------------------------

      unlimitedKmEnabled:
          map['unlimitedKmEnabled'] ?? false,

      unlimitedKmSurcharge: _toDouble(
        map['unlimitedKmSurcharge'],
      ),

      // -----------------------------------------------------------------------
      // TIME SETTINGS
      // -----------------------------------------------------------------------

      gracePeriodMinutes: _toInt(
        map['gracePeriodMinutes'],
      ),

      extraHourRate: _toDouble(
        map['extraHourRate'],
      ),

      extraDayRate: _toDouble(
        map['extraDayRate'],
      ),

      lateReturnRate: _toDouble(
        map['lateReturnRate'],
      ),

      // -----------------------------------------------------------------------
      // DEPOSIT
      // -----------------------------------------------------------------------

      securityDeposit: _toDouble(
        map['securityDeposit'],
      ),

      // -----------------------------------------------------------------------
      // STATUS
      // -----------------------------------------------------------------------

      isActive:
          map['isActive'] ?? false,
    );
  }

  // ===========================================================================
  // MODEL → FIREBASE
  // ===========================================================================

  Map<String, dynamic> toMap() {
    return {
      // -----------------------------------------------------------------------
      // IDENTITY
      // -----------------------------------------------------------------------

      'tenantId': tenantId,

      'vehicleId': vehicleId,

      'name': name,

      'currency': currency,

      // -----------------------------------------------------------------------
      // BASIC PRICING
      // -----------------------------------------------------------------------

      'hourlyRate': hourlyRate,

      'dailyRate': dailyRate,

      'weekendRate': weekendRate,

      'weeklyRate': weeklyRate,

      'monthlyRate': monthlyRate,

      // -----------------------------------------------------------------------
      // KM SETTINGS
      // -----------------------------------------------------------------------

      'kmPricingMode': kmPricingMode.value,

      'includedKmPerDay': includedKmPerDay,

      'kmOptions': kmOptions,

      'perKmRate': perKmRate,

      'extraKmRate': extraKmRate,

      // -----------------------------------------------------------------------
      // KM PACKAGES
      // -----------------------------------------------------------------------

      'kmPackages': kmPackages
          .map(
            (package) => package.toMap(),
          )
          .toList(),

      // -----------------------------------------------------------------------
      // UNLIMITED KM
      // -----------------------------------------------------------------------

      'unlimitedKmEnabled':
          unlimitedKmEnabled,

      'unlimitedKmSurcharge':
          unlimitedKmSurcharge,

      // -----------------------------------------------------------------------
      // TIME SETTINGS
      // -----------------------------------------------------------------------

      'gracePeriodMinutes':
          gracePeriodMinutes,

      'extraHourRate':
          extraHourRate,

      'extraDayRate':
          extraDayRate,

      'lateReturnRate':
          lateReturnRate,

      // -----------------------------------------------------------------------
      // DEPOSIT
      // -----------------------------------------------------------------------

      'securityDeposit':
          securityDeposit,

      // -----------------------------------------------------------------------
      // STATUS
      // -----------------------------------------------------------------------

      'isActive':
          isActive,
    };
  }

  // ===========================================================================
  // COPY WITH
  // ===========================================================================

  PricingProfile copyWith({
    String? id,
    String? tenantId,
    String? vehicleId,
    String? name,
    String? currency,
    double? hourlyRate,
    double? dailyRate,
    double? weekendRate,
    double? weeklyRate,
    double? monthlyRate,
    KmPricingMode? kmPricingMode,
    int? includedKmPerDay,
    List<int>? kmOptions,
    double? perKmRate,
    double? extraKmRate,
    List<KmPricingPackage>? kmPackages,
    bool? unlimitedKmEnabled,
    double? unlimitedKmSurcharge,
    int? gracePeriodMinutes,
    double? extraHourRate,
    double? extraDayRate,
    double? lateReturnRate,
    double? securityDeposit,
    bool? isActive,
  }) {
    return PricingProfile(
      id: id ?? this.id,

      tenantId:
          tenantId ?? this.tenantId,

      vehicleId:
          vehicleId ?? this.vehicleId,

      name:
          name ?? this.name,

      currency:
          currency ?? this.currency,

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

      kmPricingMode:
          kmPricingMode ?? this.kmPricingMode,

      includedKmPerDay:
          includedKmPerDay ?? this.includedKmPerDay,

      kmOptions:
          kmOptions ?? this.kmOptions,

      perKmRate:
          perKmRate ?? this.perKmRate,

      extraKmRate:
          extraKmRate ?? this.extraKmRate,

      kmPackages:
          kmPackages ?? this.kmPackages,

      unlimitedKmEnabled:
          unlimitedKmEnabled ??
          this.unlimitedKmEnabled,

      unlimitedKmSurcharge:
          unlimitedKmSurcharge ??
          this.unlimitedKmSurcharge,

      gracePeriodMinutes:
          gracePeriodMinutes ??
          this.gracePeriodMinutes,

      extraHourRate:
          extraHourRate ??
          this.extraHourRate,

      extraDayRate:
          extraDayRate ??
          this.extraDayRate,

      lateReturnRate:
          lateReturnRate ??
          this.lateReturnRate,

      securityDeposit:
          securityDeposit ??
          this.securityDeposit,

      isActive:
          isActive ?? this.isActive,
    );
  }

  // ===========================================================================
  // CONVERSION HELPERS
  // ===========================================================================

  static double _toDouble(
    dynamic value,
  ) {
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
  ) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  static List<int> _toIntList(
    dynamic value,
  ) {
    if (value is Iterable) {
      return value
          .map(
            (item) => _toInt(item),
          )
          .where(
            (value) => value > 0,
          )
          .toList();
    }

    return [];
  }

  static List<KmPricingPackage> _toPackageList(
    dynamic value,
  ) {
    if (value is! Iterable) {
      return [];
    }

    final packages =
        <KmPricingPackage>[];

    int index = 0;

    for (final item in value) {
      if (item is Map) {
        final map =
            Map<String, dynamic>.from(item);

        packages.add(
          KmPricingPackage.fromMap(
            map['id']?.toString() ??
                'package_$index',
            map,
          ),
        );
      }

      index++;
    }

    return packages;
  }
}

// ============================================================================
// KM PRICING MODE
// ============================================================================

enum KmPricingMode {
  included,
  perKm,
  unlimited,
  package,
  slabs;

  // ---------------------------------------------------------------------------
  // ENUM → FIREBASE STRING
  // ---------------------------------------------------------------------------

  String get value {
    switch (this) {
      case KmPricingMode.included:
        return 'included';

      case KmPricingMode.perKm:
        return 'perKm';

      case KmPricingMode.unlimited:
        return 'unlimited';

      case KmPricingMode.package:
        return 'package';

      case KmPricingMode.slabs:
        return 'slabs';
    }
  }

  // ---------------------------------------------------------------------------
  // FIREBASE STRING → ENUM
  // ---------------------------------------------------------------------------

  static KmPricingMode fromString(
    dynamic value,
  ) {
    switch (value?.toString()) {
      case 'perKm':
        return KmPricingMode.perKm;

      case 'unlimited':
        return KmPricingMode.unlimited;

      case 'package':
        return KmPricingMode.package;

      case 'slabs':
        return KmPricingMode.slabs;

      case 'included':
      default:
        return KmPricingMode.included;
    }
  }
}