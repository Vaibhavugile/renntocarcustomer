import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/add_on.dart';
import '../models/cancellation_rule.dart';
import '../models/discount_rule.dart';
import '../models/extra_charge.dart';
import '../models/km_slab.dart';
import '../models/pricing_config.dart';
import '../models/pricing_profile.dart';
import '../models/protection_plan.dart';
import '../models/rental_package.dart';
import '../models/tax_rule.dart';

/// Firebase data-access layer for tenant pricing.
///
/// Firestore structure:
///
/// tenants/{tenantId}/pricing/{pricingDocumentId}
/// tenants/{tenantId}/pricingProfiles/{pricingProfileId}
///
/// PricingService only loads/caches configuration. It does not calculate
/// booking totals; PricingEngine remains responsible for calculation.
///
/// Important:
/// - Tenant IDs are always supplied by the caller.
/// - No Firebase branding/color values are used here.
/// - No dummy pricing is created.
/// - Vehicle pricing profiles are kept separate from tenant-level pricing.
/// - PricingProfile contains rental types, special-date rules, KM packages,
///   deposit configuration and pricingVersion.
class PricingService {
  PricingService._();

  static final PricingService instance = PricingService._();

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  PricingConfig? _cachedPricing;

  String? _cachedTenantId;

  // Individual profiles are also cached so a vehicle can be loaded without
  // requiring the complete tenant pricing document.
  final Map<String, PricingProfile> _profileCache =
      <String, PricingProfile>{};

  // ===========================================================================
  // FIREBASE REFERENCES
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
  // LOAD TENANT PRICING
  // ===========================================================================

  /// Loads the complete pricing configuration for a tenant.
  ///
  /// Default Firebase document:
  ///
  /// tenants/{tenantId}/pricing/pricing_rentocar
  ///
  /// You can pass another [pricingDocumentId] for another tenant.
  Future<PricingConfig> loadPricing({
    required String tenantId,
    String pricingDocumentId = 'pricing_rentocar',
    bool forceRefresh = false,
  }) async {
    final normalizedTenantId = tenantId.trim();
    final normalizedDocumentId =
        pricingDocumentId.trim();

    if (normalizedTenantId.isEmpty) {
      throw ArgumentError(
        'tenantId cannot be empty.',
      );
    }

    if (normalizedDocumentId.isEmpty) {
      throw ArgumentError(
        'pricingDocumentId cannot be empty.',
      );
    }

    // -------------------------------------------------------------------------
    // RETURN CACHE ONLY FOR THE SAME TENANT
    // -------------------------------------------------------------------------

    if (!forceRefresh &&
        _cachedPricing != null &&
        _cachedTenantId == normalizedTenantId) {
      return _cachedPricing!;
    }

    try {
      // -----------------------------------------------------------------------
      // LOAD TENANT-LEVEL PRICING
      // -----------------------------------------------------------------------

      final pricingSnapshot =
          await _tenantPricingCollection(
        normalizedTenantId,
      ).doc(normalizedDocumentId).get();

      if (!pricingSnapshot.exists) {
        throw Exception(
          'Pricing configuration not found for tenant '
          '"$normalizedTenantId" at pricing/$normalizedDocumentId.',
        );
      }

      final pricingData =
          pricingSnapshot.data();

      if (pricingData == null) {
        throw Exception(
          'Pricing configuration is empty for tenant '
          '"$normalizedTenantId".',
        );
      }

      // -----------------------------------------------------------------------
      // LOAD VEHICLE PRICING PROFILES
      // -----------------------------------------------------------------------

      final profilesSnapshot =
          await _pricingProfilesCollection(
        normalizedTenantId,
      ).get();

      final profiles =
          <PricingProfile>[];

      for (final doc in profilesSnapshot.docs) {
        final data = doc.data();

        try {
          final profile =
              PricingProfile.fromMap(
            doc.id,
            data,
          );

          profiles.add(profile);

          _profileCache[
            _profileCacheKey(
              normalizedTenantId,
              doc.id,
            )
          ] = profile;
        } catch (e) {
          throw Exception(
            'Invalid pricing profile "${doc.id}" '
            'for tenant "$normalizedTenantId": $e',
          );
        }
      }

      if (profiles.isEmpty) {
        throw Exception(
          'No vehicle pricing profiles found for tenant '
          '"$normalizedTenantId".',
        );
      }

      // -----------------------------------------------------------------------
      // BUILD COMPLETE PRICING CONFIG
      // -----------------------------------------------------------------------

      final pricing =
          PricingConfig.fromMap(
        pricingSnapshot.id,
        {
          ...pricingData,
          'profiles': profiles
              .map(
                (profile) => {
                  'id': profile.id,
                  ...profile.toMap(),
                },
              )
              .toList(),
        },
      );

      // -----------------------------------------------------------------------
      // UPDATE CACHE
      // -----------------------------------------------------------------------

      _cachedPricing = pricing;
      _cachedTenantId =
          normalizedTenantId;

      return pricing;
    } on FirebaseException catch (e) {
      throw Exception(
        'Unable to load pricing for tenant '
        '"$normalizedTenantId": '
        '${e.message ?? e.code}',
      );
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }

      throw Exception(
        'Unable to load pricing for tenant '
        '"$normalizedTenantId".',
      );
    }
  }

  // ===========================================================================
  // REFRESH TENANT PRICING
  // ===========================================================================

  Future<PricingConfig> refreshPricing({
    required String tenantId,
    String pricingDocumentId = 'pricing_rentocar',
  }) {
    return loadPricing(
      tenantId: tenantId,
      pricingDocumentId: pricingDocumentId,
      forceRefresh: true,
    );
  }

  // ===========================================================================
  // LOAD VEHICLE PRICING PROFILE
  // ===========================================================================

  /// Directly loads:
  ///
  /// tenants/{tenantId}/pricingProfiles/{pricingProfileId}
  ///
  /// Useful when only one selected vehicle needs its current pricing.
  Future<PricingProfile?> loadPricingProfile({
    required String tenantId,
    required String pricingProfileId,
    bool forceRefresh = false,
  }) async {
    final normalizedTenantId =
        tenantId.trim();

    final normalizedProfileId =
        pricingProfileId.trim();

    if (normalizedTenantId.isEmpty) {
      throw ArgumentError(
        'tenantId cannot be empty.',
      );
    }

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

      _profileCache[cacheKey] =
          profile;

      // Keep the complete tenant cache coherent when the profile belongs to
      // the currently cached tenant. Rebuilding the whole PricingConfig here
      // is intentionally avoided because PricingConfig may contain immutable
      // collections or additional tenant-level state.
      return profile;
    } on FirebaseException catch (e) {
      throw Exception(
        'Unable to load vehicle pricing for '
        '"$normalizedProfileId": '
        '${e.message ?? e.code}',
      );
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }

      throw Exception(
        'Unable to load vehicle pricing for '
        '"$normalizedProfileId".',
      );
    }
  }

  // ===========================================================================
  // LOAD ALL PRICING PROFILES
  // ===========================================================================

  Future<List<PricingProfile>> loadPricingProfiles({
    required String tenantId,
    bool forceRefresh = false,
  }) async {
    final normalizedTenantId =
        tenantId.trim();

    if (normalizedTenantId.isEmpty) {
      throw ArgumentError(
        'tenantId cannot be empty.',
      );
    }

    if (!forceRefresh) {
      final cached =
          _profileCache.entries
              .where(
                (entry) =>
                    entry.key.startsWith(
                  '$normalizedTenantId::',
                ),
              )
              .map(
                (entry) => entry.value,
              )
              .toList();

      if (cached.isNotEmpty) {
        return cached;
      }
    }

    try {
      final snapshot =
          await _pricingProfilesCollection(
        normalizedTenantId,
      ).get();

      final profiles =
          <PricingProfile>[];

      for (final doc in snapshot.docs) {
        final profile =
            PricingProfile.fromMap(
          doc.id,
          doc.data(),
        );

        profiles.add(profile);

        _profileCache[
          _profileCacheKey(
            normalizedTenantId,
            doc.id,
          )
        ] = profile;
      }

      return profiles;
    } on FirebaseException catch (e) {
      throw Exception(
        'Unable to load pricing profiles: '
        '${e.message ?? e.code}',
      );
    }
  }

  // ===========================================================================
  // GET CURRENT PRICING
  // ===========================================================================

  PricingConfig? get cachedPricing {
    return _cachedPricing;
  }

  // ===========================================================================
  // GET CACHED TENANT ID
  // ===========================================================================

  String? get cachedTenantId {
    return _cachedTenantId;
  }

  // ===========================================================================
  // IS LOADED
  // ===========================================================================

  bool get isLoaded {
    return _cachedPricing != null;
  }

  // ===========================================================================
  // FIND PRICING FOR CAR
  // ===========================================================================

  PricingProfile? getPricingForCar(
    String pricingProfileId,
  ) {
    final pricing =
        _cachedPricing;

    final normalizedProfileId =
        pricingProfileId.trim();

    if (normalizedProfileId.isEmpty) {
      return null;
    }

    if (pricing != null) {
      final profile =
          pricing.getProfile(
        normalizedProfileId,
      );

      if (profile != null) {
        return profile;
      }
    }

    if (_cachedTenantId != null) {
      return _profileCache[
        _profileCacheKey(
          _cachedTenantId!,
          normalizedProfileId,
        )
      ];
    }

    return null;
  }

  // ===========================================================================
  // GET PRICING FOR CAR - FIREBASE FIRST
  // ===========================================================================

  /// Returns the selected vehicle's pricing.
  ///
  /// Cache is checked first. If it is not present, Firebase is queried.
  ///
  /// There is no dummy fallback.
  Future<PricingProfile?> getPricingForCarFromFirebase({
    required String tenantId,
    required String pricingProfileId,
    bool forceRefresh = false,
  }) async {
    final normalizedTenantId =
        tenantId.trim();

    final normalizedProfileId =
        pricingProfileId.trim();

    if (normalizedTenantId.isEmpty) {
      throw ArgumentError(
        'tenantId cannot be empty.',
      );
    }

    if (normalizedProfileId.isEmpty) {
      throw ArgumentError(
        'pricingProfileId cannot be empty.',
      );
    }

    if (!forceRefresh &&
        _cachedPricing != null &&
        _cachedTenantId ==
            normalizedTenantId) {
      final cachedProfile =
          getPricingForCar(
        normalizedProfileId,
      );

      if (cachedProfile != null) {
        return cachedProfile;
      }
    }

    return loadPricingProfile(
      tenantId: normalizedTenantId,
      pricingProfileId:
          normalizedProfileId,
      forceRefresh: forceRefresh,
    );
  }

  // ===========================================================================
  // RENTAL TYPE / SPECIAL DATE HELPERS
  // ===========================================================================

  /// Returns the currently cached profile and allows the UI to ask which
  /// rental types are available for a selected range.
  ///
  /// The actual rules are owned by PricingProfile.
  List<RentalType> availableRentalTypesForRange(
    PricingProfile profile, {
    required DateTime start,
    required DateTime end,
  }) {
    if (end.isBefore(start)) {
      return const [];
    }

    return profile.availableRentalTypesForRange(
      start,
      end,
    );
  }

  bool isRentalTypeEnabled(
    PricingProfile profile,
    RentalType type,
  ) {
    return profile.isRentalTypeEnabled(
      type,
    );
  }

  SpecialPricingRule? specialRuleForRange(
    PricingProfile profile, {
    required DateTime start,
    required DateTime end,
  }) {
    if (end.isBefore(start)) {
      return null;
    }

    return profile.specialRuleForRange(
      start,
      end,
    );
  }

  // ===========================================================================
  // PROFILE CACHE
  // ===========================================================================

  void cachePricingProfile({
    required String tenantId,
    required PricingProfile profile,
  }) {
    final normalizedTenantId =
        tenantId.trim();

    if (normalizedTenantId.isEmpty) {
      throw ArgumentError(
        'tenantId cannot be empty.',
      );
    }

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

  String _profileCacheKey(
    String tenantId,
    String pricingProfileId,
  ) {
    return '${tenantId.trim()}::${pricingProfileId.trim()}';
  }

  // ===========================================================================
  // CLEAR CACHE
  // ===========================================================================

  void clearCache() {
    _cachedPricing = null;
    _cachedTenantId = null;
    _profileCache.clear();
  }

  // ===========================================================================
  // SET PRICING
  // ===========================================================================

  /// Compatibility method.
  ///
  /// This only places already-loaded Firebase pricing in memory.
  /// It never creates dummy pricing.
  void setPricing(
    PricingConfig pricing, {
    String? tenantId,
  }) {
    _cachedPricing =
        pricing;

    _cachedTenantId =
        tenantId?.trim();

    if (_cachedTenantId != null) {
      try {
        final profiles =
            pricing.profiles;

        for (final profile
            in profiles) {
          _profileCache[
            _profileCacheKey(
              _cachedTenantId!,
              profile.id,
            )
          ] = profile;
        }
      } catch (_) {
        // Keep compatibility with PricingConfig implementations that expose
        // profiles differently. The main pricing cache is still valid.
      }
    }
  }
}
