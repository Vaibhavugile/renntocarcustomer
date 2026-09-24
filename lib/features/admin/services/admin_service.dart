import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/admin_model.dart';

class AdminService {
  AdminService._();

  static final AdminService instance =
      AdminService._();

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  // ============================================================
  // ADMIN COLLECTION
  // ============================================================

  CollectionReference<Map<String, dynamic>>
      _adminsCollection(
    String tenantId,
  ) {
    return _firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('admins');
  }

  // ============================================================
  // GET ALL ADMINS
  // ============================================================

  Stream<List<Admin>> watchAdmins({
    required String tenantId,
  }) {
    return _adminsCollection(tenantId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) {
            return snapshot.docs
                .map(
                  (doc) => Admin.fromMap(
                    doc.id,
                    doc.data(),
                  ),
                )
                .toList();
          },
        );
  }

  // ============================================================
  // GET SINGLE ADMIN
  // ============================================================

  Future<Admin?> getAdmin({
    required String tenantId,
    required String adminId,
  }) async {
    final doc = await _adminsCollection(
      tenantId,
    ).doc(adminId).get();

    if (!doc.exists) {
      return null;
    }

    return Admin.fromMap(
      doc.id,
      doc.data() ?? {},
    );
  }

  // ============================================================
  // CHECK IF CUSTOMER IS ALREADY ADMIN
  // ============================================================

  Future<bool> isAdmin({
    required String tenantId,
    required String customerId,
  }) async {
    final doc = await _adminsCollection(
      tenantId,
    ).doc(customerId).get();

    return doc.exists;
  }

  // ============================================================
  // ADD EXISTING CUSTOMER AS ADMIN
  // ============================================================

  Future<void> addAdmin({
    required String tenantId,
    required String customerId,
    required String roleId,
  }) async {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      throw Exception(
        'You must be logged in to add an admin.',
      );
    }

    final adminRef = _adminsCollection(
      tenantId,
    ).doc(customerId);

    final existingAdmin =
        await adminRef.get();

    if (existingAdmin.exists) {
      throw Exception(
        'This customer is already an admin.',
      );
    }

    await adminRef.set({
      'uid': customerId,
      'tenantId': tenantId,
      'roleId': roleId,
      'isActive': true,
      'createdAt':
          FieldValue.serverTimestamp(),
      'updatedAt':
          FieldValue.serverTimestamp(),
      'createdBy': currentUser.uid,
      'updatedBy': currentUser.uid,
    });
  }

  // ============================================================
  // UPDATE ADMIN
  // ============================================================

  Future<void> updateAdmin({
    required String tenantId,
    required String adminId,
    required String roleId,
    required bool isActive,
  }) async {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      throw Exception(
        'You must be logged in.',
      );
    }

    await _adminsCollection(
      tenantId,
    ).doc(adminId).update({
      'roleId': roleId,
      'isActive': isActive,
      'updatedAt':
          FieldValue.serverTimestamp(),
      'updatedBy': currentUser.uid,
    });
  }

  // ============================================================
  // ACTIVATE / DEACTIVATE ADMIN
  // ============================================================

  Future<void> setAdminStatus({
    required String tenantId,
    required String adminId,
    required bool isActive,
  }) async {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      throw Exception(
        'You must be logged in.',
      );
    }

    await _adminsCollection(
      tenantId,
    ).doc(adminId).update({
      'isActive': isActive,
      'updatedAt':
          FieldValue.serverTimestamp(),
      'updatedBy': currentUser.uid,
    });
  }

  // ============================================================
  // REMOVE ADMIN
  // ============================================================

  Future<void> removeAdmin({
    required String tenantId,
    required String adminId,
  }) async {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      throw Exception(
        'You must be logged in.',
      );
    }

    if (currentUser.uid == adminId) {
      throw Exception(
        'You cannot remove yourself as admin.',
      );
    }

    await _adminsCollection(
      tenantId,
    ).doc(adminId).delete();
  }

  // ============================================================
  // SEARCH CUSTOMERS
  // ============================================================
  //
  // We load the tenant customers and filter locally.
  //
  // This keeps the implementation simple for the first version.
  // For very large customer collections, we should later introduce
  // dedicated search fields / indexes.
  // ============================================================

  Future<List<Map<String, dynamic>>>
      searchCustomers({
    required String tenantId,
    String search = '',
  }) async {
    final snapshot = await _firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('customers')
        .limit(100)
        .get();

    final query = search
        .trim()
        .toLowerCase();

    final results =
        <Map<String, dynamic>>[];

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final name =
          data['fullName']?.toString() ?? '';

      final phone =
          data['phone']?.toString() ?? '';

      final email =
          data['email']?.toString() ?? '';

      if (query.isNotEmpty &&
          !name.toLowerCase().contains(query) &&
          !phone
              .toLowerCase()
              .contains(query) &&
          !email
              .toLowerCase()
              .contains(query)) {
        continue;
      }

      results.add({
        'customerId': doc.id,
        ...data,
      });
    }

    return results;
  }

  // ============================================================
  // GET AVAILABLE CUSTOMERS
  // ============================================================
  //
  // Excludes customers who are already admins.
  // ============================================================

  Future<List<Map<String, dynamic>>>
      getAvailableCustomers({
    required String tenantId,
    String search = '',
  }) async {
    final customers =
        await searchCustomers(
      tenantId: tenantId,
      search: search,
    );

    final adminsSnapshot =
        await _adminsCollection(
      tenantId,
    ).get();

    final adminIds = adminsSnapshot.docs
        .map((doc) => doc.id)
        .toSet();

    return customers
        .where(
          (customer) {
            final customerId =
                customer['customerId']
                    ?.toString();

            return customerId != null &&
                !adminIds.contains(
                  customerId,
                );
          },
        )
        .toList();
  }
}