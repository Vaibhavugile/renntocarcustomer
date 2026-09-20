import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/config/app_config.dart';
import '../../../cars/models/car.dart';
import '../../../cars/services/car_service.dart';
import '../../../pricing/models/pricing_profile.dart';
import '../../../pricing/services/pricing_profile_service.dart';

/// Admin vehicle editor.
///
/// Important pricing architecture:
/// - A car stores only `pricingProfileId`.
/// - The pricing profile itself stores hourly/daily packages, special rates,
///   pricing group and security-deposit configuration.
/// - A pricing profile may be shared by multiple cars.
/// - Editing a car NEVER modifies the pricing profile document.
///
/// Firestore relationship:
///
/// tenants/{tenantId}/cars/{carId}
///   pricingProfileId: "nO2RJ9228JUgcP9z3AGY"
///
/// tenants/{tenantId}/pricingProfiles/{pricingProfileId}
///   hourlyPackages: [...]
///   dailyPackages: [...]
///   specialRates: [...]
///   pricingGroupId: "pricing_reddy"
///   securityDeposit: {...}
class AdminEditCarScreen extends StatefulWidget {
  final Car car;

  const AdminEditCarScreen({
    super.key,
    required this.car,
  });

  @override
  State<AdminEditCarScreen> createState() => _AdminEditCarScreenState();
}

class _AdminEditCarScreenState extends State<AdminEditCarScreen> {
  // ---------------------------------------------------------------------------
  // FIXED PREMIUM PALETTE
  // ---------------------------------------------------------------------------

  static const Color background = Color(0xFFF8FAF9);
  static const Color card = Color(0xFFFFFFFF);
  static const Color primary = Color(0xFF0F766E);
  static const Color accent = Color(0xFF14B8A6);
  static const Color softAccent = Color(0xFFE6FFFB);
  static const Color heading = Color(0xFF17201F);
  static const Color body = Color(0xFF66706E);
  static const Color muted = Color(0xFF94A09D);
  static const Color border = Color(0xFFE5EBE9);

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _registrationController;
  late final TextEditingController _priceController;
  late final TextEditingController _sortOrderController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _featuresController;
  late final TextEditingController _branchIdsController;

  late String _type;
  late int _seats;
  late String _transmission;
  late String _fuel;

  late bool _isActive;
  late bool _isAvailable;
  late bool _isFeatured;

  // Pricing connection.
  final TextEditingController _pricingProfileSearchController =
      TextEditingController();

  List<PricingProfile> _pricingProfiles = <PricingProfile>[];
  PricingProfile? _selectedPricingProfile;
  bool _loadingPricingProfiles = false;
  bool _pricingProfilesLoaded = false;

  bool _isSaving = false;
  String? _pricingLoadError;

  final List<String> _types = <String>[
    'Hatchback',
    'Sedan',
    'SUV',
    'MUV',
    'Luxury',
    'Premium',
    'Convertible',
    'Electric',
  ];

  final List<int> _seatOptions = <int>[
    2,
    4,
    5,
    6,
    7,
    8,
    9,
  ];

  final List<String> _transmissions = <String>[
    'Manual',
    'Automatic',
    'AMT',
    'CVT',
    'DCT',
  ];

  final List<String> _fuels = <String>[
    'Petrol',
    'Diesel',
    'CNG',
    'Electric',
    'Hybrid',
  ];

  String get _tenantId => AppConfig.tenant.tenantId.trim();

  @override
  void initState() {
    super.initState();

    final car = widget.car;

    _nameController = TextEditingController(text: car.name);
    _registrationController =
        TextEditingController(text: car.registrationNumber);
    _priceController =
        TextEditingController(text: car.pricePerDay.toString());
    _sortOrderController =
        TextEditingController(text: car.sortOrder.toString());
    _descriptionController =
        TextEditingController(text: car.description);
    _featuresController =
        TextEditingController(text: car.features.join(', '));
    _branchIdsController =
        TextEditingController(text: car.branchIds.join(', '));

    _type = _types.contains(car.type) ? car.type : _types.first;
    _seats = _seatOptions.contains(car.seats) ? car.seats : 5;
    _transmission = _transmissions.contains(car.transmission)
        ? car.transmission
        : _transmissions.first;
    _fuel = _fuels.contains(car.fuel) ? car.fuel : _fuels.first;

    _isActive = car.isActive;
    _isAvailable = car.isAvailable;
    _isFeatured = car.isFeatured;

    // Load profiles immediately so the existing connection is resolved into
    // the actual pricing profile rather than requiring manual ID typing.
    _loadPricingProfiles();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _registrationController.dispose();
    _priceController.dispose();
    _sortOrderController.dispose();
    _descriptionController.dispose();
    _featuresController.dispose();
    _branchIdsController.dispose();
    _pricingProfileSearchController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // PRICING PROFILE LOADING
  // ---------------------------------------------------------------------------

  Future<void> _loadPricingProfiles() async {
    if (_tenantId.isEmpty) {
      if (mounted) {
        setState(() {
          _pricingLoadError = 'Tenant configuration is missing.';
          _pricingProfilesLoaded = true;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _loadingPricingProfiles = true;
        _pricingLoadError = null;
      });
    }

    try {
      final profiles =
          await PricingProfileService.instance.getAllPricingProfiles(
        tenantId: _tenantId,
        activeOnly: false,
      );

      PricingProfile? selected;

      final currentId = widget.car.pricingProfileId.trim();
      if (currentId.isNotEmpty) {
        for (final profile in profiles) {
          if (profile.id.trim() == currentId) {
            selected = profile;
            break;
          }
        }

        // The profile may have been created after the car screen was opened,
        // or may not be returned by a filtered query. Resolve it directly.
        if (selected == null) {
          selected =
              await PricingProfileService.instance.getPricingProfileById(
            tenantId: _tenantId,
            pricingProfileId: currentId,
          );
        }
      }

      if (!mounted) return;

      setState(() {
        _pricingProfiles = profiles;

        if (selected != null &&
            !_pricingProfiles.any((item) => item.id == selected!.id)) {
          _pricingProfiles = <PricingProfile>[
            ..._pricingProfiles,
            selected!,
          ];
          _pricingProfiles.sort(
            (a, b) => a.name.toLowerCase().compareTo(
                  b.name.toLowerCase(),
                ),
          );
        }

        _selectedPricingProfile = selected;
        _loadingPricingProfiles = false;
        _pricingProfilesLoaded = true;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingPricingProfiles = false;
        _pricingProfilesLoaded = true;
        _pricingLoadError =
            'Unable to load pricing profiles. You can still enter the profile ID manually.';
      });
    }
  }

  void _selectPricingProfile(PricingProfile? profile) {
    setState(() {
      _selectedPricingProfile = profile;
    });
  }

  Future<void> _openPricingProfilePicker() async {
    FocusScope.of(context).unfocus();

    if (_loadingPricingProfiles) {
      _showError('Pricing profiles are still loading.');
      return;
    }

    if (_pricingProfiles.isEmpty) {
      await _loadPricingProfiles();
      if (!mounted) return;

      if (_pricingProfiles.isEmpty) {
        _showError(
          _pricingLoadError ??
              'No pricing profiles are available for this tenant.',
        );
        return;
      }
    }

    _pricingProfileSearchController.clear();

    final selected = await showModalBottomSheet<PricingProfile>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _PricingProfilePickerSheet(
          profiles: _pricingProfiles,
          selectedProfileId: _selectedPricingProfile?.id,
          searchController: _pricingProfileSearchController,
        );
      },
    );

    if (selected == null || !mounted) return;

    _selectPricingProfile(selected);
  }

  // ---------------------------------------------------------------------------
  // SAVE
  // ---------------------------------------------------------------------------

  Future<void> _updateCar() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_tenantId.isEmpty) {
      _showError('Tenant configuration is missing.');
      return;
    }

    final carId = widget.car.id.trim();
    if (carId.isEmpty) {
      _showError('Car ID is missing. Unable to update this vehicle.');
      return;
    }

    final price = int.tryParse(_priceController.text.trim());
    if (price == null || price < 0) {
      _showError('Please enter a valid display price per day.');
      return;
    }

    final sortOrder = int.tryParse(_sortOrderController.text.trim());
    if (sortOrder == null || sortOrder < 0) {
      _showError('Please enter a valid sort order.');
      return;
    }

    final pricingProfileId = _selectedPricingProfile?.id.trim() ?? '';

    if (pricingProfileId.isEmpty) {
      _showError(
        'Please select a pricing profile before saving the vehicle.',
      );
      return;
    }

    final selectedProfile = _pricingProfiles
        .where((profile) => profile.id.trim() == pricingProfileId)
        .cast<PricingProfile?>()
        .firstWhere(
          (profile) => profile != null,
          orElse: () => null,
        );

    // If the selected profile is not in the locally loaded list, verify it
    // directly from Firestore before writing the car.
    PricingProfile? verifiedProfile = selectedProfile;
    try {
      verifiedProfile ??=
          await PricingProfileService.instance.getPricingProfileById(
        tenantId: _tenantId,
        pricingProfileId: pricingProfileId,
      );
    } catch (_) {
      // The actual save will not proceed without a profile.
    }

    if (verifiedProfile == null) {
      _showError('The selected pricing profile no longer exists.');
      return;
    }

    if (!verifiedProfile.isActive) {
      _showError(
        'The selected pricing profile is inactive. Activate it first or select another profile.',
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final features = _featuresController.text
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList();

      final branchIds = _branchIdsController.text
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList();

      final status = !_isActive
          ? 'inactive'
          : (!_isAvailable ? 'unavailable' : 'available');

      final updatedCar = Car(
        id: carId,
        tenantId: _tenantId,
        name: _nameController.text.trim(),
        type: _type,
        transmission: _transmission,
        seats: _seats,
        fuel: _fuel,

        // THIS is the actual vehicle → pricing-profile connection.
        pricingProfileId: pricingProfileId,

        // Keep the car's display price for legacy/listing UI. Booking
        // calculations use the selected pricing profile.
        pricePerDay: price,

        // Preserve existing image data.
        image: widget.car.image,
        images: widget.car.images,

        registrationNumber: _registrationController.text.trim(),
        description: _descriptionController.text.trim(),
        features: features,
        branchIds: branchIds,
        status: status,
        isAvailable: _isAvailable,
        isFeatured: _isFeatured,
        isActive: _isActive,
        sortOrder: sortOrder,
      );

      await CarService.instance.updateCar(
        tenantId: _tenantId,
        carId: carId,
        car: updatedCar,
      );

      if (!mounted) return;

      // Keep the local selected profile in sync with the saved relationship.
      setState(() {
        _selectedPricingProfile = verifiedProfile;
        _isSaving = false;
      });

      _showSuccess(
        'Car updated and connected to "${verifiedProfile.name}".',
      );

      // Return the updated car as well as the "changed" result. Existing car
      // list screens that only check for true continue to work.
      Navigator.pop(context, updatedCar);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      _showError(
        'Unable to update car. ${_cleanError(e)}',
      );
    }
  }

  String _cleanError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    if (message.isEmpty) {
      return 'Please try again.';
    }
    return message;
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: heading,
          ),
        ),
        title: Text(
          'Edit Car',
          style: GoogleFonts.manrope(
            color: heading,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
            children: [
              _buildCarHeader(),
              const SizedBox(height: 18),

              _buildPricingConnectionSection(),
              const SizedBox(height: 16),

              _buildSection(
                title: 'Basic Information',
                icon: Icons.directions_car_rounded,
                children: [
                  _buildTextField(
                    controller: _nameController,
                    label: 'Car Name',
                    hint: 'e.g. Hyundai Creta',
                    icon: Icons.drive_eta_rounded,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Car name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  _buildDropdown<String>(
                    label: 'Vehicle Type',
                    value: _type,
                    items: _types,
                    icon: Icons.category_rounded,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _type = value);
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdown<int>(
                          label: 'Seats',
                          value: _seats,
                          items: _seatOptions,
                          icon: Icons.event_seat_rounded,
                          itemLabel: (value) => '$value Seats',
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _seats = value);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDropdown<String>(
                          label: 'Transmission',
                          value: _transmission,
                          items: _transmissions,
                          icon: Icons.settings_rounded,
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _transmission = value);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildDropdown<String>(
                    label: 'Fuel Type',
                    value: _fuel,
                    items: _fuels,
                    icon: Icons.local_gas_station_rounded,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _fuel = value);
                    },
                  ),
                ],
              ),

              const SizedBox(height: 16),

              _buildSection(
                title: 'Vehicle Details',
                icon: Icons.badge_rounded,
                children: [
                  _buildTextField(
                    controller: _registrationController,
                    label: 'Registration Number',
                    hint: 'e.g. MH12AB1234',
                    icon: Icons.confirmation_number_rounded,
                    textCapitalization: TextCapitalization.characters,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Registration number is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: _descriptionController,
                    label: 'Description',
                    hint: 'Short description of the vehicle',
                    icon: Icons.notes_rounded,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: _featuresController,
                    label: 'Features',
                    hint: 'AC, Bluetooth, Rear Camera',
                    icon: Icons.auto_awesome_rounded,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 7),
                  _helperText(
                    'Separate multiple features with commas.',
                  ),
                ],
              ),

              const SizedBox(height: 16),

              _buildSection(
                title: 'Vehicle Display Pricing',
                icon: Icons.payments_rounded,
                children: [
                  _buildTextField(
                    controller: _priceController,
                    label: 'Display Price / Day',
                    hint: '2499',
                    icon: Icons.currency_rupee_rounded,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Display price is required';
                      }
                      final parsed = int.tryParse(value.trim());
                      if (parsed == null || parsed < 0) {
                        return 'Enter a valid price';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildInfoBox(
                    text:
                        'This is the car-listing/display price. Booking calculations use the connected pricing profile and its hourly/daily KM packages.',
                  ),
                ],
              ),

              const SizedBox(height: 16),

              _buildSection(
                title: 'Branch Assignment',
                icon: Icons.location_on_rounded,
                children: [
                  _buildTextField(
                    controller: _branchIdsController,
                    label: 'Branch IDs',
                    hint: 'branch_001, branch_002',
                    icon: Icons.store_rounded,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 7),
                  _helperText(
                    'Separate multiple branch IDs with commas.',
                  ),
                ],
              ),

              const SizedBox(height: 16),

              _buildSection(
                title: 'Vehicle Status',
                icon: Icons.tune_rounded,
                children: [
                  _buildSwitchTile(
                    title: 'Active',
                    subtitle: 'Vehicle is active in the admin system',
                    value: _isActive,
                    onChanged: (value) {
                      setState(() {
                        _isActive = value;
                        if (!value) {
                          _isAvailable = false;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildSwitchTile(
                    title: 'Available',
                    subtitle: 'Vehicle can currently be booked',
                    value: _isAvailable,
                    enabled: _isActive,
                    onChanged: (value) {
                      setState(() => _isAvailable = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildSwitchTile(
                    title: 'Featured Car',
                    subtitle: 'Show this vehicle in featured sections',
                    value: _isFeatured,
                    onChanged: (value) {
                      setState(() => _isFeatured = value);
                    },
                  ),
                ],
              ),

              const SizedBox(height: 16),

              _buildSection(
                title: 'Display Order',
                icon: Icons.sort_rounded,
                children: [
                  _buildTextField(
                    controller: _sortOrderController,
                    label: 'Sort Order',
                    hint: '1',
                    icon: Icons.format_list_numbered_rounded,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Sort order is required';
                      }
                      final parsed = int.tryParse(value.trim());
                      if (parsed == null || parsed < 0) {
                        return 'Enter a valid number';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        child: SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _updateCar,
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              disabledBackgroundColor: primary.withValues(alpha: 0.55),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(17),
              ),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 21,
                      ),
                      const SizedBox(width: 9),
                      Text(
                        'Save Car & Pricing Connection',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PRICING CONNECTION CARD
  // ---------------------------------------------------------------------------

  Widget _buildPricingConnectionSection() {
    final profile = _selectedPricingProfile;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: profile == null ? border : accent.withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: softAccent,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.link_rounded,
                  color: primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pricing Profile Connection',
                      style: GoogleFonts.manrope(
                        color: heading,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Connect this car to the pricing you created in Pricing Profiles.',
                      style: GoogleFonts.manrope(
                        color: body,
                        fontSize: 11.5,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          if (_loadingPricingProfiles)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: border),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Loading pricing profiles...',
                    style: GoogleFonts.manrope(
                      color: body,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            if (_pricingLoadError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildWarningBox(_pricingLoadError!),
              ),

            InkWell(
              onTap: _openPricingProfilePicker,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: profile == null ? border : primary,
                    width: profile == null ? 1 : 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: profile == null
                            ? Colors.white
                            : softAccent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        profile == null
                            ? Icons.price_change_outlined
                            : Icons.check_circle_rounded,
                        color: profile == null ? muted : primary,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: profile == null
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Select Pricing Profile',
                                  style: GoogleFonts.manrope(
                                    color: heading,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Choose the pricing profile for this car',
                                  style: GoogleFonts.manrope(
                                    color: body,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  profile.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.manrope(
                                    color: heading,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  profile.id,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.manrope(
                                    color: primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: body,
                    ),
                  ],
                ),
              ),
            ),

            if (profile != null) ...[
              const SizedBox(height: 12),
              _buildPricingProfileSummary(profile),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildPricingProfileSummary(PricingProfile profile) {
    final hourlyCount = profile.hourlyPackages.length;
    final dailyCount = profile.dailyPackages.length;
    final specialCount = profile.specialRates.length;

    final depositAmount = profile.securityDeposit.monetaryAmount;
    final depositType =
        profile.securityDeposit.type.value;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: softAccent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accent.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.verified_rounded,
                color: primary,
                size: 18,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Connected pricing',
                  style: GoogleFonts.manrope(
                    color: primary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _smallStatusBadge(profile.isActive),
            ],
          ),

          const SizedBox(height: 11),

          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _metricChip(
                Icons.schedule_rounded,
                '$hourlyCount hourly',
              ),
              _metricChip(
                Icons.today_rounded,
                '$dailyCount daily',
              ),
              _metricChip(
                Icons.event_available_rounded,
                '$specialCount special',
              ),
              if (profile.pricingGroupId.trim().isNotEmpty)
                _metricChip(
                  Icons.layers_outlined,
                  profile.pricingGroupId,
                ),
            ],
          ),

          const SizedBox(height: 10),

          Text(
            depositType == 'none'
                ? 'Security deposit: None'
                : depositAmount > 0
                    ? 'Security deposit: ${_labelize(depositType)} • ₹${_formatAmount(depositAmount)}'
                    : 'Security deposit: ${_labelize(depositType)}',
            style: GoogleFonts.manrope(
              color: body,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 3),

          Text(
            'The car stores only this profile ID. Package and special-rate changes are managed from the Pricing Profile screen.',
            style: GoogleFonts.manrope(
              color: body,
              fontSize: 11,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: primary,
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: GoogleFonts.manrope(
              color: heading,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallStatusBadge(bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: active ? Colors.white : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        active ? 'Active' : 'Inactive',
        style: GoogleFonts.manrope(
          color: active ? primary : Colors.orange.shade800,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // COMMON UI
  // ---------------------------------------------------------------------------

  Widget _buildCarHeader() {
    final image = widget.car.image.trim();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: softAccent,
              borderRadius: BorderRadius.circular(18),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: image.isNotEmpty
                  ? Image.network(
                      image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _carIcon(),
                    )
                  : _carIcon(),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.car.name.isEmpty
                      ? 'Edit Vehicle'
                      : widget.car.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    color: heading,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.car.registrationNumber.isEmpty
                      ? 'Vehicle details'
                      : widget.car.registrationNumber,
                  style: GoogleFonts.manrope(
                    color: body,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          _statusBadge(),
        ],
      ),
    );
  }

  Widget _carIcon() {
    return const Icon(
      Icons.directions_car_rounded,
      color: primary,
      size: 31,
    );
  }

  Widget _statusBadge() {
    final String text;
    final Color bg;
    final Color fg;

    if (!_isActive) {
      text = 'Inactive';
      bg = Colors.grey.shade100;
      fg = Colors.grey.shade700;
    } else if (!_isAvailable) {
      text = 'Unavailable';
      bg = Colors.orange.shade50;
      fg = Colors.orange.shade800;
    } else {
      text = 'Available';
      bg = softAccent;
      fg = primary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        text,
        style: GoogleFonts.manrope(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 16,
            offset: const Offset(0, 6),
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
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 11),
              Text(
                title,
                style: GoogleFonts.manrope(
                  color: heading,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      maxLines: maxLines,
      style: GoogleFonts.manrope(
        color: heading,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      decoration: _inputDecoration(
        label: label,
        hint: hint,
        icon: icon,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: GoogleFonts.manrope(
        color: body,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: GoogleFonts.manrope(
        color: muted,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: Icon(
        icon,
        color: primary,
        size: 20,
      ),
      filled: true,
      fillColor: background,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 15,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: primary,
          width: 1.4,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: Colors.red.shade300,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: Colors.red.shade400,
          width: 1.2,
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required IconData icon,
    required ValueChanged<T?> onChanged,
    String Function(T value)? itemLabel,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      onChanged: onChanged,
      isExpanded: true,
      style: GoogleFonts.manrope(
        color: heading,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: body,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.manrope(
          color: body,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: Icon(
          icon,
          color: primary,
          size: 20,
        ),
        filled: true,
        fillColor: background,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 4,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: primary,
            width: 1.4,
          ),
        ),
      ),
      items: items.map((item) {
        return DropdownMenuItem<T>(
          value: item,
          child: Text(
            itemLabel != null ? itemLabel(item) : item.toString(),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.manrope(
                    color: enabled ? heading : muted,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.manrope(
                    color: enabled ? body : muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: enabled ? onChanged : null,
            activeColor: primary,
            activeTrackColor: accent,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox({required String text}) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: softAccent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accent.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: primary,
            size: 18,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.manrope(
                color: body,
                fontSize: 11.5,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningBox(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: Colors.orange.shade100,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange.shade800,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.manrope(
                color: Colors.orange.shade900,
                fontSize: 11,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _helperText(String text) {
    return Text(
      text,
      style: GoogleFonts.manrope(
        fontSize: 12,
        color: muted,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  String _labelize(String value) {
    return value
        .replaceAll('_', ' ')
        .replaceAllMapped(
          RegExp(r'([a-z])([A-Z])'),
          (match) => '${match.group(1)} ${match.group(2)}',
        )
        .split(' ')
        .where((item) => item.isNotEmpty)
        .map(
          (item) => item[0].toUpperCase() + item.substring(1),
        )
        .join(' ');
  }

  String _formatAmount(double amount) {
    if (!amount.isFinite) return '0';
    if (amount == amount.roundToDouble()) {
      return amount.toInt().toString();
    }
    return amount.toStringAsFixed(2);
  }
}

// ==============================================================================
// PRICING PROFILE PICKER
// ==============================================================================

class _PricingProfilePickerSheet extends StatefulWidget {
  final List<PricingProfile> profiles;
  final String? selectedProfileId;
  final TextEditingController searchController;

  const _PricingProfilePickerSheet({
    required this.profiles,
    required this.selectedProfileId,
    required this.searchController,
  });

  @override
  State<_PricingProfilePickerSheet> createState() =>
      _PricingProfilePickerSheetState();
}

class _PricingProfilePickerSheetState
    extends State<_PricingProfilePickerSheet> {
  String _query = '';

  @override
  void initState() {
    super.initState();
    widget.searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    widget.searchController.removeListener(_onSearchChanged);
    super.dispose();
  }

  void _onSearchChanged() {
    if (!mounted) return;
    setState(() {
      _query = widget.searchController.text.trim().toLowerCase();
    });
  }

  List<PricingProfile> get _filteredProfiles {
    if (_query.isEmpty) {
      return widget.profiles;
    }

    return widget.profiles.where((profile) {
      return profile.name.toLowerCase().contains(_query) ||
          profile.id.toLowerCase().contains(_query) ||
          profile.pricingGroupId.toLowerCase().contains(_query) ||
          profile.vehicleId.toLowerCase().contains(_query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final profiles = _filteredProfiles;

    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.86,
        decoration: const BoxDecoration(
          color: _AdminEditCarScreenState.card,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(28),
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: _AdminEditCarScreenState.border,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Select Pricing Profile',
                      style: GoogleFonts.manrope(
                        color: _AdminEditCarScreenState.heading,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: _AdminEditCarScreenState.body,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: TextField(
                controller: widget.searchController,
                autofocus: false,
                style: GoogleFonts.manrope(
                  color: _AdminEditCarScreenState.heading,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: 'Search name, profile ID or pricing group',
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: _AdminEditCarScreenState.primary,
                  ),
                  filled: true,
                  fillColor: _AdminEditCarScreenState.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(
                      color: _AdminEditCarScreenState.border,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(
                      color: _AdminEditCarScreenState.border,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(
                      color: _AdminEditCarScreenState.primary,
                      width: 1.3,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: profiles.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(30),
                        child: Text(
                          'No pricing profiles match your search.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(
                            color: _AdminEditCarScreenState.body,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      itemCount: profiles.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final profile = profiles[index];
                        final selected =
                            profile.id == widget.selectedProfileId;

                        return InkWell(
                          onTap: !profile.isActive
                              ? null
                              : () => Navigator.pop(context, profile),
                          borderRadius: BorderRadius.circular(18),
                          child: Opacity(
                            opacity: profile.isActive ? 1 : 0.55,
                            child: Container(
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                color: selected
                                    ? _AdminEditCarScreenState.softAccent
                                    : _AdminEditCarScreenState.card,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: selected
                                      ? _AdminEditCarScreenState.primary
                                      : _AdminEditCarScreenState.border,
                                  width: selected ? 1.3 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 45,
                                    height: 45,
                                    decoration: BoxDecoration(
                                      color: _AdminEditCarScreenState.softAccent,
                                      borderRadius: BorderRadius.circular(13),
                                    ),
                                    child: Icon(
                                      selected
                                          ? Icons.check_circle_rounded
                                          : Icons.price_change_outlined,
                                      color: _AdminEditCarScreenState.primary,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 11),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          profile.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.manrope(
                                            color:
                                                _AdminEditCarScreenState.heading,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          profile.id,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.manrope(
                                            color:
                                                _AdminEditCarScreenState.primary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 5,
                                          children: [
                                            _miniChip(
                                              '${profile.hourlyPackages.length} hourly',
                                            ),
                                            _miniChip(
                                              '${profile.dailyPackages.length} daily',
                                            ),
                                            if (profile.pricingGroupId
                                                .trim()
                                                .isNotEmpty)
                                              _miniChip(
                                                profile.pricingGroupId,
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    profile.isActive
                                        ? Icons.chevron_right_rounded
                                        : Icons.lock_outline_rounded,
                                    color: profile.isActive
                                        ? _AdminEditCarScreenState.body
                                        : Colors.orange.shade700,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _AdminEditCarScreenState.border,
        ),
      ),
      child: Text(
        text,
        style: GoogleFonts.manrope(
          color: _AdminEditCarScreenState.body,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
