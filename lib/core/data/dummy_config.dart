const Map<String, dynamic> dummyTenantConfig = {
  'tenantId': 'tenant_001',

  'branding': {
    'appName': 'Royal Drive',
    'logoUrl': '',
    'splashImageUrl': '',
    'primaryColor': '#0B0F19',
    'secondaryColor': '#D4AF37',
  },

  'business': {
    'name': 'Royal Drive Rentals',
    'phone': '+91 98765 43210',
    'email': 'support@royaldrive.com',
    'currency': 'INR',
    'supportNumber': '+91 98765 43210',
  },

  'features': {
    'branches': true,
    'kmPackages': true,
    'onlinePayment': true,
    'coupons': true,
    'extensions': true,
    'delivery': true,
  },

  'branches': [
    {
      'id': 'branch_001',
      'name': 'Baner',
      'city': 'Pune',
      'address': 'Baner Road, Pune',
    },
    {
      'id': 'branch_002',
      'name': 'Viman Nagar',
      'city': 'Pune',
      'address': 'Viman Nagar, Pune',
    },
    {
      'id': 'branch_003',
      'name': 'Hinjewadi',
      'city': 'Pune',
      'address': 'Hinjewadi Phase 1, Pune',
    },
  ],
};