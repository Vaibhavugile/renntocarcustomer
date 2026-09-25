import '../models/add_on.dart';



import '../models/cancellation_rule.dart';



import '../models/discount_rule.dart';



import '../models/km_pricing_package.dart';



import '../models/pricing_config.dart';



import '../models/pricing_profile.dart';



import '../models/protection_plan.dart';



import '../models/rental_package.dart';



import '../models/tax_rule.dart';







/// Simple pricing engine.



///



/// Business rules:



/// - Rental types: hourly and daily only.



/// - KM packages contain the normal hourly/daily price and extra-KM rate.



/// - Daily packages include KM per rental day.



/// - Special dates override package prices for the matching dates.



/// - Security deposit is separate from Trip Total.



/// - Add-ons, protection, discounts and tax remain supported.



/// - This class never reads Firestore.



class PricingEngine {



  const PricingEngine();







  PricingResult calculate({



    required PricingConfig config,



    required String pricingProfileId,



    required DateTime pickupDateTime,



    required DateTime returnDateTime,



    RentalType rentalType = RentalType.daily,



    int actualKm = 0,



    int plannedKm = 0,



    int? selectedKm,



    String? selectedKmPackageId,



    bool unlimitedKm = false,



    RentalPackage? selectedPackage,



    List<SelectedAddOn> selectedAddOns = const [],



    ProtectionPlan? selectedProtection,



    DiscountRule? selectedDiscount,



    bool includeSecurityDeposit = true,



  }) {



    if (!config.isActive) return PricingResult.empty();







    final profile = config.getProfile(pricingProfileId);



    if (profile == null || !profile.isActive) {



      return PricingResult.empty();



    }







    if (!profile.isRentalTypeEnabled(rentalType)) {



      return PricingResult.empty();



    }







    if (!returnDateTime.isAfter(pickupDateTime)) {



      return PricingResult.empty();



    }







    final duration = _calculateDuration(



      pickupDateTime,



      returnDateTime,



    );
final kmForCalculation =



        actualKm > 0 ? actualKm : plannedKm;







    final selectedKmPackage = _resolveKmPackage(



      profile,



      rentalType: rentalType,



      selectedKmPackageId: selectedKmPackageId,



      selectedKm: selectedKm,



      unlimitedKm: unlimitedKm,



    );







    

    final durationAdjusted = _applyMinimumBookingRules(
      profile,
      duration,
      rentalType: rentalType,
      packageId: selectedKmPackage?.id,
    );

    final rentalDays = rentalType == RentalType.hourly
        ? 1
        : durationAdjusted.billableDays;
final rentalPrice = selectedPackage != null



        ? selectedPackage.price



        : _calculateRentalPrice(



            profile,



            pickupDateTime,



            returnDateTime,



            rentalDays,



            rentalType: rentalType,



            selectedKmPackage: selectedKmPackage,



            unlimitedKm: unlimitedKm,



          );







    final includedKm = _calculateIncludedKm(



      profile,



      rentalDays,



      selectedPackage,



      selectedKm: selectedKm,



      selectedKmPackage: selectedKmPackage,



      rentalType: rentalType,



      unlimitedKm: unlimitedKm,



    );







    final extraKm = _calculateExtraKm(



      actualKm: actualKm,



      plannedKm: plannedKm,



      includedKm: includedKm,



      selectedPackage: selectedPackage,



      selectedKmPackage: selectedKmPackage,



      unlimitedKm: unlimitedKm,



    );







    final extraKmCharge = _calculateExtraKmCharge(



      profile,



      extraKm,



      selectedPackage,



      selectedKmPackage: selectedKmPackage,



      pickupDateTime: pickupDateTime,



      rentalType: rentalType,



      unlimitedKm: unlimitedKm,



    );







    // Daily rental is already charged by rental day. Do not add a second



    // "extra time" amount merely because the timestamps contain hours.
    final extraTimeCharge = _calculateExtraTimeCharge(
      profile,
      durationAdjusted,
      rentalType: rentalType,
      packageId: selectedKmPackage?.id,
    );







    final addOnTotal = _calculateAddOns(



      selectedAddOns,



      rentalDays,



    );







    final protectionTotal = _calculateProtection(



      selectedProtection,



      rentalDays,



    );







    final subtotalBeforeDiscount =



        rentalPrice +



        extraKmCharge +



        extraTimeCharge +



        addOnTotal +



        protectionTotal;







    final discountAmount = _calculateDiscount(



      selectedDiscount,



      subtotalBeforeDiscount,



      rentalDays,



      pickupDateTime,



    );







    final taxableAmount =



        (subtotalBeforeDiscount - discountAmount)



            .clamp(0, double.infinity)



            .toDouble();







    final taxAmount = _calculateTax(



      config.taxes,



      rentalAmount: rentalPrice,



      extraKmAmount: extraKmCharge,



      addOnAmount: addOnTotal,



      protectionAmount: protectionTotal,



      extraChargeAmount: extraTimeCharge,



      discountAmount: discountAmount,



    );







    // Deposit is NOT part of Trip Total.



    //



    // Monetary deposits increase Amount Payable.



    // Customer-bike / other-asset deposits do not add money.



    final securityDeposit = includeSecurityDeposit



        ? profile.securityDepositAmount



        : 0.0;







    final total = taxableAmount + taxAmount;



    final amountPayable = total + securityDeposit;







    return PricingResult(



      pricingProfileId: profile.id,



      rentalType: rentalType.value,



      pricingVersion: 0,



      specialPricingRuleId:



          profile.specialRateForRange(



            pickupDateTime,



            returnDateTime,



          )?.id,



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



      unlimitedKm: unlimitedKm ||



          selectedKmPackage?.unlimitedKm == true,



      extraKmCharge: extraKmCharge,



      extraTimeCharge: extraTimeCharge,

      minimumHours:
          profile.minimumHoursFor(selectedKmPackage?.id ?? ''),
      minimumDays:
          profile.minimumDaysFor(selectedKmPackage?.id ?? ''),
      fullDays: durationAdjusted.fullDays,
      extraHours: durationAdjusted.extraHours,
      extraMinutes: durationAdjusted.extraMinutes,

      addOnTotal: addOnTotal,



      protectionTotal: protectionTotal,



      subtotal: subtotalBeforeDiscount,



      discountAmount: discountAmount,



      taxableAmount: taxableAmount,



      taxAmount: taxAmount,



      securityDeposit: securityDeposit,



      total: total,



      amountPayable: amountPayable,



      rentalDays: rentalDays,



      durationHours: durationAdjusted.totalHours,
      durationMinutes: durationAdjusted.totalMinutes,



    );



  }







  // ---------------------------------------------------------------------------



  // PACKAGE RESOLUTION



  // ---------------------------------------------------------------------------







  KmPricingPackage? _resolveKmPackage(



    PricingProfile profile, {



    required RentalType rentalType,



    String? selectedKmPackageId,



    int? selectedKm,



    bool unlimitedKm = false,



  }) {



    final packages = profile.packagesFor(rentalType)



        .where((package) => package.isActive)



        .toList();







    if (packages.isEmpty) return null;







    if (selectedKmPackageId != null &&



        selectedKmPackageId.isNotEmpty) {



      final package = profile.getPackage(



        selectedKmPackageId,



        rentalType: rentalType,



      );







      if (package != null && package.isActive) {



        return package;



      }



    }







    if (unlimitedKm) {



      try {



        return packages.firstWhere(



          (package) => package.unlimitedKm,



        );



      } catch (_) {}



    }







    if (selectedKm != null && selectedKm > 0) {



      try {



        return packages.firstWhere(



          (package) =>



              !package.unlimitedKm &&



              package.includedKm == selectedKm,



        );



      } catch (_) {}



    }







    // Default to the first active finite package.



    try {



      return packages.firstWhere(



        (package) => !package.unlimitedKm,



      );



    } catch (_) {



      return packages.first;



    }



  }







  // ---------------------------------------------------------------------------



  // RENTAL PRICE



  // ---------------------------------------------------------------------------







  double _calculateRentalPrice(



    PricingProfile profile,



    DateTime pickup,



    DateTime returnTime,



    int rentalDays, {



    required RentalType rentalType,



    KmPricingPackage? selectedKmPackage,



    bool unlimitedKm = false,



  }) {



    if (selectedKmPackage == null) return 0;







    if (rentalType == RentalType.hourly) {



      final minutes = returnTime.difference(pickup).inMinutes;



      final hours = (minutes / 60).ceil().clamp(1, 100000);







      // Hourly special rate is selected using the pickup date.



      final hourlyRate = profile.priceFor(



        rentalType: RentalType.hourly,



        package: selectedKmPackage,



        date: pickup,



      );







      return hourlyRate * hours;



    }







    // Daily rental is charged per rental day.



    //



    // Each date gets its own special-rate lookup. This means a booking that



    // crosses a weekend/holiday can automatically use the special rate for



    // the affected dates without introducing a separate "weekend rental type".



    double total = 0;







    for (int i = 0; i < rentalDays; i++) {



      final date = pickup.add(Duration(days: i));







      total += profile.priceFor(



        rentalType: RentalType.daily,



        package: selectedKmPackage,



        date: date,



      );



    }







    return total;



  }







  // ---------------------------------------------------------------------------



  // INCLUDED KM



  // ---------------------------------------------------------------------------







  int _calculateIncludedKm(



    PricingProfile profile,



    int rentalDays,



    RentalPackage? selectedPackage, {



    int? selectedKm,



    KmPricingPackage? selectedKmPackage,



    required RentalType rentalType,



    bool unlimitedKm = false,



  }) {



    if (selectedPackage != null) {



      if (selectedPackage.unlimitedKm) return 0;



      return selectedPackage.includedKm;



    }







    if (selectedKmPackage != null) {



      if (selectedKmPackage.unlimitedKm) return 0;







      if (rentalType == RentalType.daily) {



        return selectedKmPackage.includedKmForDays(



          rentalDays,



        );



      }







      return selectedKmPackage.safeIncludedKm;



    }







    if (unlimitedKm) return 0;







    // This is only a legacy fallback. New profiles should always select



    // a KM package.



    if (selectedKm != null && selectedKm > 0) {



      return rentalType == RentalType.daily



          ? selectedKm * rentalDays



          : selectedKm;



    }







    return 0;



  }







  // ---------------------------------------------------------------------------



  // EXTRA KM



  // ---------------------------------------------------------------------------







  int _calculateExtraKm({



    required int actualKm,



    required int plannedKm,



    required int includedKm,



    RentalPackage? selectedPackage,



    KmPricingPackage? selectedKmPackage,



    bool unlimitedKm = false,



  }) {



    final km = actualKm > 0 ? actualKm : plannedKm;







    if (km <= 0) return 0;







    if (unlimitedKm ||



        selectedPackage?.unlimitedKm == true ||



        selectedKmPackage?.unlimitedKm == true) {



      return 0;



    }







    final extra = km - includedKm;



    return extra > 0 ? extra : 0;



  }







  // ---------------------------------------------------------------------------



  // EXTRA KM CHARGE



  // ---------------------------------------------------------------------------







  double _calculateExtraKmCharge(



    PricingProfile profile,



    int extraKm,



    RentalPackage? selectedPackage, {



    KmPricingPackage? selectedKmPackage,



    required DateTime pickupDateTime,



    required RentalType rentalType,



    bool unlimitedKm = false,



  }) {



    if (extraKm <= 0 || unlimitedKm) return 0;







    if (selectedKmPackage != null) {



      if (selectedKmPackage.unlimitedKm) return 0;







      final rate = profile.extraKmRateFor(



        package: selectedKmPackage,



        date: pickupDateTime,



      );







      return extraKm * rate;



    }







    if (selectedPackage != null) {



      if (selectedPackage.unlimitedKm) return 0;



      return extraKm * selectedPackage.extraKmRate;



    }







    return 0;



  }







  // ---------------------------------------------------------------------------



  // HOURLY EXTRA TIME



  // ---------------------------------------------------------------------------








  /// Keeps daily pricing based on complete 24-hour blocks and bills only
  /// the remaining time as extra hours.
  ///
  /// Example:
  /// 26 Sep 3 PM -> 27 Sep 4 PM = 25 hours
  /// = 1 full day + 1 extra hour.
  RentalDuration _applyMinimumBookingRules(
    PricingProfile profile,
    RentalDuration duration, {
    required RentalType rentalType,
    String? packageId,
  }) {
    if (duration.totalMinutes <= 0) {
      return duration;
    }

    if (rentalType == RentalType.hourly) {
      final minimumHours =
          profile.minimumHoursFor(packageId ?? '');
      final minimumMinutes = minimumHours * 60;

      if (duration.totalMinutes < minimumMinutes) {
        return RentalDuration(
          totalMinutes: minimumMinutes,
          totalHours: minimumHours.toDouble(),
          billableDays: 1,
          fullDays: 0,
          extraHours: minimumHours,
          extraMinutes: 0,
        );
      }

      return duration;
    }

    final fullDays = duration.totalMinutes ~/ (24 * 60);
    final remainingMinutes = duration.totalMinutes % (24 * 60);

    final configuredMinimumDays =
        profile.minimumDaysFor(packageId ?? '');
    final minimumDays =
        configuredMinimumDays < 1 ? 1 : configuredMinimumDays;

    // Minimum days means the customer pays at least that many daily
    // units. We still retain the real duration so extra-hour billing
    // remains correct when the minimum is already satisfied.
    final billableDays =
        fullDays < minimumDays ? minimumDays : fullDays;

    return RentalDuration(
      totalMinutes: duration.totalMinutes,
      totalHours: duration.totalHours,
      billableDays: billableDays.clamp(1, 100000),
      fullDays: fullDays,
      extraHours: remainingMinutes ~/ 60,
      extraMinutes: remainingMinutes % 60,
    );
  }

  double _calculateExtraTimeCharge(
    PricingProfile profile,
    RentalDuration duration, {
    required RentalType rentalType,
    String? packageId,
  }) {
    if (duration.totalMinutes <= 0 || rentalType == RentalType.hourly) {
      return 0;
    }

    final rate = profile.extraHourRateFor(packageId ?? '');
    if (!rate.isFinite || rate <= 0) return 0;

    if (duration.extraHours <= 0 && duration.extraMinutes <= 0) {
      return 0;
    }

    // Any started extra hour is charged as one extra hour.
    final extraHours =
        duration.extraHours + (duration.extraMinutes > 0 ? 1 : 0);

    return extraHours * rate;
  }

  double _calculateHourlyExtraTimeCharge(



    PricingProfile profile,



    RentalDuration duration,



  ) {



    if (duration.totalMinutes <= 0) return 0;







    // The simplified pricing model does not have a second daily/weekly/monthly



    // time-charge system. Keep this at zero unless the old optional package



    // system is explicitly supplied elsewhere.



    return 0;



  }







  // ---------------------------------------------------------------------------



  // ADD-ONS



  // ---------------------------------------------------------------------------







  double _calculateAddOns(



    List<SelectedAddOn> selectedAddOns,



    int rentalDays,



  ) {



    double total = 0;







    for (final selected in selectedAddOns) {



      if (selected.quantity <= 0) continue;







      final addOn = selected.addOn;







      var quantity = selected.quantity;







      if (addOn.maxQuantity != null &&



          quantity > addOn.maxQuantity!) {



        quantity = addOn.maxQuantity!;



      }







      var price = addOn.price * quantity;







      if (addOn.isPerDay) {



        price *= rentalDays;



      }







      total += price;



    }







    return total;



  }







  // ---------------------------------------------------------------------------



  // PROTECTION



  // ---------------------------------------------------------------------------







  double _calculateProtection(



    ProtectionPlan? protection,



    int rentalDays,



  ) {



    if (protection == null || !protection.isActive) {



      return 0;



    }







    if (protection.isPerDay) {



      return protection.price * rentalDays;



    }







    return protection.price;



  }







  // ---------------------------------------------------------------------------



  // DISCOUNT



  // ---------------------------------------------------------------------------







  double _calculateDiscount(



    DiscountRule? discount,



    double subtotal,



    int rentalDays,



    DateTime pickupDateTime,



  ) {



    if (discount == null || !discount.isActive) {



      return 0;



    }







    if (subtotal < discount.minimumBookingAmount) {



      return 0;



    }







    if (discount.minimumRentalDays != null &&



        rentalDays < discount.minimumRentalDays!) {



      return 0;



    }







    if (discount.validFrom != null &&



        pickupDateTime.isBefore(discount.validFrom!)) {



      return 0;



    }







    if (discount.validUntil != null &&



        pickupDateTime.isAfter(discount.validUntil!)) {



      return 0;



    }







    if (discount.applicableWeekdays.isNotEmpty &&



        !discount.applicableWeekdays.contains(



          pickupDateTime.weekday,



        )) {



      return 0;



    }







    double amount = 0;







    switch (discount.type) {



      case DiscountType.percentage:



        amount = subtotal *



            discount.percentage /



            100;



        break;







      case DiscountType.fixedAmount:



        amount = discount.fixedAmount;



        break;



    }







    if (discount.maximumDiscount != null &&



        amount > discount.maximumDiscount!) {



      amount = discount.maximumDiscount!;



    }







    return amount.clamp(0, subtotal).toDouble();



  }







  // ---------------------------------------------------------------------------



  // TAX



  // ---------------------------------------------------------------------------







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



        .where((tax) => tax.isActive)



        .toList();







    for (final tax in activeTaxes) {



      double taxableAmount = 0;







      if (tax.appliesToRental) {



        taxableAmount += rentalAmount;



      }







      if (tax.appliesToExtraKm) {



        taxableAmount += extraKmAmount;



      }







      if (tax.appliesToAddOns) {



        taxableAmount += addOnAmount;



      }







      if (tax.appliesToProtection) {



        taxableAmount += protectionAmount;



      }







      if (tax.appliesToExtraCharges) {



        taxableAmount += extraChargeAmount;



      }







      taxableAmount = (taxableAmount - discountAmount)



          .clamp(0, double.infinity)



          .toDouble();







      if (tax.percentage <= 0) continue;







      if (tax.isInclusive) {



        final taxAmount = taxableAmount -



            (taxableAmount /



                (1 + tax.percentage / 100));







        totalTax += taxAmount;



      } else {



        totalTax +=



            taxableAmount *



            tax.percentage /



            100;



      }



    }







    return totalTax;



  }







  // ---------------------------------------------------------------------------



  // DURATION



  // ---------------------------------------------------------------------------







  RentalDuration _calculateDuration(



    DateTime pickup,



    DateTime returnTime,



  ) {



    final difference = returnTime.difference(pickup);



    final totalMinutes = difference.inMinutes;



    final totalHours = totalMinutes / 60;







    // One daily billing unit is 24 hours. A partial day counts as one full



    // billing day. This keeps pricing predictable for timestamp-based booking.



    final fullDays = totalMinutes ~/ (24 * 60);
    final remainingMinutes = totalMinutes % (24 * 60);

    return RentalDuration(
      totalMinutes: totalMinutes,
      totalHours: totalHours,
      // A daily booking has at least one billable day. Remaining time does
      // not become another day; it is handled as extra-hour pricing.
      // Example: 25 hours = 1 full day + 1 extra hour.
      billableDays: fullDays < 1 ? 1 : fullDays,
      fullDays: fullDays,
      extraHours: remainingMinutes ~/ 60,
      extraMinutes: remainingMinutes % 60,
    );



  }



}







/// ============================================================================



/// SELECTED ADD-ON



/// ============================================================================







class SelectedAddOn {



  final AddOn addOn;



  final int quantity;







  const SelectedAddOn({



    required this.addOn,



    this.quantity = 1,



  });



}







/// ============================================================================



/// RENTAL DURATION



/// ============================================================================







class RentalDuration {



  final int totalMinutes;



  final double totalHours;



  final int billableDays;

  final int fullDays;
  final int extraHours;
  final int extraMinutes;

  const RentalDuration({
    required this.totalMinutes,
    required this.totalHours,
    required this.billableDays,
    this.fullDays = 0,
    this.extraHours = 0,
    this.extraMinutes = 0,
  });



}







/// ============================================================================



/// PRICING RESULT



/// ============================================================================







class PricingResult {



  final String pricingProfileId;



  final String rentalType;







  /// Kept for booking snapshot compatibility.



  ///



  /// New simplified profiles do not maintain a mutable pricing version.



  final int pricingVersion;







  final String? specialPricingRuleId;







  final double rentalPrice;







  final int includedKm;



  final int actualKm;



  final int plannedKm;



  final int extraKm;







  final int? selectedKm;







  final String? selectedKmPackageId;



  final String? selectedKmPackageName;



  final double? selectedKmPackageExtraKmRate;







  final bool unlimitedKm;







  final double extraKmCharge;



  final double extraTimeCharge;

  final int minimumHours;
  final int minimumDays;
  final int fullDays;
  final int extraHours;
  final int extraMinutes;

  final double addOnTotal;



  final double protectionTotal;







  final double subtotal;



  final double discountAmount;



  final double taxableAmount;



  final double taxAmount;







  /// Monetary security deposit only.



  ///



  /// Asset deposits are intentionally 0 here because they do not increase



  /// the monetary amount payable.



  final double securityDeposit;







  /// Trip total excludes security deposit.



  final double total;







  /// Trip total + monetary security deposit.



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



    required this.minimumHours,



    required this.minimumDays,



    required this.fullDays,



    required this.extraHours,



    required this.extraMinutes,



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







  factory PricingResult.empty() {



    return const PricingResult(



      pricingProfileId: '',



      rentalType: 'daily',



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
      minimumHours: 1,
      minimumDays: 1,
      fullDays: 0,
      extraHours: 0,
      extraMinutes: 0,
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







  double get tripTotal => total;







  double get refundableDeposit => securityDeposit;



}
