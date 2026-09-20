import 'km_pricing_package.dart';

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
/// Vehicle pricing itself lives in PricingProfile:
///   tenants/{tenantId}/pricingProfiles/{pricingProfileId}
///
/// PricingConfig is configuration only. PricingEngine is responsible for
/// calculating booking totals.
///
/// Simplified rental model:
///   - Hourly
///   - Daily
///   - KM packages
///   - Special date rates
///   - Security deposits
///
/// Historical bookings must store their own pricing snapshot. Updating this
/// configuration must never change an existing booking.
class PricingConfig {
  final String id;

  /// All pricing profiles loaded for this tenant.
  final List<PricingProfile> profiles;

  /// Legacy/global KM slabs retained only for compatibility with existing
  /// add-on/admin code. New vehicle pricing should use package includedKm.
  final List<KmSlab> kmSlabs;

  /// Legacy/global rental packages retained for compatibility.
  ///
  /// New rental pricing must use PricingProfile.hourlyPackages and
  /// PricingProfile.dailyPackages.
  final List<RentalPackage> packages;

  final List<ExtraCharge> extraCharges;
  final List<AddOn> addOns;
  final List<ProtectionPlan> protectionPlans;
  final List<DiscountRule> discounts;
  final List<TaxRule> taxes;
  final List<CancellationRule> cancellationRules;

  final bool isActive;

  const PricingConfig({
    required this.id,
    this.profiles = const [],
    this.kmSlabs = const [],
    this.packages = const [],
    this.extraCharges = const [],
    this.addOns = const [],
    this.protectionPlans = const [],
    this.discounts = const [],
    this.taxes = const [],
    this.cancellationRules = const [],
    this.isActive = true,
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

  List<PricingProfile>
      get activeProfiles =>
          List<PricingProfile>.unmodifiable(
            profiles.where(
              (profile) => profile.isActive,
            ),
          );

  // ===========================================================================
  // VEHICLE / GROUP LOOKUPS
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

  PricingProfile? getProfileForPricingGroup(
    String pricingGroupId,
  ) {
    final normalizedGroupId =
        pricingGroupId.trim();

    if (normalizedGroupId.isEmpty) {
      return null;
    }

    for (final profile in profiles) {
      if (profile.pricingGroupId ==
          normalizedGroupId) {
        return profile;
      }
    }

    return null;
  }

  PricingProfile? getActiveProfileForPricingGroup(
    String pricingGroupId,
  ) {
    final profile =
        getProfileForPricingGroup(
      pricingGroupId,
    );

    if (profile == null ||
        !profile.isActive) {
      return null;
    }

    return profile;
  }

  List<PricingProfile>
      getProfilesForPricingGroup(
    String pricingGroupId,
  ) {
    final normalized =
        pricingGroupId.trim();

    if (normalized.isEmpty) {
      return const [];
    }

    return List<PricingProfile>.unmodifiable(
      profiles.where(
        (profile) =>
            profile.pricingGroupId ==
            normalized,
      ),
    );
  }

  // ===========================================================================
  // RENTAL TYPE HELPERS
  // ===========================================================================

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

  /// Only hourly and daily exist in the simplified RentalType enum.
  List<RentalType>
      get supportedRentalTypes {
    final result =
        <RentalType>[];

    for (final type in RentalType.values) {
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

    for (final type in RentalType.values) {
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
  // GLOBAL COMPATIBILITY DATA
  // ===========================================================================

  List<KmSlab> get activeKmSlabs =>
      List<KmSlab>.unmodifiable(
        kmSlabs.where(
          (slab) => slab.isActive,
        ),
      );

  List<RentalPackage> get activePackages =>
      List<RentalPackage>.unmodifiable(
        packages.where(
          (package) => package.isActive,
        ),
      );

  // ===========================================================================
  // ADD-ONS
  // ===========================================================================

  List<AddOn> get activeAddOns =>
      List<AddOn>.unmodifiable(
        addOns.where(
          (addOn) => addOn.isActive,
        ),
      );

  AddOn? getAddOn(String id) {
    final normalizedId = id.trim();

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
      get activeProtectionPlans =>
          List<ProtectionPlan>.unmodifiable(
            protectionPlans.where(
              (plan) => plan.isActive,
            ),
          );

  ProtectionPlan? getProtectionPlan(
    String id,
  ) {
    final normalizedId = id.trim();

    if (normalizedId.isEmpty) {
      return null;
    }

    for (final plan in protectionPlans) {
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
      get activeDiscounts =>
          List<DiscountRule>.unmodifiable(
            discounts.where(
              (discount) =>
                  discount.isActive,
            ),
          );

  DiscountRule? getDiscount(
    String id,
  ) {
    final normalizedId = id.trim();

    if (normalizedId.isEmpty) {
      return null;
    }

    for (final discount in discounts) {
      if (discount.id == normalizedId) {
        return discount;
      }
    }

    return null;
  }

  // ===========================================================================
  // TAXES
  // ===========================================================================

  List<TaxRule> get activeTaxes =>
      List<TaxRule>.unmodifiable(
        taxes.where(
          (tax) => tax.isActive,
        ),
      );

  // ===========================================================================
  // EXTRA CHARGES
  // ===========================================================================

  List<ExtraCharge>
      get activeExtraCharges =>
          List<ExtraCharge>.unmodifiable(
            extraCharges.where(
              (charge) => charge.isActive,
            ),
          );

  // ===========================================================================
  // CANCELLATION
  // ===========================================================================

  List<CancellationRule>
      get activeCancellationRules =>
          List<CancellationRule>.unmodifiable(
            cancellationRules.where(
              (rule) => rule.isActive,
            ),
          );

  // ===========================================================================
  // FIRESTORE -> MODEL
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
  // MODEL -> FIRESTORE
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

      // Kept for existing non-pricing features.
      'kmSlabs': kmSlabs
          .map(
            (item) => {
              'id': item.id,
              ...item.toMap(),
            },
          )
          .toList(),

      // Legacy compatibility only.
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

      'protectionPlans': protectionPlans
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
      profiles: profiles ?? this.profiles,
      kmSlabs: kmSlabs ?? this.kmSlabs,
      packages: packages ?? this.packages,
      extraCharges:
          extraCharges ?? this.extraCharges,
      addOns: addOns ?? this.addOns,
      protectionPlans:
          protectionPlans ?? this.protectionPlans,
      discounts:
          discounts ?? this.discounts,
      taxes: taxes ?? this.taxes,
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
  /// Useful before an admin saves pricing configuration.
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

      if (profile.name.trim().isEmpty) {
        errors.add(
          'Pricing profile "$profileId" '
          'has no name.',
        );
      }

      if (!profile.hourlyEnabled &&
          !profile.dailyEnabled) {
        errors.add(
          'Pricing profile "$profileId" '
          'has neither an hourly nor daily package.',
        );
      }

      final packageIds =
          <String>{};

      for (final package
          in <KmPricingPackage>[
        ...profile.hourlyPackages,
        ...profile.dailyPackages,
      ]) {
        if (!packageIds.add(
          package.id,
        )) {
          // Same package can legitimately exist in both lists, so this is
          // informationally not an error.
          continue;
        }

        if (package.id.trim().isEmpty) {
          errors.add(
            'Pricing profile "$profileId" '
            'contains a package with an empty ID.',
          );
        }

        if (package.hourlyRate < 0 ||
            package.dailyRate < 0 ||
            package.extraKmRate < 0) {
          errors.add(
            'Pricing profile "$profileId" '
            'contains a negative package price.',
          );
        }

        if (!package.unlimitedKm &&
            package.safeIncludedKm < 0) {
          errors.add(
            'Pricing profile "$profileId" '
            'contains invalid included KM.',
          );
        }
      }

      final specialRateIds =
          <String>{};

      for (final rate
          in profile.specialRates) {
        if (rate.id.trim().isEmpty) {
          errors.add(
            'Pricing profile "$profileId" '
            'contains a special rate with an empty ID.',
          );
        } else if (!specialRateIds.add(
          rate.id,
        )) {
          errors.add(
            'Duplicate special rate ID '
            '"${rate.id}" in profile "$profileId".',
          );
        }

        if (rate.endDate
            .isBefore(rate.startDate)) {
          errors.add(
            'Special rate "${rate.id}" '
            'has an end date before its start date.',
          );
        }
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

  bool get isValid =>
      validate().isEmpty;

  // ===========================================================================
  // PARSER
  // ===========================================================================

  static List<T> _parseList<T>(
    dynamic value,
    T Function(
      Map<String, dynamic> item,
      int index,
    ) parser,
  ) {
    if (value is! Iterable) {
      return <T>[];
    }

    final result =
        <T>[];

    var index = 0;

    for (final rawItem in value) {
      if (rawItem is Map) {
        result.add(
          parser(
            Map<String, dynamic>.from(
              rawItem,
            ),
            index,
          ),
        );
      }

      index++;
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
