import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/config/app_config.dart';
import '../../../cars/models/car.dart';
import '../../../cars/services/car_service.dart';
import '../../../pricing/models/pricing_profile.dart';
import '../../../pricing/services/pricing_profile_service.dart';
import '../../pricing/screens/admin_add_pricing_profile_screen.dart';

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
  // ============================================================
  // PREMIUM PALETTE
  // ============================================================

  static const Color primary = Color(0xFF0F766E);
  static const Color accent = Color(0xFF14B8A6);
  static const Color background = Color(0xFFF8FAF9);
  static const Color card = Color(0xFFFFFFFF);
  static const Color softAccent = Color(0xFFE6FFFB);
  static const Color heading = Color(0xFF17201F);
  static const Color body = Color(0xFF66706E);
  static const Color muted = Color(0xFF94A09D);
  static const Color border = Color(0xFFE5EBE9);

  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _registrationController;
  late final TextEditingController _priceController;
  late final TextEditingController _sortOrderController;
  late final TextEditingController _pricingProfileController;
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

  bool _isSaving = false;

  // Pricing profiles are managed centrally. A car stores only the
  // selected pricingProfileId.
  List<PricingProfile> _pricingProfiles = [];
  PricingProfile? _selectedPricingProfile;
  bool _isPricingLoading = true;
  String? _pricingLoadError;

  final List<String> _types = [
    'Hatchback',
    'Sedan',
    'SUV',
    'MUV',
    'Luxury',
    'Premium',
    'Convertible',
    'Electric',
  ];

  final List<int> _seatOptions = [
    2,
    4,
    5,
    6,
    7,
    8,
    9,
  ];

  final List<String> _transmissions = [
    'Manual',
    'Automatic',
    'AMT',
    'CVT',
    'DCT',
  ];

  final List<String> _fuels = [
    'Petrol',
    'Diesel',
    'CNG',
    'Electric',
    'Hybrid',
  ];

  @override
  void initState() {
    super.initState();

    final car = widget.car;

    _nameController = TextEditingController(
      text: car.name,
    );

    _registrationController = TextEditingController(
      text: car.registrationNumber,
    );

    _priceController = TextEditingController(
      text: car.pricePerDay.toString(),
    );

    _sortOrderController = TextEditingController(
      text: car.sortOrder.toString(),
    );

    _pricingProfileController = TextEditingController(
      text: car.pricingProfileId,
    );

    _descriptionController = TextEditingController(
      text: car.description,
    );

    _featuresController = TextEditingController(
      text: car.features.join(', '),
    );

    _branchIdsController = TextEditingController(
      text: car.branchIds.join(', '),
    );

    _type = _types.contains(car.type)
        ? car.type
        : _types.first;

    _seats = _seatOptions.contains(car.seats)
        ? car.seats
        : 5;

    _transmission =
        _transmissions.contains(car.transmission)
            ? car.transmission
            : _transmissions.first;

    _fuel = _fuels.contains(car.fuel)
        ? car.fuel
        : _fuels.first;

    _isActive = car.isActive;
    _isAvailable = car.isAvailable;
    _isFeatured = car.isFeatured;

    _loadPricingProfiles();
  }

  String get _tenantId => AppConfig.tenant.tenantId;

  String get _currencyCode {
    final currency = AppConfig.tenant.business.currency.trim().toUpperCase();
    return currency.isEmpty ? 'INR' : currency;
  }

  String _currencySymbol() {
    switch (_currencyCode) {
      case 'INR':
        return '₹';
      case 'USD':
        return r'$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'AED':
        return 'د.إ';
      case 'SAR':
        return '﷼';
      default:
        return _currencyCode;
    }
  }

  String _formatMoney(num value) {
    final rounded = value.round();
    return '${_currencySymbol()} $rounded';
  }

  Future<void> _loadPricingProfiles() async {
    final tenantId = _tenantId.trim();

    if (tenantId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isPricingLoading = false;
        _pricingLoadError = 'Tenant configuration is missing.';
      });
      return;
    }

    if (mounted) {
      setState(() {
        _isPricingLoading = true;
        _pricingLoadError = null;
      });
    }

    try {
      final activeProfiles =
          await PricingProfileService.instance.getActivePricingProfiles(
        tenantId: tenantId,
      );

      final profiles = List<PricingProfile>.from(activeProfiles);

      // If the current profile is inactive, keep it selectable while editing
      // this car so we do not silently replace an existing assignment.
      final currentId = widget.car.pricingProfileId.trim();
      if (currentId.isNotEmpty &&
          !profiles.any((profile) => profile.id == currentId)) {
        final current =
            await PricingProfileService.instance.getPricingProfileById(
          tenantId: tenantId,
          pricingProfileId: currentId,
        );

        if (current != null) {
          profiles.insert(0, current);
        }
      }

      PricingProfile? selected;
      if (currentId.isNotEmpty) {
        for (final profile in profiles) {
          if (profile.id == currentId) {
            selected = profile;
            break;
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _pricingProfiles = profiles;
        _selectedPricingProfile = selected;
        _isPricingLoading = false;
      });

      if (selected != null) {
        _pricingProfileController.text = selected.id;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pricingProfiles = [];
        _selectedPricingProfile = null;
        _isPricingLoading = false;
        _pricingLoadError =
            'Unable to load pricing profiles. Please try again.';
      });
    }
  }

  Future<void> _createPricingProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AdminAddPricingProfileScreen(),
      ),
    );

    if (result == true && mounted) {
      await _loadPricingProfiles();
    }
  }

  Future<void> _selectPricingProfile() async {
    if (_isPricingLoading) return;

    if (_pricingProfiles.isEmpty) {
      await _createPricingProfile();
      return;
    }

    final selected = await showModalBottomSheet<PricingProfile>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.82,
          ),
          decoration: const BoxDecoration(
            color: card,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: border,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Select Pricing Profile',
                          style: GoogleFonts.manrope(
                            color: heading,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: body,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose the pricing rules this vehicle should use.',
                    style: GoogleFonts.manrope(
                      color: body,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.separated(
                      itemCount: _pricingProfiles.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 10),
                      itemBuilder: (_, index) {
                        final profile = _pricingProfiles[index];
                        final isSelected =
                            profile.id == _selectedPricingProfile?.id;

                        return InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => Navigator.pop(
                            sheetContext,
                            profile,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? softAccent
                                  : background,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isSelected ? accent : border,
                                width: isSelected ? 1.3 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? accent.withValues(alpha: 0.12)
                                        : card,
                                    borderRadius:
                                        BorderRadius.circular(13),
                                  ),
                                  child: Icon(
                                    isSelected
                                        ? Icons.check_circle_rounded
                                        : Icons.price_change_rounded,
                                    color: primary,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        profile.name.isEmpty
                                            ? profile.id
                                            : profile.name,
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
                                        '${profile.id} • ${profile.currency} • ${_formatMoney(profile.dailyRate)}/day',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.manrope(
                                          color: body,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.radio_button_checked_rounded,
                                    color: primary,
                                    size: 20,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _createPricingProfile();
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: Text(
                        'Create New Pricing Profile',
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primary,
                        side: const BorderSide(color: primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (selected == null || !mounted) return;

    setState(() {
      _selectedPricingProfile = selected;
      _pricingProfileController.text = selected.id;

      // Keep the car's display price aligned with the selected profile's
      // daily rate. The admin can still edit the display price afterward.
      _priceController.text = selected.dailyRate.round().toString();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _registrationController.dispose();
    _priceController.dispose();
    _sortOrderController.dispose();
    _pricingProfileController.dispose();
    _descriptionController.dispose();
    _featuresController.dispose();
    _branchIdsController.dispose();

    super.dispose();
  }

  // ============================================================
  // UPDATE CAR
  // ============================================================

  Future<void> _updateCar() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final tenantId = AppConfig.tenant.tenantId;

    if (tenantId.isEmpty) {
      _showError(
        'Tenant configuration is missing.',
      );
      return;
    }

    // Make sure we never update an empty/invalid document.
    if (widget.car.id.trim().isEmpty) {
      _showError(
        'Car ID is missing. Unable to update this vehicle.',
      );
      return;
    }

    final price = int.tryParse(
      _priceController.text.trim(),
    );

    final sortOrder = int.tryParse(
      _sortOrderController.text.trim(),
    );

    if (price == null || price < 0) {
      _showError(
        'Please enter a valid price per day.',
      );
      return;
    }

    if (sortOrder == null || sortOrder < 0) {
      _showError(
        'Please enter a valid sort order.',
      );
      return;
    }

    final pricingProfileId =
        _pricingProfileController.text.trim();

    if (pricingProfileId.isEmpty || _selectedPricingProfile == null) {
      _showError(
        'Please select a pricing profile before saving the car.',
      );
      return;
    }

    if (_selectedPricingProfile!.id != pricingProfileId) {
      _showError(
        'The selected pricing profile is invalid. Please select it again.',
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
          .toList();

      final branchIds = _branchIdsController.text
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();

      String status;

      if (!_isActive) {
        status = 'inactive';
      } else if (!_isAvailable) {
        status = 'unavailable';
      } else {
        status = 'available';
      }

      final updatedCar = Car(
        id: widget.car.id,

        // Always use the currently loaded tenant.
        tenantId: tenantId,

        name: _nameController.text.trim(),
        type: _type,
        transmission: _transmission,
        seats: _seats,
        fuel: _fuel,

        pricingProfileId: pricingProfileId,

        pricePerDay: price,

        // Preserve existing images.
        image: widget.car.image,
        images: widget.car.images,

        registrationNumber:
            _registrationController.text.trim(),

        description:
            _descriptionController.text.trim(),

        features: features,
        branchIds: branchIds,

        status: status,

        isAvailable: _isAvailable,
        isFeatured: _isFeatured,
        isActive: _isActive,

        sortOrder: sortOrder,
      );

      // IMPORTANT:
      // Your CarService.updateCar() requires carId.
      await CarService.instance.updateCar(
        tenantId: tenantId,
        carId: widget.car.id,
        car: updatedCar,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Car updated successfully.',
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

      // true tells the Cars list to reload.
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      _showError(
        'Unable to update car. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // ============================================================
  // ERROR
  // ============================================================

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

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,

      appBar: AppBar(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,

        leading: IconButton(
          onPressed: _isSaving
              ? null
              : () => Navigator.pop(context),
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
            padding: const EdgeInsets.fromLTRB(
              20,
              8,
              20,
              120,
            ),
            children: [
              _buildCarHeader(),

              const SizedBox(height: 20),

              // ==================================================
              // BASIC INFORMATION
              // ==================================================

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
                      if (value == null ||
                          value.trim().isEmpty) {
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
                      if (value != null) {
                        setState(() {
                          _type = value;
                        });
                      }
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
                          itemLabel: (value) =>
                              '$value Seats',
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _seats = value;
                              });
                            }
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
                            if (value != null) {
                              setState(() {
                                _transmission = value;
                              });
                            }
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
                    icon:
                        Icons.local_gas_station_rounded,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _fuel = value;
                        });
                      }
                    },
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ==================================================
              // VEHICLE DETAILS
              // ==================================================

              _buildSection(
                title: 'Vehicle Details',
                icon: Icons.badge_rounded,
                children: [
                  _buildTextField(
                    controller:
                        _registrationController,
                    label: 'Registration Number',
                    hint: 'e.g. MH12AB1234',
                    icon:
                        Icons.confirmation_number_rounded,
                    textCapitalization:
                        TextCapitalization.characters,
                    validator: (value) {
                      if (value == null ||
                          value.trim().isEmpty) {
                        return 'Registration number is required';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 14),

                  _buildTextField(
                    controller:
                        _descriptionController,
                    label: 'Description',
                    hint:
                        'Short description of the vehicle',
                    icon: Icons.notes_rounded,
                    maxLines: 4,
                  ),

                  const SizedBox(height: 14),

                  _buildTextField(
                    controller: _featuresController,
                    label: 'Features',
                    hint:
                        'AC, Bluetooth, Rear Camera',
                    icon:
                        Icons.auto_awesome_rounded,
                    maxLines: 2,
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Separate multiple features with commas.',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ==================================================
              // PRICING
              // ==================================================

              _buildSection(
                title: 'Pricing',
                icon: Icons.payments_rounded,
                children: [
                  _buildTextField(
                    controller: _priceController,
                    label: 'Display Price / Day',
                    hint: '2499',
                    icon: Icons.payments_rounded,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null ||
                          value.trim().isEmpty) {
                        return 'Price is required';
                      }

                      final parsed =
                          int.tryParse(value.trim());

                      if (parsed == null || parsed < 0) {
                        return 'Enter a valid price';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 14),

                  _buildPricingProfileSelector(),

                  const SizedBox(height: 10),

                  _buildInfoBox(
                    text:
                        'The selected pricing profile controls hourly, daily, KM package, extra KM, late return, deposit and other pricing rules. The car stores only the profile ID.',
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ==================================================
              // BRANCH ASSIGNMENT
              // ==================================================

              _buildSection(
                title: 'Branch Assignment',
                icon: Icons.location_on_rounded,
                children: [
                  _buildTextField(
                    controller:
                        _branchIdsController,
                    label: 'Branch IDs',
                    hint:
                        'branch_001, branch_002',
                    icon: Icons.store_rounded,
                    maxLines: 2,
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Separate multiple branch IDs with commas.',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ==================================================
              // STATUS
              // ==================================================

              _buildSection(
                title: 'Vehicle Status',
                icon: Icons.tune_rounded,
                children: [
                  _buildSwitchTile(
                    title: 'Active',
                    subtitle:
                        'Vehicle is active in the admin system',
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
                    subtitle:
                        'Vehicle can currently be booked',
                    value: _isAvailable,
                    enabled: _isActive,
                    onChanged: (value) {
                      setState(() {
                        _isAvailable = value;
                      });
                    },
                  ),

                  const SizedBox(height: 8),

                  _buildSwitchTile(
                    title: 'Featured Car',
                    subtitle:
                        'Show this vehicle in featured sections',
                    value: _isFeatured,
                    onChanged: (value) {
                      setState(() {
                        _isFeatured = value;
                      });
                    },
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ==================================================
              // DISPLAY ORDER
              // ==================================================

              _buildSection(
                title: 'Display Order',
                icon: Icons.sort_rounded,
                children: [
                  _buildTextField(
                    controller: _sortOrderController,
                    label: 'Sort Order',
                    hint: '1',
                    icon:
                        Icons.format_list_numbered_rounded,
                    keyboardType:
                        TextInputType.number,
                    validator: (value) {
                      if (value == null ||
                          value.trim().isEmpty) {
                        return 'Sort order is required';
                      }

                      final parsed =
                          int.tryParse(value.trim());

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

      // ==========================================================
      // SAVE BUTTON
      // ==========================================================

      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          20,
          10,
          20,
          16,
        ),
        child: SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed:
                _isSaving ? null : _updateCar,
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              disabledBackgroundColor:
                  primary.withValues(alpha: 0.55),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(17),
              ),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor:
                          AlwaysStoppedAnimation<
                              Color>(
                        Colors.white,
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons
                            .check_circle_outline_rounded,
                        size: 21,
                      ),
                      const SizedBox(width: 9),
                      Text(
                        'Save Changes',
                        style:
                            GoogleFonts.manrope(
                          fontSize: 15,
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CAR HEADER
  // ============================================================

  Widget _buildCarHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(alpha: 0.035),
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
              borderRadius:
                  BorderRadius.circular(18),
            ),
            child: ClipRRect(
              borderRadius:
                  BorderRadius.circular(18),
              child: widget.car.image.isNotEmpty
                  ? Image.network(
                      widget.car.image,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (_, __, ___) {
                        return const Icon(
                          Icons
                              .directions_car_rounded,
                          color: primary,
                          size: 31,
                        );
                      },
                    )
                  : const Icon(
                      Icons
                          .directions_car_rounded,
                      color: primary,
                      size: 31,
                    ),
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  widget.car.name.isEmpty
                      ? 'Edit Vehicle'
                      : widget.car.name,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    color: heading,
                    fontSize: 18,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  widget.car.registrationNumber
                          .isEmpty
                      ? 'Vehicle details'
                      : widget
                          .car
                          .registrationNumber,
                  style: GoogleFonts.manrope(
                    color: body,
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w600,
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

  // ============================================================
  // STATUS BADGE
  // ============================================================

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
        borderRadius:
            BorderRadius.circular(30),
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

  // ============================================================
  // SECTION
  // ============================================================

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: card,
        borderRadius:
            BorderRadius.circular(22),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(alpha: 0.025),
            blurRadius: 16,
            offset: const Offset(0, 6),
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
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: softAccent,
                  borderRadius:
                      BorderRadius.circular(12),
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
                  fontWeight:
                      FontWeight.w800,
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

  // ============================================================
  // TEXT FIELD
  // ============================================================

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization =
        TextCapitalization.none,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      textCapitalization:
          textCapitalization,
      maxLines: maxLines,
      style: GoogleFonts.manrope(
        color: heading,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
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

        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 15,
        ),

        border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(14),
          borderSide:
              const BorderSide(
            color: border,
          ),
        ),

        enabledBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(14),
          borderSide:
              const BorderSide(
            color: border,
          ),
        ),

        focusedBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(14),
          borderSide:
              const BorderSide(
            color: primary,
            width: 1.4,
          ),
        ),

        errorBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Colors.red.shade300,
          ),
        ),

        focusedErrorBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Colors.red.shade400,
            width: 1.2,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // PRICING PROFILE SELECTOR
  // ============================================================

  Widget _buildPricingProfileSelector() {
    final profile = _selectedPricingProfile;

    String subtitle;
    if (_isPricingLoading) {
      subtitle = 'Loading pricing profiles...';
    } else if (_pricingLoadError != null) {
      subtitle = _pricingLoadError!;
    } else if (profile == null) {
      subtitle = 'Select an existing profile or create a new one';
    } else {
      subtitle =
          '${profile.id} • ${profile.currency} • ${_formatMoney(profile.dailyRate)}/day';
    }

    return InkWell(
      onTap: _isSaving || _isPricingLoading
          ? null
          : _selectPricingProfile,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: profile != null ? accent : border,
            width: profile != null ? 1.2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: softAccent,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                profile != null
                    ? Icons.verified_rounded
                    : Icons.price_change_rounded,
                color: primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pricing Profile',
                    style: GoogleFonts.manrope(
                      color: body,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    profile?.name.isNotEmpty == true
                        ? profile!.name
                        : 'No pricing profile selected',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      color: profile != null ? heading : muted,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      color: _pricingLoadError != null
                          ? Colors.red.shade700
                          : body,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (_isPricingLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: primary,
                ),
              )
            else
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: body,
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DROPDOWN
  // ============================================================

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

        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 4,
        ),

        border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(14),
          borderSide:
              const BorderSide(
            color: border,
          ),
        ),

        enabledBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(14),
          borderSide:
              const BorderSide(
            color: border,
          ),
        ),

        focusedBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(14),
          borderSide:
              const BorderSide(
            color: primary,
            width: 1.4,
          ),
        ),
      ),

      items: items.map((item) {
        return DropdownMenuItem<T>(
          value: item,
          child: Text(
            itemLabel != null
                ? itemLabel(item)
                : item.toString(),
          ),
        );
      }).toList(),
    );
  }

  // ============================================================
  // SWITCH
  // ============================================================

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
  }) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius:
            BorderRadius.circular(15),
        border: Border.all(
          color: border,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.manrope(
                    color: enabled
                        ? heading
                        : muted,
                    fontSize: 14,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  subtitle,
                  style: GoogleFonts.manrope(
                    color: enabled
                        ? body
                        : muted,
                    fontSize: 11.5,
                    fontWeight:
                        FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          Switch.adaptive(
            value: value,
            onChanged:
                enabled ? onChanged : null,
            activeColor: primary,
            activeTrackColor: accent,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INFO BOX
  // ============================================================

  Widget _buildInfoBox({
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: softAccent,
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color:
              accent.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
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
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}