import 'package:cloud_firestore/cloud_firestore.dart';

/// Safe Firestore/value converters used by all booking snapshot/model classes.
int _toInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _toNullableInt(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}


/// Customer-facing booking lifecycle.
///
/// Operational vehicle status is intentionally separate from this status.
DateTime? _dateTimeFromValue(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  if (value is num) {
    try { return DateTime.fromMillisecondsSinceEpoch(value.toInt()); } catch (_) { return null; }
  }
  return null;
}

enum BookingStatus {
  pending,
  confirmed,
  pickupPending,
  active,
  returnPending,
  completed,
  cancelled,
  rejected,
  noShow,
}

enum PaymentStatus {
  pending,
  partiallyPaid,
  paid,
  failed,
  refunded,
  partiallyRefunded,
}

/// Historical snapshot of the car at the time the booking was created.
///
/// We keep this inside the booking so old bookings do not change when an
/// admin later edits the car name, image, category, etc.
class BookingCarSnapshot {
  final String carId;
  final String name;
  final String type;
  final String transmission;
  final int seats;
  final String fuel;
  final String image;
  final String pricingProfileId;
  final String registrationNumber;

  const BookingCarSnapshot({
    required this.carId,
    required this.name,
    required this.type,
    required this.transmission,
    required this.seats,
    required this.fuel,
    required this.image,
    required this.pricingProfileId,
    this.registrationNumber = '',
  });

  factory BookingCarSnapshot.fromMap(Map<String, dynamic> map) {
    return BookingCarSnapshot(
      carId: map['carId']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      type: map['type']?.toString() ?? '',
      transmission: map['transmission']?.toString() ?? '',
      seats: _toInt(map['seats']),
      fuel: map['fuel']?.toString() ?? '',
      image: map['image']?.toString() ?? '',
      pricingProfileId:
          map['pricingProfileId']?.toString() ?? '',
      registrationNumber:
          map['registrationNumber']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'carId': carId,
      'name': name,
      'type': type,
      'transmission': transmission,
      'seats': seats,
      'fuel': fuel,
      'image': image,
      'pricingProfileId': pricingProfileId,
      'registrationNumber': registrationNumber,
    };
  }
}

/// Historical snapshot of a branch at booking time.
class BookingBranchSnapshot {
  final String branchId;
  final String name;
  final String city;
  final String address;
  final String phone;

  const BookingBranchSnapshot({
    required this.branchId,
    required this.name,
    required this.city,
    required this.address,
    required this.phone,
  });

  factory BookingBranchSnapshot.fromMap(Map<String, dynamic> map) {
    return BookingBranchSnapshot(
      branchId: map['branchId']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      city: map['city']?.toString() ?? '',
      address: map['address']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'branchId': branchId,
      'name': name,
      'city': city,
      'address': address,
      'phone': phone,
    };
  }
}

/// Historical pricing snapshot.
///
/// These values are copied from the pricing calculation at booking time.
/// They should not be recalculated from the current pricing configuration
/// when an old booking is displayed.
class BookingPricingSnapshot {
  final String pricingProfileId;
  final String? kmPackageId;
  final String? kmPackageName;
  final int? includedKm;
  final bool unlimitedKm;
  final double extraKmRate;

  final double baseAmount;
  final double extraKmAmount;
  final double extraTimeAmount;
  final double addOnsAmount;
  final double protectionAmount;
  final double discountAmount;
  final double taxAmount;
  final double securityDeposit;
  final double totalAmount;

  // New rental/pricing metadata. These are snapshots and therefore remain
  // unchanged when the live pricing configuration changes.
  final String? rentalType;
  /// Historical compatibility field. New simplified pricing does not
  /// require a mutable pricing version.
  final int pricingVersion;
  final String? specialPricingRuleId;
  final String? currency;
  final double? minimumBillingAmount;

  const BookingPricingSnapshot({
    required this.pricingProfileId,
    this.kmPackageId,
    this.kmPackageName,
    this.includedKm,
    required this.unlimitedKm,
    required this.extraKmRate,
    required this.baseAmount,
    required this.extraKmAmount,
    required this.extraTimeAmount,
    required this.addOnsAmount,
    required this.protectionAmount,
    required this.discountAmount,
    required this.taxAmount,
    required this.securityDeposit,
    required this.totalAmount,
    this.rentalType,
    this.pricingVersion = 1,
    this.specialPricingRuleId,
    this.currency,
    this.minimumBillingAmount,
  });

  factory BookingPricingSnapshot.fromMap(
    Map<String, dynamic> map,
  ) {
    return BookingPricingSnapshot(
      pricingProfileId:
          map['pricingProfileId']?.toString() ?? '',
      kmPackageId: map['kmPackageId']?.toString(),
      kmPackageName: map['kmPackageName']?.toString(),
      includedKm: _toNullableInt(map['includedKm']),
      unlimitedKm: map['unlimitedKm'] == true,
      extraKmRate: _toDouble(map['extraKmRate']),
      baseAmount: _toDouble(map['baseAmount']),
      extraKmAmount: _toDouble(map['extraKmAmount']),
      extraTimeAmount: _toDouble(map['extraTimeAmount']),
      addOnsAmount: _toDouble(map['addOnsAmount']),
      protectionAmount: _toDouble(map['protectionAmount']),
      discountAmount: _toDouble(map['discountAmount']),
      taxAmount: _toDouble(map['taxAmount']),
      securityDeposit: _toDouble(map['securityDeposit']),
      totalAmount: _toDouble(map['totalAmount']),
      rentalType: map['rentalType']?.toString(),
      pricingVersion: _toInt(map['pricingVersion']) < 1
          ? 1
          : _toInt(map['pricingVersion']),
      specialPricingRuleId:
          map['specialPricingRuleId']?.toString(),
      currency: map['currency']?.toString(),
      minimumBillingAmount:
          map['minimumBillingAmount'] == null
              ? null
              : _toDouble(map['minimumBillingAmount']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'pricingProfileId': pricingProfileId,
      'kmPackageId': kmPackageId,
      'kmPackageName': kmPackageName,
      'includedKm': includedKm,
      'unlimitedKm': unlimitedKm,
      'extraKmRate': extraKmRate,
      'baseAmount': baseAmount,
      'extraKmAmount': extraKmAmount,
      'extraTimeAmount': extraTimeAmount,
      'addOnsAmount': addOnsAmount,
      'protectionAmount': protectionAmount,
      'discountAmount': discountAmount,
      'taxAmount': taxAmount,
      'securityDeposit': securityDeposit,
      'totalAmount': totalAmount,
      'rentalType': rentalType,
      'pricingVersion': pricingVersion,
      'specialPricingRuleId': specialPricingRuleId,
      'currency': currency,
      'minimumBillingAmount': minimumBillingAmount,
    };
  }
}


// ============================================================
// PAYMENT TRANSACTION / LEDGER
// ============================================================
enum PaymentSource { customer, admin, system }
enum PaymentMethodType { razorpay, cash, upi, card, bankTransfer, other }
enum PaymentTransactionStatus { pending, authorized, paid, failed, refunded, partiallyRefunded, cancelled }

/// Individual immutable payment/refund transaction for accounting history.
/// Firestore: tenants/{tenantId}/bookings/{bookingId}/payments/{paymentId}
class PaymentTransaction {
  final String paymentId;
  final String tenantId;
  final String bookingId;
  final String customerId;
  final double amount;
  final String currency;
  final PaymentTransactionStatus status;
  final PaymentMethodType method;
  final PaymentSource source;
  final String? transactionReference;
  final String? gateway;
  final String? razorpayOrderId;
  final String? razorpayPaymentId;
  final String? razorpaySignature;
  final String? gatewayTransactionId;
  final String? gatewayStatus;
  final String? gatewayMethod;
  final String customerName;
  final String customerPhone;
  final String customerEmail;
  final String? recordedBy;
  final String? recordedByRole;
  final String? note;
  final String? originalPaymentId;
  final double refundAmount;
  final DateTime? paymentDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? editedBy;
  final String? editedByRole;
  final String? editedByName;
  final DateTime? editedAt;

  const PaymentTransaction({
    required this.paymentId, required this.tenantId, required this.bookingId,
    required this.customerId, required this.amount, this.currency = 'INR',
    required this.status, required this.method, required this.source,
    this.transactionReference, this.gateway, this.razorpayOrderId,
    this.razorpayPaymentId, this.razorpaySignature, this.gatewayTransactionId,
    this.gatewayStatus, this.gatewayMethod, this.customerName = '',
    this.customerPhone = '', this.customerEmail = '', this.recordedBy,
    this.recordedByRole, this.note, this.originalPaymentId, this.refundAmount = 0,
    this.paymentDate, this.createdAt, this.updatedAt,
    this.editedBy, this.editedByRole, this.editedByName, this.editedAt,
  });

  bool get isSuccessful => status == PaymentTransactionStatus.paid || status == PaymentTransactionStatus.authorized;
  bool get isRefund => status == PaymentTransactionStatus.refunded || status == PaymentTransactionStatus.partiallyRefunded || refundAmount > 0;
  bool get isRazorpay => method == PaymentMethodType.razorpay || gateway?.trim().toLowerCase() == 'razorpay';

  factory PaymentTransaction.fromMap(String id, Map<String, dynamic> map) => PaymentTransaction(
    paymentId: id, tenantId: map['tenantId']?.toString() ?? '', bookingId: map['bookingId']?.toString() ?? '',
    customerId: map['customerId']?.toString() ?? '', amount: _toDouble(map['amount']),
    currency: map['currency']?.toString() ?? 'INR', status: _paymentTransactionStatusFromString(map['status']?.toString()),
    method: _paymentMethodTypeFromString(map['method']?.toString()), source: _paymentSourceFromString(map['source']?.toString()),
    transactionReference: map['transactionReference']?.toString(), gateway: map['gateway']?.toString(),
    razorpayOrderId: map['razorpayOrderId']?.toString(), razorpayPaymentId: map['razorpayPaymentId']?.toString(),
    razorpaySignature: map['razorpaySignature']?.toString(), gatewayTransactionId: map['gatewayTransactionId']?.toString(),
    gatewayStatus: map['gatewayStatus']?.toString(), gatewayMethod: map['gatewayMethod']?.toString(),
    customerName: map['customerName']?.toString() ?? '', customerPhone: map['customerPhone']?.toString() ?? '',
    customerEmail: map['customerEmail']?.toString() ?? '', recordedBy: map['recordedBy']?.toString(),
    recordedByRole: map['recordedByRole']?.toString(), note: map['note']?.toString(),
    originalPaymentId: map['originalPaymentId']?.toString(), refundAmount: _toDouble(map['refundAmount']),
    paymentDate: _dateTimeFromValue(map['paymentDate']), createdAt: _dateTimeFromValue(map['createdAt']), updatedAt: _dateTimeFromValue(map['updatedAt']),
    editedBy: map['editedBy']?.toString(), editedByRole: map['editedByRole']?.toString(),
    editedByName: map['editedByName']?.toString(), editedAt: _dateTimeFromValue(map['editedAt']),
  );

  Map<String, dynamic> toMap() => {
    'paymentId': paymentId, 'tenantId': tenantId, 'bookingId': bookingId, 'customerId': customerId,
    'amount': amount, 'currency': currency, 'status': _paymentTransactionStatusToString(status),
    'method': _paymentMethodTypeToString(method), 'source': _paymentSourceToString(source),
    'transactionReference': transactionReference, 'gateway': gateway, 'razorpayOrderId': razorpayOrderId,
    'razorpayPaymentId': razorpayPaymentId, 'razorpaySignature': razorpaySignature,
    'gatewayTransactionId': gatewayTransactionId, 'gatewayStatus': gatewayStatus, 'gatewayMethod': gatewayMethod,
    'customerName': customerName, 'customerPhone': customerPhone, 'customerEmail': customerEmail,
    'recordedBy': recordedBy, 'recordedByRole': recordedByRole, 'note': note, 'originalPaymentId': originalPaymentId,
    'refundAmount': refundAmount, 'paymentDate': paymentDate == null ? null : Timestamp.fromDate(paymentDate!),
    'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!), 'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
    'editedBy': editedBy, 'editedByRole': editedByRole, 'editedByName': editedByName,
    'editedAt': editedAt == null ? null : Timestamp.fromDate(editedAt!),
  };
}

PaymentTransactionStatus _paymentTransactionStatusFromString(String? v) {
  switch (v) { case 'authorized': return PaymentTransactionStatus.authorized; case 'paid': case 'captured': return PaymentTransactionStatus.paid; case 'failed': return PaymentTransactionStatus.failed; case 'refunded': return PaymentTransactionStatus.refunded; case 'partially_refunded': return PaymentTransactionStatus.partiallyRefunded; case 'cancelled': case 'canceled': return PaymentTransactionStatus.cancelled; default: return PaymentTransactionStatus.pending; }
}
String _paymentTransactionStatusToString(PaymentTransactionStatus v) => switch (v) { PaymentTransactionStatus.pending => 'pending', PaymentTransactionStatus.authorized => 'authorized', PaymentTransactionStatus.paid => 'paid', PaymentTransactionStatus.failed => 'failed', PaymentTransactionStatus.refunded => 'refunded', PaymentTransactionStatus.partiallyRefunded => 'partially_refunded', PaymentTransactionStatus.cancelled => 'cancelled' };
PaymentMethodType _paymentMethodTypeFromString(String? v) { switch (v?.trim().toLowerCase()) { case 'razorpay': return PaymentMethodType.razorpay; case 'cash': return PaymentMethodType.cash; case 'upi': return PaymentMethodType.upi; case 'card': return PaymentMethodType.card; case 'bank_transfer': case 'banktransfer': case 'bank transfer': return PaymentMethodType.bankTransfer; default: return PaymentMethodType.other; } }
String _paymentMethodTypeToString(PaymentMethodType v) => switch (v) { PaymentMethodType.razorpay => 'razorpay', PaymentMethodType.cash => 'cash', PaymentMethodType.upi => 'upi', PaymentMethodType.card => 'card', PaymentMethodType.bankTransfer => 'bank_transfer', PaymentMethodType.other => 'other' };
PaymentSource _paymentSourceFromString(String? v) => switch (v?.trim().toLowerCase()) { 'admin' => PaymentSource.admin, 'system' => PaymentSource.system, _ => PaymentSource.customer };
String _paymentSourceToString(PaymentSource v) => switch (v) { PaymentSource.customer => 'customer', PaymentSource.admin => 'admin', PaymentSource.system => 'system' };

class Booking {
  // ============================================================
  // IDENTITY / TENANT
  // ============================================================

  final String bookingId;
  final String tenantId;
  final String customerId;
  final String carId;
  final String branchId;

  // ============================================================
  // STATUS
  // ============================================================

  final BookingStatus status;
  final PaymentStatus paymentStatus;

  // ============================================================
  // RENTAL DATES
  // ============================================================

  final DateTime pickupDateTime;
  final DateTime returnDateTime;

  /// Rental mode selected during booking.
  ///
  /// Stored as a string in the booking snapshot so this model remains
  /// compatible with the pricing models while avoiding a hard dependency on
  /// their enum implementation.
  final String rentalType;

  /// Pricing profile version retained only as a historical snapshot.
  ///
  /// The simplified pricing model does not require versioning, but this field
  /// remains optional for backward compatibility with existing bookings.
  final int pricingVersion;

  /// Special-date pricing rule used, if any.
  final String? specialPricingRuleId;

  final DateTime? actualPickupDateTime;
  final DateTime? actualReturnDateTime;

  // ============================================================
  // BRANCHES
  // ============================================================

  final String pickupBranchId;
  final String returnBranchId;

  final BookingBranchSnapshot? pickupBranch;
  final BookingBranchSnapshot? returnBranch;

  // ============================================================
  // CAR SNAPSHOT
  // ============================================================

  final BookingCarSnapshot? car;

  // ============================================================
  // KM PACKAGE
  // ============================================================

  final String? kmPackageId;
  final String? kmPackageName;
  final int? includedKm;
  final bool unlimitedKm;
  final double extraKmRate;

  // ============================================================
  // PRICING SNAPSHOT
  // ============================================================

  final String pricingProfileId;

  final double baseAmount;
  final double extraKmAmount;
  final double extraTimeAmount;
  final double addOnsAmount;
  final double protectionAmount;
  final double discountAmount;
  final double taxAmount;

  final double securityDeposit;
  final double totalAmount;

  /// Complete pricing snapshot for future admin/invoice reporting.
  final BookingPricingSnapshot? pricing;

  // ============================================================
  // PAYMENTS
  // ============================================================

  final double paidAmount;
  final double refundAmount;

  /// Useful when payment integration is added later.
  final String? paymentId;
  final String? paymentOrderId;
  final String? paymentTransactionId;
  final String? paymentMethod;

  // ============================================================
  // COUPON
  // ============================================================

  final String? couponCode;

  // ============================================================
  // CUSTOMER SNAPSHOT
  // ============================================================

  final String customerName;
  final String customerPhone;
  final String customerEmail;

  // ============================================================
  // NOTES / WORKFLOW
  // ============================================================

  final String customerNote;
  final String cancellationReason;
  final String rejectionReason;

  /// Pending booking expiry. After this time a pending hold should
  /// no longer block availability.
  final DateTime? expiresAt;

  // ============================================================
  // TIMESTAMPS
  // ============================================================

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Booking({
    required this.bookingId,
    required this.tenantId,
    required this.customerId,
    required this.carId,
    required this.branchId,
    required this.status,
    required this.paymentStatus,
    required this.pickupDateTime,
    required this.returnDateTime,
    this.rentalType = 'daily',
    this.pricingVersion = 1,
    this.specialPricingRuleId,
    this.actualPickupDateTime,
    this.actualReturnDateTime,
    required this.pickupBranchId,
    required this.returnBranchId,
    this.pickupBranch,
    this.returnBranch,
    this.car,
    this.kmPackageId,
    this.kmPackageName,
    this.includedKm,
    required this.unlimitedKm,
    required this.extraKmRate,
    required this.pricingProfileId,
    required this.baseAmount,
    required this.extraKmAmount,
    required this.extraTimeAmount,
    required this.addOnsAmount,
    required this.protectionAmount,
    required this.discountAmount,
    required this.taxAmount,
    required this.securityDeposit,
    required this.totalAmount,
    this.pricing,
    required this.paidAmount,
    required this.refundAmount,
    this.paymentId,
    this.paymentOrderId,
    this.paymentTransactionId,
    this.paymentMethod,
    this.couponCode,
    required this.customerName,
    required this.customerPhone,
    required this.customerEmail,
    required this.customerNote,
    required this.cancellationReason,
    required this.rejectionReason,
    this.expiresAt,
    this.createdAt,
    this.updatedAt,
  });

  // ============================================================
  // STATUS HELPERS
  // ============================================================

  bool get isPending => status == BookingStatus.pending;

  bool get isConfirmed => status == BookingStatus.confirmed;

  bool get isPickupPending =>
      status == BookingStatus.pickupPending;

  bool get isActive => status == BookingStatus.active;

  bool get isReturnPending =>
      status == BookingStatus.returnPending;

  bool get isCompleted =>
      status == BookingStatus.completed;

  bool get isCancelled =>
      status == BookingStatus.cancelled;

  bool get isRejected =>
      status == BookingStatus.rejected;

  bool get isNoShow => status == BookingStatus.noShow;

  bool get requiresPayment =>
      paymentStatus == PaymentStatus.pending ||
      paymentStatus == PaymentStatus.partiallyPaid;

  bool get isPaymentComplete =>
      paymentStatus == PaymentStatus.paid;

  bool get canBeCancelled =>
      !isFinished &&
      status != BookingStatus.active &&
      status != BookingStatus.returnPending;

  bool get hasActualPickup =>
      actualPickupDateTime != null;

  bool get hasActualReturn =>
      actualReturnDateTime != null;

  bool get isRentalTypeHourly =>
      rentalType == 'hourly';

  bool get isRentalTypeDaily =>
      rentalType == 'daily';

  bool get isUpcoming =>
      status == BookingStatus.pending ||
      status == BookingStatus.confirmed ||
      status == BookingStatus.pickupPending;

  bool get isOngoing =>
      status == BookingStatus.active ||
      status == BookingStatus.returnPending;

  bool get isFinished =>
      status == BookingStatus.completed ||
      status == BookingStatus.cancelled ||
      status == BookingStatus.rejected ||
      status == BookingStatus.noShow;

  /// These statuses reserve the car's time window.
  bool get isBlockingAvailability =>
      status == BookingStatus.pending ||
      status == BookingStatus.confirmed ||
      status == BookingStatus.pickupPending ||
      status == BookingStatus.active ||
      status == BookingStatus.returnPending;

  /// Whether this pending booking has expired.
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  // ============================================================
  // BOOKING / PAYMENT HELPERS
  // ============================================================

  double get balanceAmount {
    final balance = totalAmount - paidAmount + refundAmount;
    return balance < 0 ? 0 : balance;
  }

  bool get hasBalance => balanceAmount > 0.009;

  bool get hasRefund => refundAmount > 0.009;

  /// The operational availability window.
  ///
  /// The availability service should still normalize daily/weekend rentals
  /// to the selected full calendar days. This getter only exposes the stored
  /// booking window.
  DateTimeRangeValue get availabilityRange {
    return DateTimeRangeValue(
      start: pickupDateTime,
      end: returnDateTime,
    );
  }

  // ============================================================
  // FIRESTORE -> MODEL
  // ============================================================

  factory Booking.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    final carMap = _mapFromDynamic(map['car']);
    final pickupBranchMap =
        _mapFromDynamic(map['pickupBranch']);
    final returnBranchMap =
        _mapFromDynamic(map['returnBranch']);
    final pricingMap =
        _mapFromDynamic(map['pricing']);

    return Booking(
      bookingId: id,
      tenantId: map['tenantId']?.toString() ?? '',
      customerId: map['customerId']?.toString() ?? '',
      carId: map['carId']?.toString() ?? '',
      branchId: map['branchId']?.toString() ?? '',

      status: _bookingStatusFromString(
        map['status']?.toString(),
      ),

      paymentStatus: _paymentStatusFromString(
        map['paymentStatus']?.toString(),
      ),

      pickupDateTime:
          _dateTimeFromValue(map['pickupDateTime']) ??
          DateTime.now(),

      returnDateTime:
          _dateTimeFromValue(map['returnDateTime']) ??
          DateTime.now(),

      rentalType:
          _normalizeRentalType(map['rentalType']),

      pricingVersion:
          _positiveInt(map['pricingVersion'], 1),

      specialPricingRuleId:
          map['specialPricingRuleId']?.toString(),

      actualPickupDateTime:
          _dateTimeFromValue(
        map['actualPickupDateTime'],
      ),

      actualReturnDateTime:
          _dateTimeFromValue(
        map['actualReturnDateTime'],
      ),

      pickupBranchId:
          map['pickupBranchId']?.toString() ?? '',

      returnBranchId:
          map['returnBranchId']?.toString() ?? '',

      pickupBranch: pickupBranchMap == null
          ? null
          : BookingBranchSnapshot.fromMap(
              pickupBranchMap,
            ),

      returnBranch: returnBranchMap == null
          ? null
          : BookingBranchSnapshot.fromMap(
              returnBranchMap,
            ),

      car: carMap == null
          ? null
          : BookingCarSnapshot.fromMap(
              carMap,
            ),

      kmPackageId:
          map['kmPackageId']?.toString(),

      kmPackageName:
          map['kmPackageName']?.toString(),

      includedKm:
          _toNullableInt(map['includedKm']),

      unlimitedKm:
          map['unlimitedKm'] == true,

      extraKmRate:
          _toDouble(map['extraKmRate']),

      pricingProfileId:
          map['pricingProfileId']?.toString() ?? '',

      baseAmount:
          _toDouble(map['baseAmount']),

      extraKmAmount:
          _toDouble(map['extraKmAmount']),

      extraTimeAmount:
          _toDouble(map['extraTimeAmount']),

      addOnsAmount:
          _toDouble(map['addOnsAmount']),

      protectionAmount:
          _toDouble(map['protectionAmount']),

      discountAmount:
          _toDouble(map['discountAmount']),

      taxAmount:
          _toDouble(map['taxAmount']),

      securityDeposit:
          _toDouble(map['securityDeposit']),

      totalAmount:
          _toDouble(map['totalAmount']),

      pricing: pricingMap == null
          ? null
          : BookingPricingSnapshot.fromMap(
              pricingMap,
            ),

      paidAmount:
          _toDouble(map['paidAmount']),

      refundAmount:
          _toDouble(map['refundAmount']),

      paymentId:
          map['paymentId']?.toString(),

      paymentOrderId:
          map['paymentOrderId']?.toString(),

      paymentTransactionId:
          map['paymentTransactionId']?.toString(),

      paymentMethod:
          map['paymentMethod']?.toString(),

      couponCode:
          map['couponCode']?.toString(),

      customerName:
          map['customerName']?.toString() ?? '',

      customerPhone:
          map['customerPhone']?.toString() ?? '',

      customerEmail:
          map['customerEmail']?.toString() ?? '',

      customerNote:
          map['customerNote']?.toString() ?? '',

      cancellationReason:
          map['cancellationReason']?.toString() ?? '',

      rejectionReason:
          map['rejectionReason']?.toString() ?? '',

      expiresAt:
          _dateTimeFromValue(map['expiresAt']),

      createdAt:
          _dateTimeFromValue(map['createdAt']),

      updatedAt:
          _dateTimeFromValue(map['updatedAt']),
    );
  }

  // ============================================================
  // MODEL -> FIRESTORE
  // ============================================================

  Map<String, dynamic> toMap() {
    return {
      // Identity
      'bookingId': bookingId,
      'tenantId': tenantId,
      'customerId': customerId,
      'carId': carId,
      'branchId': branchId,

      // Status
      'status': _bookingStatusToString(status),
      'paymentStatus':
          _paymentStatusToString(paymentStatus),

      // Rental
      'pickupDateTime':
          Timestamp.fromDate(pickupDateTime),
      'returnDateTime':
          Timestamp.fromDate(returnDateTime),

      'rentalType': rentalType,
      'pricingVersion': pricingVersion,
      'specialPricingRuleId':
          specialPricingRuleId,

      'actualPickupDateTime':
          actualPickupDateTime == null
              ? null
              : Timestamp.fromDate(
                  actualPickupDateTime!,
                ),

      'actualReturnDateTime':
          actualReturnDateTime == null
              ? null
              : Timestamp.fromDate(
                  actualReturnDateTime!,
                ),

      // Branches
      'pickupBranchId': pickupBranchId,
      'returnBranchId': returnBranchId,

      'pickupBranch':
          pickupBranch?.toMap(),

      'returnBranch':
          returnBranch?.toMap(),

      // Car snapshot
      'car':
          car?.toMap(),

      // KM
      'kmPackageId': kmPackageId,
      'kmPackageName': kmPackageName,
      'includedKm': includedKm,
      'unlimitedKm': unlimitedKm,
      'extraKmRate': extraKmRate,

      // Pricing
      'pricingProfileId': pricingProfileId,
      'baseAmount': baseAmount,
      'extraKmAmount': extraKmAmount,
      'extraTimeAmount': extraTimeAmount,
      'addOnsAmount': addOnsAmount,
      'protectionAmount': protectionAmount,
      'discountAmount': discountAmount,
      'taxAmount': taxAmount,
      'securityDeposit': securityDeposit,
      'totalAmount': totalAmount,

      'pricing':
          pricing?.toMap(),

      // Payments
      'paidAmount': paidAmount,
      'refundAmount': refundAmount,
      'paymentId': paymentId,
      'paymentOrderId': paymentOrderId,
      'paymentTransactionId':
          paymentTransactionId,
      'paymentMethod': paymentMethod,

      // Coupon
      'couponCode': couponCode,

      // Customer snapshot
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerEmail': customerEmail,

      // Workflow
      'customerNote': customerNote,
      'cancellationReason':
          cancellationReason,
      'rejectionReason':
          rejectionReason,

      'expiresAt':
          expiresAt == null
              ? null
              : Timestamp.fromDate(expiresAt!),

      // Timestamps
      'createdAt':
          createdAt == null
              ? null
              : Timestamp.fromDate(createdAt!),

      'updatedAt':
          updatedAt == null
              ? null
              : Timestamp.fromDate(updatedAt!),
    };
  }

  // ============================================================
  // COPY WITH
  // ============================================================

  Booking copyWith({
    String? bookingId,
    String? tenantId,
    String? customerId,
    String? carId,
    String? branchId,
    BookingStatus? status,
    PaymentStatus? paymentStatus,
    DateTime? pickupDateTime,
    DateTime? returnDateTime,
    String? rentalType,
    int? pricingVersion,
    String? specialPricingRuleId,
    DateTime? actualPickupDateTime,
    DateTime? actualReturnDateTime,
    String? pickupBranchId,
    String? returnBranchId,
    BookingBranchSnapshot? pickupBranch,
    BookingBranchSnapshot? returnBranch,
    BookingCarSnapshot? car,
    String? kmPackageId,
    String? kmPackageName,
    int? includedKm,
    bool? unlimitedKm,
    double? extraKmRate,
    String? pricingProfileId,
    double? baseAmount,
    double? extraKmAmount,
    double? extraTimeAmount,
    double? addOnsAmount,
    double? protectionAmount,
    double? discountAmount,
    double? taxAmount,
    double? securityDeposit,
    double? totalAmount,
    BookingPricingSnapshot? pricing,
    double? paidAmount,
    double? refundAmount,
    String? paymentId,
    String? paymentOrderId,
    String? paymentTransactionId,
    String? paymentMethod,
    String? couponCode,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? customerNote,
    String? cancellationReason,
    String? rejectionReason,
    DateTime? expiresAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Booking(
      bookingId:
          bookingId ?? this.bookingId,
      tenantId:
          tenantId ?? this.tenantId,
      customerId:
          customerId ?? this.customerId,
      carId:
          carId ?? this.carId,
      branchId:
          branchId ?? this.branchId,

      status:
          status ?? this.status,

      paymentStatus:
          paymentStatus ?? this.paymentStatus,

      pickupDateTime:
          pickupDateTime ??
          this.pickupDateTime,

      returnDateTime:
          returnDateTime ??
          this.returnDateTime,

      rentalType:
          rentalType ??
          this.rentalType,

      pricingVersion:
          pricingVersion ??
          this.pricingVersion,

      specialPricingRuleId:
          specialPricingRuleId ??
          this.specialPricingRuleId,

      actualPickupDateTime:
          actualPickupDateTime ??
          this.actualPickupDateTime,

      actualReturnDateTime:
          actualReturnDateTime ??
          this.actualReturnDateTime,

      pickupBranchId:
          pickupBranchId ??
          this.pickupBranchId,

      returnBranchId:
          returnBranchId ??
          this.returnBranchId,

      pickupBranch:
          pickupBranch ??
          this.pickupBranch,

      returnBranch:
          returnBranch ??
          this.returnBranch,

      car:
          car ?? this.car,

      kmPackageId:
          kmPackageId ??
          this.kmPackageId,

      kmPackageName:
          kmPackageName ??
          this.kmPackageName,

      includedKm:
          includedKm ??
          this.includedKm,

      unlimitedKm:
          unlimitedKm ??
          this.unlimitedKm,

      extraKmRate:
          extraKmRate ??
          this.extraKmRate,

      pricingProfileId:
          pricingProfileId ??
          this.pricingProfileId,

      baseAmount:
          baseAmount ??
          this.baseAmount,

      extraKmAmount:
          extraKmAmount ??
          this.extraKmAmount,

      extraTimeAmount:
          extraTimeAmount ??
          this.extraTimeAmount,

      addOnsAmount:
          addOnsAmount ??
          this.addOnsAmount,

      protectionAmount:
          protectionAmount ??
          this.protectionAmount,

      discountAmount:
          discountAmount ??
          this.discountAmount,

      taxAmount:
          taxAmount ??
          this.taxAmount,

      securityDeposit:
          securityDeposit ??
          this.securityDeposit,

      totalAmount:
          totalAmount ??
          this.totalAmount,

      pricing:
          pricing ?? this.pricing,

      paidAmount:
          paidAmount ??
          this.paidAmount,

      refundAmount:
          refundAmount ??
          this.refundAmount,

      paymentId:
          paymentId ??
          this.paymentId,

      paymentOrderId:
          paymentOrderId ??
          this.paymentOrderId,

      paymentTransactionId:
          paymentTransactionId ??
          this.paymentTransactionId,

      paymentMethod:
          paymentMethod ??
          this.paymentMethod,

      couponCode:
          couponCode ??
          this.couponCode,

      customerName:
          customerName ??
          this.customerName,

      customerPhone:
          customerPhone ??
          this.customerPhone,

      customerEmail:
          customerEmail ??
          this.customerEmail,

      customerNote:
          customerNote ??
          this.customerNote,

      cancellationReason:
          cancellationReason ??
          this.cancellationReason,

      rejectionReason:
          rejectionReason ??
          this.rejectionReason,

      expiresAt:
          expiresAt ??
          this.expiresAt,

      createdAt:
          createdAt ??
          this.createdAt,

      updatedAt:
          updatedAt ??
          this.updatedAt,
    );
  }

  // ============================================================
  // STATUS CONVERTERS
  // ============================================================

  static BookingStatus _bookingStatusFromString(
    String? value,
  ) {
    switch (value) {
      case 'confirmed':
        return BookingStatus.confirmed;

      case 'pickup_pending':
        return BookingStatus.pickupPending;

      case 'active':
        return BookingStatus.active;

      case 'return_pending':
        return BookingStatus.returnPending;

      case 'completed':
        return BookingStatus.completed;

      case 'cancelled':
        return BookingStatus.cancelled;

      case 'rejected':
        return BookingStatus.rejected;

      case 'no_show':
        return BookingStatus.noShow;

      case 'pending':
      default:
        return BookingStatus.pending;
    }
  }

  static String _bookingStatusToString(
    BookingStatus status,
  ) {
    switch (status) {
      case BookingStatus.pending:
        return 'pending';

      case BookingStatus.confirmed:
        return 'confirmed';

      case BookingStatus.pickupPending:
        return 'pickup_pending';

      case BookingStatus.active:
        return 'active';

      case BookingStatus.returnPending:
        return 'return_pending';

      case BookingStatus.completed:
        return 'completed';

      case BookingStatus.cancelled:
        return 'cancelled';

      case BookingStatus.rejected:
        return 'rejected';

      case BookingStatus.noShow:
        return 'no_show';
    }
  }

  static PaymentStatus _paymentStatusFromString(
    String? value,
  ) {
    switch (value) {
      case 'partially_paid':
        return PaymentStatus.partiallyPaid;

      case 'paid':
        return PaymentStatus.paid;

      case 'failed':
        return PaymentStatus.failed;

      case 'refunded':
        return PaymentStatus.refunded;

      case 'partially_refunded':
        return PaymentStatus.partiallyRefunded;

      case 'pending':
      default:
        return PaymentStatus.pending;
    }
  }

  static String _paymentStatusToString(
    PaymentStatus status,
  ) {
    switch (status) {
      case PaymentStatus.pending:
        return 'pending';

      case PaymentStatus.partiallyPaid:
        return 'partially_paid';

      case PaymentStatus.paid:
        return 'paid';

      case PaymentStatus.failed:
        return 'failed';

      case PaymentStatus.refunded:
        return 'refunded';

      case PaymentStatus.partiallyRefunded:
        return 'partially_refunded';
    }
  }

  // ============================================================
  // VALUE CONVERTERS
  // ============================================================

  static DateTime? _dateTimeFromValue(
    dynamic value,
  ) {
    if (value == null) return null;

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  static Map<String, dynamic>? _mapFromDynamic(
    dynamic value,
  ) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return null;
  }

  static int _positiveInt(
    dynamic value,
    int fallback,
  ) {
    final parsed = _toInt(value);
    return parsed < 1 ? fallback : parsed;
  }

  static String _normalizeRentalType(
    dynamic value,
  ) {
    final normalized =
        value?.toString().trim().toLowerCase();

    switch (normalized) {
      case 'hourly':
        return 'hourly';
      case 'weekend':
        // Legacy bookings may contain weekend. The new pricing model has only
        // hourly and daily rental types, so legacy weekend records are treated
        // as daily for display/calculation compatibility.
        return 'daily';
      case 'daily':
        return 'daily';
      default:
        return 'daily';
    }
  }
}

/// Lightweight range value used by booking availability integrations without
/// coupling this model to a UI/date-range package.
class DateTimeRangeValue {
  final DateTime start;
  final DateTime end;

  const DateTimeRangeValue({
    required this.start,
    required this.end,
  });

  bool get isValid =>
      !end.isBefore(start);

  Duration get duration =>
      end.difference(start);

  bool overlaps(
    DateTime otherStart,
    DateTime otherEnd,
  ) {
    return start.isBefore(otherEnd) &&
        end.isAfter(otherStart);
  }
}

