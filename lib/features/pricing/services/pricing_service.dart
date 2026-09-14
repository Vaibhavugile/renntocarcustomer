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

class PricingService {
  PricingService._();

  static final PricingService instance = PricingService._();

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  PricingConfig? _cachedPricing;

  String? _cachedTenantId;

  // ===========================================================================
  // LOAD TENANT PRICING
  // ===========================================================================
  //
  // Firebase structure:
  //
  // tenants/{tenantId}/pricing/pricing_rentocar
  //
  // This document contains:
  // - KM slabs
  // - rental packages
  // - extra charges
  // - add-ons
  // - protection plans
  // - discounts
  // - taxes
  // - cancellation rules
  //
  // Vehicle-specific pricing is stored separately under:
  //
  // tenants/{tenantId}/pricingProfiles/{pricingProfileId}
  //
  // ===========================================================================

  Future<PricingConfig> loadPricing({
    required String tenantId,
  }) async {
    final normalizedTenantId = tenantId.trim();

    if (normalizedTenantId.isEmpty) {
      throw ArgumentError(
        'tenantId cannot be empty.',
      );
    }

    // -------------------------------------------------------------------------
    // RETURN CACHE ONLY FOR THE SAME TENANT
    // -------------------------------------------------------------------------

    if (_cachedPricing != null &&
        _cachedTenantId == normalizedTenantId) {
      return _cachedPricing!;
    }

    try {
      // -----------------------------------------------------------------------
      // LOAD TENANT-LEVEL PRICING
      // -----------------------------------------------------------------------

      final pricingSnapshot = await _firestore
          .collection('tenants')
          .doc(normalizedTenantId)
          .collection('pricing')
          .doc('pricing_rentocar')
          .get();

      if (!pricingSnapshot.exists) {
        throw Exception(
          'Pricing configuration not found for tenant '
          '"$normalizedTenantId".',
        );
      }

      final pricingData = pricingSnapshot.data();

      if (pricingData == null) {
        throw Exception(
          'Pricing configuration is empty for tenant '
          '"$normalizedTenantId".',
        );
      }

      // -----------------------------------------------------------------------
      // LOAD VEHICLE PRICING PROFILES
      // -----------------------------------------------------------------------
      //
      // Vehicle pricing profiles are stored separately from the tenant-level
      // pricing configuration.
      //
      // We load them here so PricingConfig can contain the complete pricing
      // configuration expected by PricingEngine.
      // -----------------------------------------------------------------------

      final profilesSnapshot = await _firestore
          .collection('tenants')
          .doc(normalizedTenantId)
          .collection('pricingProfiles')
          .get();

      final profiles = <PricingProfile>[];

      for (final doc in profilesSnapshot.docs) {
        final data = doc.data();

        try {
          final profile = PricingProfile.fromMap(
            doc.id,
            data,
          );

          profiles.add(profile);
        } catch (e) {
          throw Exception(
            'Invalid pricing profile "${doc.id}": $e',
          );
        }
      }

      // -----------------------------------------------------------------------
      // VALIDATE THAT VEHICLE PRICING PROFILES WERE LOADED
      // -----------------------------------------------------------------------

      if (profiles.isEmpty) {
        throw Exception(
          'No vehicle pricing profiles found for tenant '
          '"$normalizedTenantId".',
        );
      }

      // -----------------------------------------------------------------------
      // BUILD COMPLETE PRICING CONFIG
      // -----------------------------------------------------------------------
      //
      // IMPORTANT:
      //
      // PricingProfile.fromMap() receives the Firestore document ID.
      //
      // PricingProfile.toMap() contains the pricing values but the ID is not
      // serialized by the model.
      //
      // Therefore we MUST explicitly put the profile ID back into the map
      // before PricingConfig.fromMap() reconstructs the profiles.
      //
      // Without this:
      //
      // pricing_creta
      // pricing_seltos
      // pricing_city
      // pricing_fortuner
      //
      // would become:
      //
      // pricing_profile_0
      // pricing_profile_1
      // pricing_profile_2
      // pricing_profile_3
      //
      // and PricingEngine would not be able to find the profile referenced
      // by Car.pricingProfileId.
      // -----------------------------------------------------------------------

      final pricing = PricingConfig.fromMap(
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
      _cachedTenantId = normalizedTenantId;

      return pricing;
    } on FirebaseException catch (e) {
      throw Exception(
        'Unable to load pricing: '
        '${e.message ?? e.code}',
      );
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }

      throw Exception(
        'Unable to load pricing.',
      );
    }
  }

  // ===========================================================================
  // LOAD VEHICLE PRICING PROFILE
  // ===========================================================================
  //
  // Directly loads:
  //
  // tenants/{tenantId}/pricingProfiles/{pricingProfileId}
  //
  // This is useful when CarDetailsScreen only needs the pricing profile for
  // one particular vehicle.
  //
  // ===========================================================================

  Future<PricingProfile?> loadPricingProfile({
    required String tenantId,
    required String pricingProfileId,
  }) async {
    final normalizedTenantId = tenantId.trim();
    final normalizedProfileId = pricingProfileId.trim();

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

    try {
      final doc = await _firestore
          .collection('tenants')
          .doc(normalizedTenantId)
          .collection('pricingProfiles')
          .doc(normalizedProfileId)
          .get();

      if (!doc.exists) {
        return null;
      }

      final data = doc.data();

      if (data == null) {
        return null;
      }

      return PricingProfile.fromMap(
        doc.id,
        data,
      );
    } on FirebaseException catch (e) {
      throw Exception(
        'Unable to load vehicle pricing: '
        '${e.message ?? e.code}',
      );
    } catch (e) {
      throw Exception(
        'Unable to load vehicle pricing.',
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
    final pricing = _cachedPricing;

    if (pricing == null) {
      return null;
    }

    final normalizedProfileId =
        pricingProfileId.trim();

    if (normalizedProfileId.isEmpty) {
      return null;
    }

    return pricing.getProfile(
      normalizedProfileId,
    );
  }

  // ===========================================================================
  // GET PRICING FOR CAR - FIREBASE FIRST
  // ===========================================================================
  //
  // If the profile is already part of the loaded tenant pricing configuration,
  // return it from memory.
  //
  // Otherwise fetch it directly from Firebase.
  //
  // There is NO dummy fallback.
  //
  // ===========================================================================

  Future<PricingProfile?> getPricingForCarFromFirebase({
    required String tenantId,
    required String pricingProfileId,
  }) async {
    final normalizedTenantId = tenantId.trim();
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

    // -------------------------------------------------------------------------
    // CHECK CACHE
    // -------------------------------------------------------------------------

    if (_cachedPricing != null &&
        _cachedTenantId == normalizedTenantId) {
      final cachedProfile = getPricingForCar(
        normalizedProfileId,
      );

      if (cachedProfile != null) {
        return cachedProfile;
      }
    }

    // -------------------------------------------------------------------------
    // FETCH DIRECTLY FROM FIREBASE
    // -------------------------------------------------------------------------

    return loadPricingProfile(
      tenantId: normalizedTenantId,
      pricingProfileId: normalizedProfileId,
    );
  }

  // ===========================================================================
  // CLEAR CACHE
  // ===========================================================================

  void clearCache() {
    _cachedPricing = null;
    _cachedTenantId = null;
  }

  // ===========================================================================
  // SET PRICING
  // ===========================================================================
  //
  // Kept for compatibility with existing PricingManager code.
  //
  // This does NOT load dummy data.
  // It only allows already-fetched Firebase pricing to be placed in memory.
  //
  // ===========================================================================

  void setPricing(
    PricingConfig pricing, {
    String? tenantId,
  }) {
    _cachedPricing = pricing;
    _cachedTenantId = tenantId?.trim();
  }
}