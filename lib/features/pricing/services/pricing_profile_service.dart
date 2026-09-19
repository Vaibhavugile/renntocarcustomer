import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/pricing_profile.dart';

/// Firestore CRUD/service layer for vehicle pricing profiles.
///
/// Firestore:
///
/// tenants/{tenantId}/pricingProfiles/{pricingProfileId}
///
/// This service owns:
/// - tenant isolation
/// - profile CRUD
/// - pricing versioning
/// - rental-type/special-date pricing persistence
/// - cache invalidation
/// - vehicle → pricing profile lookup
/// - realtime streams
///
/// It does NOT calculate booking totals. PricingEngine remains the calculation
/// authority.
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
    final normalizedTenantId =
        _normalizeTenantId(tenantId);

    return _firestore
        .collection('tenants')
        .doc(normalizedTenantId)
        .collection('pricingProfiles');
  }

  // ===========================================================================
  // NORMALIZATION
  // ===========================================================================

  String _normalizeTenantId(
    String tenantId,
  ) {
    final normalized =
        tenantId.trim();

    if (normalized.isEmpty) {
      throw ArgumentError(
        'tenantId cannot be empty.',
      );
    }

    return normalized;
  }

  String _normalizeProfileId(
    String pricingProfileId,
  ) {
    final normalized =
        pricingProfileId.trim();

    if (normalized.isEmpty) {
      throw ArgumentError(
        'pricingProfileId cannot be empty.',
      );
    }

    return normalized;
  }

  String _normalizeVehicleId(
    String vehicleId,
  ) {
    final normalized =
        vehicleId.trim();

    if (normalized.isEmpty) {
      throw ArgumentError(
        'vehicleId cannot be empty.',
      );
    }

    return normalized;
  }

  // ===========================================================================
  // GET ALL PRICING PROFILES
  // ===========================================================================

  Future<List<PricingProfile>>
      getAllPricingProfiles({
    required String tenantId,
    bool activeOnly = false,
  }) async {
    final normalizedTenantId =
        _normalizeTenantId(tenantId);

    try {
      final snapshot =
          await _profiles(
            normalizedTenantId,
          ).get();

      final profiles =
          snapshot.docs.map(
        (doc) {
          return PricingProfile.fromMap(
            doc.id,
            doc.data(),
          );
        },
      ).where(
        (profile) =>
            !activeOnly ||
            profile.isActive,
      ).toList();

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
  }) {
    return getAllPricingProfiles(
      tenantId: tenantId,
      activeOnly: true,
    );
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
          await _profiles(
            normalizedTenantId,
          ).doc(
            normalizedProfileId,
          ).get();

      if (!doc.exists) {
        return null;
      }

      final data =
          doc.data();

      if (data == null) {
        return null;
      }

      return _parseAndValidateProfile(
        tenantId: normalizedTenantId,
        documentId: doc.id,
        data: data,
      );
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
        _normalizeVehicleId(vehicleId);

    try {
      final snapshot =
          await _profiles(
            normalizedTenantId,
          ).where(
            'vehicleId',
            isEqualTo: normalizedVehicleId,
          ).limit(1).get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      final doc =
          snapshot.docs.first;

      return _parseAndValidateProfile(
        tenantId: normalizedTenantId,
        documentId: doc.id,
        data: doc.data(),
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

      // Method argument is authoritative.
      data['tenantId'] =
          normalizedTenantId;

      // The Firestore document ID is authoritative.
      data['id'] =
          doc.id;

      // New pricing configurations start at version 1.
      final requestedVersion =
          profile.pricingVersion > 0
              ? profile.pricingVersion
              : 1;

      data['pricingVersion'] =
          requestedVersion;

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

  /// Updates pricing and automatically increments pricingVersion.
  ///
  /// This is critical for immutable booking snapshots:
  ///
  /// Booking A → pricingVersion 3
  /// Pricing edited → profile becomes version 4
  /// Booking A remains version 3.
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
          _profiles(
            normalizedTenantId,
          ).doc(
            normalizedProfileId,
          );

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

      final currentVersion =
          _readInt(
        existingData?['pricingVersion'],
        fallback: 1,
      );

      final nextVersion =
          currentVersion < 1
              ? 1
              : currentVersion + 1;

      final data =
          profile.toMap();

      // Never trust tenant/profile IDs coming from the UI.
      data['tenantId'] =
          normalizedTenantId;

      data['id'] =
          normalizedProfileId;

      data['pricingVersion'] =
          nextVersion;

      // Preserve the original creation timestamp when it exists.
      if (existingData?['createdAt'] != null) {
        data['createdAt'] =
            existingData!['createdAt'];
      }

      data['updatedAt'] =
          FieldValue.serverTimestamp();

      await doc.set(
        data,
        SetOptions(
          merge: false,
        ),
      );
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
  // UPDATE PRICING PROFILE FROM MAP
  // ===========================================================================

  /// Useful for admin forms that already produce a Firebase-ready map.
  ///
  /// pricingVersion is always incremented server-side by reading the current
  /// document first.
  Future<int> updatePricingProfileMap({
    required String tenantId,
    required String pricingProfileId,
    required Map<String, dynamic> values,
  }) async {
    final normalizedTenantId =
        _normalizeTenantId(tenantId);

    final normalizedProfileId =
        _normalizeProfileId(
      pricingProfileId,
    );

    try {
      final doc =
          _profiles(
            normalizedTenantId,
          ).doc(
            normalizedProfileId,
          );

      final existing =
          await doc.get();

      if (!existing.exists) {
        throw Exception(
          'Pricing profile not found.',
        );
      }

      final existingData =
          existing.data();

      final existingTenantId =
          existingData?['tenantId']
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

      final currentVersion =
          _readInt(
        existingData?['pricingVersion'],
        fallback: 1,
      );

      final nextVersion =
          currentVersion < 1
              ? 1
              : currentVersion + 1;

      final data =
          Map<String, dynamic>.from(
        values,
      );

      data['tenantId'] =
          normalizedTenantId;

      data['id'] =
          normalizedProfileId;

      data['pricingVersion'] =
          nextVersion;

      if (existingData?['createdAt'] != null) {
        data['createdAt'] =
            existingData!['createdAt'];
      }

      data['updatedAt'] =
          FieldValue.serverTimestamp();

      await doc.set(
        data,
        SetOptions(
          merge: false,
        ),
      );

      return nextVersion;
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
  // DUPLICATE PRICING PROFILE
  // ===========================================================================

  /// Creates a new profile based on an existing profile.
  ///
  /// The duplicated profile starts at pricingVersion 1.
  Future<String> duplicatePricingProfile({
    required String tenantId,
    required String sourcePricingProfileId,
    String? newPricingProfileId,
    String? newName,
  }) async {
    final normalizedTenantId =
        _normalizeTenantId(tenantId);

    final source =
        await getPricingProfileById(
      tenantId: normalizedTenantId,
      pricingProfileId:
          sourcePricingProfileId,
    );

    if (source == null) {
      throw Exception(
        'Source pricing profile not found.',
      );
    }

    final copied =
        source.copyWith(
      id: newPricingProfileId ??
          '',
      name: newName ??
          '${source.name} Copy',
      pricingVersion: 1,
    );

    return createPricingProfile(
      tenantId: normalizedTenantId,
      profile: copied,
    );
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
          _profiles(
            normalizedTenantId,
          ).doc(
            normalizedProfileId,
          );

      final snapshot =
          await doc.get();

      if (!snapshot.exists) {
        throw Exception(
          'Pricing profile not found.',
        );
      }

      await doc.update({
        'isActive': true,
        'tenantId':
            normalizedTenantId,
        'pricingVersion':
            FieldValue.increment(1),
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
          _profiles(
            normalizedTenantId,
          ).doc(
            normalizedProfileId,
          );

      final snapshot =
          await doc.get();

      if (!snapshot.exists) {
        throw Exception(
          'Pricing profile not found.',
        );
      }

      await doc.update({
        'isActive': false,
        'tenantId':
            normalizedTenantId,
        'pricingVersion':
            FieldValue.increment(1),
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
  // DELETE PRICING PROFILE
  // ===========================================================================

  /// Hard delete.
  ///
  /// Prefer deactivation when the profile has historical bookings because
  /// old bookings should retain their pricingSnapshot.
  Future<void> deletePricingProfile({
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
          _profiles(
            normalizedTenantId,
          ).doc(
            normalizedProfileId,
          );

      final snapshot =
          await doc.get();

      if (!snapshot.exists) {
        return;
      }

      final data =
          snapshot.data();

      final existingTenantId =
          data?['tenantId']
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

      await doc.delete();
    } on FirebaseException catch (e) {
      throw Exception(
        'Unable to delete pricing profile: '
        '${e.message ?? e.code}',
      );
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }

      throw Exception(
        'Unable to delete pricing profile.',
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

    return _profiles(
      normalizedTenantId,
    ).snapshots().map(
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

    return _profiles(
      normalizedTenantId,
    ).snapshots().map(
      (snapshot) {
        final profiles =
            snapshot.docs.map(
          (doc) {
            return PricingProfile.fromMap(
              doc.id,
              doc.data(),
            );
          },
        ).where(
          (profile) =>
              profile.isActive,
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
  // WATCH SINGLE PROFILE
  // ===========================================================================

  Stream<PricingProfile?>
      watchPricingProfile({
    required String tenantId,
    required String pricingProfileId,
  }) {
    final normalizedTenantId =
        _normalizeTenantId(tenantId);

    final normalizedProfileId =
        _normalizeProfileId(
      pricingProfileId,
    );

    return _profiles(
      normalizedTenantId,
    ).doc(
      normalizedProfileId,
    ).snapshots().map(
      (doc) {
        if (!doc.exists) {
          return null;
        }

        final data =
            doc.data();

        if (data == null) {
          return null;
        }

        return _parseAndValidateProfile(
          tenantId:
              normalizedTenantId,
          documentId: doc.id,
          data: data,
        );
      },
    );
  }

  // ===========================================================================
  // RENTAL TYPE HELPERS
  // ===========================================================================

  List<RentalType>
      availableRentalTypesForRange(
    PricingProfile profile, {
    required DateTime start,
    required DateTime end,
  }) {
    if (end.isBefore(start)) {
      return const [];
    }

    return profile
        .availableRentalTypesForRange(
      start,
      end,
    );
  }

  bool isRentalTypeEnabled(
    PricingProfile profile,
    RentalType type,
  ) {
    return profile.isRentalTypeEnabled(
      type,
    );
  }

  SpecialPricingRule?
      specialRuleForRange(
    PricingProfile profile, {
    required DateTime start,
    required DateTime end,
  }) {
    if (end.isBefore(start)) {
      return null;
    }

    return profile.specialRuleForRange(
      start,
      end,
    );
  }

  // ===========================================================================
  // VALIDATION
  // ===========================================================================

  PricingProfile _parseAndValidateProfile({
    required String tenantId,
    required String documentId,
    required Map<String, dynamic> data,
  }) {
    final profile =
        PricingProfile.fromMap(
      documentId,
      data,
    );

    if (profile.tenantId.isNotEmpty &&
        profile.tenantId != tenantId) {
      throw Exception(
        'Pricing profile "$documentId" belongs to another tenant.',
      );
    }

    return profile;
  }

  int _readInt(
    dynamic value, {
    required int fallback,
  }) {
    if (value is num) {
      return value.toInt();
    }

    final parsed =
        int.tryParse(
      value?.toString() ?? '',
    );

    return parsed ?? fallback;
  }
}
