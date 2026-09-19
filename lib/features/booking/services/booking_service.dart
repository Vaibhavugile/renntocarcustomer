import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/booking.dart';
import '../../cars/models/car.dart';
import '../../admin/availability/services/admin_availability_service.dart';

/// Firebase booking data layer.
///
/// IMPORTANT:
/// - Every booking is tenant-scoped.
/// - Customer reads are restricted to the authenticated Firebase UID.
/// - Booking stores historical car/branch/customer/pricing snapshots.
/// - Availability checks consider vehicle status, blocks and blocking bookings.
///
/// NOTE:
/// This service is Firebase-only. Availability is checked again immediately
/// before a booking is written. Firestore Security Rules must independently
/// enforce tenant/admin/customer authorization.
class BookingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AdminAvailabilityService _availabilityService =
      AdminAvailabilityService.instance;

  BookingService._();

  static final BookingService instance =
      BookingService._();

  factory BookingService() => instance;

  CollectionReference<Map<String, dynamic>> _bookings(
    String tenantId,
  ) =>
      _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('bookings');

  CollectionReference<Map<String, dynamic>> _cars(
    String tenantId,
  ) =>
      _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('cars');

  CollectionReference<Map<String, dynamic>> _branches(
    String tenantId,
  ) =>
      _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('branches');

  CollectionReference<Map<String, dynamic>> _customers(
    String tenantId,
  ) =>
      _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('customers');

  User _requireUser() {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User is not authenticated.');
    }
    return user;
  }

  void _validateTenant(
    Booking booking,
    String tenantId,
  ) {
    if (booking.tenantId != tenantId) {
      throw Exception('Tenant mismatch.');
    }
  }

  void _validateCustomer(
    Booking booking,
    String customerId,
  ) {
    if (booking.customerId != customerId) {
      throw Exception('Customer identity mismatch.');
    }
  }

  String get currentCustomerId => _requireUser().uid;

  // ============================================================
  // AVAILABILITY
  // ============================================================

  /// Uses the same availability engine as the Admin calendar and
  /// Customer Date/Time selection.
  ///
  /// This keeps vehicle status, active blocks, booking status handling,
  /// expired pending bookings and time-overlap rules consistent everywhere.
  Future<bool> isCarAvailable({
    required String tenantId,
    required String carId,
    required DateTime pickupDateTime,
    required DateTime returnDateTime,
    String? excludeBookingId,
  }) async {
    _validateDateRange(pickupDateTime, returnDateTime);

    final normalized = _normalizeAvailabilityRange(
      rentalType: null,
      pickupDateTime: pickupDateTime,
      returnDateTime: returnDateTime,
    );

    final snapshot = await _availabilityService.getAvailabilityForRange(
      rangeStart: normalized.start,
      rangeEnd: normalized.end,
      tenantId: tenantId,
    );

    Car? car;
    for (final item in snapshot.cars) {
      if (item.id == carId) {
        car = item;
        break;
      }
    }

    if (car == null) {
      return false;
    }

    final bookings = snapshot.bookings.where((booking) {
      if (excludeBookingId == null) return true;
      return booking.id != excludeBookingId;
    }).toList();

    return _availabilityService.isCarAvailableForRange(
      car: car,
      start: normalized.start,
      end: normalized.end,
      bookings: bookings,
      blocks: snapshot.blocks,
    );
  }

  /// Availability check that understands hourly/daily/weekend rental
  /// semantics.
  ///
  /// Hourly uses the exact timestamps.
  /// Daily/weekend occupy the complete selected calendar days and therefore
  /// end at 23:59:59.999999 on the selected return date.
  Future<bool> isCarAvailableForRental({
    required String tenantId,
    required String carId,
    required String rentalType,
    required DateTime pickupDateTime,
    required DateTime returnDateTime,
    String? excludeBookingId,
  }) async {
    _validateDateRange(
      pickupDateTime,
      returnDateTime,
    );

    final normalized = _normalizeAvailabilityRange(
      rentalType: rentalType,
      pickupDateTime: pickupDateTime,
      returnDateTime: returnDateTime,
    );

    final snapshot =
        await _availabilityService.getAvailabilityForRange(
      rangeStart: normalized.start,
      rangeEnd: normalized.end,
      tenantId: tenantId,
    );

    Car? car;
    for (final item in snapshot.cars) {
      if (item.id == carId) {
        car = item;
        break;
      }
    }

    if (car == null) {
      return false;
    }

    final bookings = snapshot.bookings.where((booking) {
      if (excludeBookingId == null) {
        return true;
      }
      return booking.id != excludeBookingId;
    }).toList();

    return _availabilityService.isCarAvailableForRange(
      car: car,
      start: normalized.start,
      end: normalized.end,
      bookings: bookings,
      blocks: snapshot.blocks,
    );
  }

  /// Rechecks a booking using the rental type stored on the booking.
  Future<bool> isBookingStillAvailable({
    required String tenantId,
    required Booking booking,
  }) {
    _validateTenant(booking, tenantId);

    return isCarAvailableForRental(
      tenantId: tenantId,
      carId: booking.carId,
      rentalType: booking.rentalType,
      pickupDateTime: booking.pickupDateTime,
      returnDateTime: booking.returnDateTime,
      excludeBookingId: booking.bookingId,
    );
  }

  void _validateDateRange(
    DateTime pickup,
    DateTime returnTime,
  ) {
    if (!pickup.isBefore(returnTime)) {
      throw Exception(
        'Return time must be after pickup time.',
      );
    }
  }

  // ============================================================
  // CREATE BOOKING
  // ============================================================

  Future<Booking> createBooking({
    required String tenantId,
    required Booking booking,
  }) async {
    final user = _requireUser();

    _validateTenant(booking, tenantId);
    _validateCustomer(booking, user.uid);
    _validateDateRange(
      booking.pickupDateTime,
      booking.returnDateTime,
    );

    _validateRentalMetadata(booking);

    if (booking.carId.trim().isEmpty) {
      throw Exception('Car is required.');
    }

    if (booking.pickupBranchId.trim().isEmpty) {
      throw Exception('Pickup branch is required.');
    }

    // Customer ID, Firebase UID and customer document ID are the same
    // identifier in this application.
    final customerDoc = await _customers(tenantId)
        .doc(user.uid)
        .get();

    if (!customerDoc.exists || customerDoc.data() == null) {
      throw Exception(
        'Customer profile was not found. Please complete your profile first.',
      );
    }

    final customerData = customerDoc.data()!;

    if (customerData['tenantId']?.toString() != tenantId) {
      throw Exception('Customer tenant mismatch.');
    }

    if (customerData['isActive'] == false) {
      throw Exception('Customer account is inactive.');
    }

    // If firebaseUid is stored, it must match the document ID/auth UID.
    final storedFirebaseUid =
        customerData['firebaseUid']?.toString().trim() ?? '';

    if (storedFirebaseUid.isNotEmpty && storedFirebaseUid != user.uid) {
      throw Exception('Customer Firebase identity mismatch.');
    }

    // Enrich the booking with immutable snapshots before saving.
    final enriched = await _buildHistoricalSnapshot(
      tenantId: tenantId,
      booking: booking,
      customerId: user.uid,
    );

    // Final authoritative availability check immediately before write.
    final available = await isCarAvailableForRental(
      tenantId: tenantId,
      carId: enriched.carId,
      rentalType: enriched.rentalType,
      pickupDateTime: enriched.pickupDateTime,
      returnDateTime: enriched.returnDateTime,
    );

    if (!available) {
      throw Exception(
        'This car is not available for the selected dates.',
      );
    }

    final reference = _bookings(tenantId).doc();
    final data = enriched.toMap();

    data['bookingId'] = reference.id;
    data['tenantId'] = tenantId;

    // customerId == Firestore customer document ID == Firebase Auth UID.
    data['customerId'] = user.uid;
    data['customerFirebaseUid'] = user.uid;
    data['firebaseUid'] = user.uid;

    data['createdBy'] = user.uid;
    data['createdByRole'] = 'customer';
    data['bookingSource'] = 'customer';
    data['bookingChannel'] = 'app';

    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();

    // Keep booking searchable without depending on nested snapshots.
    data['carId'] = enriched.carId;
    data['branchId'] = enriched.branchId;
    data['pickupBranchId'] = enriched.pickupBranchId;
    data['returnBranchId'] = enriched.returnBranchId;

    await reference.set(data);

    final saved = await reference.get();

    if (!saved.exists || saved.data() == null) {
      throw Exception('Unable to create booking.');
    }

    return Booking.fromMap(
      saved.id,
      saved.data()!,
    );
  }

  void _validateRentalMetadata(
    Booking booking,
  ) {
    final rentalType =
        booking.rentalType.trim().toLowerCase();

    const allowed = {
      'hourly',
      'daily',
      'weekend',
    };

    if (!allowed.contains(rentalType)) {
      throw Exception(
        'Invalid rental type. Use hourly, daily or weekend.',
      );
    }

    if (booking.pricingVersion < 1) {
      throw Exception(
        'Invalid pricing version.',
      );
    }

    if (booking.pricingProfileId.trim().isEmpty) {
      throw Exception(
        'Pricing profile is required.',
      );
    }
  }

  _AvailabilityRange _normalizeAvailabilityRange({
    required String? rentalType,
    required DateTime pickupDateTime,
    required DateTime returnDateTime,
  }) {
    final type =
        rentalType?.trim().toLowerCase();

    if (type == 'daily' ||
        type == 'weekend') {
      final start = DateTime(
        pickupDateTime.year,
        pickupDateTime.month,
        pickupDateTime.day,
      );

      final end = DateTime(
        returnDateTime.year,
        returnDateTime.month,
        returnDateTime.day,
        23,
        59,
        59,
        999,
      );

      return _AvailabilityRange(
        start: start,
        end: end,
      );
    }

    return _AvailabilityRange(
      start: pickupDateTime,
      end: returnDateTime,
    );
  }

  // ============================================================
  // ADMIN AUTHORIZATION
  // ============================================================

  Future<Map<String, dynamic>> _requireTenantAdmin({
    required String tenantId,
  }) async {
    final user = _requireUser();

    final adminDoc = await _firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('admins')
        .doc(user.uid)
        .get();

    if (!adminDoc.exists || adminDoc.data() == null) {
      throw Exception('Admin access is required.');
    }

    final data = adminDoc.data()!;

    if (data['tenantId']?.toString() != tenantId) {
      throw Exception('Admin tenant mismatch.');
    }

    if (data['isActive'] != true) {
      throw Exception('Admin account is inactive.');
    }

    return data;
  }

  Future<Booking> createBookingForAdmin({
    required String tenantId,
    required Booking booking,
  }) async {
    final adminUser = _requireUser();

    await _requireTenantAdmin(
      tenantId: tenantId,
    );

    _validateTenant(booking, tenantId);
    _validateDateRange(
      booking.pickupDateTime,
      booking.returnDateTime,
    );

    _validateRentalMetadata(booking);

    if (booking.carId.trim().isEmpty) {
      throw Exception('Car is required.');
    }

    if (booking.pickupBranchId.trim().isEmpty) {
      throw Exception('Pickup branch is required.');
    }

    if (booking.customerId.trim().isEmpty) {
      throw Exception('Customer is required.');
    }

    // customerId is intentionally the same value as:
    // 1. Firestore customers/{customerId} document ID
    // 2. customer.customerId field
    // 3. customer.firebaseUid field
    // 4. Firebase Authentication UID
    final customerId = booking.customerId.trim();

    final customerDoc = await _customers(tenantId)
        .doc(customerId)
        .get();

    if (!customerDoc.exists || customerDoc.data() == null) {
      throw Exception('Selected customer was not found.');
    }

    // The selected customer document ID must be the customer ID.
    if (customerDoc.id != customerId) {
      throw Exception('Customer identity mismatch.');
    }

    final customerData = customerDoc.data()!;

    if (customerData['tenantId']?.toString() != tenantId) {
      throw Exception('Customer tenant mismatch.');
    }

    if (customerData['isActive'] == false) {
      throw Exception('Selected customer is inactive.');
    }

    final storedCustomerId =
        customerData['customerId']?.toString().trim() ?? '';
    final linkedFirebaseUid =
        customerData['firebaseUid']?.toString().trim() ?? '';

    if (storedCustomerId.isNotEmpty && storedCustomerId != customerId) {
      throw Exception('Customer ID field does not match document ID.');
    }

    if (linkedFirebaseUid.isNotEmpty &&
        linkedFirebaseUid != customerId) {
      throw Exception(
        'Customer Firebase UID must match the customer ID.',
      );
    }

    // Because customerId == Firebase UID in this architecture, the admin
    // booking always belongs to the selected customer's Firebase account.
    if (linkedFirebaseUid.isEmpty) {
      throw Exception(
        'Selected customer does not have a Firebase account yet.',
      );
    }

    final enriched = await _buildHistoricalSnapshot(
      tenantId: tenantId,
      booking: booking,
      customerId: customerId,
      useAuthenticatedUserAsCustomer: false,
    );

    // Final authoritative availability check immediately before write.
    final available = await isCarAvailableForRental(
      tenantId: tenantId,
      carId: enriched.carId,
      rentalType: enriched.rentalType,
      pickupDateTime: enriched.pickupDateTime,
      returnDateTime: enriched.returnDateTime,
    );

    if (!available) {
      throw Exception(
        'This car is no longer available for the selected dates.',
      );
    }

    final reference = _bookings(tenantId).doc();
    final data = enriched.toMap();

    data['bookingId'] = reference.id;
    data['tenantId'] = tenantId;

    // IMPORTANT:
    // Admin-created booking uses the SELECTED CUSTOMER'S Firebase UID.
    data['customerId'] = customerId;
    data['customerFirebaseUid'] = customerId;
    data['firebaseUid'] = customerId;

    // Admin audit information.
    data['createdBy'] = adminUser.uid;
    data['createdByRole'] = 'admin';
    data['bookingSource'] = 'admin';
    data['bookingChannel'] = 'walk_in';

    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();

    data['carId'] = enriched.carId;
    data['branchId'] = enriched.branchId;
    data['pickupBranchId'] = enriched.pickupBranchId;
    data['returnBranchId'] = enriched.returnBranchId;

    await reference.set(data);

    final saved = await reference.get();

    if (!saved.exists || saved.data() == null) {
      throw Exception('Unable to create booking.');
    }

    return Booking.fromMap(
      saved.id,
      saved.data()!,
    );
  }

  // ============================================================
  // ADMIN BOOKING READS
  // ============================================================

  Future<Booking?> getBookingForAdmin({
    required String tenantId,
    required String bookingId,
  }) async {
    await _requireTenantAdmin(
      tenantId: tenantId,
    );

    final doc = await _bookings(tenantId)
        .doc(bookingId)
        .get();

    if (!doc.exists || doc.data() == null) {
      return null;
    }

    final booking = Booking.fromMap(
      doc.id,
      doc.data()!,
    );

    _validateTenant(booking, tenantId);

    return booking;
  }

  Future<List<Booking>> getAllBookingsForAdmin({
    required String tenantId,
    String? carId,
    String? customerId,
  }) async {
    await _requireTenantAdmin(
      tenantId: tenantId,
    );

    Query<Map<String, dynamic>> query =
        _bookings(tenantId);

    if (carId != null && carId.trim().isNotEmpty) {
      query = query.where(
        'carId',
        isEqualTo: carId.trim(),
      );
    }

    if (customerId != null &&
        customerId.trim().isNotEmpty) {
      query = query.where(
        'customerId',
        isEqualTo: customerId.trim(),
      );
    }

    final snapshot = await query.get();

    final bookings = snapshot.docs
        .map(
          (doc) => Booking.fromMap(
            doc.id,
            doc.data(),
          ),
        )
        .where(
          (booking) =>
              booking.tenantId == tenantId,
        )
        .toList();

    bookings.sort(
      (a, b) => b.pickupDateTime.compareTo(
        a.pickupDateTime,
      ),
    );

    return bookings;
  }

  Future<List<Booking>> getBookingsForAdminDateRange({
    required String tenantId,
    required DateTime start,
    required DateTime end,
    String? carId,
    BookingStatus? status,
  }) async {
    await _requireTenantAdmin(
      tenantId: tenantId,
    );

    if (!start.isBefore(end)) {
      throw Exception(
        'End date must be after start date.',
      );
    }

    Query<Map<String, dynamic>> query =
        _bookings(tenantId)
            .where(
              'pickupDateTime',
              isLessThan: Timestamp.fromDate(end),
            );

    if (carId != null &&
        carId.trim().isNotEmpty) {
      query = query.where(
        'carId',
        isEqualTo: carId.trim(),
      );
    }

    final snapshot = await query.get();

    final result = snapshot.docs
        .map(
          (doc) => Booking.fromMap(
            doc.id,
            doc.data(),
          ),
        )
        .where(
          (booking) =>
              booking.tenantId == tenantId &&
              booking.returnDateTime.isAfter(start) &&
              booking.pickupDateTime.isBefore(end) &&
              (status == null ||
                  booking.status == status),
        )
        .toList();

    result.sort(
      (a, b) =>
          a.pickupDateTime.compareTo(
        b.pickupDateTime,
      ),
    );

    return result;
  }

  Future<List<Booking>> getBookingsForCarForRange({
    required String tenantId,
    required String carId,
    required DateTime start,
    required DateTime end,
  }) {
    return getBookingsForAdminDateRange(
      tenantId: tenantId,
      start: start,
      end: end,
      carId: carId,
    );
  }

  Future<void> updateBookingStatusForAdmin({
    required String tenantId,
    required String bookingId,
    required BookingStatus status,
  }) async {
    await _requireTenantAdmin(
      tenantId: tenantId,
    );

    final reference =
        _bookings(tenantId).doc(bookingId);

    final doc = await reference.get();

    if (!doc.exists || doc.data() == null) {
      throw Exception('Booking not found.');
    }

    final booking = Booking.fromMap(
      doc.id,
      doc.data()!,
    );

    _validateTenant(booking, tenantId);

    await reference.update({
      'status': _statusToString(status),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> cancelBookingForAdmin({
    required String tenantId,
    required String bookingId,
    String reason = '',
  }) async {
    await _requireTenantAdmin(
      tenantId: tenantId,
    );

    final reference =
        _bookings(tenantId).doc(bookingId);

    final doc = await reference.get();

    if (!doc.exists || doc.data() == null) {
      throw Exception('Booking not found.');
    }

    final booking = Booking.fromMap(
      doc.id,
      doc.data()!,
    );

    _validateTenant(booking, tenantId);

    if (booking.status != BookingStatus.pending &&
        booking.status != BookingStatus.confirmed &&
        booking.status != BookingStatus.pickupPending) {
      throw Exception(
        'This booking cannot be cancelled.',
      );
    }

    await reference.update({
      'status': 'cancelled',
      'cancellationReason': reason,
      'cancelledBy': _auth.currentUser!.uid,
      'cancelledByRole': 'admin',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Copies current car/branch/customer information into the booking.
  ///
  /// This prevents historical bookings from changing when an admin edits
  /// the current car, branch or customer profile later.
  Future<Booking> _buildHistoricalSnapshot({
    required String tenantId,
    required Booking booking,
    required String customerId,
    bool useAuthenticatedUserAsCustomer = true,
  }) async {
    final user = useAuthenticatedUserAsCustomer
        ? _requireUser()
        : null;

    BookingCarSnapshot? carSnapshot = booking.car;
    BookingBranchSnapshot? pickupBranch = booking.pickupBranch;
    BookingBranchSnapshot? returnBranch = booking.returnBranch;

    // Car snapshot.
    final carDoc = await _cars(tenantId)
        .doc(booking.carId)
        .get();

    if (!carDoc.exists || carDoc.data() == null) {
      throw Exception('Selected car was not found.');
    }

    final carData = carDoc.data()!;

    carSnapshot ??= BookingCarSnapshot(
      carId: booking.carId,
      name: carData['name']?.toString() ?? '',
      type: carData['type']?.toString() ?? '',
      transmission:
          carData['transmission']?.toString() ?? '',
      seats: _toInt(carData['seats']),
      fuel: carData['fuel']?.toString() ?? '',
      image: carData['image']?.toString() ?? '',
      pricingProfileId:
          booking.pricingProfileId.isNotEmpty
              ? booking.pricingProfileId
              : carData['pricingProfileId']?.toString() ?? '',
    );

    // Pickup branch snapshot.
    final pickupDoc = await _branches(tenantId)
        .doc(booking.pickupBranchId)
        .get();

    if (!pickupDoc.exists || pickupDoc.data() == null) {
      throw Exception('Pickup branch was not found.');
    }

    final pickupData = pickupDoc.data()!;

    pickupBranch ??= BookingBranchSnapshot(
      branchId: booking.pickupBranchId,
      name: pickupData['name']?.toString() ?? '',
      city: pickupData['city']?.toString() ?? '',
      address: pickupData['address']?.toString() ?? '',
      phone: pickupData['phone']?.toString() ?? '',
    );

    // Return branch snapshot.
    final returnId = booking.returnBranchId.isNotEmpty
        ? booking.returnBranchId
        : booking.pickupBranchId;

    if (returnId == booking.pickupBranchId) {
      returnBranch ??= pickupBranch;
    } else {
      final returnDoc = await _branches(tenantId)
          .doc(returnId)
          .get();

      if (!returnDoc.exists || returnDoc.data() == null) {
        throw Exception('Return branch was not found.');
      }

      final returnData = returnDoc.data()!;

      returnBranch ??= BookingBranchSnapshot(
        branchId: returnId,
        name: returnData['name']?.toString() ?? '',
        city: returnData['city']?.toString() ?? '',
        address: returnData['address']?.toString() ?? '',
        phone: returnData['phone']?.toString() ?? '',
      );
    }

    // Customer snapshot.
    //
    // Customer ID is always the Firebase UID and the Firestore customer
    // document ID in this application.
    var customerName = booking.customerName;
    var customerPhone = booking.customerPhone;
    var customerEmail = booking.customerEmail;

    final customerDoc = await _customers(tenantId)
        .doc(customerId)
        .get();

    if (customerDoc.exists && customerDoc.data() != null) {
      final customerData = customerDoc.data()!;

      if (customerName.trim().isEmpty) {
        customerName =
            customerData['fullName']?.toString() ?? '';
      }

      if (customerPhone.trim().isEmpty) {
        customerPhone =
            customerData['phone']?.toString() ?? '';
      }

      if (customerEmail.trim().isEmpty) {
        customerEmail =
            customerData['email']?.toString() ?? '';
      }
    }

    if (useAuthenticatedUserAsCustomer) {
      final user = _requireUser();

      if (user.uid != customerId) {
        throw Exception('Customer identity mismatch.');
      }

      if (customerPhone.trim().isEmpty) {
        customerPhone = user.phoneNumber ?? '';
      }

      if (customerEmail.trim().isEmpty) {
        customerEmail = user.email ?? '';
      }
    }

    return booking.copyWith(
      tenantId: tenantId,
      customerId: customerId,
      branchId: booking.branchId.isNotEmpty
          ? booking.branchId
          : booking.pickupBranchId,
      pickupBranchId: booking.pickupBranchId,
      returnBranchId: returnId,
      car: carSnapshot,
      pickupBranch: pickupBranch,
      returnBranch: returnBranch,
      customerName: customerName,
      customerPhone: customerPhone,
      customerEmail: customerEmail,
      updatedAt: DateTime.now(),
    );
  }

  // ============================================================
  // READ ONE
  // ============================================================

  Future<Booking?> getBooking({
    required String tenantId,
    required String bookingId,
  }) async {
    final user = _requireUser();

    final doc = await _bookings(tenantId)
        .doc(bookingId)
        .get();

    if (!doc.exists || doc.data() == null) {
      return null;
    }

    final booking = Booking.fromMap(
      doc.id,
      doc.data()!,
    );

    _validateTenant(booking, tenantId);

    final ownsBooking = booking.customerId == user.uid;

    if (!ownsBooking) {
      throw Exception('Customer identity mismatch.');
    }

    return booking;
  }

  // ============================================================
  // CUSTOMER BOOKINGS
  // ============================================================

  Future<List<Booking>> getCustomerBookings({
    required String tenantId,
  }) async {
    final user = _requireUser();

    final snapshot = await _bookings(tenantId)
        .where(
          'customerId',
          isEqualTo: user.uid,
        )
        .get();

    final bookings = <Booking>[];

    for (final doc in snapshot.docs) {
      final booking = Booking.fromMap(
        doc.id,
        doc.data(),
      );

      _validateTenant(booking, tenantId);

      if (booking.customerId == user.uid) {
        bookings.add(booking);
      }
    }

    bookings.sort(
      (a, b) => b.pickupDateTime.compareTo(
        a.pickupDateTime,
      ),
    );

    return bookings;
  }

  Stream<List<Booking>> watchCustomerBookings({
    required String tenantId,
  }) {
    final user = _requireUser();

    return _bookings(tenantId)
        .where(
          'customerId',
          isEqualTo: user.uid,
        )
        .snapshots()
        .map((snapshot) {
      final bookings = snapshot.docs
          .map(
            (doc) => Booking.fromMap(
              doc.id,
              doc.data(),
            ),
          )
          .where(
            (booking) =>
                booking.tenantId == tenantId &&
                booking.customerId == user.uid,
          )
          .toList();

      bookings.sort(
        (a, b) => b.pickupDateTime.compareTo(
          a.pickupDateTime,
        ),
      );

      return bookings;
    });
  }

  // ============================================================
  // CALENDAR / DATE QUERIES
  // ============================================================

  Future<List<Booking>> getBookingsForMonth({
    required String tenantId,
    required DateTime month,
  }) async {
    final start = DateTime(
      month.year,
      month.month,
      1,
    );

    final end = DateTime(
      month.year,
      month.month + 1,
      1,
    );

    final bookings = await getCustomerBookings(
      tenantId: tenantId,
    );

    final result = bookings
        .where(
          (booking) =>
              booking.returnDateTime.isAfter(start) &&
              booking.pickupDateTime.isBefore(end),
        )
        .toList();

    result.sort(
      (a, b) => a.pickupDateTime.compareTo(
        b.pickupDateTime,
      ),
    );

    return result;
  }

  Future<List<Booking>> getBookingsForDate({
    required String tenantId,
    required DateTime date,
  }) async {
    final start = DateTime(
      date.year,
      date.month,
      date.day,
    );

    final end = start.add(
      const Duration(days: 1),
    );

    final bookings = await getCustomerBookings(
      tenantId: tenantId,
    );

    return bookings
        .where(
          (booking) =>
              booking.returnDateTime.isAfter(start) &&
              booking.pickupDateTime.isBefore(end),
        )
        .toList();
  }

  Future<bool> hasCustomerBookingOverlap({
    required String tenantId,
    required DateTime start,
    required DateTime end,
    String? excludeBookingId,
  }) async {
    _validateDateRange(start, end);

    final bookings = await getCustomerBookings(
      tenantId: tenantId,
    );

    return bookings.any(
      (booking) =>
          booking.isBlockingAvailability &&
          booking.bookingId != excludeBookingId &&
          booking.pickupDateTime.isBefore(end) &&
          booking.returnDateTime.isAfter(start),
    );
  }

  // ============================================================
  // FILTERS
  // ============================================================

  Future<List<Booking>> getUpcomingBookings({
    required String tenantId,
  }) async {
    final bookings = await getCustomerBookings(
      tenantId: tenantId,
    );

    return bookings
        .where((booking) => booking.isUpcoming)
        .toList();
  }

  Future<List<Booking>> getOngoingBookings({
    required String tenantId,
  }) async {
    final bookings = await getCustomerBookings(
      tenantId: tenantId,
    );

    return bookings
        .where((booking) => booking.isOngoing)
        .toList();
  }

  Future<List<Booking>> getCompletedBookings({
    required String tenantId,
  }) async {
    final bookings = await getCustomerBookings(
      tenantId: tenantId,
    );

    return bookings
        .where((booking) => booking.isCompleted)
        .toList();
  }

  Future<List<Booking>> getCancelledBookings({
    required String tenantId,
  }) async {
    final bookings = await getCustomerBookings(
      tenantId: tenantId,
    );

    return bookings
        .where(
          (booking) =>
              booking.isCancelled ||
              booking.isRejected ||
              booking.isNoShow,
        )
        .toList();
  }

  // ============================================================
  // ACTIVE BOOKING
  // ============================================================

  Future<bool> hasActiveBooking({
    required String tenantId,
  }) async {
    final bookings = await getCustomerBookings(
      tenantId: tenantId,
    );

    return bookings.any(
      (booking) =>
          booking.isUpcoming ||
          booking.isOngoing,
    );
  }

  Future<Booking?> getActiveBooking({
    required String tenantId,
  }) async {
    final bookings = await getCustomerBookings(
      tenantId: tenantId,
    );

    for (final booking in bookings) {
      if (booking.isOngoing) {
        return booking;
      }
    }

    return null;
  }

  // ============================================================
  // CANCEL
  // ============================================================

  Future<void> cancelBooking({
    required String tenantId,
    required String bookingId,
    String reason = '',
  }) async {
    final user = _requireUser();

    final reference =
        _bookings(tenantId).doc(bookingId);

    final doc = await reference.get();

    if (!doc.exists || doc.data() == null) {
      throw Exception('Booking not found.');
    }

    final booking = Booking.fromMap(
      doc.id,
      doc.data()!,
    );

    _validateTenant(booking, tenantId);
    _validateCustomer(booking, user.uid);

    if (booking.status != BookingStatus.pending &&
        booking.status != BookingStatus.confirmed &&
        booking.status != BookingStatus.pickupPending) {
      throw Exception(
        'This booking cannot be cancelled.',
      );
    }

    await reference.update({
      'status': 'cancelled',
      'cancellationReason': reason,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // STATUS
  // ============================================================

  Future<void> updateBookingStatus({
    required String tenantId,
    required String bookingId,
    required BookingStatus status,
  }) async {
    final user = _requireUser();

    final reference =
        _bookings(tenantId).doc(bookingId);

    final doc = await reference.get();

    if (!doc.exists || doc.data() == null) {
      throw Exception('Booking not found.');
    }

    final booking = Booking.fromMap(
      doc.id,
      doc.data()!,
    );

    _validateTenant(booking, tenantId);
    _validateCustomer(booking, user.uid);

    await reference.update({
      'status': _statusToString(status),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markPickupStarted({
    required String tenantId,
    required String bookingId,
  }) async {
    final user = _requireUser();
    final reference =
        _bookings(tenantId).doc(bookingId);

    final doc = await reference.get();

    if (!doc.exists || doc.data() == null) {
      throw Exception('Booking not found.');
    }

    final booking = Booking.fromMap(
      doc.id,
      doc.data()!,
    );

    _validateTenant(booking, tenantId);
    _validateCustomer(booking, user.uid);

    await reference.update({
      'status': 'active',
      'actualPickupDateTime':
          FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markReturnStarted({
    required String tenantId,
    required String bookingId,
  }) async {
    final user = _requireUser();
    final reference =
        _bookings(tenantId).doc(bookingId);

    final doc = await reference.get();

    if (!doc.exists || doc.data() == null) {
      throw Exception('Booking not found.');
    }

    final booking = Booking.fromMap(
      doc.id,
      doc.data()!,
    );

    _validateTenant(booking, tenantId);
    _validateCustomer(booking, user.uid);

    await reference.update({
      'status': 'return_pending',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markReturnCompleted({
    required String tenantId,
    required String bookingId,
  }) async {
    final user = _requireUser();
    final reference =
        _bookings(tenantId).doc(bookingId);

    final doc = await reference.get();

    if (!doc.exists || doc.data() == null) {
      throw Exception('Booking not found.');
    }

    final booking = Booking.fromMap(
      doc.id,
      doc.data()!,
    );

    _validateTenant(booking, tenantId);
    _validateCustomer(booking, user.uid);

    await reference.update({
      'status': 'completed',
      'actualReturnDateTime':
          FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // ADMIN PICKUP / RETURN OPERATIONS
  // ============================================================

  Future<void> markPickupStartedForAdmin({
    required String tenantId,
    required String bookingId,
  }) async {
    await _requireTenantAdmin(
      tenantId: tenantId,
    );

    final reference =
        _bookings(tenantId).doc(bookingId);

    final doc = await reference.get();

    if (!doc.exists || doc.data() == null) {
      throw Exception('Booking not found.');
    }

    final booking = Booking.fromMap(
      doc.id,
      doc.data()!,
    );

    _validateTenant(booking, tenantId);

    if (booking.status != BookingStatus.confirmed &&
        booking.status != BookingStatus.pickupPending) {
      throw Exception(
        'This booking is not ready for pickup.',
      );
    }

    await reference.update({
      'status': 'active',
      'actualPickupDateTime':
          FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastActionBy': _auth.currentUser!.uid,
      'lastActionByRole': 'admin',
    });
  }

  Future<void> markReturnStartedForAdmin({
    required String tenantId,
    required String bookingId,
  }) async {
    await _requireTenantAdmin(
      tenantId: tenantId,
    );

    final reference =
        _bookings(tenantId).doc(bookingId);

    final doc = await reference.get();

    if (!doc.exists || doc.data() == null) {
      throw Exception('Booking not found.');
    }

    final booking = Booking.fromMap(
      doc.id,
      doc.data()!,
    );

    _validateTenant(booking, tenantId);

    if (booking.status != BookingStatus.active) {
      throw Exception(
        'This booking is not active.',
      );
    }

    await reference.update({
      'status': 'return_pending',
      'updatedAt': FieldValue.serverTimestamp(),
      'lastActionBy': _auth.currentUser!.uid,
      'lastActionByRole': 'admin',
    });
  }

  Future<void> markReturnCompletedForAdmin({
    required String tenantId,
    required String bookingId,
  }) async {
    await _requireTenantAdmin(
      tenantId: tenantId,
    );

    final reference =
        _bookings(tenantId).doc(bookingId);

    final doc = await reference.get();

    if (!doc.exists || doc.data() == null) {
      throw Exception('Booking not found.');
    }

    final booking = Booking.fromMap(
      doc.id,
      doc.data()!,
    );

    _validateTenant(booking, tenantId);

    if (booking.status != BookingStatus.returnPending &&
        booking.status != BookingStatus.active) {
      throw Exception(
        'This booking is not ready for return completion.',
      );
    }

    await reference.update({
      'status': 'completed',
      'actualReturnDateTime':
          FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastActionBy': _auth.currentUser!.uid,
      'lastActionByRole': 'admin',
    });
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _statusToString(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return 'pending';
      case BookingStatus.confirmed:
        return 'confirmed';
      case BookingStatus.pickupPending:
        return 'pickup_pending';
      case BookingStatus.active:
        return 'active';
      case BookingStatus.returnPending:
        return 'return_pending';
      case BookingStatus.completed:
        return 'completed';
      case BookingStatus.cancelled:
        return 'cancelled';
      case BookingStatus.rejected:
        return 'rejected';
      case BookingStatus.noShow:
        return 'no_show';
    }
  }

  int _toInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

}

class _AvailabilityRange {
  final DateTime start;
  final DateTime end;

  const _AvailabilityRange({
    required this.start,
    required this.end,
  });
}
