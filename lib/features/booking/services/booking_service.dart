import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/booking.dart';

/// Firebase booking data layer.
///
/// IMPORTANT:
/// - Every booking is tenant-scoped.
/// - Customer reads are restricted to the authenticated Firebase UID.
/// - Booking stores historical car/branch/customer/pricing snapshots.
/// - Availability checks consider vehicle status, blocks and blocking bookings.
///
/// NOTE:
/// The Flutter client check is an important safety layer, but final production
/// double-booking prevention should also be enforced by the Node.js/MySQL
/// backend with a server-side transaction/locking strategy.
class BookingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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

  CollectionReference<Map<String, dynamic>> _blocks(
    String tenantId,
  ) =>
      _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('vehicleBlocks');

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

  Future<bool> isCarAvailable({
    required String tenantId,
    required String carId,
    required DateTime pickupDateTime,
    required DateTime returnDateTime,
    String? excludeBookingId,
  }) async {
    _validateDateRange(pickupDateTime, returnDateTime);

    final carDoc = await _cars(tenantId).doc(carId).get();

    if (!carDoc.exists || carDoc.data() == null) {
      return false;
    }

    final car = carDoc.data()!;

    final isActive = car['isActive'] != false;
    final isAvailable = car['isAvailable'] != false;

    final status =
        car['status']?.toString().toLowerCase() ?? 'active';

    if (!isActive || !isAvailable || status != 'active') {
      return false;
    }

    // Scheduled maintenance / manual blocks.
    final blocks = await _blocks(tenantId)
        .where('carId', isEqualTo: carId)
        .where('status', isEqualTo: 'active')
        .get();

    for (final doc in blocks.docs) {
      final data = doc.data();

      final start = _dateTime(data['startDateTime']);
      final end = _dateTime(data['endDateTime']);

      if (start == null || end == null) continue;

      if (_timesOverlap(
        pickupDateTime,
        returnDateTime,
        start,
        end,
      )) {
        return false;
      }
    }

    // Existing bookings for this vehicle.
    final existing = await _bookings(tenantId)
        .where('carId', isEqualTo: carId)
        .get();

    final now = DateTime.now();

    for (final doc in existing.docs) {
      final booking = Booking.fromMap(
        doc.id,
        doc.data(),
      );

      if (excludeBookingId != null &&
          booking.bookingId == excludeBookingId) {
        continue;
      }

      if (!booking.isBlockingAvailability) {
        continue;
      }

      // Expired pending bookings no longer hold the vehicle.
      if (booking.status == BookingStatus.pending) {
        final expiry = booking.expiresAt;
        if (expiry != null && !expiry.isAfter(now)) {
          continue;
        }
      }

      if (_timesOverlap(
        pickupDateTime,
        returnDateTime,
        booking.pickupDateTime,
        booking.returnDateTime,
      )) {
        return false;
      }
    }

    return true;
  }

  bool _timesOverlap(
    DateTime requestedStart,
    DateTime requestedEnd,
    DateTime existingStart,
    DateTime existingEnd,
  ) {
    return existingStart.isBefore(requestedEnd) &&
        existingEnd.isAfter(requestedStart);
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

    if (booking.carId.trim().isEmpty) {
      throw Exception('Car is required.');
    }

    if (booking.pickupBranchId.trim().isEmpty) {
      throw Exception('Pickup branch is required.');
    }

    // Enrich the booking with immutable snapshots before saving.
    final enriched = await _buildHistoricalSnapshot(
      tenantId: tenantId,
      booking: booking,
    );

    final available = await isCarAvailable(
      tenantId: tenantId,
      carId: enriched.carId,
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
    data['customerId'] = user.uid;
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

  /// Copies current car/branch/customer information into the booking.
  ///
  /// This prevents historical bookings from changing when an admin edits
  /// the current car, branch or customer profile later.
  Future<Booking> _buildHistoricalSnapshot({
    required String tenantId,
    required Booking booking,
  }) async {
    final user = _requireUser();

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

    // The customer snapshot should always represent the authenticated user.
    var customerName = booking.customerName;
    var customerPhone = booking.customerPhone;
    var customerEmail = booking.customerEmail;

    final customerDoc = await _firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('customers')
        .doc(user.uid)
        .get();

    if (customerDoc.exists && customerDoc.data() != null) {
      final customerData = customerDoc.data()!;

      if (customerName.trim().isEmpty) {
        customerName =
            customerData['fullName']?.toString() ?? '';
      }

      if (customerPhone.trim().isEmpty) {
        customerPhone =
            customerData['phone']?.toString() ??
                user.phoneNumber ??
                '';
      }

      if (customerEmail.trim().isEmpty) {
        customerEmail =
            customerData['email']?.toString() ??
                user.email ??
                '';
      }
    }

    if (customerPhone.trim().isEmpty) {
      customerPhone = user.phoneNumber ?? '';
    }

    if (customerEmail.trim().isEmpty) {
      customerEmail = user.email ?? '';
    }

    return booking.copyWith(
      tenantId: tenantId,
      customerId: user.uid,
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
    _validateCustomer(booking, user.uid);

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
      _validateCustomer(booking, user.uid);

      bookings.add(booking);
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
        .map(
      (snapshot) {
        final bookings = <Booking>[];

        for (final doc in snapshot.docs) {
          final booking = Booking.fromMap(
            doc.id,
            doc.data(),
          );

          _validateTenant(booking, tenantId);
          _validateCustomer(
            booking,
            user.uid,
          );

          bookings.add(booking);
        }

        bookings.sort(
          (a, b) => b.pickupDateTime.compareTo(
            a.pickupDateTime,
          ),
        );

        return bookings;
      },
    );
  }

  // ============================================================
  // CALENDAR / DATE QUERIES
  // ============================================================

  Future<List<Booking>> getBookingsForMonth({
    required String tenantId,
    required DateTime month,
  }) async {
    final user = _requireUser();

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

    final snapshot = await _bookings(tenantId)
        .where(
          'customerId',
          isEqualTo: user.uid,
        )
        .get();

    final result = <Booking>[];

    for (final doc in snapshot.docs) {
      final booking = Booking.fromMap(
        doc.id,
        doc.data(),
      );

      _validateTenant(booking, tenantId);
      _validateCustomer(booking, user.uid);

      // Include bookings that overlap the month.
      if (booking.returnDateTime.isAfter(start) &&
          booking.pickupDateTime.isBefore(end)) {
        result.add(booking);
      }
    }

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

  DateTime? _dateTime(dynamic value) {
    if (value == null) return null;

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
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
