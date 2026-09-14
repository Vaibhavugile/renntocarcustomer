import 'pricing_profile.dart';
import 'km_slab.dart';
import 'rental_package.dart';
import 'extra_charge.dart';
import 'add_on.dart';
import 'protection_plan.dart';
import 'discount_rule.dart';
import 'tax_rule.dart';
import 'cancellation_rule.dart';

class PricingConfig {
  final String id;

  // ---------------------------------------------------------------------------
  // CORE PRICING
  // ---------------------------------------------------------------------------
  //
  // Multiple pricing profiles are supported.
  //
  // Example:
  // pricing_creta
  // pricing_seltos
  // pricing_city
  // pricing_fortuner
  //
  // Each car points to one profile using pricingProfileId.
  // ---------------------------------------------------------------------------

  final List<PricingProfile> profiles;

  // ---------------------------------------------------------------------------
  // KM
  // ---------------------------------------------------------------------------

  final List<KmSlab> kmSlabs;

  // ---------------------------------------------------------------------------
  // RENTAL PACKAGES
  // ---------------------------------------------------------------------------

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
  // FIND PRICING PROFILE FOR A CAR
  // ===========================================================================

  PricingProfile? getProfile(
    String pricingProfileId,
  ) {
    for (final profile in profiles) {
      if (profile.id == pricingProfileId) {
        return profile;
      }
    }

    return null;
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

      // -----------------------------------------------------------------------
      // MULTIPLE PRICING PROFILES
      // -----------------------------------------------------------------------

      profiles: _parseList<PricingProfile>(
        map['profiles'],
        (item, index) {
          return PricingProfile.fromMap(
            item['id']?.toString() ??
                'pricing_profile_$index',
            item,
          );
        },
      ),

      // -----------------------------------------------------------------------
      // KM SLABS
      // -----------------------------------------------------------------------

      kmSlabs: _parseList<KmSlab>(
        map['kmSlabs'],
        (item, index) {
          return KmSlab.fromMap(
            item['id']?.toString() ??
                'km_slab_$index',
            item,
          );
        },
      ),

      // -----------------------------------------------------------------------
      // PACKAGES
      // -----------------------------------------------------------------------

      packages: _parseList<RentalPackage>(
        map['packages'],
        (item, index) {
          return RentalPackage.fromMap(
            item['id']?.toString() ??
                'package_$index',
            item,
          );
        },
      ),

      // -----------------------------------------------------------------------
      // EXTRA CHARGES
      // -----------------------------------------------------------------------

      extraCharges: _parseList<ExtraCharge>(
        map['extraCharges'],
        (item, index) {
          return ExtraCharge.fromMap(
            item['id']?.toString() ??
                'charge_$index',
            item,
          );
        },
      ),

      // -----------------------------------------------------------------------
      // ADD-ONS
      // -----------------------------------------------------------------------

      addOns: _parseList<AddOn>(
        map['addOns'],
        (item, index) {
          return AddOn.fromMap(
            item['id']?.toString() ??
                'addon_$index',
            item,
          );
        },
      ),

      // -----------------------------------------------------------------------
      // PROTECTION
      // -----------------------------------------------------------------------

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

      // -----------------------------------------------------------------------
      // DISCOUNTS
      // -----------------------------------------------------------------------

      discounts: _parseList<DiscountRule>(
        map['discounts'],
        (item, index) {
          return DiscountRule.fromMap(
            item['id']?.toString() ??
                'discount_$index',
            item,
          );
        },
      ),

      // -----------------------------------------------------------------------
      // TAXES
      // -----------------------------------------------------------------------

      taxes: _parseList<TaxRule>(
        map['taxes'],
        (item, index) {
          return TaxRule.fromMap(
            item['id']?.toString() ??
                'tax_$index',
            item,
          );
        },
      ),

      // -----------------------------------------------------------------------
      // CANCELLATION RULES
      // -----------------------------------------------------------------------

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
          map['isActive'] ?? true,
    );
  }

  // ===========================================================================
  // MODEL → FIRESTORE
  // ===========================================================================

  Map<String, dynamic> toMap() {
    return {
      // -----------------------------------------------------------------------
      // PRICING PROFILES
      // -----------------------------------------------------------------------

      'profiles': profiles
          .map(
            (item) => {
              'id': item.id,
              ...item.toMap(),
            },
          )
          .toList(),

      // -----------------------------------------------------------------------
      // KM SLABS
      // -----------------------------------------------------------------------

      'kmSlabs': kmSlabs
          .map(
            (item) => {
              'id': item.id,
              ...item.toMap(),
            },
          )
          .toList(),

      // -----------------------------------------------------------------------
      // PACKAGES
      // -----------------------------------------------------------------------

      'packages': packages
          .map(
            (item) => {
              'id': item.id,
              ...item.toMap(),
            },
          )
          .toList(),

      // -----------------------------------------------------------------------
      // EXTRA CHARGES
      // -----------------------------------------------------------------------

      'extraCharges': extraCharges
          .map(
            (item) => {
              'id': item.id,
              ...item.toMap(),
            },
          )
          .toList(),

      // -----------------------------------------------------------------------
      // ADD-ONS
      // -----------------------------------------------------------------------

      'addOns': addOns
          .map(
            (item) => {
              'id': item.id,
              ...item.toMap(),
            },
          )
          .toList(),

      // -----------------------------------------------------------------------
      // PROTECTION
      // -----------------------------------------------------------------------

      'protectionPlans':
          protectionPlans
              .map(
                (item) => {
                  'id': item.id,
                  ...item.toMap(),
                },
              )
              .toList(),

      // -----------------------------------------------------------------------
      // DISCOUNTS
      // -----------------------------------------------------------------------

      'discounts': discounts
          .map(
            (item) => {
              'id': item.id,
              ...item.toMap(),
            },
          )
          .toList(),

      // -----------------------------------------------------------------------
      // TAXES
      // -----------------------------------------------------------------------

      'taxes': taxes
          .map(
            (item) => {
              'id': item.id,
              ...item.toMap(),
            },
          )
          .toList(),

      // -----------------------------------------------------------------------
      // CANCELLATION
      // -----------------------------------------------------------------------

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
      return [];
    }

    final result = <T>[];

    for (int i = 0; i < value.length; i++) {
      final item = value[i];

      if (item is Map) {
        result.add(
          parser(
            Map<String, dynamic>.from(item),
            i,
          ),
        );
      }
    }

    return result;
  }
}