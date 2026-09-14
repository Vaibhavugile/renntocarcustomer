import '../models/pricing_config.dart';
import '../models/pricing_profile.dart';
import '../services/pricing_service.dart';

class PricingManager {
  PricingManager._();

  static final PricingManager instance =
      PricingManager._();

  // ===========================================================================
  // PRICING SERVICE
  // ===========================================================================

  final PricingService _service =
      PricingService.instance;

  // ===========================================================================
  // INITIALIZE
  // ===========================================================================

  Future<PricingConfig> initialize({
    required String tenantId,
  }) async {
    return _service.loadPricing(
      tenantId: tenantId,
    );
  }

  // ===========================================================================
  // CURRENT PRICING
  // ===========================================================================

  PricingConfig? get pricing {
    return _service.cachedPricing;
  }

  // ===========================================================================
  // LOADED
  // ===========================================================================

  bool get isLoaded {
    return _service.isLoaded;
  }

  // ===========================================================================
  // CACHED TENANT
  // ===========================================================================

  String? get cachedTenantId {
    return _service.cachedTenantId;
  }

  // ===========================================================================
  // GET CAR PRICING FROM CACHE
  // ===========================================================================

  PricingProfile? getPricingForCar(
    String pricingProfileId,
  ) {
    return _service.getPricingForCar(
      pricingProfileId,
    );
  }

  // ===========================================================================
  // GET CAR PRICING FROM FIREBASE
  // ===========================================================================
  //
  // Used when a particular vehicle's pricing profile needs to be fetched.
  //
  // Firebase:
  //
  // tenants/{tenantId}/pricingProfiles/{pricingProfileId}
  //
  // ===========================================================================

  Future<PricingProfile?> loadPricingForCar({
    required String tenantId,
    required String pricingProfileId,
  }) async {
    return _service.getPricingForCarFromFirebase(
      tenantId: tenantId,
      pricingProfileId: pricingProfileId,
    );
  }

  // ===========================================================================
  // SET PRICING
  // ===========================================================================
  //
  // Compatibility method.
  //
  // This accepts pricing that has already been loaded from Firebase.
  // It does NOT create dummy pricing.
  //
  // ===========================================================================

  void setPricing(
    PricingConfig pricing, {
    String? tenantId,
  }) {
    _service.setPricing(
      pricing,
      tenantId: tenantId,
    );
  }

  // ===========================================================================
  // CLEAR
  // ===========================================================================

  void clear() {
    _service.clearCache();
  }
}