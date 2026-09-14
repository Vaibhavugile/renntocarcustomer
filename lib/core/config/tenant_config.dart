class TenantConfig {
  final String tenantId;
  final BrandingConfig branding;
  final BusinessConfig business;
  final FeatureConfig features;

  const TenantConfig({
    required this.tenantId,
    required this.branding,
    required this.business,
    required this.features,
  });

  factory TenantConfig.fromMap(Map<String, dynamic> map) {
    return TenantConfig(
      tenantId: map['tenantId'] ?? '',

      branding: BrandingConfig(
        appName: map['appName'] ?? '',
        logoUrl: map['logoUrl'] ?? '',
        splashImageUrl: map['splashImageUrl'] ?? '',
        primaryColor: map['primaryColor'] ?? '#0B0F19',
        secondaryColor: map['secondaryColor'] ?? '#D4AF37',
      ),

      business: BusinessConfig(
        name: map['businessName'] ?? '',
        phone: map['phone'] ?? '',
        email: map['email'] ?? '',
        currency: map['currency'] ?? 'INR',
        supportNumber: map['supportNumber'] ?? '',
      ),

      features: FeatureConfig.fromMap(
        Map<String, dynamic>.from(
          map['features'] ?? {},
        ),
      ),
    );
  }
}

class BrandingConfig {
  final String appName;
  final String logoUrl;
  final String splashImageUrl;
  final String primaryColor;
  final String secondaryColor;

  const BrandingConfig({
    required this.appName,
    required this.logoUrl,
    required this.splashImageUrl,
    required this.primaryColor,
    required this.secondaryColor,
  });
}

class BusinessConfig {
  final String name;
  final String phone;
  final String email;
  final String currency;
  final String supportNumber;

  const BusinessConfig({
    required this.name,
    required this.phone,
    required this.email,
    required this.currency,
    required this.supportNumber,
  });
}

class FeatureConfig {
  final bool branches;
  final bool booking;
  final bool payments;
  final bool kmPackages;
  final bool coupons;
  final bool extensions;
  final bool notifications;

  const FeatureConfig({
    required this.branches,
    required this.booking,
    required this.payments,
    required this.kmPackages,
    required this.coupons,
    required this.extensions,
    required this.notifications,
  });

  factory FeatureConfig.fromMap(Map<String, dynamic> map) {
    return FeatureConfig(
      branches: map['branches'] ?? false,
      booking: map['booking'] ?? false,
      payments: map['payments'] ?? false,
      kmPackages: map['kmPackages'] ?? false,
      coupons: map['coupons'] ?? false,
      extensions: map['extensions'] ?? false,
      notifications: map['notifications'] ?? false,
    );
  }
}