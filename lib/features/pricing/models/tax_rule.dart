class TaxRule {
  final String id;

  // ---------------------------------------------------------------------------
  // BASIC INFORMATION
  // ---------------------------------------------------------------------------

  final String name;

  final String description;

  /// Example:
  /// GST
  /// SGST
  /// CGST
  /// IGST
  final TaxType type;

  // ---------------------------------------------------------------------------
  // TAX RATE
  // ---------------------------------------------------------------------------

  /// Percentage tax rate.
  ///
  /// Example:
  /// 18 = 18%
  final double percentage;

  // ---------------------------------------------------------------------------
  // PRICE BEHAVIOUR
  // ---------------------------------------------------------------------------

  /// If true:
  ///
  /// ₹1,000 already includes tax.
  ///
  /// If false:
  ///
  /// ₹1,000 + tax.
  final bool isInclusive;

  /// Whether this tax is calculated on the
  /// rental amount.
  final bool appliesToRental;

  /// Whether this tax applies to extra KM.
  final bool appliesToExtraKm;

  /// Whether this tax applies to add-ons.
  final bool appliesToAddOns;

  /// Whether this tax applies to delivery/pickup.
  final bool appliesToDelivery;

  /// Whether this tax applies to protection plans.
  final bool appliesToProtection;

  /// Whether this tax applies to extra charges.
  final bool appliesToExtraCharges;

  // ---------------------------------------------------------------------------
  // TARGETING
  // ---------------------------------------------------------------------------

  /// Empty = all vehicles.
  final List<String> vehicleIds;

  /// Empty = all branches.
  final List<String> branchIds;

  // ---------------------------------------------------------------------------
  // STATUS
  // ---------------------------------------------------------------------------

  final bool isActive;

  final bool isCustomerVisible;

  const TaxRule({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.percentage,
    required this.isInclusive,
    required this.appliesToRental,
    required this.appliesToExtraKm,
    required this.appliesToAddOns,
    required this.appliesToDelivery,
    required this.appliesToProtection,
    required this.appliesToExtraCharges,
    required this.vehicleIds,
    required this.branchIds,
    required this.isActive,
    required this.isCustomerVisible,
  });

  // ---------------------------------------------------------------------------
  // FIRESTORE → MODEL
  // ---------------------------------------------------------------------------

  factory TaxRule.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    return TaxRule(
      id: id,

      name: map['name'] ?? '',

      description:
          map['description'] ?? '',

      type: TaxType.fromString(
        map['type'],
      ),

      percentage:
          _toDouble(map['percentage']),

      isInclusive:
          map['isInclusive'] ?? false,

      appliesToRental:
          map['appliesToRental'] ?? true,

      appliesToExtraKm:
          map['appliesToExtraKm'] ?? true,

      appliesToAddOns:
          map['appliesToAddOns'] ?? true,

      appliesToDelivery:
          map['appliesToDelivery'] ?? true,

      appliesToProtection:
          map['appliesToProtection'] ?? true,

      appliesToExtraCharges:
          map['appliesToExtraCharges'] ?? true,

      vehicleIds:
          _toStringList(
        map['vehicleIds'],
      ),

      branchIds:
          _toStringList(
        map['branchIds'],
      ),

      isActive:
          map['isActive'] ?? true,

      isCustomerVisible:
          map['isCustomerVisible'] ?? true,
    );
  }

  // ---------------------------------------------------------------------------
  // MODEL → FIRESTORE
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'type': type.value,
      'percentage': percentage,
      'isInclusive': isInclusive,
      'appliesToRental': appliesToRental,
      'appliesToExtraKm': appliesToExtraKm,
      'appliesToAddOns': appliesToAddOns,
      'appliesToDelivery': appliesToDelivery,
      'appliesToProtection': appliesToProtection,
      'appliesToExtraCharges': appliesToExtraCharges,
      'vehicleIds': vehicleIds,
      'branchIds': branchIds,
      'isActive': isActive,
      'isCustomerVisible': isCustomerVisible,
    };
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  static List<String> _toStringList(
    dynamic value,
  ) {
    if (value is List) {
      return value
          .map(
            (item) => item.toString(),
          )
          .toList();
    }

    return [];
  }
}

// ============================================================================
// TAX TYPE
// ============================================================================

enum TaxType {
  gst,
  cgst,
  sgst,
  igst,
  vat,
  serviceTax,
  other;

  String get value {
    switch (this) {
      case TaxType.gst:
        return 'gst';

      case TaxType.cgst:
        return 'cgst';

      case TaxType.sgst:
        return 'sgst';

      case TaxType.igst:
        return 'igst';

      case TaxType.vat:
        return 'vat';

      case TaxType.serviceTax:
        return 'serviceTax';

      case TaxType.other:
        return 'other';
    }
  }

  static TaxType fromString(
    dynamic value,
  ) {
    switch (value?.toString()) {
      case 'gst':
        return TaxType.gst;

      case 'cgst':
        return TaxType.cgst;

      case 'sgst':
        return TaxType.sgst;

      case 'igst':
        return TaxType.igst;

      case 'vat':
        return TaxType.vat;

      case 'serviceTax':
        return TaxType.serviceTax;

      case 'other':
      default:
        return TaxType.other;
    }
  }
}