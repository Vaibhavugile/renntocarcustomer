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

  factory BusinessConfig.fromMap(Map<String, dynamic> map) {
    return BusinessConfig(
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      currency: map['currency'] ?? 'INR',
      supportNumber: map['supportNumber'] ?? '',
    );
  }
}