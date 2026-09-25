import 'km_pricing_package.dart';

/// Rental modes supported by the car-rental business.
///
/// Only:
///   1. hourly
///   2. daily
enum RentalType {
  hourly,
  daily;

  String get value => name;

  String get label {
    switch (this) {
      case RentalType.hourly:
        return 'Hourly';
      case RentalType.daily:
        return 'Daily';
    }
  }

  static RentalType? fromString(dynamic value) {
    switch (value?.toString().trim().toLowerCase()) {
      case 'hourly':
        return RentalType.hourly;
      case 'daily':
        return RentalType.daily;
      default:
        return null;
    }
  }
}

/// A simple date-range pricing override.
///
/// Example:
///   Diwali: 2026-10-18 -> 2026-10-25
///   daily package pkg_150 -> 2999
///   daily package pkg_250 -> 3299
///
/// Package IDs are used instead of duplicating complete package definitions.
class SpecialRate {
  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;

  final Map<String, double> hourlyPrices;
  final Map<String, double> dailyPrices;

  /// If set, this replaces the package extra-KM rate for the matching date.
  final double? extraKmRate;

  const SpecialRate({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    this.isActive = true,
    this.hourlyPrices = const {},
    this.dailyPrices = const {},
    this.extraKmRate,
  });

  bool containsDate(DateTime date) {
    if (!isActive) return false;

    final day = DateTime(
      date.year,
      date.month,
      date.day,
    );

    final start = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );

    final endExclusive = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
    ).add(
      const Duration(days: 1),
    );

    return !day.isBefore(start) &&
        day.isBefore(endExclusive);
  }

  bool appliesToRange(
    DateTime start,
    DateTime end,
  ) {
    if (!isActive || end.isBefore(start)) {
      return false;
    }

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
      if (containsDate(cursor)) {
        return true;
      }

      cursor = cursor.add(
        const Duration(days: 1),
      );
    }

    return false;
  }

  double? priceFor({
    required RentalType rentalType,
    required String packageId,
  }) {
    final prices =
        rentalType == RentalType.hourly
            ? hourlyPrices
            : dailyPrices;

    final price = prices[packageId];

    if (price == null ||
        !price.isFinite ||
        price < 0) {
      return null;
    }

    return price;
  }

  factory SpecialRate.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    final start =
        _safeDate(map['startDate']);

    final end =
        _safeDate(
      map['endDate'],
      fallback: start,
    );

    return SpecialRate(
      id: id,
      name:
          map['name']?.toString() ?? id,
      startDate: start,
      endDate: end,
      isActive: _safeBool(
        map['isActive'] ??
            map['enabled'],
        fallback: true,
      ),
      hourlyPrices: _toDoubleMap(
        map['hourlyPrices'] ??
            map['hourly'],
      ),
      dailyPrices: _toDoubleMap(
        map['dailyPrices'] ??
            map['daily'],
      ),
      extraKmRate:
          map['extraKmRate'] == null
              ? null
              : _safeDouble(
                  map['extraKmRate'],
                ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'startDate': startDate,
      'endDate': endDate,
      'isActive': isActive,
      'hourlyPrices': hourlyPrices,
      'dailyPrices': dailyPrices,
      if (extraKmRate != null)
        'extraKmRate': extraKmRate,
    };
  }

  SpecialRate copyWith({
    String? id,
    String? name,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    Map<String, double>? hourlyPrices,
    Map<String, double>? dailyPrices,
    double? extraKmRate,
    bool clearExtraKmRate = false,
  }) {
    return SpecialRate(
      id: id ?? this.id,
      name: name ?? this.name,
      startDate:
          startDate ?? this.startDate,
      endDate:
          endDate ?? this.endDate,
      isActive:
          isActive ?? this.isActive,
      hourlyPrices:
          hourlyPrices ?? this.hourlyPrices,
      dailyPrices:
          dailyPrices ?? this.dailyPrices,
      extraKmRate:
          clearExtraKmRate
              ? null
              : (extraKmRate ??
                  this.extraKmRate),
    );
  }
}

/// Security deposit is completely separate from rental/trip pricing.
///
/// Monetary deposits increase amount payable but never tripTotal.
/// Asset deposits are recorded as security and add no money to payable.
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

  String get label {
    switch (this) {
      case DepositType.none:
        return 'No Deposit';
      case DepositType.cash:
        return 'Cash';
      case DepositType.online:
        return 'Online';
      case DepositType.bankTransfer:
        return 'Bank Transfer';
      case DepositType.vehicleAsset:
        return 'Customer Bike';
      case DepositType.otherAsset:
        return 'Other Asset';
    }
  }

  bool get isAsset {
    return this == DepositType.vehicleAsset ||
        this == DepositType.otherAsset;
  }

  bool get isMonetary {
    switch (this) {
      case DepositType.cash:
      case DepositType.online:
      case DepositType.bankTransfer:
        return true;
      case DepositType.none:
      case DepositType.vehicleAsset:
      case DepositType.otherAsset:
        return false;
    }
  }

  static DepositType fromString(
    dynamic value,
  ) {
    switch (
        value
            ?.toString()
            .trim()
            .toLowerCase()) {
      case 'cash':
        return DepositType.cash;

      case 'online':
      case 'upi':
        return DepositType.online;

      case 'banktransfer':
      case 'bank_transfer':
      case 'bank transfer':
        return DepositType.bankTransfer;

      case 'vehicleasset':
      case 'vehicle_asset':
      case 'customerbike':
      case 'customer_bike':
      case 'bike':
        return DepositType.vehicleAsset;

      case 'otherasset':
      case 'other_asset':
        return DepositType.otherAsset;

      case 'none':
      default:
        return DepositType.none;
    }
  }
}

/// Pricing-level default security-deposit configuration.
///
/// Booking-level details such as bike registration, photos, or asset
/// inspection belong to the booking/inspection records, not this profile.
class DepositConfig {
  final DepositType type;
  final double amount;
  final String paymentMethod;
  final String assetDescription;
  final double minimumAssetValue;

  const DepositConfig({
    this.type = DepositType.none,
    this.amount = 0,
    this.paymentMethod = '',
    this.assetDescription = '',
    this.minimumAssetValue = 0,
  });

  bool get required =>
      type != DepositType.none;

  bool get isMonetary =>
      type.isMonetary;

  double get monetaryAmount {
    if (!isMonetary) return 0;

    if (!amount.isFinite ||
        amount < 0) {
      return 0;
    }

    return amount;
  }

  factory DepositConfig.fromMap(
    dynamic value,
  ) {
    final map = value is Map
        ? Map<String, dynamic>.from(
            value,
          )
        : <String, dynamic>{};

    final legacyAmount =
        _safeDouble(
      map['amount'] ??
          map['defaultAmount'] ??
          map['securityDeposit'],
    );

    var type = DepositType.fromString(
      map['type'] ??
          map['depositType'],
    );

    // Migration support for old profiles
    // containing only a positive securityDeposit.
    if (type == DepositType.none &&
        legacyAmount > 0) {
      type = DepositType.cash;
    }

    return DepositConfig(
      type: type,
      amount: legacyAmount,
      paymentMethod:
          map['paymentMethod']
              ?.toString() ??
          '',
      assetDescription:
          map['assetDescription']
              ?.toString() ??
          map['description']
              ?.toString() ??
          '',
      minimumAssetValue:
          _safeDouble(
        map['minimumAssetValue'],
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.value,
      'amount':
          isMonetary
              ? monetaryAmount
              : 0,
      'paymentMethod':
          paymentMethod,
      'assetDescription':
          assetDescription,
      'minimumAssetValue':
          minimumAssetValue,
    };
  }

  DepositConfig copyWith({
    DepositType? type,
    double? amount,
    String? paymentMethod,
    String? assetDescription,
    double? minimumAssetValue,
  }) {
    return DepositConfig(
      type: type ?? this.type,
      amount:
          amount ?? this.amount,
      paymentMethod:
          paymentMethod ??
              this.paymentMethod,
      assetDescription:
          assetDescription ??
              this.assetDescription,
      minimumAssetValue:
          minimumAssetValue ??
              this.minimumAssetValue,
    );
  }
}

/// Simplified pricing profile.
///
/// One pricing profile can be shared by multiple cars.
///
/// Example:
///   Premium SUV
///     -> Creta
///     -> Seltos
///     -> XUV700
///
/// A profile contains only:
///   - hourly packages
///   - daily packages
///   - special date rates
///   - security deposit
class PricingProfile {
  final String id;
  final String tenantId;

  /// Kept for compatibility with vehicle-linked pricing.
  ///
  /// For shared pricing groups this can be empty.
  final String vehicleId;

  /// Shared pricing-group identifier.
  final String pricingGroupId;

  final String name;
  final String currency;

  final List<KmPricingPackage>
      hourlyPackages;

  final List<KmPricingPackage>
      dailyPackages;

  final List<SpecialRate>
      specialRates;

  final DepositConfig
      securityDeposit;

  /// Package-specific minimum booking duration.
  /// Key = KM package id.
  final Map<String, int> minimumHoursByPackageId;

  /// Package-specific minimum daily booking duration.
  /// Key = KM package id.
  final Map<String, int> minimumDaysByPackageId;

  /// Package-specific extra-hour charge.
  /// Key = KM package id.
  final Map<String, double> extraHourRateByPackageId;

  final bool isActive;

  const PricingProfile({
    required this.id,
    required this.tenantId,
    this.vehicleId = '',
    this.pricingGroupId = '',
    required this.name,
    this.currency = 'INR',
    this.hourlyPackages =
        const [],
    this.dailyPackages =
        const [],
    this.specialRates =
        const [],
    this.securityDeposit =
        const DepositConfig(),
    this.minimumHoursByPackageId = const {},
    this.minimumDaysByPackageId = const {},
    this.extraHourRateByPackageId = const {},
    this.isActive = true,
  });

  /// Compatibility getter for older UI code.
  List<KmPricingPackage>
      get kmPackages =>
          dailyPackages;

  double get securityDepositAmount =>
      securityDeposit.monetaryAmount;

  bool get hourlyEnabled =>
      hourlyPackages.any(
        (package) =>
            package.isActive &&
            package.supportsHourly,
      );

  bool get dailyEnabled =>
      dailyPackages.any(
        (package) =>
            package.isActive &&
            package.supportsDaily,
      );

  // ===========================================================================
  // PACKAGE BOOKING RULES
  // ===========================================================================

  int minimumHoursFor(String packageId) {
    final value = minimumHoursByPackageId[packageId.trim()];
    return value != null && value > 0 ? value : 1;
  }

  int minimumDaysFor(String packageId) {
    final value = minimumDaysByPackageId[packageId.trim()];
    return value != null && value > 0 ? value : 1;
  }

  double extraHourRateFor(String packageId) {
    final value = extraHourRateByPackageId[packageId.trim()];
    if (value == null || !value.isFinite || value < 0) return 0;
    return value;
  }

  List<KmPricingPackage> packagesFor(
    RentalType type,
  ) {
    switch (type) {
      case RentalType.hourly:
        return hourlyPackages;
      case RentalType.daily:
        return dailyPackages;
    }
  }

  KmPricingPackage? getPackage(
    String packageId, {
    RentalType? rentalType,
  }) {
    final normalizedId =
        packageId.trim();

    if (normalizedId.isEmpty) {
      return null;
    }

    final source =
        rentalType == null
            ? <KmPricingPackage>[
                ...hourlyPackages,
                ...dailyPackages,
              ]
            : packagesFor(
                rentalType,
              );

    for (final package
        in source) {
      if (package.id ==
          normalizedId) {
        return package;
      }
    }

    return null;
  }

  KmPricingPackage? getPackageByKm(
    int km, {
    RentalType? rentalType,
  }) {
    if (km < 0) return null;

    final source =
        rentalType == null
            ? <KmPricingPackage>[
                ...hourlyPackages,
                ...dailyPackages,
              ]
            : packagesFor(
                rentalType,
              );

    for (final package
        in source) {
      if (package.isActive &&
          !package.unlimitedKm &&
          package.includedKm ==
              km) {
        return package;
      }
    }

    return null;
  }

  KmPricingPackage?
      getUnlimitedPackage({
    RentalType? rentalType,
  }) {
    final source =
        rentalType == null
            ? <KmPricingPackage>[
                ...hourlyPackages,
                ...dailyPackages,
              ]
            : packagesFor(
                rentalType,
              );

    for (final package
        in source) {
      if (package.isActive &&
          package.unlimitedKm) {
        return package;
      }
    }

    return null;
  }

  SpecialRate? specialRateForDate(
    DateTime date,
  ) {
    for (final rate
        in specialRates) {
      if (rate.containsDate(date)) {
        return rate;
      }
    }

    return null;
  }

  SpecialRate? specialRateForRange(
    DateTime start,
    DateTime end,
  ) {
    if (end.isBefore(start)) {
      return null;
    }

    for (final rate
        in specialRates) {
      if (rate.appliesToRange(
        start,
        end,
      )) {
        return rate;
      }
    }

    return null;
  }

  double priceFor({
    required RentalType rentalType,
    required KmPricingPackage package,
    required DateTime date,
  }) {
    final special =
        specialRateForDate(date);

    final override =
        special?.priceFor(
      rentalType: rentalType,
      packageId: package.id,
    );

    if (override != null &&
        override.isFinite &&
        override >= 0) {
      return override;
    }

    return normalPriceFor(
      rentalType: rentalType,
      package: package,
    );
  }

  double normalPriceFor({
    required RentalType rentalType,
    required KmPricingPackage package,
  }) {
    return package.rateFor(
      rentalType.value,
    );
  }

  double extraKmRateFor({
    required KmPricingPackage package,
    DateTime? date,
  }) {
    if (date != null) {
      final special =
          specialRateForDate(date);

      final override =
          special?.extraKmRate;

      if (override != null &&
          override.isFinite &&
          override >= 0) {
        return override;
      }
    }

    return package.safeExtraKmRate;
  }

  bool isRentalTypeEnabled(
    RentalType type,
  ) {
    return packagesFor(type).any(
      (package) =>
          package.isActive &&
          package.supportsRentalType(
            type.value,
          ),
    );
  }

  List<RentalType>
      availableRentalTypesForRange(
    DateTime start,
    DateTime end,
  ) {
    if (end.isBefore(start)) {
      return const [];
    }

    final result =
        <RentalType>[];

    if (isRentalTypeEnabled(
      RentalType.hourly,
    )) {
      result.add(
        RentalType.hourly,
      );
    }

    if (isRentalTypeEnabled(
      RentalType.daily,
    )) {
      result.add(
        RentalType.daily,
      );
    }

    return List.unmodifiable(
      result,
    );
  }

  factory PricingProfile.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    final hourly =
        _toPackageList(
      map['hourlyPackages'],
    );

    final daily =
        _toPackageList(
      map['dailyPackages'],
    );

    // Migration support for the old combined package list.
    final legacy =
        _toPackageList(
      map['kmPackages'] ??
          map['packages'],
    );

    final resolvedHourly =
        hourly.isNotEmpty
            ? hourly
            : legacy;

    final resolvedDaily =
        daily.isNotEmpty
            ? daily
            : legacy;

    return PricingProfile(
      id: id,
      tenantId:
          map['tenantId']
              ?.toString() ??
          '',
      vehicleId:
          map['vehicleId']
              ?.toString() ??
          '',
      pricingGroupId:
          map['pricingGroupId']
              ?.toString() ??
          map['pricingGroup']
              ?.toString() ??
          '',
      name:
          map['name']?.toString() ??
          id,
      currency:
          map['currency']
              ?.toString() ??
          'INR',
      hourlyPackages:
          List.unmodifiable(
        resolvedHourly,
      ),
      dailyPackages:
          List.unmodifiable(
        resolvedDaily,
      ),
      specialRates:
          List.unmodifiable(
        _toSpecialRateList(
          map['specialRates'] ??
              map['specialPricingRules'] ??
              map['specialDates'],
        ),
      ),
      securityDeposit:
          DepositConfig.fromMap(
        map['securityDeposit'] ??
            map[
              'securityDepositConfig'
            ] ??
            map['depositConfig'] ??
            <String, dynamic>{
              'type':
                  map['depositType'],
              'amount':
                  map['securityDeposit'],
            },
      ),
      minimumHoursByPackageId: _toIntMap(
        map['minimumHoursByPackageId'] ??
            map['minimumHoursByPackage'] ??
            map['minimumHours'],
      ),
      minimumDaysByPackageId: _toIntMap(
        map['minimumDaysByPackageId'] ??
            map['minimumDaysByPackage'] ??
            map['minimumDays'],
      ),
      extraHourRateByPackageId: _toDoubleMap(
        map['extraHourRateByPackageId'] ??
            map['extraHourRatesByPackageId'] ??
            map['extraHourRate'],
      ),
      isActive: _safeBool(
        map['isActive'],
        fallback: true,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tenantId': tenantId,
      'vehicleId': vehicleId,
      'pricingGroupId':
          pricingGroupId,
      'name': name,
      'currency': currency,
      'hourlyPackages':
          hourlyPackages
              .map(
                (package) =>
                    package.toMap(),
              )
              .toList(),
      'dailyPackages':
          dailyPackages
              .map(
                (package) =>
                    package.toMap(),
              )
              .toList(),
      'specialRates':
          specialRates
              .map(
                (rate) =>
                    rate.toMap(),
              )
              .toList(),
      'securityDeposit':
          securityDeposit.toMap(),
      'minimumHoursByPackageId':
          Map<String, int>.from(
        minimumHoursByPackageId,
      ),
      'minimumDaysByPackageId':
          Map<String, int>.from(
        minimumDaysByPackageId,
      ),
      'extraHourRateByPackageId':
          Map<String, double>.from(
        extraHourRateByPackageId,
      ),
      'isActive': isActive,
    };
  }


  // ===========================================================================
  // LEGACY UI COMPATIBILITY GETTERS
  // ===========================================================================
  // These getters keep older screens compiling while the active pricing model
  // remains hourly/daily + KM packages + special date rates.
  // They do not participate in pricing calculations.

  KmPricingMode get kmPricingMode => KmPricingMode.package;

  double get hourlyRate {
    for (final package in hourlyPackages) {
      if (package.isActive && package.safeHourlyRate > 0) {
        return package.safeHourlyRate;
      }
    }
    return 0;
  }

  double get dailyRate {
    for (final package in dailyPackages) {
      if (package.isActive && package.safeDailyRate > 0) {
        return package.safeDailyRate;
      }
    }
    return 0;
  }

  /// Weekend/weekly/monthly are no longer supported by the pricing engine.
  /// Kept at zero only so old display-only widgets do not break compilation.
  double get weekendRate => 0;
  double get weeklyRate => 0;
  double get monthlyRate => 0;

  double get extraKmRate {
    final packages = <KmPricingPackage>[
      ...hourlyPackages,
      ...dailyPackages,
    ];
    for (final package in packages) {
      if (package.isActive && package.safeExtraKmRate > 0) {
        return package.safeExtraKmRate;
      }
    }
    return 0;
  }

  List<int> get kmOptions {
    final values = <int>{};
    for (final package in <KmPricingPackage>[
      ...hourlyPackages,
      ...dailyPackages,
    ]) {
      if (package.isActive && !package.unlimitedKm) {
        values.add(package.safeIncludedKm);
      }
    }
    final result = values.where((km) => km > 0).toList()..sort();
    return List.unmodifiable(result);
  }

  int get includedKmPerDay {
    for (final package in dailyPackages) {
      if (package.isActive && !package.unlimitedKm) {
        return package.safeIncludedKm;
      }
    }
    return 0;
  }

  bool get unlimitedKmEnabled =>
      dailyPackages.any((package) => package.isActive && package.unlimitedKm);

  double get unlimitedKmSurcharge => 0;

  int get gracePeriodMinutes => 0;
  double get extraHourRate => 0;
  double get extraDayRate => 0;
  double get lateReturnRate => 0;

  bool get isAsset => securityDeposit.type.isMonetary == false &&
      securityDeposit.type != DepositType.none;

  /// Historical display-only alias used by old widgets.
  double get securityDepositAmountValue => securityDeposit.monetaryAmount;

  void validate() {
    final errors = <String>[];

    if (id.trim().isEmpty) errors.add('Pricing profile ID is required.');
    if (tenantId.trim().isEmpty) errors.add('Tenant ID is required.');
    if (name.trim().isEmpty) errors.add('Pricing profile name is required.');

    if (hourlyPackages.isEmpty && dailyPackages.isEmpty) {
      errors.add('At least one hourly or daily package is required.');
    }

    for (final package in <KmPricingPackage>[
      ...hourlyPackages,
      ...dailyPackages,
    ]) {
      if (package.id.trim().isEmpty) {
        errors.add('A package has an empty ID.');
      }
      if (package.safeHourlyRate < 0 ||
          package.safeDailyRate < 0 ||
          package.safeExtraKmRate < 0) {
        errors.add('Package "${package.id}" contains an invalid price.');
      }
    }

    for (final rate in specialRates) {
      if (rate.name.trim().isEmpty) {
        errors.add('A special rate has no name.');
      }
      if (rate.endDate.isBefore(rate.startDate)) {
        errors.add('Special rate "${rate.name}" has an invalid date range.');
      }
    }

    if (errors.isNotEmpty) {
      throw ArgumentError(errors.join(' '));
    }
  }

  PricingProfile copyWith({
    String? id,
    String? tenantId,
    String? vehicleId,
    String? pricingGroupId,
    String? name,
    String? currency,
    List<KmPricingPackage>?
        hourlyPackages,
    List<KmPricingPackage>?
        dailyPackages,
    List<SpecialRate>?
        specialRates,
    DepositConfig?
        securityDeposit,
    Map<String, int>?
        minimumHoursByPackageId,
    Map<String, int>?
        minimumDaysByPackageId,
    Map<String, double>?
        extraHourRateByPackageId,
    bool? isActive,
  }) {
    return PricingProfile(
      id: id ?? this.id,
      tenantId:
          tenantId ?? this.tenantId,
      vehicleId:
          vehicleId ?? this.vehicleId,
      pricingGroupId:
          pricingGroupId ??
              this.pricingGroupId,
      name: name ?? this.name,
      currency:
          currency ?? this.currency,
      hourlyPackages:
          hourlyPackages ??
              this.hourlyPackages,
      dailyPackages:
          dailyPackages ??
              this.dailyPackages,
      specialRates:
          specialRates ??
              this.specialRates,
      securityDeposit:
          securityDeposit ??
              this.securityDeposit,
      minimumHoursByPackageId:
          minimumHoursByPackageId ??
              this.minimumHoursByPackageId,
      minimumDaysByPackageId:
          minimumDaysByPackageId ??
              this.minimumDaysByPackageId,
      extraHourRateByPackageId:
          extraHourRateByPackageId ??
              this.extraHourRateByPackageId,
      isActive:
          isActive ?? this.isActive,
    );
  }
}

/// Kept only as a temporary source-compatibility enum for older imports.
///
/// New pricing code must use:
///   hourlyPackages
///   dailyPackages
///
/// Do not use this enum for pricing calculations.
enum KmPricingMode {
  included,
  perKm,
  unlimited,
  package,
  slabs;

  String get value => name;

  static KmPricingMode fromString(
    dynamic value,
  ) {
    switch (
        value
            ?.toString()
            .trim()) {
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

// ============================================================================
// SAFE CONVERSION HELPERS
// ============================================================================

bool _safeBool(
  dynamic value, {
  bool fallback = false,
}) {
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
      normalized == 'yes' ||
      normalized == '1') {
    return true;
  }

  if (normalized == 'false' ||
      normalized == 'no' ||
      normalized == '0') {
    return false;
  }

  return fallback;
}

double _safeDouble(
  dynamic value, {
  double fallback = 0,
}) {
  if (value is num) {
    final result =
        value.toDouble();

    return result.isFinite
        ? result
        : fallback;
  }

  final result =
      double.tryParse(
    value?.toString() ?? '',
  );

  if (result == null ||
      !result.isFinite) {
    return fallback;
  }

  return result;
}

DateTime _safeDate(
  dynamic value, {
  DateTime? fallback,
}) {
  if (value is DateTime) {
    return value;
  }

  try {
    final dynamic dynamicValue =
        value;

    final result =
        dynamicValue.toDate();

    if (result is DateTime) {
      return result;
    }
  } catch (_) {}

  final parsed =
      DateTime.tryParse(
    value?.toString() ?? '',
  );

  return parsed ??
      fallback ??
      DateTime(
        2000,
        1,
        1,
      );
}

Map<String, int>
    _toIntMap(
  dynamic value,
) {
  if (value is! Map) {
    return {};
  }

  final result = <String, int>{};
  value.forEach((key, rawValue) {
    final id = key.toString().trim();
    if (id.isEmpty) return;

    final parsed = rawValue is num
        ? rawValue.toInt()
        : int.tryParse(rawValue.toString().trim());

    if (parsed != null && parsed > 0) {
      result[id] = parsed;
    }
  });

  return Map.unmodifiable(result);
}

Map<String, double>
    _toDoubleMap(
  dynamic value,
) {
  if (value is! Map) {
    return {};
  }

  final result =
      <String, double>{};

  value.forEach(
    (key, rawValue) {
      final id =
          key.toString();

      final amount =
          _safeDouble(
        rawValue,
      );

      if (id.isNotEmpty &&
          amount >= 0) {
        result[id] = amount;
      }
    },
  );

  return Map.unmodifiable(
    result,
  );
}

List<KmPricingPackage>
    _toPackageList(
  dynamic value,
) {
  if (value is! Iterable) {
    return [];
  }

  final packages =
      <KmPricingPackage>[];

  var index = 0;

  for (final item in value) {
    if (item is Map) {
      final map =
          Map<String, dynamic>.from(
        item,
      );

      final packageId =
          map['id']
                  ?.toString()
                  .trim()
                  .isNotEmpty ==
              true
              ? map['id']
                  .toString()
                  .trim()
              : 'package_$index';

      packages.add(
        KmPricingPackage.fromMap(
          packageId,
          map,
        ),
      );
    }

    index++;
  }

  return packages;
}

List<SpecialRate>
    _toSpecialRateList(
  dynamic value,
) {
  if (value is! Iterable) {
    return [];
  }

  final rates =
      <SpecialRate>[];

  var index = 0;

  for (final item in value) {
    if (item is Map) {
      final map =
          Map<String, dynamic>.from(
        item,
      );

      final rateId =
          map['id']
                  ?.toString()
                  .trim()
                  .isNotEmpty ==
              true
              ? map['id']
                  .toString()
                  .trim()
              : 'special_$index';

      rates.add(
        SpecialRate.fromMap(
          rateId,
          map,
        ),
      );
    }

    index++;
  }

  return rates;
}
