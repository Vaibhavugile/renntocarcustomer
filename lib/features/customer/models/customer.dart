class Customer {
  final String customerId;
  final String tenantId;

  final String fullName;
  final String phone;
  final String email;

  final String profileImageUrl;

  final String dateOfBirth;
  final String gender;

  final CustomerAddress? address;
  final EmergencyContact? emergencyContact;

  final String kycStatus;

  final bool profileCompleted;
  final bool isActive;

  final int totalBookings;
  final int completedBookings;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Customer({
    required this.customerId,
    required this.tenantId,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.profileImageUrl,
    required this.dateOfBirth,
    required this.gender,
    required this.address,
    required this.emergencyContact,
    required this.kycStatus,
    required this.profileCompleted,
    required this.isActive,
    required this.totalBookings,
    required this.completedBookings,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Customer.fromMap(
    String customerId,
    Map<String, dynamic> map,
  ) {
    return Customer(
      customerId: customerId,
      tenantId: map['tenantId']?.toString() ?? '',

      fullName: map['fullName']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      email: map['email']?.toString() ?? '',

      profileImageUrl:
          map['profileImageUrl']?.toString() ?? '',

      dateOfBirth:
          map['dateOfBirth']?.toString() ?? '',

      gender:
          map['gender']?.toString() ?? '',

      address: map['address'] != null
          ? CustomerAddress.fromMap(
              Map<String, dynamic>.from(map['address']),
            )
          : null,

      emergencyContact:
          map['emergencyContact'] != null
              ? EmergencyContact.fromMap(
                  Map<String, dynamic>.from(
                    map['emergencyContact'],
                  ),
                )
              : null,

      kycStatus:
          map['kycStatus']?.toString() ?? 'not_started',

      profileCompleted:
          map['profileCompleted'] ?? false,

      isActive:
          map['isActive'] ?? true,

      totalBookings:
          _toInt(map['totalBookings']),

      completedBookings:
          _toInt(map['completedBookings']),

      createdAt:
          _toDateTime(map['createdAt']),

      updatedAt:
          _toDateTime(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tenantId': tenantId,

      'fullName': fullName,
      'phone': phone,
      'email': email,

      'profileImageUrl': profileImageUrl,

      'dateOfBirth': dateOfBirth,
      'gender': gender,

      'address': address?.toMap(),

      'emergencyContact':
          emergencyContact?.toMap(),

      'kycStatus': kycStatus,

      'profileCompleted': profileCompleted,
      'isActive': isActive,

      'totalBookings': totalBookings,
      'completedBookings': completedBookings,

      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  Customer copyWith({
    String? fullName,
    String? email,
    String? profileImageUrl,
    String? dateOfBirth,
    String? gender,
    CustomerAddress? address,
    EmergencyContact? emergencyContact,
    String? kycStatus,
    bool? profileCompleted,
    bool? isActive,
    int? totalBookings,
    int? completedBookings,
    DateTime? updatedAt,
  }) {
    return Customer(
      customerId: customerId,
      tenantId: tenantId,

      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      email: email ?? this.email,

      profileImageUrl:
          profileImageUrl ?? this.profileImageUrl,

      dateOfBirth:
          dateOfBirth ?? this.dateOfBirth,

      gender:
          gender ?? this.gender,

      address:
          address ?? this.address,

      emergencyContact:
          emergencyContact ?? this.emergencyContact,

      kycStatus:
          kycStatus ?? this.kycStatus,

      profileCompleted:
          profileCompleted ?? this.profileCompleted,

      isActive:
          isActive ?? this.isActive,

      totalBookings:
          totalBookings ?? this.totalBookings,

      completedBookings:
          completedBookings ?? this.completedBookings,

      createdAt: createdAt,
      updatedAt:
          updatedAt ?? this.updatedAt,
    );
  }

  static int _toInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
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
    } catch (_) {}

    return DateTime.tryParse(
      value.toString(),
    );
  }
}


class CustomerAddress {
  final String addressLine1;
  final String addressLine2;
  final String city;
  final String state;
  final String postalCode;
  final String country;

  const CustomerAddress({
    required this.addressLine1,
    required this.addressLine2,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.country,
  });

  factory CustomerAddress.fromMap(
    Map<String, dynamic> map,
  ) {
    return CustomerAddress(
      addressLine1:
          map['addressLine1']?.toString() ?? '',
      addressLine2:
          map['addressLine2']?.toString() ?? '',
      city:
          map['city']?.toString() ?? '',
      state:
          map['state']?.toString() ?? '',
      postalCode:
          map['postalCode']?.toString() ?? '',
      country:
          map['country']?.toString() ?? 'India',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'addressLine1': addressLine1,
      'addressLine2': addressLine2,
      'city': city,
      'state': state,
      'postalCode': postalCode,
      'country': country,
    };
  }
}


class EmergencyContact {
  final String name;
  final String phone;
  final String relationship;

  const EmergencyContact({
    required this.name,
    required this.phone,
    required this.relationship,
  });

  factory EmergencyContact.fromMap(
    Map<String, dynamic> map,
  ) {
    return EmergencyContact(
      name:
          map['name']?.toString() ?? '',
      phone:
          map['phone']?.toString() ?? '',
      relationship:
          map['relationship']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'relationship': relationship,
    };
  }
}