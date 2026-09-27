import 'package:cloud_firestore/cloud_firestore.dart';

/// Tenant-specific Razorpay configuration.
///
/// IMPORTANT:
/// - keyId is safe to return to the Flutter app.
/// - keySecret MUST NOT be stored in this client-readable document.
/// - The secret will be stored/configured on the backend in a later step.
class RazorpayConfig {
  final bool enabled;

  /// test / live
  final String mode;

  /// rzp_test_xxx / rzp_live_xxx
  final String keyId;

  /// Currently INR, but kept configurable for future expansion.
  final String currency;

  /// True when the tenant has completed the configuration.
  final bool configured;

  final DateTime? updatedAt;

  final String? updatedBy;

  const RazorpayConfig({
    this.enabled = false,
    this.mode = 'test',
    this.keyId = '',
    this.currency = 'INR',
    this.configured = false,
    this.updatedAt,
    this.updatedBy,
  });

  bool get isTestMode => mode == 'test';

  bool get isLiveMode => mode == 'live';

  bool get isValid {
    return enabled &&
        keyId.trim().isNotEmpty &&
        (mode == 'test' || mode == 'live') &&
        currency.trim().isNotEmpty;
  }

  RazorpayConfig copyWith({
    bool? enabled,
    String? mode,
    String? keyId,
    String? currency,
    bool? configured,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return RazorpayConfig(
      enabled: enabled ?? this.enabled,
      mode: mode ?? this.mode,
      keyId: keyId ?? this.keyId,
      currency: currency ?? this.currency,
      configured: configured ?? this.configured,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'mode': mode,
      'keyId': keyId,
      'currency': currency,
      'configured': configured,
      'updatedAt': updatedAt == null
          ? null
          : Timestamp.fromDate(updatedAt!),
      'updatedBy': updatedBy,
    };
  }

  factory RazorpayConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const RazorpayConfig();
    }

    DateTime? updatedAt;

    final rawUpdatedAt = map['updatedAt'];

    if (rawUpdatedAt is Timestamp) {
      updatedAt = rawUpdatedAt.toDate();
    } else if (rawUpdatedAt is DateTime) {
      updatedAt = rawUpdatedAt;
    }

    final mode = (map['mode']?.toString() ?? 'test').trim().toLowerCase();

    return RazorpayConfig(
      enabled: map['enabled'] == true,
      mode: mode == 'live' ? 'live' : 'test',
      keyId: map['keyId']?.toString().trim() ?? '',
      currency: map['currency']?.toString().trim().toUpperCase() ?? 'INR',
      configured: map['configured'] == true,
      updatedAt: updatedAt,
      updatedBy: map['updatedBy']?.toString().trim(),
    );
  }

  @override
  String toString() {
    return 'RazorpayConfig('
        'enabled: $enabled, '
        'mode: $mode, '
        'keyId: $keyId, '
        'currency: $currency, '
        'configured: $configured'
        ')';
  }
}