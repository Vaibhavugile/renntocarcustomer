class Car {
  final String id;
  final String tenantId;

  // ============================================================
  // BASIC DETAILS
  // ============================================================

  final String name;
  final String type;
  final String transmission;
  final int seats;
  final String fuel;

  // ============================================================
  // PRICING
  // ============================================================

  final String pricingProfileId;
  final int pricePerDay;

  // ============================================================
  // IMAGES
  // ============================================================

  /// Main / primary vehicle image.
  final String image;

  /// All vehicle images including the primary image.
  final List<String> images;

  // ============================================================
  // VEHICLE DETAILS
  // ============================================================

  final String registrationNumber;

  /// Current odometer reading in kilometres.
  final int currentKm;

  final String description;
  final List<String> features;

  // ============================================================
  // BRANCHES
  // ============================================================

  final List<String> branchIds;

  // ============================================================
  // STATUS
  // ============================================================

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
    required this.currentKm,
    required this.description,
    required this.features,

    required this.branchIds,

    required this.status,
    required this.isAvailable,
    required this.isFeatured,
    required this.isActive,

    required this.sortOrder,
  });

  // ============================================================
  // FROM FIRESTORE
  // ============================================================

  factory Car.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    return Car(
      id: id,

      tenantId:
          map['tenantId']?.toString() ?? '',

      // ----------------------------------------------------------
      // BASIC DETAILS
      // ----------------------------------------------------------

      name:
          map['name']?.toString() ?? '',

      type:
          map['type']?.toString() ?? '',

      transmission:
          map['transmission']?.toString() ?? '',

      seats:
          _toInt(map['seats']),

      fuel:
          map['fuel']?.toString() ?? '',

      // ----------------------------------------------------------
      // PRICING
      // ----------------------------------------------------------

      pricingProfileId:
          map['pricingProfileId']?.toString() ?? '',

      pricePerDay:
          _toInt(map['pricePerDay']),

      // ----------------------------------------------------------
      // IMAGES
      // ----------------------------------------------------------

      image:
          map['image']?.toString() ?? '',

      images:
          _toStringList(map['images']),

      // ----------------------------------------------------------
      // VEHICLE DETAILS
      // ----------------------------------------------------------

      registrationNumber:
          map['registrationNumber']?.toString() ?? '',

      currentKm:
          _toInt(map['currentKm']),

      description:
          map['description']?.toString() ?? '',

      features:
          _toStringList(map['features']),

      // ----------------------------------------------------------
      // BRANCHES
      // ----------------------------------------------------------

      branchIds:
          _toStringList(map['branchIds']),

      // ----------------------------------------------------------
      // STATUS
      // ----------------------------------------------------------

      status:
          map['status']?.toString() ?? 'available',

      isAvailable:
          map['isAvailable'] == true,

      isFeatured:
          map['isFeatured'] == true,

      isActive:
          map['isActive'] == true,

      sortOrder:
          _toInt(map['sortOrder']),
    );
  }

  // ============================================================
  // TO FIRESTORE
  // ============================================================

  Map<String, dynamic> toMap() {
    return {
      'tenantId': tenantId,

      // ----------------------------------------------------------
      // BASIC DETAILS
      // ----------------------------------------------------------

      'name': name,
      'type': type,
      'transmission': transmission,
      'seats': seats,
      'fuel': fuel,

      // ----------------------------------------------------------
      // PRICING
      // ----------------------------------------------------------

      'pricingProfileId': pricingProfileId,
      'pricePerDay': pricePerDay,

      // ----------------------------------------------------------
      // IMAGES
      // ----------------------------------------------------------

      'image': image,
      'images': images,

      // ----------------------------------------------------------
      // VEHICLE DETAILS
      // ----------------------------------------------------------

      'registrationNumber': registrationNumber,
      'currentKm': currentKm,
      'description': description,
      'features': features,

      // ----------------------------------------------------------
      // BRANCHES
      // ----------------------------------------------------------

      'branchIds': branchIds,

      // ----------------------------------------------------------
      // STATUS
      // ----------------------------------------------------------

      'status': status,
      'isAvailable': isAvailable,
      'isFeatured': isFeatured,
      'isActive': isActive,

      'sortOrder': sortOrder,
    };
  }

  // ============================================================
  // COPY WITH
  // ============================================================

  Car copyWith({
    String? name,
    String? type,
    String? transmission,
    int? seats,
    String? fuel,

    String? pricingProfileId,
    int? pricePerDay,

    String? image,
    List<String>? images,

    String? registrationNumber,
    int? currentKm,
    String? description,
    List<String>? features,

    List<String>? branchIds,

    String? status,
    bool? isAvailable,
    bool? isFeatured,
    bool? isActive,

    int? sortOrder,
  }) {
    return Car(
      id: id,
      tenantId: tenantId,

      name:
          name ?? this.name,

      type:
          type ?? this.type,

      transmission:
          transmission ?? this.transmission,

      seats:
          seats ?? this.seats,

      fuel:
          fuel ?? this.fuel,

      pricingProfileId:
          pricingProfileId ??
          this.pricingProfileId,

      pricePerDay:
          pricePerDay ??
          this.pricePerDay,

      image:
          image ?? this.image,

      images:
          images ?? this.images,

      registrationNumber:
          registrationNumber ??
          this.registrationNumber,

      currentKm:
          currentKm ??
          this.currentKm,

      description:
          description ??
          this.description,

      features:
          features ??
          this.features,

      branchIds:
          branchIds ??
          this.branchIds,

      status:
          status ??
          this.status,

      isAvailable:
          isAvailable ??
          this.isAvailable,

      isFeatured:
          isFeatured ??
          this.isFeatured,

      isActive:
          isActive ??
          this.isActive,

      sortOrder:
          sortOrder ??
          this.sortOrder,
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  static int _toInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  static List<String> _toStringList(
    dynamic value,
  ) {
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

    return <String>[];
  }
}