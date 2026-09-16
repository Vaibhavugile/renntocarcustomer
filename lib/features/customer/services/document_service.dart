import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/customer_document.dart';

class DocumentService {
  DocumentService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> _documents(
    String tenantId,
    String customerId,
  ) {
    return _firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('customers')
        .doc(customerId)
        .collection('documents');
  }

  Future<List<CustomerDocument>> getDocuments({
    required String tenantId,
    required String customerId,
    bool admin = false,
  }) async {
    if (!admin) {
      _validateIdentity(tenantId, customerId);
    }

    final snapshot = await _documents(tenantId, customerId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => CustomerDocument.fromMap(doc.id, doc.data()))
        .toList();
  }

  Future<CustomerDocument?> getDocument({
    required String tenantId,
    required String customerId,
    required CustomerDocumentType type,
    bool admin = false,
  }) async {
    if (!admin) {
      _validateIdentity(tenantId, customerId);
    }

    final snapshot = await _documents(tenantId, customerId)
        .where('documentType', isEqualTo: _typeKey(type))
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final doc = snapshot.docs.first;
    return CustomerDocument.fromMap(doc.id, doc.data());
  }

  Future<CustomerDocument> saveDocument({
    required String tenantId,
    required String customerId,
    required CustomerDocumentType type,
    required String documentNumber,
    required File frontFile,
    required File backFile,
    bool admin = false,
  }) async {
    if (!admin) {
      _validateIdentity(tenantId, customerId);
    }

    if (documentNumber.trim().isEmpty) {
      throw Exception('Document number is required.');
    }
    if (!await frontFile.exists()) {
      throw Exception('Front document image was not found.');
    }
    if (!await backFile.exists()) {
      throw Exception('Back document image was not found.');
    }

    final existing = await getDocument(
      tenantId: tenantId,
      customerId: customerId,
      type: type,
      admin: admin,
    );

    final documentRef = existing == null
        ? _documents(tenantId, customerId).doc()
        : _documents(tenantId, customerId).doc(existing.documentId);

    final documentKey = _typeKey(type);

    final frontRef = _storage.ref(
      'tenants/$tenantId/customers/$customerId/documents/$documentKey/front.jpg',
    );
    final backRef = _storage.ref(
      'tenants/$tenantId/customers/$customerId/documents/$documentKey/back.jpg',
    );

    await frontRef.putFile(
      frontFile,
      SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'tenantId': tenantId,
          'customerId': customerId,
          'documentType': documentKey,
          'side': 'front',
        },
      ),
    );

    await backRef.putFile(
      backFile,
      SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'tenantId': tenantId,
          'customerId': customerId,
          'documentType': documentKey,
          'side': 'back',
        },
      ),
    );

    final data = {
      'tenantId': tenantId,
      'customerId': customerId,
      'documentType': documentKey,
      'documentNumber': documentNumber.trim(),
      'frontImageUrl': await frontRef.getDownloadURL(),
      'backImageUrl': await backRef.getDownloadURL(),
      'status': 'pending',
      'rejectionReason': '',
      'verifiedAt': null,
      'verifiedBy': '',
      'updatedAt': FieldValue.serverTimestamp(),
      if (existing == null) 'createdAt': FieldValue.serverTimestamp(),
    };

    await documentRef.set(data, SetOptions(merge: true));

    await _firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('customers')
        .doc(customerId)
        .set({
      'tenantId': tenantId,
      'customerId': customerId,
      'kycStatus': 'pending',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final saved = await documentRef.get();
    if (!saved.exists || saved.data() == null) {
      throw Exception('Unable to save document information.');
    }

    return CustomerDocument.fromMap(saved.id, saved.data()!);
  }

  Future<void> verifyDocument({
    required String tenantId,
    required String customerId,
    required String documentId,
    required String adminId,
  }) async {
    await _documents(tenantId, customerId).doc(documentId).update({
      'status': 'verified',
      'rejectionReason': '',
      'verifiedAt': FieldValue.serverTimestamp(),
      'verifiedBy': adminId,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _syncCustomerKycStatus(tenantId, customerId);
  }

  Future<void> rejectDocument({
    required String tenantId,
    required String customerId,
    required String documentId,
    required String adminId,
    required String reason,
  }) async {
    if (reason.trim().isEmpty) {
      throw Exception('Rejection reason is required.');
    }

    await _documents(tenantId, customerId).doc(documentId).update({
      'status': 'rejected',
      'rejectionReason': reason.trim(),
      'verifiedAt': null,
      'verifiedBy': adminId,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _syncCustomerKycStatus(tenantId, customerId);
  }

  Future<void> _syncCustomerKycStatus(
    String tenantId,
    String customerId,
  ) async {
    final docs = await getDocuments(
      tenantId: tenantId,
      customerId: customerId,
      admin: true,
    );

    final license = docs.any((d) =>
        d.type == CustomerDocumentType.drivingLicense &&
        d.status == CustomerDocumentStatus.verified);

    final governmentId = docs.any((d) =>
        d.type == CustomerDocumentType.governmentId &&
        d.status == CustomerDocumentStatus.verified);

    String status = 'not_started';

    if (docs.any((d) => d.status == CustomerDocumentStatus.rejected)) {
      status = 'rejected';
    } else if (license && governmentId) {
      status = 'verified';
    } else if (docs.any((d) => d.status == CustomerDocumentStatus.pending)) {
      status = 'pending';
    }

    await _firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('customers')
        .doc(customerId)
        .set({
      'kycStatus': status,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<bool> hasVerifiedRequiredDocuments({
    required String tenantId,
    required String customerId,
  }) async {
    final documents = await getDocuments(
      tenantId: tenantId,
      customerId: customerId,
    );

    final licenseVerified = documents.any(
      (document) =>
          document.type == CustomerDocumentType.drivingLicense &&
          document.isVerified,
    );

    final governmentIdVerified = documents.any(
      (document) =>
          document.type == CustomerDocumentType.governmentId &&
          document.isVerified,
    );

    return licenseVerified && governmentIdVerified;
  }

  void _validateIdentity(String tenantId, String customerId) {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User is not authenticated.');
    if (tenantId.trim().isEmpty) throw Exception('Tenant ID is required.');
    if (customerId.trim().isEmpty) throw Exception('Customer ID is required.');
    if (user.uid != customerId) {
      throw Exception('Customer identity mismatch.');
    }
  }

  String _typeKey(CustomerDocumentType type) {
    switch (type) {
      case CustomerDocumentType.drivingLicense:
        return 'driving_license';
      case CustomerDocumentType.governmentId:
        return 'government_id';
    }
  }
}
