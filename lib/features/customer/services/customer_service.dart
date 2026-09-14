import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/customer.dart';

class CustomerService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  Future<Customer?> getCurrentCustomer({
    required String tenantId,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      return null;
    }

    final doc = await _firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('customers')
        .doc(user.uid)
        .get();

    if (!doc.exists || doc.data() == null) {
      return null;
    }

    return Customer.fromMap(
      doc.id,
      doc.data()!,
    );
  }

  Future<Customer> createCustomerIfNotExists({
    required String tenantId,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception(
        'User is not authenticated.',
      );
    }

    final customerRef = _firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('customers')
        .doc(user.uid);

    final existing = await customerRef.get();

    if (existing.exists && existing.data() != null) {
      return Customer.fromMap(
        existing.id,
        existing.data()!,
      );
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

      'createdAt': now,
      'updatedAt': now,
    });

    final saved = await customerRef.get();

    return Customer.fromMap(
      saved.id,
      saved.data()!,
    );
  }

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

    await _firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('customers')
        .doc(customer.customerId)
        .update({
      ...customer.toMap(),
      'tenantId': tenantId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}