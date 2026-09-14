class Car {
  final String id;
  final String tenantId;

  final String name;
  final String type;
  final String transmission;
  final int seats;
  final String fuel;

  final String pricingProfileId;
  final int pricePerDay;

  final String image;
  final List<String> images;

  final String registrationNumber;
  final String description;
  final List<String> features;

  final List<String> branchIds;

  final String status;

  final bool isAvailable;
  final bool isFeatured;
  final bool isActive;

  final int sortOrder;

  const Car({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.type,
    required this.transmission,
    required this.seats,
    required this.fuel,
    required this.pricingProfileId,
    required this.pricePerDay,
    required this.image,
    required this.images,
    required this.registrationNumber,
    required this.description,
    required this.features,
    required this.branchIds,
    required this.status,
    required this.isAvailable,
    required this.isFeatured,
    required this.isActive,
    required this.sortOrder,
  });

  factory Car.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    return Car(
      id: id,

      tenantId: map['tenantId']?.toString() ?? '',

      name: map['name']?.toString() ?? '',
      type: map['type']?.toString() ?? '',
      transmission: map['transmission']?.toString() ?? '',
      seats: _toInt(map['seats']),
      fuel: map['fuel']?.toString() ?? '',

      pricingProfileId:
          map['pricingProfileId']?.toString() ?? '',

      pricePerDay: _toInt(map['pricePerDay']),

      image: map['image']?.toString() ?? '',

      images: _toStringList(map['images']),

      registrationNumber:
          map['registrationNumber']?.toString() ?? '',

      description:
          map['description']?.toString() ?? '',

      features: _toStringList(map['features']),

      branchIds: _toStringList(map['branchIds']),

      status: map['status']?.toString() ?? 'available',

      isAvailable:
          map['isAvailable'] ?? false,

      isFeatured:
          map['isFeatured'] ?? false,

      isActive:
          map['isActive'] ?? true,

      sortOrder:
          _toInt(map['sortOrder']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tenantId': tenantId,

      'name': name,
      'type': type,
      'transmission': transmission,
      'seats': seats,
      'fuel': fuel,

      'pricingProfileId': pricingProfileId,
      'pricePerDay': pricePerDay,

      'image': image,
      'images': images,

      'registrationNumber': registrationNumber,
      'description': description,
      'features': features,

      'branchIds': branchIds,

      'status': status,

      'isAvailable': isAvailable,
      'isFeatured': isFeatured,
      'isActive': isActive,

      'sortOrder': sortOrder,
    };
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

  static List<String> _toStringList(dynamic value) {
    if (value is Iterable) {
      return value
          .map(
            (item) => item.toString(),
          )
          .where(
            (item) => item.isNotEmpty,
          )
          .toList();
    }

    return [];
  }
}