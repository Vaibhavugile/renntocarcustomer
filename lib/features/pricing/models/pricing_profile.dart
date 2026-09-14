import 'km_pricing_package.dart';

class PricingProfile {
  final String id;

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
  // NEW KM PACKAGE SYSTEM
  // ===========================================================================
  //
  // Every package has its own:
  //
  // 150 KM
  //   Hourly
  //   Daily
  //   Weekend
  //   Weekly
  //   Monthly
  //   Extra KM
  //
  // 250 KM
  //   Hourly
  //   Daily
  //   Weekend
  //   Weekly
  //   Monthly
  //   Extra KM
  //
  // etc.
  //

  final List<KmPricingPackage> kmPackages;

  // ===========================================================================
  // UNLIMITED KM
  // ===========================================================================
  //
  // Previous unlimited system is retained.
  //
  // For the new package system, unlimited can also simply be represented
  // as a KmPricingPackage with unlimitedKm = true.
  //

  final bool unlimitedKmEnabled;

  final double unlimitedKmSurcharge;

  // ===========================================================================
  // TIME SETTINGS
  // ===========================================================================

  final int gracePeriodMinutes;

  final double extraHourRate;

  final double extraDayRate;

  final double lateReturnRate;

  // ===========================================================================
  // DEPOSIT
  // ===========================================================================

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

    // NEW package system
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
      // NEW KM PACKAGES
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

      isActive: map['isActive'] ?? false,
    );
  }

  // ===========================================================================
  // MODEL → FIREBASE
  // ===========================================================================

  Map<String, dynamic> toMap() {
    return {
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
      // NEW KM PACKAGES
      // -----------------------------------------------------------------------

      'kmPackages': kmPackages
          .map(
            (package) => package.toMap(),
          )
          .toList(),

      // -----------------------------------------------------------------------
      // UNLIMITED KM
      // -----------------------------------------------------------------------

      'unlimitedKmEnabled': unlimitedKmEnabled,

      'unlimitedKmSurcharge': unlimitedKmSurcharge,

      // -----------------------------------------------------------------------
      // TIME SETTINGS
      // -----------------------------------------------------------------------

      'gracePeriodMinutes': gracePeriodMinutes,

      'extraHourRate': extraHourRate,

      'extraDayRate': extraDayRate,

      'lateReturnRate': lateReturnRate,

      // -----------------------------------------------------------------------
      // DEPOSIT
      // -----------------------------------------------------------------------

      'securityDeposit': securityDeposit,

      // -----------------------------------------------------------------------
      // STATUS
      // -----------------------------------------------------------------------

      'isActive': isActive,
    };
  }

  // ===========================================================================
  // HELPERS
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
    if (value is List) {
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
    if (value is! List) {
      return [];
    }

    final packages = <KmPricingPackage>[];

    for (int index = 0; index < value.length; index++) {
      final item = value[index];

      if (item is Map) {
        final map = Map<String, dynamic>.from(item);

        packages.add(
          KmPricingPackage.fromMap(
            map['id']?.toString() ??
                'package_$index',
            map,
          ),
        );
      }
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