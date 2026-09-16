import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/pricing_profile.dart';

class PricingProfileService {
  PricingProfileService._();

  static final PricingProfileService instance =
      PricingProfileService._();

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  // ===========================================================================
  // COLLECTION
  // ===========================================================================

  CollectionReference<Map<String, dynamic>> _profiles(
    String tenantId,
  ) {
    final normalizedTenantId = tenantId.trim();

    if (normalizedTenantId.isEmpty) {
      throw ArgumentError(
        'tenantId cannot be empty.',
      );
    }

    return _firestore
        .collection('tenants')
        .doc(normalizedTenantId)
        .collection('pricingProfiles');
  }

  // ===========================================================================
  // NORMALIZE TENANT ID
  // ===========================================================================

  String _normalizeTenantId(
    String tenantId,
  ) {
    final normalizedTenantId =
        tenantId.trim();

    if (normalizedTenantId.isEmpty) {
      throw ArgumentError(
        'tenantId cannot be empty.',
      );
    }

    return normalizedTenantId;
  }

  // ===========================================================================
  // NORMALIZE PROFILE ID
  // ===========================================================================

  String _normalizeProfileId(
    String pricingProfileId,
  ) {
    final normalizedProfileId =
        pricingProfileId.trim();

    if (normalizedProfileId.isEmpty) {
      throw ArgumentError(
        'pricingProfileId cannot be empty.',
      );
    }

    return normalizedProfileId;
  }

  // ===========================================================================
  // GET ALL PRICING PROFILES
  // ===========================================================================

  Future<List<PricingProfile>> getAllPricingProfiles({
    required String tenantId,
  }) async {
    final normalizedTenantId =
        _normalizeTenantId(tenantId);

    try {
      final snapshot =
          await _profiles(normalizedTenantId).get();

      final profiles = snapshot.docs.map(
        (doc) {
          final data = doc.data();

          return PricingProfile.fromMap(
            doc.id,
            data,
          );
        },
      ).toList();

      // Sort in Dart instead of Firestore so older
      // documents without "name" never break the query.
      profiles.sort(
        (a, b) => a.name
            .toLowerCase()
            .compareTo(
              b.name.toLowerCase(),
            ),
      );

      return profiles;
    } on FirebaseException catch (e) {
      throw Exception(
        'Unable to load pricing profiles: '
        '${e.message ?? e.code}',
      );
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }

      throw Exception(
        'Unable to load pricing profiles.',
      );
    }
  }

  // ===========================================================================
  // GET ACTIVE PRICING PROFILES
  // ===========================================================================

  Future<List<PricingProfile>>
      getActivePricingProfiles({
    required String tenantId,
  }) async {
    final profiles =
        await getAllPricingProfiles(
      tenantId: tenantId,
    );

    return profiles
        .where(
          (profile) => profile.isActive,
        )
        .toList();
  }

  // ===========================================================================
  // GET PRICING PROFILE BY ID
  // ===========================================================================

  Future<PricingProfile?>
      getPricingProfileById({
    required String tenantId,
    required String pricingProfileId,
  }) async {
    final normalizedTenantId =
        _normalizeTenantId(tenantId);

    final normalizedProfileId =
        _normalizeProfileId(
      pricingProfileId,
    );

    try {
      final doc =
          await _profiles(normalizedTenantId)
              .doc(normalizedProfileId)
              .get();

      if (!doc.exists) {
        return null;
      }

      final data = doc.data();

      if (data == null) {
        return null;
      }

      final profile =
          PricingProfile.fromMap(
        doc.id,
        data,
      );

      // Tenant safety check.
      if (profile.tenantId.isNotEmpty &&
          profile.tenantId !=
              normalizedTenantId) {
        throw Exception(
          'Pricing profile belongs to another tenant.',
        );
      }

      return profile;
    } on FirebaseException catch (e) {
      throw Exception(
        'Unable to load pricing profile: '
        '${e.message ?? e.code}',
      );
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }

      throw Exception(
        'Unable to load pricing profile.',
      );
    }
  }

  // ===========================================================================
  // GET PRICING PROFILE FOR VEHICLE
  // ===========================================================================

  Future<PricingProfile?>
      getPricingProfileForVehicle({
    required String tenantId,
    required String vehicleId,
  }) async {
    final normalizedTenantId =
        _normalizeTenantId(tenantId);

    final normalizedVehicleId =
        vehicleId.trim();

    if (normalizedVehicleId.isEmpty) {
      throw ArgumentError(
        'vehicleId cannot be empty.',
      );
    }

    try {
      final snapshot =
          await _profiles(normalizedTenantId)
              .where(
                'vehicleId',
                isEqualTo: normalizedVehicleId,
              )
              .limit(1)
              .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      final doc =
          snapshot.docs.first;

      final data = doc.data();

      return PricingProfile.fromMap(
        doc.id,
        data,
      );
    } on FirebaseException catch (e) {
      throw Exception(
        'Unable to load vehicle pricing profile: '
        '${e.message ?? e.code}',
      );
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }

      throw Exception(
        'Unable to load vehicle pricing profile.',
      );
    }
  }

  // ===========================================================================
  // CREATE PRICING PROFILE
  // ===========================================================================

  Future<String> createPricingProfile({
    required String tenantId,
    required PricingProfile profile,
  }) async {
    final normalizedTenantId =
        _normalizeTenantId(tenantId);

    try {
      final collection =
          _profiles(normalizedTenantId);

      // If the caller provides an ID, use it.
      // Otherwise Firestore generates one.
      final requestedId =
          profile.id.trim();

      final doc = requestedId.isNotEmpty
          ? collection.doc(requestedId)
          : collection.doc();

      final existing =
          await doc.get();

      if (existing.exists) {
        throw Exception(
          'A pricing profile with ID '
          '"${doc.id}" already exists.',
        );
      }

      final data =
          profile.toMap();

      // Always enforce the tenant from the method argument.
      // Never trust a tenantId coming from the UI/model.
      data['tenantId'] =
          normalizedTenantId;

      data['createdAt'] =
          FieldValue.serverTimestamp();

      data['updatedAt'] =
          FieldValue.serverTimestamp();

      await doc.set(data);

      return doc.id;
    } on FirebaseException catch (e) {
      throw Exception(
        'Unable to create pricing profile: '
        '${e.message ?? e.code}',
      );
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }

      throw Exception(
        'Unable to create pricing profile.',
      );
    }
  }

  // ===========================================================================
  // UPDATE PRICING PROFILE
  // ===========================================================================

  Future<void> updatePricingProfile({
    required String tenantId,
    required String pricingProfileId,
    required PricingProfile profile,
  }) async {
    final normalizedTenantId =
        _normalizeTenantId(tenantId);

    final normalizedProfileId =
        _normalizeProfileId(
      pricingProfileId,
    );

    try {
      final doc =
          _profiles(normalizedTenantId)
              .doc(normalizedProfileId);

      final existing =
          await doc.get();

      if (!existing.exists) {
        throw Exception(
          'Pricing profile not found.',
        );
      }

      final existingData =
          existing.data();

      if (existingData != null) {
        final existingTenantId =
            existingData['tenantId']
                ?.toString()
                .trim();

        if (existingTenantId != null &&
            existingTenantId.isNotEmpty &&
            existingTenantId !=
                normalizedTenantId) {
          throw Exception(
            'Pricing profile belongs to another tenant.',
          );
        }
      }

      final data =
          profile.toMap();

      // Always enforce tenant isolation.
      data['tenantId'] =
          normalizedTenantId;

      // The Firestore document ID is authoritative.
      data['id'] =
          normalizedProfileId;

      data['updatedAt'] =
          FieldValue.serverTimestamp();

      await doc.update(data);
    } on FirebaseException catch (e) {
      throw Exception(
        'Unable to update pricing profile: '
        '${e.message ?? e.code}',
      );
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }

      throw Exception(
        'Unable to update pricing profile.',
      );
    }
  }

  // ===========================================================================
  // ACTIVATE PRICING PROFILE
  // ===========================================================================

  Future<void> activatePricingProfile({
    required String tenantId,
    required String pricingProfileId,
  }) async {
    final normalizedTenantId =
        _normalizeTenantId(tenantId);

    final normalizedProfileId =
        _normalizeProfileId(
      pricingProfileId,
    );

    try {
      final doc =
          _profiles(normalizedTenantId)
              .doc(normalizedProfileId);

      final snapshot =
          await doc.get();

      if (!snapshot.exists) {
        throw Exception(
          'Pricing profile not found.',
        );
      }

      await doc.update({
        'isActive': true,
        'tenantId': normalizedTenantId,
        'updatedAt':
            FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw Exception(
        'Unable to activate pricing profile: '
        '${e.message ?? e.code}',
      );
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }

      throw Exception(
        'Unable to activate pricing profile.',
      );
    }
  }

  // ===========================================================================
  // DEACTIVATE PRICING PROFILE
  // ===========================================================================

  Future<void> deactivatePricingProfile({
    required String tenantId,
    required String pricingProfileId,
  }) async {
    final normalizedTenantId =
        _normalizeTenantId(tenantId);

    final normalizedProfileId =
        _normalizeProfileId(
      pricingProfileId,
    );

    try {
      final doc =
          _profiles(normalizedTenantId)
              .doc(normalizedProfileId);

      final snapshot =
          await doc.get();

      if (!snapshot.exists) {
        throw Exception(
          'Pricing profile not found.',
        );
      }

      await doc.update({
        'isActive': false,
        'tenantId': normalizedTenantId,
        'updatedAt':
            FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw Exception(
        'Unable to deactivate pricing profile: '
        '${e.message ?? e.code}',
      );
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }

      throw Exception(
        'Unable to deactivate pricing profile.',
      );
    }
  }

  // ===========================================================================
  // WATCH ALL PRICING PROFILES
  // ===========================================================================

  Stream<List<PricingProfile>>
      watchPricingProfiles({
    required String tenantId,
  }) {
    final normalizedTenantId =
        _normalizeTenantId(tenantId);

    return _profiles(normalizedTenantId)
        .snapshots()
        .map(
      (snapshot) {
        final profiles =
            snapshot.docs.map(
          (doc) {
            return PricingProfile.fromMap(
              doc.id,
              doc.data(),
            );
          },
        ).toList();

        profiles.sort(
          (a, b) => a.name
              .toLowerCase()
              .compareTo(
                b.name.toLowerCase(),
              ),
        );

        return profiles;
      },
    );
  }

  // ===========================================================================
  // WATCH ACTIVE PRICING PROFILES
  // ===========================================================================

  Stream<List<PricingProfile>>
      watchActivePricingProfiles({
    required String tenantId,
  }) {
    final normalizedTenantId =
        _normalizeTenantId(tenantId);

    return _profiles(normalizedTenantId)
        .snapshots()
        .map(
      (snapshot) {
        final profiles =
            snapshot.docs
                .map(
                  (doc) =>
                      PricingProfile.fromMap(
                    doc.id,
                    doc.data(),
                  ),
                )
                .where(
                  (profile) =>
                      profile.isActive,
                )
                .toList();

        profiles.sort(
          (a, b) => a.name
              .toLowerCase()
              .compareTo(
                b.name.toLowerCase(),
              ),
        );

        return profiles;
      },
    );
  }
}