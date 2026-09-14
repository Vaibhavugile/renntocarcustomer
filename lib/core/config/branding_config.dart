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

  factory BrandingConfig.fromMap(Map<String, dynamic> map) {
    return BrandingConfig(
      appName: map['appName'] ?? '',
      logoUrl: map['logoUrl'] ?? '',
      splashImageUrl: map['splashImageUrl'] ?? '',
      primaryColor: map['primaryColor'] ?? '#0B0F19',
      secondaryColor: map['secondaryColor'] ?? '#D4AF37',
    );
  }
}