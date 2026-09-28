import 'package:flutter/material.dart';

/// Structured booking information extracted from the customer's
/// conversation with the AI assistant.
class AIBookingDetails {
  final DateTime? pickupDate;
  final TimeOfDay? pickupTime;

  final DateTime? returnDate;
  final TimeOfDay? returnTime;

  final String? branchId;
  final String? carId;

  final String? carType;
  final String? transmission;
  final String? fuel;

  final int? seats;

  final String? customerName;

  const AIBookingDetails({
    this.pickupDate,
    this.pickupTime,
    this.returnDate,
    this.returnTime,
    this.branchId,
    this.carId,
    this.carType,
    this.transmission,
    this.fuel,
    this.seats,
    this.customerName,
  });

  bool get hasPickupDate => pickupDate != null;

  bool get hasPickupTime => pickupTime != null;

  bool get hasReturnDate => returnDate != null;

  bool get hasReturnTime => returnTime != null;

  bool get hasPickupDateTime =>
      pickupDate != null && pickupTime != null;

  bool get hasReturnDateTime =>
      returnDate != null && returnTime != null;

  bool get hasRentalPeriod =>
      hasPickupDateTime && hasReturnDateTime;

  bool get hasCarPreference =>
      carId != null ||
      carType != null ||
      transmission != null ||
      fuel != null ||
      seats != null;

  AIBookingDetails copyWith({
    DateTime? pickupDate,
    TimeOfDay? pickupTime,
    DateTime? returnDate,
    TimeOfDay? returnTime,
    String? branchId,
    String? carId,
    String? carType,
    String? transmission,
    String? fuel,
    int? seats,
    String? customerName,
  }) {
    return AIBookingDetails(
      pickupDate: pickupDate ?? this.pickupDate,
      pickupTime: pickupTime ?? this.pickupTime,
      returnDate: returnDate ?? this.returnDate,
      returnTime: returnTime ?? this.returnTime,
      branchId: branchId ?? this.branchId,
      carId: carId ?? this.carId,
      carType: carType ?? this.carType,
      transmission: transmission ?? this.transmission,
      fuel: fuel ?? this.fuel,
      seats: seats ?? this.seats,
      customerName: customerName ?? this.customerName,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'pickupDate': pickupDate?.toIso8601String(),
      'pickupTime': pickupTime == null
          ? null
          : {
              'hour': pickupTime!.hour,
              'minute': pickupTime!.minute,
            },
      'returnDate': returnDate?.toIso8601String(),
      'returnTime': returnTime == null
          ? null
          : {
              'hour': returnTime!.hour,
              'minute': returnTime!.minute,
            },
      'branchId': branchId,
      'carId': carId,
      'carType': carType,
      'transmission': transmission,
      'fuel': fuel,
      'seats': seats,
      'customerName': customerName,
    };
  }

  factory AIBookingDetails.fromMap(
    Map<String, dynamic> map,
  ) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;

      if (value is DateTime) {
        return value;
      }

      final parsed = DateTime.tryParse(value.toString());

      if (parsed == null) return null;

      return DateTime(
        parsed.year,
        parsed.month,
        parsed.day,
      );
    }

    TimeOfDay? parseTime(dynamic value) {
      if (value == null) return null;

      if (value is Map) {
        final hour = int.tryParse(
          value['hour']?.toString() ?? '',
        );

        final minute = int.tryParse(
          value['minute']?.toString() ?? '',
        );

        if (hour != null &&
            minute != null &&
            hour >= 0 &&
            hour <= 23 &&
            minute >= 0 &&
            minute <= 59) {
          return TimeOfDay(
            hour: hour,
            minute: minute,
          );
        }
      }

      final text = value.toString().trim();

      final match = RegExp(
        r'^(\d{1,2}):(\d{2})$',
      ).firstMatch(text);

      if (match != null) {
        final hour = int.tryParse(match.group(1)!);
        final minute = int.tryParse(match.group(2)!);

        if (hour != null &&
            minute != null &&
            hour >= 0 &&
            hour <= 23 &&
            minute >= 0 &&
            minute <= 59) {
          return TimeOfDay(
            hour: hour,
            minute: minute,
          );
        }
      }

      return null;
    }

    return AIBookingDetails(
      pickupDate: parseDate(map['pickupDate']),
      pickupTime: parseTime(map['pickupTime']),
      returnDate: parseDate(map['returnDate']),
      returnTime: parseTime(map['returnTime']),
      branchId: map['branchId']?.toString(),
      carId: map['carId']?.toString(),
      carType: map['carType']?.toString(),
      transmission: map['transmission']?.toString(),
      fuel: map['fuel']?.toString(),
      seats: map['seats'] is int
          ? map['seats'] as int
          : int.tryParse(
              map['seats']?.toString() ?? '',
            ),
      customerName: map['customerName']?.toString(),
    );
  }

  @override
  String toString() {
    return 'AIBookingDetails('
        'pickupDate: $pickupDate, '
        'pickupTime: $pickupTime, '
        'returnDate: $returnDate, '
        'returnTime: $returnTime, '
        'branchId: $branchId, '
        'carId: $carId, '
        'carType: $carType, '
        'transmission: $transmission, '
        'fuel: $fuel, '
        'seats: $seats'
        ')';
  }
}

/// Parses structured booking information returned by the AI.
///
/// Important:
/// This service does NOT guess dates or invent booking information.
/// The AI/function should provide structured values, and this service
/// validates/converts them into Flutter types.
class AIBookingParserService {
  AIBookingParserService._();

  static final AIBookingParserService instance =
      AIBookingParserService._();

  /// Parses the `bookingState` returned by the AI function.
  AIBookingDetails parseBookingState(
    dynamic bookingState,
  ) {
    if (bookingState == null) {
      return const AIBookingDetails();
    }

    if (bookingState is! Map) {
      return const AIBookingDetails();
    }

    return AIBookingDetails.fromMap(
      Map<String, dynamic>.from(bookingState),
    );
  }

  /// Determines which important booking information is still missing.
  List<String> getMissingFields(
    AIBookingDetails booking,
  ) {
    final missing = <String>[];

    if (booking.pickupDate == null) {
      missing.add('pickupDate');
    }

    if (booking.pickupTime == null) {
      missing.add('pickupTime');
    }

    if (booking.returnDate == null) {
      missing.add('returnDate');
    }

    if (booking.returnTime == null) {
      missing.add('returnTime');
    }

    return missing;
  }

  /// Returns true when the minimum booking information is available
  /// for an availability search.
  bool canCheckAvailability(
    AIBookingDetails booking,
  ) {
    return booking.hasRentalPeriod;
  }

  /// Creates a human-readable summary for the UI.
  String createSummary(
    AIBookingDetails booking,
  ) {
    final parts = <String>[];

    if (booking.pickupDate != null) {
      parts.add(
        'Pickup: ${_formatDate(booking.pickupDate!)}',
      );
    }

    if (booking.pickupTime != null) {
      parts.add(
        'Pickup time: ${_formatTime(booking.pickupTime!)}',
      );
    }

    if (booking.returnDate != null) {
      parts.add(
        'Return: ${_formatDate(booking.returnDate!)}',
      );
    }

    if (booking.returnTime != null) {
      parts.add(
        'Return time: ${_formatTime(booking.returnTime!)}',
      );
    }

    if (booking.branchId != null &&
        booking.branchId!.trim().isNotEmpty) {
      parts.add(
        'Branch: ${booking.branchId}',
      );
    }

    if (booking.carType != null &&
        booking.carType!.trim().isNotEmpty) {
      parts.add(
        'Type: ${booking.carType}',
      );
    }

    if (booking.transmission != null &&
        booking.transmission!.trim().isNotEmpty) {
      parts.add(
        'Transmission: ${booking.transmission}',
      );
    }

    if (booking.seats != null) {
      parts.add(
        'Seats: ${booking.seats}',
      );
    }

    return parts.join(' • ');
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day/$month/$year';
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0
        ? 12
        : time.hourOfPeriod;

    final minute =
        time.minute.toString().padLeft(2, '0');

    final period =
        time.period == DayPeriod.am ? 'AM' : 'PM';

    return '$hour:$minute $period';
  }
}