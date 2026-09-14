class KmSlab {
  final String id;

  /// Starting KM for this slab.
  /// Example: 101
  final int fromKm;

  /// Ending KM for this slab.
  /// Example: 200
  ///
  /// Use null for an unlimited upper range.
  /// Example: 501+
  final int? toKm;

  /// Price charged for each KM within this slab.
  final double pricePerKm;

  /// Whether this slab is currently active.
  final bool isActive;

  const KmSlab({
    required this.id,
    required this.fromKm,
    required this.toKm,
    required this.pricePerKm,
    required this.isActive,
  });

  factory KmSlab.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    return KmSlab(
      id: id,
      fromKm: _toInt(map['fromKm']),
      toKm: map['toKm'] == null
          ? null
          : _toInt(map['toKm']),
      pricePerKm: _toDouble(
        map['pricePerKm'],
      ),
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fromKm': fromKm,
      'toKm': toKm,
      'pricePerKm': pricePerKm,
      'isActive': isActive,
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