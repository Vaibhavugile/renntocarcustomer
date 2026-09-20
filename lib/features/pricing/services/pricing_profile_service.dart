import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/pricing_profile.dart';

/// Firestore CRUD/service layer for the simplified vehicle pricing model.
///
/// Firestore:
///   tenants/{tenantId}/pricingProfiles/{pricingProfileId}
///
/// Pricing model:
///   Pricing Profile
///     ├── hourlyPackages
///     ├── dailyPackages
///     ├── specialRates
///     └── securityDeposit
///
/// Supported rental types:
///   - hourly
///   - daily
///
/// The service deliberately does not create or persist weekend/weekly/monthly
/// pricing fields. Legacy documents can still be read through
/// PricingProfile.fromMap() for migration compatibility.
///
/// IMPORTANT
/// - This service stores pricing configuration only.
/// - It does not calculate booking totals.
/// - Booking-level price changes belong to the Booking/PricingSnapshot.
/// - pricingVersion is not used by the new pricing model.
/// - Legacy pricing fields are accepted while reading old documents through
///   PricingProfile.fromMap(), but are never written back by this service.
class PricingProfileService {
  PricingProfileService._();

  static final PricingProfileService instance = PricingProfileService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _profiles(String tenantId) {
    final id = _tenantId(tenantId);
    return _firestore
        .collection('tenants')
        .doc(id)
        .collection('pricingProfiles');
  }

  CollectionReference<Map<String, dynamic>> _cars(String tenantId) {
    final id = _tenantId(tenantId);
    return _firestore
        .collection('tenants')
        .doc(id)
        .collection('cars');
  }

  String _tenantId(String value) {
    final id = value.trim();
    if (id.isEmpty) {
      throw ArgumentError('tenantId cannot be empty.');
    }
    return id;
  }

  String _profileId(String value) {
    final id = value.trim();
    if (id.isEmpty) {
      throw ArgumentError('pricingProfileId cannot be empty.');
    }
    return id;
  }

  String _requiredId(String value, String field) {
    final id = value.trim();
    if (id.isEmpty) {
      throw ArgumentError('$field cannot be empty.');
    }
    return id;
  }

  String? _optionalId(String? value) {
    final id = value?.trim();
    return id == null || id.isEmpty ? null : id;
  }

  // ===========================================================================
  // READ
  // ===========================================================================

  Future<List<PricingProfile>> getAllPricingProfiles({
    required String tenantId,
    bool activeOnly = false,
  }) async {
    final id = _tenantId(tenantId);

    try {
      final snapshot = await _profiles(id).get();
      final profiles = <PricingProfile>[];

      for (final doc in snapshot.docs) {
        final profile = _parse(doc, id);
        if (!activeOnly || profile.isActive) {
          profiles.add(profile);
        }
      }

      profiles.sort((a, b) {
        final name = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        if (name != 0) return name;
        return a.id.compareTo(b.id);
      });

      return List.unmodifiable(profiles);
    } on FirebaseException catch (e) {
      throw Exception(
        'Unable to load pricing profiles: ${e.message ?? e.code}',
      );
    }
  }

  Future<List<PricingProfile>> getActivePricingProfiles({
    required String tenantId,
  }) {
    return getAllPricingProfiles(tenantId: tenantId, activeOnly: true);
  }

  Future<PricingProfile?> getPricingProfileById({
    required String tenantId,
    required String pricingProfileId,
  }) async {
    final tenant = _tenantId(tenantId);
    final profileId = _profileId(pricingProfileId);

    try {
      final doc = await _profiles(tenant).doc(profileId).get();
      if (!doc.exists || doc.data() == null) return null;
      return _parse(doc, tenant);
    } on FirebaseException catch (e) {
      throw Exception(
        'Unable to load pricing profile: ${e.message ?? e.code}',
      );
    }
  }

  /// Finds the profile directly assigned to a vehicle first.
  ///
  /// If no vehicle-specific profile exists, the car document is checked for:
  ///   1. pricingProfileId
  ///   2. pricingGroupId
  ///
  /// This allows multiple cars to share one pricing profile/group without
  /// duplicating pricing documents.
  Future<PricingProfile?> getPricingProfileForVehicle({
    required String tenantId,
    required String vehicleId,
  }) async {
    final tenant = _tenantId(tenantId);
    final carId = _requiredId(vehicleId, 'vehicleId');

    try {
      final direct = await _profiles(tenant)
          .where('vehicleId', isEqualTo: carId)
          .limit(1)
          .get();

      if (direct.docs.isNotEmpty) {
        return _parse(direct.docs.first, tenant);
      }

      final carDoc = await _cars(tenant).doc(carId).get();
      if (!carDoc.exists || carDoc.data() == null) return null;

      final car = carDoc.data()!;
      final profileId = _optionalId(car['pricingProfileId']?.toString());
      if (profileId != null) {
        final profile = await getPricingProfileById(
          tenantId: tenant,
          pricingProfileId: profileId,
        );
        if (profile != null) return profile;
      }

      final groupId = _optionalId(
        car['pricingGroupId']?.toString() ?? car['pricingGroup']?.toString(),
      );
      if (groupId != null) {
        return getPricingProfileForGroup(
          tenantId: tenant,
          pricingGroupId: groupId,
        );
      }

      return null;
    } on FirebaseException catch (e) {
      throw Exception(
        'Unable to load vehicle pricing profile: ${e.message ?? e.code}',
      );
    }
  }

  /// Alias for vehicle/car pricing lookup.
  ///
  /// Kept intentionally small so callers can use either vehicle terminology
  /// without creating a second pricing implementation.
  Future<PricingProfile?> getPricingProfileForCar({
    required String tenantId,
    required String carId,
  }) {
    return getPricingProfileForVehicle(
      tenantId: tenantId,
      vehicleId: carId,
    );
  }

  Future<PricingProfile?> getPricingProfileForGroup({
    required String tenantId,
    required String pricingGroupId,
  }) async {
    final tenant = _tenantId(tenantId);
    final groupId = _requiredId(pricingGroupId, 'pricingGroupId');

    try {
      final snapshot = await _profiles(tenant)
          .where('pricingGroupId', isEqualTo: groupId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return _parse(snapshot.docs.first, tenant);
    } on FirebaseException catch (e) {
      throw Exception(
        'Unable to load pricing group profile: ${e.message ?? e.code}',
      );
    }
  }

  /// Returns all profiles belonging to a pricing group.
  Future<List<PricingProfile>> getPricingProfilesForGroup({
    required String tenantId,
    required String pricingGroupId,
    bool activeOnly = false,
  }) async {
    final tenant = _tenantId(tenantId);
    final groupId = _requiredId(pricingGroupId, 'pricingGroupId');

    try {
      final snapshot = await _profiles(tenant)
          .where('pricingGroupId', isEqualTo: groupId)
          .get();

      final result = snapshot.docs
          .map((doc) => _parse(doc, tenant))
          .where((profile) => !activeOnly || profile.isActive)
          .toList();

      result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return List.unmodifiable(result);
    } on FirebaseException catch (e) {
      throw Exception(
        'Unable to load pricing profiles for group: ${e.message ?? e.code}',
      );
    }
  }

  // ===========================================================================
  // CREATE
  // ===========================================================================

  Future<String> createPricingProfile({
    required String tenantId,
    required PricingProfile profile,
  }) async {
    final tenant = _tenantId(tenantId);
    _validateProfile(profile, tenant);

    try {
      final collection = _profiles(tenant);
      final requestedId = profile.id.trim();
      final doc = requestedId.isEmpty
          ? collection.doc()
          : collection.doc(requestedId);

      if ((await doc.get()).exists) {
        throw Exception('A pricing profile with ID "${doc.id}" already exists.');
      }

      final data = _prepareWriteMap(
        profile,
        tenantId: tenant,
        documentId: doc.id,
      );

      data['createdAt'] = FieldValue.serverTimestamp();
      data['updatedAt'] = FieldValue.serverTimestamp();

      await doc.set(data);
      return doc.id;
    } on FirebaseException catch (e) {
      throw Exception(
        'Unable to create pricing profile: ${e.message ?? e.code}',
      );
    }
  }

  // ===========================================================================
  // UPDATE
  // ===========================================================================

  Future<void> updatePricingProfile({
    required String tenantId,
    required String pricingProfileId,
    required PricingProfile profile,
  }) async {
    final tenant = _tenantId(tenantId);
    final profileId = _profileId(pricingProfileId);

    _validateProfile(profile, tenant);

    if (profile.id.trim().isNotEmpty && profile.id.trim() != profileId) {
      throw Exception('Pricing profile ID does not match the document ID.');
    }

    try {
      final doc = _profiles(tenant).doc(profileId);
      final existing = await doc.get();

      if (!existing.exists || existing.data() == null) {
        throw Exception('Pricing profile not found.');
      }

      _verifyTenant(existing.data(), tenant);

      final data = _prepareWriteMap(
        profile,
        tenantId: tenant,
        documentId: profileId,
      );

      final existingData = existing.data()!;
      if (existingData['createdAt'] != null) {
        data['createdAt'] = existingData['createdAt'];
      } else {
        data['createdAt'] = FieldValue.serverTimestamp();
      }
      data['updatedAt'] = FieldValue.serverTimestamp();

      await doc.set(data, SetOptions(merge: false));
    } on FirebaseException catch (e) {
      throw Exception(
        'Unable to update pricing profile: ${e.message ?? e.code}',
      );
    }
  }

  /// Updates from an admin-form map while allowing only the new pricing fields.
  Future<void> updatePricingProfileMap({
    required String tenantId,
    required String pricingProfileId,
    required Map<String, dynamic> values,
  }) async {
    final tenant = _tenantId(tenantId);
    final profileId = _profileId(pricingProfileId);

    try {
      final doc = _profiles(tenant).doc(profileId);
      final existing = await doc.get();

      if (!existing.exists || existing.data() == null) {
        throw Exception('Pricing profile not found.');
      }
      _verifyTenant(existing.data(), tenant);

      final sanitized = _sanitizeMap(values);
      sanitized['tenantId'] = tenant;
      sanitized['id'] = profileId;

      // A map update must pass the exact same model validation as a normal
      // PricingProfile update. This prevents malformed package/deposit/special
      // rate data from bypassing the typed validation path.
      final parsedProfile = PricingProfile.fromMap(profileId, sanitized);
      _validateProfile(parsedProfile, tenant);

      final old = existing.data()!;
      sanitized['createdAt'] = old['createdAt'] ?? FieldValue.serverTimestamp();
      sanitized['updatedAt'] = FieldValue.serverTimestamp();

      await doc.set(sanitized, SetOptions(merge: false));
    } on FirebaseException catch (e) {
      throw Exception(
        'Unable to update pricing profile: ${e.message ?? e.code}',
      );
    }
  }

  // ===========================================================================
  // DUPLICATE
  // ===========================================================================

  Future<String> duplicatePricingProfile({
    required String tenantId,
    required String sourcePricingProfileId,
    String? newPricingProfileId,
    String? newName,
  }) async {
    final tenant = _tenantId(tenantId);
    final source = await getPricingProfileById(
      tenantId: tenant,
      pricingProfileId: sourcePricingProfileId,
    );

    if (source == null) {
      throw Exception('Source pricing profile not found.');
    }

    final copied = source.copyWith(
      id: newPricingProfileId?.trim() ?? '',
      name: newName?.trim().isNotEmpty == true
          ? newName!.trim()
          : '${source.name} Copy',
    );

    return createPricingProfile(tenantId: tenant, profile: copied);
  }

  // ===========================================================================
  // ACTIVE STATE
  // ===========================================================================

  Future<void> activatePricingProfile({
    required String tenantId,
    required String pricingProfileId,
  }) => _setActive(
        tenantId: tenantId,
        pricingProfileId: pricingProfileId,
        active: true,
      );

  Future<void> deactivatePricingProfile({
    required String tenantId,
    required String pricingProfileId,
  }) => _setActive(
        tenantId: tenantId,
        pricingProfileId: pricingProfileId,
        active: false,
      );

  Future<void> _setActive({
    required String tenantId,
    required String pricingProfileId,
    required bool active,
  }) async {
    final tenant = _tenantId(tenantId);
    final profileId = _profileId(pricingProfileId);

    try {
      final doc = _profiles(tenant).doc(profileId);
      final snapshot = await doc.get();
      if (!snapshot.exists || snapshot.data() == null) {
        throw Exception('Pricing profile not found.');
      }
      _verifyTenant(snapshot.data(), tenant);

      await doc.update({
        'isActive': active,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw Exception(
        'Unable to ${active ? 'activate' : 'deactivate'} pricing profile: '
        '${e.message ?? e.code}',
      );
    }
  }

  // ===========================================================================
  // DELETE
  // ===========================================================================

  Future<void> deletePricingProfile({
    required String tenantId,
    required String pricingProfileId,
  }) async {
    final tenant = _tenantId(tenantId);
    final profileId = _profileId(pricingProfileId);

    try {
      final doc = _profiles(tenant).doc(profileId);
      final snapshot = await doc.get();
      if (!snapshot.exists) return;
      _verifyTenant(snapshot.data(), tenant);
      await doc.delete();
    } on FirebaseException catch (e) {
      throw Exception(
        'Unable to delete pricing profile: ${e.message ?? e.code}',
      );
    }
  }

  // ===========================================================================
  // REALTIME
  // ===========================================================================

  Stream<List<PricingProfile>> watchPricingProfiles({
    required String tenantId,
  }) {
    final tenant = _tenantId(tenantId);

    return _profiles(tenant).snapshots().map((snapshot) {
      final profiles = <PricingProfile>[];
      for (final doc in snapshot.docs) {
        profiles.add(_parse(doc, tenant));
      }
      profiles.sort((a, b) {
        final name = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        if (name != 0) return name;
        return a.id.compareTo(b.id);
      });
      return List.unmodifiable(profiles);
    });
  }

  Stream<List<PricingProfile>> watchActivePricingProfiles({
    required String tenantId,
  }) {
    return watchPricingProfiles(tenantId: tenantId).map(
      (profiles) => List.unmodifiable(
        profiles.where((profile) => profile.isActive),
      ),
    );
  }

  Stream<PricingProfile?> watchPricingProfile({
    required String tenantId,
    required String pricingProfileId,
  }) {
    final tenant = _tenantId(tenantId);
    final profileId = _profileId(pricingProfileId);

    return _profiles(tenant).doc(profileId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return _parse(doc, tenant);
    });
  }

  // ===========================================================================
  // SIMPLE PRICING HELPERS
  // ===========================================================================

  /// Returns the first active profile for a vehicle/group lookup.
  ///
  /// The normal vehicle lookup remains backward compatible and may return an
  /// inactive profile when explicitly requested by callers. Booking/pricing
  /// flows should use this helper when they require a profile that can actually
  /// be used for new rentals.
  Future<PricingProfile?> getActivePricingProfileForVehicle({
    required String tenantId,
    required String vehicleId,
  }) async {
    final profile = await getPricingProfileForVehicle(
      tenantId: tenantId,
      vehicleId: vehicleId,
    );
    if (profile == null || !profile.isActive) return null;
    return profile;
  }

  /// Returns the first active profile in a pricing group.
  Future<PricingProfile?> getActivePricingProfileForGroup({
    required String tenantId,
    required String pricingGroupId,
  }) async {
    final profile = await getPricingProfileForGroup(
      tenantId: tenantId,
      pricingGroupId: pricingGroupId,
    );
    if (profile == null || !profile.isActive) return null;
    return profile;
  }


  List<RentalType> availableRentalTypes(PricingProfile profile) {
    final result = <RentalType>[];
    if (profile.hourlyEnabled) result.add(RentalType.hourly);
    if (profile.dailyEnabled) result.add(RentalType.daily);
    return List.unmodifiable(result);
  }

  bool isRentalTypeEnabled(PricingProfile profile, RentalType type) {
    return profile.isRentalTypeEnabled(type);
  }

  SpecialRate? specialRateForDate(PricingProfile profile, DateTime date) {
    return profile.specialRateForDate(date);
  }

  SpecialRate? specialRateForRange(
    PricingProfile profile, {
    required DateTime start,
    required DateTime end,
  }) {
    if (end.isBefore(start)) return null;
return profile.specialRateForRange(
  start,
  end,
);
  }

  // ===========================================================================
  // VALIDATION / PARSING
  // ===========================================================================

  PricingProfile _parse(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String tenantId,
  ) {
    final raw = Map<String, dynamic>.from(doc.data()!);
    raw['id'] = doc.id;

    // Old documents may not have tenantId. The Firestore path is already
    // tenant-scoped, so inject the current tenant only for parsing. A stored
    // non-empty tenantId is still checked and cannot cross tenant boundaries.
    final storedTenant = raw['tenantId']?.toString().trim() ?? '';
    if (storedTenant.isEmpty) {
      raw['tenantId'] = tenantId;
    }

    final profile = PricingProfile.fromMap(doc.id, raw);
    _verifyProfileTenant(profile, tenantId, doc.id);
    _validateProfile(profile, tenantId, allowEmptyId: false);
    return profile;
  }

  void _verifyProfileTenant(
    PricingProfile profile,
    String tenantId,
    String documentId,
  ) {
    final profileTenant = profile.tenantId.trim();
    if (profileTenant.isNotEmpty && profileTenant != tenantId) {
      throw Exception(
        'Pricing profile "$documentId" belongs to another tenant.',
      );
    }
  }

  void _verifyTenant(Map<String, dynamic>? data, String tenantId) {
    final stored = data?['tenantId']?.toString().trim() ?? '';
    if (stored.isNotEmpty && stored != tenantId) {
      throw Exception('Pricing profile belongs to another tenant.');
    }
  }

  void _validateProfile(
    PricingProfile profile,
    String tenantId, {
    bool allowEmptyId = true,
  }) {
    if (!allowEmptyId && profile.id.trim().isEmpty) {
      throw Exception('Pricing profile ID cannot be empty.');
    }

    if (profile.name.trim().isEmpty) {
      throw Exception('Pricing profile name cannot be empty.');
    }

    final profileTenant = profile.tenantId.trim();
    if (profileTenant.isNotEmpty && profileTenant != tenantId) {
      throw Exception('Pricing profile belongs to another tenant.');
    }

    if (!profile.hourlyEnabled && !profile.dailyEnabled) {
      throw Exception(
        'Pricing profile must contain at least one hourly or daily package.',
      );
    }

    _validatePackages(profile.hourlyPackages, 'hourly');
    _validatePackages(profile.dailyPackages, 'daily');
    _validateSpecialRates(profile.specialRates);
    _validateDeposit(profile.securityDeposit);
  }

  void _validatePackages(List<dynamic> packages, String type) {
    final ids = <String>{};
    for (final package in packages) {
      if (package == null) {
        throw Exception('$type package cannot be null.');
      }
      final id = package.id?.toString().trim() ?? '';
      final name = package.name?.toString().trim() ?? '';
      if (id.isEmpty) throw Exception('$type package ID cannot be empty.');
      if (!ids.add(id)) throw Exception('Duplicate $type package ID "$id".');
      if (name.isEmpty) throw Exception('$type package "$id" needs a name.');

      final active = package.isActive == true;
      final unlimited = package.unlimitedKm == true;
      final includedKm = package.includedKm;
      final rate = type == 'hourly'
          ? package.hourlyRate
          : package.dailyRate;

      if (active && !unlimited && (includedKm == null || includedKm < 0)) {
        throw Exception('$type package "$id" has invalid included KM.');
      }
      if (active && (rate is! num || rate < 0)) {
        throw Exception('$type package "$id" has an invalid price.');
      }
      if (package.extraKmRate is num && package.extraKmRate < 0) {
        throw Exception('$type package "$id" has an invalid extra KM rate.');
      }
    }
  }

  void _validateSpecialRates(List<SpecialRate> rates) {
    final ids = <String>{};
    for (final rate in rates) {
      if (!ids.add(rate.id.trim())) {
        throw Exception('Duplicate special rate ID "${rate.id}".');
      }
      if (rate.id.trim().isEmpty) {
        throw Exception('Special rate ID cannot be empty.');
      }
      if (rate.name.trim().isEmpty) {
        throw Exception('Special rate name cannot be empty.');
      }
      if (rate.endDate.isBefore(rate.startDate)) {
        throw Exception('Special rate "${rate.id}" has an invalid date range.');
      }
      for (final value in rate.hourlyPrices.values) {
        if (value < 0) throw Exception('Special hourly price cannot be negative.');
      }
      for (final value in rate.dailyPrices.values) {
        if (value < 0) throw Exception('Special daily price cannot be negative.');
      }
      if (rate.extraKmRate != null && rate.extraKmRate! < 0) {
        throw Exception('Special extra KM rate cannot be negative.');
      }
    }
  }

  void _validateDeposit(DepositConfig deposit) {
    if (deposit.amount < 0) {
      throw Exception('Security deposit amount cannot be negative.');
    }
    if (deposit.minimumAssetValue < 0) {
      throw Exception('Minimum security asset value cannot be negative.');
    }
  }

  // ===========================================================================
  // FIRESTORE WRITE MAP
  // ===========================================================================

  Map<String, dynamic> _prepareWriteMap(
    PricingProfile profile, {
    required String tenantId,
    required String documentId,
  }) {
    final raw = Map<String, dynamic>.from(profile.toMap());

    raw['id'] = documentId;
    raw['tenantId'] = tenantId;

    // Never persist obsolete pricing architecture.
    const obsolete = <String>{
      'pricingVersion',
      'weekendRate',
      'weeklyRate',
      'monthlyRate',
      'hourlyRate',
      'dailyRate',
      'weekendPricing',
      'weeklyPricing',
      'monthlyPricing',
      'specialPricingRules',
      'kmPricingMode',
      'includedKmPerDay',
      'perKmRate',
      'kmPackages',
      'depositConfig',
    };
   raw.removeWhere(
  (key, value) => obsolete.contains(key),
);

    return _sanitizeMap(raw);
  }

  Map<String, dynamic> _sanitizeMap(Map<String, dynamic> values) {
    final data = Map<String, dynamic>.from(values);

    const allowed = <String>{
      'id',
      'tenantId',
      'vehicleId',
      'pricingGroupId',
      'name',
      'currency',
      'hourlyPackages',
      'dailyPackages',
      'specialRates',
      'securityDeposit',
      'isActive',
      'createdAt',
      'updatedAt',
    };

    data.removeWhere((key, value) => !allowed.contains(key));

    // Explicitly remove legacy fields even if an allowed-map is changed later.
    data.remove('pricingVersion');
    data.remove('weekendRate');
    data.remove('weeklyRate');
    data.remove('monthlyRate');
    data.remove('specialPricingRules');
    data.remove('kmPricingMode');
    data.remove('includedKmPerDay');
    data.remove('perKmRate');
    data.remove('kmPackages');
    data.remove('depositConfig');

    return data;
  }

  void _validateRawMap(Map<String, dynamic> data) {
    final profileId = data['id']?.toString().trim() ?? '';
    final tenantId = data['tenantId']?.toString().trim() ?? '';

    if (profileId.isEmpty) {
      throw Exception('Pricing profile ID cannot be empty.');
    }
    if (tenantId.isEmpty) {
      throw Exception('Pricing profile tenantId cannot be empty.');
    }

    final profile = PricingProfile.fromMap(profileId, data);
    _validateProfile(profile, tenantId, allowEmptyId: false);
  }
}
