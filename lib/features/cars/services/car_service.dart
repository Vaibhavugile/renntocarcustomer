import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/car.dart';

class CarService {
  CarService._();

  static final CarService instance = CarService._();

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseStorage _storage =
      FirebaseStorage.instance;

  // ============================================================
  // FIRESTORE CARS COLLECTION
  // ============================================================

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
  // FIREBASE STORAGE CAR FOLDER
  // ============================================================

  Reference _carStorageFolder({
    required String tenantId,
    required String carId,
  }) {
    if (tenantId.trim().isEmpty) {
      throw ArgumentError(
        'tenantId cannot be empty.',
      );
    }

    if (carId.trim().isEmpty) {
      throw ArgumentError(
        'carId cannot be empty.',
      );
    }

    return _storage
        .ref()
        .child('tenants')
        .child(tenantId)
        .child('cars')
        .child(carId);
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
    } catch (_) {
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
    } catch (_) {
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
    } catch (_) {
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
    } catch (_) {
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
    } catch (_) {
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
    } catch (_) {
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
    } catch (_) {
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

      // Never allow a car to move to
      // another tenant.
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
    } catch (_) {
      throw Exception(
        'Unable to update car.',
      );
    }
  }

  // ============================================================
  // UPLOAD PRIMARY IMAGE
  // ============================================================

  Future<String> uploadPrimaryImage({
    required String tenantId,
    required String carId,
    required Uint8List bytes,
  }) async {
    if (bytes.isEmpty) {
      throw ArgumentError(
        'Image data cannot be empty.',
      );
    }

    try {
      final folder = _carStorageFolder(
        tenantId: tenantId,
        carId: carId,
      );

      final fileRef = folder.child(
        'primary_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      await fileRef.putData(
        bytes,
        SettableMetadata(
          contentType: 'image/jpeg',
          cacheControl:
              'public,max-age=31536000',
        ),
      );

      return await fileRef.getDownloadURL();
    } on FirebaseException catch (e) {
      throw Exception(
        'Unable to upload primary image: '
        '${e.message ?? e.code}',
      );
    } catch (_) {
      throw Exception(
        'Unable to upload primary image.',
      );
    }
  }

  // ============================================================
  // UPLOAD GALLERY IMAGE
  // ============================================================

  Future<String> uploadGalleryImage({
    required String tenantId,
    required String carId,
    required Uint8List bytes,
    int? index,
  }) async {
    if (bytes.isEmpty) {
      throw ArgumentError(
        'Image data cannot be empty.',
      );
    }

    try {
      final folder = _carStorageFolder(
        tenantId: tenantId,
        carId: carId,
      );

      final suffix = index != null
          ? 'gallery_${index}_'
          : 'gallery_';

      final fileRef = folder.child(
        '${suffix}${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      await fileRef.putData(
        bytes,
        SettableMetadata(
          contentType: 'image/jpeg',
          cacheControl:
              'public,max-age=31536000',
        ),
      );

      return await fileRef.getDownloadURL();
    } on FirebaseException catch (e) {
      throw Exception(
        'Unable to upload car image: '
        '${e.message ?? e.code}',
      );
    } catch (_) {
      throw Exception(
        'Unable to upload car image.',
      );
    }
  }

  // ============================================================
  // UPLOAD MULTIPLE IMAGES
  // ============================================================

  Future<List<String>> uploadImages({
    required String tenantId,
    required String carId,
    required List<Uint8List> images,
  }) async {
    if (images.isEmpty) {
      return <String>[];
    }

    final urls = <String>[];

    try {
      for (int i = 0; i < images.length; i++) {
        final url = await uploadGalleryImage(
          tenantId: tenantId,
          carId: carId,
          bytes: images[i],
          index: i,
        );

        urls.add(url);
      }

      return urls;
    } catch (e) {
      // Clean up images uploaded during this
      // incomplete operation.
      for (final url in urls) {
        await deleteImageByUrl(
          url: url,
        );
      }

      rethrow;
    }
  }

  // ============================================================
  // DELETE IMAGE BY URL
  // ============================================================

  Future<void> deleteImageByUrl({
    required String url,
  }) async {
    if (url.trim().isEmpty) {
      return;
    }

    try {
      final reference =
          _storage.refFromURL(url);

      await reference.delete();
    } on FirebaseException catch (e) {
      // already deleted
      if (e.code == 'object-not-found') {
        return;
      }

      throw Exception(
        'Unable to delete image: '
        '${e.message ?? e.code}',
      );
    } catch (_) {
      throw Exception(
        'Unable to delete image.',
      );
    }
  }

  // ============================================================
  // DELETE MULTIPLE IMAGES
  // ============================================================

  Future<void> deleteImages({
    required List<String> urls,
  }) async {
    if (urls.isEmpty) {
      return;
    }

    for (final url in urls) {
      await deleteImageByUrl(
        url: url,
      );
    }
  }

  // ============================================================
  // UPDATE CAR IMAGES
  // ============================================================

  Future<void> updateCarImages({
    required String tenantId,
    required String carId,
    required String primaryImage,
    required List<String> images,
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
        'image': primaryImage,
        'images': images,
        'updatedAt':
            FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw Exception(
        'Unable to update car images: '
        '${e.message ?? e.code}',
      );
    } catch (_) {
      throw Exception(
        'Unable to update car images.',
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
    } catch (_) {
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
    } catch (_) {
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
    if (carId.trim().isEmpty) {
      throw ArgumentError(
        'carId cannot be empty.',
      );
    }

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
    } catch (_) {
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
    if (carId.trim().isEmpty) {
      throw ArgumentError(
        'status cannot be empty.',
      );
    }

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
    } catch (_) {
      throw Exception(
        'Unable to update car status.',
      );
    }
  }

  // ============================================================
  // UPDATE CURRENT KM
  // ============================================================

  Future<void> updateCurrentKm({
    required String tenantId,
    required String carId,
    required int currentKm,
  }) async {
    if (carId.trim().isEmpty) {
      throw ArgumentError(
        'carId cannot be empty.',
      );
    }

    if (currentKm < 0) {
      throw ArgumentError(
        'currentKm cannot be negative.',
      );
    }

    try {
      await _cars(tenantId)
          .doc(carId)
          .update({
        'currentKm': currentKm,
        'updatedAt':
            FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw Exception(
        'Unable to update current KM: '
        '${e.message ?? e.code}',
      );
    } catch (_) {
      throw Exception(
        'Unable to update current KM.',
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