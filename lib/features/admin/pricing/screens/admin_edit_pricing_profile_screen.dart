import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../../cars/models/car.dart';
import '../../../cars/services/car_service.dart';
import '../../../pricing/models/km_pricing_package.dart';
import '../../../pricing/models/pricing_profile.dart';
import '../../../pricing/services/pricing_profile_service.dart';

class AdminEditPricingProfileScreen extends StatefulWidget {
  final PricingProfile profile;

  const AdminEditPricingProfileScreen({
    super.key,
    required this.profile,
  });

  @override
  State<AdminEditPricingProfileScreen> createState() =>
      _AdminEditPricingProfileScreenState();
}

class _AdminEditPricingProfileScreenState
    extends State<AdminEditPricingProfileScreen> {
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

  final TextEditingController _hourlyController =
      TextEditingController();

  final TextEditingController _dailyController =
      TextEditingController();

  final TextEditingController _weekendController =
      TextEditingController();

  final TextEditingController _weeklyController =
      TextEditingController();

  final TextEditingController _monthlyController =
      TextEditingController();

  final TextEditingController _includedKmController =
      TextEditingController();

  final TextEditingController _perKmController =
      TextEditingController();

  final TextEditingController _extraKmController =
      TextEditingController();

  final TextEditingController
      _unlimitedSurchargeController =
      TextEditingController();

  final TextEditingController _graceController =
      TextEditingController();

  final TextEditingController _extraHourController =
      TextEditingController();

  final TextEditingController _extraDayController =
      TextEditingController();

  final TextEditingController _lateReturnController =
      TextEditingController();

  final TextEditingController _depositController =
      TextEditingController();

  final TextEditingController _kmOptionsController =
      TextEditingController();

  List<Car> _cars = [];

  Car? _selectedCar;

  late KmPricingMode _kmPricingMode;

  late bool _unlimitedEnabled;
  late bool _isActive;

  bool _isLoadingCars = true;
  bool _isSaving = false;

  final List<_EditPackageDraft> _packages = [];

  String get tenantId => AppConfig.tenant.tenantId;

  @override
  void initState() {
    super.initState();

    _initializeFields();
    _loadCars();
  }

  void _initializeFields() {
    final profile = widget.profile;

    _nameController.text = profile.name;

    _hourlyController.text =
        _formatNumber(profile.hourlyRate);

    _dailyController.text =
        _formatNumber(profile.dailyRate);

    _weekendController.text =
        _formatNumber(profile.weekendRate);

    _weeklyController.text =
        _formatNumber(profile.weeklyRate);

    _monthlyController.text =
        _formatNumber(profile.monthlyRate);

    _includedKmController.text =
        profile.includedKmPerDay.toString();

    _perKmController.text =
        _formatNumber(profile.perKmRate);

    _extraKmController.text =
        _formatNumber(profile.extraKmRate);

    _unlimitedSurchargeController.text =
        _formatNumber(
      profile.unlimitedKmSurcharge,
    );

    _graceController.text =
        profile.gracePeriodMinutes.toString();

    _extraHourController.text =
        _formatNumber(profile.extraHourRate);

    _extraDayController.text =
        _formatNumber(profile.extraDayRate);

    _lateReturnController.text =
        _formatNumber(profile.lateReturnRate);

    _depositController.text =
        _formatNumber(profile.securityDeposit);

    _kmOptionsController.text =
        profile.kmOptions.join(', ');

    _kmPricingMode =
        profile.kmPricingMode;

    _unlimitedEnabled =
        profile.unlimitedKmEnabled;

    _isActive =
        profile.isActive;

    for (final package
        in profile.kmPackages) {
      _packages.add(
        _EditPackageDraft.fromPackage(
          package,
        ),
      );
    }
  }

  Future<void> _loadCars() async {
    try {
      final cars = await CarService.instance.getAllCars(
        tenantId: tenantId,
      );

      if (!mounted) return;

      setState(() {
        _cars = cars
            .where((car) => car.isActive)
            .toList();

        for (final car in _cars) {
          if (car.id ==
              widget.profile.vehicleId) {
            _selectedCar = car;
            break;
          }
        }

        _isLoadingCars = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoadingCars = false;
      });

      _showSnackBar(
        'Unable to load vehicles.',
        isError: true,
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hourlyController.dispose();
    _dailyController.dispose();
    _weekendController.dispose();
    _weeklyController.dispose();
    _monthlyController.dispose();
    _includedKmController.dispose();
    _perKmController.dispose();
    _extraKmController.dispose();
    _unlimitedSurchargeController.dispose();
    _graceController.dispose();
    _extraHourController.dispose();
    _extraDayController.dispose();
    _lateReturnController.dispose();
    _depositController.dispose();
    _kmOptionsController.dispose();

    for (final package in _packages) {
      package.dispose();
    }

    super.dispose();
  }

  void _addPackage() {
    setState(() {
      _packages.add(
        _EditPackageDraft(),
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCar == null) {
      _showSnackBar(
        'Please select a vehicle.',
        isError: true,
      );
      return;
    }

    if (_kmPricingMode ==
            KmPricingMode.package &&
        _packages.isEmpty) {
      _showSnackBar(
        'Add at least one KM package.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final updatedProfile =
          PricingProfile(
        id: widget.profile.id,
        tenantId: tenantId,
        vehicleId: _selectedCar!.id,
        name: _nameController.text.trim(),
        currency: widget.profile.currency,

        hourlyRate:
            _number(_hourlyController),
        dailyRate:
            _number(_dailyController),
        weekendRate:
            _number(_weekendController),
        weeklyRate:
            _number(_weeklyController),
        monthlyRate:
            _number(_monthlyController),

        kmPricingMode:
            _kmPricingMode,
        includedKmPerDay:
            _integer(_includedKmController),
        kmOptions:
            _parseKmOptions(),
        perKmRate:
            _number(_perKmController),
        extraKmRate:
            _number(_extraKmController),

        kmPackages:
            _packages.map(
          _buildPackage,
        ).toList(),

        unlimitedKmEnabled:
            _unlimitedEnabled,
        unlimitedKmSurcharge:
            _number(
          _unlimitedSurchargeController,
        ),

        gracePeriodMinutes:
            _integer(_graceController),
        extraHourRate:
            _number(_extraHourController),
        extraDayRate:
            _number(_extraDayController),
        lateReturnRate:
            _number(_lateReturnController),

        securityDeposit:
            _number(_depositController),

        isActive: _isActive,
      );

      await PricingProfileService.instance
          .updatePricingProfile(
        tenantId: tenantId,
        pricingProfileId:
            widget.profile.id,
        profile: updatedProfile,
      );

      if (!mounted) return;

      _showSnackBar(
        'Pricing profile updated successfully.',
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
    _EditPackageDraft draft,
  ) {
    return KmPricingPackage(
      id: draft.idController.text
              .trim()
              .isEmpty
          ? 'package_${DateTime.now().microsecondsSinceEpoch}'
          : draft.idController.text.trim(),
      name:
          draft.nameController.text.trim(),
      includedKm:
          draft.unlimited
              ? null
              : int.tryParse(
                  draft.kmController.text.trim(),
                ),
      unlimitedKm:
          draft.unlimited,
      hourlyRate:
          _number(
        draft.hourlyController,
      ),
      dailyRate:
          _number(
        draft.dailyController,
      ),
      weekendRate:
          _number(
        draft.weekendController,
      ),
      weeklyRate:
          _number(
        draft.weeklyController,
      ),
      monthlyRate:
          _number(
        draft.monthlyController,
      ),
      extraKmRate:
          _number(
        draft.extraKmController,
      ),
    );
  }

  List<int> _parseKmOptions() {
    return _kmOptionsController.text
        .split(',')
        .map(
          (value) => int.tryParse(
            value.trim(),
          ),
        )
        .whereType<int>()
        .where((value) => value > 0)
        .toSet()
        .toList();
  }

  double _number(
    TextEditingController controller,
  ) {
    return double.tryParse(
          controller.text.trim(),
        ) ??
        0;
  }

  int _integer(
    TextEditingController controller,
  ) {
    return int.tryParse(
          controller.text.trim(),
        ) ??
        0;
  }

  String _formatNumber(
    double value,
  ) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toString();
  }

  void _showSnackBar(
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor:
              isError
                  ? Colors.red.shade700
                  : primary,
          behavior:
              SnackBarBehavior.floating,
          margin:
              const EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(12),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        surfaceTintColor:
            Colors.transparent,
        elevation: 0,
        title: const Text(
          'Edit Pricing Profile',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 21,
            fontWeight: FontWeight.w800,
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
            _profileIdentity(),
            const SizedBox(height: 16),
            _section(
              title: 'Vehicle',
              subtitle:
                  'Change the vehicle attached to this pricing profile.',
              icon:
                  Icons.directions_car_outlined,
              child:
                  _vehicleDropdown(),
            ),
            const SizedBox(height: 16),
            _section(
              title: 'Profile Details',
              subtitle:
                  'Update the profile information.',
              icon: Icons.badge_outlined,
              child: Column(
                children: [
                  _field(
                    controller:
                        _nameController,
                    label:
                        'Pricing profile name',
                    hint:
                        'Pricing profile',
                    validator:
                        _required,
                  ),
                  const SizedBox(
                    height: 14,
                  ),
                  TextFormField(
                    initialValue:
                        widget.profile.currency,
                    readOnly: true,
                    decoration:
                        _decoration(
                      'Currency',
                      widget.profile.currency,
                    ),
                    style:
                        const TextStyle(
                      fontFamily:
                          'Manrope',
                      fontWeight:
                          FontWeight.w700,
                      color: heading,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _section(
              title: 'Base Rental Rates',
              subtitle:
                  'Update the default rental rates.',
              icon:
                  Icons.payments_outlined,
              child: _rateGrid(),
            ),
            const SizedBox(height: 16),
            _section(
              title: 'KM Pricing',
              subtitle:
                  'Update distance pricing rules and packages.',
              icon:
                  Icons.route_outlined,
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  _modeSelector(),
                  const SizedBox(
                    height: 16,
                  ),
                  if (_kmPricingMode ==
                      KmPricingMode.included)
                    _includedKmFields(),
                  if (_kmPricingMode ==
                      KmPricingMode.perKm)
                    _perKmFields(),
                  if (_kmPricingMode ==
                      KmPricingMode.slabs)
                    _slabFields(),
                  if (_kmPricingMode ==
                      KmPricingMode.unlimited)
                    _unlimitedFields(),
                  if (_kmPricingMode ==
                      KmPricingMode.package)
                    _packageFields(),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _section(
              title: 'Extra Charges',
              subtitle:
                  'Update extension and late-return charges.',
              icon:
                  Icons.schedule_outlined,
              child: _extraCharges(),
            ),
            const SizedBox(height: 16),
            _section(
              title: 'Security Deposit',
              subtitle:
                  'Update the security deposit.',
              icon: Icons
                  .account_balance_wallet_outlined,
              child: _field(
                controller:
                    _depositController,
                label:
                    'Security deposit',
                hint: '5000',
                keyboardType:
                    TextInputType.number,
              ),
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
                activeColor:
                    primary,
                title:
                    const Text(
                  'Active pricing profile',
                  style:
                      TextStyle(
                    fontFamily:
                        'Manrope',
                    fontSize: 14,
                    fontWeight:
                        FontWeight.w700,
                    color:
                        heading,
                  ),
                ),
                subtitle:
                    const Text(
                  'Enable this profile for bookings.',
                  style:
                      TextStyle(
                    fontFamily:
                        'Manrope',
                    fontSize: 12,
                    color:
                        body,
                  ),
                ),
                value:
                    _isActive,
                onChanged:
                    (value) {
                  setState(() {
                    _isActive =
                        value;
                  });
                },
              ),
            ),
            const SizedBox(
              height: 24,
            ),
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
                        'Save Changes',
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

  Widget _profileIdentity() {
    return Container(
      padding:
          const EdgeInsets.all(17),
      decoration:
          BoxDecoration(
        color: softAccent,
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        border: Border.all(
          color:
              accent.withValues(
            alpha: 0.18,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.price_change_outlined,
            color: primary,
            size: 24,
          ),
          const SizedBox(
            width: 12,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pricing Profile ID',
                  style: TextStyle(
                    fontFamily:
                        'Manrope',
                    fontSize: 10.5,
                    fontWeight:
                        FontWeight.w700,
                    color: body,
                  ),
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  widget.profile.id,
                  style:
                      const TextStyle(
                    fontFamily:
                        'Manrope',
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w800,
                    color:
                        heading,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _vehicleDropdown() {
    if (_isLoadingCars) {
      return const LinearProgressIndicator(
        color: primary,
        backgroundColor:
            softAccent,
      );
    }

    return DropdownButtonFormField<Car>(
      initialValue:
          _selectedCar,
      isExpanded: true,
      decoration:
          _decoration(
        'Vehicle',
        'Select vehicle',
      ),
      items:
          _cars.map((car) {
        return DropdownMenuItem<Car>(
          value: car,
          child: Text(
            car.name,
            style:
                const TextStyle(
              fontFamily:
                  'Manrope',
              fontSize: 13.5,
              color:
                  heading,
            ),
          ),
        );
      }).toList(),
      onChanged:
          (car) {
        setState(() {
          _selectedCar =
              car;
        });
      },
      validator:
          (value) {
        if (value ==
            null) {
          return 'Select a vehicle';
        }
        return null;
      },
    );
  }

  Widget _rateGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child:
                  _field(
                controller:
                    _hourlyController,
                label:
                    'Hourly',
                hint:
                    '399',
                keyboardType:
                    TextInputType
                        .number,
              ),
            ),
            const SizedBox(
              width: 12,
            ),
            Expanded(
              child:
                  _field(
                controller:
                    _dailyController,
                label:
                    'Daily',
                hint:
                    '2499',
                keyboardType:
                    TextInputType
                        .number,
              ),
            ),
          ],
        ),
        const SizedBox(
          height: 12,
        ),
        Row(
          children: [
            Expanded(
              child:
                  _field(
                controller:
                    _weekendController,
                label:
                    'Weekend',
                hint:
                    '2799',
                keyboardType:
                    TextInputType
                        .number,
              ),
            ),
            const SizedBox(
              width: 12,
            ),
            Expanded(
              child:
                  _field(
                controller:
                    _weeklyController,
                label:
                    'Weekly',
                hint:
                    '13999',
                keyboardType:
                    TextInputType
                        .number,
              ),
            ),
          ],
        ),
        const SizedBox(
          height: 12,
        ),
        _field(
          controller:
              _monthlyController,
          label:
              'Monthly',
          hint:
              '44999',
          keyboardType:
              TextInputType.number,
        ),
      ],
    );
  }

  Widget _modeSelector() {
    return DropdownButtonFormField<KmPricingMode>(
      initialValue:
          _kmPricingMode,
      decoration:
          _decoration(
        'KM pricing mode',
        'Select KM pricing',
      ),
      items:
          KmPricingMode.values
              .map(
                (mode) {
          return DropdownMenuItem(
            value: mode,
            child:
                Text(
              _modeLabel(
                mode,
              ),
              style:
                  const TextStyle(
                fontFamily:
                    'Manrope',
                fontSize:
                    13,
                color:
                    heading,
              ),
            ),
          );
        },
              )
              .toList(),
      onChanged:
          (value) {
        if (value ==
            null) {
          return;
        }

        setState(() {
          _kmPricingMode =
              value;
        });
      },
    );
  }

  Widget _includedKmFields() {
    return Column(
      children: [
        _field(
          controller:
              _includedKmController,
          label:
              'Included KM per day',
          hint: '150',
          keyboardType:
              TextInputType.number,
        ),
        const SizedBox(
          height: 12,
        ),
        _field(
          controller:
              _kmOptionsController,
          label:
              'KM options',
          hint:
              '150, 300, 500, 750, 1000',
          helper:
              'Separate values with commas.',
        ),
      ],
    );
  }

  Widget _perKmFields() {
    return Column(
      children: [
        _field(
          controller:
              _perKmController,
          label:
              'Per KM rate',
          hint:
              '18',
          keyboardType:
              TextInputType.number,
        ),
        const SizedBox(
          height: 12,
        ),
        _field(
          controller:
              _extraKmController,
          label:
              'Extra KM rate',
          hint:
              '15',
          keyboardType:
              TextInputType.number,
        ),
      ],
    );
  }

  Widget _slabFields() {
    return Column(
      children: [
        _field(
          controller:
              _kmOptionsController,
          label:
              'KM slab options',
          hint:
              '150, 300, 500, 750, 1000',
        ),
        const SizedBox(
          height: 12,
        ),
        _field(
          controller:
              _extraKmController,
          label:
              'Extra KM rate',
          hint:
              '15',
          keyboardType:
              TextInputType.number,
        ),
      ],
    );
  }

  Widget _unlimitedFields() {
    return _field(
      controller:
          _unlimitedSurchargeController,
      label:
          'Unlimited KM surcharge',
      hint:
          '1000',
      keyboardType:
          TextInputType.number,
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
                style:
                    TextStyle(
                  fontFamily:
                      'Manrope',
                  fontSize: 14,
                  fontWeight:
                      FontWeight.w800,
                  color:
                      heading,
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
                  const Text(
                'Add',
              ),
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
              color:
                  background,
              borderRadius:
                  BorderRadius.circular(
                14,
              ),
              border:
                  Border.all(
                color:
                    border,
              ),
            ),
            child:
                const Text(
              'No KM packages configured.',
              style:
                  TextStyle(
                fontFamily:
                    'Manrope',
                fontSize:
                    12,
                color:
                    body,
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
    _EditPackageDraft package,
  ) {
    return Container(
      margin:
          const EdgeInsets.only(
        top: 12,
      ),
      padding:
          const EdgeInsets.all(
        15,
      ),
      decoration:
          BoxDecoration(
        color:
            background,
        borderRadius:
            BorderRadius.circular(
          17,
        ),
        border:
            Border.all(
          color:
              border,
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
                  color:
                      softAccent,
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
                  color:
                      primary,
                ),
              ),
              const SizedBox(
                width: 10,
              ),
              Expanded(
                child:
                    Text(
                  'Package ${index + 1}',
                  style:
                      const TextStyle(
                    fontFamily:
                        'Manrope',
                    fontSize:
                        13,
                    fontWeight:
                        FontWeight.w800,
                    color:
                        heading,
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
                  color:
                      muted,
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
                fontSize:
                    13,
                fontWeight:
                    FontWeight.w700,
                color:
                    heading,
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
                  TextInputType
                      .number,
            ),
          const SizedBox(
            height: 10,
          ),
          _packageRates(
            package,
          ),
        ],
      ),
    );
  }

  Widget _packageRates(
    _EditPackageDraft package,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child:
                  _field(
                controller:
                    package
                        .hourlyController,
                label:
                    'Hourly',
                hint:
                    '499',
                keyboardType:
                    TextInputType
                        .number,
              ),
            ),
            const SizedBox(
              width: 10,
            ),
            Expanded(
              child:
                  _field(
                controller:
                    package
                        .dailyController,
                label:
                    'Daily',
                hint:
                    '3199',
                keyboardType:
                    TextInputType
                        .number,
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
              child:
                  _field(
                controller:
                    package
                        .weekendController,
                label:
                    'Weekend',
                hint:
                    '3499',
                keyboardType:
                    TextInputType
                        .number,
              ),
            ),
            const SizedBox(
              width: 10,
            ),
            Expanded(
              child:
                  _field(
                controller:
                    package
                        .weeklyController,
                label:
                    'Weekly',
                hint:
                    '16999',
                keyboardType:
                    TextInputType
                        .number,
              ),
            ),
          ],
        ),
        const SizedBox(
          height: 10,
        ),
        _field(
          controller:
              package
                  .monthlyController,
          label:
              'Monthly',
          hint:
              '54999',
          keyboardType:
              TextInputType.number,
        ),
        const SizedBox(
          height: 10,
        ),
        _field(
          controller:
              package
                  .extraKmController,
          label:
              'Extra KM rate',
          hint:
              '14',
          keyboardType:
              TextInputType.number,
        ),
      ],
    );
  }

  Widget _extraCharges() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child:
                  _field(
                controller:
                    _graceController,
                label:
                    'Grace minutes',
                hint:
                    '30',
                keyboardType:
                    TextInputType
                        .number,
              ),
            ),
            const SizedBox(
              width: 12,
            ),
            Expanded(
              child:
                  _field(
                controller:
                    _extraHourController,
                label:
                    'Extra hour',
                hint:
                    '299',
                keyboardType:
                    TextInputType
                        .number,
              ),
            ),
          ],
        ),
        const SizedBox(
          height: 12,
        ),
        Row(
          children: [
            Expanded(
              child:
                  _field(
                controller:
                    _extraDayController,
                label:
                    'Extra day',
                hint:
                    '2499',
                keyboardType:
                    TextInputType
                        .number,
              ),
            ),
            const SizedBox(
              width: 12,
            ),
            Expanded(
              child:
                  _field(
                controller:
                    _lateReturnController,
                label:
                    'Late return',
                hint:
                    '349',
                keyboardType:
                    TextInputType
                        .number,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _section({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding:
          const EdgeInsets.all(
        18,
      ),
      decoration:
          BoxDecoration(
        color:
            card,
        borderRadius:
            BorderRadius.circular(
          21,
        ),
        border:
            Border.all(
          color:
              border,
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(
              alpha:
                  0.025,
            ),
            blurRadius:
                14,
            offset:
                const Offset(
              0,
              5,
            ),
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
                  color:
                      softAccent,
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
                child:
                    Icon(
                  icon,
                  color:
                      primary,
                  size:
                      21,
                ),
              ),
              const SizedBox(
                width: 11,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style:
                          const TextStyle(
                        fontFamily:
                            'Manrope',
                        fontSize:
                            15,
                        fontWeight:
                            FontWeight.w800,
                        color:
                            heading,
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
                        fontSize:
                            11.5,
                        height:
                            1.35,
                        color:
                            body,
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
    required TextEditingController controller,
    required String label,
    required String hint,
    String? helper,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller:
          controller,
      keyboardType:
          keyboardType,
      validator:
          validator,
      style:
          const TextStyle(
        fontFamily:
            'Manrope',
        fontSize:
            13.5,
        color:
            heading,
      ),
      decoration:
          _decoration(
        label,
        hint,
      ).copyWith(
        helperText:
            helper,
      ),
    );
  }

  InputDecoration _decoration(
    String label,
    String hint,
  ) {
    return InputDecoration(
      labelText:
          label,
      hintText:
          hint,
      labelStyle:
          const TextStyle(
        fontFamily:
            'Manrope',
        fontSize:
            12.5,
        color:
            body,
      ),
      hintStyle:
          const TextStyle(
        fontFamily:
            'Manrope',
        fontSize:
            12,
        color:
            muted,
      ),
      filled:
          true,
      fillColor:
          background,
      contentPadding:
          const EdgeInsets.symmetric(
        horizontal:
            14,
        vertical:
            14,
      ),
      enabledBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          13,
        ),
        borderSide:
            const BorderSide(
          color:
              border,
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
          color:
              primary,
          width:
              1.2,
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

  String _modeLabel(
    KmPricingMode mode,
  ) {
    switch (mode) {
      case KmPricingMode.included:
        return 'Included KM';
      case KmPricingMode.perKm:
        return 'Per KM';
      case KmPricingMode.unlimited:
        return 'Unlimited KM';
      case KmPricingMode.package:
        return 'KM Packages';
      case KmPricingMode.slabs:
        return 'KM Slabs';
    }
  }
}

class _EditPackageDraft {
  final TextEditingController idController =
      TextEditingController();

  final TextEditingController nameController =
      TextEditingController();

  final TextEditingController kmController =
      TextEditingController();

  final TextEditingController hourlyController =
      TextEditingController();

  final TextEditingController dailyController =
      TextEditingController();

  final TextEditingController weekendController =
      TextEditingController();

  final TextEditingController weeklyController =
      TextEditingController();

  final TextEditingController monthlyController =
      TextEditingController();

  final TextEditingController extraKmController =
      TextEditingController();

  bool unlimited = false;

  _EditPackageDraft();

  _EditPackageDraft.fromPackage(
    KmPricingPackage package,
  ) {
    idController.text =
        package.id;

    nameController.text =
        package.name;

    if (package.includedKm != null) {
      kmController.text =
          package.includedKm.toString();
    }

    hourlyController.text =
        package.hourlyRate.toString();

    dailyController.text =
        package.dailyRate.toString();

    weekendController.text =
        package.weekendRate.toString();

    weeklyController.text =
        package.weeklyRate.toString();

    monthlyController.text =
        package.monthlyRate.toString();

    extraKmController.text =
        package.extraKmRate.toString();

    unlimited =
        package.unlimitedKm;
  }

  void dispose() {
    idController.dispose();
    nameController.dispose();
    kmController.dispose();
    hourlyController.dispose();
    dailyController.dispose();
    weekendController.dispose();
    weeklyController.dispose();
    monthlyController.dispose();
    extraKmController.dispose();
  }
}