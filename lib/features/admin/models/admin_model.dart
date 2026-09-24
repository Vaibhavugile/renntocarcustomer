import 'package:cloud_firestore/cloud_firestore.dart';

class Admin {
  final String adminId;
  final String tenantId;
  final String roleId;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  const Admin({
    required this.adminId,
    required this.tenantId,
    required this.roleId,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.updatedBy,
  });

  factory Admin.fromMap(
    String adminId,
    Map<String, dynamic> map,
  ) {
    return Admin(
      adminId: adminId,
      tenantId: map['tenantId']?.toString() ?? '',
      roleId: map['roleId']?.toString() ?? 'admin',
      isActive: map['isActive'] == true,
      createdAt: _toDateTime(map['createdAt']),
      updatedAt: _toDateTime(map['updatedAt']),
      createdBy: map['createdBy']?.toString(),
      updatedBy: map['updatedBy']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tenantId': tenantId,
      'roleId': roleId,
      'isActive': isActive,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'createdBy': createdBy,
      'updatedBy': updatedBy,
    };
  }

  Admin copyWith({
    String? roleId,
    bool? isActive,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return Admin(
      adminId: adminId,
      tenantId: tenantId,
      roleId: roleId ?? this.roleId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value;
    }

    if (value is Timestamp) {
      return value.toDate();
    }

    try {
      return value.toDate();
    } catch (_) {
      return DateTime.tryParse(
        value.toString(),
      );
    }
  }
}