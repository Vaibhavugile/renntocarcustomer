class Branch {
  final String id;
  final String name;
  final String city;
  final String address;
  final String phone;
  final bool isActive;

  const Branch({
    required this.id,
    required this.name,
    required this.city,
    required this.address,
    required this.phone,
    required this.isActive,
  });

  factory Branch.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    return Branch(
      id: id,
      name: map['name'] ?? '',
      city: map['city'] ?? '',
      address: map['address'] ?? '',
      phone: map['phone'] ?? '',
      isActive: map['isActive'] ?? false,
    );
  }
}