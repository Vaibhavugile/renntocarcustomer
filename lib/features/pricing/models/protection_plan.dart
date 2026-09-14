class ProtectionPlan {
  final String id;

  // ---------------------------------------------------------------------------
  // BASIC INFORMATION
  // ---------------------------------------------------------------------------

  final String name;
  final String description;

  /// Optional short label displayed in the customer app.
  ///
  /// Examples:
  /// "BEST VALUE"
  /// "RECOMMENDED"
  /// "LOW LIABILITY"
  final String? badge;

  // ---------------------------------------------------------------------------
  // PRICE
  // ---------------------------------------------------------------------------

  /// Base protection price.
  ///
  /// Example:
  /// ₹299 per trip
  final double price;

  /// Whether the protection price is calculated per rental day.
  ///
  /// Example:
  /// ₹299/day × 3 days = ₹897
  final bool isPerDay;

  // ---------------------------------------------------------------------------
  // DAMAGE / LIABILITY
  // ---------------------------------------------------------------------------

  /// Maximum amount the customer is liable for
  /// under this protection plan, according to
  /// the tenant's configured policy.
  ///
  /// Example:
  /// ₹5,000
  final double customerLiabilityLimit;

  /// Whether the plan covers accidental damage.
  final bool coversAccidentalDamage;

  /// Whether the plan covers theft.
  final bool coversTheft;

  /// Whether the plan covers third-party damage.
  final bool coversThirdPartyDamage;

  /// Whether the plan covers windshield/glass damage.
  final bool coversGlassDamage;

  /// Whether the plan covers tyre damage.
  final bool coversTyreDamage;

  // ---------------------------------------------------------------------------
  // EXCLUSIONS
  // ---------------------------------------------------------------------------

  /// Text describing what is NOT covered.
  ///
  /// This is displayed to the customer.
  final List<String> exclusions;

  // ---------------------------------------------------------------------------
  // TAX
  // ---------------------------------------------------------------------------

  final bool isTaxable;

  // ---------------------------------------------------------------------------
  // CUSTOMER VISIBILITY
  // ---------------------------------------------------------------------------

  final bool isOptional;

  final bool isCustomerVisible;

  // ---------------------------------------------------------------------------
  // STATUS
  // ---------------------------------------------------------------------------

  final bool isActive;

  const ProtectionPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.badge,
    required this.price,
    required this.isPerDay,
    required this.customerLiabilityLimit,
    required this.coversAccidentalDamage,
    required this.coversTheft,
    required this.coversThirdPartyDamage,
    required this.coversGlassDamage,
    required this.coversTyreDamage,
    required this.exclusions,
    required this.isTaxable,
    required this.isOptional,
    required this.isCustomerVisible,
    required this.isActive,
  });

  // ---------------------------------------------------------------------------
  // FIRESTORE → MODEL
  // ---------------------------------------------------------------------------

  factory ProtectionPlan.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    return ProtectionPlan(
      id: id,

      name: map['name'] ?? '',

      description:
          map['description'] ?? '',

      badge: map['badge']?.toString(),

      price: _toDouble(
        map['price'],
      ),

      isPerDay:
          map['isPerDay'] ?? false,

      customerLiabilityLimit:
          _toDouble(
        map['customerLiabilityLimit'],
      ),

      coversAccidentalDamage:
          map['coversAccidentalDamage'] ?? false,

      coversTheft:
          map['coversTheft'] ?? false,

      coversThirdPartyDamage:
          map['coversThirdPartyDamage'] ?? false,

      coversGlassDamage:
          map['coversGlassDamage'] ?? false,

      coversTyreDamage:
          map['coversTyreDamage'] ?? false,

      exclusions:
          _toStringList(
        map['exclusions'],
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
      'badge': badge,
      'price': price,
      'isPerDay': isPerDay,
      'customerLiabilityLimit':
          customerLiabilityLimit,
      'coversAccidentalDamage':
          coversAccidentalDamage,
      'coversTheft':
          coversTheft,
      'coversThirdPartyDamage':
          coversThirdPartyDamage,
      'coversGlassDamage':
          coversGlassDamage,
      'coversTyreDamage':
          coversTyreDamage,
      'exclusions': exclusions,
      'isTaxable': isTaxable,
      'isOptional': isOptional,
      'isCustomerVisible':
          isCustomerVisible,
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