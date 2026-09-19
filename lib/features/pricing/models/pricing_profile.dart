import 'km_pricing_package.dart';



// ============================================================================
// SAFE CONVERSION HELPERS
// ============================================================================

bool _safeBool(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final normalized = value?.toString().trim().toLowerCase();
  if (normalized == 'true' || normalized == 'yes' || normalized == '1') return true;
  if (normalized == 'false' || normalized == 'no' || normalized == '0') return false;
  return fallback;
}

int _safeInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int _positiveInt(dynamic value, {required int fallback}) {
  final parsed = _safeInt(value);
  return parsed > 0 ? parsed : fallback;
}

double _safeDouble(dynamic value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

DateTime _safeDate(dynamic value, {DateTime? fallback}) {
  if (value is DateTime) return value;
  try {
    final dynamic dynamicValue = value;
    final result = dynamicValue.toDate();
    if (result is DateTime) return result;
  } catch (_) {}
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  return parsed ?? fallback ?? DateTime(2000, 1, 1);
}

bool _nestedEnabled(dynamic value) {
  if (value is Map) return _safeBool(value['enabled']);
  return false;
}

double _nestedRate(dynamic value) {
  if (value is Map) return _safeDouble(value['rate']);
  return 0;
}

// ============================================================================
// RENTAL TYPE
// ============================================================================

/// The commercial billing mode selected for a booking.
///
/// Availability and billing are intentionally separate concerns:
/// - hourly uses the exact pickup/return timestamps.
/// - daily blocks the complete selected dates.
/// - weekend blocks the complete selected weekend dates.
/// - special-date rules can enable/disable any of the above.
enum RentalType {
  hourly,
  daily,
  weekend;

  String get value {
    switch (this) {
      case RentalType.hourly:
        return 'hourly';
      case RentalType.daily:
        return 'daily';
      case RentalType.weekend:
        return 'weekend';
    }
  }

  String get label {
    switch (this) {
      case RentalType.hourly:
        return 'Hourly';
      case RentalType.daily:
        return 'Daily';
      case RentalType.weekend:
        return 'Weekend';
    }
  }

  static RentalType? fromString(dynamic value) {
    switch (value?.toString().trim().toLowerCase()) {
      case 'hourly':
        return RentalType.hourly;
      case 'daily':
        return RentalType.daily;
      case 'weekend':
        return RentalType.weekend;
      default:
        return null;
    }
  }
}

// ============================================================================
// RENTAL TYPE PRICING
// ============================================================================

/// Configurable availability/billing rules for one rental type.
///
/// These settings are stored in the pricing profile so the app does not
/// hard-code things such as "minimum 5 hours".
class RentalTypePricing {
  final bool enabled;

  /// Used only by hourly billing. Example: 5.
  final int minimumBillingHours;

  /// Used by daily billing. Example: 1.
  final int minimumBillingDays;

  /// Used by weekend billing when the business wants a minimum/maximum range.
  final int minimumWeekendDays;
  final int maximumWeekendDays;

  /// Weekend dates that are eligible for this rental type.
  /// Defaults to Saturday + Sunday.
  final List<int> allowedWeekdays;

  /// Whether time selection is required by the UI.
  final bool requireTimeSelection;

  /// Optional base rate fallback. Package-specific rates take priority.
  final double rate;

  const RentalTypePricing({
    this.enabled = false,
    this.minimumBillingHours = 1,
    this.minimumBillingDays = 1,
    this.minimumWeekendDays = 2,
    this.maximumWeekendDays = 2,
    this.allowedWeekdays = const [6, 7],
    this.requireTimeSelection = false,
    this.rate = 0,
  });

  factory RentalTypePricing.fromMap(
    dynamic value, {
    bool defaultEnabled = false,
    double defaultRate = 0,
    bool defaultRequireTimeSelection = false,
  }) {
    final map = value is Map
        ? Map<String, dynamic>.from(value)
        : <String, dynamic>{};

    final rawWeekdays = map['allowedWeekdays'];
    final weekdays = rawWeekdays is Iterable
        ? rawWeekdays
            .map((e) => _safeInt(e))
            .where((e) => e >= 1 && e <= 7)
            .toList()
        : const <int>[6, 7];

    return RentalTypePricing(
      enabled: map.containsKey('enabled')
          ? _safeBool(map['enabled'])
          : defaultEnabled,
      minimumBillingHours: _positiveInt(
        map['minimumBillingHours'],
        fallback: 1,
      ),
      minimumBillingDays: _positiveInt(
        map['minimumBillingDays'],
        fallback: 1,
      ),
      minimumWeekendDays: _positiveInt(
        map['minimumWeekendDays'],
        fallback: 2,
      ),
      maximumWeekendDays: _positiveInt(
        map['maximumWeekendDays'],
        fallback: 2,
      ),
      allowedWeekdays:
          weekdays.isEmpty ? const [6, 7] : List.unmodifiable(weekdays),
      requireTimeSelection: map.containsKey('requireTimeSelection')
          ? _safeBool(map['requireTimeSelection'])
          : defaultRequireTimeSelection,
      rate: _safeDouble(
        map['rate'],
        fallback: defaultRate,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'minimumBillingHours': minimumBillingHours,
      'minimumBillingDays': minimumBillingDays,
      'minimumWeekendDays': minimumWeekendDays,
      'maximumWeekendDays': maximumWeekendDays,
      'allowedWeekdays': allowedWeekdays,
      'requireTimeSelection': requireTimeSelection,
      'rate': rate,
    };
  }

  RentalTypePricing copyWith({
    bool? enabled,
    int? minimumBillingHours,
    int? minimumBillingDays,
    int? minimumWeekendDays,
    int? maximumWeekendDays,
    List<int>? allowedWeekdays,
    bool? requireTimeSelection,
    double? rate,
  }) {
    return RentalTypePricing(
      enabled: enabled ?? this.enabled,
      minimumBillingHours:
          minimumBillingHours ?? this.minimumBillingHours,
      minimumBillingDays:
          minimumBillingDays ?? this.minimumBillingDays,
      minimumWeekendDays:
          minimumWeekendDays ?? this.minimumWeekendDays,
      maximumWeekendDays:
          maximumWeekendDays ?? this.maximumWeekendDays,
      allowedWeekdays:
          allowedWeekdays ?? this.allowedWeekdays,
      requireTimeSelection:
          requireTimeSelection ?? this.requireTimeSelection,
      rate: rate ?? this.rate,
    );
  }
}

// ============================================================================
// SPECIAL PRICING RULE
// ============================================================================

/// Date-range override for holidays, festivals, events, peak periods, etc.
///
/// A special rule has higher priority than normal/weekend pricing when it
/// applies to a selected booking date.
class SpecialPricingRule {
  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;

  final bool enabled;

  final bool hourlyEnabled;
  final bool dailyEnabled;
  final bool weekendEnabled;

  final double hourlyRate;
  final double dailyRate;
  final double weekendRate;
  final double extraKmRate;

  final int minimumBillingHours;

  const SpecialPricingRule({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    this.enabled = true,
    this.hourlyEnabled = false,
    this.dailyEnabled = true,
    this.weekendEnabled = true,
    this.hourlyRate = 0,
    this.dailyRate = 0,
    this.weekendRate = 0,
    this.extraKmRate = 0,
    this.minimumBillingHours = 1,
  });

  bool containsDate(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final endExclusive =
        DateTime(endDate.year, endDate.month, endDate.day).add(
      const Duration(days: 1),
    );

    return enabled &&
        !day.isBefore(start) &&
        day.isBefore(endExclusive);
  }

  bool appliesToRange(DateTime start, DateTime end) {
    if (!enabled) return false;

    var cursor = DateTime(start.year, start.month, start.day);
    final last = DateTime(end.year, end.month, end.day);

    while (!cursor.isAfter(last)) {
      if (containsDate(cursor)) return true;
      cursor = cursor.add(const Duration(days: 1));
    }

    return false;
  }

  bool isEnabledFor(RentalType type) {
    switch (type) {
      case RentalType.hourly:
        return hourlyEnabled;
      case RentalType.daily:
        return dailyEnabled;
      case RentalType.weekend:
        return weekendEnabled;
    }
  }

  double rateFor(RentalType type) {
    switch (type) {
      case RentalType.hourly:
        return hourlyRate;
      case RentalType.daily:
        return dailyRate;
      case RentalType.weekend:
        return weekendRate;
    }
  }

  factory SpecialPricingRule.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    return SpecialPricingRule(
      id: id,
      name: map['name']?.toString() ?? id,
      startDate: _safeDate(map['startDate']),
      endDate: _safeDate(
        map['endDate'],
        fallback: _safeDate(map['startDate']),
      ),
      enabled: _safeBool(map['enabled'], fallback: true),
      hourlyEnabled: _safeBool(
        map['hourlyEnabled'] ?? _nestedEnabled(map['hourly']),
      ),
      dailyEnabled: _safeBool(
        map['dailyEnabled'] ?? _nestedEnabled(map['daily']),
        fallback: true,
      ),
      weekendEnabled: _safeBool(
        map['weekendEnabled'] ?? _nestedEnabled(map['weekend']),
        fallback: true,
      ),
      hourlyRate: _safeDouble(
        map['hourlyRate'] ?? _nestedRate(map['hourly']),
      ),
      dailyRate: _safeDouble(
        map['dailyRate'] ?? _nestedRate(map['daily']),
      ),
      weekendRate: _safeDouble(
        map['weekendRate'] ?? _nestedRate(map['weekend']),
      ),
      extraKmRate: _safeDouble(map['extraKmRate']),
      minimumBillingHours: _positiveInt(
        map['minimumBillingHours'],
        fallback: 1,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'startDate': startDate,
      'endDate': endDate,
      'enabled': enabled,
      'hourlyEnabled': hourlyEnabled,
      'dailyEnabled': dailyEnabled,
      'weekendEnabled': weekendEnabled,
      'hourlyRate': hourlyRate,
      'dailyRate': dailyRate,
      'weekendRate': weekendRate,
      'extraKmRate': extraKmRate,
      'minimumBillingHours': minimumBillingHours,
    };
  }
}

// ============================================================================
// DEPOSIT CONFIGURATION
// ============================================================================

enum DepositType {
  none,
  cash,
  online,
  bankTransfer,
  vehicleAsset,
  otherAsset;

  String get value {
    switch (this) {
      case DepositType.none:
        return 'none';
      case DepositType.cash:
        return 'cash';
      case DepositType.online:
        return 'online';
      case DepositType.bankTransfer:
        return 'bankTransfer';
      case DepositType.vehicleAsset:
        return 'vehicleAsset';
      case DepositType.otherAsset:
        return 'otherAsset';
    }
  }

  static DepositType fromString(dynamic value) {
    switch (value?.toString()) {
      case 'cash':
        return DepositType.cash;
      case 'online':
        return DepositType.online;
      case 'bankTransfer':
        return DepositType.bankTransfer;
      case 'vehicleAsset':
        return DepositType.vehicleAsset;
      case 'otherAsset':
        return DepositType.otherAsset;
      case 'none':
      default:
        return DepositType.none;
    }
  }
}

/// Defines what security a rental business accepts.
///
/// Asset deposits are intentionally not converted into cash. The estimated
/// asset value is informational/security value, while monetary deposits are
/// actual collected money.
class DepositConfig {
  final bool required;
  final double defaultAmount;
  final List<DepositType> allowedTypes;
  final double minimumAssetValue;

  const DepositConfig({
    this.required = false,
    this.defaultAmount = 0,
    this.allowedTypes = const [DepositType.cash, DepositType.online],
    this.minimumAssetValue = 0,
  });

  factory DepositConfig.fromMap(dynamic value) {
    final map = value is Map
        ? Map<String, dynamic>.from(value)
        : <String, dynamic>{};

    final rawTypes = map['allowedTypes'];
    final types = rawTypes is Iterable
        ? rawTypes
            .map(DepositType.fromString)
            .toSet()
            .toList()
        : <DepositType>[
            DepositType.cash,
            DepositType.online,
            DepositType.bankTransfer,
            DepositType.vehicleAsset,
            DepositType.otherAsset,
          ];

    return DepositConfig(
      required: _safeBool(map['required']),
      defaultAmount: _safeDouble(
        map['defaultAmount'] ?? map['amount'],
      ),
      allowedTypes:
          types.isEmpty ? const [DepositType.cash] : List.unmodifiable(types),
      minimumAssetValue: _safeDouble(map['minimumAssetValue']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'required': required,
      'defaultAmount': defaultAmount,
      'allowedTypes': allowedTypes.map((e) => e.value).toList(),
      'minimumAssetValue': minimumAssetValue,
    };
  }
}

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


  // ===========================================================================
  // RENTAL TYPE PRICING
  // ===========================================================================

  /// Current configurable rules for Hourly / Daily / Weekend booking.
  final RentalTypePricing hourlyPricing;
  final RentalTypePricing dailyPricing;
  final RentalTypePricing weekendPricing;

  /// Date-range overrides such as festivals, holidays and peak periods.
  final List<SpecialPricingRule> specialPricingRules;

  /// Incremented whenever pricing is changed. A booking must store the
  /// resulting pricing snapshot/version so future changes cannot alter it.
  final int pricingVersion;

  // ===========================================================================
  // DEPOSIT
  // ===========================================================================

  /// Security deposit configuration. Monetary deposits and physical assets
  /// are represented separately.
  final DepositConfig depositConfig;

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

    // Rental type pricing
    required this.hourlyPricing,
    required this.dailyPricing,
    required this.weekendPricing,
    required this.specialPricingRules,
    required this.pricingVersion,

    // Deposit
    required this.depositConfig,

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

  /// Backwards-compatible monetary deposit amount.
  ///
  /// New code should use depositConfig.defaultAmount and depositConfig.allowedTypes.
  double get securityDeposit => depositConfig.defaultAmount;

  /// Returns the normal pricing configuration for a rental type.
  RentalTypePricing rentalPricingFor(RentalType type) {
    switch (type) {
      case RentalType.hourly:
        return hourlyPricing;
      case RentalType.daily:
        return dailyPricing;
      case RentalType.weekend:
        return weekendPricing;
    }
  }

  /// Whether a rental type is currently available without considering
  /// date-range special overrides.
  bool isRentalTypeEnabled(RentalType type) {
    return rentalPricingFor(type).enabled;
  }

  /// Returns the first special rule that applies to the selected range.
  ///
  /// Rules are evaluated in stored order. The pricing admin should keep more
  /// specific/high-priority rules before broad peak-period rules.
  SpecialPricingRule? specialRuleForRange(
    DateTime start,
    DateTime end,
  ) {
    for (final rule in specialPricingRules) {
      if (rule.appliesToRange(start, end)) return rule;
    }
    return null;
  }

  /// Returns the rental types allowed for a date range after applying special
  /// pricing overrides.
  List<RentalType> availableRentalTypesForRange(
    DateTime start,
    DateTime end,
  ) {
    final result = <RentalType>[];

    for (final type in RentalType.values) {
      if (!isRentalTypeEnabled(type)) continue;

      final rule = specialRuleForRange(start, end);
      if (rule != null && !rule.isEnabledFor(type)) continue;

      result.add(type);
    }

    return result;
  }

  /// Returns the applicable base rate. Package-specific rates should be
  /// applied by PricingEngine after this profile-level fallback.
  double baseRateFor(
    RentalType type, {
    DateTime? start,
    DateTime? end,
  }) {
    if (start != null && end != null) {
      final rule = specialRuleForRange(start, end);
      if (rule != null && rule.isEnabledFor(type)) {
        final specialRate = rule.rateFor(type);
        if (specialRate > 0) return specialRate;
      }
    }

    final config = rentalPricingFor(type);
    if (config.rate > 0) return config.rate;

    switch (type) {
      case RentalType.hourly:
        return hourlyRate;
      case RentalType.daily:
        return dailyRate;
      case RentalType.weekend:
        return weekendRate;
    }
  }

  /// Extra KM rate after applying a special date override.
  double extraKmRateFor({
    DateTime? start,
    DateTime? end,
  }) {
    if (start != null && end != null) {
      final rule = specialRuleForRange(start, end);
      if (rule != null && rule.extraKmRate > 0) {
        return rule.extraKmRate;
      }
    }
    return extraKmRate;
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
      // RENTAL TYPE PRICING
      // -----------------------------------------------------------------------

      hourlyPricing: RentalTypePricing.fromMap(
        (map['hourlyPricing'] ?? _rentalTypeMap(map, 'hourly')),
        defaultEnabled: _legacyRentalTypeEnabled(
          map,
          RentalType.hourly,
        ),
        defaultRate: _toDouble(map['hourlyRate']),
        defaultRequireTimeSelection: true,
      ),

      dailyPricing: RentalTypePricing.fromMap(
        (map['dailyPricing'] ?? _rentalTypeMap(map, 'daily')),
        defaultEnabled: _legacyRentalTypeEnabled(
          map,
          RentalType.daily,
        ),
        defaultRate: _toDouble(map['dailyRate']),
      ),

      weekendPricing: RentalTypePricing.fromMap(
        (map['weekendPricing'] ?? _rentalTypeMap(map, 'weekend')),
        defaultEnabled: _legacyRentalTypeEnabled(
          map,
          RentalType.weekend,
        ),
        defaultRate: _toDouble(map['weekendRate']),
      ),

      specialPricingRules: _toSpecialRuleList(
        map['specialPricingRules'] ?? map['specialDates'],
      ),

      pricingVersion: _toInt(map['pricingVersion']),

      // -----------------------------------------------------------------------
      // DEPOSIT
      // -----------------------------------------------------------------------

      depositConfig: DepositConfig.fromMap(
        map['depositConfig'] ??
            {
              'required': _toDouble(map['securityDeposit']) > 0,
              'defaultAmount': map['securityDeposit'],
              'allowedTypes': ['cash', 'online'],
            },
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
      // RENTAL TYPE PRICING
      // -----------------------------------------------------------------------

      'hourlyPricing': hourlyPricing.toMap(),
      'dailyPricing': dailyPricing.toMap(),
      'weekendPricing': weekendPricing.toMap(),

      'specialPricingRules': specialPricingRules
          .map((rule) => rule.toMap())
          .toList(),

      'pricingVersion': pricingVersion,

      // -----------------------------------------------------------------------
      // DEPOSIT
      // -----------------------------------------------------------------------

      'depositConfig': depositConfig.toMap(),

      // Backwards compatibility for existing admin/customer code.
      'securityDeposit': depositConfig.defaultAmount,

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
    RentalTypePricing? hourlyPricing,
    RentalTypePricing? dailyPricing,
    RentalTypePricing? weekendPricing,
    List<SpecialPricingRule>? specialPricingRules,
    int? pricingVersion,
    DepositConfig? depositConfig,
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

      hourlyPricing:
          hourlyPricing ?? this.hourlyPricing,

      dailyPricing:
          dailyPricing ?? this.dailyPricing,

      weekendPricing:
          weekendPricing ?? this.weekendPricing,

      specialPricingRules:
          specialPricingRules ?? this.specialPricingRules,

      pricingVersion:
          pricingVersion ?? this.pricingVersion,

      depositConfig: securityDeposit != null
          ? DepositConfig(
              required: this.depositConfig.required,
              defaultAmount: securityDeposit,
              allowedTypes: this.depositConfig.allowedTypes,
              minimumAssetValue: this.depositConfig.minimumAssetValue,
            )
          : (depositConfig ?? this.depositConfig),

      isActive:
          isActive ?? this.isActive,
    );
  }

  // ===========================================================================
  // CONVERSION HELPERS
  // ===========================================================================


  static dynamic _rentalTypeMap(
    Map<String, dynamic> map,
    String key,
  ) {
    final raw = map['rentalTypes'];
    if (raw is Map) return raw[key];
    return null;
  }

  static bool _legacyRentalTypeEnabled(
    Map<String, dynamic> map,
    RentalType type,
  ) {
    final raw = map['rentalTypes'];
    if (raw is Map) {
      final key = type.value;
      final entry = raw[key];
      if (entry is Map && entry.containsKey('enabled')) {
        return _safeBool(entry['enabled']);
      }
    }

    // Existing profiles historically had rates without an enabled flag.
    // Treat a positive legacy rate as enabled so existing data keeps working.
    switch (type) {
      case RentalType.hourly:
        return _toDouble(map['hourlyRate']) > 0;
      case RentalType.daily:
        return _toDouble(map['dailyRate']) > 0;
      case RentalType.weekend:
        return _toDouble(map['weekendRate']) > 0;
    }
  }

  static List<SpecialPricingRule> _toSpecialRuleList(
    dynamic value,
  ) {
    if (value is! Iterable) return [];

    final rules = <SpecialPricingRule>[];
    int index = 0;

    for (final item in value) {
      if (item is Map) {
        final map = Map<String, dynamic>.from(item);
        rules.add(
          SpecialPricingRule.fromMap(
            map['id']?.toString() ?? 'special_$index',
            map,
          ),
        );
      }
      index++;
    }

    return rules;
  }

  static bool _safeBool(
    dynamic value, {
    bool fallback = false,
  }) {
    if (value is bool) return value;
    if (value is num) return value != 0;

    final normalized = value?.toString().trim().toLowerCase();
    if (normalized == 'true' || normalized == 'yes' || normalized == '1') {
      return true;
    }
    if (normalized == 'false' || normalized == 'no' || normalized == '0') {
      return false;
    }
    return fallback;
  }

  static int _safeInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _positiveInt(
    dynamic value, {
    required int fallback,
  }) {
    final parsed = _safeInt(value);
    return parsed > 0 ? parsed : fallback;
  }

  static double _safeDouble(
    dynamic value, {
    double fallback = 0,
  }) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static DateTime _safeDate(
    dynamic value, {
    DateTime? fallback,
  }) {
    if (value is DateTime) return value;

    // Supports Firestore Timestamp without importing cloud_firestore into
    // this pure model file: Timestamp exposes toDate() dynamically.
    try {
      final dynamic toDate = value;
      final result = toDate.toDate();
      if (result is DateTime) return result;
    } catch (_) {
      // Fall through to string parsing.
    }

    final parsed = DateTime.tryParse(value?.toString() ?? '');
    return parsed ?? fallback ?? DateTime(2000, 1, 1);
  }

  static bool _nestedEnabled(dynamic value) {
    if (value is Map) {
      return _safeBool(value['enabled']);
    }
    return false;
  }

  static double _nestedRate(dynamic value) {
    if (value is Map) {
      return _safeDouble(value['rate']);
    }
    return 0;
  }

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