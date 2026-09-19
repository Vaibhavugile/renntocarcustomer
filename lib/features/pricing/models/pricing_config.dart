import 'pricing_profile.dart';
import 'km_slab.dart';
import 'rental_package.dart';
import 'extra_charge.dart';
import 'add_on.dart';
import 'protection_plan.dart';
import 'discount_rule.dart';
import 'tax_rule.dart';
import 'cancellation_rule.dart';

/// Tenant-level pricing container.
///
/// Firestore:
///   tenants/{tenantId}/pricing/{pricingDocumentId}
///
/// Vehicle-specific pricing is stored separately:
///   tenants/{tenantId}/pricingProfiles/{pricingProfileId}
///
/// PricingConfig is a configuration container only. It does not calculate
/// booking totals. PricingEngine is the calculation authority.
///
/// Historical bookings must save their own pricingSnapshot. Updating this
/// configuration must therefore never mutate an existing booking's price.
class PricingConfig {
  final String id;

  // ---------------------------------------------------------------------------
  // CORE PRICING
  // ---------------------------------------------------------------------------

  /// Multiple vehicle pricing profiles are supported.
  ///
  /// Example:
  ///   pricing_creta
  ///   pricing_seltos
  ///   pricing_city
  ///   pricing_fortuner
  ///
  /// Each Car points to one profile using pricingProfileId.
  final List<PricingProfile> profiles;

  // ---------------------------------------------------------------------------
  // KM
  // ---------------------------------------------------------------------------

  final List<KmSlab> kmSlabs;

  // ---------------------------------------------------------------------------
  // LEGACY / GLOBAL RENTAL PACKAGES
  // ---------------------------------------------------------------------------

  /// Retained for compatibility with the older pricing architecture.
  ///
  /// New vehicle pricing should normally use PricingProfile.kmPackages.
  final List<RentalPackage> packages;

  // ---------------------------------------------------------------------------
  // EXTRA CHARGES
  // ---------------------------------------------------------------------------

  final List<ExtraCharge> extraCharges;

  // ---------------------------------------------------------------------------
  // ADD-ONS
  // ---------------------------------------------------------------------------

  final List<AddOn> addOns;

  // ---------------------------------------------------------------------------
  // PROTECTION
  // ---------------------------------------------------------------------------

  final List<ProtectionPlan> protectionPlans;

  // ---------------------------------------------------------------------------
  // DISCOUNTS
  // ---------------------------------------------------------------------------

  final List<DiscountRule> discounts;

  // ---------------------------------------------------------------------------
  // TAXES
  // ---------------------------------------------------------------------------

  final List<TaxRule> taxes;

  // ---------------------------------------------------------------------------
  // CANCELLATION
  // ---------------------------------------------------------------------------

  final List<CancellationRule> cancellationRules;

  // ---------------------------------------------------------------------------
  // STATUS
  // ---------------------------------------------------------------------------

  final bool isActive;

  const PricingConfig({
    required this.id,
    required this.profiles,
    required this.kmSlabs,
    required this.packages,
    required this.extraCharges,
    required this.addOns,
    required this.protectionPlans,
    required this.discounts,
    required this.taxes,
    required this.cancellationRules,
    required this.isActive,
  });

  // ===========================================================================
  // PROFILE LOOKUPS
  // ===========================================================================

  PricingProfile? getProfile(
    String pricingProfileId,
  ) {
    final normalizedId =
        pricingProfileId.trim();

    if (normalizedId.isEmpty) {
      return null;
    }

    for (final profile in profiles) {
      if (profile.id == normalizedId) {
        return profile;
      }
    }

    return null;
  }

  PricingProfile? getActiveProfile(
    String pricingProfileId,
  ) {
    final profile =
        getProfile(pricingProfileId);

    if (profile == null ||
        !profile.isActive) {
      return null;
    }

    return profile;
  }

  List<PricingProfile> get activeProfiles {
    return List<PricingProfile>.unmodifiable(
      profiles.where(
        (profile) => profile.isActive,
      ),
    );
  }

  // ===========================================================================
  // VEHICLE LOOKUPS
  // ===========================================================================

  PricingProfile? getProfileForVehicle(
    String vehicleId,
  ) {
    final normalizedVehicleId =
        vehicleId.trim();

    if (normalizedVehicleId.isEmpty) {
      return null;
    }

    for (final profile in profiles) {
      if (profile.vehicleId ==
          normalizedVehicleId) {
        return profile;
      }
    }

    return null;
  }

  PricingProfile? getActiveProfileForVehicle(
    String vehicleId,
  ) {
    final profile =
        getProfileForVehicle(vehicleId);

    if (profile == null ||
        !profile.isActive) {
      return null;
    }

    return profile;
  }

  // ===========================================================================
  // RENTAL TYPE HELPERS
  // ===========================================================================

  /// Returns profiles that support the selected rental type.
  List<PricingProfile>
      getProfilesForRentalType(
    RentalType type,
  ) {
    return List<PricingProfile>.unmodifiable(
      profiles.where(
        (profile) =>
            profile.isActive &&
            profile.isRentalTypeEnabled(type),
      ),
    );
  }

  /// Returns rental types supported by at least one active profile.
  List<RentalType> get supportedRentalTypes {
    final result =
        <RentalType>[];

    for (final type
        in RentalType.values) {
      if (profiles.any(
        (profile) =>
            profile.isActive &&
            profile.isRentalTypeEnabled(type),
      )) {
        result.add(type);
      }
    }

    return List<RentalType>.unmodifiable(
      result,
    );
  }

  /// Returns rental types available for a selected date/time range across all
  /// active pricing profiles.
  ///
  /// This is useful for admin/customer UI before a vehicle has been selected.
  List<RentalType>
      availableRentalTypesForRange({
    required DateTime start,
    required DateTime end,
  }) {
    if (end.isBefore(start)) {
      return const [];
    }

    final result =
        <RentalType>[];

    for (final type
        in RentalType.values) {
      final available =
          profiles.any(
        (profile) =>
            profile.isActive &&
            profile
                .availableRentalTypesForRange(
                  start,
                  end,
                )
                .contains(type),
      );

      if (available) {
        result.add(type);
      }
    }

    return List<RentalType>.unmodifiable(
      result,
    );
  }

  // ===========================================================================
  // GLOBAL KM SLABS
  // ===========================================================================

  List<KmSlab> get activeKmSlabs {
    return List<KmSlab>.unmodifiable(
      kmSlabs.where(
        (slab) => slab.isActive,
      ),
    );
  }

  // ===========================================================================
  // GLOBAL PACKAGES
  // ===========================================================================

  List<RentalPackage> get activePackages {
    return List<RentalPackage>.unmodifiable(
      packages.where(
        (package) => package.isActive,
      ),
    );
  }

  // ===========================================================================
  // ADD-ONS
  // ===========================================================================

  List<AddOn> get activeAddOns {
    return List<AddOn>.unmodifiable(
      addOns.where(
        (addOn) => addOn.isActive,
      ),
    );
  }

  AddOn? getAddOn(
    String id,
  ) {
    final normalizedId =
        id.trim();

    if (normalizedId.isEmpty) {
      return null;
    }

    for (final addOn in addOns) {
      if (addOn.id == normalizedId) {
        return addOn;
      }
    }

    return null;
  }

  // ===========================================================================
  // PROTECTION
  // ===========================================================================

  List<ProtectionPlan>
      get activeProtectionPlans {
    return List<ProtectionPlan>.unmodifiable(
      protectionPlans.where(
        (plan) => plan.isActive,
      ),
    );
  }

  ProtectionPlan? getProtectionPlan(
    String id,
  ) {
    final normalizedId =
        id.trim();

    if (normalizedId.isEmpty) {
      return null;
    }

    for (final plan
        in protectionPlans) {
      if (plan.id == normalizedId) {
        return plan;
      }
    }

    return null;
  }

  // ===========================================================================
  // DISCOUNTS
  // ===========================================================================

  List<DiscountRule>
      get activeDiscounts {
    return List<DiscountRule>.unmodifiable(
      discounts.where(
        (discount) => discount.isActive,
      ),
    );
  }

  DiscountRule? getDiscount(
    String id,
  ) {
    final normalizedId =
        id.trim();

    if (normalizedId.isEmpty) {
      return null;
    }

    for (final discount
        in discounts) {
      if (discount.id == normalizedId) {
        return discount;
      }
    }

    return null;
  }

  // ===========================================================================
  // TAXES
  // ===========================================================================

  List<TaxRule> get activeTaxes {
    return List<TaxRule>.unmodifiable(
      taxes.where(
        (tax) => tax.isActive,
      ),
    );
  }

  // ===========================================================================
  // EXTRA CHARGES
  // ===========================================================================

  List<ExtraCharge>
      get activeExtraCharges {
    return List<ExtraCharge>.unmodifiable(
      extraCharges.where(
        (charge) => charge.isActive,
      ),
    );
  }

  // ===========================================================================
  // CANCELLATION
  // ===========================================================================

  List<CancellationRule>
      get activeCancellationRules {
    return List<CancellationRule>.unmodifiable(
      cancellationRules.where(
        (rule) => rule.isActive,
      ),
    );
  }

  // ===========================================================================
  // FIRESTORE → MODEL
  // ===========================================================================

  factory PricingConfig.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    return PricingConfig(
      id: id,

      profiles:
          _parseList<PricingProfile>(
        map['profiles'],
        (item, index) {
          return PricingProfile.fromMap(
            item['id']?.toString() ??
                'pricing_profile_$index',
            item,
          );
        },
      ),

      kmSlabs:
          _parseList<KmSlab>(
        map['kmSlabs'],
        (item, index) {
          return KmSlab.fromMap(
            item['id']?.toString() ??
                'km_slab_$index',
            item,
          );
        },
      ),

      packages:
          _parseList<RentalPackage>(
        map['packages'],
        (item, index) {
          return RentalPackage.fromMap(
            item['id']?.toString() ??
                'package_$index',
            item,
          );
        },
      ),

      extraCharges:
          _parseList<ExtraCharge>(
        map['extraCharges'],
        (item, index) {
          return ExtraCharge.fromMap(
            item['id']?.toString() ??
                'charge_$index',
            item,
          );
        },
      ),

      addOns:
          _parseList<AddOn>(
        map['addOns'],
        (item, index) {
          return AddOn.fromMap(
            item['id']?.toString() ??
                'addon_$index',
            item,
          );
        },
      ),

      protectionPlans:
          _parseList<ProtectionPlan>(
        map['protectionPlans'],
        (item, index) {
          return ProtectionPlan.fromMap(
            item['id']?.toString() ??
                'protection_$index',
            item,
          );
        },
      ),

      discounts:
          _parseList<DiscountRule>(
        map['discounts'],
        (item, index) {
          return DiscountRule.fromMap(
            item['id']?.toString() ??
                'discount_$index',
            item,
          );
        },
      ),

      taxes:
          _parseList<TaxRule>(
        map['taxes'],
        (item, index) {
          return TaxRule.fromMap(
            item['id']?.toString() ??
                'tax_$index',
            item,
          );
        },
      ),

      cancellationRules:
          _parseList<CancellationRule>(
        map['cancellationRules'],
        (item, index) {
          return CancellationRule.fromMap(
            item['id']?.toString() ??
                'cancel_$index',
            item,
          );
        },
      ),

      isActive:
          _toBool(
        map['isActive'],
        true,
      ),
    );
  }

  // ===========================================================================
  // MODEL → FIRESTORE
  // ===========================================================================

  Map<String, dynamic> toMap() {
    return {
      'profiles': profiles
          .map(
            (item) => {
              'id': item.id,
              ...item.toMap(),
            },
          )
          .toList(),

      'kmSlabs': kmSlabs
          .map(
            (item) => {
              'id': item.id,
              ...item.toMap(),
            },
          )
          .toList(),

      'packages': packages
          .map(
            (item) => {
              'id': item.id,
              ...item.toMap(),
            },
          )
          .toList(),

      'extraCharges': extraCharges
          .map(
            (item) => {
              'id': item.id,
              ...item.toMap(),
            },
          )
          .toList(),

      'addOns': addOns
          .map(
            (item) => {
              'id': item.id,
              ...item.toMap(),
            },
          )
          .toList(),

      'protectionPlans':
          protectionPlans
              .map(
                (item) => {
                  'id': item.id,
                  ...item.toMap(),
                },
              )
              .toList(),

      'discounts': discounts
          .map(
            (item) => {
              'id': item.id,
              ...item.toMap(),
            },
          )
          .toList(),

      'taxes': taxes
          .map(
            (item) => {
              'id': item.id,
              ...item.toMap(),
            },
          )
          .toList(),

      'cancellationRules':
          cancellationRules
              .map(
                (item) => {
                  'id': item.id,
                  ...item.toMap(),
                },
              )
              .toList(),

      'isActive': isActive,
    };
  }

  // ===========================================================================
  // COPY WITH
  // ===========================================================================

  PricingConfig copyWith({
    String? id,
    List<PricingProfile>? profiles,
    List<KmSlab>? kmSlabs,
    List<RentalPackage>? packages,
    List<ExtraCharge>? extraCharges,
    List<AddOn>? addOns,
    List<ProtectionPlan>? protectionPlans,
    List<DiscountRule>? discounts,
    List<TaxRule>? taxes,
    List<CancellationRule>? cancellationRules,
    bool? isActive,
  }) {
    return PricingConfig(
      id: id ?? this.id,
      profiles:
          profiles ?? this.profiles,
      kmSlabs:
          kmSlabs ?? this.kmSlabs,
      packages:
          packages ?? this.packages,
      extraCharges:
          extraCharges ?? this.extraCharges,
      addOns:
          addOns ?? this.addOns,
      protectionPlans:
          protectionPlans ??
              this.protectionPlans,
      discounts:
          discounts ?? this.discounts,
      taxes:
          taxes ?? this.taxes,
      cancellationRules:
          cancellationRules ??
              this.cancellationRules,
      isActive:
          isActive ?? this.isActive,
    );
  }

  // ===========================================================================
  // VALIDATION
  // ===========================================================================

  /// Returns validation errors instead of throwing.
  ///
  /// Useful for an admin pricing editor before saving.
  List<String> validate() {
    final errors =
        <String>[];

    if (id.trim().isEmpty) {
      errors.add(
        'PricingConfig ID is required.',
      );
    }

    final profileIds =
        <String>{};

    for (final profile in profiles) {
      final profileId =
          profile.id.trim();

      if (profileId.isEmpty) {
        errors.add(
          'A pricing profile has an empty ID.',
        );
      } else if (!profileIds.add(
        profileId,
      )) {
        errors.add(
          'Duplicate pricing profile ID: '
          '$profileId',
        );
      }

      if (profile.tenantId.trim().isEmpty) {
        errors.add(
          'Pricing profile "$profileId" '
          'has no tenantId.',
        );
      }

      if (profile.pricingVersion < 1) {
        errors.add(
          'Pricing profile "$profileId" '
          'has invalid pricingVersion.',
        );
      }
    }

    final slabIds =
        <String>{};

    for (final slab in kmSlabs) {
      if (!slabIds.add(slab.id)) {
        errors.add(
          'Duplicate KM slab ID: ${slab.id}',
        );
      }
    }

    final addOnIds =
        <String>{};

    for (final addOn in addOns) {
      if (!addOnIds.add(addOn.id)) {
        errors.add(
          'Duplicate add-on ID: ${addOn.id}',
        );
      }
    }

    final taxIds =
        <String>{};

    for (final tax in taxes) {
      if (!taxIds.add(tax.id)) {
        errors.add(
          'Duplicate tax ID: ${tax.id}',
        );
      }
    }

    return List<String>.unmodifiable(
      errors,
    );
  }

  bool get isValid {
    return validate().isEmpty;
  }

  // ===========================================================================
  // LIST PARSER
  // ===========================================================================

  static List<T> _parseList<T>(
    dynamic value,
    T Function(
      Map<String, dynamic> item,
      int index,
    ) parser,
  ) {
    if (value is! List) {
      return <T>[];
    }

    final result =
        <T>[];

    for (
      int index = 0;
      index < value.length;
      index++
    ) {
      final item =
          value[index];

      if (item is Map) {
        result.add(
          parser(
            Map<String, dynamic>.from(
              item,
            ),
            index,
          ),
        );
      }
    }

    return result;
  }

  static bool _toBool(
    dynamic value,
    bool fallback,
  ) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    final normalized =
        value
            ?.toString()
            .trim()
            .toLowerCase();

    if (normalized == 'true' ||
        normalized == '1' ||
        normalized == 'yes') {
      return true;
    }

    if (normalized == 'false' ||
        normalized == '0' ||
        normalized == 'no') {
      return false;
    }

    return fallback;
  }

  @override
  String toString() {
    return 'PricingConfig('
        'id: $id, '
        'profiles: ${profiles.length}, '
        'kmSlabs: ${kmSlabs.length}, '
        'packages: ${packages.length}, '
        'extraCharges: ${extraCharges.length}, '
        'addOns: ${addOns.length}, '
        'protectionPlans: ${protectionPlans.length}, '
        'discounts: ${discounts.length}, '
        'taxes: ${taxes.length}, '
        'cancellationRules: ${cancellationRules.length}, '
        'isActive: $isActive'
        ')';
  }
}
