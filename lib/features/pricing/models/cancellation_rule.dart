class CancellationRule {
  final String id;

  // ---------------------------------------------------------------------------
  // BASIC INFORMATION
  // ---------------------------------------------------------------------------

  final String name;

  final String description;

  // ---------------------------------------------------------------------------
  // TIME WINDOW
  // ---------------------------------------------------------------------------

  /// Minimum hours before pickup time for this rule to apply.
  ///
  /// Example:
  /// 48 = cancellation 48+ hours before pickup.
  final int minimumHoursBeforePickup;

  /// Maximum hours before pickup time for this rule to apply.
  ///
  /// null = no upper limit.
  ///
  /// Example:
  /// 24 means the rule applies between
  /// 24 and 48 hours before pickup.
  final int? maximumHoursBeforePickup;

  // ---------------------------------------------------------------------------
  // REFUND
  // ---------------------------------------------------------------------------

  /// Percentage of the booking amount refunded.
  ///
  /// Example:
  /// 100 = full refund
  /// 50 = 50% refund
  /// 0 = no refund
  final double refundPercentage;

  /// Fixed cancellation fee.
  ///
  /// This can be used instead of or together with
  /// the percentage-based rule.
  final double cancellationFee;

  /// Whether the cancellation fee is taken
  /// from the refundable amount.
  final bool feeFromRefund;

  // ---------------------------------------------------------------------------
  // DEPOSIT
  // ---------------------------------------------------------------------------

  /// Whether the security deposit is refundable
  /// when this cancellation rule is applied.
  final bool refundSecurityDeposit;

  // ---------------------------------------------------------------------------
  // BOOKING CONDITIONS
  // ---------------------------------------------------------------------------

  /// Minimum booking amount required for this rule.
  final double minimumBookingAmount;

  /// Specific vehicle IDs.
  ///
  /// Empty = all vehicles.
  final List<String> vehicleIds;

  /// Specific branch IDs.
  ///
  /// Empty = all branches.
  final List<String> branchIds;

  // ---------------------------------------------------------------------------
  // STATUS
  // ---------------------------------------------------------------------------

  final bool isActive;

  final bool isCustomerVisible;

  const CancellationRule({
    required this.id,
    required this.name,
    required this.description,
    required this.minimumHoursBeforePickup,
    required this.maximumHoursBeforePickup,
    required this.refundPercentage,
    required this.cancellationFee,
    required this.feeFromRefund,
    required this.refundSecurityDeposit,
    required this.minimumBookingAmount,
    required this.vehicleIds,
    required this.branchIds,
    required this.isActive,
    required this.isCustomerVisible,
  });

  // ---------------------------------------------------------------------------
  // FIRESTORE → MODEL
  // ---------------------------------------------------------------------------

  factory CancellationRule.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    return CancellationRule(
      id: id,

      name: map['name'] ?? '',

      description:
          map['description'] ?? '',

      minimumHoursBeforePickup:
          _toInt(
        map['minimumHoursBeforePickup'],
      ),

      maximumHoursBeforePickup:
          map['maximumHoursBeforePickup'] == null
              ? null
              : _toInt(
                  map['maximumHoursBeforePickup'],
                ),

      refundPercentage:
          _toDouble(
        map['refundPercentage'],
      ),

      cancellationFee:
          _toDouble(
        map['cancellationFee'],
      ),

      feeFromRefund:
          map['feeFromRefund'] ?? false,

      refundSecurityDeposit:
          map['refundSecurityDeposit'] ?? true,

      minimumBookingAmount:
          _toDouble(
        map['minimumBookingAmount'],
      ),

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
      'minimumHoursBeforePickup':
          minimumHoursBeforePickup,
      'maximumHoursBeforePickup':
          maximumHoursBeforePickup,
      'refundPercentage':
          refundPercentage,
      'cancellationFee':
          cancellationFee,
      'feeFromRefund':
          feeFromRefund,
      'refundSecurityDeposit':
          refundSecurityDeposit,
      'minimumBookingAmount':
          minimumBookingAmount,
      'vehicleIds':
          vehicleIds,
      'branchIds':
          branchIds,
      'isActive':
          isActive,
      'isCustomerVisible':
          isCustomerVisible,
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