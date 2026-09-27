import 'package:cloud_firestore/cloud_firestore.dart';

/// ============================================================
/// AI BOOKING STATE SERVICE
/// ============================================================
///
/// This state is designed around the actual Rentocar Firestore
/// structure.
///
/// IMPORTANT:
/// The AI does NOT decide whether a car is actually available
/// or what the final price is.
///
/// The AI collects the customer's requirements.
/// Backend services then verify:
///
/// 1. Branch
/// 2. Car
/// 3. Booking date/time
/// 4. Existing bookings
/// 5. Pricing profile
/// 6. Pricing package
/// 7. Special dates
/// 8. Extra KM
/// 9. Extra hours
/// 10. Security deposit
///
/// ============================================================

class AIBookingStateService {
  AIBookingStateService._();

  static final AIBookingStateService instance =
      AIBookingStateService._();

  // ============================================================
  // CREATE EMPTY STATE
  // ============================================================

  AIBookingState createEmpty() {
    return AIBookingState();
  }

  // ============================================================
  // FROM MAP
  // ============================================================

  AIBookingState fromMap(
    Map<String, dynamic>? data,
  ) {
    if (data == null) {
      return AIBookingState();
    }

    return AIBookingState.fromMap(data);
  }

  // ============================================================
  // MERGE AI UPDATES
  // ============================================================

  AIBookingState merge(
    AIBookingState current,
    Map<String, dynamic> updates,
  ) {
    final map = current.toMap();

    for (final entry in updates.entries) {
      final key = entry.key;
      final value = entry.value;

      if (value == null) {
        continue;
      }

      if (value is String &&
          value.trim().isEmpty) {
        continue;
      }

      map[key] = value;
    }

    return AIBookingState.fromMap(map);
  }

  // ============================================================
  // UPDATE SINGLE FIELD
  // ============================================================

  AIBookingState updateField({
    required AIBookingState current,
    required String field,
    required dynamic value,
  }) {
    return merge(
      current,
      {
        field: value,
      },
    );
  }

  // ============================================================
  // CLEAR FIELD
  // ============================================================

  AIBookingState clearField({
    required AIBookingState current,
    required String field,
  }) {
    final map = current.toMap();

    map.remove(field);

    return AIBookingState.fromMap(map);
  }

  // ============================================================
  // CLEAR STATE
  // ============================================================

  AIBookingState clear() {
    return AIBookingState();
  }

  // ============================================================
  // FIRESTORE MAP
  // ============================================================

  Map<String, dynamic> toFirestoreMap(
    AIBookingState state,
  ) {
    return state.toFirestore();
  }

  // ============================================================
  // BASIC BOOKING VALIDATION
  // ============================================================

  AIBookingValidation validate(
    AIBookingState state,
  ) {
    final missing = <String>[];

    if (_isEmpty(state.pickupDate)) {
      missing.add('pickupDate');
    }

    if (_isEmpty(state.pickupTime)) {
      missing.add('pickupTime');
    }

    if (_isEmpty(state.returnDate)) {
      missing.add('returnDate');
    }

    if (_isEmpty(state.returnTime)) {
      missing.add('returnTime');
    }

    return AIBookingValidation(
      isValid: missing.isEmpty,
      missingFields: missing,
    );
  }

  // ============================================================
  // CAR SEARCH VALIDATION
  // ============================================================

  AIBookingValidation validateForCarSearch(
    AIBookingState state,
  ) {
    final missing = <String>[];

    if (_isEmpty(state.pickupDate)) {
      missing.add('pickupDate');
    }

    if (_isEmpty(state.pickupTime)) {
      missing.add('pickupTime');
    }

    if (_isEmpty(state.returnDate)) {
      missing.add('returnDate');
    }

    if (_isEmpty(state.returnTime)) {
      missing.add('returnTime');
    }

    if (_isEmpty(state.pickupBranchId) &&
        _isEmpty(state.pickupLocation)) {
      missing.add('pickupLocation');
    }

    return AIBookingValidation(
      isValid: missing.isEmpty,
      missingFields: missing,
    );
  }

  // ============================================================
  // BOOKING CONFIRMATION VALIDATION
  // ============================================================

  AIBookingValidation validateForConfirmation(
    AIBookingState state,
  ) {
    final missing = <String>[];

    if (_isEmpty(state.pickupDate)) {
      missing.add('pickupDate');
    }

    if (_isEmpty(state.pickupTime)) {
      missing.add('pickupTime');
    }

    if (_isEmpty(state.returnDate)) {
      missing.add('returnDate');
    }

    if (_isEmpty(state.returnTime)) {
      missing.add('returnTime');
    }

    if (_isEmpty(state.pickupBranchId)) {
      missing.add('pickupBranchId');
    }

    if (_isEmpty(state.selectedCarId)) {
      missing.add('selectedCarId');
    }

    if (_isEmpty(state.selectedPackageId)) {
      missing.add('selectedPackageId');
    }

    return AIBookingValidation(
      isValid: missing.isEmpty,
      missingFields: missing,
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  bool _isEmpty(dynamic value) {
    if (value == null) {
      return true;
    }

    if (value is String) {
      return value.trim().isEmpty;
    }

    return false;
  }
}


/// ============================================================
/// AI BOOKING STATE
/// ============================================================

class AIBookingState {
  // ============================================================
  // DATE & TIME
  // ============================================================

  final String? pickupDate;

  final String? pickupTime;

  final String? returnDate;

  final String? returnTime;

  // ============================================================
  // PICKUP BRANCH
  // ============================================================

  final String? pickupBranchId;

  final String? pickupBranchName;

  // ============================================================
  // RETURN BRANCH
  // ============================================================

  final String? returnBranchId;

  final String? returnBranchName;

  // ============================================================
  // LOCATION
  // ============================================================

  final String? pickupLocation;

  final String? returnLocation;

  final double? pickupLatitude;

  final double? pickupLongitude;

  final double? returnLatitude;

  final double? returnLongitude;

  // ============================================================
  // CUSTOMER VEHICLE REQUIREMENTS
  // ============================================================

  final String? requestedCarType;

  final String? requestedTransmission;

  final String? requestedFuel;

  final int? requestedSeats;

  // ============================================================
  // SELECTED REAL CAR
  // ============================================================

  final String? selectedCarId;

  final String? selectedCarName;

  final String? selectedCarType;

  final String? selectedCarTransmission;

  final String? selectedCarFuel;

  final int? selectedCarSeats;

  final String? selectedCarImage;

  final List<String> selectedCarImages;

  final String? selectedCarRegistrationNumber;

  final int? selectedCarCurrentKm;

  final String? selectedCarStatus;

  final bool? selectedCarIsActive;

  final bool? selectedCarIsAvailable;

  final bool? selectedCarIsFeatured;

  // ============================================================
  // ACTUAL CAR BRANCH IDS
  // ============================================================

  final List<String> selectedCarBranchIds;

  // ============================================================
  // PRICING PROFILE
  // ============================================================

  final String? pricingProfileId;

  final String? pricingProfileName;

  // ============================================================
  // PRICING PACKAGE
  // ============================================================

  final String? selectedPackageId;

  final String? selectedPackageName;

  final String? selectedPackageType;

  // ============================================================
  // PACKAGE DETAILS
  // ============================================================

  final double? includedKm;

  final double? extraKmCharge;

  final double? extraHourCharge;

  final double? packagePrice;

  final int? minimumHours;

  final int? minimumDays;

  // ============================================================
  // BOOKING DURATION
  // ============================================================

  final int? durationHours;

  final int? durationDays;

  // ============================================================
  // PRICING CALCULATION
  // ============================================================

  final double? baseAmount;

  final double? packageAmount;

  final double? extraKmAmount;

  final double? extraHourAmount;

  final double? specialDateAdjustment;

  final double? weekendAdjustment;

  final double? securityDeposit;

  final double? taxes;

  final double? discount;

  final double? finalAmount;

  final String? currency;

  // ============================================================
  // CUSTOMER REQUIREMENTS
  // ============================================================

  final int? numberOfPassengers;

  final int? numberOfBags;

  final bool? selfDrive;

  final bool? deliveryRequired;

  final bool? pickupRequired;

  final String? customerNote;

  // ============================================================
  // BOOKING
  // ============================================================

  final String? bookingId;

  final String? bookingStatus;

  // ============================================================
  // CONSTRUCTOR
  // ============================================================

  AIBookingState({
    this.pickupDate,
    this.pickupTime,
    this.returnDate,
    this.returnTime,

    this.pickupBranchId,
    this.pickupBranchName,

    this.returnBranchId,
    this.returnBranchName,

    this.pickupLocation,
    this.returnLocation,

    this.pickupLatitude,
    this.pickupLongitude,
    this.returnLatitude,
    this.returnLongitude,

    this.requestedCarType,
    this.requestedTransmission,
    this.requestedFuel,
    this.requestedSeats,

    this.selectedCarId,
    this.selectedCarName,
    this.selectedCarType,
    this.selectedCarTransmission,
    this.selectedCarFuel,
    this.selectedCarSeats,
    this.selectedCarImage,
    this.selectedCarImages = const [],
    this.selectedCarRegistrationNumber,
    this.selectedCarCurrentKm,
    this.selectedCarStatus,
    this.selectedCarIsActive,
    this.selectedCarIsAvailable,
    this.selectedCarIsFeatured,

    this.selectedCarBranchIds = const [],

    this.pricingProfileId,
    this.pricingProfileName,

    this.selectedPackageId,
    this.selectedPackageName,
    this.selectedPackageType,

    this.includedKm,
    this.extraKmCharge,
    this.extraHourCharge,
    this.packagePrice,

    this.minimumHours,
    this.minimumDays,

    this.durationHours,
    this.durationDays,

    this.baseAmount,
    this.packageAmount,
    this.extraKmAmount,
    this.extraHourAmount,
    this.specialDateAdjustment,
    this.weekendAdjustment,
    this.securityDeposit,
    this.taxes,
    this.discount,
    this.finalAmount,
    this.currency,

    this.numberOfPassengers,
    this.numberOfBags,

    this.selfDrive,
    this.deliveryRequired,
    this.pickupRequired,

    this.customerNote,

    this.bookingId,
    this.bookingStatus,
  });

  // ============================================================
  // FROM MAP
  // ============================================================

  factory AIBookingState.fromMap(
    Map<String, dynamic> map,
  ) {
    return AIBookingState(
      pickupDate:
          _string(map['pickupDate']),

      pickupTime:
          _string(map['pickupTime']),

      returnDate:
          _string(map['returnDate']),

      returnTime:
          _string(map['returnTime']),

      pickupBranchId:
          _string(map['pickupBranchId']),

      pickupBranchName:
          _string(map['pickupBranchName']),

      returnBranchId:
          _string(map['returnBranchId']),

      returnBranchName:
          _string(map['returnBranchName']),

      pickupLocation:
          _string(map['pickupLocation']),

      returnLocation:
          _string(map['returnLocation']),

      pickupLatitude:
          _double(map['pickupLatitude']),

      pickupLongitude:
          _double(map['pickupLongitude']),

      returnLatitude:
          _double(map['returnLatitude']),

      returnLongitude:
          _double(map['returnLongitude']),

      // --------------------------------------------------------
      // REQUESTED VEHICLE
      // --------------------------------------------------------

      requestedCarType:
          _string(map['requestedCarType']),

      requestedTransmission:
          _string(
        map['requestedTransmission'],
      ),

      requestedFuel:
          _string(map['requestedFuel']),

      requestedSeats:
          _int(map['requestedSeats']),

      // --------------------------------------------------------
      // SELECTED CAR
      // --------------------------------------------------------

      selectedCarId:
          _string(map['selectedCarId']),

      selectedCarName:
          _string(map['selectedCarName']),

      selectedCarType:
          _string(map['selectedCarType']),

      selectedCarTransmission:
          _string(
        map['selectedCarTransmission'],
      ),

      selectedCarFuel:
          _string(map['selectedCarFuel']),

      selectedCarSeats:
          _int(map['selectedCarSeats']),

      selectedCarImage:
          _string(map['selectedCarImage']),

      selectedCarImages:
          _stringList(
        map['selectedCarImages'],
      ),

      selectedCarRegistrationNumber:
          _string(
        map['selectedCarRegistrationNumber'],
      ),

      selectedCarCurrentKm:
          _int(
        map['selectedCarCurrentKm'],
      ),

      selectedCarStatus:
          _string(
        map['selectedCarStatus'],
      ),

      selectedCarIsActive:
          _bool(
        map['selectedCarIsActive'],
      ),

      selectedCarIsAvailable:
          _bool(
        map['selectedCarIsAvailable'],
      ),

      selectedCarIsFeatured:
          _bool(
        map['selectedCarIsFeatured'],
      ),

      selectedCarBranchIds:
          _stringList(
        map['selectedCarBranchIds'],
      ),

      // --------------------------------------------------------
      // PRICING PROFILE
      // --------------------------------------------------------

      pricingProfileId:
          _string(
        map['pricingProfileId'],
      ),

      pricingProfileName:
          _string(
        map['pricingProfileName'],
      ),

      // --------------------------------------------------------
      // PACKAGE
      // --------------------------------------------------------

      selectedPackageId:
          _string(
        map['selectedPackageId'],
      ),

      selectedPackageName:
          _string(
        map['selectedPackageName'],
      ),

      selectedPackageType:
          _string(
        map['selectedPackageType'],
      ),

      includedKm:
          _double(
        map['includedKm'],
      ),

      extraKmCharge:
          _double(
        map['extraKmCharge'],
      ),

      extraHourCharge:
          _double(
        map['extraHourCharge'],
      ),

      packagePrice:
          _double(
        map['packagePrice'],
      ),

      minimumHours:
          _int(
        map['minimumHours'],
      ),

      minimumDays:
          _int(
        map['minimumDays'],
      ),

      // --------------------------------------------------------
      // DURATION
      // --------------------------------------------------------

      durationHours:
          _int(
        map['durationHours'],
      ),

      durationDays:
          _int(
        map['durationDays'],
      ),

      // --------------------------------------------------------
      // PRICING
      // --------------------------------------------------------

      baseAmount:
          _double(
        map['baseAmount'],
      ),

      packageAmount:
          _double(
        map['packageAmount'],
      ),

      extraKmAmount:
          _double(
        map['extraKmAmount'],
      ),

      extraHourAmount:
          _double(
        map['extraHourAmount'],
      ),

      specialDateAdjustment:
          _double(
        map['specialDateAdjustment'],
      ),

      weekendAdjustment:
          _double(
        map['weekendAdjustment'],
      ),

      securityDeposit:
          _double(
        map['securityDeposit'],
      ),

      taxes:
          _double(
        map['taxes'],
      ),

      discount:
          _double(
        map['discount'],
      ),

      finalAmount:
          _double(
        map['finalAmount'],
      ),

      currency:
          _string(
        map['currency'],
      ),

      // --------------------------------------------------------
      // CUSTOMER
      // --------------------------------------------------------

      numberOfPassengers:
          _int(
        map['numberOfPassengers'],
      ),

      numberOfBags:
          _int(
        map['numberOfBags'],
      ),

      selfDrive:
          _bool(
        map['selfDrive'],
      ),

      deliveryRequired:
          _bool(
        map['deliveryRequired'],
      ),

      pickupRequired:
          _bool(
        map['pickupRequired'],
      ),

      customerNote:
          _string(
        map['customerNote'],
      ),

      // --------------------------------------------------------
      // BOOKING
      // --------------------------------------------------------

      bookingId:
          _string(
        map['bookingId'],
      ),

      bookingStatus:
          _string(
        map['bookingStatus'],
      ),
    );
  }

  // ============================================================
  // TO MAP
  // ============================================================

  Map<String, dynamic> toMap() {
    return {
      // Date/time

      'pickupDate':
          pickupDate,

      'pickupTime':
          pickupTime,

      'returnDate':
          returnDate,

      'returnTime':
          returnTime,

      // Branch

      'pickupBranchId':
          pickupBranchId,

      'pickupBranchName':
          pickupBranchName,

      'returnBranchId':
          returnBranchId,

      'returnBranchName':
          returnBranchName,

      // Location

      'pickupLocation':
          pickupLocation,

      'returnLocation':
          returnLocation,

      'pickupLatitude':
          pickupLatitude,

      'pickupLongitude':
          pickupLongitude,

      'returnLatitude':
          returnLatitude,

      'returnLongitude':
          returnLongitude,

      // Requested car

      'requestedCarType':
          requestedCarType,

      'requestedTransmission':
          requestedTransmission,

      'requestedFuel':
          requestedFuel,

      'requestedSeats':
          requestedSeats,

      // Selected car

      'selectedCarId':
          selectedCarId,

      'selectedCarName':
          selectedCarName,

      'selectedCarType':
          selectedCarType,

      'selectedCarTransmission':
          selectedCarTransmission,

      'selectedCarFuel':
          selectedCarFuel,

      'selectedCarSeats':
          selectedCarSeats,

      'selectedCarImage':
          selectedCarImage,

      'selectedCarImages':
          selectedCarImages,

      'selectedCarRegistrationNumber':
          selectedCarRegistrationNumber,

      'selectedCarCurrentKm':
          selectedCarCurrentKm,

      'selectedCarStatus':
          selectedCarStatus,

      'selectedCarIsActive':
          selectedCarIsActive,

      'selectedCarIsAvailable':
          selectedCarIsAvailable,

      'selectedCarIsFeatured':
          selectedCarIsFeatured,

      'selectedCarBranchIds':
          selectedCarBranchIds,

      // Pricing profile

      'pricingProfileId':
          pricingProfileId,

      'pricingProfileName':
          pricingProfileName,

      // Package

      'selectedPackageId':
          selectedPackageId,

      'selectedPackageName':
          selectedPackageName,

      'selectedPackageType':
          selectedPackageType,

      'includedKm':
          includedKm,

      'extraKmCharge':
          extraKmCharge,

      'extraHourCharge':
          extraHourCharge,

      'packagePrice':
          packagePrice,

      'minimumHours':
          minimumHours,

      'minimumDays':
          minimumDays,

      // Duration

      'durationHours':
          durationHours,

      'durationDays':
          durationDays,

      // Pricing

      'baseAmount':
          baseAmount,

      'packageAmount':
          packageAmount,

      'extraKmAmount':
          extraKmAmount,

      'extraHourAmount':
          extraHourAmount,

      'specialDateAdjustment':
          specialDateAdjustment,

      'weekendAdjustment':
          weekendAdjustment,

      'securityDeposit':
          securityDeposit,

      'taxes':
          taxes,

      'discount':
          discount,

      'finalAmount':
          finalAmount,

      'currency':
          currency,

      // Customer

      'numberOfPassengers':
          numberOfPassengers,

      'numberOfBags':
          numberOfBags,

      'selfDrive':
          selfDrive,

      'deliveryRequired':
          deliveryRequired,

      'pickupRequired':
          pickupRequired,

      'customerNote':
          customerNote,

      // Booking

      'bookingId':
          bookingId,

      'bookingStatus':
          bookingStatus,
    };
  }

  // ============================================================
  // FIRESTORE SAFE MAP
  // ============================================================

  Map<String, dynamic> toFirestore() {
    final map = toMap();

    map.removeWhere(
      (key, value) => value == null,
    );

    return map;
  }

  // ============================================================
  // COPY WITH
  // ============================================================

  AIBookingState copyWith({
    String? pickupDate,
    String? pickupTime,
    String? returnDate,
    String? returnTime,

    String? pickupBranchId,
    String? pickupBranchName,

    String? returnBranchId,
    String? returnBranchName,

    String? pickupLocation,
    String? returnLocation,

    double? pickupLatitude,
    double? pickupLongitude,
    double? returnLatitude,
    double? returnLongitude,

    String? requestedCarType,
    String? requestedTransmission,
    String? requestedFuel,
    int? requestedSeats,

    String? selectedCarId,
    String? selectedCarName,
    String? selectedCarType,
    String? selectedCarTransmission,
    String? selectedCarFuel,
    int? selectedCarSeats,
    String? selectedCarImage,
    List<String>? selectedCarImages,
    String? selectedCarRegistrationNumber,
    int? selectedCarCurrentKm,
    String? selectedCarStatus,
    bool? selectedCarIsActive,
    bool? selectedCarIsAvailable,
    bool? selectedCarIsFeatured,

    List<String>? selectedCarBranchIds,

    String? pricingProfileId,
    String? pricingProfileName,

    String? selectedPackageId,
    String? selectedPackageName,
    String? selectedPackageType,

    double? includedKm,
    double? extraKmCharge,
    double? extraHourCharge,
    double? packagePrice,

    int? minimumHours,
    int? minimumDays,

    int? durationHours,
    int? durationDays,

    double? baseAmount,
    double? packageAmount,
    double? extraKmAmount,
    double? extraHourAmount,
    double? specialDateAdjustment,
    double? weekendAdjustment,
    double? securityDeposit,
    double? taxes,
    double? discount,
    double? finalAmount,
    String? currency,

    int? numberOfPassengers,
    int? numberOfBags,

    bool? selfDrive,
    bool? deliveryRequired,
    bool? pickupRequired,

    String? customerNote,

    String? bookingId,
    String? bookingStatus,
  }) {
    return AIBookingState(
      pickupDate:
          pickupDate ?? this.pickupDate,

      pickupTime:
          pickupTime ?? this.pickupTime,

      returnDate:
          returnDate ?? this.returnDate,

      returnTime:
          returnTime ?? this.returnTime,

      pickupBranchId:
          pickupBranchId ??
          this.pickupBranchId,

      pickupBranchName:
          pickupBranchName ??
          this.pickupBranchName,

      returnBranchId:
          returnBranchId ??
          this.returnBranchId,

      returnBranchName:
          returnBranchName ??
          this.returnBranchName,

      pickupLocation:
          pickupLocation ??
          this.pickupLocation,

      returnLocation:
          returnLocation ??
          this.returnLocation,

      pickupLatitude:
          pickupLatitude ??
          this.pickupLatitude,

      pickupLongitude:
          pickupLongitude ??
          this.pickupLongitude,

      returnLatitude:
          returnLatitude ??
          this.returnLatitude,

      returnLongitude:
          returnLongitude ??
          this.returnLongitude,

      requestedCarType:
          requestedCarType ??
          this.requestedCarType,

      requestedTransmission:
          requestedTransmission ??
          this.requestedTransmission,

      requestedFuel:
          requestedFuel ??
          this.requestedFuel,

      requestedSeats:
          requestedSeats ??
          this.requestedSeats,

      selectedCarId:
          selectedCarId ??
          this.selectedCarId,

      selectedCarName:
          selectedCarName ??
          this.selectedCarName,

      selectedCarType:
          selectedCarType ??
          this.selectedCarType,

      selectedCarTransmission:
          selectedCarTransmission ??
          this.selectedCarTransmission,

      selectedCarFuel:
          selectedCarFuel ??
          this.selectedCarFuel,

      selectedCarSeats:
          selectedCarSeats ??
          this.selectedCarSeats,

      selectedCarImage:
          selectedCarImage ??
          this.selectedCarImage,

      selectedCarImages:
          selectedCarImages ??
          this.selectedCarImages,

      selectedCarRegistrationNumber:
          selectedCarRegistrationNumber ??
          this.selectedCarRegistrationNumber,

      selectedCarCurrentKm:
          selectedCarCurrentKm ??
          this.selectedCarCurrentKm,

      selectedCarStatus:
          selectedCarStatus ??
          this.selectedCarStatus,

      selectedCarIsActive:
          selectedCarIsActive ??
          this.selectedCarIsActive,

      selectedCarIsAvailable:
          selectedCarIsAvailable ??
          this.selectedCarIsAvailable,

      selectedCarIsFeatured:
          selectedCarIsFeatured ??
          this.selectedCarIsFeatured,

      selectedCarBranchIds:
          selectedCarBranchIds ??
          this.selectedCarBranchIds,

      pricingProfileId:
          pricingProfileId ??
          this.pricingProfileId,

      pricingProfileName:
          pricingProfileName ??
          this.pricingProfileName,

      selectedPackageId:
          selectedPackageId ??
          this.selectedPackageId,

      selectedPackageName:
          selectedPackageName ??
          this.selectedPackageName,

      selectedPackageType:
          selectedPackageType ??
          this.selectedPackageType,

      includedKm:
          includedKm ??
          this.includedKm,

      extraKmCharge:
          extraKmCharge ??
          this.extraKmCharge,

      extraHourCharge:
          extraHourCharge ??
          this.extraHourCharge,

      packagePrice:
          packagePrice ??
          this.packagePrice,

      minimumHours:
          minimumHours ??
          this.minimumHours,

      minimumDays:
          minimumDays ??
          this.minimumDays,

      durationHours:
          durationHours ??
          this.durationHours,

      durationDays:
          durationDays ??
          this.durationDays,

      baseAmount:
          baseAmount ??
          this.baseAmount,

      packageAmount:
          packageAmount ??
          this.packageAmount,

      extraKmAmount:
          extraKmAmount ??
          this.extraKmAmount,

      extraHourAmount:
          extraHourAmount ??
          this.extraHourAmount,

      specialDateAdjustment:
          specialDateAdjustment ??
          this.specialDateAdjustment,

      weekendAdjustment:
          weekendAdjustment ??
          this.weekendAdjustment,

      securityDeposit:
          securityDeposit ??
          this.securityDeposit,

      taxes:
          taxes ??
          this.taxes,

      discount:
          discount ??
          this.discount,

      finalAmount:
          finalAmount ??
          this.finalAmount,

      currency:
          currency ??
          this.currency,

      numberOfPassengers:
          numberOfPassengers ??
          this.numberOfPassengers,

      numberOfBags:
          numberOfBags ??
          this.numberOfBags,

      selfDrive:
          selfDrive ??
          this.selfDrive,

      deliveryRequired:
          deliveryRequired ??
          this.deliveryRequired,

      pickupRequired:
          pickupRequired ??
          this.pickupRequired,

      customerNote:
          customerNote ??
          this.customerNote,

      bookingId:
          bookingId ??
          this.bookingId,

      bookingStatus:
          bookingStatus ??
          this.bookingStatus,
    );
  }

  // ============================================================
  // DATE/TIME CHECKS
  // ============================================================

  bool get hasPickupDateTime =>
      _hasValue(pickupDate) &&
      _hasValue(pickupTime);

  bool get hasReturnDateTime =>
      _hasValue(returnDate) &&
      _hasValue(returnTime);

  // ============================================================
  // BRANCH CHECK
  // ============================================================

  bool get hasPickupBranch =>
      _hasValue(pickupBranchId);

  bool get hasReturnBranch =>
      _hasValue(returnBranchId);

  // ============================================================
  // CAR CHECK
  // ============================================================

  bool get hasSelectedCar =>
      _hasValue(selectedCarId);

  // ============================================================
  // PRICING PROFILE CHECK
  // ============================================================

  bool get hasPricingProfile =>
      _hasValue(pricingProfileId);

  // ============================================================
  // PACKAGE CHECK
  // ============================================================

  bool get hasSelectedPackage =>
      _hasValue(selectedPackageId);

  // ============================================================
  // PRICE CHECK
  // ============================================================

  bool get hasPrice =>
      finalAmount != null;

  // ============================================================
  // BOOKING READY
  // ============================================================

  bool get isReadyForBooking =>
      hasPickupDateTime &&
      hasReturnDateTime &&
      hasPickupBranch &&
      hasSelectedCar &&
      hasSelectedPackage;

  // ============================================================
  // CAR IS CURRENTLY ELIGIBLE
  // ============================================================

  bool get selectedCarLooksAvailable {
    return selectedCarIsActive == true &&
        selectedCarIsAvailable == true &&
        (selectedCarStatus == null ||
            selectedCarStatus!
                .toLowerCase() ==
                'available');
  }

  // ============================================================
  // SUMMARY FOR AI
  // ============================================================

  String get summary {
    final parts = <String>[];

    if (_hasValue(selectedCarName)) {
      parts.add(selectedCarName!);
    }

    if (_hasValue(selectedCarType)) {
      parts.add(selectedCarType!);
    }

    if (_hasValue(selectedCarTransmission)) {
      parts.add(selectedCarTransmission!);
    }

    if (_hasValue(pickupDate)) {
      parts.add(
        'Pickup $pickupDate',
      );
    }

    if (_hasValue(pickupTime)) {
      parts.add(
        pickupTime!,
      );
    }

    if (_hasValue(returnDate)) {
      parts.add(
        'Return $returnDate',
      );
    }

    if (_hasValue(returnTime)) {
      parts.add(
        returnTime!,
      );
    }

    if (_hasValue(pickupBranchName)) {
      parts.add(
        pickupBranchName!,
      );
    }

    if (_hasValue(selectedPackageName)) {
      parts.add(
        selectedPackageName!,
      );
    }

    return parts.join(' • ');
  }

  // ============================================================
  // AI CONTEXT
  // ============================================================

  Map<String, dynamic> toAIContext() {
    return {
      'booking': {
        'pickupDate':
            pickupDate,

        'pickupTime':
            pickupTime,

        'returnDate':
            returnDate,

        'returnTime':
            returnTime,

        'pickupBranchId':
            pickupBranchId,

        'pickupBranchName':
            pickupBranchName,

        'returnBranchId':
            returnBranchId,

        'returnBranchName':
            returnBranchName,
      },

      'vehiclePreference': {
        'type':
            requestedCarType,

        'transmission':
            requestedTransmission,

        'fuel':
            requestedFuel,

        'seats':
            requestedSeats,
      },

      'selectedCar': {
        'id':
            selectedCarId,

        'name':
            selectedCarName,

        'type':
            selectedCarType,

        'transmission':
            selectedCarTransmission,

        'fuel':
            selectedCarFuel,

        'seats':
            selectedCarSeats,

        'pricingProfileId':
            pricingProfileId,

        'branchIds':
            selectedCarBranchIds,
      },

      'package': {
        'id':
            selectedPackageId,

        'name':
            selectedPackageName,

        'type':
            selectedPackageType,

        'includedKm':
            includedKm,

        'extraKmCharge':
            extraKmCharge,

        'extraHourCharge':
            extraHourCharge,

        'price':
            packagePrice,
      },

      'pricing': {
        'baseAmount':
            baseAmount,

        'packageAmount':
            packageAmount,

        'extraKmAmount':
            extraKmAmount,

        'extraHourAmount':
            extraHourAmount,

        'specialDateAdjustment':
            specialDateAdjustment,

        'weekendAdjustment':
            weekendAdjustment,

        'securityDeposit':
            securityDeposit,

        'taxes':
            taxes,

        'discount':
            discount,

        'finalAmount':
            finalAmount,

        'currency':
            currency,
      },

      'status': {
        'hasPickupDateTime':
            hasPickupDateTime,

        'hasReturnDateTime':
            hasReturnDateTime,

        'hasSelectedCar':
            hasSelectedCar,

        'hasSelectedPackage':
            hasSelectedPackage,

        'readyForBooking':
            isReadyForBooking,
      },
    };
  }
}


/// ============================================================
/// VALIDATION
/// ============================================================

class AIBookingValidation {
  final bool isValid;

  final List<String> missingFields;

  const AIBookingValidation({
    required this.isValid,
    required this.missingFields,
  });

  String get message {
    if (isValid) {
      return 'Booking information is complete.';
    }

    if (missingFields.isEmpty) {
      return 'Some booking information is missing.';
    }

    return 'Missing: ${missingFields.join(', ')}';
  }
}


/// ============================================================
/// PARSING HELPERS
/// ============================================================

String? _string(
  dynamic value,
) {
  if (value == null) {
    return null;
  }

  final result =
      value.toString().trim();

  if (result.isEmpty) {
    return null;
  }

  return result;
}

double? _double(
  dynamic value,
) {
  if (value == null) {
    return null;
  }

  if (value is double) {
    return value;
  }

  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(
    value.toString(),
  );
}

int? _int(
  dynamic value,
) {
  if (value == null) {
    return null;
  }

  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(
    value.toString(),
  );
}

bool? _bool(
  dynamic value,
) {
  if (value == null) {
    return null;
  }

  if (value is bool) {
    return value;
  }

  final text =
      value.toString().toLowerCase();

  if (text == 'true') {
    return true;
  }

  if (text == 'false') {
    return false;
  }

  return null;
}

List<String> _stringList(
  dynamic value,
) {
  if (value == null) {
    return const [];
  }

  if (value is Iterable) {
    return value
        .map(
          (item) => item.toString(),
        )
        .where(
          (item) => item.trim().isNotEmpty,
        )
        .toList();
  }

  return const [];
}

bool _hasValue(
  dynamic value,
) {
  if (value == null) {
    return false;
  }

  if (value is String) {
    return value.trim().isNotEmpty;
  }

  return true;
}
