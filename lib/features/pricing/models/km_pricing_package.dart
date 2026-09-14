class KmPricingPackage {
  final String id;
  final String name;

  /// KM included in this package.
  /// null = unlimited package.
  final int? includedKm;

  /// Whether this is an unlimited KM package.
  final bool unlimitedKm;

  // ---------------------------------------------------------------------------
  // DURATION PRICES
  // ---------------------------------------------------------------------------

  final double hourlyRate;
  final double dailyRate;
  final double weekendRate;
  final double weeklyRate;
  final double monthlyRate;

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
    required this.hourlyRate,
    required this.dailyRate,
    required this.weekendRate,
    required this.weeklyRate,
    required this.monthlyRate,
    required this.extraKmRate,
  });

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
      unlimitedKm: map['unlimitedKm'] ?? false,

      hourlyRate: _toDouble(map['hourlyRate']),
      dailyRate: _toDouble(map['dailyRate']),
      weekendRate: _toDouble(map['weekendRate']),
      weeklyRate: _toDouble(map['weeklyRate']),
      monthlyRate: _toDouble(map['monthlyRate']),

      extraKmRate: _toDouble(map['extraKmRate']),
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

      'hourlyRate': hourlyRate,
      'dailyRate': dailyRate,
      'weekendRate': weekendRate,
      'weeklyRate': weeklyRate,
      'monthlyRate': monthlyRate,

      'extraKmRate': extraKmRate,
    };
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

  static int? _toNullableInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toInt();
    }

    final parsed = int.tryParse(value.toString());

    return parsed;
  }
}