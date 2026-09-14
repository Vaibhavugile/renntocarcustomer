import 'package:cloud_firestore/cloud_firestore.dart';

enum CustomerDocumentType {
  drivingLicense,
  governmentId,
}

enum CustomerDocumentStatus {
  notUploaded,
  pending,
  verified,
  rejected,
}

class CustomerDocument {
  final String documentId;
  final String tenantId;
  final String customerId;
  final CustomerDocumentType type;
  final String documentNumber;
  final String frontImageUrl;
  final String backImageUrl;
  final CustomerDocumentStatus status;
  final String rejectionReason;
  final DateTime? verifiedAt;
  final String verifiedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CustomerDocument({
    required this.documentId,
    required this.tenantId,
    required this.customerId,
    required this.type,
    required this.documentNumber,
    required this.frontImageUrl,
    required this.backImageUrl,
    required this.status,
    required this.rejectionReason,
    required this.verifiedAt,
    required this.verifiedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get hasFront => frontImageUrl.trim().isNotEmpty;
  bool get hasBack => backImageUrl.trim().isNotEmpty;

  bool get isComplete =>
      hasFront && hasBack && documentNumber.trim().isNotEmpty;

  bool get isVerified =>
      status == CustomerDocumentStatus.verified;

  String get typeKey {
    switch (type) {
      case CustomerDocumentType.drivingLicense:
        return 'driving_license';
      case CustomerDocumentType.governmentId:
        return 'government_id';
    }
  }

  String get typeLabel {
    switch (type) {
      case CustomerDocumentType.drivingLicense:
        return 'Driving License';
      case CustomerDocumentType.governmentId:
        return 'Government ID';
    }
  }

  CustomerDocument copyWith({
    String? documentId,
    String? tenantId,
    String? customerId,
    CustomerDocumentType? type,
    String? documentNumber,
    String? frontImageUrl,
    String? backImageUrl,
    CustomerDocumentStatus? status,
    String? rejectionReason,
    DateTime? verifiedAt,
    String? verifiedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CustomerDocument(
      documentId: documentId ?? this.documentId,
      tenantId: tenantId ?? this.tenantId,
      customerId: customerId ?? this.customerId,
      type: type ?? this.type,
      documentNumber: documentNumber ?? this.documentNumber,
      frontImageUrl: frontImageUrl ?? this.frontImageUrl,
      backImageUrl: backImageUrl ?? this.backImageUrl,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      verifiedBy: verifiedBy ?? this.verifiedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory CustomerDocument.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    return CustomerDocument(
      documentId: id,
      tenantId: map['tenantId']?.toString() ?? '',
      customerId: map['customerId']?.toString() ?? '',
      type: _typeFromString(map['documentType']?.toString()),
      documentNumber: map['documentNumber']?.toString() ?? '',
      frontImageUrl: map['frontImageUrl']?.toString() ?? '',
      backImageUrl: map['backImageUrl']?.toString() ?? '',
      status: _statusFromString(map['status']?.toString()),
      rejectionReason: map['rejectionReason']?.toString() ?? '',
      verifiedAt: _date(map['verifiedAt']),
      verifiedBy: map['verifiedBy']?.toString() ?? '',
      createdAt: _date(map['createdAt']),
      updatedAt: _date(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tenantId': tenantId,
      'customerId': customerId,
      'documentType': typeKey,
      'documentNumber': documentNumber,
      'frontImageUrl': frontImageUrl,
      'backImageUrl': backImageUrl,
      'status': _statusToString(status),
      'rejectionReason': rejectionReason,
      'verifiedAt': verifiedAt == null
          ? null
          : Timestamp.fromDate(verifiedAt!),
      'verifiedBy': verifiedBy,
      'createdAt': createdAt == null
          ? null
          : Timestamp.fromDate(createdAt!),
      'updatedAt': updatedAt == null
          ? null
          : Timestamp.fromDate(updatedAt!),
    };
  }

  static CustomerDocumentType _typeFromString(String? value) {
    switch (value) {
      case 'government_id':
        return CustomerDocumentType.governmentId;
      case 'driving_license':
      default:
        return CustomerDocumentType.drivingLicense;
    }
  }

  static CustomerDocumentStatus _statusFromString(String? value) {
    switch (value) {
      case 'pending':
        return CustomerDocumentStatus.pending;
      case 'verified':
        return CustomerDocumentStatus.verified;
      case 'rejected':
        return CustomerDocumentStatus.rejected;
      case 'not_uploaded':
      default:
        return CustomerDocumentStatus.notUploaded;
    }
  }

  static String _statusToString(CustomerDocumentStatus status) {
    switch (status) {
      case CustomerDocumentStatus.notUploaded:
        return 'not_uploaded';
      case CustomerDocumentStatus.pending:
        return 'pending';
      case CustomerDocumentStatus.verified:
        return 'verified';
      case CustomerDocumentStatus.rejected:
        return 'rejected';
    }
  }

  static DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
