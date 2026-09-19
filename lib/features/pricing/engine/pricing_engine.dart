import '../models/add_on.dart';
import '../models/cancellation_rule.dart';
import '../models/discount_rule.dart';
import '../models/km_pricing_package.dart';
import '../models/pricing_config.dart';
import '../models/pricing_profile.dart';
import '../models/protection_plan.dart';
import '../models/rental_package.dart';
import '../models/tax_rule.dart';

class PricingEngine {
  const PricingEngine();

  // ===========================================================================
  // MAIN PRICING CALCULATION
  // ===========================================================================
  //
  // IMPORTANT:
  // This class NEVER reads Firestore.
  //
  // PricingConfig is already loaded in memory.
  //
  // Car
  //   ↓
  // pricingProfileId
  //   ↓
  // PricingConfig.getProfile()
  //   ↓
  // PricingProfile
  //   ↓
  // PricingEngine
  //   ↓
  // PricingResult
  // ===========================================================================

  PricingResult calculate({
    required PricingConfig config,

    /// Pricing profile assigned to the selected car.
    required String pricingProfileId,

    required DateTime pickupDateTime,
    required DateTime returnDateTime,

    /// Rental mode selected by the customer/admin.
    ///
    /// Hourly  = exact pickup/return timestamps.
    /// Daily   = date-based rental; availability is handled separately.
    /// Weekend = weekend-only date-based rental.
    RentalType rentalType = RentalType.daily,

    /// Actual KM driven.
    ///
    /// Normally 0 during booking.
    /// Filled later when the vehicle is returned.
    int actualKm = 0,

    /// Estimated/planned KM.
    ///
    /// Useful for pure per-KM pricing during booking.
    /// If not supplied, 0 is used.
    int plannedKm = 0,

    /// Optional customer-selected total KM allowance for the complete rental.
    ///
    /// Example:
    /// 750 = 750 KM included for the complete booking.
    ///
    /// If null, the profile's default included KM per day is used.
    int? selectedKm,

    /// Optional exact KM pricing package selected by the customer.
    ///
    /// When supplied, this takes priority over selectedKm for package mode.
    String? selectedKmPackageId,

    /// Whether the customer selected unlimited KM.
    bool unlimitedKm = false,

    /// Optional client-configured rental package.
    RentalPackage? selectedPackage,

    /// Optional customer-selected add-ons.
    List<SelectedAddOn> selectedAddOns = const [],

    /// Optional protection plan.
    ProtectionPlan? selectedProtection,

    /// Optional discount/coupon.
    DiscountRule? selectedDiscount,

    /// Whether security deposit should be included
    /// in the amount payable.
    bool includeSecurityDeposit = true,
  }) {
    // -------------------------------------------------------------------------
    // VALIDATE CONFIG
    // -------------------------------------------------------------------------

    if (!config.isActive) {
      return PricingResult.empty();
    }

    // -------------------------------------------------------------------------
    // FIND CAR'S PRICING PROFILE
    // -------------------------------------------------------------------------

    final profile = config.getProfile(
      pricingProfileId,
    );

    if (profile == null || !profile.isActive) {
      return PricingResult.empty();
    }

    // -------------------------------------------------------------------------
    // RENTAL TYPE / SPECIAL DATE VALIDATION
    // -------------------------------------------------------------------------

    if (!profile.isRentalTypeEnabled(rentalType)) {
      return PricingResult.empty();
    }

    final specialRule = profile.specialRuleForRange(
      pickupDateTime,
      returnDateTime,
    );

    if (specialRule != null &&
        !specialRule.isEnabledFor(rentalType)) {
      return PricingResult.empty();
    }

    if (rentalType == RentalType.weekend &&
        !profile.weekendPricing.allowedWeekdays.every(
          (weekday) => weekday >= DateTime.monday && weekday <= DateTime.sunday,
        )) {
      return PricingResult.empty();
    }

    // -------------------------------------------------------------------------
    // VALIDATE DATES
    // -------------------------------------------------------------------------

    if (!returnDateTime.isAfter(pickupDateTime)) {
      return PricingResult.empty();
    }

    // -------------------------------------------------------------------------
    // DURATION
    // -------------------------------------------------------------------------

    final duration = _calculateDuration(
      pickupDateTime,
      returnDateTime,
    );

    final rentalDays = rentalType == RentalType.hourly
        ? 1
        : _calculateRentalDaysForType(
            pickupDateTime,
            returnDateTime,
            rentalType,
          );

    // -------------------------------------------------------------------------
    // KM USED FOR BOOKING CALCULATION
    // -------------------------------------------------------------------------

    final kmForCalculation =
        actualKm > 0 ? actualKm : plannedKm;

    // -------------------------------------------------------------------------
    // 1. RENTAL PRICE
    // -------------------------------------------------------------------------

    final selectedKmPackage = _resolveKmPackage(
      profile,
      selectedKmPackageId: selectedKmPackageId,
      selectedKm: selectedKm,
      unlimitedKm: unlimitedKm,
    );

    final rentalPrice = selectedPackage != null
        ? selectedPackage.price
        : _calculateRentalPrice(
            profile,
            pickupDateTime,
            returnDateTime,
            rentalDays,
            kmForCalculation,
            rentalType: rentalType,
            specialRule: specialRule,
            selectedKmPackage: selectedKmPackage,
            unlimitedKm: unlimitedKm,
          );

    // -------------------------------------------------------------------------
    // 2. INCLUDED KM
    // -------------------------------------------------------------------------

    final includedKm = _calculateIncludedKm(
      profile,
      rentalDays,
      selectedPackage,
      selectedKm: selectedKm,
      selectedKmPackage: selectedKmPackage,
      unlimitedKm: unlimitedKm,
    );

    // -------------------------------------------------------------------------
    // 3. EXTRA KM
    // -------------------------------------------------------------------------

    final extraKm = _calculateExtraKm(
      profile,
      actualKm: actualKm,
      plannedKm: plannedKm,
      includedKm: includedKm,
      selectedPackage: selectedPackage,
      unlimitedKm: unlimitedKm,
    );

    // -------------------------------------------------------------------------
    // 4. EXTRA KM CHARGE
    // -------------------------------------------------------------------------

    final extraKmCharge = _calculateExtraKmCharge(
      profile,
      config,
      extraKm,
      selectedPackage,
      specialRule: specialRule,
      selectedKmPackage: selectedKmPackage,
      unlimitedKm: unlimitedKm,
    );

    // -------------------------------------------------------------------------
    // 5. EXTRA / LATE TIME
    // -------------------------------------------------------------------------

    final extraTimeCharge = _calculateExtraTimeCharge(
      profile,
      duration,
    );

    // -------------------------------------------------------------------------
    // 6. ADD-ONS
    // -------------------------------------------------------------------------

    final addOnTotal = _calculateAddOns(
      selectedAddOns,
      rentalDays,
    );

    // -------------------------------------------------------------------------
    // 7. PROTECTION
    // -------------------------------------------------------------------------

    final protectionTotal = _calculateProtection(
      selectedProtection,
      rentalDays,
    );

    // -------------------------------------------------------------------------
    // 8. SUBTOTAL
    // -------------------------------------------------------------------------

    final subtotalBeforeDiscount =
        rentalPrice +
        extraKmCharge +
        extraTimeCharge +
        addOnTotal +
        protectionTotal;

    // -------------------------------------------------------------------------
    // 9. DISCOUNT
    // -------------------------------------------------------------------------

    final discountAmount = _calculateDiscount(
      selectedDiscount,
      subtotalBeforeDiscount,
      rentalDays,
      pickupDateTime,
    );

    // -------------------------------------------------------------------------
    // 10. TAXABLE AMOUNT
    // -------------------------------------------------------------------------

    final taxableAmount =
        (subtotalBeforeDiscount - discountAmount)
            .clamp(0, double.infinity)
            .toDouble();

    // -------------------------------------------------------------------------
    // 11. TAX
    // -------------------------------------------------------------------------

    final taxAmount = _calculateTax(
      config.taxes,
      rentalAmount: rentalPrice,
      extraKmAmount: extraKmCharge,
      addOnAmount: addOnTotal,
      protectionAmount: protectionTotal,
      extraChargeAmount: extraTimeCharge,
      discountAmount: discountAmount,
    );

    // -------------------------------------------------------------------------
    // 12. SECURITY DEPOSIT
    // -------------------------------------------------------------------------

    final securityDeposit = includeSecurityDeposit &&
            profile.depositConfig.required
        ? profile.depositConfig.defaultAmount
        : 0;

    // -------------------------------------------------------------------------
    // 13. TRIP TOTAL
    // -------------------------------------------------------------------------

    final total = taxableAmount + taxAmount;

    // -------------------------------------------------------------------------
    // 14. AMOUNT PAYABLE
    // -------------------------------------------------------------------------

    final amountPayable =
        total + securityDeposit;

    // -------------------------------------------------------------------------
    // RESULT
    // -------------------------------------------------------------------------

    return PricingResult(
      pricingProfileId: profile.id,
      rentalType: rentalType.value,
      pricingVersion: profile.pricingVersion,
      specialPricingRuleId: specialRule?.id,

      rentalPrice: rentalPrice,

      includedKm: includedKm,
      actualKm: actualKm,
      plannedKm: plannedKm,
      extraKm: extraKm,

      selectedKm: selectedKm,
      selectedKmPackageId: selectedKmPackage?.id,
      selectedKmPackageName: selectedKmPackage?.name,
      selectedKmPackageExtraKmRate:
          selectedKmPackage?.extraKmRate,
      unlimitedKm: unlimitedKm,
      extraKmCharge: extraKmCharge,

      extraTimeCharge: extraTimeCharge,

      addOnTotal: addOnTotal,

      protectionTotal: protectionTotal,

      subtotal: subtotalBeforeDiscount,

      discountAmount: discountAmount,

      taxableAmount: taxableAmount,

      taxAmount: taxAmount,

      securityDeposit: securityDeposit.toDouble(),

      total: total,

      amountPayable: amountPayable,

      rentalDays: rentalDays,

      durationHours: duration.totalHours,
      durationMinutes: duration.totalMinutes,
    );
  }

  // ===========================================================================
  // RENTAL PRICE
  // ===========================================================================

  // ===========================================================================
  // KM PACKAGE RESOLUTION
  // ===========================================================================

  KmPricingPackage? _resolveKmPackage(
    PricingProfile profile, {
    String? selectedKmPackageId,
    int? selectedKm,
    bool unlimitedKm = false,
  }) {
    if (profile.kmPackages.isEmpty) {
      return null;
    }

    if (selectedKmPackageId != null &&
        selectedKmPackageId.isNotEmpty) {
      final package = profile.getPackage(
        selectedKmPackageId,
      );

      if (package != null) {
        return package;
      }
    }

    if (unlimitedKm) {
      return profile.getUnlimitedPackage();
    }

    if (selectedKm != null &&
        selectedKm > 0) {
      return profile.getPackageByKm(
        selectedKm,
      );
    }

    // If package mode is enabled and nothing was explicitly selected,
    // use the first active/available finite package as the default.
    try {
      return profile.kmPackages.firstWhere(
        (package) => !package.unlimitedKm,
      );
    } catch (_) {
      return profile.kmPackages.isNotEmpty
          ? profile.kmPackages.first
          : null;
    }
  }

  // ===========================================================================
  // RENTAL PRICE
  // ===========================================================================

  double _calculateRentalPrice(
    PricingProfile profile,
    DateTime pickup,
    DateTime returnTime,
    int rentalDays,
    int km, {
    RentalType rentalType = RentalType.daily,
    SpecialPricingRule? specialRule,
    KmPricingPackage? selectedKmPackage,
    bool unlimitedKm = false,
  }) {
    // -------------------------------------------------------------------------
    // PACKAGE MODE
    // -------------------------------------------------------------------------
    //
    // The selected KM package owns the duration prices.
    //
    // Example:
    // 250 KM package
    //   Hourly   = package.hourlyRate
    //   Daily    = package.dailyRate
    //   Weekend  = package.weekendRate
    //   Weekly   = package.weeklyRate
    //   Monthly  = package.monthlyRate
    //
    // We NEVER derive a 250 KM price by adding KM to the 150 KM price.
    //

    if (profile.kmPricingMode == KmPricingMode.package &&
        selectedKmPackage != null) {
      return _calculatePackageTimeBasedPrice(
        selectedKmPackage,
        pickup,
        returnTime,
        rentalDays,
        rentalType: rentalType,
        specialRule: specialRule,
      );
    }

    switch (profile.kmPricingMode) {
      // -----------------------------------------------------------------------
      // PURE PER-KM
      // -----------------------------------------------------------------------

      case KmPricingMode.perKm:
        return _calculatePerKmPrice(
          profile,
          km,
        );

      // -----------------------------------------------------------------------
      // TIME BASED / LEGACY
      // -----------------------------------------------------------------------

      case KmPricingMode.included:
      case KmPricingMode.unlimited:
      case KmPricingMode.package:
      case KmPricingMode.slabs:
        final basePrice = _calculateTimeBasedPrice(
          profile,
          pickup,
          returnTime,
          rentalDays,
          rentalType: rentalType,
          specialRule: specialRule,
        );

        // Legacy unlimited surcharge remains supported.
        if (unlimitedKm &&
            profile.unlimitedKmEnabled &&
            profile.unlimitedKmSurcharge > 0) {
          return basePrice +
              (profile.unlimitedKmSurcharge * rentalDays);
        }

        return basePrice;
    }
  }

  // ===========================================================================
  // PACKAGE TIME BASED PRICE
  // ===========================================================================

  double _calculatePackageTimeBasedPrice(
    KmPricingPackage package,
    DateTime pickup,
    DateTime returnTime,
    int rentalDays, {
    RentalType rentalType = RentalType.daily,
    SpecialPricingRule? specialRule,
  }) {
    final totalMinutes =
        returnTime.difference(pickup).inMinutes;

    final totalHours =
        totalMinutes / 60;

    // -------------------------------------------------------------------------
    // MONTHLY
    // -------------------------------------------------------------------------

    if (rentalDays >= 30 &&
        package.monthlyRate > 0) {
      final months = rentalDays ~/ 30;
      final remainingDays = rentalDays % 30;

      double total =
          months * package.monthlyRate;

      if (remainingDays > 0) {
        final remainingStart = pickup.add(
          Duration(days: months * 30),
        );

        total += _calculatePackageDailyWeekendPrice(
          package,
          remainingStart,
          remainingDays,
        );
      }

      return total;
    }

    // -------------------------------------------------------------------------
    // WEEKLY
    // -------------------------------------------------------------------------

    if (rentalDays >= 7 &&
        package.weeklyRate > 0) {
      final weeks = rentalDays ~/ 7;
      final remainingDays = rentalDays % 7;

      double total =
          weeks * package.weeklyRate;

      if (remainingDays > 0) {
        final remainingStart = pickup.add(
          Duration(days: weeks * 7),
        );

        total += _calculatePackageDailyWeekendPrice(
          package,
          remainingStart,
          remainingDays,
        );
      }

      return total;
    }

    // -------------------------------------------------------------------------
    // RENTAL TYPE
    // -------------------------------------------------------------------------

    switch (rentalType) {
      case RentalType.hourly:
        final configuredMinimum =
            specialRule?.minimumBillingHours ??
            0;
        final profileMinimum =
            configuredMinimum > 0
                ? configuredMinimum
                : 1;
        final hours = totalHours.ceil() < profileMinimum
            ? profileMinimum
            : totalHours.ceil();

        final rate = specialRule?.hourlyRate ??
            package.hourlyRate;

        return rate > 0 ? hours * rate : 0;

      case RentalType.daily:
        return _calculatePackageDailyPrice(
          package,
          pickup,
          rentalDays,
          specialRule: specialRule,
        );

      case RentalType.weekend:
        final rate = specialRule?.weekendRate ??
            package.weekendRate;

        if (rate <= 0) return 0;

        return rentalDays * rate;
    }
  }

  // ===========================================================================
  // PACKAGE DAILY + WEEKEND
  // ===========================================================================

  double _calculatePackageDailyWeekendPrice(
    KmPricingPackage package,
    DateTime start,
    int days,
  ) {
    double total = 0;

    for (int i = 0; i < days; i++) {
      final date = start.add(
        Duration(days: i),
      );

      final isWeekend =
          date.weekday == DateTime.saturday ||
          date.weekday == DateTime.sunday;

      if (isWeekend &&
          package.weekendRate > 0) {
        total += package.weekendRate;
      } else {
        total += package.dailyRate;
      }
    }

    return total;
  }

  double _calculatePackageDailyPrice(
    KmPricingPackage package,
    DateTime start,
    int days, {
    SpecialPricingRule? specialRule,
  }) {
    if (days <= 0) return 0;

    double total = 0;

    for (int i = 0; i < days; i++) {
      final date = start.add(Duration(days: i));

      final specialRate = specialRule?.dailyRate;
      if (specialRate != null && specialRate > 0) {
        total += specialRate;
      } else {
        total += package.dailyRate;
      }
    }

    return total;
  }

  // ===========================================================================
  // LEGACY TIME BASED PRICE
  // ===========================================================================

  double _calculateTimeBasedPrice(
    PricingProfile profile,
    DateTime pickup,
    DateTime returnTime,
    int rentalDays, {
    RentalType rentalType = RentalType.daily,
    SpecialPricingRule? specialRule,
  }) {
    final totalMinutes =
        returnTime.difference(pickup).inMinutes;

    final totalHours =
        totalMinutes / 60;

    // -------------------------------------------------------------------------
    // MONTHLY
    // -------------------------------------------------------------------------

    if (rentalDays >= 30 &&
        profile.monthlyRate > 0) {
      final months = rentalDays ~/ 30;
      final remainingDays = rentalDays % 30;

      double total =
          months * profile.monthlyRate;

      if (remainingDays > 0) {
        final remainingStart = pickup.add(
          Duration(days: months * 30),
        );

        total += _calculateDailyWeekendPrice(
          profile,
          remainingStart,
          remainingDays,
        );
      }

      return total;
    }

    // -------------------------------------------------------------------------
    // WEEKLY
    // -------------------------------------------------------------------------

    if (rentalDays >= 7 &&
        profile.weeklyRate > 0) {
      final weeks = rentalDays ~/ 7;
      final remainingDays = rentalDays % 7;

      double total =
          weeks * profile.weeklyRate;

      if (remainingDays > 0) {
        final remainingStart = pickup.add(
          Duration(days: weeks * 7),
        );

        total += _calculateDailyWeekendPrice(
          profile,
          remainingStart,
          remainingDays,
        );
      }

      return total;
    }

    // -------------------------------------------------------------------------
    // RENTAL TYPE
    // -------------------------------------------------------------------------

    switch (rentalType) {
      case RentalType.hourly:
        final minimum = specialRule?.minimumBillingHours ??
            profile.hourlyPricing.minimumBillingHours;
        final minimumHours = minimum > 0 ? minimum : 1;
        final hours = totalHours.ceil() < minimumHours
            ? minimumHours
            : totalHours.ceil();

        final rate = specialRule?.hourlyRate ??
            profile.hourlyPricing.rate;

        return rate > 0
            ? hours * rate
            : profile.hourlyRate * hours;

      case RentalType.daily:
        final specialDailyRate = specialRule?.dailyRate;
        if (specialDailyRate != null && specialDailyRate > 0) {
          return specialDailyRate * rentalDays;
        }
        return profile.dailyPricing.rate > 0
            ? profile.dailyPricing.rate * rentalDays
            : _calculateDailyWeekendPrice(
                profile,
                pickup,
                rentalDays,
              );

      case RentalType.weekend:
        final specialWeekendRate = specialRule?.weekendRate;
        final weekendRate = specialWeekendRate != null &&
                specialWeekendRate > 0
            ? specialWeekendRate
            : profile.weekendPricing.rate;

        return weekendRate > 0
            ? weekendRate * rentalDays
            : _calculateDailyWeekendPrice(
                profile,
                pickup,
                rentalDays,
              );
    }
  }

  // ===========================================================================
  // DAILY + WEEKEND
  // ===========================================================================

  double _calculateDailyWeekendPrice(
    PricingProfile profile,
    DateTime start,
    int days,
  ) {
    double total = 0;

    for (int i = 0; i < days; i++) {
      final date = start.add(
        Duration(days: i),
      );

      final isWeekend =
          date.weekday == DateTime.saturday ||
          date.weekday == DateTime.sunday;

      if (isWeekend &&
          profile.weekendRate > 0) {
        total += profile.weekendRate;
      } else {
        total += profile.dailyRate;
      }
    }

    return total;
  }

  // ===========================================================================
  // PURE PER-KM
  // ===========================================================================

  double _calculatePerKmPrice(
    PricingProfile profile,
    int km,
  ) {
    if (km <= 0) {
      return 0;
    }

    return km * profile.perKmRate;
  }

  // ===========================================================================
  // INCLUDED KM
  // ===========================================================================

  int _calculateIncludedKm(
    PricingProfile profile,
    int rentalDays,
    RentalPackage? selectedPackage, {
    int? selectedKm,
    KmPricingPackage? selectedKmPackage,
    bool unlimitedKm = false,
  }) {
    // -------------------------------------------------------------------------
    // PACKAGE
    // -------------------------------------------------------------------------

    if (selectedPackage != null) {
      if (selectedPackage.unlimitedKm) {
        return 0;
      }

      return selectedPackage.includedKm;
    }

    // -------------------------------------------------------------------------
    // NEW KM PACKAGE
    // -------------------------------------------------------------------------

    if (selectedKmPackage != null) {
      if (selectedKmPackage.unlimitedKm) {
        return 0;
      }

      return selectedKmPackage.includedKm ?? 0;
    }

    // -------------------------------------------------------------------------
    // CUSTOMER SELECTED UNLIMITED KM
    // -------------------------------------------------------------------------

    if (unlimitedKm &&
        profile.unlimitedKmEnabled) {
      return 0;
    }

    // -------------------------------------------------------------------------
    // PROFILE UNLIMITED KM
    // -------------------------------------------------------------------------

    if (profile.kmPricingMode ==
        KmPricingMode.unlimited) {
      return 0;
    }

    // -------------------------------------------------------------------------
    // CUSTOMER SELECTED TOTAL KM
    // -------------------------------------------------------------------------

    if (selectedKm != null &&
        selectedKm > 0) {
      return selectedKm;
    }

    // -------------------------------------------------------------------------
    // PURE PER-KM
    // -------------------------------------------------------------------------

    if (profile.kmPricingMode ==
        KmPricingMode.perKm) {
      return 0;
    }

    // -------------------------------------------------------------------------
    // DEFAULT INCLUDED KM
    // -------------------------------------------------------------------------

    return profile.includedKmPerDay *
        rentalDays;
  }

  // ===========================================================================
  // EXTRA KM
  // ===========================================================================

  int _calculateExtraKm(
    PricingProfile profile, {
    required int actualKm,
    required int plannedKm,
    required int includedKm,
    RentalPackage? selectedPackage,
    bool unlimitedKm = false,
  }) {
    final km =
        actualKm > 0 ? actualKm : plannedKm;

    if (km <= 0) {
      return 0;
    }

    // -------------------------------------------------------------------------
    // PURE PER-KM
    // -------------------------------------------------------------------------

    if (selectedPackage == null &&
        profile.kmPricingMode ==
            KmPricingMode.perKm) {
      return 0;
    }

    // -------------------------------------------------------------------------
    // UNLIMITED
    // -------------------------------------------------------------------------

    if (unlimitedKm ||
        selectedPackage?.unlimitedKm == true ||
        profile.kmPricingMode ==
            KmPricingMode.unlimited) {
      return 0;
    }

    // -------------------------------------------------------------------------
    // INCLUDED KM
    // -------------------------------------------------------------------------

    if (km <= includedKm) {
      return 0;
    }

    return km - includedKm;
  }

  // ===========================================================================
  // EXTRA KM CHARGE
  // ===========================================================================

  double _calculateExtraKmCharge(
    PricingProfile profile,
    PricingConfig config,
    int extraKm,
    RentalPackage? selectedPackage, {
    SpecialPricingRule? specialRule,
    KmPricingPackage? selectedKmPackage,
    bool unlimitedKm = false,
  }) {
    if (extraKm <= 0) {
      return 0;
    }

    // Special-date extra-KM rate overrides the normal profile/package rate.
    if (specialRule?.extraKmRate != null &&
        specialRule!.extraKmRate > 0 &&
        !unlimitedKm) {
      return extraKm * specialRule.extraKmRate;
    }

    // -------------------------------------------------------------------------
    // NEW KM PACKAGE
    // -------------------------------------------------------------------------
    //
    // Each selected package carries its OWN extra KM rate.
    //

    if (selectedKmPackage != null) {
      if (selectedKmPackage.unlimitedKm) {
        return 0;
      }

      return extraKm *
          selectedKmPackage.extraKmRate;
    }

    // -------------------------------------------------------------------------
    // PACKAGE
    // -------------------------------------------------------------------------

    if (unlimitedKm) {
      return 0;
    }

    if (selectedPackage != null) {
      if (selectedPackage.unlimitedKm) {
        return 0;
      }

      return extraKm *
          selectedPackage.extraKmRate;
    }

    // -------------------------------------------------------------------------
    // PROFILE
    // -------------------------------------------------------------------------

    switch (profile.kmPricingMode) {
      case KmPricingMode.unlimited:
        return 0;

      case KmPricingMode.perKm:
        return 0;

      case KmPricingMode.included:
      case KmPricingMode.package:
        return extraKm *
            profile.extraKmRate;

      case KmPricingMode.slabs:
        return _calculateSlabCharge(
          config,
          profile,
          extraKm,
        );
    }
  }

  // ===========================================================================
  // KM SLABS
  // ===========================================================================

  double _calculateSlabCharge(
    PricingConfig config,
    PricingProfile profile,
    int extraKm,
  ) {
    if (extraKm <= 0) {
      return 0;
    }

    final slabs = config.kmSlabs
        .where(
          (slab) => slab.isActive,
        )
        .toList()
      ..sort(
        (a, b) =>
            a.fromKm.compareTo(b.fromKm),
      );

    if (slabs.isEmpty) {
      return extraKm *
          profile.extraKmRate;
    }

    double total = 0;

    int remainingKm = extraKm;

    for (final slab in slabs) {
      if (remainingKm <= 0) {
        break;
      }

      final start = slab.fromKm;
      final end = slab.toKm;

      if (end != null &&
          end < start) {
        continue;
      }

      final slabCapacity = end == null
          ? remainingKm
          : end - start + 1;

      if (slabCapacity <= 0) {
        continue;
      }

      final chargeableKm =
          remainingKm < slabCapacity
              ? remainingKm
              : slabCapacity;

      total +=
          chargeableKm *
          slab.pricePerKm;

      remainingKm -= chargeableKm;
    }

    // Configuration gaps fallback.
    if (remainingKm > 0) {
      total +=
          remainingKm *
          profile.extraKmRate;
    }

    return total;
  }

  // ===========================================================================
  // EXTRA / LATE TIME
  // ===========================================================================

  double _calculateExtraTimeCharge(
    PricingProfile profile,
    RentalDuration duration,
  ) {
    if (duration.totalMinutes <= 0) {
      return 0;
    }

    final remainingMinutes =
        duration.totalMinutes %
            (24 * 60);

    // Exact whole days.
    if (remainingMinutes == 0) {
      return 0;
    }

    final extraMinutes =
        remainingMinutes;

    // Grace period.
    if (extraMinutes <=
        profile.gracePeriodMinutes) {
      return 0;
    }

    final chargeableMinutes =
        extraMinutes -
        profile.gracePeriodMinutes;

    final extraHours =
        (chargeableMinutes / 60).ceil();

    // Prefer late-return rate.
    if (profile.lateReturnRate > 0) {
      return extraHours *
          profile.lateReturnRate;
    }

    // Otherwise extra-hour rate.
    if (profile.extraHourRate > 0) {
      return extraHours *
          profile.extraHourRate;
    }

    return 0;
  }

  // ===========================================================================
  // ADD-ONS
  // ===========================================================================

  double _calculateAddOns(
    List<SelectedAddOn> selectedAddOns,
    int rentalDays,
  ) {
    double total = 0;

    for (final selected in selectedAddOns) {
      if (selected.quantity <= 0) {
        continue;
      }

      final addOn = selected.addOn;

      int quantity =
          selected.quantity;

      // Maximum quantity.
      if (addOn.maxQuantity != null &&
          quantity >
              addOn.maxQuantity!) {
        quantity =
            addOn.maxQuantity!;
      }

      double price =
          addOn.price * quantity;

      // Per-day add-on.
      if (addOn.isPerDay) {
        price *= rentalDays;
      }

      total += price;
    }

    return total;
  }

  // ===========================================================================
  // PROTECTION
  // ===========================================================================

  double _calculateProtection(
    ProtectionPlan? protection,
    int rentalDays,
  ) {
    if (protection == null ||
        !protection.isActive) {
      return 0;
    }

    if (protection.isPerDay) {
      return protection.price *
          rentalDays;
    }

    return protection.price;
  }

  // ===========================================================================
  // DISCOUNT
  // ===========================================================================

  double _calculateDiscount(
    DiscountRule? discount,
    double subtotal,
    int rentalDays,
    DateTime pickupDateTime,
  ) {
    if (discount == null ||
        !discount.isActive) {
      return 0;
    }

    // -------------------------------------------------------------------------
    // MINIMUM BOOKING
    // -------------------------------------------------------------------------

    if (subtotal <
        discount.minimumBookingAmount) {
      return 0;
    }

    // -------------------------------------------------------------------------
    // MINIMUM RENTAL DAYS
    // -------------------------------------------------------------------------

    if (discount.minimumRentalDays !=
            null &&
        rentalDays <
            discount.minimumRentalDays!) {
      return 0;
    }

    // -------------------------------------------------------------------------
    // DATE RANGE
    // -------------------------------------------------------------------------

    if (discount.validFrom != null &&
        pickupDateTime.isBefore(
          discount.validFrom!,
        )) {
      return 0;
    }

    if (discount.validUntil != null &&
        pickupDateTime.isAfter(
          discount.validUntil!,
        )) {
      return 0;
    }

    // -------------------------------------------------------------------------
    // WEEKDAY
    // -------------------------------------------------------------------------

    if (discount.applicableWeekdays
            .isNotEmpty &&
        !discount.applicableWeekdays
            .contains(
          pickupDateTime.weekday,
        )) {
      return 0;
    }

    // -------------------------------------------------------------------------
    // CALCULATE
    // -------------------------------------------------------------------------

    double amount = 0;

    switch (discount.type) {
      case DiscountType.percentage:
        amount =
            subtotal *
            discount.percentage /
            100;
        break;

      case DiscountType.fixedAmount:
        amount =
            discount.fixedAmount;
        break;
    }

    // -------------------------------------------------------------------------
    // MAXIMUM DISCOUNT
    // -------------------------------------------------------------------------

    if (discount.maximumDiscount !=
            null &&
        amount >
            discount.maximumDiscount!) {
      amount =
          discount.maximumDiscount!;
    }

    return amount
        .clamp(0, subtotal)
        .toDouble();
  }

  // ===========================================================================
  // TAX
  // ===========================================================================

  double _calculateTax(
    List<TaxRule> taxes, {
    required double rentalAmount,
    required double extraKmAmount,
    required double addOnAmount,
    required double protectionAmount,
    required double extraChargeAmount,
    required double discountAmount,
  }) {
    double totalTax = 0;

    final activeTaxes = taxes
        .where(
          (tax) => tax.isActive,
        )
        .toList();

    for (final tax in activeTaxes) {
      double taxableAmount = 0;

      if (tax.appliesToRental) {
        taxableAmount +=
            rentalAmount;
      }

      if (tax.appliesToExtraKm) {
        taxableAmount +=
            extraKmAmount;
      }

      if (tax.appliesToAddOns) {
        taxableAmount +=
            addOnAmount;
      }

      if (tax.appliesToProtection) {
        taxableAmount +=
            protectionAmount;
      }

      if (tax.appliesToExtraCharges) {
        taxableAmount +=
            extraChargeAmount;
      }

      // Apply discount before tax.
      taxableAmount =
          (taxableAmount -
                  discountAmount)
              .clamp(
                0,
                double.infinity,
              )
              .toDouble();

      if (tax.percentage <= 0) {
        continue;
      }

      // -----------------------------------------------------------------------
      // TAX INCLUSIVE
      // -----------------------------------------------------------------------

      if (tax.isInclusive) {
        final taxAmount =
            taxableAmount -
            (
              taxableAmount /
              (
                1 +
                tax.percentage / 100
              )
            );

        totalTax += taxAmount;
      }

      // -----------------------------------------------------------------------
      // TAX EXCLUSIVE
      // -----------------------------------------------------------------------

      else {
        totalTax +=
            taxableAmount *
            tax.percentage /
            100;
      }
    }

    return totalTax;
  }

  // ===========================================================================
  // DURATION
  // ===========================================================================

  RentalDuration _calculateDuration(
    DateTime pickup,
    DateTime returnTime,
  ) {
    final difference =
        returnTime.difference(
      pickup,
    );

    final totalMinutes =
        difference.inMinutes;

    final totalHours =
        totalMinutes / 60;

    final billableDays =
        (totalMinutes /
                (24 * 60))
            .ceil()
            .clamp(1, 100000);

    return RentalDuration(
      totalMinutes: totalMinutes,
      totalHours: totalHours,
      billableDays: billableDays,
    );
  }
}

// ============================================================================
// SELECTED ADD-ON
// ============================================================================

class SelectedAddOn {
  final AddOn addOn;
  final int quantity;

  const SelectedAddOn({
    required this.addOn,
    this.quantity = 1,
  });
}

// ============================================================================
// RENTAL DURATION
// ============================================================================

class RentalDuration {
  final int totalMinutes;
  final double totalHours;
  final int billableDays;

  const RentalDuration({
    required this.totalMinutes,
    required this.totalHours,
    required this.billableDays,
  });
}

// ============================================================================
// PRICING RESULT
// ============================================================================

class PricingResult {
  /// Pricing profile used for this calculation.
  final String pricingProfileId;

  /// Hourly / daily / weekend.
  final String rentalType;

  /// Immutable pricing configuration version used for this calculation.
  final int pricingVersion;

  /// Special pricing rule used, if any.
  final String? specialPricingRuleId;

  final double rentalPrice;

  final int includedKm;
  final int actualKm;
  final int plannedKm;
  final int extraKm;

  /// Customer-selected total KM allowance.
  /// Null means the profile default was used.
  final int? selectedKm;

  /// Exact KM pricing package selected.
  final String? selectedKmPackageId;

  /// Display name of the selected KM pricing package.
  final String? selectedKmPackageName;

  /// Extra KM rate belonging to the selected package.
  final double? selectedKmPackageExtraKmRate;

  /// Whether unlimited KM was selected.
  final bool unlimitedKm;

  final double extraKmCharge;

  final double extraTimeCharge;

  final double addOnTotal;

  final double protectionTotal;

  final double subtotal;

  final double discountAmount;

  final double taxableAmount;

  final double taxAmount;

  final double securityDeposit;

  final double total;

  final double amountPayable;

  final int rentalDays;

  final double durationHours;

  final int durationMinutes;

  const PricingResult({
    required this.pricingProfileId,
    required this.rentalType,
    required this.pricingVersion,
    required this.specialPricingRuleId,

    required this.rentalPrice,

    required this.includedKm,
    required this.actualKm,
    required this.plannedKm,
    required this.extraKm,

    required this.selectedKm,
    required this.selectedKmPackageId,
    required this.selectedKmPackageName,
    required this.selectedKmPackageExtraKmRate,
    required this.unlimitedKm,

    required this.extraKmCharge,

    required this.extraTimeCharge,

    required this.addOnTotal,

    required this.protectionTotal,

    required this.subtotal,

    required this.discountAmount,

    required this.taxableAmount,

    required this.taxAmount,

    required this.securityDeposit,

    required this.total,

    required this.amountPayable,

    required this.rentalDays,

    required this.durationHours,

    required this.durationMinutes,
  });

  // ===========================================================================
  // EMPTY RESULT
  // ===========================================================================

  factory PricingResult.empty() {
    return const PricingResult(
      pricingProfileId: '',
      rentalType: RentalType.daily.value,
      pricingVersion: 0,
      specialPricingRuleId: null,

      rentalPrice: 0,

      includedKm: 0,
      actualKm: 0,
      plannedKm: 0,
      extraKm: 0,

      selectedKm: null,
      selectedKmPackageId: null,
      selectedKmPackageName: null,
      selectedKmPackageExtraKmRate: null,
      unlimitedKm: false,

      extraKmCharge: 0,

      extraTimeCharge: 0,

      addOnTotal: 0,

      protectionTotal: 0,

      subtotal: 0,

      discountAmount: 0,

      taxableAmount: 0,

      taxAmount: 0,

      securityDeposit: 0,

      total: 0,

      amountPayable: 0,

      rentalDays: 0,

      durationHours: 0,

      durationMinutes: 0,
    );
  }

  // ===========================================================================
  // BREAKDOWN
  // ===========================================================================

  Map<String, double> get breakdown {
    return {
      'Rental': rentalPrice,
      'Extra KM': extraKmCharge,
      'Extra Time': extraTimeCharge,
      'Add-ons': addOnTotal,
      'Protection': protectionTotal,
      'Discount': -discountAmount,
      'Tax': taxAmount,
      'Security Deposit': securityDeposit,
      'Total': total,
    };
  }

  // ===========================================================================
  // RENTAL TOTAL
  // ===========================================================================

  double get tripTotal => total;

  // ===========================================================================
  // REFUNDABLE DEPOSIT
  // ===========================================================================

  double get refundableDeposit =>
      securityDeposit;
}