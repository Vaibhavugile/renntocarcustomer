import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/branch.dart';

class BranchService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  Future<List<Branch>> getBranches(
    String tenantId,
  ) async {
    final snapshot = await _firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('branches')
        .where('isActive', isEqualTo: true)
        .get();

    return snapshot.docs
        .map(
          (doc) => Branch.fromMap(
            doc.id,
            doc.data(),
          ),
        )
        .toList();
  }
}