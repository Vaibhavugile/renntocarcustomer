import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/car.dart';

class CarService {
  CarService._();

  static final CarService instance = CarService._();

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _cars(
    String tenantId,
  ) {
    if (tenantId.trim().isEmpty) {
      throw ArgumentError(
        'tenantId cannot be empty.',
      );
    }

    return _firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('cars');
  }

  // ============================================================
  // GET ALL ACTIVE CARS
  // ============================================================

  Future<List<Car>> getCars({
    required String tenantId,
  }) async {
    try {
      final snapshot = await _cars(tenantId)
          .where(
            'isActive',
            isEqualTo: true,
          )
          .orderBy(
            'sortOrder',
          )
          .get();

      return snapshot.docs
          .map(
            (doc) => Car.fromMap(
              doc.id,
              doc.data(),
            ),
          )
          .toList();
    } on FirebaseException catch (e) {
      throw Exception(
        'Unable to load cars: '
        '${e.message ?? e.code}',
      );
    } catch (e) {
      throw Exception(
        'Unable to load cars.',
      );
    }
  }

  // ============================================================
  // GET ALL CARS FOR ADMIN
  // ============================================================

  Future<List<Car>> getAllCars({
    required String tenantId,
  }) async {
    try {
      final snapshot = await _cars(tenantId)
          .orderBy(
            'sortOrder',
          )
          .get();

      return snapshot.docs
          .map(
            (doc) => Car.fromMap(
              doc.id,
              doc.data(),
            ),
          )
          .toList();
    } on FirebaseException catch (e) {
      throw Exception(
        'Unable to load cars: '
        '${e.message ?? e.code}',
      );
    } catch (e) {
      throw Exception(
        'Unable to load cars.',
      );
    }
  }

  // ============================================================
  // GET AVAILABLE CARS
  // ============================================================

  Future<List<Car>> getAvailableCars({
    required String tenantId,
  }) async {
    try {
      final snapshot = await _cars(tenantId)
          .where(
            'isActive',
            isEqualTo: true,
          )
          .where(
            'isAvailable',
            isEqualTo: true,
          )
          .orderBy(
            'sortOrder',
          )
          .get();

      return snapshot.docs
          .map(
            (doc) => Car.fromMap(
              doc.id,
              doc.data(),
            ),
          )
          .toList();
    } on FirebaseException catch (e) {
      throw Exception(
        'Unable to load available cars: '
        '${e.message ?? e.code}',
      );
    } catch (e) {
      throw Exception(
        'Unable to load available cars.',
      );
    }
  }

  // ============================================================
  // GET FEATURED CARS
  // ============================================================

  Future<List<Car>> getFeaturedCars({
    required String tenantId,
  }) async {
    try {
      final snapshot = await _cars(tenantId)
          .where(
            'isActive',
            isEqualTo: true,
          )
          .where(
            'isAvailable',
            isEqualTo: true,
          )
          .where(
            'isFeatured',
            isEqualTo: true,
          )
          .orderBy(
            'sortOrder',
          )
          .get();

      return snapshot.docs
          .map(
            (doc) => Car.fromMap(
              doc.id,
              doc.data(),
            ),
          )
          .toList();
    } on FirebaseException catch (e) {
      throw Exception(
        'Unable to load featured cars: '
        '${e.message ?? e.code}',
      );
    } catch (e) {
      throw Exception(
        'Unable to load featured cars.',
      );
    }
  }

  // ============================================================
  // GET SINGLE CAR
  // ============================================================

  Future<Car?> getCarById({
    required String tenantId,
    required String carId,
  }) async {
    if (carId.trim().isEmpty) {
      throw ArgumentError(
        'carId cannot be empty.',
      );
    }

    try {
      final doc = await _cars(tenantId)
          .doc(carId)
          .get();

      if (!doc.exists) {
        return null;
      }

      final data = doc.data();

      if (data == null) {
        return null;
      }

      return Car.fromMap(
        doc.id,
        data,
      );
    } on FirebaseException catch (e) {
      throw Exception(
        'Unable to load car: '
        '${e.message ?? e.code}',
      );
    } catch (e) {
      throw Exception(
        'Unable to load car.',
      );
    }
  }

  // ============================================================
  // GET CARS BY BRANCH
  // ============================================================

  Future<List<Car>> getCarsByBranch({
    required String tenantId,
    required String branchId,
  }) async {
    if (branchId.trim().isEmpty) {
      throw ArgumentError(
        'branchId cannot be empty.',
      );
    }

    try {
      final snapshot = await _cars(tenantId)
          .where(
            'isActive',
            isEqualTo: true,
          )
          .where(
            'branchIds',
            arrayContains: branchId,
          )
          .orderBy(
            'sortOrder',
          )
          .get();

      return snapshot.docs
          .map(
            (doc) => Car.fromMap(
              doc.id,
              doc.data(),
            ),
          )
          .toList();
    } on FirebaseException catch (e) {
      throw Exception(
        'Unable to load branch cars: '
        '${e.message ?? e.code}',
      );
    } catch (e) {
      throw Exception(
        'Unable to load branch cars.',
      );
    }
  }

  // ============================================================
  // CREATE CAR
  // ============================================================

  Future<String> createCar({
    required String tenantId,
    required Car car,
  }) async {
    try {
      final collection = _cars(tenantId);

      final doc = collection.doc();

      final data = car.toMap();

      // Always enforce tenant ownership.
      data['tenantId'] = tenantId;

      data['createdAt'] =
          FieldValue.serverTimestamp();

      data['updatedAt'] =
          FieldValue.serverTimestamp();

      await doc.set(data);

      return doc.id;
    } on FirebaseException catch (e) {
      throw Exception(
        'Unable to create car: '
        '${e.message ?? e.code}',
      );
    } catch (e) {
      throw Exception(
        'Unable to create car.',
      );
    }
  }

  // ============================================================
  // UPDATE CAR
  // ============================================================

  Future<void> updateCar({
    required String tenantId,
    required String carId,
    required Car car,
  }) async {
    if (carId.trim().isEmpty) {
      throw ArgumentError(
        'carId cannot be empty.',
      );
    }

    try {
      final data = car.toMap();

      // Never allow a car to be moved to
      // another tenant through this method.
      data['tenantId'] = tenantId;

      data['updatedAt'] =
          FieldValue.serverTimestamp();

      await _cars(tenantId)
          .doc(carId)
          .update(data);
    } on FirebaseException catch (e) {
      throw Exception(
        'Unable to update car: '
        '${e.message ?? e.code}',
      );
    } catch (e) {
      throw Exception(
        'Unable to update car.',
      );
    }
  }

  // ============================================================
  // DEACTIVATE CAR
  // ============================================================

  Future<void> deactivateCar({
    required String tenantId,
    required String carId,
  }) async {
    if (carId.trim().isEmpty) {
      throw ArgumentError(
        'carId cannot be empty.',
      );
    }

    try {
      await _cars(tenantId)
          .doc(carId)
          .update({
        'isActive': false,
        'isAvailable': false,
        'status': 'inactive',
        'updatedAt':
            FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw Exception(
        'Unable to deactivate car: '
        '${e.message ?? e.code}',
      );
    } catch (e) {
      throw Exception(
        'Unable to deactivate car.',
      );
    }
  }

  // ============================================================
  // ACTIVATE CAR
  // ============================================================

  Future<void> activateCar({
    required String tenantId,
    required String carId,
  }) async {
    if (carId.trim().isEmpty) {
      throw ArgumentError(
        'carId cannot be empty.',
      );
    }

    try {
      await _cars(tenantId)
          .doc(carId)
          .update({
        'isActive': true,
        'isAvailable': true,
        'status': 'available',
        'updatedAt':
            FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw Exception(
        'Unable to activate car: '
        '${e.message ?? e.code}',
      );
    } catch (e) {
      throw Exception(
        'Unable to activate car.',
      );
    }
  }

  // ============================================================
  // UPDATE AVAILABILITY
  // ============================================================

  Future<void> updateAvailability({
    required String tenantId,
    required String carId,
    required bool isAvailable,
  }) async {
    try {
      await _cars(tenantId)
          .doc(carId)
          .update({
        'isAvailable': isAvailable,
        'updatedAt':
            FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw Exception(
        'Unable to update car availability: '
        '${e.message ?? e.code}',
      );
    } catch (e) {
      throw Exception(
        'Unable to update car availability.',
      );
    }
  }

  // ============================================================
  // UPDATE STATUS
  // ============================================================

  Future<void> updateStatus({
    required String tenantId,
    required String carId,
    required String status,
  }) async {
    if (status.trim().isEmpty) {
      throw ArgumentError(
        'status cannot be empty.',
      );
    }

    try {
      await _cars(tenantId)
          .doc(carId)
          .update({
        'status': status,
        'updatedAt':
            FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw Exception(
        'Unable to update car status: '
        '${e.message ?? e.code}',
      );
    } catch (e) {
      throw Exception(
        'Unable to update car status.',
      );
    }
  }

  // ============================================================
  // STREAM ACTIVE CARS
  // ============================================================

  Stream<List<Car>> watchCars({
    required String tenantId,
  }) {
    return _cars(tenantId)
        .where(
          'isActive',
          isEqualTo: true,
        )
        .orderBy(
          'sortOrder',
        )
        .snapshots()
        .map(
          (snapshot) {
            return snapshot.docs
                .map(
                  (doc) => Car.fromMap(
                    doc.id,
                    doc.data(),
                  ),
                )
                .toList();
          },
        );
  }

  // ============================================================
  // STREAM FEATURED CARS
  // ============================================================

  Stream<List<Car>> watchFeaturedCars({
    required String tenantId,
  }) {
    return _cars(tenantId)
        .where(
          'isActive',
          isEqualTo: true,
        )
        .where(
          'isAvailable',
          isEqualTo: true,
        )
        .where(
          'isFeatured',
          isEqualTo: true,
        )
        .orderBy(
          'sortOrder',
        )
        .snapshots()
        .map(
          (snapshot) {
            return snapshot.docs
                .map(
                  (doc) => Car.fromMap(
                    doc.id,
                    doc.data(),
                  ),
                )
                .toList();
          },
        );
  }
}