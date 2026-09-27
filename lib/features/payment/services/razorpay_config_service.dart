import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/config/app_config.dart';
import '../models/razorpay_config.dart';

/// Manages tenant-specific Razorpay configuration.
///
/// Firestore:
///
/// tenants/{tenantId}
///   razorpay:
///     enabled
///     mode
///     keyId
///     currency
///     configured
///     updatedAt
///     updatedBy
///
/// IMPORTANT:
/// Razorpay Key Secret is intentionally NOT handled here.
/// It belongs on the trusted backend.
class RazorpayConfigService {
  RazorpayConfigService._();

  static final RazorpayConfigService instance =
      RazorpayConfigService._();

  factory RazorpayConfigService() => instance;

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  String get tenantId {
    final id = AppConfig.tenant.tenantId.trim();

    if (id.isEmpty) {
      throw Exception('Tenant ID is not available.');
    }

    return id;
  }

  DocumentReference<Map<String, dynamic>> get _tenantRef {
    return _firestore
        .collection('tenants')
        .doc(tenantId);
  }

  Future<RazorpayConfig> getConfig() async {
    final snapshot = await _tenantRef.get();

    if (!snapshot.exists || snapshot.data() == null) {
      return const RazorpayConfig();
    }

    final data = snapshot.data()!;

    final razorpayData = data['razorpay'];

    if (razorpayData is Map) {
      return RazorpayConfig.fromMap(
        Map<String, dynamic>.from(razorpayData),
      );
    }

    return const RazorpayConfig();
  }

  Stream<RazorpayConfig> watchConfig() {
    return _tenantRef.snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return const RazorpayConfig();
      }

      final data = snapshot.data()!;

      final razorpayData = data['razorpay'];

      if (razorpayData is Map) {
        return RazorpayConfig.fromMap(
          Map<String, dynamic>.from(razorpayData),
        );
      }

      return const RazorpayConfig();
    });
  }

  Future<void> saveConfig({
    required bool enabled,
    required String mode,
    required String keyId,
    String currency = 'INR',
  }) async {
    final normalizedMode = mode.trim().toLowerCase();

    if (normalizedMode != 'test' &&
        normalizedMode != 'live') {
      throw Exception(
        'Razorpay mode must be test or live.',
      );
    }

    final normalizedKeyId = keyId.trim();

    if (normalizedKeyId.isEmpty) {
      throw Exception(
        'Razorpay Key ID is required.',
      );
    }

    final normalizedCurrency =
        currency.trim().toUpperCase();

    if (normalizedCurrency.isEmpty) {
      throw Exception(
        'Currency is required.',
      );
    }

    final user = _auth.currentUser;

    if (user == null) {
      throw Exception(
        'You must be logged in to update Razorpay settings.',
      );
    }

    final config = RazorpayConfig(
      enabled: enabled,
      mode: normalizedMode,
      keyId: normalizedKeyId,
      currency: normalizedCurrency,
      configured: true,
      updatedAt: DateTime.now(),
      updatedBy: user.uid,
    );

    await _tenantRef.set(
      {
        'razorpay': config.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> enable() async {
    final current = await getConfig();

    if (current.keyId.trim().isEmpty) {
      throw Exception(
        'Configure the Razorpay Key ID before enabling Razorpay.',
      );
    }

    final user = _auth.currentUser;

    if (user == null) {
      throw Exception(
        'You must be logged in.',
      );
    }

    await _tenantRef.set(
      {
        'razorpay': {
          'enabled': true,
          'mode': current.mode,
          'keyId': current.keyId,
          'currency': current.currency,
          'configured': true,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': user.uid,
        },
      },
      SetOptions(merge: true),
    );
  }

  Future<void> disable() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception(
        'You must be logged in.',
      );
    }

    await _tenantRef.set(
      {
        'razorpay': {
          'enabled': false,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': user.uid,
        },
      },
      SetOptions(merge: true),
    );
  }

  Future<void> updateMode(String mode) async {
    final normalized = mode.trim().toLowerCase();

    if (normalized != 'test' &&
        normalized != 'live') {
      throw Exception(
        'Invalid Razorpay mode.',
      );
    }

    final current = await getConfig();

    final user = _auth.currentUser;

    if (user == null) {
      throw Exception(
        'You must be logged in.',
      );
    }

    await _tenantRef.set(
      {
        'razorpay': {
          'mode': normalized,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': user.uid,
        },
      },
      SetOptions(merge: true),
    );
  }
}