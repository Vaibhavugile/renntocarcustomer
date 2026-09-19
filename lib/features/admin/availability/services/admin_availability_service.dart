import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/config/app_config.dart';
import '../../../cars/models/car.dart';

/// Tenant-scoped availability data layer.
///
/// Availability is based on:
/// 1. Vehicle operational state.
/// 2. Active vehicle blocks in `vehicleBlocks`.
/// 3. Blocking bookings in `bookings`.
///
/// IMPORTANT:
/// - Hourly rentals use the exact pickup/return timestamps.
/// - Daily rentals reserve every selected calendar day and end at
///   23:59:59.999 on the selected return date.
/// - Weekend rentals use the same whole-calendar-day availability rule.
/// - Minimum billable hours/days belong to pricing, NOT availability.
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

  String _tenantId(String? tenantId) {
    final id = (tenantId ?? AppConfig.tenant.tenantId).trim();
    if (id.isEmpty) {
      throw Exception('Tenant configuration is missing.');
    }
    return id;
  }

  /// Loads all active vehicles for a tenant.
  Future<List<Car>> getCars({
    String? tenantId,
  }) async {
    final id = _tenantId(tenantId);

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

  /// Loads bookings that can reserve a vehicle and overlap the supplied
  /// calendar/time range.
  Future<List<AvailabilityBooking>> getBookingsForRange({
    required DateTime rangeStart,
    required DateTime rangeEnd,
    String? tenantId,
  }) async {
    if (!rangeEnd.isAfter(rangeStart)) {
      throw Exception('Booking availability range is invalid.');
    }

    final id = _tenantId(tenantId);

    // pickupDateTime < rangeEnd ensures bookings that started before the
    // requested window can still be considered.
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
      if (!returnTime.isAfter(pickup)) continue;

      // Expired pending bookings no longer hold the vehicle.
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

  /// Loads active vehicle blocks overlapping the supplied range.
  Future<List<AvailabilityBlock>> getBlocksForRange({
    required DateTime rangeStart,
    required DateTime rangeEnd,
    String? tenantId,
  }) async {
    if (!rangeEnd.isAfter(rangeStart)) {
      throw Exception('Vehicle block availability range is invalid.');
    }

    final id = _tenantId(tenantId);

    final snapshot = await _blocks(id)
        .where('status', isEqualTo: 'active')
        .get();

    final results = <AvailabilityBlock>[];

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final start = _dateTime(data['startDateTime']);
      final end = _dateTime(data['endDateTime']);

      if (start == null || end == null || !end.isAfter(start)) continue;
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

  /// Loads the availability snapshot for a calendar month.
  Future<AdminAvailabilitySnapshot> getMonthAvailability({
    required DateTime month,
    String? tenantId,
  }) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);

    final snapshot = await getAvailabilityForRange(
      rangeStart: start,
      rangeEnd: end,
      tenantId: tenantId,
    );

    return AdminAvailabilitySnapshot(
      month: start,
      cars: snapshot.cars,
      bookings: snapshot.bookings,
      blocks: snapshot.blocks,
    );
  }

  /// Loads bookings, blocks and vehicles for the COMPLETE requested range.
  ///
  /// This method intentionally does not apply pricing minimums or convert
  /// daily/weekend ranges. Pass the operational range you want to inspect.
  Future<AdminAvailabilitySnapshot> getAvailabilityForRange({
    required DateTime rangeStart,
    required DateTime rangeEnd,
    String? tenantId,
  }) async {
    if (!rangeEnd.isAfter(rangeStart)) {
      throw Exception('Availability range is invalid.');
    }

    final id = _tenantId(tenantId);
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
      month: rangeStart,
      cars: cars,
      bookings: results[0] as List<AvailabilityBooking>,
      blocks: results[1] as List<AvailabilityBlock>,
    );
  }

  /// Returns the operational range used for vehicle availability.
  ///
  /// Hourly:
  ///   pickup 10:00 -> return 15:00
  ///   remains exactly 10:00 -> 15:00.
  ///
  /// Daily / weekend:
  ///   pickup Sep 18 -> return Sep 20
  ///   becomes Sep 18 00:00:00 -> Sep 20 23:59:59.999.
  ///
  /// `rentalType` accepts `hourly`, `daily`, or `weekend`.
  ({DateTime start, DateTime end}) normalizeRentalRange({
    required DateTime pickupDateTime,
    required DateTime returnDateTime,
    String rentalType = 'daily',
  }) {
    if (!returnDateTime.isAfter(pickupDateTime)) {
      throw Exception('Return date/time must be after pickup date/time.');
    }

    final type = rentalType.trim().toLowerCase();

    switch (type) {
      case 'hourly':
        return (
          start: pickupDateTime,
          end: returnDateTime,
        );

      case 'daily':
      case 'weekend':
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

        if (!end.isAfter(start)) {
          throw Exception('Rental availability range is invalid.');
        }

        return (start: start, end: end);

      default:
        throw Exception(
          'Unsupported rental type "$rentalType". '
          'Expected hourly, daily, or weekend.',
        );
    }
  }

  /// Checks whether a car is available for a rental using the correct
  /// operational availability semantics for the rental type.
  Future<bool> isCarAvailableForRental({
    required Car car,
    required DateTime pickupDateTime,
    required DateTime returnDateTime,
    String rentalType = 'daily',
    String? tenantId,
  }) async {
    final range = normalizeRentalRange(
      pickupDateTime: pickupDateTime,
      returnDateTime: returnDateTime,
      rentalType: rentalType,
    );

    final snapshot = await getAvailabilityForRange(
      rangeStart: range.start,
      rangeEnd: range.end,
      tenantId: tenantId,
    );

    return isCarAvailableForRange(
      car: car,
      start: range.start,
      end: range.end,
      bookings: snapshot.bookings,
      blocks: snapshot.blocks,
    );
  }

  /// Returns vehicles available for the COMPLETE rental range.
  Future<List<Car>> getAvailableCarsForRental({
    required DateTime pickupDateTime,
    required DateTime returnDateTime,
    String rentalType = 'daily',
    String? tenantId,
  }) async {
    final range = normalizeRentalRange(
      pickupDateTime: pickupDateTime,
      returnDateTime: returnDateTime,
      rentalType: rentalType,
    );

    return getAvailableCarsForRange(
      rangeStart: range.start,
      rangeEnd: range.end,
      tenantId: tenantId,
    );
  }

  /// Returns vehicles available for an already-normalized operational range.
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

  /// Pure in-memory availability check.
  bool isCarAvailableForRange({
    required Car car,
    required DateTime start,
    required DateTime end,
    required List<AvailabilityBooking> bookings,
    required List<AvailabilityBlock> blocks,
  }) {
    if (!end.isAfter(start)) return false;
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

  /// Returns booking conflicts for a vehicle.
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

  /// Returns vehicle-block conflicts for a vehicle.
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

  /// Returns all conflicts (bookings + blocks) for one vehicle.
  List<AvailabilityConflict> conflictsForCarCombined({
    required String carId,
    required DateTime start,
    required DateTime end,
    required List<AvailabilityBooking> bookings,
    required List<AvailabilityBlock> blocks,
  }) {
    final conflicts = <AvailabilityConflict>[];

    for (final booking in conflictsForCar(
      carId: carId,
      start: start,
      end: end,
      bookings: bookings,
    )) {
      conflicts.add(AvailabilityConflict.booking(booking));
    }

    for (final block in blocksForCar(
      carId: carId,
      start: start,
      end: end,
      blocks: blocks,
    )) {
      conflicts.add(AvailabilityConflict.block(block));
    }

    conflicts.sort(
      (a, b) => a.startDateTime.compareTo(b.startDateTime),
    );

    return conflicts;
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

  /// Returns bookings belonging to one vehicle.
  List<AvailabilityBooking> bookingsForCar(String carId) {
    return bookings.where((booking) => booking.carId == carId).toList();
  }

  /// Returns blocks belonging to one vehicle.
  List<AvailabilityBlock> blocksForCar(String carId) {
    return blocks.where((block) => block.carId == carId).toList();
  }

  bool isCarAvailable({
    required Car car,
    required DateTime start,
    required DateTime end,
  }) {
    return AdminAvailabilityService.instance.isCarAvailableForRange(
      car: car,
      start: start,
      end: end,
      bookings: bookings,
      blocks: blocks,
    );
  }
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

  Duration get duration => returnDateTime.difference(pickupDateTime);

  bool get isPending => status == 'pending';

  bool get isConfirmed =>
      status == 'confirmed' ||
      status == 'pickup_pending' ||
      status == 'pickupPending';

  bool get isActive => status == 'active';

  bool get isReturnPending =>
      status == 'return_pending' ||
      status == 'returnPending';
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

  Duration get duration => endDateTime.difference(startDateTime);
}

enum AvailabilityConflictType {
  booking,
  vehicleBlock,
}

class AvailabilityConflict {
  final AvailabilityConflictType type;
  final String id;
  final String title;
  final String status;
  final DateTime startDateTime;
  final DateTime endDateTime;

  const AvailabilityConflict._({
    required this.type,
    required this.id,
    required this.title,
    required this.status,
    required this.startDateTime,
    required this.endDateTime,
  });

  factory AvailabilityConflict.booking(AvailabilityBooking booking) {
    return AvailabilityConflict._(
      type: AvailabilityConflictType.booking,
      id: booking.id,
      title: booking.customerName,
      status: booking.status,
      startDateTime: booking.pickupDateTime,
      endDateTime: booking.returnDateTime,
    );
  }

  factory AvailabilityConflict.block(AvailabilityBlock block) {
    return AvailabilityConflict._(
      type: AvailabilityConflictType.vehicleBlock,
      id: block.id,
      title: block.title,
      status: block.type,
      startDateTime: block.startDateTime,
      endDateTime: block.endDateTime,
    );
  }

  bool get isBooking => type == AvailabilityConflictType.booking;
  bool get isVehicleBlock => type == AvailabilityConflictType.vehicleBlock;
}
