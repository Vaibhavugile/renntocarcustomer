import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/customer.dart';

class CustomerService {
  CustomerService();

  static final CustomerService instance = CustomerService();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  CollectionReference<Map<String, dynamic>> _customers(
    String tenantId,
  ) {
    return _firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('customers');
  }

  // ============================================================
  // IDENTITY HELPERS
  //
  // Architecture:
  // customerId == Firestore document ID == firebaseUid == Auth UID
  // ============================================================

  Customer _customerFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = Map<String, dynamic>.from(doc.data());

    // The document ID is the authoritative customer identity.
    data['customerId'] = doc.id;
    data['firebaseUid'] = doc.id;

    return Customer.fromMap(
      doc.id,
      data,
    );
  }

  Customer _customerFromSingleDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    if (!doc.exists || doc.data() == null) {
      throw Exception('Customer document does not exist.');
    }

    final data = Map<String, dynamic>.from(doc.data()!);

    // The document ID is the authoritative customer identity.
    data['customerId'] = doc.id;
    data['firebaseUid'] = doc.id;

    return Customer.fromMap(
      doc.id,
      data,
    );
  }

  // ============================================================
  // CURRENT CUSTOMER
  // ============================================================

  Future<Customer?> getCurrentCustomer({
    required String tenantId,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      return null;
    }

    final customerRef = _customers(tenantId).doc(user.uid);

    final doc = await customerRef.get();

    if (!doc.exists || doc.data() == null) {
      return null;
    }

    final customer = _customerFromSingleDocument(doc);

    if (customer.tenantId != tenantId) {
      return null;
    }

    return customer;
  }

  // ============================================================
  // CREATE CUSTOMER AFTER NORMAL CUSTOMER OTP LOGIN
  // ============================================================

  Future<Customer> createCustomerIfNotExists({
    required String tenantId,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception(
        'User is not authenticated.',
      );
    }

    final customerRef = _customers(tenantId).doc(user.uid);

    final existing = await customerRef.get();

    if (existing.exists && existing.data() != null) {
      return _customerFromSingleDocument(existing);
    }

    final now = FieldValue.serverTimestamp();

    final customer = Customer(
      customerId: user.uid,
      tenantId: tenantId,
      fullName: '',
      phone: user.phoneNumber ?? '',
      email: user.email ?? '',
      profileImageUrl: '',
      dateOfBirth: '',
      gender: '',
      address: null,
      emergencyContact: null,
      kycStatus: 'not_started',
      profileCompleted: false,
      isActive: true,
      totalBookings: 0,
      completedBookings: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await customerRef.set({
      ...customer.toMap(),
      'customerId': user.uid,
      'firebaseUid': user.uid,
      'tenantId': tenantId,
      'createdAt': now,
      'updatedAt': now,
    });

    final saved = await customerRef.get();

    if (!saved.exists || saved.data() == null) {
      throw Exception(
        'Unable to create customer profile.',
      );
    }

    return _customerFromSingleDocument(saved);
  }

  // ============================================================
  // ADMIN CREATE CUSTOMER
  //
  // IMPORTANT:
  // This does NOT directly create the Firestore customer.
  //
  // Flutter -> Cloud Function
  // Cloud Function -> Firebase Auth
  // Firebase Auth -> UID
  // Cloud Function -> customers/{UID}
  // ============================================================

  Future<String> createCustomerByAdmin({
    required String tenantId,
    required String fullName,
    required String phone,
    String email = '',
  }) async {
    if (tenantId.trim().isEmpty) {
      throw Exception(
        'Tenant ID is required.',
      );
    }

    if (fullName.trim().isEmpty) {
      throw Exception(
        'Customer name is required.',
      );
    }

    if (phone.trim().isEmpty) {
      throw Exception(
        'Customer phone number is required.',
      );
    }

    final callable = _functions.httpsCallable(
      'createCustomer',
    );

    try {
      final result = await callable.call({
        'tenantId': tenantId.trim(),
        'fullName': fullName.trim(),
        'phone': phone.trim(),
        'email': email.trim(),
      });

      if (result.data is! Map) {
        throw Exception(
          'Invalid response received from createCustomer.',
        );
      }

      final data = Map<String, dynamic>.from(
        result.data as Map,
      );

      final success = data['success'] == true;

      if (!success) {
        throw Exception(
          data['message'] ??
              'Customer could not be created.',
        );
      }

      final customerId =
          data['customerId']?.toString() ?? '';

      if (customerId.isEmpty) {
        throw Exception(
          'Customer was created but no customer ID was returned.',
        );
      }

      return customerId;
    } on FirebaseFunctionsException catch (e) {
      switch (e.code) {
        case 'unauthenticated':
          throw Exception(
            'Your admin session has expired. Please login again.',
          );

        case 'permission-denied':
          throw Exception(
            e.message ??
                'You do not have permission to create customers.',
          );

        case 'invalid-argument':
          throw Exception(
            e.message ??
                'Please check the customer information.',
          );

        case 'already-exists':
          throw Exception(
            e.message ??
                'A customer with this phone number already exists.',
          );

        case 'not-found':
          throw Exception(
            e.message ??
                'Tenant was not found.',
          );

        default:
          throw Exception(
            e.message ??
                'Unable to create customer. Please try again.',
          );
      }
    } catch (e) {
      throw Exception(
        e.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
    }
  }

  // ============================================================
  // ADMIN GET ALL CUSTOMERS
  // ============================================================

  Future<List<Customer>> getAllCustomers({
    required String tenantId,
    bool activeOnly = false,
  }) async {
    Query<Map<String, dynamic>> query =
        _customers(tenantId);

    if (activeOnly) {
      query = query.where(
        'isActive',
        isEqualTo: true,
      );
    }

    final snapshot = await query.get();

    final customers = snapshot.docs
        .map(_customerFromDocument)
        .where(
          (customer) =>
              customer.tenantId == tenantId,
        )
        .toList();

    customers.sort(
      (a, b) => a.fullName
          .toLowerCase()
          .compareTo(
            b.fullName.toLowerCase(),
          ),
    );

    return customers;
  }

  // ============================================================
  // ADMIN GET CUSTOMER
  // ============================================================

  Future<Customer?> getCustomer({
    required String tenantId,
    required String customerId,
  }) async {
    final doc = await _customers(tenantId)
        .doc(customerId)
        .get();

    if (!doc.exists || doc.data() == null) {
      return null;
    }

    final customer = Customer.fromMap(
      doc.id,
      doc.data()!,
    );

    if (customer.tenantId != tenantId) {
      throw Exception(
        'Tenant mismatch.',
      );
    }

    return customer;
  }

  // ============================================================
  // GET CUSTOMER BY PHONE
  // ============================================================

  Future<Customer?> getCustomerByPhone({
    required String tenantId,
    required String phone,
  }) async {
    final normalized = phone.trim();

    if (normalized.isEmpty) {
      return null;
    }

    final snapshot = await _customers(tenantId)
        .where(
          'phone',
          isEqualTo: normalized,
        )
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    final doc = snapshot.docs.first;

    final customer = _customerFromSingleDocument(doc);

    if (customer.tenantId != tenantId) {
      return null;
    }

    return customer;
  }

  // ============================================================
  // ADMIN UPDATE CUSTOMER
  // ============================================================

  Future<void> updateCustomerForAdmin({
    required String tenantId,
    required Customer customer,
  }) async {
    if (customer.customerId.trim().isEmpty) {
      throw Exception(
        'Customer ID is required.',
      );
    }

    if (customer.tenantId != tenantId) {
      throw Exception(
        'Tenant mismatch.',
      );
    }

    await _customers(tenantId)
        .doc(customer.customerId)
        .update({
      ...customer.toMap(),
      'customerId': customer.customerId,
      'firebaseUid': customer.customerId,
      'tenantId': tenantId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // ADMIN ACTIVATE / DEACTIVATE CUSTOMER
  // ============================================================

  Future<void> setCustomerActive({
    required String tenantId,
    required String customerId,
    required bool isActive,
  }) async {
    await _customers(tenantId)
        .doc(customerId)
        .update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // CUSTOMER UPDATE OWN PROFILE
  // ============================================================

  Future<void> updateCustomer({
    required String tenantId,
    required Customer customer,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception(
        'User is not authenticated.',
      );
    }

    if (user.uid != customer.customerId) {
      throw Exception(
        'Customer identity mismatch.',
      );
    }

    if (customer.tenantId != tenantId) {
      throw Exception(
        'Tenant mismatch.',
      );
    }

    await _customers(tenantId)
        .doc(customer.customerId)
        .update({
      ...customer.toMap(),
      'customerId': customer.customerId,
      'firebaseUid': customer.customerId,
      'tenantId': tenantId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // WATCH CUSTOMERS
  // ============================================================

  Stream<List<Customer>> watchCustomers({
    required String tenantId,
  }) {
    return _customers(tenantId)
        .snapshots()
        .map((snapshot) {
      final customers = snapshot.docs
          .map(_customerFromDocument)
          .where(
            (customer) =>
                customer.tenantId == tenantId,
          )
          .toList();

      customers.sort(
        (a, b) => a.fullName
            .toLowerCase()
            .compareTo(
              b.fullName.toLowerCase(),
            ),
      );

      return customers;
    });
  }
}