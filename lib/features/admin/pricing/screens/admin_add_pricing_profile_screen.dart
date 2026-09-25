import 'package:flutter/material.dart';



import '../../../../core/config/app_config.dart';

import '../../../pricing/models/km_pricing_package.dart';

import '../../../pricing/models/pricing_profile.dart';

import '../../../pricing/services/pricing_profile_service.dart';



/// Admin screen for creating a simple vehicle/pricing-group pricing profile.

///

/// Pricing model:

///   - Hourly rental

///   - Daily rental

///   - KM packages

///   - Special date-rate overrides

///   - Security deposit

///

/// Removed from the old screen:

///   - Weekend rental type

///   - Weekly rental

///   - Monthly rental

///   - Per-KM pricing mode

///   - KM slabs as the primary pricing mechanism

///   - Unlimited surcharge

///   - Legacy minimum billing settings

///   - Legacy RentalTypePricing

///   - Legacy SpecialPricingRule

///

/// The source of truth is PricingProfile + KmPricingPackage.

class AdminAddPricingProfileScreen extends StatefulWidget {

  const AdminAddPricingProfileScreen({

    super.key,

  });



  @override

  State<AdminAddPricingProfileScreen> createState() =>

      _AdminAddPricingProfileScreenState();

}



class _AdminAddPricingProfileScreenState

    extends State<AdminAddPricingProfileScreen> {

  static const Color background = Color(0xFFF8FAF9);

  static const Color card = Color(0xFFFFFFFF);

  static const Color primary = Color(0xFF0F766E);

  static const Color accent = Color(0xFF14B8A6);

  static const Color softAccent = Color(0xFFE6FFFB);

  static const Color heading = Color(0xFF17201F);

  static const Color body = Color(0xFF66706E);

  static const Color muted = Color(0xFF94A09D);

  static const Color border = Color(0xFFE5EBE9);



  final _formKey = GlobalKey<FormState>();



  final TextEditingController _nameController =

      TextEditingController();



  final TextEditingController _pricingGroupController =

      TextEditingController();



  final TextEditingController _depositController =

      TextEditingController();



  final TextEditingController _minimumAssetValueController =

      TextEditingController();



  final TextEditingController _specialRuleNameController =

      TextEditingController();



  final TextEditingController _specialHourlyController =

      TextEditingController();



  final TextEditingController _specialDailyController =

      TextEditingController();



  final TextEditingController _specialExtraKmController =

      TextEditingController();
bool _isActive = true;
bool _isSaving = false;



  bool _hourlyEnabled = true;

  bool _dailyEnabled = true;



  DepositType _depositType = DepositType.none;



  bool _specialRuleEnabled = false;

  DateTime? _specialStartDate;

  DateTime? _specialEndDate;



  final List<_PackageDraft> _packages = [];



  String get tenantId =>

      AppConfig.tenant.tenantId;



  @override
  void initState() {
    super.initState();
  }



  @override

  void dispose() {

    _nameController.dispose();

    _pricingGroupController.dispose();

    _depositController.dispose();

    _minimumAssetValueController.dispose();

    _specialRuleNameController.dispose();

    _specialHourlyController.dispose();

    _specialDailyController.dispose();

    _specialExtraKmController.dispose();



    for (final package in _packages) {

      package.dispose();

    }



    super.dispose();

  }





  // ===========================================================================

  // PACKAGES

  // ===========================================================================



  void _addPackage() {

    setState(() {

      _packages.add(

        _PackageDraft(),

      );

    });

  }



  void _removePackage(int index) {

    final package = _packages[index];



    setState(() {

      _packages.removeAt(index);

    });



    package.dispose();

  }



  // ===========================================================================

  // SAVE

  // ===========================================================================



  Future<void> _save() async {

    if (!_formKey.currentState!.validate()) {

      return;

    }
    if (_packages.isEmpty) {

      _showSnackBar(

        'Add at least one KM package.',

        isError: true,

      );

      return;

    }



    final packages =

        _packages.map(_buildPackage).toList();



    final activePackages = packages

        .where(

          (package) => package.isActive,

        )

        .toList();



    if (activePackages.isEmpty) {

      _showSnackBar(

        'At least one package must be active.',

        isError: true,

      );

      return;

    }



    if (_hourlyEnabled &&

        !activePackages.any(

          (package) => package.supportsHourly,

        )) {

      _showSnackBar(

        'Hourly rental is enabled, but no active package has an hourly price.',

        isError: true,

      );

      return;

    }



    if (_dailyEnabled &&

        !activePackages.any(

          (package) => package.supportsDaily,

        )) {

      _showSnackBar(

        'Daily rental is enabled, but no active package has a daily price.',

        isError: true,

      );

      return;

    }



    if (!_hourlyEnabled && !_dailyEnabled) {

      _showSnackBar(

        'Enable at least one rental type.',

        isError: true,

      );

      return;

    }



    if (_specialRuleEnabled) {

      if (_specialStartDate == null ||

          _specialEndDate == null) {

        _showSnackBar(

          'Select the special-rate start and end dates.',

          isError: true,

        );

        return;

      }



      if (_specialEndDate!.isBefore(

        _specialStartDate!,

      )) {

        _showSnackBar(

          'Special-rate end date cannot be before the start date.',

          isError: true,

        );

        return;

      }

    }



    setState(() {

      _isSaving = true;

    });



    try {

      final hourlyPackages = activePackages

          .where(

            (package) => package.supportsHourly,

          )

          .toList();



      final dailyPackages = activePackages

          .where(

            (package) => package.supportsDaily,

          )

          .toList();

      final minimumHoursByPackageId =
          <String, int>{};
      final minimumDaysByPackageId =
          <String, int>{};
      final extraHourRateByPackageId =
          <String, double>{};

      for (final draft in _packages) {
        final builtPackage = _buildPackage(draft);
        final packageId = builtPackage.id.trim();

        if (_hourlyEnabled && builtPackage.supportsHourly) {
          minimumHoursByPackageId[packageId] =
              _positiveIntOrDefault(
            draft.minimumHoursController.text,
            1,
          );
        }

        if (_dailyEnabled && builtPackage.supportsDaily) {
          minimumDaysByPackageId[packageId] =
              _positiveIntOrDefault(
            draft.minimumDaysController.text,
            1,
          );
        }

        extraHourRateByPackageId[packageId] =
            _nonNegativeDouble(
          draft.extraHourController.text,
        );
      }

      final profile =
          PricingProfile(

        id: '',

        tenantId: tenantId,

        // Reusable profile: cars are connected after creation.
        vehicleId: '',

        pricingGroupId:

            _pricingGroupController.text.trim(),

        name:

            _nameController.text.trim(),

        currency:

            AppConfig.tenant.business.currency,

        hourlyPackages:

            _hourlyEnabled

                ? hourlyPackages

                : const [],

        dailyPackages:

            _dailyEnabled

                ? dailyPackages

                : const [],

        specialRates:

            _buildSpecialRates(

          activePackages,

        ),

        securityDeposit:

            _buildDepositConfig(),

        
        minimumHoursByPackageId:
            Map<String, int>.unmodifiable(
          minimumHoursByPackageId,
        ),
        minimumDaysByPackageId:
            Map<String, int>.unmodifiable(
          minimumDaysByPackageId,
        ),
        extraHourRateByPackageId:
            Map<String, double>.unmodifiable(
          extraHourRateByPackageId,
        ),
        isActive: _isActive,

      );



      final errors = _validatePricingProfile(profile);



      if (errors.isNotEmpty) {

        throw Exception(errors.join('\n'));

      }



      await PricingProfileService.instance

          .createPricingProfile(

        tenantId: tenantId,

        profile: profile,

      );



      if (!mounted) return;



      _showSnackBar(

        'Pricing profile created successfully. Connect cars from Edit Pricing Profile.',

      );



      Navigator.pop(

        context,

        true,

      );

    } catch (e) {

      if (!mounted) return;



      _showSnackBar(

        e.toString().replaceFirst(

              'Exception: ',

              '',

            ),

        isError: true,

      );

    } finally {

      if (mounted) {

        setState(() {

          _isSaving = false;

        });

      }

    }

  }



  KmPricingPackage _buildPackage(

    _PackageDraft draft,

  ) {

    final id = draft.idController.text

        .trim()

        .isEmpty

        ? 'package_${DateTime.now().microsecondsSinceEpoch}'

        : draft.idController.text.trim();



    return KmPricingPackage(

      id: id,

      name: draft.nameController.text.trim(),

      includedKm: draft.unlimited

          ? null

          : _nullablePositiveInt(

              draft.kmController.text,

            ),

      unlimitedKm: draft.unlimited,

      isActive: draft.isActive,

      hourlyRate:

          _nonNegativeDouble(

        draft.hourlyController.text,

      ),

      dailyRate:

          _nonNegativeDouble(

        draft.dailyController.text,

      ),

      extraKmRate:

          _nonNegativeDouble(

        draft.extraKmController.text,

      ),

    );

  }



  List<SpecialRate> _buildSpecialRates(

    List<KmPricingPackage> packages,

  ) {

    if (!_specialRuleEnabled ||

        _specialStartDate == null ||

        _specialEndDate == null) {

      return const [];

    }



    final hourlyPrice =

        _nonNegativeDouble(

      _specialHourlyController.text,

    );



    final dailyPrice =

        _nonNegativeDouble(

      _specialDailyController.text,

    );



    final extraKm =

        _nonNegativeDouble(

      _specialExtraKmController.text,

    );



    final hourlyPrices =

        <String, double>{};



    final dailyPrices =

        <String, double>{};



    for (final package in packages) {

      if (package.supportsHourly &&

          _hourlyEnabled &&

          hourlyPrice > 0) {

        hourlyPrices[package.id] =

            hourlyPrice;

      }



      if (package.supportsDaily &&

          _dailyEnabled &&

          dailyPrice > 0) {

        dailyPrices[package.id] =

            dailyPrice;

      }

    }



    return [

      SpecialRate(

        id:

            'special_${DateTime.now().microsecondsSinceEpoch}',

        name:

            _specialRuleNameController.text.trim().isEmpty

                ? 'Special Pricing'

                : _specialRuleNameController.text.trim(),

        startDate:

            _dateOnly(_specialStartDate!),

        endDate:

            _dateOnly(_specialEndDate!),

        isActive: true,

        hourlyPrices:

            Map<String, double>.unmodifiable(

          hourlyPrices,

        ),

        dailyPrices:

            Map<String, double>.unmodifiable(

          dailyPrices,

        ),

        extraKmRate:

            extraKm > 0 ? extraKm : null,

      ),

    ];

  }



  DepositConfig _buildDepositConfig() {

    if (_depositType ==

        DepositType.none) {

      return const DepositConfig(

        type: DepositType.none,

      );

    }



    final amount =

        _nonNegativeDouble(

      _depositController.text,

    );



    final minimumAssetValue =

        _nonNegativeDouble(

      _minimumAssetValueController.text,

    );



    return DepositConfig(

      type: _depositType,

      amount:

          _depositType.isMonetary

              ? amount

              : 0,

      paymentMethod:

          _depositType.isMonetary

              ? _depositPaymentMethod(

                  _depositType,

                )

              : '',

      assetDescription:

          _depositType ==

                  DepositType.vehicleAsset

              ? 'Customer vehicle/bike held as security'

              : _depositType ==

                      DepositType.otherAsset

                  ? 'Other customer asset held as security'

                  : '',

      minimumAssetValue:

          _depositType.isAsset

              ? minimumAssetValue

              : 0,

    );

  }



  String _depositPaymentMethod(

    DepositType type,

  ) {

    switch (type) {

      case DepositType.cash:

        return 'cash';

      case DepositType.online:

        return 'online';

      case DepositType.bankTransfer:

        return 'bank_transfer';

      default:

        return '';

    }

  }



  /// Local validation for the simplified PricingProfile model.

  ///

  /// The simplified model intentionally has no `validate()` method returning

  /// a List<String>. Validation belongs here so this screen does not depend

  /// on the legacy PricingProfile validation API.

  List<String> _validatePricingProfile(PricingProfile profile) {

    final errors = <String>[];



    if (profile.tenantId.trim().isEmpty) {

      errors.add('Tenant ID is required.');

    }



    if (profile.name.trim().isEmpty) {

      errors.add('Pricing profile name is required.');

    }



    if (profile.currency.trim().isEmpty) {

      errors.add('Currency is required.');

    }



    if (profile.hourlyPackages.isEmpty &&

        profile.dailyPackages.isEmpty) {

      errors.add('At least one hourly or daily pricing package is required.');

    }



    for (final package in [

      ...profile.hourlyPackages,

      ...profile.dailyPackages,

    ]) {

      if (package.id.trim().isEmpty) {

        errors.add('Every KM package must have an ID.');

      }

      if (package.name.trim().isEmpty) {

        errors.add('Every KM package must have a name.');

      }

      if (!package.unlimitedKm &&

          (package.includedKm == null || package.includedKm! < 0)) {

        errors.add(

          'Package "${package.name}" must have a valid included KM value or be unlimited.',

        );

      }

      if (package.safeHourlyRate < 0 || package.safeDailyRate < 0) {

        errors.add('Package "${package.name}" has an invalid rental price.');

      }

      if (package.safeExtraKmRate < 0) {

        errors.add('Package "${package.name}" has an invalid extra KM rate.');

      }

    }



    for (final rate in profile.specialRates) {

      if (rate.name.trim().isEmpty) {

        errors.add('Special-rate name is required.');

      }

      if (rate.endDate.isBefore(rate.startDate)) {

        errors.add(

          'Special-rate "${rate.name}" has an invalid date range.',

        );

      }

      for (final price in rate.hourlyPrices.values) {

        if (!price.isFinite || price < 0) {

          errors.add('A special hourly price is invalid.');

          break;

        }

      }

      for (final price in rate.dailyPrices.values) {

        if (!price.isFinite || price < 0) {

          errors.add('A special daily price is invalid.');

          break;

        }

      }

      if (rate.extraKmRate != null &&

          (!rate.extraKmRate!.isFinite || rate.extraKmRate! < 0)) {

        errors.add('A special extra KM rate is invalid.');

      }

    }



    final deposit = profile.securityDeposit;

    if (deposit.amount < 0) {

      errors.add('Security deposit amount cannot be negative.');

    }

    if (deposit.minimumAssetValue < 0) {

      errors.add('Minimum security asset value cannot be negative.');

    }



    return errors.toSet().toList();

  }



  // ===========================================================================

  // SPECIAL DATE PICKER

  // ===========================================================================



  Future<void> _pickSpecialDate({

    required bool start,

  }) async {

    final initial = start

        ? (_specialStartDate ??

            DateTime.now())

        : (_specialEndDate ??

            _specialStartDate ??

            DateTime.now());



    final picked =

        await showDatePicker(

      context: context,

      initialDate: initial,

      firstDate: DateTime(2020),

      lastDate: DateTime(2100),

    );



    if (picked == null ||

        !mounted) {

      return;

    }



    setState(() {

      if (start) {

        _specialStartDate = picked;



        if (_specialEndDate != null &&

            _specialEndDate!.isBefore(

              picked,

            )) {

          _specialEndDate = picked;

        }

      } else {

        _specialEndDate = picked;

      }

    });

  }



  String _formatDate(

    DateTime? date,

  ) {

    if (date == null) {

      return 'Select date';

    }



    return '${date.day.toString().padLeft(2, '0')}/'

        '${date.month.toString().padLeft(2, '0')}/'

        '${date.year}';

  }



  DateTime _dateOnly(

    DateTime date,

  ) {

    return DateTime(

      date.year,

      date.month,

      date.day,

    );

  }



  // ===========================================================================

  // BUILD

  // ===========================================================================



  @override

  Widget build(

    BuildContext context,

  ) {

    return Scaffold(

      backgroundColor: background,

      appBar: AppBar(

        backgroundColor: background,

        surfaceTintColor:

            Colors.transparent,

        elevation: 0,

        title: const Text(

          'Add Pricing Profile',

          style: TextStyle(

            fontFamily: 'Manrope',

            fontSize: 21,

            fontWeight:

                FontWeight.w800,

            color: heading,

          ),

        ),

      ),

      body: Form(

        key: _formKey,

        child: ListView(

          padding:

              const EdgeInsets.fromLTRB(

            20,

            6,

            20,

            40,

          ),

          children: [




            _section(

              title: 'Profile Details',

              subtitle:

                  'Create one reusable pricing profile that can be connected to multiple cars.',

              icon: Icons.badge_outlined,

              child: Column(

                children: [

                  _field(

                    controller:

                        _nameController,

                    label:

                        'Pricing profile name',

                    hint:

                        'e.g. Premium SUV Standard',

                    validator:

                        _required,

                  ),

                  const SizedBox(

                    height: 14,

                  ),

                  _field(

                    controller:

                        _pricingGroupController,

                    label:

                        'Pricing group ID',

                    hint:

                        'e.g. premium_suv',

                    helper:

                        'Use the same group ID when multiple cars should share the same pricing.',

                  ),

                  const SizedBox(

                    height: 14,

                  ),

                  _readOnlyCurrency(),

                ],

              ),

            ),

            const SizedBox(height: 16),



                        _section(
              title: 'Car Connection',
              subtitle:
                  'Create the pricing profile first. Connect one or many cars after saving.',
              icon: Icons.link_rounded,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: softAccent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: primary,
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This profile is reusable. After creation, open Edit Pricing Profile → Connected Cars to connect as many cars as you want.',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 11.5,
                          height: 1.45,
                          color: body,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

_section(

              title: 'Rental Types',

              subtitle:

                  'This pricing system supports hourly and daily rentals only.',

              icon:

                  Icons.access_time_rounded,

              child:

                  _rentalTypeSettings(),

            ),

            const SizedBox(height: 16),



            _section(

              title: 'KM Packages',

              subtitle:

                  'Create packages such as 150 KM, 500 KM, 1000 KM or Unlimited. Daily included KM is multiplied by the number of billable rental days. Extra hours use the package extra-hour rate.',

              icon:

                  Icons.route_outlined,

              child:

                  _packageFields(),

            ),

            const SizedBox(height: 16),



            _section(

              title: 'Special Date Pricing',

              subtitle:

                  'Use a date range for holidays, festivals, weekends or high-season pricing.',

              icon:

                  Icons.event_available_outlined,

              child:

                  _specialPricingFields(),

            ),

            const SizedBox(height: 16),



            _section(

              title: 'Security Deposit',

              subtitle:

                  'The security deposit is separate from the trip total.',

              icon:

                  Icons.account_balance_wallet_outlined,

              child:

                  _depositFields(),

            ),

            const SizedBox(height: 16),



            _section(

              title: 'Status',

              subtitle:

                  'Inactive profiles cannot be used for new bookings.',

              icon:

                  Icons.toggle_on_outlined,

              child:

                  SwitchListTile.adaptive(

                contentPadding:

                    EdgeInsets.zero,

                activeColor: primary,

                title:

                    const Text(

                  'Active pricing profile',

                  style: TextStyle(

                    fontFamily:

                        'Manrope',

                    fontSize: 14,

                    fontWeight:

                        FontWeight.w700,

                    color: heading,

                  ),

                ),

                subtitle:

                    const Text(

                  'Enable this profile immediately.',

                  style: TextStyle(

                    fontFamily:

                        'Manrope',

                    fontSize: 12,

                    color: body,

                  ),

                ),

                value: _isActive,

                onChanged: (value) {

                  setState(() {

                    _isActive = value;

                  });

                },

              ),

            ),

            const SizedBox(height: 24),



            SizedBox(

              height: 52,

              child:

                  ElevatedButton(

                onPressed:

                    _isSaving

                        ? null

                        : _save,

                style:

                    ElevatedButton.styleFrom(

                  backgroundColor:

                      primary,

                  foregroundColor:

                      Colors.white,

                  disabledBackgroundColor:

                      primary.withValues(

                    alpha: 0.5,

                  ),

                  elevation: 0,

                  shape:

                      RoundedRectangleBorder(

                    borderRadius:

                        BorderRadius.circular(

                      15,

                    ),

                  ),

                ),

                child: _isSaving

                    ? const SizedBox(

                        width: 21,

                        height: 21,

                        child:

                            CircularProgressIndicator(

                          strokeWidth: 2.2,

                          color:

                              Colors.white,

                        ),

                      )

                    : const Text(

                        'Create Pricing Profile',

                        style:

                            TextStyle(

                          fontFamily:

                              'Manrope',

                          fontSize: 14,

                          fontWeight:

                              FontWeight.w800,

                        ),

                      ),

              ),

            ),

          ],

        ),

      ),

    );

  }





  // ===========================================================================

  // RENTAL TYPES

  // ===========================================================================



  Widget _rentalTypeSettings() {

    return Column(

      children: [

        _rentalTypeTile(

          title: 'Hourly rental',

          subtitle:

              'Uses the package hourly price. Availability uses exact pickup and return timestamps.',

          value:

              _hourlyEnabled,

          onChanged: (value) {

            setState(() {

              _hourlyEnabled =

                  value;

            });

          },

        ),

        const Divider(

          height: 20,

          color: border,

        ),

        _rentalTypeTile(

          title: 'Daily rental',

          subtitle:

              'Uses the package daily price. Included KM is multiplied by the number of rental days.',

          value:

              _dailyEnabled,

          onChanged: (value) {

            setState(() {

              _dailyEnabled =

                  value;

            });

          },

        ),

        const SizedBox(height: 10),

        Container(

          width:

              double.infinity,

          padding:

              const EdgeInsets.all(12),

          decoration:

              BoxDecoration(

            color: softAccent,

            borderRadius:

                BorderRadius.circular(

              12,

            ),

          ),

          child: const Row(

            children: [

              Icon(

                Icons.info_outline,

                size: 18,

                color: primary,

              ),

              SizedBox(width: 9),

              Expanded(

                child: Text(

                  'Weekend, weekly and monthly rentals are no longer separate rental types. Weekend/holiday/festival changes are handled through Special Date Pricing. Set minimum hours/days and extra-hour pricing inside each KM package.',

                  style: TextStyle(

                    fontFamily:

                        'Manrope',

                    fontSize: 11.5,

                    height: 1.4,

                    color: body,

                  ),

                ),

              ),

            ],

          ),

        ),

      ],

    );

  }



  Widget _rentalTypeTile({

    required String title,

    required String subtitle,

    required bool value,

    required ValueChanged<bool>

        onChanged,

  }) {

    return SwitchListTile.adaptive(

      contentPadding:

          EdgeInsets.zero,

      activeColor: primary,

      title: Text(

        title,

        style:

            const TextStyle(

          fontFamily: 'Manrope',

          fontSize: 13.5,

          fontWeight:

              FontWeight.w800,

          color: heading,

        ),

      ),

      subtitle: Text(

        subtitle,

        style:

            const TextStyle(

          fontFamily: 'Manrope',

          fontSize: 11.5,

          height: 1.35,

          color: body,

        ),

      ),

      value: value,

      onChanged: onChanged,

    );

  }



  // ===========================================================================

  // PACKAGES

  // ===========================================================================


Widget _readOnlyCurrency() {
  final currency = AppConfig.tenant.business.currency.trim();

  return InputDecorator(
    decoration: _decoration(
      'Currency',
      'Configured business currency',
    ),
    child: Row(
      children: [
        const Icon(
          Icons.currency_exchange_rounded,
          size: 18,
          color: primary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            currency.isEmpty ? 'Not configured' : currency,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: heading,
            ),
          ),
        ),
        const Icon(
          Icons.lock_outline_rounded,
          size: 16,
          color: muted,
        ),
      ],
    ),
  );
}
  Widget _packageFields() {

    return Column(

      crossAxisAlignment:

          CrossAxisAlignment.start,

      children: [

        Row(

          children: [

            const Expanded(

              child: Text(

                'KM Packages',

                style: TextStyle(

                  fontFamily:

                      'Manrope',

                  fontSize: 14,

                  fontWeight:

                      FontWeight.w800,

                  color: heading,

                ),

              ),

            ),

            TextButton.icon(

              onPressed:

                  _addPackage,

              icon:

                  const Icon(

                Icons.add_rounded,

                size: 18,

              ),

              label:

                  const Text('Add'),

              style:

                  TextButton.styleFrom(

                foregroundColor:

                    primary,

                textStyle:

                    const TextStyle(

                  fontFamily:

                      'Manrope',

                  fontWeight:

                      FontWeight.w700,

                ),

              ),

            ),

          ],

        ),

        const SizedBox(height: 6),

        if (_packages.isEmpty)

          Container(

            width:

                double.infinity,

            padding:

                const EdgeInsets.all(

              16,

            ),

            decoration:

                BoxDecoration(

              color: background,

              borderRadius:

                  BorderRadius.circular(

                14,

              ),

              border: Border.all(

                color: border,

              ),

            ),

            child:

                const Text(

              'No packages added yet. Add packages such as 150 KM, 500 KM, 1000 KM or Unlimited.',

              style: TextStyle(

                fontFamily:

                    'Manrope',

                fontSize: 12,

                height: 1.5,

                color: body,

              ),

            ),

          ),

        ...List.generate(

          _packages.length,

          (index) =>

              _packageCard(

            index,

            _packages[index],

          ),

        ),

      ],

    );

  }



  Widget _packageCard(

    int index,

    _PackageDraft package,

  ) {

    return Container(

      margin:

          const EdgeInsets.only(

        top: 12,

      ),

      padding:

          const EdgeInsets.all(15),

      decoration:

          BoxDecoration(

        color: background,

        borderRadius:

            BorderRadius.circular(

          17,

        ),

        border: Border.all(

          color: border,

        ),

      ),

      child: Column(

        children: [

          Row(

            children: [

              Container(

                width: 34,

                height: 34,

                decoration:

                    BoxDecoration(

                  color: softAccent,

                  borderRadius:

                      BorderRadius.circular(

                    10,

                  ),

                ),

                child:

                    const Icon(

                  Icons

                      .inventory_2_outlined,

                  size: 18,

                  color: primary,

                ),

              ),

              const SizedBox(

                width: 10,

              ),

              Expanded(

                child: Text(

                  'Package ${index + 1}',

                  style:

                      const TextStyle(

                    fontFamily:

                        'Manrope',

                    fontSize: 13,

                    fontWeight:

                        FontWeight.w800,

                    color: heading,

                  ),

                ),

              ),

              IconButton(

                onPressed:

                    () =>

                        _removePackage(

                  index,

                ),

                icon:

                    const Icon(

                  Icons

                      .delete_outline_rounded,

                  color: muted,

                  size: 20,

                ),

              ),

            ],

          ),

          const SizedBox(

            height: 10,

          ),

          _field(

            controller:

                package.idController,

            label:

                'Package ID',

            hint:

                'creta_500',

            validator:

                _required,

          ),

          const SizedBox(

            height: 10,

          ),

          _field(

            controller:

                package.nameController,

            label:

                'Package name',

            hint:

                '500 KM',

            validator:

                _required,

          ),

          const SizedBox(

            height: 10,

          ),

          SwitchListTile.adaptive(

            contentPadding:

                EdgeInsets.zero,

            activeColor:

                primary,

            title:

                const Text(

              'Unlimited KM',

              style:

                  TextStyle(

                fontFamily:

                    'Manrope',

                fontSize: 13,

                fontWeight:

                    FontWeight.w700,

                color: heading,

              ),

            ),

            subtitle:

                const Text(

              'Unlimited packages ignore extra-KM calculation.',

              style:

                  TextStyle(

                fontFamily:

                    'Manrope',

                fontSize: 11,

                color: body,

              ),

            ),

            value:

                package.unlimited,

            onChanged:

                (value) {

              setState(() {

                package.unlimited =

                    value;

              });

            },

          ),

          if (!package.unlimited)

            _field(

              controller:

                  package.kmController,

              label:

                  'Included KM',

              hint:

                  '500',

              keyboardType:

                  TextInputType.number,

              validator:

                  _positiveOrEmpty,

            ),

          const SizedBox(

            height: 10,

          ),

          Row(

            children: [

              Expanded(

                child: _field(

                  controller:

                      package.hourlyController,

                  label:

                      'Hourly price',

                  hint:

                      '499',

                  keyboardType:

                      TextInputType.number,

                  validator:

                      _nonNegativeValidator,

                ),

              ),

              const SizedBox(

                width: 10,

              ),

              Expanded(

                child: _field(

                  controller:

                      package.dailyController,

                  label:

                      'Daily price',

                  hint:

                      '3199',

                  keyboardType:

                      TextInputType.number,

                  validator:

                      _nonNegativeValidator,

                ),

              ),

            ],

          ),

          const SizedBox(

            height: 10,

          ),

          _field(

            controller:

                package.extraKmController,

            label:

                'Extra KM rate',

            hint:

                '14',

            keyboardType:

                TextInputType.number,

            validator:

                _nonNegativeValidator,

          ),

          
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _field(
                  controller:
                      package.minimumHoursController,
                  label:
                      'Minimum hours',
                  hint:
                      '1',
                  keyboardType:
                      TextInputType.number,
                  validator:
                      _positiveIntegerValidator,
                  helper:
                      'Minimum hourly booking',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _field(
                  controller:
                      package.minimumDaysController,
                  label:
                      'Minimum days',
                  hint:
                      '1',
                  keyboardType:
                      TextInputType.number,
                  validator:
                      _positiveIntegerValidator,
                  helper:
                      'Minimum daily booking',
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          _field(
            controller:
                package.extraHourController,
            label:
                'Extra hour charge',
            hint:
                '300',
            keyboardType:
                TextInputType.number,
            validator:
                _nonNegativeValidator,
            helper:
                '25 hours = 1 day + 1 extra hour, not 2 days.',
          ),

          const SizedBox(

            height: 4,

          ),

          SwitchListTile.adaptive(

            contentPadding:

                EdgeInsets.zero,

            activeColor:

                primary,

            title:

                const Text(

              'Package active',

              style:

                  TextStyle(

                fontFamily:

                    'Manrope',

                fontSize: 12.5,

                fontWeight:

                    FontWeight.w700,

                color: heading,

              ),

            ),

            value:

                package.isActive,

            onChanged:

                (value) =>

                    setState(

              () =>

                  package.isActive =

                      value,

            ),

          ),

        ],

      ),

    );

  }



  // ===========================================================================

  // SPECIAL PRICING

  // ===========================================================================



  Widget _specialPricingFields() {

    return Column(

      crossAxisAlignment:

          CrossAxisAlignment.start,

      children: [

        SwitchListTile.adaptive(

          contentPadding:

              EdgeInsets.zero,

          activeColor: primary,

          title:

              const Text(

            'Enable special pricing',

            style:

                TextStyle(

              fontFamily:

                  'Manrope',

              fontSize: 13.5,

              fontWeight:

                  FontWeight.w800,

              color: heading,

            ),

          ),

          subtitle:

              const Text(

            'Use this for weekends, holidays, festivals or high-season date ranges.',

            style:

                TextStyle(

              fontFamily:

                  'Manrope',

              fontSize: 11.5,

              color: body,

            ),

          ),

          value:

              _specialRuleEnabled,

          onChanged:

              (value) {

            setState(() {

              _specialRuleEnabled =

                  value;

            });

          },

        ),

        if (_specialRuleEnabled) ...[

          const SizedBox(

            height: 8,

          ),

          _field(

            controller:

                _specialRuleNameController,

            label:

                'Rule name',

            hint:

                'Diwali / Peak Season / Weekend',

            validator:

                _required,

          ),

          const SizedBox(

            height: 10,

          ),

          Row(

            children: [

              Expanded(

                child:

                    _datePickerField(

                  label:

                      'Start date',

                  value:

                      _formatDate(

                    _specialStartDate,

                  ),

                  onTap:

                      () =>

                          _pickSpecialDate(

                    start: true,

                  ),

                ),

              ),

              const SizedBox(

                width: 10,

              ),

              Expanded(

                child:

                    _datePickerField(

                  label:

                      'End date',

                  value:

                      _formatDate(

                    _specialEndDate,

                  ),

                  onTap:

                      () =>

                          _pickSpecialDate(

                    start: false,

                  ),

                ),

              ),

            ],

          ),

          const SizedBox(

            height: 10,

          ),

          Row(

            children: [

              Expanded(

                child: _field(

                  controller:

                      _specialHourlyController,

                  label:

                      'Special hourly price',

                  hint:

                      '599',

                  keyboardType:

                      TextInputType.number,

                  validator:

                      _nonNegativeValidator,

                ),

              ),

              const SizedBox(

                width: 10,

              ),

              Expanded(

                child: _field(

                  controller:

                      _specialDailyController,

                  label:

                      'Special daily price',

                  hint:

                      '2999',

                  keyboardType:

                      TextInputType.number,

                  validator:

                      _nonNegativeValidator,

                ),

              ),

            ],

          ),

          const SizedBox(

            height: 10,

          ),

          _field(

            controller:

                _specialExtraKmController,

            label:

                'Special extra KM rate',

            hint:

                '20',

            keyboardType:

                TextInputType.number,

            helper:

                'Leave empty or 0 to keep each package normal extra-KM rate.',

            validator:

                _nonNegativeValidator,

          ),

          const SizedBox(

            height: 10,

          ),

          Container(

            width:

                double.infinity,

            padding:

                const EdgeInsets.all(12),

            decoration:

                BoxDecoration(

              color: softAccent,

              borderRadius:

                  BorderRadius.circular(

                12,

              ),

            ),

            child:

                const Text(

              'The special hourly/daily price is applied to the matching active packages during this date range. The package itself is not modified.',

              style:

                  TextStyle(

                fontFamily:

                    'Manrope',

                fontSize: 11.5,

                height: 1.4,

                color: body,

              ),

            ),

          ),

        ],

      ],

    );

  }



  Widget _datePickerField({

    required String label,

    required String value,

    required VoidCallback onTap,

  }) {

    return InkWell(

      onTap: onTap,

      borderRadius:

          BorderRadius.circular(13),

      child: InputDecorator(

        decoration:

            _decoration(

          label,

          'Select date',

        ),

        child: Row(

          children: [

            const Icon(

              Icons

                  .calendar_today_outlined,

              size: 17,

              color: primary,

            ),

            const SizedBox(

              width: 8,

            ),

            Expanded(

              child: Text(

                value,

                style:

                    const TextStyle(

                  fontFamily:

                      'Manrope',

                  fontSize: 13,

                  color: heading,

                  fontWeight:

                      FontWeight.w600,

                ),

              ),

            ),

          ],

        ),

      ),

    );

  }



  // ===========================================================================

  // DEPOSIT

  // ===========================================================================



  Widget _depositFields() {

    final monetary =

        _depositType.isMonetary;

    final asset =

        _depositType.isAsset;



    return Column(

      children: [

        DropdownButtonFormField<DepositType>(

          initialValue:

              _depositType,

          decoration:

              _decoration(

            'Deposit type',

            'Select deposit type',

          ),

          items: DepositType.values

              .map(

                (type) =>

                    DropdownMenuItem<

                        DepositType>(

                  value: type,

                  child: Text(

                    _depositTypeLabel(

                      type,

                    ),

                    style:

                        const TextStyle(

                      fontFamily:

                          'Manrope',

                      fontSize: 13,

                      color: heading,

                    ),

                  ),

                ),

              )

              .toList(),

          onChanged:

              (value) {

            if (value == null) {

              return;

            }



            setState(() {

              _depositType =

                  value;



              if (!value.isMonetary) {

                _depositController

                    .clear();

              }

            });

          },

        ),

        if (monetary) ...[

          const SizedBox(

            height: 12,

          ),

          _field(

            controller:

                _depositController,

            label:

                'Security deposit amount',

            hint:

                '5000',

            keyboardType:

                TextInputType.number,

            validator:

                _nonNegativeValidator,

            helper:

                'This amount is added to Amount Payable separately. It is not part of Trip Total.',

          ),

        ],

        if (asset) ...[

          const SizedBox(

            height: 12,

          ),

          _field(

            controller:

                _minimumAssetValueController,

            label:

                'Minimum asset value',

            hint:

                '50000',

            keyboardType:

                TextInputType.number,

            validator:

                _nonNegativeValidator,

            helper:

                'For a bike or other asset accepted as security.',

          ),

        ],

        const SizedBox(

          height: 10,

        ),

        Container(

          width:

              double.infinity,

          padding:

              const EdgeInsets.all(12),

          decoration:

              BoxDecoration(

            color: softAccent,

            borderRadius:

                BorderRadius.circular(

              12,

            ),

          ),

          child:

              Text(

            _depositType ==

                    DepositType.none

                ? 'No security deposit will be collected.'

                : monetary

                    ? 'Monetary deposit is separate from the rental/trip total.'

                    : 'The customer asset is held as security and does not increase the trip total or monetary amount payable.',

            style:

                const TextStyle(

              fontFamily:

                  'Manrope',

              fontSize: 11.5,

              height: 1.4,

              color: body,

            ),

          ),

        ),

      ],

    );

  }



  String _depositTypeLabel(

    DepositType type,

  ) {

    switch (type) {

      case DepositType.none:

        return 'None';

      case DepositType.cash:

        return 'Cash';

      case DepositType.online:

        return 'Online';

      case DepositType.bankTransfer:

        return 'Bank transfer';

      case DepositType.vehicleAsset:

        return 'Customer bike / vehicle';

      case DepositType.otherAsset:

        return 'Other asset';

    }

  }



  // ===========================================================================

  // UI HELPERS

  // ===========================================================================



  Widget _section({

    required String title,

    required String subtitle,

    required IconData icon,

    required Widget child,

  }) {

    return Container(

      padding:

          const EdgeInsets.all(18),

      decoration:

          BoxDecoration(

        color: card,

        borderRadius:

            BorderRadius.circular(

          21,

        ),

        border: Border.all(

          color: border,

        ),

        boxShadow: [

          BoxShadow(

            color:

                Colors.black.withValues(

              alpha: 0.025,

            ),

            blurRadius: 14,

            offset:

                const Offset(0, 5),

          ),

        ],

      ),

      child: Column(

        crossAxisAlignment:

            CrossAxisAlignment.start,

        children: [

          Row(

            children: [

              Container(

                width: 40,

                height: 40,

                decoration:

                    BoxDecoration(

                  color: softAccent,

                  borderRadius:

                      BorderRadius.circular(

                    12,

                  ),

                ),

                child: Icon(

                  icon,

                  color: primary,

                  size: 21,

                ),

              ),

              const SizedBox(

                width: 11,

              ),

              Expanded(

                child: Column(

                  crossAxisAlignment:

                      CrossAxisAlignment

                          .start,

                  children: [

                    Text(

                      title,

                      style:

                          const TextStyle(

                        fontFamily:

                            'Manrope',

                        fontSize: 15,

                        fontWeight:

                            FontWeight.w800,

                        color: heading,

                      ),

                    ),

                    const SizedBox(

                      height: 2,

                    ),

                    Text(

                      subtitle,

                      style:

                          const TextStyle(

                        fontFamily:

                            'Manrope',

                        fontSize: 11.5,

                        height: 1.35,

                        color: body,

                      ),

                    ),

                  ],

                ),

              ),

            ],

          ),

          const SizedBox(

            height: 17,

          ),

          child,

        ],

      ),

    );

  }



  Widget _field({

    required TextEditingController

        controller,

    required String label,

    required String hint,

    String? helper,

    TextInputType? keyboardType,

    String? Function(String?)?

        validator,

  }) {

    return TextFormField(

      controller: controller,

      keyboardType: keyboardType,

      validator: validator,

      style:

          const TextStyle(

        fontFamily: 'Manrope',

        fontSize: 13.5,

        color: heading,

      ),

      decoration:

          _decoration(

        label,

        hint,

      ).copyWith(

        helperText: helper,

      ),

    );

  }



  InputDecoration _decoration(

    String label,

    String hint,

  ) {

    return InputDecoration(

      labelText: label,

      hintText: hint,

      labelStyle:

          const TextStyle(

        fontFamily: 'Manrope',

        fontSize: 12.5,

        color: body,

      ),

      hintStyle:

          const TextStyle(

        fontFamily: 'Manrope',

        fontSize: 12,

        color: muted,

      ),

      filled: true,

      fillColor: background,

      contentPadding:

          const EdgeInsets.symmetric(

        horizontal: 14,

        vertical: 14,

      ),

      enabledBorder:

          OutlineInputBorder(

        borderRadius:

            BorderRadius.circular(

          13,

        ),

        borderSide:

            const BorderSide(

          color: border,

        ),

      ),

      focusedBorder:

          OutlineInputBorder(

        borderRadius:

            BorderRadius.circular(

          13,

        ),

        borderSide:

            const BorderSide(

          color: primary,

          width: 1.2,

        ),

      ),

      errorBorder:

          OutlineInputBorder(

        borderRadius:

            BorderRadius.circular(

          13,

        ),

        borderSide:

            BorderSide(

          color:

              Colors.red.shade300,

        ),

      ),

      focusedErrorBorder:

          OutlineInputBorder(

        borderRadius:

            BorderRadius.circular(

          13,

        ),

        borderSide:

            BorderSide(

          color:

              Colors.red.shade600,

        ),

      ),

    );

  }



  String? _required(

    String? value,

  ) {

    if (value == null ||

        value.trim().isEmpty) {

      return 'Required';

    }



    return null;

  }



  String? _positiveOrEmpty(

    String? value,

  ) {

    if (value == null ||

        value.trim().isEmpty) {

      return 'Required';

    }



    final number =

        int.tryParse(

      value.trim(),

    );



    if (number == null ||

        number < 0) {

      return 'Enter valid KM';

    }



    return null;

  }
  String? _positiveIntegerValidator(
    String? value,
  ) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }

    final number = int.tryParse(value.trim());

    if (number == null || number < 1) {
      return 'Enter 1 or more';
    }

    return null;
  }

  int _positiveIntOrDefault(
    String value,
    int fallback,
  ) {
    final parsed = int.tryParse(value.trim());

    if (parsed == null || parsed < 1) {
      return fallback;
    }

    return parsed;
  }





  String? _nonNegativeValidator(

    String? value,

  ) {

    if (value == null ||

        value.trim().isEmpty) {

      return null;

    }



    final number =

        double.tryParse(

      value.trim(),

    );



    if (number == null ||

        !number.isFinite ||

        number < 0) {

      return 'Enter a valid amount';

    }



    return null;

  }



  double _nonNegativeDouble(

    String value,

  ) {

    final parsed =

        double.tryParse(

      value.trim(),

    );



    if (parsed == null ||

        !parsed.isFinite ||

        parsed < 0) {

      return 0;

    }



    return parsed;

  }



  int? _nullablePositiveInt(

    String value,

  ) {

    final parsed =

        int.tryParse(

      value.trim(),

    );



    if (parsed == null ||

        parsed < 0) {

      return null;

    }



    return parsed;

  }



  void _showSnackBar(

    String message, {

    bool isError = false,

  }) {

    ScaffoldMessenger.of(

      context,

    )

      ..hideCurrentSnackBar()

      ..showSnackBar(

        SnackBar(

          content: Text(

            message,

            style:

                const TextStyle(

              fontFamily:

                  'Manrope',

              fontWeight:

                  FontWeight.w600,

            ),

          ),

          backgroundColor:

              isError

                  ? Colors.red.shade700

                  : primary,

          behavior:

              SnackBarBehavior

                  .floating,

          margin:

              const EdgeInsets.all(

            16,

          ),

          shape:

              RoundedRectangleBorder(

            borderRadius:

                BorderRadius.circular(

              12,

            ),

          ),

        ),

      );

  }

}



// =============================================================================

// PACKAGE DRAFT

// =============================================================================



class _PackageDraft {

  final TextEditingController

      idController =

      TextEditingController();



  final TextEditingController

      nameController =

      TextEditingController();



  final TextEditingController

      kmController =

      TextEditingController();



  final TextEditingController

      hourlyController =

      TextEditingController();



  final TextEditingController

      dailyController =

      TextEditingController();



  final TextEditingController

      extraKmController =

      TextEditingController();




  final TextEditingController
      minimumHoursController =
      TextEditingController(text: '1');

  final TextEditingController
      minimumDaysController =
      TextEditingController(text: '1');

  final TextEditingController
      extraHourController =
      TextEditingController(text: '0');

  bool unlimited = false;

  bool isActive = true;



  void dispose() {

    idController.dispose();

    nameController.dispose();

    kmController.dispose();

    hourlyController.dispose();

    dailyController.dispose();

    extraKmController.dispose();

    minimumHoursController.dispose();
    minimumDaysController.dispose();
    extraHourController.dispose();
  }

}
