class DiscountRule {
  final String id;

  // ---------------------------------------------------------------------------
  // BASIC INFORMATION
  // ---------------------------------------------------------------------------

  final String name;
  final String description;

  /// Optional coupon code.
  ///
  /// Example:
  /// FIRSTCAR
  /// WEEKEND10
  /// RENT500
  final String? couponCode;

  // ---------------------------------------------------------------------------
  // DISCOUNT TYPE
  // ---------------------------------------------------------------------------

  final DiscountType type;

  /// Percentage value.
  ///
  /// Example:
  /// 10 = 10%
  final double percentage;

  /// Fixed discount amount.
  ///
  /// Example:
  /// ₹500
  final double fixedAmount;

  // ---------------------------------------------------------------------------
  // LIMITS
  // ---------------------------------------------------------------------------

  /// Maximum discount amount.
  ///
  /// Useful for percentage discounts.
  ///
  /// Example:
  /// 20% discount, maximum ₹1,000.
  final double? maximumDiscount;

  /// Minimum booking amount required.
  final double minimumBookingAmount;

  /// Minimum rental duration required.
  ///
  /// Example:
  /// 7 days.
  final int? minimumRentalDays;

  /// Maximum number of times this coupon can be used globally.
  final int? usageLimit;

  /// Maximum number of times one customer can use it.
  final int? usageLimitPerCustomer;

  // ---------------------------------------------------------------------------
  // TARGETING
  // ---------------------------------------------------------------------------

  /// Specific vehicle IDs.
  ///
  /// Empty = all vehicles.
  final List<String> vehicleIds;

  /// Specific branch IDs.
  ///
  /// Empty = all branches.
  final List<String> branchIds;

  /// Specific customer IDs.
  ///
  /// Empty = all customers.
  final List<String> customerIds;

  // ---------------------------------------------------------------------------
  // DATE RULES
  // ---------------------------------------------------------------------------

  final DateTime? validFrom;
  final DateTime? validUntil;

  /// Specific weekdays on which this discount applies.
  ///
  /// 1 = Monday
  /// 2 = Tuesday
  /// ...
  /// 7 = Sunday
  ///
  /// Empty = every day.
  final List<int> applicableWeekdays;

  // ---------------------------------------------------------------------------
  // COMBINATION RULES
  // ---------------------------------------------------------------------------

  /// Whether another discount can be applied together with this one.
  final bool canCombine;

  /// Whether this discount applies automatically.
  ///
  /// Example:
  /// 7+ days = automatic 10% discount.
  final bool isAutomatic;

  // ---------------------------------------------------------------------------
  // STATUS
  // ---------------------------------------------------------------------------

  final bool isActive;

  final bool isCustomerVisible;

  const DiscountRule({
    required this.id,
    required this.name,
    required this.description,
    required this.couponCode,
    required this.type,
    required this.percentage,
    required this.fixedAmount,
    required this.maximumDiscount,
    required this.minimumBookingAmount,
    required this.minimumRentalDays,
    required this.usageLimit,
    required this.usageLimitPerCustomer,
    required this.vehicleIds,
    required this.branchIds,
    required this.customerIds,
    required this.validFrom,
    required this.validUntil,
    required this.applicableWeekdays,
    required this.canCombine,
    required this.isAutomatic,
    required this.isActive,
    required this.isCustomerVisible,
  });

  // ---------------------------------------------------------------------------
  // FIRESTORE → MODEL
  // ---------------------------------------------------------------------------

  factory DiscountRule.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    return DiscountRule(
      id: id,

      name: map['name'] ?? '',

      description:
          map['description'] ?? '',

      couponCode:
          map['couponCode']?.toString(),

      type: DiscountType.fromString(
        map['type'],
      ),

      percentage:
          _toDouble(map['percentage']),

      fixedAmount:
          _toDouble(map['fixedAmount']),

      maximumDiscount:
          map['maximumDiscount'] == null
              ? null
              : _toDouble(
                  map['maximumDiscount'],
                ),

      minimumBookingAmount:
          _toDouble(
        map['minimumBookingAmount'],
      ),

      minimumRentalDays:
          map['minimumRentalDays'] == null
              ? null
              : _toInt(
                  map['minimumRentalDays'],
                ),

      usageLimit:
          map['usageLimit'] == null
              ? null
              : _toInt(
                  map['usageLimit'],
                ),

      usageLimitPerCustomer:
          map['usageLimitPerCustomer'] == null
              ? null
              : _toInt(
                  map['usageLimitPerCustomer'],
                ),

      vehicleIds:
          _toStringList(
        map['vehicleIds'],
      ),

      branchIds:
          _toStringList(
        map['branchIds'],
      ),

      customerIds:
          _toStringList(
        map['customerIds'],
      ),

      validFrom:
          _toDateTime(
        map['validFrom'],
      ),

      validUntil:
          _toDateTime(
        map['validUntil'],
      ),

      applicableWeekdays:
          _toIntList(
        map['applicableWeekdays'],
      ),

      canCombine:
          map['canCombine'] ?? false,

      isAutomatic:
          map['isAutomatic'] ?? false,

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
      'couponCode': couponCode,

      'type': type.value,

      'percentage': percentage,
      'fixedAmount': fixedAmount,
      'maximumDiscount': maximumDiscount,

      'minimumBookingAmount':
          minimumBookingAmount,

      'minimumRentalDays':
          minimumRentalDays,

      'usageLimit':
          usageLimit,

      'usageLimitPerCustomer':
          usageLimitPerCustomer,

      'vehicleIds':
          vehicleIds,

      'branchIds':
          branchIds,

      'customerIds':
          customerIds,

      'validFrom':
          validFrom,

      'validUntil':
          validUntil,

      'applicableWeekdays':
          applicableWeekdays,

      'canCombine':
          canCombine,

      'isAutomatic':
          isAutomatic,

      'isActive':
          isActive,

      'isCustomerVisible':
          isCustomerVisible,
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

  static int _toInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
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

  static List<int> _toIntList(
    dynamic value,
  ) {
    if (value is List) {
      return value
          .map(
            (item) => _toInt(item),
          )
          .toList();
    }

    return [];
  }

  static DateTime? _toDateTime(
    dynamic value,
  ) {
    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    // Supports Firestore Timestamp without
    // importing Firebase into our model.
    try {
      return value?.toDate() as DateTime?;
    } catch (_) {
      return null;
    }
  }
}

// ============================================================================
// DISCOUNT TYPE
// ============================================================================

enum DiscountType {
  percentage,
  fixedAmount;

  String get value {
    switch (this) {
      case DiscountType.percentage:
        return 'percentage';

      case DiscountType.fixedAmount:
        return 'fixedAmount';
    }
  }

  static DiscountType fromString(
    dynamic value,
  ) {
    switch (value?.toString()) {
      case 'fixedAmount':
        return DiscountType.fixedAmount;

      case 'percentage':
      default:
        return DiscountType.percentage;
    }
  }
}