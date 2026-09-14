class RentalPackage {
  final String id;

  // ---------------------------------------------------------------------------
  // PACKAGE INFORMATION
  // ---------------------------------------------------------------------------

  final String name;
  final String description;

  /// Number of rental days.
  /// Example:
  /// 2 = 2-day package
  /// 7 = weekly package
  final int durationDays;

  /// Optional minimum rental hours.
  /// Useful for hourly/custom packages.
  final int? durationHours;

  // ---------------------------------------------------------------------------
  // KM
  // ---------------------------------------------------------------------------

  /// Total KM included in this package.
  ///
  /// Example:
  /// 2 Days + 200 KM
  /// includedKm = 200
  final int includedKm;

  /// Whether the package has unlimited KM.
  final bool unlimitedKm;

  /// Extra KM price after included KM is exceeded.
  final double extraKmRate;

  // ---------------------------------------------------------------------------
  // PRICE
  // ---------------------------------------------------------------------------

  /// Complete package price before tax/add-ons.
  final double price;

  // ---------------------------------------------------------------------------
  // PACKAGE RULES
  // ---------------------------------------------------------------------------

  /// Whether this package can be selected by customers.
  final bool isBookable;

  /// Whether this package is currently active.
  final bool isActive;

  /// Optional label shown in the app.
  ///
  /// Example:
  /// "BEST VALUE"
  /// "WEEKEND SPECIAL"
  /// "MOST POPULAR"
  final String? badge;

  const RentalPackage({
    required this.id,
    required this.name,
    required this.description,
    required this.durationDays,
    required this.durationHours,
    required this.includedKm,
    required this.unlimitedKm,
    required this.extraKmRate,
    required this.price,
    required this.isBookable,
    required this.isActive,
    required this.badge,
  });

  // ---------------------------------------------------------------------------
  // FIRESTORE → MODEL
  // ---------------------------------------------------------------------------

  factory RentalPackage.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    return RentalPackage(
      id: id,

      name: map['name'] ?? '',

      description: map['description'] ?? '',

      durationDays: _toInt(
        map['durationDays'],
      ),

      durationHours: map['durationHours'] == null
          ? null
          : _toInt(
              map['durationHours'],
            ),

      includedKm: _toInt(
        map['includedKm'],
      ),

      unlimitedKm:
          map['unlimitedKm'] ?? false,

      extraKmRate: _toDouble(
        map['extraKmRate'],
      ),

      price: _toDouble(
        map['price'],
      ),

      isBookable:
          map['isBookable'] ?? true,

      isActive:
          map['isActive'] ?? true,

      badge: map['badge']?.toString(),
    );
  }

  // ---------------------------------------------------------------------------
  // MODEL → FIRESTORE
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'durationDays': durationDays,
      'durationHours': durationHours,
      'includedKm': includedKm,
      'unlimitedKm': unlimitedKm,
      'extraKmRate': extraKmRate,
      'price': price,
      'isBookable': isBookable,
      'isActive': isActive,
      'badge': badge,
    };
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  static int _toInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }
}