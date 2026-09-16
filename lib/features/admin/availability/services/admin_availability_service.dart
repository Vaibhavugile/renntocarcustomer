import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/config/app_config.dart';
import '../../../cars/models/car.dart';

/// Tenant-scoped availability data layer for the admin availability screens.
///
/// Availability is calculated from:
/// 1. Car operational state.
/// 2. Active vehicle blocks in `vehicleBlocks`.
/// 3. Blocking bookings in `bookings`.
///
/// Booking statuses that reserve the vehicle:
/// pending, confirmed, pickup_pending, active, return_pending.
/// Expired pending bookings are excluded from the availability snapshot.
class AdminAvailabilityService {
  AdminAvailabilityService._();

  static final AdminAvailabilityService instance =
      AdminAvailabilityService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _cars(String tenantId) {
    return _firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('cars');
  }

  CollectionReference<Map<String, dynamic>> _bookings(String tenantId) {
    return _firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('bookings');
  }

  CollectionReference<Map<String, dynamic>> _blocks(String tenantId) {
    return _firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('vehicleBlocks');
  }

  static const Set<String> _blockingStatuses = {
    'pending',
    'confirmed',
    'pickup_pending',
    'pickupPending',
    'active',
    'return_pending',
    'returnPending',
  };

  Future<List<Car>> getCars({
    String? tenantId,
  }) async {
    final id = (tenantId ?? AppConfig.tenant.tenantId).trim();
    if (id.isEmpty) {
      throw Exception('Tenant configuration is missing.');
    }

    final snapshot = await _cars(id)
        .where('isActive', isEqualTo: true)
        .get();

    final cars = snapshot.docs
        .map((doc) => Car.fromMap(doc.id, doc.data()))
        .toList();

    cars.sort((a, b) {
      final order = a.sortOrder.compareTo(b.sortOrder);
      if (order != 0) return order;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return cars;
  }

  /// Loads all potentially relevant bookings for a calendar window.
  ///
  /// We query pickupDateTime < rangeEnd and locally check returnDateTime,
  /// so bookings that began before the month/day still appear.
  Future<List<AvailabilityBooking>> getBookingsForRange({
    required DateTime rangeStart,
    required DateTime rangeEnd,
    String? tenantId,
  }) async {
    if (!rangeEnd.isAfter(rangeStart)) {
      throw Exception('Booking availability range is invalid.');
    }

    final id = (tenantId ?? AppConfig.tenant.tenantId).trim();
    if (id.isEmpty) {
      throw Exception('Tenant configuration is missing.');
    }

    final snapshot = await _bookings(id)
        .where(
          'pickupDateTime',
          isLessThan: Timestamp.fromDate(rangeEnd),
        )
        .get();

    final now = DateTime.now();
    final results = <AvailabilityBooking>[];

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final status = data['status']?.toString().trim() ?? '';
      if (!_blockingStatuses.contains(status)) continue;

      final pickup = _dateTime(data['pickupDateTime']);
      final returnTime = _dateTime(data['returnDateTime']);

      if (pickup == null || returnTime == null) continue;

      // Expired pending bookings no longer hold the car.
      if (status == 'pending') {
        final expiresAt = _dateTime(data['expiresAt']);
        if (expiresAt != null && !expiresAt.isAfter(now)) {
          continue;
        }
      }

      if (!_overlaps(pickup, returnTime, rangeStart, rangeEnd)) {
        continue;
      }

      results.add(
        AvailabilityBooking(
          id: doc.id,
          carId: data['carId']?.toString() ?? '',
          customerName: data['customerName']?.toString() ?? 'Customer',
          customerPhone: data['customerPhone']?.toString() ?? '',
          status: status,
          pickupDateTime: pickup,
          returnDateTime: returnTime,
          pickupBranchId: data['pickupBranchId']?.toString() ??
              data['branchId']?.toString() ??
              '',
          returnBranchId: data['returnBranchId']?.toString() ?? '',
          totalAmount: _double(data['totalAmount']),
        ),
      );
    }

    results.sort(
      (a, b) => a.pickupDateTime.compareTo(b.pickupDateTime),
    );

    return results;
  }

  Future<List<AvailabilityBlock>> getBlocksForRange({
    required DateTime rangeStart,
    required DateTime rangeEnd,
    String? tenantId,
  }) async {
    if (!rangeEnd.isAfter(rangeStart)) {
      throw Exception('Vehicle block availability range is invalid.');
    }

    final id = (tenantId ?? AppConfig.tenant.tenantId).trim();
    if (id.isEmpty) {
      throw Exception('Tenant configuration is missing.');
    }

    final snapshot = await _blocks(id)
        .where('status', isEqualTo: 'active')
        .get();

    final results = <AvailabilityBlock>[];

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final start = _dateTime(data['startDateTime']);
      final end = _dateTime(data['endDateTime']);

      if (start == null || end == null) continue;
      if (!_overlaps(start, end, rangeStart, rangeEnd)) continue;

      results.add(
        AvailabilityBlock(
          id: doc.id,
          carId: data['carId']?.toString() ?? '',
          title: data['title']?.toString() ??
              data['reason']?.toString() ??
              'Vehicle Block',
          reason: data['reason']?.toString() ?? '',
          startDateTime: start,
          endDateTime: end,
          type: data['type']?.toString() ?? 'maintenance',
        ),
      );
    }

    results.sort(
      (a, b) => a.startDateTime.compareTo(b.startDateTime),
    );

    return results;
  }

  Future<AdminAvailabilitySnapshot> getMonthAvailability({
    required DateTime month,
    String? tenantId,
  }) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);

    final cars = await getCars(tenantId: tenantId);

    final results = await Future.wait([
      getBookingsForRange(
        rangeStart: start,
        rangeEnd: end,
        tenantId: tenantId,
      ),
      getBlocksForRange(
        rangeStart: start,
        rangeEnd: end,
        tenantId: tenantId,
      ),
    ]);

    return AdminAvailabilitySnapshot(
      month: start,
      cars: cars,
      bookings: results[0] as List<AvailabilityBooking>,
      blocks: results[1] as List<AvailabilityBlock>,
    );
  }

  /// Loads availability for the COMPLETE requested rental range.
  ///
  /// Example:
  ///   28 Sep 2026 10:00 AM -> 03 Oct 2026 10:00 AM
  ///
  /// Bookings and vehicle blocks from BOTH months are included because the
  /// underlying range queries use the complete requested start/end range.
  Future<AdminAvailabilitySnapshot> getAvailabilityForRange({
    required DateTime rangeStart,
    required DateTime rangeEnd,
    String? tenantId,
  }) async {
    if (!rangeEnd.isAfter(rangeStart)) {
      throw Exception('Availability range is invalid.');
    }

    final id = (tenantId ?? AppConfig.tenant.tenantId).trim();
    if (id.isEmpty) {
      throw Exception('Tenant configuration is missing.');
    }

    final cars = await getCars(tenantId: id);

    final results = await Future.wait([
      getBookingsForRange(
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        tenantId: id,
      ),
      getBlocksForRange(
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        tenantId: id,
      ),
    ]);

    return AdminAvailabilitySnapshot(
      // Kept as rangeStart for compatibility with the existing snapshot model.
      month: rangeStart,
      cars: cars,
      bookings: results[0] as List<AvailabilityBooking>,
      blocks: results[1] as List<AvailabilityBlock>,
    );
  }

  /// Returns vehicles that are available for the COMPLETE requested rental
  /// period, not merely available on the pickup date.
  Future<List<Car>> getAvailableCarsForRange({
    required DateTime rangeStart,
    required DateTime rangeEnd,
    String? tenantId,
  }) async {
    final snapshot = await getAvailabilityForRange(
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      tenantId: tenantId,
    );

    return snapshot.cars.where((car) {
      return isCarAvailableForRange(
        car: car,
        start: rangeStart,
        end: rangeEnd,
        bookings: snapshot.bookings,
        blocks: snapshot.blocks,
      );
    }).toList();
  }

  bool isCarAvailableForRange({
    required Car car,
    required DateTime start,
    required DateTime end,
    required List<AvailabilityBooking> bookings,
    required List<AvailabilityBlock> blocks,
  }) {
    if (!car.isActive || !car.isAvailable) return false;

    final status = car.status.trim().toLowerCase();
    if (status == 'inactive' || status == 'unavailable') return false;

    for (final block in blocks) {
      if (block.carId != car.id) continue;

      if (_overlaps(
        block.startDateTime,
        block.endDateTime,
        start,
        end,
      )) {
        return false;
      }
    }

    for (final booking in bookings) {
      if (booking.carId != car.id) continue;

      if (_overlaps(
        booking.pickupDateTime,
        booking.returnDateTime,
        start,
        end,
      )) {
        return false;
      }
    }

    return true;
  }

  List<AvailabilityBooking> conflictsForCar({
    required String carId,
    required DateTime start,
    required DateTime end,
    required List<AvailabilityBooking> bookings,
  }) {
    return bookings
        .where(
          (booking) =>
              booking.carId == carId &&
              _overlaps(
                booking.pickupDateTime,
                booking.returnDateTime,
                start,
                end,
              ),
        )
        .toList();
  }

  List<AvailabilityBlock> blocksForCar({
    required String carId,
    required DateTime start,
    required DateTime end,
    required List<AvailabilityBlock> blocks,
  }) {
    return blocks
        .where(
          (block) =>
              block.carId == carId &&
              _overlaps(
                block.startDateTime,
                block.endDateTime,
                start,
                end,
              ),
        )
        .toList();
  }

  bool _overlaps(
    DateTime existingStart,
    DateTime existingEnd,
    DateTime requestedStart,
    DateTime requestedEnd,
  ) {
    return existingStart.isBefore(requestedEnd) &&
        existingEnd.isAfter(requestedStart);
  }

  DateTime? _dateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;

    try {
      return value.toDate();
    } catch (_) {}

    return DateTime.tryParse(value.toString());
  }

  double _double(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class AdminAvailabilitySnapshot {
  final DateTime month;
  final List<Car> cars;
  final List<AvailabilityBooking> bookings;
  final List<AvailabilityBlock> blocks;

  const AdminAvailabilitySnapshot({
    required this.month,
    required this.cars,
    required this.bookings,
    required this.blocks,
  });
}

class AvailabilityBooking {
  final String id;
  final String carId;
  final String customerName;
  final String customerPhone;
  final String status;
  final DateTime pickupDateTime;
  final DateTime returnDateTime;
  final String pickupBranchId;
  final String returnBranchId;
  final double totalAmount;

  const AvailabilityBooking({
    required this.id,
    required this.carId,
    required this.customerName,
    required this.customerPhone,
    required this.status,
    required this.pickupDateTime,
    required this.returnDateTime,
    required this.pickupBranchId,
    required this.returnBranchId,
    required this.totalAmount,
  });
}

class AvailabilityBlock {
  final String id;
  final String carId;
  final String title;
  final String reason;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final String type;

  const AvailabilityBlock({
    required this.id,
    required this.carId,
    required this.title,
    required this.reason,
    required this.startDateTime,
    required this.endDateTime,
    required this.type,
  });
}
