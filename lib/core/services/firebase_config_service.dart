import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseConfigService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>?> getTenantConfig(
    String tenantId,
  ) async {
    final doc = await _firestore
        .collection('tenants')
        .doc(tenantId)
        .get();

    if (!doc.exists) {
      return null;
    }

    return doc.data();
  }
}