import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserRoleResult {
  final bool isAdmin;
  final bool isActive;
  final String? roleId;
  final String? tenantId;

  const UserRoleResult({
    required this.isAdmin,
    required this.isActive,
    this.roleId,
    this.tenantId,
  });

  const UserRoleResult.customer({
    this.tenantId,
  })  : isAdmin = false,
        isActive = true,
        roleId = null;

  const UserRoleResult.admin({
    required this.tenantId,
    required this.roleId,
    required this.isActive,
  }) : isAdmin = true;
}

class UserRoleService {
  UserRoleService._();

  static final UserRoleService instance = UserRoleService._();

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  Future<UserRoleResult> getCurrentUserRole({
    required String tenantId,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('User is not authenticated.');
    }

    final adminRef = _firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('admins')
        .doc(user.uid);

    final adminDoc = await adminRef.get();

    if (adminDoc.exists) {
      final data = adminDoc.data() ?? {};

      final storedTenantId =
          data['tenantId']?.toString() ?? '';

      if (storedTenantId != tenantId) {
        throw Exception(
          'Admin tenant mismatch.',
        );
      }

      final isActive =
          data['isActive'] == true;

      if (!isActive) {
        return UserRoleResult.admin(
          tenantId: tenantId,
          roleId:
              data['roleId']?.toString() ?? 'admin',
          isActive: false,
        );
      }

      return UserRoleResult.admin(
        tenantId: tenantId,
        roleId:
            data['roleId']?.toString() ?? 'admin',
        isActive: true,
      );
    }

    return UserRoleResult.customer(
      tenantId: tenantId,
    );
  }
}