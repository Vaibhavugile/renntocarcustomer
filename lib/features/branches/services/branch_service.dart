import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/branch.dart';

class BranchService {
  BranchService._();

  static final BranchService instance = BranchService._();

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  // ============================================================
  // TENANT BRANCH COLLECTION
  // ============================================================

  CollectionReference<Map<String, dynamic>> _branches(
    String tenantId,
  ) {
    if (tenantId.trim().isEmpty) {
      throw ArgumentError(
        'Tenant ID cannot be empty.',
      );
    }

    return _firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('branches');
  }

  // ============================================================
  // GET ACTIVE BRANCHES
  // ============================================================

  Future<List<Branch>> getBranches(
    String tenantId,
  ) async {
    final snapshot = await _branches(tenantId)
        .where('isActive', isEqualTo: true)
        .get();

    final branches = snapshot.docs
        .map(
          (doc) => Branch.fromMap(
            doc.id,
            doc.data(),
          ),
        )
        .toList();

    _sortBranches(branches);

    return branches;
  }

  // ============================================================
  // GET ALL BRANCHES
  // ============================================================

  Future<List<Branch>> getAllBranches(
    String tenantId,
  ) async {
    final snapshot = await _branches(tenantId).get();

    final branches = snapshot.docs
        .map(
          (doc) => Branch.fromMap(
            doc.id,
            doc.data(),
          ),
        )
        .toList();

    _sortBranches(branches);

    return branches;
  }

  // ============================================================
  // GET BRANCH BY ID
  // ============================================================

  Future<Branch?> getBranchById({
    required String tenantId,
    required String branchId,
  }) async {
    if (branchId.trim().isEmpty) {
      return null;
    }

    final doc = await _branches(tenantId)
        .doc(branchId)
        .get();

    if (!doc.exists || doc.data() == null) {
      return null;
    }

    return Branch.fromMap(
      doc.id,
      doc.data()!,
    );
  }

  // ============================================================
  // CREATE BRANCH
  // ============================================================

  Future<String> createBranch({
    required String tenantId,
    required Branch branch,
  }) async {
    final normalizedTenantId =
        tenantId.trim();

    if (normalizedTenantId.isEmpty) {
      throw ArgumentError(
        'Tenant ID cannot be empty.',
      );
    }

    final collection =
        _branches(normalizedTenantId);

    final doc = collection.doc();

    final data = branch.toMap();

    // Never trust a tenantId coming from the UI/model.
    data['tenantId'] =
        normalizedTenantId;

    data['createdAt'] =
        FieldValue.serverTimestamp();

    data['updatedAt'] =
        FieldValue.serverTimestamp();

    await doc.set(data);

    return doc.id;
  }

  // ============================================================
  // UPDATE BRANCH
  // ============================================================

  Future<void> updateBranch({
    required String tenantId,
    required String branchId,
    required Branch branch,
  }) async {
    final normalizedTenantId =
        tenantId.trim();

    final normalizedBranchId =
        branchId.trim();

    if (normalizedTenantId.isEmpty) {
      throw ArgumentError(
        'Tenant ID cannot be empty.',
      );
    }

    if (normalizedBranchId.isEmpty) {
      throw ArgumentError(
        'Branch ID cannot be empty.',
      );
    }

    final data = branch.toMap();

    // Always enforce the current tenant.
    data['tenantId'] =
        normalizedTenantId;

    data['updatedAt'] =
        FieldValue.serverTimestamp();

    await _branches(normalizedTenantId)
        .doc(normalizedBranchId)
        .update(data);
  }

  // ============================================================
  // ACTIVATE BRANCH
  // ============================================================

  Future<void> activateBranch({
    required String tenantId,
    required String branchId,
  }) async {
    await _branches(tenantId)
        .doc(branchId)
        .update({
      'tenantId': tenantId,
      'isActive': true,
      'updatedAt':
          FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // DEACTIVATE BRANCH
  // ============================================================

  Future<void> deactivateBranch({
    required String tenantId,
    required String branchId,
  }) async {
    await _branches(tenantId)
        .doc(branchId)
        .update({
      'tenantId': tenantId,
      'isActive': false,
      'updatedAt':
          FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // WATCH ACTIVE BRANCHES
  // ============================================================

  Stream<List<Branch>> watchBranches(
    String tenantId,
  ) {
    return _branches(tenantId)
        .where(
          'isActive',
          isEqualTo: true,
        )
        .snapshots()
        .map((snapshot) {
      final branches = snapshot.docs
          .map(
            (doc) => Branch.fromMap(
              doc.id,
              doc.data(),
            ),
          )
          .toList();

      _sortBranches(branches);

      return branches;
    });
  }

  // ============================================================
  // WATCH ALL BRANCHES
  // ============================================================

  Stream<List<Branch>> watchAllBranches(
    String tenantId,
  ) {
    return _branches(tenantId)
        .snapshots()
        .map((snapshot) {
      final branches = snapshot.docs
          .map(
            (doc) => Branch.fromMap(
              doc.id,
              doc.data(),
            ),
          )
          .toList();

      _sortBranches(branches);

      return branches;
    });
  }

  // ============================================================
  // SORT
  // ============================================================

  void _sortBranches(
    List<Branch> branches,
  ) {
    branches.sort((a, b) {
      final nameA = a.name.toLowerCase();
      final nameB = b.name.toLowerCase();

      return nameA.compareTo(nameB);
    });
  }
}