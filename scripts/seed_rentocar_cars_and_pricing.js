/**
 * Rentocar — Exact Cars + Pricing Firestore Seed
 *
 * Tenant:
 *   tenant_001
 *
 * Run from Flutter project root:
 *
 *   node scripts/seed_rentocar_cars_and_pricing_exact.js
 *
 * Required:
 *
 *   npm install firebase-admin
 *
 * IMPORTANT:
 * - Everything is stored ONLY inside tenants/tenant_001.
 * - Old car IDs are removed before creating the exact new car IDs.
 * - Nothing outside tenant_001 is touched.
 * - Firebase branding colors are NOT used.
 * - Cars and pricing profiles are stored separately.
 * - Cars are linked to pricing through pricingProfileId.
 */

const {
  initializeApp,
  cert,
  getApps,
  deleteApp,
} = require("firebase-admin/app");

const {
  getFirestore,
  FieldValue,
} = require("firebase-admin/firestore");


// ============================================================================
// SERVICE ACCOUNT
// ============================================================================

const serviceAccount = require("../serviceAccountKey.json");


// ============================================================================
// TENANT
// ============================================================================

const TENANT_ID = "tenant_001";


// ============================================================================
// FIREBASE INITIALIZATION
// ============================================================================

if (!getApps().length) {
  initializeApp({
    credential: cert(serviceAccount),
  });
}

const db = getFirestore();

const tenantRef = db
  .collection("tenants")
  .doc(TENANT_ID);


// ============================================================================
// EXACT CARS FROM YOUR dummy_cars.dart
// ============================================================================

const cars = [
  {
    id: "car_001",

    tenantId: TENANT_ID,

    name: "Hyundai Creta",

    type: "SUV",

    transmission: "Automatic",

    seats: 5,

    fuel: "Petrol",

    pricingProfileId: "pricing_creta",

    pricePerDay: 2499,

    image:
      "https://images.unsplash.com/photo-1606664515524-ed2f786a0bd6",

    isAvailable: true,

    isFeatured: true,

    // Platform fields
    isActive: true,

    status: "active",

    branchIds: [
      "branch_001",
      "branch_002",
      "branch_003",
    ],

    description:
      "Comfortable automatic SUV suitable for city drives, weekend trips and family travel.",

    features: [
      "AC",
      "Bluetooth",
      "GPS",
      "Rear Camera",
    ],

    sortOrder: 1,
  },

  {
    id: "car_002",

    tenantId: TENANT_ID,

    name: "Kia Seltos",

    type: "SUV",

    transmission: "Automatic",

    seats: 5,

    fuel: "Petrol",

    pricingProfileId: "pricing_seltos",

    pricePerDay: 2699,

    image:
      "https://images.unsplash.com/photo-1549317661-bd32c8ce0db2",

    isAvailable: true,

    isFeatured: true,

    // Platform fields
    isActive: true,

    status: "active",

    branchIds: [
      "branch_001",
      "branch_002",
      "branch_003",
    ],

    description:
      "Premium automatic SUV with a comfortable cabin and smooth city and highway performance.",

    features: [
      "AC",
      "Bluetooth",
      "GPS",
      "Rear Camera",
    ],

    sortOrder: 2,
  },

  {
    id: "car_003",

    tenantId: TENANT_ID,

    name: "Honda City",

    type: "Sedan",

    transmission: "Automatic",

    seats: 5,

    fuel: "Petrol",

    pricingProfileId: "pricing_city",

    pricePerDay: 2199,

    image:
      "https://images.unsplash.com/photo-1550355291-bbee04a92027",

    isAvailable: true,

    isFeatured: true,

    // Platform fields
    isActive: true,

    status: "active",

    branchIds: [
      "branch_001",
      "branch_002",
      "branch_003",
    ],

    description:
      "Refined automatic sedan ideal for comfortable city and long-distance travel.",

    features: [
      "AC",
      "Bluetooth",
      "GPS",
      "Rear Camera",
    ],

    sortOrder: 3,
  },

  {
    id: "car_004",

    tenantId: TENANT_ID,

    name: "Toyota Fortuner",

    type: "Luxury",

    transmission: "Automatic",

    seats: 7,

    fuel: "Diesel",

    pricingProfileId: "pricing_fortuner",

    pricePerDay: 4999,

    image:
      "https://images.unsplash.com/photo-1519641471654-76ce0107ad1b",

    isAvailable: true,

    isFeatured: true,

    // Platform fields
    isActive: true,

    status: "active",

    branchIds: [
      "branch_001",
      "branch_002",
      "branch_003",
    ],

    description:
      "Premium 7-seater SUV for family travel, highway journeys and premium rentals.",

    features: [
      "AC",
      "Bluetooth",
      "GPS",
      "Rear Camera",
      "7 Seats",
    ],

    sortOrder: 4,
  },
];


// ============================================================================
// VEHICLE PRICING PROFILES
// ============================================================================

const pricingProfiles = [

  // ==========================================================================
  // HYUNDAI CRETA
  // ==========================================================================

  {
    id: "pricing_creta",

    tenantId: TENANT_ID,

    vehicleId: "car_001",

    name: "Hyundai Creta Pricing",

    currency: "INR",

    hourlyRate: 399,

    dailyRate: 2499,

    weekendRate: 2799,

    weeklyRate: 13999,

    monthlyRate: 44999,

    kmPricingMode: "package",

    includedKmPerDay: 150,

    kmOptions: [
      150,
      300,
      500,
      750,
      1000,
      1500,
    ],

    perKmRate: 18,

    extraKmRate: 15,

    unlimitedKmEnabled: true,

    unlimitedKmSurcharge: 1000,

    gracePeriodMinutes: 30,

    extraHourRate: 299,

    extraDayRate: 2499,

    lateReturnRate: 349,

    securityDeposit: 5000,

    kmPackages: [

      {
        id: "creta_basic_150",

        name: "Basic",

        includedKm: 150,

        unlimitedKm: false,

        hourlyRate: 399,

        dailyRate: 2499,

        weekendRate: 2799,

        weeklyRate: 13999,

        monthlyRate: 44999,

        extraKmRate: 15,
      },

      {
        id: "creta_250",

        name: "250 KM",

        includedKm: 250,

        unlimitedKm: false,

        hourlyRate: 449,

        dailyRate: 2799,

        weekendRate: 3099,

        weeklyRate: 15499,

        monthlyRate: 49999,

        extraKmRate: 15,
      },

      {
        id: "creta_500",

        name: "500 KM",

        includedKm: 500,

        unlimitedKm: false,

        hourlyRate: 499,

        dailyRate: 3199,

        weekendRate: 3499,

        weeklyRate: 16999,

        monthlyRate: 54999,

        extraKmRate: 14,
      },

      {
        id: "creta_750",

        name: "750 KM",

        includedKm: 750,

        unlimitedKm: false,

        hourlyRate: 549,

        dailyRate: 3499,

        weekendRate: 3799,

        weeklyRate: 18499,

        monthlyRate: 59999,

        extraKmRate: 13,
      },

      {
        id: "creta_1000",

        name: "1000 KM",

        includedKm: 1000,

        unlimitedKm: false,

        hourlyRate: 599,

        dailyRate: 3799,

        weekendRate: 4099,

        weeklyRate: 19999,

        monthlyRate: 64999,

        extraKmRate: 12,
      },

      {
        id: "creta_1500",

        name: "1500 KM",

        includedKm: 1500,

        unlimitedKm: false,

        hourlyRate: 649,

        dailyRate: 4199,

        weekendRate: 4499,

        weeklyRate: 21999,

        monthlyRate: 69999,

        extraKmRate: 11,
      },

      {
        id: "creta_unlimited",

        name: "Unlimited",

        includedKm: null,

        unlimitedKm: true,

        hourlyRate: 699,

        dailyRate: 4499,

        weekendRate: 4899,

        weeklyRate: 23999,

        monthlyRate: 74999,

        extraKmRate: 0,
      },
    ],

    isActive: true,
  },


  // ==========================================================================
  // KIA SELTOS
  // ==========================================================================

  {
    id: "pricing_seltos",

    tenantId: TENANT_ID,

    vehicleId: "car_002",

    name: "Kia Seltos Pricing",

    currency: "INR",

    hourlyRate: 449,

    dailyRate: 2699,

    weekendRate: 2999,

    weeklyRate: 14999,

    monthlyRate: 47999,

    kmPricingMode: "package",

    includedKmPerDay: 150,

    kmOptions: [
      150,
      300,
      500,
      750,
      1000,
      1500,
    ],

    perKmRate: 19,

    extraKmRate: 16,

    unlimitedKmEnabled: true,

    unlimitedKmSurcharge: 1100,

    gracePeriodMinutes: 30,

    extraHourRate: 349,

    extraDayRate: 2699,

    lateReturnRate: 399,

    securityDeposit: 5000,

    kmPackages: [

      {
        id: "seltos_basic_150",

        name: "Basic",

        includedKm: 150,

        unlimitedKm: false,

        hourlyRate: 449,

        dailyRate: 2699,

        weekendRate: 2999,

        weeklyRate: 14999,

        monthlyRate: 47999,

        extraKmRate: 16,
      },

      {
        id: "seltos_250",

        name: "250 KM",

        includedKm: 250,

        unlimitedKm: false,

        hourlyRate: 499,

        dailyRate: 2999,

        weekendRate: 3299,

        weeklyRate: 16499,

        monthlyRate: 52999,

        extraKmRate: 16,
      },

      {
        id: "seltos_500",

        name: "500 KM",

        includedKm: 500,

        unlimitedKm: false,

        hourlyRate: 549,

        dailyRate: 3399,

        weekendRate: 3699,

        weeklyRate: 17999,

        monthlyRate: 57999,

        extraKmRate: 15,
      },

      {
        id: "seltos_750",

        name: "750 KM",

        includedKm: 750,

        unlimitedKm: false,

        hourlyRate: 599,

        dailyRate: 3699,

        weekendRate: 3999,

        weeklyRate: 19499,

        monthlyRate: 62999,

        extraKmRate: 14,
      },

      {
        id: "seltos_1000",

        name: "1000 KM",

        includedKm: 1000,

        unlimitedKm: false,

        hourlyRate: 649,

        dailyRate: 3999,

        weekendRate: 4299,

        weeklyRate: 20999,

        monthlyRate: 67999,

        extraKmRate: 13,
      },

      {
        id: "seltos_1500",

        name: "1500 KM",

        includedKm: 1500,

        unlimitedKm: false,

        hourlyRate: 699,

        dailyRate: 4399,

        weekendRate: 4699,

        weeklyRate: 22999,

        monthlyRate: 72999,

        extraKmRate: 12,
      },

      {
        id: "seltos_unlimited",

        name: "Unlimited",

        includedKm: null,

        unlimitedKm: true,

        hourlyRate: 749,

        dailyRate: 4899,

        weekendRate: 5299,

        weeklyRate: 24999,

        monthlyRate: 77999,

        extraKmRate: 0,
      },
    ],

    isActive: true,
  },


  // ==========================================================================
  // HONDA CITY
  // ==========================================================================

  {
    id: "pricing_city",

    tenantId: TENANT_ID,

    vehicleId: "car_003",

    name: "Honda City Pricing",

    currency: "INR",

    hourlyRate: 349,

    dailyRate: 2199,

    weekendRate: 2499,

    weeklyRate: 12499,

    monthlyRate: 39999,

    kmPricingMode: "package",

    includedKmPerDay: 150,

    kmOptions: [
      150,
      300,
      500,
      750,
      1000,
      1500,
    ],

    perKmRate: 17,

    extraKmRate: 14,

    unlimitedKmEnabled: true,

    unlimitedKmSurcharge: 900,

    gracePeriodMinutes: 30,

    extraHourRate: 249,

    extraDayRate: 2199,

    lateReturnRate: 299,

    securityDeposit: 4000,

    kmPackages: [

      {
        id: "city_basic_150",

        name: "Basic",

        includedKm: 150,

        unlimitedKm: false,

        hourlyRate: 349,

        dailyRate: 2199,

        weekendRate: 2499,

        weeklyRate: 12499,

        monthlyRate: 39999,

        extraKmRate: 14,
      },

      {
        id: "city_250",

        name: "250 KM",

        includedKm: 250,

        unlimitedKm: false,

        hourlyRate: 399,

        dailyRate: 2499,

        weekendRate: 2799,

        weeklyRate: 13999,

        monthlyRate: 43999,

        extraKmRate: 14,
      },

      {
        id: "city_500",

        name: "500 KM",

        includedKm: 500,

        unlimitedKm: false,

        hourlyRate: 449,

        dailyRate: 2799,

        weekendRate: 3099,

        weeklyRate: 15499,

        monthlyRate: 47999,

        extraKmRate: 13,
      },

      {
        id: "city_750",

        name: "750 KM",

        includedKm: 750,

        unlimitedKm: false,

        hourlyRate: 499,

        dailyRate: 3099,

        weekendRate: 3399,

        weeklyRate: 16999,

        monthlyRate: 51999,

        extraKmRate: 12,
      },

      {
        id: "city_1000",

        name: "1000 KM",

        includedKm: 1000,

        unlimitedKm: false,

        hourlyRate: 549,

        dailyRate: 3399,

        weekendRate: 3699,

        weeklyRate: 18499,

        monthlyRate: 55999,

        extraKmRate: 11,
      },

      {
        id: "city_1500",

        name: "1500 KM",

        includedKm: 1500,

        unlimitedKm: false,

        hourlyRate: 599,

        dailyRate: 3799,

        weekendRate: 4099,

        weeklyRate: 20499,

        monthlyRate: 59999,

        extraKmRate: 10,
      },

      {
        id: "city_unlimited",

        name: "Unlimited",

        includedKm: null,

        unlimitedKm: true,

        hourlyRate: 649,

        dailyRate: 3999,

        weekendRate: 4399,

        weeklyRate: 21999,

        monthlyRate: 64999,

        extraKmRate: 0,
      },
    ],

    isActive: true,
  },


  // ==========================================================================
  // TOYOTA FORTUNER
  // ==========================================================================

  {
    id: "pricing_fortuner",

    tenantId: TENANT_ID,

    vehicleId: "car_004",

    name: "Toyota Fortuner Pricing",

    currency: "INR",

    hourlyRate: 799,

    dailyRate: 4999,

    weekendRate: 5499,

    weeklyRate: 28999,

    monthlyRate: 89999,

    kmPricingMode: "package",

    includedKmPerDay: 200,

    kmOptions: [
      200,
      500,
      750,
      1000,
      1500,
      2000,
    ],

    perKmRate: 30,

    extraKmRate: 25,

    unlimitedKmEnabled: true,

    unlimitedKmSurcharge: 1800,

    gracePeriodMinutes: 30,

    extraHourRate: 699,

    extraDayRate: 4999,

    lateReturnRate: 799,

    securityDeposit: 10000,

    kmPackages: [

      {
        id: "fortuner_basic_200",

        name: "Basic",

        includedKm: 200,

        unlimitedKm: false,

        hourlyRate: 799,

        dailyRate: 4999,

        weekendRate: 5499,

        weeklyRate: 28999,

        monthlyRate: 89999,

        extraKmRate: 25,
      },

      {
        id: "fortuner_500",

        name: "500 KM",

        includedKm: 500,

        unlimitedKm: false,

        hourlyRate: 899,

        dailyRate: 5499,

        weekendRate: 5999,

        weeklyRate: 31999,

        monthlyRate: 99999,

        extraKmRate: 24,
      },

      {
        id: "fortuner_750",

        name: "750 KM",

        includedKm: 750,

        unlimitedKm: false,

        hourlyRate: 999,

        dailyRate: 5999,

        weekendRate: 6499,

        weeklyRate: 34999,

        monthlyRate: 109999,

        extraKmRate: 22,
      },

      {
        id: "fortuner_1000",

        name: "1000 KM",

        includedKm: 1000,

        unlimitedKm: false,

        hourlyRate: 1099,

        dailyRate: 6499,

        weekendRate: 6999,

        weeklyRate: 37999,

        monthlyRate: 119999,

        extraKmRate: 20,
      },

      {
        id: "fortuner_1500",

        name: "1500 KM",

        includedKm: 1500,

        unlimitedKm: false,

        hourlyRate: 1199,

        dailyRate: 6999,

        weekendRate: 7499,

        weeklyRate: 40999,

        monthlyRate: 129999,

        extraKmRate: 18,
      },

      {
        id: "fortuner_2000",

        name: "2000 KM",

        includedKm: 2000,

        unlimitedKm: false,

        hourlyRate: 1299,

        dailyRate: 7499,

        weekendRate: 7999,

        weeklyRate: 43999,

        monthlyRate: 139999,

        extraKmRate: 16,
      },

      {
        id: "fortuner_unlimited",

        name: "Unlimited",

        includedKm: null,

        unlimitedKm: true,

        hourlyRate: 1399,

        dailyRate: 8499,

        weekendRate: 8999,

        weeklyRate: 48999,

        monthlyRate: 149999,

        extraKmRate: 0,
      },
    ],

    isActive: true,
  },
];


// ============================================================================
// TENANT-LEVEL PRICING
// ============================================================================

const tenantPricing = {
  tenantId: TENANT_ID,

  pricingConfigId: "pricing_rentocar",

  currency: "INR",


  // ==========================================================================
  // KM SLABS
  // ==========================================================================

  kmSlabs: [

    {
      id: "slab_001",

      fromKm: 1,

      toKm: 100,

      pricePerKm: 15,

      isActive: true,
    },

    {
      id: "slab_002",

      fromKm: 101,

      toKm: 300,

      pricePerKm: 13,

      isActive: true,
    },

    {
      id: "slab_003",

      fromKm: 301,

      toKm: 500,

      pricePerKm: 11,

      isActive: true,
    },

    {
      id: "slab_004",

      fromKm: 501,

      toKm: null,

      pricePerKm: 9,

      isActive: true,
    },
  ],


  // ==========================================================================
  // TENANT RENTAL PACKAGES
  // ==========================================================================

  rentalPackages: [

    {
      id: "package_1_day",

      name: "1 Day • 150 KM",

      description:
        "24 hours with 150 KM included.",

      durationDays: 1,

      durationHours: 24,

      includedKm: 150,

      unlimitedKm: false,

      extraKmRate: 15,

      price: 2499,

      isBookable: true,

      isActive: true,

      badge: "POPULAR",
    },

    {
      id: "package_2_day",

      name: "2 Days • 300 KM",

      description:
        "48 hours with 300 KM included.",

      durationDays: 2,

      durationHours: 48,

      includedKm: 300,

      unlimitedKm: false,

      extraKmRate: 15,

      price: 4699,

      isBookable: true,

      isActive: true,

      badge: "BEST VALUE",
    },

    {
      id: "package_3_day",

      name: "3 Days • 450 KM",

      description:
        "72 hours with 450 KM included.",

      durationDays: 3,

      durationHours: 72,

      includedKm: 450,

      unlimitedKm: false,

      extraKmRate: 14,

      price: 6499,

      isBookable: true,

      isActive: true,

      badge: null,
    },

    {
      id: "package_weekend",

      name: "Weekend Drive",

      description:
        "A flexible weekend package with 400 KM included.",

      durationDays: 2,

      durationHours: 48,

      includedKm: 400,

      unlimitedKm: false,

      extraKmRate: 15,

      price: 5499,

      isBookable: true,

      isActive: true,

      badge: "WEEKEND",
    },

    {
      id: "package_7_day",

      name: "7 Days • 1050 KM",

      description:
        "One week with 1050 KM included.",

      durationDays: 7,

      durationHours: 168,

      includedKm: 1050,

      unlimitedKm: false,

      extraKmRate: 12,

      price: 13999,

      isBookable: true,

      isActive: true,

      badge: "WEEKLY",
    },

    {
      id: "package_unlimited",

      name: "Unlimited Drive",

      description:
        "Unlimited KM for a worry-free trip.",

      durationDays: 1,

      durationHours: 24,

      includedKm: 0,

      unlimitedKm: true,

      extraKmRate: 0,

      price: 3499,

      isBookable: true,

      isActive: true,

      badge: "UNLIMITED",
    },
  ],


  // ==========================================================================
  // EXTRA CHARGES
  // ==========================================================================

  extraCharges: [

    {
      id: "charge_home_delivery",

      name: "Home Delivery",

      description:
        "Vehicle delivery to the customer location.",

      type: "delivery",

      amount: 299,

      unitPrice: null,

      unit: "booking",

      isPerUnit: false,

      isTaxable: true,

      isOptional: true,

      isCustomerVisible: true,

      isActive: true,
    },

    {
      id: "charge_airport_pickup",

      name: "Airport Pickup",

      description:
        "Vehicle pickup service at the airport.",

      type: "airport",

      amount: 499,

      unitPrice: null,

      unit: "booking",

      isPerUnit: false,

      isTaxable: true,

      isOptional: true,

      isCustomerVisible: true,

      isActive: true,
    },

    {
      id: "charge_airport_drop",

      name: "Airport Drop",

      description:
        "Vehicle return/drop service at the airport.",

      type: "airport",

      amount: 499,

      unitPrice: null,

      unit: "booking",

      isPerUnit: false,

      isTaxable: true,

      isOptional: true,

      isCustomerVisible: true,

      isActive: true,
    },

    {
      id: "charge_convenience",

      name: "Convenience Fee",

      description:
        "Platform and booking convenience fee.",

      type: "convenienceFee",

      amount: 99,

      unitPrice: null,

      unit: "booking",

      isPerUnit: false,

      isTaxable: true,

      isOptional: false,

      isCustomerVisible: true,

      isActive: true,
    },
  ],


  // ==========================================================================
  // ADD-ONS
  // ==========================================================================

  addOns: [

    {
      id: "addon_additional_driver",

      name: "Additional Driver",

      description:
        "Add another authorized driver.",

      type: "additionalDriver",

      price: 199,

      isPerUnit: true,

      isPerDay: true,

      maxQuantity: 1,

      isTaxable: true,

      isOptional: true,

      isCustomerVisible: true,

      isActive: true,
    },

    {
      id: "addon_child_seat",

      name: "Child Seat",

      description:
        "Safety seat for children.",

      type: "childSeat",

      price: 149,

      isPerUnit: true,

      isPerDay: true,

      maxQuantity: 2,

      isTaxable: true,

      isOptional: true,

      isCustomerVisible: true,

      isActive: true,
    },

    {
      id: "addon_baby_seat",

      name: "Baby Seat",

      description:
        "Baby safety seat.",

      type: "babySeat",

      price: 149,

      isPerUnit: true,

      isPerDay: true,

      maxQuantity: 1,

      isTaxable: true,

      isOptional: true,

      isCustomerVisible: true,

      isActive: true,
    },

    {
      id: "addon_gps",

      name: "GPS Navigation",

      description:
        "Portable GPS navigation unit.",

      type: "gps",

      price: 99,

      isPerUnit: false,

      isPerDay: true,

      maxQuantity: 1,

      isTaxable: true,

      isOptional: true,

      isCustomerVisible: true,

      isActive: true,
    },

    {
      id: "addon_wifi",

      name: "Portable Wi-Fi",

      description:
        "Portable internet connectivity.",

      type: "wifi",

      price: 149,

      isPerUnit: false,

      isPerDay: true,

      maxQuantity: 1,

      isTaxable: true,

      isOptional: true,

      isCustomerVisible: true,

      isActive: true,
    },

    {
      id: "addon_fastag",

      name: "FASTag",

      description:
        "FASTag service for the rental.",

      type: "fastag",

      price: 99,

      isPerUnit: false,

      isPerDay: false,

      maxQuantity: 1,

      isTaxable: true,

      isOptional: true,

      isCustomerVisible: true,

      isActive: true,
    },
  ],


  // ==========================================================================
  // PROTECTION PLANS
  // ==========================================================================

  protectionPlans: [

    {
      id: "protection_basic",

      name: "Basic Protection",

      description:
        "Basic protection for your rental.",

      badge: "BASIC",

      price: 199,

      isPerDay: true,

      customerLiabilityLimit: 25000,

      coversAccidentalDamage: true,

      coversTheft: false,

      coversThirdPartyDamage: true,

      coversGlassDamage: false,

      coversTyreDamage: false,

      exclusions: [
        "Negligent driving",
        "Unauthorized driver",
      ],

      isTaxable: true,

      isOptional: true,

      isCustomerVisible: true,

      isActive: true,
    },

    {
      id: "protection_standard",

      name: "Standard Protection",

      description:
        "Enhanced protection with reduced liability.",

      badge: "RECOMMENDED",

      price: 349,

      isPerDay: true,

      customerLiabilityLimit: 15000,

      coversAccidentalDamage: true,

      coversTheft: true,

      coversThirdPartyDamage: true,

      coversGlassDamage: true,

      coversTyreDamage: false,

      exclusions: [
        "Negligent driving",
        "Unauthorized driver",
      ],

      isTaxable: true,

      isOptional: true,

      isCustomerVisible: true,

      isActive: true,
    },

    {
      id: "protection_premium",

      name: "Premium Protection",

      description:
        "Maximum protection with minimal liability.",

      badge: "PREMIUM",

      price: 549,

      isPerDay: true,

      customerLiabilityLimit: 7500,

      coversAccidentalDamage: true,

      coversTheft: true,

      coversThirdPartyDamage: true,

      coversGlassDamage: true,

      coversTyreDamage: true,

      exclusions: [
        "Negligent driving",
        "Unauthorized driver",
      ],

      isTaxable: true,

      isOptional: true,

      isCustomerVisible: true,

      isActive: true,
    },
  ],


  // ==========================================================================
  // DISCOUNTS
  // ==========================================================================

  discounts: [

    {
      id: "discount_welcome",

      name: "Welcome Offer",

      description:
        "10% off for eligible new bookings.",

      couponCode: "WELCOME10",

      type: "percentage",

      percentage: 10,

      fixedAmount: 0,

      maximumDiscount: 1000,

      minimumBookingAmount: 2000,

      minimumRentalDays: null,

      usageLimit: 1000,

      usageLimitPerCustomer: 1,

      vehicleIds: [],

      branchIds: [],

      customerIds: [],

      validFrom: null,

      validUntil: null,

      applicableWeekdays: [],

      canCombine: false,

      isAutomatic: false,

      isActive: true,

      isCustomerVisible: true,
    },

    {
      id: "discount_weekly",

      name: "Weekly Drive Offer",

      description:
        "Flat ₹750 discount on longer rentals.",

      couponCode: "WEEKLY750",

      type: "fixedAmount",

      percentage: 0,

      fixedAmount: 750,

      maximumDiscount: null,

      minimumBookingAmount: 10000,

      minimumRentalDays: 7,

      usageLimit: 500,

      usageLimitPerCustomer: 2,

      vehicleIds: [],

      branchIds: [],

      customerIds: [],

      validFrom: null,

      validUntil: null,

      applicableWeekdays: [],

      canCombine: false,

      isAutomatic: true,

      isActive: true,

      isCustomerVisible: true,
    },
  ],


  // ==========================================================================
  // TAX
  // ==========================================================================

  taxes: [

    {
      id: "tax_gst_18",

      name: "GST",

      description:
        "18% GST on applicable rental charges.",

      type: "gst",

      percentage: 18,

      isInclusive: false,

      appliesToRental: true,

      appliesToExtraKm: true,

      appliesToAddOns: true,

      appliesToDelivery: true,

      appliesToProtection: true,

      appliesToExtraCharges: true,

      vehicleIds: [],

      branchIds: [],

      isActive: true,

      isCustomerVisible: true,
    },
  ],


  // ==========================================================================
  // CANCELLATION RULES
  // ==========================================================================

  cancellationRules: [

    {
      id: "cancel_more_than_48",

      name: "48+ Hours Before Pickup",

      description:
        "High refund when cancelled early.",

      minimumHoursBeforePickup: 48,

      maximumHoursBeforePickup: null,

      refundPercentage: 100,

      cancellationFee: 0,

      feeFromRefund: false,

      refundSecurityDeposit: true,

      minimumBookingAmount: 0,

      vehicleIds: [],

      branchIds: [],

      isActive: true,

      isCustomerVisible: true,
    },

    {
      id: "cancel_24_to_48",

      name: "24–48 Hours Before Pickup",

      description:
        "Partial refund for cancellations within this window.",

      minimumHoursBeforePickup: 24,

      maximumHoursBeforePickup: 48,

      refundPercentage: 75,

      cancellationFee: 0,

      feeFromRefund: true,

      refundSecurityDeposit: true,

      minimumBookingAmount: 0,

      vehicleIds: [],

      branchIds: [],

      isActive: true,

      isCustomerVisible: true,
    },

    {
      id: "cancel_less_than_24",

      name: "Less Than 24 Hours",

      description:
        "Reduced refund for late cancellations.",

      minimumHoursBeforePickup: 0,

      maximumHoursBeforePickup: 24,

      refundPercentage: 50,

      cancellationFee: 0,

      feeFromRefund: true,

      refundSecurityDeposit: true,

      minimumBookingAmount: 0,

      vehicleIds: [],

      branchIds: [],

      isActive: true,

      isCustomerVisible: true,
    },
  ],


  isActive: true,
};


// ============================================================================
// SEED FUNCTION
// ============================================================================

async function seed() {

  console.log("");
  console.log("==============================================");
  console.log(" RENTOCAR FIREBASE SEED");
  console.log("==============================================");
  console.log("");
  console.log(`Tenant: ${TENANT_ID}`);
  console.log("");


  // ==========================================================================
  // ENSURE TENANT EXISTS
  // ==========================================================================

  console.log("🏢 Verifying tenant...");

  await tenantRef.set(
    {
      tenantId: TENANT_ID,

      updatedAt:
        FieldValue.serverTimestamp(),
    },
    {
      merge: true,
    }
  );

  console.log("   ✓ Tenant verified");

  console.log("");


  // ==========================================================================
  // DELETE OLD CAR DOCUMENTS
  //
  // IMPORTANT:
  // Only old car documents are deleted.
  // Nothing else is touched.
  // ==========================================================================

  console.log("🧹 Removing previous car documents...");

  const previousCarIds = [
    "car_creta",
    "car_seltos",
    "car_city",
    "car_fortuner",
  ];

  for (const carId of previousCarIds) {

    await tenantRef
      .collection("cars")
      .doc(carId)
      .delete();

    console.log(
      `   ✓ Removed old ${carId}`
    );
  }

  console.log("");


  // ==========================================================================
  // WRITE EXACT CARS
  // ==========================================================================

  console.log(
    "🚗 Writing exact dummy_cars data..."
  );

  for (const car of cars) {

    await tenantRef
      .collection("cars")
      .doc(car.id)
      .set(
        {
          ...car,

          createdAt:
            FieldValue.serverTimestamp(),

          updatedAt:
            FieldValue.serverTimestamp(),
        },
        {
          merge: true,
        }
      );

    console.log(
      `   ✓ ${car.name} (${car.id})`
    );
  }

  console.log("");


  // ==========================================================================
  // WRITE VEHICLE PRICING PROFILES
  // ==========================================================================

  console.log(
    "💰 Writing vehicle pricing profiles..."
  );

  for (const profile of pricingProfiles) {

    await tenantRef
      .collection("pricingProfiles")
      .doc(profile.id)
      .set(
        {
          ...profile,

          createdAt:
            FieldValue.serverTimestamp(),

          updatedAt:
            FieldValue.serverTimestamp(),
        },
        {
          merge: true,
        }
      );

    console.log(
      `   ✓ ${profile.name} (${profile.id})`
    );

    console.log(
      `     └─ ${profile.kmPackages.length} KM packages`
    );
  }

  console.log("");


  // ==========================================================================
  // WRITE TENANT-LEVEL PRICING
  // ==========================================================================

  console.log(
    "⚙️ Writing tenant-level pricing..."
  );

  await tenantRef
    .collection("pricing")
    .doc("pricing_rentocar")
    .set(
      {
        ...tenantPricing,

        createdAt:
          FieldValue.serverTimestamp(),

        updatedAt:
          FieldValue.serverTimestamp(),
      },
      {
        merge: true,
      }
    );

  console.log(
    "   ✓ pricing_rentocar"
  );

  console.log("");


  // ==========================================================================
  // SUMMARY
  // ==========================================================================

  console.log(
    "=============================================="
  );

  console.log(
    " ✅ RENTOCAR FIREBASE SEED COMPLETE"
  );

  console.log(
    "=============================================="
  );

  console.log("");

  console.log("Tenant:");
  console.log(
    `  tenants/${TENANT_ID}`
  );

  console.log("");

  console.log("Cars:");
  console.log(
    `  tenants/${TENANT_ID}/cars/`
  );

  console.log("");

  console.log("Pricing Profiles:");
  console.log(
    `  tenants/${TENANT_ID}/pricingProfiles/`
  );

  console.log("");

  console.log("Tenant Pricing:");
  console.log(
    `  tenants/${TENANT_ID}/pricing/pricing_rentocar`
  );

  console.log("");

  console.log(
    "Cars seeded:",
    cars.length
  );

  console.log(
    "Pricing profiles seeded:",
    pricingProfiles.length
  );

  console.log(
    "KM packages per vehicle:",
    pricingProfiles[0].kmPackages.length
  );

  console.log("");

  console.log("Extra charges: ✓");
  console.log("Add-ons: ✓");
  console.log("Protection plans: ✓");
  console.log("Discounts: ✓");
  console.log("Taxes: ✓");
  console.log("Cancellation rules: ✓");

  console.log("");

  console.log(
    "=============================================="
  );

  console.log(
    " Firebase data is tenant-scoped."
  );

  console.log(
    " No dummy fallback is required."
  );

  console.log(
    "=============================================="
  );

  console.log("");
}


// ============================================================================
// RUN
// ============================================================================

seed()
  .catch((error) => {

    console.error("");

    console.error(
      "❌ SEED FAILED"
    );

    console.error(error);

    process.exit(1);
  })
  .finally(async () => {

    const apps = getApps();

    if (apps.length) {

      await deleteApp(
        apps[0]
      );
    }
  });