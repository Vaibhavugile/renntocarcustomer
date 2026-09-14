class FeatureConfig {
  final bool branches;
  final bool kmPackages;
  final bool onlinePayment;
  final bool coupons;
  final bool extensions;
  final bool delivery;

  const FeatureConfig({
    required this.branches,
    required this.kmPackages,
    required this.onlinePayment,
    required this.coupons,
    required this.extensions,
    required this.delivery,
  });

  factory FeatureConfig.fromMap(Map<String, dynamic> map) {
    return FeatureConfig(
      branches: map['branches'] ?? false,
      kmPackages: map['kmPackages'] ?? false,
      onlinePayment: map['onlinePayment'] ?? false,
      coupons: map['coupons'] ?? false,
      extensions: map['extensions'] ?? false,
      delivery: map['delivery'] ?? false,
    );
  }
}