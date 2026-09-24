import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter/material.dart';







import '../../../../core/config/app_config.dart';



import '../../../cars/models/car.dart';



import '../../../cars/services/car_service.dart';



import '../../../pricing/models/km_pricing_package.dart';



import '../../../pricing/models/pricing_profile.dart';



import '../../../pricing/services/pricing_profile_service.dart';







/// Edit screen for the simplified car-rental pricing model.



///



/// Supported rental types:



///   - Hourly



///   - Daily



///



/// Removed from the old screen:



///   - Weekend rental type



///   - Weekly rental type



///   - Monthly rental type



///   - Legacy KM pricing modes



///   - Minimum/maximum weekend rules



///   - Legacy extra-hour/day/late-return pricing



///   - Pricing version management



///



/// Security deposit is kept separate from trip pricing.



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







  final _nameController = TextEditingController();



  final _pricingGroupController = TextEditingController();







  final _depositAmountController = TextEditingController();



  final _paymentMethodController = TextEditingController();



  final _assetDescriptionController = TextEditingController();



  final _minimumAssetValueController = TextEditingController();







  final List<_EditPackageDraft> _packages = [];



  final List<_EditSpecialRateDraft> _specialRates = [];







  List<Car> _cars = [];









  bool _isLoadingCars = true;



  bool _isConnectingCars = false;
  bool _isSaving = false;



  bool _isActive = true;







  DepositType _depositType = DepositType.none;







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



    _pricingGroupController.text = profile.pricingGroupId;



    _isActive = profile.isActive;







    final deposit = profile.securityDeposit;



    _depositType = deposit.type;



    _depositAmountController.text = _formatNumber(deposit.amount);



    _paymentMethodController.text = deposit.paymentMethod;



    _assetDescriptionController.text = deposit.assetDescription;



    _minimumAssetValueController.text =



        _formatNumber(deposit.minimumAssetValue);







    final byId = <String, _EditPackageDraft>{};







    for (final package in profile.hourlyPackages) {



      final draft = byId.putIfAbsent(



        package.id,



        () => _EditPackageDraft.fromPackage(package),



      );



      draft.hourlyController.text = _formatNumber(package.hourlyRate);



    }







    for (final package in profile.dailyPackages) {



      final draft = byId.putIfAbsent(



        package.id,



        () => _EditPackageDraft.fromPackage(package),



      );



      draft.dailyController.text = _formatNumber(package.dailyRate);



    }







    _packages.addAll(byId.values);







    for (final rate in profile.specialRates) {



      _specialRates.add(



        _EditSpecialRateDraft.fromSpecialRate(rate),



      );



    }



  }







  Future<void> _loadCars() async {

    try {

      final cars = await CarService.instance.getAllCars(tenantId: tenantId);

      if (!mounted) return;

      setState(() {

        _cars = cars.where((car) => car.isActive).toList();

        _isLoadingCars = false;

      });

    } catch (_) {

      if (!mounted) return;

      setState(() => _isLoadingCars = false);

      _showSnackBar('Unable to load vehicles.', isError: true);

    }

  }



  List<Car> get _connectedCars => _cars

      .where((car) => car.pricingProfileId == widget.profile.id)

      .toList();



  Future<void> _openConnectCarsDialog() async {

    if (_isConnectingCars || _isLoadingCars) return;

    final result = await showDialog<Set<String>>(

      context: context,

      builder: (dialogContext) {

        var search = '';

        var selected = _connectedCars.map((car) => car.id).toSet();

        return StatefulBuilder(

          builder: (context, setDialogState) {

            final q = search.trim().toLowerCase();

            final filtered = _cars.where((car) {

              if (q.isEmpty) return true;

              return car.name.toLowerCase().contains(q) ||

                  car.registrationNumber.toLowerCase().contains(q);

            }).toList();

            return AlertDialog(

              backgroundColor: card,

              surfaceTintColor: Colors.transparent,

              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),

              title: Row(children: [

                Container(width: 40, height: 40, decoration: BoxDecoration(color: softAccent, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.directions_car_filled_outlined, color: primary)),

                const SizedBox(width: 12),

                const Expanded(child: Text('Connect Cars', style: TextStyle(fontFamily: 'Manrope', fontSize: 18, fontWeight: FontWeight.w800, color: heading))),

              ]),

              content: SizedBox(

                width: 520,

                child: Column(mainAxisSize: MainAxisSize.min, children: [

                  TextField(

                    onChanged: (value) => setDialogState(() => search = value),

                    decoration: InputDecoration(

                      hintText: 'Search by car name or registration',

                      prefixIcon: const Icon(Icons.search_rounded),

                      filled: true,

                      fillColor: background,

                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: border)),

                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: border)),

                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: primary)),

                    ),

                  ),

                  const SizedBox(height: 10),

                  Align(alignment: Alignment.centerLeft, child: Text('${selected.length} car${selected.length == 1 ? '' : 's'} selected', style: const TextStyle(fontFamily: 'Manrope', fontSize: 11.5, fontWeight: FontWeight.w700, color: body))),

                  const SizedBox(height: 6),

                  Flexible(

                    child: filtered.isEmpty

                        ? Padding(padding: const EdgeInsets.all(24), child: _infoText('No active cars found.'))

                        : ListView.separated(

                            shrinkWrap: true,

                            itemCount: filtered.length,

                            separatorBuilder: (_, __) => const Divider(height: 1),

                            itemBuilder: (context, index) {

                              final car = filtered[index];

                              final registration = car.registrationNumber.trim();

                              return CheckboxListTile(

                                value: selected.contains(car.id),

                                activeColor: primary,

                                contentPadding: EdgeInsets.zero,

                                onChanged: (value) => setDialogState(() {

                                  if (value == true) selected.add(car.id); else selected.remove(car.id);

                                }),

                                title: Text(car.name, style: const TextStyle(fontFamily: 'Manrope', fontSize: 13, fontWeight: FontWeight.w800, color: heading)),

                                subtitle: registration.isEmpty ? null : Text(registration, style: const TextStyle(fontFamily: 'Manrope', fontSize: 11, color: body)),

                              );

                            },

                          ),

                  ),

                ]),

              ),

              actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),

              actions: [

                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),

                ElevatedButton(

                  onPressed: () => Navigator.pop(dialogContext, Set<String>.from(selected)),

                  style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),

                  child: const Text('Save Connections', style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800)),

                ),

              ],

            );

          },

        );

      },

    );

    if (result == null || !mounted) return;

    await _saveCarConnections(result);

  }



  Future<void> _saveCarConnections(Set<String> selectedIds) async {
    if (_isConnectingCars) return;

    setState(() => _isConnectingCars = true);

    try {
      final carsRef = FirebaseFirestore.instance
          .collection('tenants')
          .doc(tenantId)
          .collection('cars');

      final changedCars = _cars.where((car) {
        final shouldBeConnected = selectedIds.contains(car.id);
        final isConnected = car.pricingProfileId == widget.profile.id;
        return shouldBeConnected != isConnected;
      }).toList();

      // Firestore batches are limited to 500 writes. Keep a safety margin
      // so this continues to work even when a profile is used by a large fleet.
      const batchSize = 450;

      for (var offset = 0; offset < changedCars.length; offset += batchSize) {
        final end = (offset + batchSize < changedCars.length)
            ? offset + batchSize
            : changedCars.length;
        final batch = FirebaseFirestore.instance.batch();

        for (final car in changedCars.sublist(offset, end)) {
          final shouldBeConnected = selectedIds.contains(car.id);
          final ref = carsRef.doc(car.id);

          if (shouldBeConnected) {
            batch.set(
              ref,
              {
                'tenantId': tenantId,
                'pricingProfileId': widget.profile.id,
                'updatedAt': FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true),
            );
          } else {
            batch.set(
              ref,
              {
                'pricingProfileId': FieldValue.delete(),
                'updatedAt': FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true),
            );
          }
        }

        if (end > offset) {
          await batch.commit();
        }
      }

      await _loadCars();

      if (!mounted) return;

      final count = selectedIds.length;
      _showSnackBar(
        count == 0
            ? 'All cars disconnected from this profile.'
            : '$count car${count == 1 ? '' : 's'} connected to this profile.',
      );
    } catch (e) {
      if (!mounted) return;

      _showSnackBar(
        'Unable to update car connections: ${e.toString().replaceFirst('Exception: ', '')}',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isConnectingCars = false);
      }
    }
  }

  Future<void> _disconnectCar(Car car) async {

    final confirmed = await showDialog<bool>(

      context: context,

      builder: (context) => AlertDialog(

        backgroundColor: card,

        surfaceTintColor: Colors.transparent,

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),

        title: const Text('Disconnect car?', style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, color: heading)),

        content: Text('${car.name} will no longer use this pricing profile.', style: const TextStyle(fontFamily: 'Manrope', fontSize: 13, color: body)),

        actions: [

          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),

          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white, elevation: 0), child: const Text('Disconnect')),

        ],

      ),

    );

    if (confirmed != true || !mounted) return;

    await _saveCarConnections(_connectedCars.where((item) => item.id != car.id).map((item) => item.id).toSet());

  }



  void dispose() {



    _nameController.dispose();



    _pricingGroupController.dispose();



    _depositAmountController.dispose();



    _paymentMethodController.dispose();



    _assetDescriptionController.dispose();



    _minimumAssetValueController.dispose();







    for (final package in _packages) {



      package.dispose();



    }



    for (final rate in _specialRates) {



      rate.dispose();



    }







    super.dispose();



  }







  void _addPackage() {



    setState(() {



      _packages.add(_EditPackageDraft());



    });



  }







  void _removePackage(int index) {



    final package = _packages.removeAt(index);



    package.dispose();



    setState(() {});



  }







  void _addSpecialRate() {



    final now = DateTime.now();



    setState(() {



      _specialRates.add(



        _EditSpecialRateDraft(



          startDate: DateTime(now.year, now.month, now.day),



          endDate: DateTime(now.year, now.month, now.day),



        ),



      );



    });



  }







  void _removeSpecialRate(int index) {



    final rate = _specialRates.removeAt(index);



    rate.dispose();



    setState(() {});



  }







  Future<void> _save() async {



    if (!_formKey.currentState!.validate()) return;







    if (_packages.isEmpty) {



      _showSnackBar(



        'Add at least one KM package.',



        isError: true,



      );



      return;



    }







    for (var i = 0; i < _packages.length; i++) {



      final package = _packages[i];



      final hasHourly = _number(package.hourlyController) > 0;



      final hasDaily = _number(package.dailyController) > 0;







      if (!hasHourly && !hasDaily) {



        _showSnackBar(



          'Package ${i + 1} needs an hourly or daily price.',



          isError: true,



        );



        return;



      }







      if (!package.unlimited &&



          _integer(package.kmController) <= 0) {



        _showSnackBar(



          'Enter included KM for package ${i + 1}, or enable Unlimited KM.',



          isError: true,



        );



        return;



      }



    }







    for (var i = 0; i < _specialRates.length; i++) {



      final rate = _specialRates[i];



      if (rate.startDate == null || rate.endDate == null) {



        _showSnackBar(



          'Select both dates for special rate ${i + 1}.',



          isError: true,



        );



        return;



      }



      if (rate.endDate!.isBefore(rate.startDate!)) {



        _showSnackBar(



          'Special rate ${i + 1} end date cannot be before start date.',



          isError: true,



        );



        return;



      }



    }







    setState(() => _isSaving = true);







    try {



      final packageModels = _packages.map(_buildPackage).toList();







      final hourlyPackages = packageModels



          .where((package) => package.hourlyRate > 0)



          .toList(growable: false);



      final dailyPackages = packageModels



          .where((package) => package.dailyRate > 0)



          .toList(growable: false);







      if (hourlyPackages.isEmpty && dailyPackages.isEmpty) {



        throw Exception('At least one hourly or daily package is required.');



      }







      final updatedProfile = PricingProfile(



        id: widget.profile.id,



        tenantId: tenantId,



        // Multi-car connections are stored on each car through pricingProfileId.

        vehicleId: widget.profile.vehicleId,



        pricingGroupId: _pricingGroupController.text.trim(),



        name: _nameController.text.trim(),



        currency: widget.profile.currency,



        hourlyPackages: hourlyPackages,



        dailyPackages: dailyPackages,



        specialRates: _buildSpecialRates(),



        securityDeposit: _buildDepositConfig(),



        isActive: _isActive,



      );







      await PricingProfileService.instance.updatePricingProfile(



        tenantId: tenantId,



        pricingProfileId: widget.profile.id,



        profile: updatedProfile,



      );







      if (!mounted) return;







      _showSnackBar('Pricing profile updated successfully.');



      Navigator.pop(context, true);



    } catch (e) {



      if (!mounted) return;







      _showSnackBar(



        e.toString().replaceFirst('Exception: ', ''),



        isError: true,



      );



    } finally {



      if (mounted) setState(() => _isSaving = false);



    }



  }







  KmPricingPackage _buildPackage(_EditPackageDraft draft) {



    final id = draft.idController.text.trim().isEmpty



        ? 'package_${DateTime.now().microsecondsSinceEpoch}'



        : draft.idController.text.trim();







    return KmPricingPackage(



      id: id,



      name: draft.nameController.text.trim().isEmpty



          ? id



          : draft.nameController.text.trim(),



      includedKm: draft.unlimited



          ? null



          : _integer(draft.kmController),



      unlimitedKm: draft.unlimited,



      isActive: draft.isActive,



      hourlyRate: _number(draft.hourlyController),



      dailyRate: _number(draft.dailyController),



      extraKmRate: _number(draft.extraKmController),



    );



  }







  List<SpecialRate> _buildSpecialRates() {



    final result = <SpecialRate>[];







    for (final draft in _specialRates) {



      final start = draft.startDate;



      final end = draft.endDate;



      if (start == null || end == null) continue;







      final hourlyPrices = <String, double>{};



      final dailyPrices = <String, double>{};







      for (final package in _packages) {



        final id = package.idController.text.trim();



        if (id.isEmpty) continue;







        final hourly = _number(draft.hourlyControllers[id]);



        final daily = _number(draft.dailyControllers[id]);







        if (hourly > 0) hourlyPrices[id] = hourly;



        if (daily > 0) dailyPrices[id] = daily;



      }







      final extraKmText = draft.extraKmController.text.trim();



      final extraKm = extraKmText.isEmpty



          ? null



          : double.tryParse(extraKmText);







      result.add(



        SpecialRate(



          id: draft.id.isEmpty



              ? 'special_${DateTime.now().microsecondsSinceEpoch}'



              : draft.id,



          name: draft.nameController.text.trim().isEmpty



              ? 'Special Pricing'



              : draft.nameController.text.trim(),



          startDate: DateTime(start.year, start.month, start.day),



          endDate: DateTime(end.year, end.month, end.day),



          isActive: draft.isActive,



          hourlyPrices: hourlyPrices,



          dailyPrices: dailyPrices,



          extraKmRate: extraKm != null && extraKm >= 0 ? extraKm : null,



        ),



      );



    }







    return result;



  }







  DepositConfig _buildDepositConfig() {



    final type = _depositType;







    if (type == DepositType.none) {



      return const DepositConfig();



    }







    final isMoney = type.isMonetary;







    return DepositConfig(



      type: type,



      amount: isMoney ? _number(_depositAmountController) : 0,



      paymentMethod: isMoney



          ? _paymentMethodController.text.trim()



          : '',



      assetDescription: type == DepositType.vehicleAsset ||



              type == DepositType.otherAsset



          ? _assetDescriptionController.text.trim()



          : '',



      minimumAssetValue: type == DepositType.vehicleAsset ||



              type == DepositType.otherAsset



          ? _number(_minimumAssetValueController)



          : 0,



    );



  }







  Future<void> _pickSpecialDate(



    _EditSpecialRateDraft rate, {



    required bool start,



  }) async {



    final now = DateTime.now();



    final initial = start



        ? (rate.startDate ?? now)



        : (rate.endDate ?? rate.startDate ?? now);







    final picked = await showDatePicker(



      context: context,



      firstDate: DateTime(now.year - 2),



      lastDate: DateTime(now.year + 10),



      initialDate: initial,



      builder: (context, child) {



        return Theme(



          data: Theme.of(context).copyWith(



            colorScheme: const ColorScheme.light(



              primary: primary,



              surface: card,



            ),



          ),



          child: child!,



        );



      },



    );







    if (picked == null || !mounted) return;







    setState(() {



      if (start) {



        rate.startDate = picked;



        if (rate.endDate != null && rate.endDate!.isBefore(picked)) {



          rate.endDate = picked;



        }



      } else {



        if (rate.startDate != null && picked.isBefore(rate.startDate!)) {



          _showSnackBar(



            'End date cannot be before start date.',



            isError: true,



          );



          return;



        }



        rate.endDate = picked;



      }



    });



  }







  String _dateLabel(DateTime? date) {



    if (date == null) return 'Select date';



    final d = date.day.toString().padLeft(2, '0');



    final m = date.month.toString().padLeft(2, '0');



    return '$d/$m/${date.year}';



  }







  double _number(TextEditingController? controller) {



    if (controller == null) return 0;



    final value = double.tryParse(controller.text.trim()) ?? 0;



    return value.isFinite && value >= 0 ? value : 0;



  }







  int _integer(TextEditingController controller) {



    final value = int.tryParse(controller.text.trim()) ?? 0;



    return value < 0 ? 0 : value;



  }







  String _formatNumber(double value) {



    if (!value.isFinite || value == 0) return '0';



    if (value == value.roundToDouble()) return value.toInt().toString();



    return value.toString();



  }







  String? _required(String? value) {



    if (value == null || value.trim().isEmpty) return 'Required';



    return null;



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



          backgroundColor: isError ? Colors.red.shade700 : primary,



          behavior: SnackBarBehavior.floating,



          margin: const EdgeInsets.all(16),



          shape: RoundedRectangleBorder(



            borderRadius: BorderRadius.circular(12),



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



        surfaceTintColor: Colors.transparent,



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



          padding: const EdgeInsets.fromLTRB(20, 6, 20, 40),



          children: [



            _identityCard(),



            const SizedBox(height: 16),



            _section(



              title: 'Profile Details',



              subtitle: 'Update the shared pricing profile information.',



              icon: Icons.badge_outlined,



              child: _profileDetails(),



            ),



            const SizedBox(height: 16),



            _section(



              title: 'Connected Cars & Pricing Group',



              subtitle:



                  'Connect multiple cars to this profile. Every connected car will use the same pricing.',



              icon: Icons.directions_car_outlined,



              child: _vehicleAndGroup(),



            ),



            const SizedBox(height: 16),



            _section(



              title: 'Rental Packages',



              subtitle:



                  'Configure only hourly and daily packages. Each package can have its own KM allowance and extra-KM rate.',



              icon: Icons.route_outlined,



              child: _packagesSection(),



            ),



            const SizedBox(height: 16),



            _section(



              title: 'Special Date Pricing',



              subtitle:



                  'Use date ranges for weekends, holidays, festivals or high-season periods.',



              icon: Icons.event_available_outlined,



              child: _specialRatesSection(),



            ),



            const SizedBox(height: 16),



            _section(



              title: 'Security Deposit',



              subtitle:



                  'Deposit is separate from the trip total. Monetary deposits affect amount payable; asset deposits do not.',



              icon: Icons.account_balance_wallet_outlined,



              child: _depositSection(),



            ),



            const SizedBox(height: 16),



            _section(



              title: 'Status',



              subtitle: 'Inactive profiles cannot be used for new bookings.',



              icon: Icons.toggle_on_outlined,



              child: SwitchListTile.adaptive(



                contentPadding: EdgeInsets.zero,



                activeColor: primary,



                title: const Text(



                  'Active pricing profile',



                  style: TextStyle(



                    fontFamily: 'Manrope',



                    fontSize: 14,



                    fontWeight: FontWeight.w700,



                    color: heading,



                  ),



                ),



                subtitle: const Text(



                  'Enable this profile for bookings.',



                  style: TextStyle(



                    fontFamily: 'Manrope',



                    fontSize: 12,



                    color: body,



                  ),



                ),



                value: _isActive,



                onChanged: (value) => setState(() => _isActive = value),



              ),



            ),



            const SizedBox(height: 24),



            SizedBox(



              height: 52,



              child: ElevatedButton(



                onPressed: _isSaving ? null : _save,



                style: ElevatedButton.styleFrom(



                  backgroundColor: primary,



                  foregroundColor: Colors.white,



                  disabledBackgroundColor: primary.withValues(alpha: 0.5),



                  elevation: 0,



                  shape: RoundedRectangleBorder(



                    borderRadius: BorderRadius.circular(15),



                  ),



                ),



                child: _isSaving



                    ? const SizedBox(



                        width: 21,



                        height: 21,



                        child: CircularProgressIndicator(



                          strokeWidth: 2.2,



                          color: Colors.white,



                        ),



                      )



                    : const Text(



                        'Save Changes',



                        style: TextStyle(



                          fontFamily: 'Manrope',



                          fontSize: 14,



                          fontWeight: FontWeight.w800,



                        ),



                      ),



              ),



            ),



          ],



        ),



      ),



    );



  }







  Widget _identityCard() {



    return Container(



      padding: const EdgeInsets.all(17),



      decoration: BoxDecoration(



        color: softAccent,



        borderRadius: BorderRadius.circular(18),



        border: Border.all(color: accent.withValues(alpha: 0.18)),



      ),



      child: Row(



        children: [



          const Icon(Icons.price_change_outlined, color: primary, size: 24),



          const SizedBox(width: 12),



          Expanded(



            child: Column(



              crossAxisAlignment: CrossAxisAlignment.start,



              children: [



                const Text(



                  'Pricing Profile ID',



                  style: TextStyle(



                    fontFamily: 'Manrope',



                    fontSize: 10.5,



                    fontWeight: FontWeight.w700,



                    color: body,



                  ),



                ),



                const SizedBox(height: 3),



                Text(



                  widget.profile.id,



                  style: const TextStyle(



                    fontFamily: 'Manrope',



                    fontSize: 13,



                    fontWeight: FontWeight.w800,



                    color: heading,



                  ),



                ),



              ],



            ),



          ),



        ],



      ),



    );



  }







  Widget _profileDetails() {



    return Column(



      children: [



        _field(



          controller: _nameController,



          label: 'Pricing profile name',



          hint: 'Premium SUV',



          validator: _required,



        ),



        const SizedBox(height: 12),



        TextFormField(



          initialValue: widget.profile.currency,



          readOnly: true,



          decoration: _decoration('Currency', widget.profile.currency),



          style: const TextStyle(



            fontFamily: 'Manrope',



            fontWeight: FontWeight.w700,



            color: heading,



          ),



        ),



      ],



    );



  }







  Widget _vehicleAndGroup() {

    final connected = _connectedCars;

    return Column(

      crossAxisAlignment: CrossAxisAlignment.start,

      children: [

        Container(

          padding: const EdgeInsets.all(14),

          decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(16), border: Border.all(color: border)),

          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            Row(children: [

              Container(width: 38, height: 38, decoration: BoxDecoration(color: softAccent, borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.directions_car_outlined, color: primary, size: 20)),

              const SizedBox(width: 10),

              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                const Text('Connected Cars', style: TextStyle(fontFamily: 'Manrope', fontSize: 13.5, fontWeight: FontWeight.w800, color: heading)),

                const SizedBox(height: 2),

                Text('${connected.length} car${connected.length == 1 ? '' : 's'} using this profile', style: const TextStyle(fontFamily: 'Manrope', fontSize: 11, color: body)),

              ])),

              SizedBox(

                height: 38,

                child: OutlinedButton.icon(

                  onPressed: _isConnectingCars || _isLoadingCars ? null : _openConnectCarsDialog,

                  icon: _isConnectingCars ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: primary)) : const Icon(Icons.add_rounded, size: 17),

                  label: const Text('Connect Cars'),

                  style: OutlinedButton.styleFrom(foregroundColor: primary, side: BorderSide(color: primary.withValues(alpha: 0.35)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)), textStyle: const TextStyle(fontFamily: 'Manrope', fontSize: 11.5, fontWeight: FontWeight.w800)),

                ),

              ),

            ]),

            const SizedBox(height: 12),

            if (_isLoadingCars)

              const LinearProgressIndicator(color: primary, backgroundColor: softAccent)

            else if (connected.isEmpty)

              _infoText('No cars are connected yet. Connect one or multiple cars to share this pricing profile.')

            else

              ...connected.map((car) => Container(

                margin: const EdgeInsets.only(bottom: 7),

                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),

                decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(12), border: Border.all(color: border)),

                child: Row(children: [

                  const Icon(Icons.directions_car_filled_outlined, size: 18, color: primary),

                  const SizedBox(width: 9),

                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                    Text(car.name, style: const TextStyle(fontFamily: 'Manrope', fontSize: 12.5, fontWeight: FontWeight.w800, color: heading)),

                    if (car.registrationNumber.trim().isNotEmpty) Text(car.registrationNumber.trim(), style: const TextStyle(fontFamily: 'Manrope', fontSize: 10.5, color: body)),

                  ])),

                  IconButton(tooltip: 'Disconnect', onPressed: _isConnectingCars ? null : () => _disconnectCar(car), icon: const Icon(Icons.link_off_rounded, size: 18, color: muted)),

                ]),

              )),

          ]),

        ),

        const SizedBox(height: 12),

        _field(controller: _pricingGroupController, label: 'Pricing group ID', hint: 'premium_suv', helper: 'Optional. Use the same group ID for cars that share this pricing.'),

      ],

    );

  }



  Widget _packagesSection() {



    return Column(



      crossAxisAlignment: CrossAxisAlignment.start,



      children: [



        Row(



          children: [



            const Expanded(



              child: Text(



                'KM Packages',



                style: TextStyle(



                  fontFamily: 'Manrope',



                  fontSize: 14,



                  fontWeight: FontWeight.w800,



                  color: heading,



                ),



              ),



            ),



            TextButton.icon(



              onPressed: _addPackage,



              icon: const Icon(Icons.add_rounded, size: 18),



              label: const Text('Add Package'),



              style: TextButton.styleFrom(



                foregroundColor: primary,



                textStyle: const TextStyle(



                  fontFamily: 'Manrope',



                  fontWeight: FontWeight.w700,



                ),



              ),



            ),



          ],



        ),



        if (_packages.isEmpty)



          _emptyBox('No KM packages configured.'),



        ...List.generate(



          _packages.length,



          (index) => _packageCard(index, _packages[index]),



        ),



      ],



    );



  }







  Widget _packageCard(int index, _EditPackageDraft package) {



    return Container(



      margin: const EdgeInsets.only(top: 12),



      padding: const EdgeInsets.all(15),



      decoration: BoxDecoration(



        color: background,



        borderRadius: BorderRadius.circular(17),



        border: Border.all(color: border),



      ),



      child: Column(



        children: [



          Row(



            children: [



              Container(



                width: 34,



                height: 34,



                decoration: BoxDecoration(



                  color: softAccent,



                  borderRadius: BorderRadius.circular(10),



                ),



                child: const Icon(



                  Icons.inventory_2_outlined,



                  size: 18,



                  color: primary,



                ),



              ),



              const SizedBox(width: 10),



              Expanded(



                child: Text(



                  'Package ${index + 1}',



                  style: const TextStyle(



                    fontFamily: 'Manrope',



                    fontSize: 13,



                    fontWeight: FontWeight.w800,



                    color: heading,



                  ),



                ),



              ),



              IconButton(



                onPressed: () => _removePackage(index),



                icon: const Icon(



                  Icons.delete_outline_rounded,



                  color: muted,



                  size: 20,



                ),



              ),



            ],



          ),



          const SizedBox(height: 10),



          _field(



            controller: package.idController,



            label: 'Package ID',



            hint: 'suv_500',



            validator: _required,



          ),



          const SizedBox(height: 10),



          _field(



            controller: package.nameController,



            label: 'Package name',



            hint: '500 KM',



            validator: _required,



          ),



          const SizedBox(height: 8),



          SwitchListTile.adaptive(



            contentPadding: EdgeInsets.zero,



            activeColor: primary,



            title: const Text(



              'Unlimited KM',



              style: TextStyle(



                fontFamily: 'Manrope',



                fontSize: 13,



                fontWeight: FontWeight.w700,



                color: heading,



              ),



            ),



            value: package.unlimited,



            onChanged: (value) => setState(() => package.unlimited = value),



          ),



          if (!package.unlimited)



            _field(



              controller: package.kmController,



              label: 'Included KM',



              hint: '500',



              keyboardType: TextInputType.number,



              validator: (value) {



                if (package.unlimited) return null;



                final km = int.tryParse(value?.trim() ?? '');



                return km == null || km <= 0 ? 'Enter included KM' : null;



              },



            ),



          const SizedBox(height: 10),



          Row(



            children: [



              Expanded(



                child: _field(



                  controller: package.hourlyController,



                  label: 'Hourly price',



                  hint: '499',



                  keyboardType: TextInputType.number,



                ),



              ),



              const SizedBox(width: 10),



              Expanded(



                child: _field(



                  controller: package.dailyController,



                  label: 'Daily price',



                  hint: '3199',



                  keyboardType: TextInputType.number,



                ),



              ),



            ],



          ),



          const SizedBox(height: 10),



          _field(



            controller: package.extraKmController,



            label: 'Extra KM rate',



            hint: '14',



            keyboardType: TextInputType.number,



          ),



          const SizedBox(height: 8),



          SwitchListTile.adaptive(



            contentPadding: EdgeInsets.zero,



            activeColor: primary,



            title: const Text(



              'Package active',



              style: TextStyle(



                fontFamily: 'Manrope',



                fontSize: 12.5,



                fontWeight: FontWeight.w700,



                color: heading,



              ),



            ),



            value: package.isActive,



            onChanged: (value) => setState(() => package.isActive = value),



          ),



          _infoText(



            'Daily included KM is multiplied by the number of rental days. Example: 250 KM/day × 4 days = 1,000 KM included.',



          ),



        ],



      ),



    );



  }







  Widget _specialRatesSection() {



    return Column(



      crossAxisAlignment: CrossAxisAlignment.start,



      children: [



        Row(



          children: [



            const Expanded(



              child: Text(



                'Special Date Rules',



                style: TextStyle(



                  fontFamily: 'Manrope',



                  fontSize: 14,



                  fontWeight: FontWeight.w800,



                  color: heading,



                ),



              ),



            ),



            TextButton.icon(



              onPressed: _addSpecialRate,



              icon: const Icon(Icons.add_rounded, size: 18),



              label: const Text('Add Rule'),



              style: TextButton.styleFrom(foregroundColor: primary),



            ),



          ],



        ),



        if (_specialRates.isEmpty)



          _emptyBox(



            'No special rates. Normal package prices will be used.',



          ),



        ...List.generate(



          _specialRates.length,



          (index) => _specialRateCard(index, _specialRates[index]),



        ),



      ],



    );



  }







  Widget _specialRateCard(int index, _EditSpecialRateDraft rate) {



    return Container(



      margin: const EdgeInsets.only(top: 12),



      padding: const EdgeInsets.all(15),



      decoration: BoxDecoration(



        color: background,



        borderRadius: BorderRadius.circular(17),



        border: Border.all(color: border),



      ),



      child: Column(



        crossAxisAlignment: CrossAxisAlignment.start,



        children: [



          Row(



            children: [



              const Icon(Icons.event_outlined, color: primary, size: 20),



              const SizedBox(width: 8),



              Expanded(



                child: Text(



                  'Special Rule ${index + 1}',



                  style: const TextStyle(



                    fontFamily: 'Manrope',



                    fontWeight: FontWeight.w800,



                    color: heading,



                  ),



                ),



              ),



              IconButton(



                onPressed: () => _removeSpecialRate(index),



                icon: const Icon(Icons.delete_outline, color: muted),



              ),



            ],



          ),



          _field(



            controller: rate.nameController,



            label: 'Rule name',



            hint: 'Diwali / New Year / Holiday',



          ),



          const SizedBox(height: 12),



          Row(



            children: [



              Expanded(



                child: _datePickerField(



                  label: 'Start date',



                  value: rate.startDate,



                  onTap: () => _pickSpecialDate(rate, start: true),



                ),



              ),



              const SizedBox(width: 10),



              Expanded(



                child: _datePickerField(



                  label: 'End date',



                  value: rate.endDate,



                  onTap: () => _pickSpecialDate(rate, start: false),



                ),



              ),



            ],



          ),



          const SizedBox(height: 12),



          _field(



            controller: rate.extraKmController,



            label: 'Special extra KM rate',



            hint: '20',



            keyboardType: TextInputType.number,



            helper: 'Leave blank to keep each package normal extra-KM rate.',



          ),



          const SizedBox(height: 12),



          const Text(



            'Package-specific special prices',



            style: TextStyle(



              fontFamily: 'Manrope',



              fontSize: 12.5,



              fontWeight: FontWeight.w800,



              color: heading,



            ),



          ),



          const SizedBox(height: 8),



          if (_packages.isEmpty)



            _infoText('Add packages above before configuring special prices.'),



          ..._packages.map(



            (package) => _specialPackageRow(rate, package),



          ),



          const SizedBox(height: 8),



          SwitchListTile.adaptive(



            contentPadding: EdgeInsets.zero,



            activeColor: primary,



            title: const Text(



              'Rule active',



              style: TextStyle(



                fontFamily: 'Manrope',



                fontWeight: FontWeight.w700,



                fontSize: 12.5,



                color: heading,



              ),



            ),



            value: rate.isActive,



            onChanged: (value) => setState(() => rate.isActive = value),



          ),



        ],



      ),



    );



  }







  Widget _specialPackageRow(



    _EditSpecialRateDraft rate,



    _EditPackageDraft package,



  ) {



    final id = package.idController.text.trim();



    if (id.isEmpty) {



      return _infoText('Enter package ID to configure its special price.');



    }







    final hourly = rate.hourlyControllers.putIfAbsent(



      id,



      () => TextEditingController(),



    );



    final daily = rate.dailyControllers.putIfAbsent(



      id,



      () => TextEditingController(),



    );







    return Container(



      margin: const EdgeInsets.only(bottom: 8),



      padding: const EdgeInsets.all(10),



      decoration: BoxDecoration(



        color: card,



        borderRadius: BorderRadius.circular(12),



        border: Border.all(color: border),



      ),



      child: Column(



        crossAxisAlignment: CrossAxisAlignment.start,



        children: [



          Text(



            package.nameController.text.trim().isEmpty



                ? id



                : package.nameController.text.trim(),



            style: const TextStyle(



              fontFamily: 'Manrope',



              fontWeight: FontWeight.w700,



              fontSize: 12,



              color: heading,



            ),



          ),



          const SizedBox(height: 8),



          Row(



            children: [



              Expanded(



                child: _field(



                  controller: hourly,



                  label: 'Special hourly',



                  hint: '599',



                  keyboardType: TextInputType.number,



                ),



              ),



              const SizedBox(width: 8),



              Expanded(



                child: _field(



                  controller: daily,



                  label: 'Special daily',



                  hint: '3499',



                  keyboardType: TextInputType.number,



                ),



              ),



            ],



          ),



        ],



      ),



    );



  }







  Widget _depositSection() {



    final isMoney = _depositType.isMonetary;



    final isAsset = _depositType == DepositType.vehicleAsset ||



        _depositType == DepositType.otherAsset;







    return Column(



      children: [



        DropdownButtonFormField<DepositType>(



          initialValue: _depositType,



          decoration: _decoration('Deposit type', 'Select deposit type'),



          items: DepositType.values



              .map(



                (type) => DropdownMenuItem<DepositType>(



                  value: type,



                  child: Text(



                    _depositLabel(type),



                    style: const TextStyle(



                      fontFamily: 'Manrope',



                      fontSize: 13,



                      color: heading,



                    ),



                  ),



                ),



              )



              .toList(),



          onChanged: (type) {



            if (type == null) return;



            setState(() => _depositType = type);



          },



        ),



        if (isMoney) ...[



          const SizedBox(height: 12),



          _field(



            controller: _depositAmountController,



            label: 'Security deposit amount',



            hint: '5000',



            keyboardType: TextInputType.number,



          ),



          const SizedBox(height: 12),



          _field(



            controller: _paymentMethodController,



            label: 'Default payment method',



            hint: 'Cash / UPI / Bank Transfer',



          ),



        ],



        if (isAsset) ...[



          const SizedBox(height: 12),



          _field(



            controller: _assetDescriptionController,



            label: 'Asset description',



            hint: 'Customer bike / other asset',



          ),



          const SizedBox(height: 12),



          _field(



            controller: _minimumAssetValueController,



            label: 'Minimum asset value',



            hint: '50000',



            keyboardType: TextInputType.number,



          ),



        ],



        if (_depositType == DepositType.none)



          Padding(



            padding: const EdgeInsets.only(top: 10),



            child: _infoText('No security deposit will be required by default.'),



          ),



        if (isMoney)



          Padding(



            padding: const EdgeInsets.only(top: 10),



            child: _infoText(



              'The deposit is not included in Trip Total. It is added separately to the amount payable when collected.',



            ),



          ),



        if (isAsset)



          Padding(



            padding: const EdgeInsets.only(top: 10),



            child: _infoText(



              'Customer bike/asset deposits are security records and do not add money to the trip total or amount payable.',



            ),



          ),



      ],



    );



  }







  String _depositLabel(DepositType type) {



    switch (type) {



      case DepositType.none:



        return 'No Deposit';



      case DepositType.cash:



        return 'Cash';



      case DepositType.online:



        return 'Online / UPI';



      case DepositType.bankTransfer:



        return 'Bank Transfer';



      case DepositType.vehicleAsset:



        return 'Customer Bike';



      case DepositType.otherAsset:



        return 'Other Asset';



    }



  }







  Widget _section({



    required String title,



    required String subtitle,



    required IconData icon,



    required Widget child,



  }) {



    return Container(



      padding: const EdgeInsets.all(17),



      decoration: BoxDecoration(



        color: card,



        borderRadius: BorderRadius.circular(20),



        border: Border.all(color: border),



        boxShadow: const [



          BoxShadow(



            blurRadius: 18,



            offset: Offset(0, 5),



            color: Color(0x0A17201F),



          ),



        ],



      ),



      child: Column(



        crossAxisAlignment: CrossAxisAlignment.start,



        children: [



          Row(



            children: [



              Container(



                width: 38,



                height: 38,



                decoration: BoxDecoration(



                  color: softAccent,



                  borderRadius: BorderRadius.circular(11),



                ),



                child: Icon(icon, color: primary, size: 20),



              ),



              const SizedBox(width: 11),



              Expanded(



                child: Column(



                  crossAxisAlignment: CrossAxisAlignment.start,



                  children: [



                    Text(



                      title,



                      style: const TextStyle(



                        fontFamily: 'Manrope',



                        fontSize: 15,



                        fontWeight: FontWeight.w800,



                        color: heading,



                      ),



                    ),



                    const SizedBox(height: 2),



                    Text(



                      subtitle,



                      style: const TextStyle(



                        fontFamily: 'Manrope',



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



          const SizedBox(height: 16),



          child,



        ],



      ),



    );



  }







  Widget _field({



    required TextEditingController controller,



    required String label,



    required String hint,



    TextInputType? keyboardType,



    String? helper,



    String? Function(String?)? validator,



  }) {



    return TextFormField(



      controller: controller,



      keyboardType: keyboardType,



      validator: validator,



      style: const TextStyle(



        fontFamily: 'Manrope',



        fontSize: 13,



        fontWeight: FontWeight.w600,



        color: heading,



      ),



      decoration: _decoration(label, hint, helper: helper),



    );



  }







  InputDecoration _decoration(



    String label,



    String hint, {



    String? helper,



  }) {



    return InputDecoration(



      labelText: label,



      hintText: hint,



      helperText: helper,



      labelStyle: const TextStyle(



        fontFamily: 'Manrope',



        fontSize: 12,



        color: body,



      ),



      hintStyle: const TextStyle(



        fontFamily: 'Manrope',



        fontSize: 12,



        color: muted,



      ),



      helperStyle: const TextStyle(



        fontFamily: 'Manrope',



        fontSize: 10.5,



        color: muted,



      ),



      filled: true,



      fillColor: background,



      contentPadding: const EdgeInsets.symmetric(



        horizontal: 13,



        vertical: 13,



      ),



      border: OutlineInputBorder(



        borderRadius: BorderRadius.circular(13),



        borderSide: const BorderSide(color: border),



      ),



      enabledBorder: OutlineInputBorder(



        borderRadius: BorderRadius.circular(13),



        borderSide: const BorderSide(color: border),



      ),



      focusedBorder: OutlineInputBorder(



        borderRadius: BorderRadius.circular(13),



        borderSide: const BorderSide(color: primary, width: 1.3),



      ),



      errorBorder: OutlineInputBorder(



        borderRadius: BorderRadius.circular(13),



        borderSide: BorderSide(color: Colors.red.shade300),



      ),



      focusedErrorBorder: OutlineInputBorder(



        borderRadius: BorderRadius.circular(13),



        borderSide: BorderSide(color: Colors.red.shade600),



      ),



    );



  }







  Widget _datePickerField({



    required String label,



    required DateTime? value,



    required VoidCallback onTap,



  }) {



    return InkWell(



      borderRadius: BorderRadius.circular(13),



      onTap: onTap,



      child: InputDecorator(



        decoration: _decoration(label, 'Select date'),



        child: Row(



          children: [



            const Icon(Icons.calendar_today_outlined, size: 16, color: primary),



            const SizedBox(width: 8),



            Expanded(



              child: Text(



                _dateLabel(value),



                style: TextStyle(



                  fontFamily: 'Manrope',



                  fontSize: 12.5,



                  fontWeight: FontWeight.w600,



                  color: value == null ? muted : heading,



                ),



              ),



            ),



          ],



        ),



      ),



    );



  }







  Widget _emptyBox(String message) {



    return Container(



      width: double.infinity,



      margin: const EdgeInsets.only(top: 10),



      padding: const EdgeInsets.all(15),



      decoration: BoxDecoration(



        color: background,



        borderRadius: BorderRadius.circular(14),



        border: Border.all(color: border),



      ),



      child: Text(



        message,



        style: const TextStyle(



          fontFamily: 'Manrope',



          fontSize: 12,



          color: body,



        ),



      ),



    );



  }







  Widget _infoText(String text) {



    return Text(



      text,



      style: const TextStyle(



        fontFamily: 'Manrope',



        fontSize: 10.8,



        height: 1.35,



        color: muted,



      ),



    );



  }



}







class _EditPackageDraft {



  final idController = TextEditingController();



  final nameController = TextEditingController();



  final kmController = TextEditingController();



  final hourlyController = TextEditingController();



  final dailyController = TextEditingController();



  final extraKmController = TextEditingController();







  bool unlimited = false;



  bool isActive = true;







  _EditPackageDraft();







  factory _EditPackageDraft.fromPackage(KmPricingPackage package) {



    final draft = _EditPackageDraft();



    draft.idController.text = package.id;



    draft.nameController.text = package.name;



    draft.kmController.text = package.includedKm?.toString() ?? '';



    draft.hourlyController.text = _numberText(package.hourlyRate);



    draft.dailyController.text = _numberText(package.dailyRate);



    draft.extraKmController.text = _numberText(package.extraKmRate);



    draft.unlimited = package.unlimitedKm;



    draft.isActive = package.isActive;



    return draft;



  }







  static String _numberText(double value) {



    if (value == value.roundToDouble()) return value.toInt().toString();



    return value.toString();



  }







  void dispose() {



    idController.dispose();



    nameController.dispose();



    kmController.dispose();



    hourlyController.dispose();



    dailyController.dispose();



    extraKmController.dispose();



  }



}







class _EditSpecialRateDraft {



  final String id;



  final nameController = TextEditingController();



  final extraKmController = TextEditingController();



  final Map<String, TextEditingController> hourlyControllers = {};



  final Map<String, TextEditingController> dailyControllers = {};







  DateTime? startDate;



  DateTime? endDate;



  bool isActive;







  _EditSpecialRateDraft({



    this.id = '',



    this.startDate,



    this.endDate,



    this.isActive = true,



  });







  factory _EditSpecialRateDraft.fromSpecialRate(SpecialRate rate) {



    final draft = _EditSpecialRateDraft(



      id: rate.id,



      startDate: rate.startDate,



      endDate: rate.endDate,



      isActive: rate.isActive,



    );



    draft.nameController.text = rate.name;



    if (rate.extraKmRate != null) {



      draft.extraKmController.text = rate.extraKmRate.toString();



    }







    for (final entry in rate.hourlyPrices.entries) {



      final controller = TextEditingController();



      controller.text = _numberText(entry.value);



      draft.hourlyControllers[entry.key] = controller;



    }



    for (final entry in rate.dailyPrices.entries) {



      final controller = TextEditingController();



      controller.text = _numberText(entry.value);



      draft.dailyControllers[entry.key] = controller;



    }







    return draft;



  }







  static String _numberText(double value) {



    if (value == value.roundToDouble()) return value.toInt().toString();



    return value.toString();



  }







  void dispose() {



    nameController.dispose();



    extraKmController.dispose();



    for (final controller in hourlyControllers.values) {



      controller.dispose();



    }



    for (final controller in dailyControllers.values) {



      controller.dispose();



    }



  }



}
