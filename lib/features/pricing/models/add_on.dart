class AddOn {
  final String id;

  // ---------------------------------------------------------------------------
  // BASIC INFORMATION
  // ---------------------------------------------------------------------------

  final String name;
  final String description;
  final AddOnType type;

  // ---------------------------------------------------------------------------
  // PRICING
  // ---------------------------------------------------------------------------

  /// Base price for the add-on.
  ///
  /// Examples:
  /// Child seat       ₹300
  /// Additional driver ₹500
  /// GPS              ₹199
  final double price;

  /// Whether the price is calculated per unit.
  ///
  /// Example:
  /// 2 child seats = 2 × unitPrice
  final bool isPerUnit;

  /// Whether the price is calculated per day.
  ///
  /// Example:
  /// GPS = ₹100/day
  final bool isPerDay;

  /// Optional maximum quantity.
  ///
  /// Example:
  /// Maximum 2 child seats.
  final int? maxQuantity;

  // ---------------------------------------------------------------------------
  // TAX
  // ---------------------------------------------------------------------------

  final bool isTaxable;

  // ---------------------------------------------------------------------------
  // CUSTOMER SELECTION
  // ---------------------------------------------------------------------------

  /// Whether the customer can select this add-on.
  final bool isOptional;

  /// Whether this add-on is visible in the customer app.
  final bool isCustomerVisible;

  // ---------------------------------------------------------------------------
  // AVAILABILITY
  // ---------------------------------------------------------------------------

  final bool isActive;

  const AddOn({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.price,
    required this.isPerUnit,
    required this.isPerDay,
    required this.maxQuantity,
    required this.isTaxable,
    required this.isOptional,
    required this.isCustomerVisible,
    required this.isActive,
  });

  // ---------------------------------------------------------------------------
  // FIRESTORE → MODEL
  // ---------------------------------------------------------------------------

  factory AddOn.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    return AddOn(
      id: id,

      name: map['name'] ?? '',

      description:
          map['description'] ?? '',

      type: AddOnType.fromString(
        map['type'],
      ),

      price: _toDouble(
        map['price'],
      ),

      isPerUnit:
          map['isPerUnit'] ?? false,

      isPerDay:
          map['isPerDay'] ?? false,

      maxQuantity:
          map['maxQuantity'] == null
              ? null
              : _toInt(
                  map['maxQuantity'],
                ),

      isTaxable:
          map['isTaxable'] ?? true,

      isOptional:
          map['isOptional'] ?? true,

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
      'price': price,
      'isPerUnit': isPerUnit,
      'isPerDay': isPerDay,
      'maxQuantity': maxQuantity,
      'isTaxable': isTaxable,
      'isOptional': isOptional,
      'isCustomerVisible': isCustomerVisible,
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

// ============================================================================
// ADD-ON TYPE
// ============================================================================

enum AddOnType {
  additionalDriver,
  childSeat,
  babySeat,
  gps,
  roofCarrier,
  wifi,
  fastag,
  airportPickup,
  airportDrop,
  homeDelivery,
  pickupService,
  dropService,
  insurance,
  protection,
  cleaning,
  other;

  String get value {
    switch (this) {
      case AddOnType.additionalDriver:
        return 'additionalDriver';

      case AddOnType.childSeat:
        return 'childSeat';

      case AddOnType.babySeat:
        return 'babySeat';

      case AddOnType.gps:
        return 'gps';

      case AddOnType.roofCarrier:
        return 'roofCarrier';

      case AddOnType.wifi:
        return 'wifi';

      case AddOnType.fastag:
        return 'fastag';

      case AddOnType.airportPickup:
        return 'airportPickup';

      case AddOnType.airportDrop:
        return 'airportDrop';

      case AddOnType.homeDelivery:
        return 'homeDelivery';

      case AddOnType.pickupService:
        return 'pickupService';

      case AddOnType.dropService:
        return 'dropService';

      case AddOnType.insurance:
        return 'insurance';

      case AddOnType.protection:
        return 'protection';

      case AddOnType.cleaning:
        return 'cleaning';

      case AddOnType.other:
        return 'other';
    }
  }

  static AddOnType fromString(
    dynamic value,
  ) {
    switch (value?.toString()) {
      case 'additionalDriver':
        return AddOnType.additionalDriver;

      case 'childSeat':
        return AddOnType.childSeat;

      case 'babySeat':
        return AddOnType.babySeat;

      case 'gps':
        return AddOnType.gps;

      case 'roofCarrier':
        return AddOnType.roofCarrier;

      case 'wifi':
        return AddOnType.wifi;

      case 'fastag':
        return AddOnType.fastag;

      case 'airportPickup':
        return AddOnType.airportPickup;

      case 'airportDrop':
        return AddOnType.airportDrop;

      case 'homeDelivery':
        return AddOnType.homeDelivery;

      case 'pickupService':
        return AddOnType.pickupService;

      case 'dropService':
        return AddOnType.dropService;

      case 'insurance':
        return AddOnType.insurance;

      case 'protection':
        return AddOnType.protection;

      case 'cleaning':
        return AddOnType.cleaning;

      case 'other':
      default:
        return AddOnType.other;
    }
  }
}