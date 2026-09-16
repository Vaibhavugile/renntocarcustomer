class Branch {
  final String id;
  final String tenantId;

  final String name;
  final String city;
  final String address;
  final String phone;

  final bool isActive;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Branch({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.city,
    required this.address,
    required this.phone,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  factory Branch.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    return Branch(
      id: id,
      tenantId: map['tenantId']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      city: map['city']?.toString() ?? '',
      address: map['address']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      isActive: map['isActive'] ?? false,
      createdAt: _toDateTime(map['createdAt']),
      updatedAt: _toDateTime(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tenantId': tenantId,
      'name': name,
      'city': city,
      'address': address,
      'phone': phone,
      'isActive': isActive,
    };
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value;
    }

    try {
      return value.toDate();
    } catch (_) {
      return null;
    }
  }

  Branch copyWith({
    String? id,
    String? tenantId,
    String? name,
    String? city,
    String? address,
    String? phone,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Branch(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      name: name ?? this.name,
      city: city ?? this.city,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}