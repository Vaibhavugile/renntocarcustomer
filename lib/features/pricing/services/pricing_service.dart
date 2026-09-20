import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/pricing_config.dart';
import '../models/pricing_profile.dart';

/// Firebase data-access layer for tenant pricing.
///
/// Simple pricing structure:
///
/// tenants/{tenantId}/pricing/{pricingDocumentId}
/// tenants/{tenantId}/pricingProfiles/{pricingProfileId}
///
/// PricingService ONLY loads, parses and caches pricing configuration.
/// It does not calculate booking totals.
///
/// PricingProfile contains:
///   - hourlyPackages
///   - dailyPackages
///   - specialRates
///   - securityDepositConfig
///
/// There is no weekend / weekly / monthly rental pricing here.
class PricingService {
  PricingService._();

  static final PricingService instance =
      PricingService._();

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  PricingConfig? _cachedPricing;
  String? _cachedTenantId;
  String? _cachedPricingDocumentId;

  /// Cache is tenant-scoped so one tenant can never accidentally receive
  /// another tenant's pricing.
  final Map<String, PricingProfile> _profileCache =
      <String, PricingProfile>{};

  // ===========================================================================
  // FIRESTORE REFERENCES
  // ===========================================================================

  CollectionReference<Map<String, dynamic>>
      _tenantPricingCollection(
    String tenantId,
  ) {
    return _firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('pricing');
  }

  CollectionReference<Map<String, dynamic>>
      _pricingProfilesCollection(
    String tenantId,
  ) {
    return _firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('pricingProfiles');
  }

  // ===========================================================================
  // TENANT PRICING
  // ===========================================================================

  Future<PricingConfig> loadPricing({
    required String tenantId,
    String pricingDocumentId = 'pricing_rentocar',
    bool forceRefresh = false,
  }) async {
    final normalizedTenantId =
        tenantId.trim();
    final normalizedDocumentId =
        pricingDocumentId.trim();

    _validateTenantId(normalizedTenantId);
    _validateDocumentId(normalizedDocumentId);

    if (!forceRefresh &&
        _cachedPricing != null &&
        _cachedTenantId == normalizedTenantId &&
        _cachedPricingDocumentId ==
            normalizedDocumentId) {
      return _cachedPricing!;
    }

    try {
      final snapshot =
          await _tenantPricingCollection(
        normalizedTenantId,
      ).doc(normalizedDocumentId).get();

      if (!snapshot.exists) {
        throw Exception(
          'Pricing configuration not found for tenant '
          '"$normalizedTenantId" at '
          'pricing/$normalizedDocumentId.',
        );
      }

      final data = snapshot.data();

      if (data == null) {
        throw Exception(
          'Pricing configuration is empty for tenant '
          '"$normalizedTenantId".',
        );
      }

      // Load profiles independently from the tenant pricing document.
      // This keeps car/pricing-group configuration separate from global
      // tenant settings.
      final profiles =
          await loadPricingProfiles(
        tenantId: normalizedTenantId,
        forceRefresh: forceRefresh,
      );

      final pricingData =
          <String, dynamic>{
        ...data,
        'profiles': profiles
            .map(
              (profile) => <String, dynamic>{
                'id': profile.id,
                ...profile.toMap(),
              },
            )
            .toList(),
      };

      final pricing =
          PricingConfig.fromMap(
        snapshot.id,
        pricingData,
      );

      _cachedPricing = pricing;
      _cachedTenantId =
          normalizedTenantId;
      _cachedPricingDocumentId =
          normalizedDocumentId;

      return pricing;
    } on FirebaseException catch (e) {
      throw Exception(
        'Unable to load pricing for tenant '
        '"$normalizedTenantId": '
        '${e.message ?? e.code}',
      );
    } catch (e) {
      if (e is Exception) rethrow;

      throw Exception(
        'Unable to load pricing for tenant '
        '"$normalizedTenantId".',
      );
    }
  }

  Future<PricingConfig> refreshPricing({
    required String tenantId,
    String pricingDocumentId =
        'pricing_rentocar',
  }) {
    return loadPricing(
      tenantId: tenantId,
      pricingDocumentId:
          pricingDocumentId,
      forceRefresh: true,
    );
  }

  // ===========================================================================
  // SINGLE PRICING PROFILE
  // ===========================================================================

  Future<PricingProfile?> loadPricingProfile({
    required String tenantId,
    required String pricingProfileId,
    bool forceRefresh = false,
  }) async {
    final normalizedTenantId =
        tenantId.trim();
    final normalizedProfileId =
        pricingProfileId.trim();

    _validateTenantId(normalizedTenantId);

    if (normalizedProfileId.isEmpty) {
      throw ArgumentError(
        'pricingProfileId cannot be empty.',
      );
    }

    final cacheKey = _profileCacheKey(
      normalizedTenantId,
      normalizedProfileId,
    );

    if (!forceRefresh &&
        _profileCache.containsKey(cacheKey)) {
      return _profileCache[cacheKey];
    }

    try {
      final doc =
          await _pricingProfilesCollection(
        normalizedTenantId,
      ).doc(normalizedProfileId).get();

      if (!doc.exists) {
        return null;
      }

      final data = doc.data();

      if (data == null) {
        return null;
      }

      final profile =
          PricingProfile.fromMap(
        doc.id,
        data,
      );

      // Protect against a malformed profile that accidentally belongs to a
      // different tenant.
      final profileTenantId =
          profile.tenantId.trim();

      if (profileTenantId.isNotEmpty &&
          profileTenantId !=
              normalizedTenantId) {
        throw Exception(
          'Pricing profile "${doc.id}" belongs to tenant '
          '"$profileTenantId", not "$normalizedTenantId".',
        );
      }

      _profileCache[cacheKey] =
          profile;

      return profile;
    } on FirebaseException catch (e) {
      throw Exception(
        'Unable to load pricing profile '
        '"$normalizedProfileId": '
        '${e.message ?? e.code}',
      );
    } catch (e) {
      if (e is Exception) rethrow;

      throw Exception(
        'Unable to load pricing profile '
        '"$normalizedProfileId".',
      );
    }
  }

  Future<PricingProfile?> getPricingForCarFromFirebase({
    required String tenantId,
    required String pricingProfileId,
    bool forceRefresh = false,
  }) {
    return loadPricingProfile(
      tenantId: tenantId,
      pricingProfileId:
          pricingProfileId,
      forceRefresh: forceRefresh,
    );
  }

  // ===========================================================================
  // ALL PROFILES
  // ===========================================================================

  Future<List<PricingProfile>> loadPricingProfiles({
    required String tenantId,
    bool forceRefresh = false,
  }) async {
    final normalizedTenantId =
        tenantId.trim();

    _validateTenantId(
      normalizedTenantId,
    );

    if (!forceRefresh) {
      final cached = _profileCache
          .entries
          .where(
            (entry) => entry.key.startsWith(
              '$normalizedTenantId::',
            ),
          )
          .map(
            (entry) => entry.value,
          )
          .toList();

      if (cached.isNotEmpty) {
        return List.unmodifiable(cached);
      }
    }

    try {
      final snapshot =
          await _pricingProfilesCollection(
        normalizedTenantId,
      ).get();

      final profiles =
          <PricingProfile>[];

      for (final doc
          in snapshot.docs) {
        try {
          final profile =
              PricingProfile.fromMap(
            doc.id,
            doc.data(),
          );

          final profileTenantId =
              profile.tenantId.trim();

          if (profileTenantId.isNotEmpty &&
              profileTenantId !=
                  normalizedTenantId) {
            throw Exception(
              'Profile tenant mismatch.',
            );
          }

          profiles.add(profile);

          _profileCache[
            _profileCacheKey(
              normalizedTenantId,
              doc.id,
            )
          ] = profile;
        } catch (e) {
          throw Exception(
            'Invalid pricing profile '
            '"${doc.id}" for tenant '
            '"$normalizedTenantId": $e',
          );
        }
      }

      return List.unmodifiable(
        profiles,
      );
    } on FirebaseException catch (e) {
      throw Exception(
        'Unable to load pricing profiles for tenant '
        '"$normalizedTenantId": '
        '${e.message ?? e.code}',
      );
    } catch (e) {
      if (e is Exception) rethrow;

      throw Exception(
        'Unable to load pricing profiles for tenant '
        '"$normalizedTenantId".',
      );
    }
  }

  // ===========================================================================
  // CACHE LOOKUPS
  // ===========================================================================

  PricingConfig? get cachedPricing =>
      _cachedPricing;

  String? get cachedTenantId =>
      _cachedTenantId;

  bool get isLoaded =>
      _cachedPricing != null;

  PricingProfile? getPricingForCar(
    String pricingProfileId,
  ) {
    final normalizedProfileId =
        pricingProfileId.trim();

    if (normalizedProfileId.isEmpty) {
      return null;
    }

    // First search the complete tenant pricing object.
    final pricing = _cachedPricing;

    if (pricing != null) {
      final profile =
          pricing.getProfile(
        normalizedProfileId,
      );

      if (profile != null) {
        return profile;
      }
    }

    // Then use the tenant-scoped profile cache.
    final tenantId = _cachedTenantId;

    if (tenantId == null ||
        tenantId.isEmpty) {
      return null;
    }

    return _profileCache[
      _profileCacheKey(
        tenantId,
        normalizedProfileId,
      )
    ];
  }

  // ===========================================================================
  // PROFILE CACHE MANAGEMENT
  // ===========================================================================

  void cachePricingProfile({
    required String tenantId,
    required PricingProfile profile,
  }) {
    final normalizedTenantId =
        tenantId.trim();

    _validateTenantId(
      normalizedTenantId,
    );

    _profileCache[
      _profileCacheKey(
        normalizedTenantId,
        profile.id,
      )
    ] = profile;
  }

  void clearProfileCache({
    String? tenantId,
  }) {
    final normalizedTenantId =
        tenantId?.trim();

    if (normalizedTenantId == null ||
        normalizedTenantId.isEmpty) {
      _profileCache.clear();
      return;
    }

    final prefix =
        '$normalizedTenantId::';

    _profileCache.removeWhere(
      (key, value) =>
          key.startsWith(prefix),
    );
  }

  // ===========================================================================
  // SET / CLEAR
  // ===========================================================================

  /// Places already-loaded configuration in memory.
  ///
  /// This does not write anything to Firebase and does not create fallback
  /// pricing.
  void setPricing(
    PricingConfig pricing, {
    String? tenantId,
    String? pricingDocumentId,
  }) {
    _cachedPricing = pricing;

    _cachedTenantId =
        tenantId?.trim();

    _cachedPricingDocumentId =
        pricingDocumentId?.trim();

    final normalizedTenantId =
        _cachedTenantId;

    if (normalizedTenantId == null ||
        normalizedTenantId.isEmpty) {
      return;
    }

    try {
      for (final profile
          in pricing.profiles) {
        _profileCache[
          _profileCacheKey(
            normalizedTenantId,
            profile.id,
          )
        ] = profile;
      }
    } catch (_) {
      // The main PricingConfig cache is still valid.
    }
  }

  void clearCache() {
    _cachedPricing = null;
    _cachedTenantId = null;
    _cachedPricingDocumentId = null;
    _profileCache.clear();
  }

  // ===========================================================================
  // INTERNAL HELPERS
  // ===========================================================================

  String _profileCacheKey(
    String tenantId,
    String pricingProfileId,
  ) {
    return '${tenantId.trim()}::'
        '${pricingProfileId.trim()}';
  }

  void _validateTenantId(
    String tenantId,
  ) {
    if (tenantId.isEmpty) {
      throw ArgumentError(
        'tenantId cannot be empty.',
      );
    }
  }

  void _validateDocumentId(
    String documentId,
  ) {
    if (documentId.isEmpty) {
      throw ArgumentError(
        'pricingDocumentId cannot be empty.',
      );
    }
  }
}
