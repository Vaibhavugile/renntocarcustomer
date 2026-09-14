import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/customer_document.dart';

class DocumentService {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;

  DocumentService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _auth = auth ?? FirebaseAuth.instance;

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
  }) async {
    _validateIdentity(tenantId, customerId);

    final snapshot = await _documents(tenantId, customerId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => CustomerDocument.fromMap(
              doc.id,
              doc.data(),
            ))
        .toList();
  }

  Future<CustomerDocument?> getDocument({
    required String tenantId,
    required String customerId,
    required CustomerDocumentType type,
  }) async {
    _validateIdentity(tenantId, customerId);

    final snapshot = await _documents(tenantId, customerId)
        .where(
          'documentType',
          isEqualTo: _typeKey(type),
        )
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
  }) async {
    _validateIdentity(tenantId, customerId);

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

    final frontUrl = await frontRef.getDownloadURL();
    final backUrl = await backRef.getDownloadURL();

    final now = FieldValue.serverTimestamp();

    final data = {
      'tenantId': tenantId,
      'customerId': customerId,
      'documentType': documentKey,
      'documentNumber': documentNumber.trim(),
      'frontImageUrl': frontUrl,
      'backImageUrl': backUrl,
      'status': 'pending',
      'rejectionReason': '',
      'verifiedAt': null,
      'verifiedBy': '',
      'updatedAt': now,
      if (existing == null) 'createdAt': now,
    };

    await documentRef.set(
      data,
      SetOptions(merge: true),
    );

    // Keep the customer-level KYC status synchronized with the
    // document workflow. Full verification is still performed by
    // the admin/backend; uploading documents only moves the customer
    // into the pending state.
    await _firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('customers')
        .doc(customerId)
        .set(
      {
        'tenantId': tenantId,
        'customerId': customerId,
        'kycStatus': 'pending',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    final saved = await documentRef.get();

    if (!saved.exists || saved.data() == null) {
      throw Exception('Unable to save document information.');
    }

    return CustomerDocument.fromMap(
      saved.id,
      saved.data()!,
    );
  }

  Future<void> deleteDocument({
    required String tenantId,
    required String customerId,
    required CustomerDocumentType type,
  }) async {
    _validateIdentity(tenantId, customerId);

    final existing = await getDocument(
      tenantId: tenantId,
      customerId: customerId,
      type: type,
    );

    if (existing == null) return;

    final key = _typeKey(type);

    final folder = _storage.ref(
      'tenants/$tenantId/customers/$customerId/documents/$key',
    );

    try {
      await folder.child('front.jpg').delete();
    } catch (_) {}

    try {
      await folder.child('back.jpg').delete();
    } catch (_) {}

    await _documents(tenantId, customerId)
        .doc(existing.documentId)
        .delete();
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

  void _validateIdentity(
    String tenantId,
    String customerId,
  ) {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('User is not authenticated.');
    }

    if (tenantId.trim().isEmpty) {
      throw Exception('Tenant ID is required.');
    }

    if (customerId.trim().isEmpty) {
      throw Exception('Customer ID is required.');
    }

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
