// import '../models/add_on.dart';
// import '../models/cancellation_rule.dart';
// import '../models/discount_rule.dart';
// import '../models/extra_charge.dart';
// import '../models/km_pricing_package.dart';
// import '../models/km_slab.dart';
// import '../models/pricing_config.dart';
// import '../models/pricing_profile.dart';
// import '../models/protection_plan.dart';
// import '../models/rental_package.dart';
// import '../models/tax_rule.dart';

// /// Dummy pricing configuration for Rentocar.
// ///
// /// IMPORTANT:
// /// This represents ONE CLIENT'S pricing configuration.
// ///
// /// Each vehicle can have its own PricingProfile.
// ///
// /// Later this exact structure will come from the backend/API/Firestore.
// ///
// /// The pricing engine does not need to change when another client has
// /// completely different pricing.
// final PricingConfig rentocarDummyPricing =
//     PricingConfig(
//   id: 'pricing_rentocar',

//   // ===========================================================================
//   // VEHICLE PRICING PROFILES
//   // ===========================================================================

//   profiles: const [
//     // -------------------------------------------------------------------------
//     // HYUNDAI CRETA
//     // -------------------------------------------------------------------------

//     PricingProfile(
//       id: 'pricing_creta',

//       hourlyRate: 399,

//       dailyRate: 2499,

//       weekendRate: 2799,

//       weeklyRate: 13999,

//       monthlyRate: 44999,

//       kmPricingMode:
//           KmPricingMode.package,

//       includedKmPerDay: 150,

//       // Customer-selectable total KM options.
//       kmOptions: [
//         150,
//         300,
//         500,
//         750,
//         1000,
//         1500,
//       ],

//       perKmRate: 18,

//       extraKmRate: 15,

//       // NEW: independent pricing for every KM package.
//       kmPackages: [
//         KmPricingPackage(
//           id: 'creta_basic_150',
//           name: 'Basic',
//           includedKm: 150,
//           unlimitedKm: false,
//           hourlyRate: 399,
//           dailyRate: 2499,
//           weekendRate: 2799,
//           weeklyRate: 13999,
//           monthlyRate: 44999,
//           extraKmRate: 15,
//         ),
//         KmPricingPackage(
//           id: 'creta_250',
//           name: '250 KM',
//           includedKm: 250,
//           unlimitedKm: false,
//           hourlyRate: 449,
//           dailyRate: 2799,
//           weekendRate: 3099,
//           weeklyRate: 15499,
//           monthlyRate: 49999,
//           extraKmRate: 15,
//         ),
//         KmPricingPackage(
//           id: 'creta_500',
//           name: '500 KM',
//           includedKm: 500,
//           unlimitedKm: false,
//           hourlyRate: 499,
//           dailyRate: 3199,
//           weekendRate: 3499,
//           weeklyRate: 16999,
//           monthlyRate: 54999,
//           extraKmRate: 14,
//         ),
//         KmPricingPackage(
//           id: 'creta_750',
//           name: '750 KM',
//           includedKm: 750,
//           unlimitedKm: false,
//           hourlyRate: 549,
//           dailyRate: 3499,
//           weekendRate: 3799,
//           weeklyRate: 18499,
//           monthlyRate: 59999,
//           extraKmRate: 13,
//         ),
//         KmPricingPackage(
//           id: 'creta_1000',
//           name: '1000 KM',
//           includedKm: 1000,
//           unlimitedKm: false,
//           hourlyRate: 599,
//           dailyRate: 3799,
//           weekendRate: 4099,
//           weeklyRate: 19999,
//           monthlyRate: 64999,
//           extraKmRate: 12,
//         ),
//         KmPricingPackage(
//           id: 'creta_1500',
//           name: '1500 KM',
//           includedKm: 1500,
//           unlimitedKm: false,
//           hourlyRate: 649,
//           dailyRate: 4199,
//           weekendRate: 4499,
//           weeklyRate: 21999,
//           monthlyRate: 69999,
//           extraKmRate: 11,
//         ),
//         KmPricingPackage(
//           id: 'creta_unlimited',
//           name: 'Unlimited',
//           includedKm: null,
//           unlimitedKm: true,
//           hourlyRate: 699,
//           dailyRate: 4499,
//           weekendRate: 4899,
//           weeklyRate: 23999,
//           monthlyRate: 74999,
//           extraKmRate: 0,
//         ),
//       ],

//       // Unlimited KM option.
//       unlimitedKmEnabled: true,
//       unlimitedKmSurcharge: 1000,

//       gracePeriodMinutes: 30,

//       extraHourRate: 299,

//       extraDayRate: 2499,

//       lateReturnRate: 349,

//       securityDeposit: 5000,

//       isActive: true,
//     ),

//     // -------------------------------------------------------------------------
//     // KIA SELTOS
//     // -------------------------------------------------------------------------

//     PricingProfile(
//       id: 'pricing_seltos',

//       hourlyRate: 449,

//       dailyRate: 2699,

//       weekendRate: 2999,

//       weeklyRate: 14999,

//       monthlyRate: 47999,

//       kmPricingMode:
//           KmPricingMode.package,

//       includedKmPerDay: 150,

//       kmOptions: [
//         150,
//         300,
//         500,
//         750,
//         1000,
//         1500,
//       ],

//       perKmRate: 19,

//       extraKmRate: 16,

//       // NEW: independent pricing for every KM package.
//       kmPackages: [
//         KmPricingPackage(
//           id: 'seltos_basic_150',
//           name: 'Basic',
//           includedKm: 150,
//           unlimitedKm: false,
//           hourlyRate: 449,
//           dailyRate: 2699,
//           weekendRate: 2999,
//           weeklyRate: 14999,
//           monthlyRate: 47999,
//           extraKmRate: 16,
//         ),
//         KmPricingPackage(
//           id: 'seltos_250',
//           name: '250 KM',
//           includedKm: 250,
//           unlimitedKm: false,
//           hourlyRate: 499,
//           dailyRate: 2999,
//           weekendRate: 3299,
//           weeklyRate: 16499,
//           monthlyRate: 52999,
//           extraKmRate: 16,
//         ),
//         KmPricingPackage(
//           id: 'seltos_500',
//           name: '500 KM',
//           includedKm: 500,
//           unlimitedKm: false,
//           hourlyRate: 549,
//           dailyRate: 3399,
//           weekendRate: 3699,
//           weeklyRate: 17999,
//           monthlyRate: 57999,
//           extraKmRate: 15,
//         ),
//         KmPricingPackage(
//           id: 'seltos_750',
//           name: '750 KM',
//           includedKm: 750,
//           unlimitedKm: false,
//           hourlyRate: 599,
//           dailyRate: 3699,
//           weekendRate: 3999,
//           weeklyRate: 19499,
//           monthlyRate: 62999,
//           extraKmRate: 14,
//         ),
//         KmPricingPackage(
//           id: 'seltos_1000',
//           name: '1000 KM',
//           includedKm: 1000,
//           unlimitedKm: false,
//           hourlyRate: 649,
//           dailyRate: 3999,
//           weekendRate: 4299,
//           weeklyRate: 20999,
//           monthlyRate: 67999,
//           extraKmRate: 13,
//         ),
//         KmPricingPackage(
//           id: 'seltos_1500',
//           name: '1500 KM',
//           includedKm: 1500,
//           unlimitedKm: false,
//           hourlyRate: 699,
//           dailyRate: 4399,
//           weekendRate: 4699,
//           weeklyRate: 22999,
//           monthlyRate: 72999,
//           extraKmRate: 12,
//         ),
//         KmPricingPackage(
//           id: 'seltos_unlimited',
//           name: 'Unlimited',
//           includedKm: null,
//           unlimitedKm: true,
//           hourlyRate: 749,
//           dailyRate: 4899,
//           weekendRate: 5299,
//           weeklyRate: 24999,
//           monthlyRate: 77999,
//           extraKmRate: 0,
//         ),
//       ],

//       unlimitedKmEnabled: true,
//       unlimitedKmSurcharge: 1100,

//       gracePeriodMinutes: 30,

//       extraHourRate: 349,

//       extraDayRate: 2699,

//       lateReturnRate: 399,

//       securityDeposit: 5000,

//       isActive: true,
//     ),

//     // -------------------------------------------------------------------------
//     // HONDA CITY
//     // -------------------------------------------------------------------------

//     PricingProfile(
//       id: 'pricing_city',

//       hourlyRate: 349,

//       dailyRate: 2199,

//       weekendRate: 2499,

//       weeklyRate: 12499,

//       monthlyRate: 39999,

//       kmPricingMode:
//           KmPricingMode.package,

//       includedKmPerDay: 150,

//       kmOptions: [
//         150,
//         300,
//         500,
//         750,
//         1000,
//         1500,
//       ],

//       perKmRate: 17,

//       extraKmRate: 14,

//       // NEW: independent pricing for every KM package.
//       kmPackages: [
//         KmPricingPackage(
//           id: 'city_basic_150',
//           name: 'Basic',
//           includedKm: 150,
//           unlimitedKm: false,
//           hourlyRate: 349,
//           dailyRate: 2199,
//           weekendRate: 2499,
//           weeklyRate: 12499,
//           monthlyRate: 39999,
//           extraKmRate: 14,
//         ),
//         KmPricingPackage(
//           id: 'city_250',
//           name: '250 KM',
//           includedKm: 250,
//           unlimitedKm: false,
//           hourlyRate: 399,
//           dailyRate: 2499,
//           weekendRate: 2799,
//           weeklyRate: 13999,
//           monthlyRate: 43999,
//           extraKmRate: 14,
//         ),
//         KmPricingPackage(
//           id: 'city_500',
//           name: '500 KM',
//           includedKm: 500,
//           unlimitedKm: false,
//           hourlyRate: 449,
//           dailyRate: 2799,
//           weekendRate: 3099,
//           weeklyRate: 15499,
//           monthlyRate: 47999,
//           extraKmRate: 13,
//         ),
//         KmPricingPackage(
//           id: 'city_750',
//           name: '750 KM',
//           includedKm: 750,
//           unlimitedKm: false,
//           hourlyRate: 499,
//           dailyRate: 3099,
//           weekendRate: 3399,
//           weeklyRate: 16999,
//           monthlyRate: 51999,
//           extraKmRate: 12,
//         ),
//         KmPricingPackage(
//           id: 'city_1000',
//           name: '1000 KM',
//           includedKm: 1000,
//           unlimitedKm: false,
//           hourlyRate: 549,
//           dailyRate: 3399,
//           weekendRate: 3699,
//           weeklyRate: 18499,
//           monthlyRate: 55999,
//           extraKmRate: 11,
//         ),
//         KmPricingPackage(
//           id: 'city_1500',
//           name: '1500 KM',
//           includedKm: 1500,
//           unlimitedKm: false,
//           hourlyRate: 599,
//           dailyRate: 3799,
//           weekendRate: 4099,
//           weeklyRate: 20499,
//           monthlyRate: 59999,
//           extraKmRate: 10,
//         ),
//         KmPricingPackage(
//           id: 'city_unlimited',
//           name: 'Unlimited',
//           includedKm: null,
//           unlimitedKm: true,
//           hourlyRate: 649,
//           dailyRate: 3999,
//           weekendRate: 4399,
//           weeklyRate: 21999,
//           monthlyRate: 64999,
//           extraKmRate: 0,
//         ),
//       ],

//       unlimitedKmEnabled: true,
//       unlimitedKmSurcharge: 900,

//       gracePeriodMinutes: 30,

//       extraHourRate: 249,

//       extraDayRate: 2199,

//       lateReturnRate: 299,

//       securityDeposit: 4000,

//       isActive: true,
//     ),

//     // -------------------------------------------------------------------------
//     // TOYOTA FORTUNER
//     // -------------------------------------------------------------------------

//     PricingProfile(
//       id: 'pricing_fortuner',

//       hourlyRate: 799,

//       dailyRate: 4999,

//       weekendRate: 5499,

//       weeklyRate: 28999,

//       monthlyRate: 89999,

//       kmPricingMode:
//           KmPricingMode.package,

//       includedKmPerDay: 200,

//       kmOptions: [
//         200,
//         500,
//         750,
//         1000,
//         1500,
//         2000,
//       ],

//       perKmRate: 30,

//       extraKmRate: 25,

//       // NEW: independent pricing for every KM package.
//       kmPackages: [
//         KmPricingPackage(
//           id: 'fortuner_basic_200',
//           name: 'Basic',
//           includedKm: 200,
//           unlimitedKm: false,
//           hourlyRate: 799,
//           dailyRate: 4999,
//           weekendRate: 5499,
//           weeklyRate: 28999,
//           monthlyRate: 89999,
//           extraKmRate: 25,
//         ),
//         KmPricingPackage(
//           id: 'fortuner_500',
//           name: '500 KM',
//           includedKm: 500,
//           unlimitedKm: false,
//           hourlyRate: 899,
//           dailyRate: 5499,
//           weekendRate: 5999,
//           weeklyRate: 31999,
//           monthlyRate: 99999,
//           extraKmRate: 24,
//         ),
//         KmPricingPackage(
//           id: 'fortuner_750',
//           name: '750 KM',
//           includedKm: 750,
//           unlimitedKm: false,
//           hourlyRate: 999,
//           dailyRate: 5999,
//           weekendRate: 6499,
//           weeklyRate: 34999,
//           monthlyRate: 109999,
//           extraKmRate: 22,
//         ),
//         KmPricingPackage(
//           id: 'fortuner_1000',
//           name: '1000 KM',
//           includedKm: 1000,
//           unlimitedKm: false,
//           hourlyRate: 1099,
//           dailyRate: 6499,
//           weekendRate: 6999,
//           weeklyRate: 37999,
//           monthlyRate: 119999,
//           extraKmRate: 20,
//         ),
//         KmPricingPackage(
//           id: 'fortuner_1500',
//           name: '1500 KM',
//           includedKm: 1500,
//           unlimitedKm: false,
//           hourlyRate: 1199,
//           dailyRate: 6999,
//           weekendRate: 7499,
//           weeklyRate: 40999,
//           monthlyRate: 129999,
//           extraKmRate: 18,
//         ),
//         KmPricingPackage(
//           id: 'fortuner_2000',
//           name: '2000 KM',
//           includedKm: 2000,
//           unlimitedKm: false,
//           hourlyRate: 1299,
//           dailyRate: 7499,
//           weekendRate: 7999,
//           weeklyRate: 43999,
//           monthlyRate: 139999,
//           extraKmRate: 16,
//         ),
//         KmPricingPackage(
//           id: 'fortuner_unlimited',
//           name: 'Unlimited',
//           includedKm: null,
//           unlimitedKm: true,
//           hourlyRate: 1399,
//           dailyRate: 8499,
//           weekendRate: 8999,
//           weeklyRate: 48999,
//           monthlyRate: 149999,
//           extraKmRate: 0,
//         ),
//       ],

//       unlimitedKmEnabled: true,
//       unlimitedKmSurcharge: 1800,

//       gracePeriodMinutes: 30,

//       extraHourRate: 699,

//       extraDayRate: 4999,

//       lateReturnRate: 799,

//       securityDeposit: 10000,

//       isActive: true,
//     ),
//   ],

//   // ===========================================================================
//   // KM SLABS
//   // ===========================================================================

//   kmSlabs: const [
//     KmSlab(
//       id: 'slab_001',
//       fromKm: 1,
//       toKm: 100,
//       pricePerKm: 15,
//       isActive: true,
//     ),

//     KmSlab(
//       id: 'slab_002',
//       fromKm: 101,
//       toKm: 300,
//       pricePerKm: 13,
//       isActive: true,
//     ),

//     KmSlab(
//       id: 'slab_003',
//       fromKm: 301,
//       toKm: 500,
//       pricePerKm: 11,
//       isActive: true,
//     ),

//     KmSlab(
//       id: 'slab_004',
//       fromKm: 501,
//       toKm: null,
//       pricePerKm: 9,
//       isActive: true,
//     ),
//   ],

//   // ===========================================================================
//   // RENTAL PACKAGES
//   // ===========================================================================

//   packages: const [
//     RentalPackage(
//       id: 'package_1_day',
//       name: '1 Day • 150 KM',
//       description:
//           '24 hours with 150 KM included.',
//       durationDays: 1,
//       durationHours: 24,
//       includedKm: 150,
//       unlimitedKm: false,
//       extraKmRate: 15,
//       price: 2499,
//       isBookable: true,
//       isActive: true,
//       badge: 'POPULAR',
//     ),

//     RentalPackage(
//       id: 'package_2_day',
//       name: '2 Days • 300 KM',
//       description:
//           '48 hours with 300 KM included.',
//       durationDays: 2,
//       durationHours: 48,
//       includedKm: 300,
//       unlimitedKm: false,
//       extraKmRate: 15,
//       price: 4699,
//       isBookable: true,
//       isActive: true,
//       badge: 'BEST VALUE',
//     ),

//     RentalPackage(
//       id: 'package_3_day',
//       name: '3 Days • 450 KM',
//       description:
//           '72 hours with 450 KM included.',
//       durationDays: 3,
//       durationHours: 72,
//       includedKm: 450,
//       unlimitedKm: false,
//       extraKmRate: 14,
//       price: 6499,
//       isBookable: true,
//       isActive: true,
//       badge: null,
//     ),

//     RentalPackage(
//       id: 'package_weekend',
//       name: 'Weekend Drive',
//       description:
//           'A flexible weekend package with 400 KM included.',
//       durationDays: 2,
//       durationHours: 48,
//       includedKm: 400,
//       unlimitedKm: false,
//       extraKmRate: 15,
//       price: 5499,
//       isBookable: true,
//       isActive: true,
//       badge: 'WEEKEND',
//     ),

//     RentalPackage(
//       id: 'package_7_day',
//       name: '7 Days • 1050 KM',
//       description:
//           'One week with 1050 KM included.',
//       durationDays: 7,
//       durationHours: 168,
//       includedKm: 1050,
//       unlimitedKm: false,
//       extraKmRate: 12,
//       price: 13999,
//       isBookable: true,
//       isActive: true,
//       badge: 'WEEKLY',
//     ),

//     RentalPackage(
//       id: 'package_unlimited',
//       name: 'Unlimited Drive',
//       description:
//           'Unlimited KM for a worry-free trip.',
//       durationDays: 1,
//       durationHours: 24,
//       includedKm: 0,
//       unlimitedKm: true,
//       extraKmRate: 0,
//       price: 3499,
//       isBookable: true,
//       isActive: true,
//       badge: 'UNLIMITED',
//     ),
//   ],

//   // ===========================================================================
//   // EXTRA CHARGES
//   // ===========================================================================

//   extraCharges: const [
//     ExtraCharge(
//       id: 'charge_home_delivery',
//       name: 'Home Delivery',
//       description:
//           'Vehicle delivery to the customer location.',
//       type: ExtraChargeType.delivery,
//       amount: 299,
//       unitPrice: null,
//       unit: 'booking',
//       isPerUnit: false,
//       isTaxable: true,
//       isOptional: true,
//       isCustomerVisible: true,
//       isActive: true,
//     ),

//     ExtraCharge(
//       id: 'charge_airport_pickup',
//       name: 'Airport Pickup',
//       description:
//           'Vehicle pickup service at the airport.',
//       type: ExtraChargeType.airport,
//       amount: 499,
//       unitPrice: null,
//       unit: 'booking',
//       isPerUnit: false,
//       isTaxable: true,
//       isOptional: true,
//       isCustomerVisible: true,
//       isActive: true,
//     ),

//     ExtraCharge(
//       id: 'charge_airport_drop',
//       name: 'Airport Drop',
//       description:
//           'Vehicle return/drop service at the airport.',
//       type: ExtraChargeType.airport,
//       amount: 499,
//       unitPrice: null,
//       unit: 'booking',
//       isPerUnit: false,
//       isTaxable: true,
//       isOptional: true,
//       isCustomerVisible: true,
//       isActive: true,
//     ),

//     ExtraCharge(
//       id: 'charge_convenience',
//       name: 'Convenience Fee',
//       description:
//           'Platform and booking convenience fee.',
//       type: ExtraChargeType.convenienceFee,
//       amount: 99,
//       unitPrice: null,
//       unit: 'booking',
//       isPerUnit: false,
//       isTaxable: true,
//       isOptional: false,
//       isCustomerVisible: true,
//       isActive: true,
//     ),
//   ],

//   // ===========================================================================
//   // ADD-ONS
//   // ===========================================================================

//   addOns: const [
//     AddOn(
//       id: 'addon_additional_driver',
//       name: 'Additional Driver',
//       description:
//           'Add another authorized driver.',
//       type: AddOnType.additionalDriver,
//       price: 199,
//       isPerUnit: true,
//       isPerDay: true,
//       maxQuantity: 1,
//       isTaxable: true,
//       isOptional: true,
//       isCustomerVisible: true,
//       isActive: true,
//     ),

//     AddOn(
//       id: 'addon_child_seat',
//       name: 'Child Seat',
//       description:
//           'Safety seat for children.',
//       type: AddOnType.childSeat,
//       price: 149,
//       isPerUnit: true,
//       isPerDay: true,
//       maxQuantity: 2,
//       isTaxable: true,
//       isOptional: true,
//       isCustomerVisible: true,
//       isActive: true,
//     ),

//     AddOn(
//       id: 'addon_baby_seat',
//       name: 'Baby Seat',
//       description:
//           'Baby safety seat.',
//       type: AddOnType.babySeat,
//       price: 149,
//       isPerUnit: true,
//       isPerDay: true,
//       maxQuantity: 1,
//       isTaxable: true,
//       isOptional: true,
//       isCustomerVisible: true,
//       isActive: true,
//     ),

//     AddOn(
//       id: 'addon_gps',
//       name: 'GPS Navigation',
//       description:
//           'Portable GPS navigation unit.',
//       type: AddOnType.gps,
//       price: 99,
//       isPerUnit: false,
//       isPerDay: true,
//       maxQuantity: 1,
//       isTaxable: true,
//       isOptional: true,
//       isCustomerVisible: true,
//       isActive: true,
//     ),

//     AddOn(
//       id: 'addon_wifi',
//       name: 'Portable Wi-Fi',
//       description:
//           'Portable internet connectivity.',
//       type: AddOnType.wifi,
//       price: 149,
//       isPerUnit: false,
//       isPerDay: true,
//       maxQuantity: 1,
//       isTaxable: true,
//       isOptional: true,
//       isCustomerVisible: true,
//       isActive: true,
//     ),

//     AddOn(
//       id: 'addon_fastag',
//       name: 'FASTag',
//       description:
//           'FASTag service for the rental.',
//       type: AddOnType.fastag,
//       price: 99,
//       isPerUnit: false,
//       isPerDay: false,
//       maxQuantity: 1,
//       isTaxable: true,
//       isOptional: true,
//       isCustomerVisible: true,
//       isActive: true,
//     ),
//   ],

//   // ===========================================================================
//   // PROTECTION PLANS
//   // ===========================================================================

//   protectionPlans: const [
//     ProtectionPlan(
//       id: 'protection_basic',
//       name: 'Basic Protection',
//       description:
//           'Basic protection for your rental.',
//       badge: 'BASIC',
//       price: 199,
//       isPerDay: true,
//       customerLiabilityLimit: 25000,
//       coversAccidentalDamage: true,
//       coversTheft: false,
//       coversThirdPartyDamage: true,
//       coversGlassDamage: false,
//       coversTyreDamage: false,
//       exclusions: [
//         'Negligent driving',
//         'Unauthorized driver',
//       ],
//       isTaxable: true,
//       isOptional: true,
//       isCustomerVisible: true,
//       isActive: true,
//     ),

//     ProtectionPlan(
//       id: 'protection_standard',
//       name: 'Standard Protection',
//       description:
//           'Enhanced protection with reduced liability.',
//       badge: 'RECOMMENDED',
//       price: 349,
//       isPerDay: true,
//       customerLiabilityLimit: 15000,
//       coversAccidentalDamage: true,
//       coversTheft: true,
//       coversThirdPartyDamage: true,
//       coversGlassDamage: true,
//       coversTyreDamage: false,
//       exclusions: [
//         'Negligent driving',
//         'Unauthorized driver',
//       ],
//       isTaxable: true,
//       isOptional: true,
//       isCustomerVisible: true,
//       isActive: true,
//     ),

//     ProtectionPlan(
//       id: 'protection_premium',
//       name: 'Premium Protection',
//       description:
//           'Maximum protection with minimal liability.',
//       badge: 'PREMIUM',
//       price: 549,
//       isPerDay: true,
//       customerLiabilityLimit: 7500,
//       coversAccidentalDamage: true,
//       coversTheft: true,
//       coversThirdPartyDamage: true,
//       coversGlassDamage: true,
//       coversTyreDamage: true,
//       exclusions: [
//         'Negligent driving',
//         'Unauthorized driver',
//       ],
//       isTaxable: true,
//       isOptional: true,
//       isCustomerVisible: true,
//       isActive: true,
//     ),
//   ],

//   // ===========================================================================
//   // DISCOUNTS
//   // ===========================================================================

//   discounts: const [
//     DiscountRule(
//       id: 'discount_welcome',
//       name: 'Welcome Offer',
//       description:
//           '10% off for eligible new bookings.',
//       couponCode: 'WELCOME10',
//       type: DiscountType.percentage,
//       percentage: 10,
//       fixedAmount: 0,
//       maximumDiscount: 1000,
//       minimumBookingAmount: 2000,
//       minimumRentalDays: null,
//       usageLimit: 1000,
//       usageLimitPerCustomer: 1,
//       vehicleIds: [],
//       branchIds: [],
//       customerIds: [],
//       validFrom: null,
//       validUntil: null,
//       applicableWeekdays: [],
//       canCombine: false,
//       isAutomatic: false,
//       isActive: true,
//       isCustomerVisible: true,
//     ),

//     DiscountRule(
//       id: 'discount_weekly',
//       name: 'Weekly Drive Offer',
//       description:
//           'Flat ₹750 discount on longer rentals.',
//       couponCode: 'WEEKLY750',
//       type: DiscountType.fixedAmount,
//       percentage: 0,
//       fixedAmount: 750,
//       maximumDiscount: null,
//       minimumBookingAmount: 10000,
//       minimumRentalDays: 7,
//       usageLimit: 500,
//       usageLimitPerCustomer: 2,
//       vehicleIds: [],
//       branchIds: [],
//       customerIds: [],
//       validFrom: null,
//       validUntil: null,
//       applicableWeekdays: [],
//       canCombine: false,
//       isAutomatic: true,
//       isActive: true,
//       isCustomerVisible: true,
//     ),
//   ],

//   // ===========================================================================
//   // TAXES
//   // ===========================================================================

//   taxes: const [
//     TaxRule(
//       id: 'tax_gst_18',
//       name: 'GST',
//       description:
//           '18% GST on applicable rental charges.',
//       type: TaxType.gst,
//       percentage: 18,
//       isInclusive: false,
//       appliesToRental: true,
//       appliesToExtraKm: true,
//       appliesToAddOns: true,
//       appliesToDelivery: true,
//       appliesToProtection: true,
//       appliesToExtraCharges: true,
//       vehicleIds: [],
//       branchIds: [],
//       isActive: true,
//       isCustomerVisible: true,
//     ),
//   ],

//   // ===========================================================================
//   // CANCELLATION RULES
//   // ===========================================================================

//   cancellationRules: const [
//     CancellationRule(
//       id: 'cancel_more_than_48',
//       name: '48+ Hours Before Pickup',
//       description:
//           'High refund when cancelled early.',
//       minimumHoursBeforePickup: 48,
//       maximumHoursBeforePickup: null,
//       refundPercentage: 100,
//       cancellationFee: 0,
//       feeFromRefund: false,
//       refundSecurityDeposit: true,
//       minimumBookingAmount: 0,
//       vehicleIds: [],
//       branchIds: [],
//       isActive: true,
//       isCustomerVisible: true,
//     ),

//     CancellationRule(
//       id: 'cancel_24_to_48',
//       name: '24–48 Hours Before Pickup',
//       description:
//           'Partial refund for cancellations within this window.',
//       minimumHoursBeforePickup: 24,
//       maximumHoursBeforePickup: 48,
//       refundPercentage: 75,
//       cancellationFee: 0,
//       feeFromRefund: true,
//       refundSecurityDeposit: true,
//       minimumBookingAmount: 0,
//       vehicleIds: [],
//       branchIds: [],
//       isActive: true,
//       isCustomerVisible: true,
//     ),

//     CancellationRule(
//       id: 'cancel_less_than_24',
//       name: 'Less Than 24 Hours',
//       description:
//           'Reduced refund for late cancellations.',
//       minimumHoursBeforePickup: 0,
//       maximumHoursBeforePickup: 24,
//       refundPercentage: 50,
//       cancellationFee: 0,
//       feeFromRefund: true,
//       refundSecurityDeposit: true,
//       minimumBookingAmount: 0,
//       vehicleIds: [],
//       branchIds: [],
//       isActive: true,
//       isCustomerVisible: true,
//     ),
//   ],

//   isActive: true,
// );