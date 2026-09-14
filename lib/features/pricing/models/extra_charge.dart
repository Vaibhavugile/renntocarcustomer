class ExtraCharge {
  final String id;

  // ---------------------------------------------------------------------------
  // BASIC INFORMATION
  // ---------------------------------------------------------------------------

  final String name;

  final String description;

  final ExtraChargeType type;

  // ---------------------------------------------------------------------------
  // PRICE
  // ---------------------------------------------------------------------------

  /// Base amount of the charge.
  ///
  /// Examples:
  /// ₹499 delivery
  /// ₹300 cleaning
  /// ₹250 late return
  final double amount;

  /// Optional per-unit amount.
  ///
  /// Examples:
  /// ₹15 per KM
  /// ₹250 per hour
  final double? unitPrice;

  /// Unit used when unitPrice is applicable.
  ///
  /// Examples:
  /// "km"
  /// "hour"
  /// "day"
  /// "trip"
  final String? unit;

  // ---------------------------------------------------------------------------
  // CALCULATION
  // ---------------------------------------------------------------------------

  /// Whether this charge is calculated based on quantity.
  ///
  /// Example:
  /// Delivery = fixed
  /// Extra KM = quantity based
  final bool isPerUnit;

  /// Whether this charge is taxable.
  final bool isTaxable;

  // ---------------------------------------------------------------------------
  // CUSTOMER VISIBILITY
  // ---------------------------------------------------------------------------

  /// Whether the customer can select this charge.
  ///
  /// Example:
  /// Airport pickup = selectable
  /// Damage charge = admin-only
  final bool isOptional;

  /// Whether this charge should be shown to customers.
  final bool isCustomerVisible;

  // ---------------------------------------------------------------------------
  // STATUS
  // ---------------------------------------------------------------------------

  final bool isActive;

  const ExtraCharge({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.amount,
    required this.unitPrice,
    required this.unit,
    required this.isPerUnit,
    required this.isTaxable,
    required this.isOptional,
    required this.isCustomerVisible,
    required this.isActive,
  });

  // ---------------------------------------------------------------------------
  // FIRESTORE → MODEL
  // ---------------------------------------------------------------------------

  factory ExtraCharge.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    return ExtraCharge(
      id: id,

      name: map['name'] ?? '',

      description:
          map['description'] ?? '',

      type: ExtraChargeType.fromString(
        map['type'],
      ),

      amount: _toDouble(
        map['amount'],
      ),

      unitPrice: map['unitPrice'] == null
          ? null
          : _toDouble(
              map['unitPrice'],
            ),

      unit: map['unit']?.toString(),

      isPerUnit:
          map['isPerUnit'] ?? false,

      isTaxable:
          map['isTaxable'] ?? true,

      isOptional:
          map['isOptional'] ?? false,

      isCustomerVisible:
          map['isCustomerVisible'] ?? true,

      isActive:
          map['isActive'] ?? true,
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
      'amount': amount,
      'unitPrice': unitPrice,
      'unit': unit,
      'isPerUnit': isPerUnit,
      'isTaxable': isTaxable,
      'isOptional': isOptional,
      'isCustomerVisible': isCustomerVisible,
      'isActive': isActive,
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
}

// ============================================================================
// EXTRA CHARGE TYPE
// ============================================================================

enum ExtraChargeType {
  pickup,
  delivery,
  airport,
  fuel,
  cleaning,
  damage,
  lateReturn,
  extraHour,
  extraDay,
  extraKm,
  toll,
  parking,
  driver,
  extension,
  cancellation,
  convenienceFee,
  other;

  String get value {
    switch (this) {
      case ExtraChargeType.pickup:
        return 'pickup';

      case ExtraChargeType.delivery:
        return 'delivery';

      case ExtraChargeType.airport:
        return 'airport';

      case ExtraChargeType.fuel:
        return 'fuel';

      case ExtraChargeType.cleaning:
        return 'cleaning';

      case ExtraChargeType.damage:
        return 'damage';

      case ExtraChargeType.lateReturn:
        return 'lateReturn';

      case ExtraChargeType.extraHour:
        return 'extraHour';

      case ExtraChargeType.extraDay:
        return 'extraDay';

      case ExtraChargeType.extraKm:
        return 'extraKm';

      case ExtraChargeType.toll:
        return 'toll';

      case ExtraChargeType.parking:
        return 'parking';

      case ExtraChargeType.driver:
        return 'driver';

      case ExtraChargeType.extension:
        return 'extension';

      case ExtraChargeType.cancellation:
        return 'cancellation';

      case ExtraChargeType.convenienceFee:
        return 'convenienceFee';

      case ExtraChargeType.other:
        return 'other';
    }
  }

  static ExtraChargeType fromString(
    dynamic value,
  ) {
    switch (value?.toString()) {
      case 'pickup':
        return ExtraChargeType.pickup;

      case 'delivery':
        return ExtraChargeType.delivery;

      case 'airport':
        return ExtraChargeType.airport;

      case 'fuel':
        return ExtraChargeType.fuel;

      case 'cleaning':
        return ExtraChargeType.cleaning;

      case 'damage':
        return ExtraChargeType.damage;

      case 'lateReturn':
        return ExtraChargeType.lateReturn;

      case 'extraHour':
        return ExtraChargeType.extraHour;

      case 'extraDay':
        return ExtraChargeType.extraDay;

      case 'extraKm':
        return ExtraChargeType.extraKm;

      case 'toll':
        return ExtraChargeType.toll;

      case 'parking':
        return ExtraChargeType.parking;

      case 'driver':
        return ExtraChargeType.driver;

      case 'extension':
        return ExtraChargeType.extension;

      case 'cancellation':
        return ExtraChargeType.cancellation;

      case 'convenienceFee':
        return ExtraChargeType.convenienceFee;

      case 'other':
      default:
        return ExtraChargeType.other;
    }
  }
}