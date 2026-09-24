import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/config/app_config.dart';
import '../../../cars/models/car.dart';
import '../../../cars/services/car_service.dart';
import '../../../pricing/models/pricing_profile.dart';
import '../../../pricing/services/pricing_profile_service.dart';

class AdminAddCarScreen extends StatefulWidget {
  const AdminAddCarScreen({
    super.key,
  });

  @override
  State<AdminAddCarScreen> createState() =>
      _AdminAddCarScreenState();
}

class _AdminAddCarScreenState
    extends State<AdminAddCarScreen> {
  // ============================================================
  // PREMIUM PALETTE
  // ============================================================

  static const Color background =
      Color(0xFFF8FAF9);

  static const Color card =
      Color(0xFFFFFFFF);

  static const Color primary =
      Color(0xFF0F766E);

  static const Color accent =
      Color(0xFF14B8A6);

  static const Color softAccent =
      Color(0xFFE6FFFB);

  static const Color heading =
      Color(0xFF17201F);

  static const Color body =
      Color(0xFF66706E);

  static const Color muted =
      Color(0xFF94A09D);

  static const Color border =
      Color(0xFFE5EBE9);

  static const Color danger =
      Color(0xFFD66A6A);

  // ============================================================
  // SERVICES
  // ============================================================

  final CarService _carService =
      CarService.instance;

  final ImagePicker _imagePicker =
      ImagePicker();

  // ============================================================
  // FORM
  // ============================================================

  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  final TextEditingController _nameController =
      TextEditingController();

  final TextEditingController
      _registrationController =
      TextEditingController();

  final TextEditingController
      _currentKmController =
      TextEditingController();

  final TextEditingController
      _pricingProfileController =
      TextEditingController();

  final TextEditingController
      _descriptionController =
      TextEditingController();

  final TextEditingController
      _featuresController =
      TextEditingController();

  final TextEditingController
      _branchIdsController =
      TextEditingController();

  final TextEditingController
      _sortOrderController =
      TextEditingController(
    text: '0',
  );

  // ============================================================
  // FORM STATE
  // ============================================================

  String _selectedType = 'SUV';

  String _selectedTransmission =
      'Automatic';

  String _selectedFuel = 'Petrol';

  int _selectedSeats = 5;

  bool _isAvailable = true;

  bool _isFeatured = false;

  bool _isActive = true;

  bool _saving = false;

  // ============================================================
  // PRICING
  // ============================================================

  List<PricingProfile> _pricingProfiles = [];

  PricingProfile? _selectedPricingProfile;

  bool _isPricingLoading = true;

  String? _pricingLoadError;

  // ============================================================
  // IMAGES
  // ============================================================

  final List<Uint8List> _selectedImages =
      <Uint8List>[];

  int _primaryImageIndex = 0;

  // ============================================================
  // TENANT
  // ============================================================

  String get _tenantId {
    try {
      return AppConfig.tenant.tenantId;
    } catch (_) {
      return '';
    }
  }

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _loadPricingProfiles();
  }

  // ============================================================
  // PRICING
  // ============================================================

  Future<void> _loadPricingProfiles() async {
    final tenantId = _tenantId.trim();

    if (tenantId.isEmpty) {
      if (!mounted) return;

      setState(() {
        _isPricingLoading = false;
        _pricingLoadError =
            'Tenant configuration is unavailable.';
      });

      return;
    }

    try {
      final profiles =
          await PricingProfileService.instance
              .getAllPricingProfiles(
        tenantId: tenantId,
      );

      if (!mounted) return;

      setState(() {
        _pricingProfiles = profiles
            .where(
              (profile) => profile.isActive,
            )
            .toList();

        _isPricingLoading = false;

        _pricingLoadError = null;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _pricingProfiles = [];

        _isPricingLoading = false;

        _pricingLoadError =
            'Unable to load pricing profiles.';
      });
    }
  }

  Future<void> _selectPricingProfile() async {
    final selected =
        await showModalBottomSheet<PricingProfile>(
      context: context,
      backgroundColor: card,
      isScrollControlled: true,
      shape:
          const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.fromLTRB(
              20,
              18,
              20,
              20,
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration:
                        BoxDecoration(
                      color: border,
                      borderRadius:
                          BorderRadius.circular(
                        20,
                      ),
                    ),
                  ),
                ),

                const SizedBox(
                  height: 18,
                ),

                Text(
                  'Select Pricing Profile',
                  style:
                      GoogleFonts.manrope(
                    fontSize: 18,
                    fontWeight:
                        FontWeight.w900,
                    color: heading,
                  ),
                ),

                const SizedBox(
                  height: 5,
                ),

                Text(
                  'Select the reusable pricing profile for this vehicle.',
                  style:
                      GoogleFonts.manrope(
                    fontSize: 11.5,
                    fontWeight:
                        FontWeight.w500,
                    color: body,
                  ),
                ),

                const SizedBox(
                  height: 16,
                ),

                if (_pricingProfiles.isEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(
                      vertical: 18,
                    ),
                    child: Text(
                      'No active pricing profiles found.',
                      style:
                          GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight:
                            FontWeight.w600,
                        color: body,
                      ),
                    ),
                  )
                else
                  Flexible(
                    child:
                        ListView.separated(
                      shrinkWrap: true,
                      itemCount:
                          _pricingProfiles
                              .length,
                      separatorBuilder:
                          (_, __) =>
                              const SizedBox(
                        height: 8,
                      ),
                      itemBuilder:
                          (_, index) {
                        final profile =
                            _pricingProfiles[
                                index];

                        return InkWell(
                          borderRadius:
                              BorderRadius
                                  .circular(
                            16,
                          ),
                          onTap: () =>
                              Navigator.pop(
                            context,
                            profile,
                          ),
                          child:
                              Container(
                            padding:
                                const EdgeInsets
                                    .all(
                              14,
                            ),
                            decoration:
                                BoxDecoration(
                              color:
                                  background,
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                16,
                              ),
                              border:
                                  Border.all(
                                color:
                                    border,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration:
                                      BoxDecoration(
                                    color:
                                        softAccent,
                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                      13,
                                    ),
                                  ),
                                  child:
                                      const Icon(
                                    Icons
                                        .price_change_rounded,
                                    color:
                                        primary,
                                    size: 21,
                                  ),
                                ),

                                const SizedBox(
                                  width: 12,
                                ),

                                Expanded(
                                  child:
                                      Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment
                                            .start,
                                    children: [
                                      Text(
                                        profile
                                                .name
                                                .isEmpty
                                            ? profile
                                                .id
                                            : profile
                                                .name,
                                        maxLines:
                                            1,
                                        overflow:
                                            TextOverflow
                                                .ellipsis,
                                        style:
                                            GoogleFonts
                                                .manrope(
                                          fontSize:
                                              12.5,
                                          fontWeight:
                                              FontWeight
                                                  .w800,
                                          color:
                                              heading,
                                        ),
                                      ),
                                      const SizedBox(
                                        height: 3,
                                      ),
                                      Text(
                                        _pricingProfileSummary(
                                          profile,
                                        ),
                                        maxLines:
                                            1,
                                        overflow:
                                            TextOverflow
                                                .ellipsis,
                                        style:
                                            GoogleFonts
                                                .manrope(
                                          fontSize:
                                              10.5,
                                          fontWeight:
                                              FontWeight
                                                  .w600,
                                          color:
                                              body,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const Icon(
                                  Icons
                                      .chevron_right_rounded,
                                  color:
                                      muted,
                                  size: 21,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                const SizedBox(
                  height: 12,
                ),

                SizedBox(
                  width:
                      double.infinity,
                  child:
                      OutlinedButton.icon(
                    onPressed: () =>
                        Navigator.pop(
                      context,
                    ),
                    icon:
                        const Icon(
                      Icons.close_rounded,
                      size: 18,
                    ),
                    label:
                        const Text(
                      'Close',
                    ),
                    style:
                        OutlinedButton
                            .styleFrom(
                      foregroundColor:
                          primary,
                      side:
                          const BorderSide(
                        color: primary,
                      ),
                      padding:
                          const EdgeInsets
                              .symmetric(
                        vertical: 13,
                      ),
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius
                                .circular(
                          14,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null && mounted) {
      setState(() {
        _selectedPricingProfile =
            selected;

        _pricingProfileController
            .text = selected.id;
      });
    }
  }

  String _pricingProfileSummary(
    PricingProfile profile,
  ) {
    final hourly =
        profile.hourlyPackages
            .where(
              (p) =>
                  p.isActive &&
                  p.safeHourlyRate > 0,
            )
            .length;

    final daily =
        profile.dailyPackages
            .where(
              (p) =>
                  p.isActive &&
                  p.safeDailyRate > 0,
            )
            .length;

    final parts = <String>[];

    if (hourly > 0) {
      parts.add('$hourly hourly');
    }

    if (daily > 0) {
      parts.add('$daily daily');
    }

    final mode = parts.isEmpty
        ? 'No active packages'
        : parts.join(' • ');

    return '${profile.id} • '
        '${profile.currency} • $mode';
  }

  double _profileDisplayDailyRate(
    PricingProfile profile,
  ) {
    for (final package
        in profile.dailyPackages) {
      if (!package.isActive) {
        continue;
      }

      final rate =
          package.safeDailyRate;

      if (rate > 0) {
        return rate;
      }
    }

    for (final package
        in profile.hourlyPackages) {
      if (!package.isActive) {
        continue;
      }

      final rate =
          package.safeHourlyRate;

      if (rate > 0) {
        return rate;
      }
    }

    return 0;
  }

  // ============================================================
  // IMAGE PICKER
  // ============================================================

  Future<void> _pickImages() async {
    if (_saving) return;

    try {
      final picked =
          await _imagePicker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1800,
        maxHeight: 1800,
      );

      if (picked.isEmpty) {
        return;
      }

      final newImages =
          <Uint8List>[];

      for (final file in picked) {
        final bytes =
            await file.readAsBytes();

        if (bytes.isNotEmpty) {
          newImages.add(bytes);
        }
      }

      if (!mounted ||
          newImages.isEmpty) {
        return;
      }

      setState(() {
        _selectedImages
            .addAll(newImages);
      });
    } catch (e) {
      if (!mounted) return;

      _showError(
        'Unable to select images. '
        '${e.toString()}',
      );
    }
  }

  void _removeImage(int index) {
    if (_saving) return;

    setState(() {
      _selectedImages.removeAt(index);

      if (_selectedImages.isEmpty) {
        _primaryImageIndex = 0;
        return;
      }

      if (index == _primaryImageIndex) {
        _primaryImageIndex = 0;
      } else if (index <
          _primaryImageIndex) {
        _primaryImageIndex--;
      }

      if (_primaryImageIndex >=
          _selectedImages.length) {
        _primaryImageIndex =
            _selectedImages.length - 1;
      }
    });
  }

  void _setPrimaryImage(int index) {
    if (_saving) return;

    setState(() {
      _primaryImageIndex = index;
    });
  }

  // ============================================================
  // SAVE
  // ============================================================

  Future<void> _saveCar() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!
        .validate()) {
      return;
    }

    final tenantId =
        _tenantId.trim();

    if (tenantId.isEmpty) {
      _showError(
        'Tenant configuration is unavailable.',
      );
      return;
    }

    final currentKm =
        int.tryParse(
              _currentKmController
                  .text
                  .trim(),
            ) ??
            0;

    if (currentKm < 0) {
      _showError(
        'Current KM cannot be negative.',
      );
      return;
    }

    if (_selectedImages.isEmpty) {
      _showError(
        'Please add at least one vehicle photo.',
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final features =
          _parseList(
        _featuresController.text,
      );

      final branchIds =
          _parseList(
        _branchIdsController.text,
      );

      final selectedProfile =
          _selectedPricingProfile;

      final pricePerDay =
          selectedProfile == null
              ? 0
              : _profileDisplayDailyRate(
                    selectedProfile,
                  ).round();

      final sortOrder =
          int.tryParse(
                _sortOrderController
                    .text
                    .trim(),
              ) ??
              0;

      // ----------------------------------------------------------
      // CREATE VEHICLE DOCUMENT FIRST
      // ----------------------------------------------------------

      final car = Car(
        id: '',
        tenantId: tenantId,

        name:
            _nameController.text.trim(),

        type: _selectedType,

        transmission:
            _selectedTransmission,

        seats: _selectedSeats,

        fuel: _selectedFuel,

        pricingProfileId:
            _pricingProfileController
                .text
                .trim(),

        pricePerDay:
            pricePerDay,

        // Images are uploaded after the
        // Firestore document receives its ID.
        image: '',

        images: const [],

        registrationNumber:
            _registrationController
                .text
                .trim()
                .toUpperCase(),

        currentKm: currentKm,

        description:
            _descriptionController
                .text
                .trim(),

        features: features,

        branchIds: branchIds,

        status: _isActive
            ? (_isAvailable
                ? 'available'
                : 'unavailable')
            : 'inactive',

        isAvailable:
            _isActive &&
            _isAvailable,

        isFeatured:
            _isActive &&
            _isFeatured,

        isActive:
            _isActive,

        sortOrder:
            sortOrder,
      );

      final carId =
          await _carService.createCar(
        tenantId: tenantId,
        car: car,
      );

      // ----------------------------------------------------------
      // UPLOAD IMAGES
      // ----------------------------------------------------------

      final primaryBytes =
          _selectedImages[
              _primaryImageIndex];

      final primaryUrl =
          await _carService
              .uploadPrimaryImage(
        tenantId: tenantId,
        carId: carId,
        bytes: primaryBytes,
      );

      // ----------------------------------------------------------
      // UPLOAD GALLERY IMAGES
      //
      // We upload every selected image as
      // a gallery image as well, then store
      // all URLs in `images`.
      // ----------------------------------------------------------

      final galleryUrls =
          await _carService.uploadImages(
        tenantId: tenantId,
        carId: carId,
        images: _selectedImages,
      );

      // ----------------------------------------------------------
      // UPDATE IMAGE FIELDS
      // ----------------------------------------------------------

      await _carService.updateCarImages(
        tenantId: tenantId,
        carId: carId,
        primaryImage: primaryUrl,
        images: galleryUrls,
      );

      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      _showSuccess(
        'Vehicle added successfully.',
      );

      Navigator.pop(
        context,
        true,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      _showError(
        e.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
    }
  }

  // ============================================================
  // LIST PARSER
  // ============================================================

  List<String> _parseList(
    String value,
  ) {
    return value
        .split(',')
        .map(
          (item) => item.trim(),
        )
        .where(
          (item) => item.isNotEmpty,
        )
        .toList();
  }

  // ============================================================
  // SNACKBARS
  // ============================================================

  void _showError(
    String message,
  ) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          message,
          style:
              GoogleFonts.manrope(
            fontWeight:
                FontWeight.w700,
          ),
        ),
        backgroundColor: danger,
        behavior:
            SnackBarBehavior.floating,
        margin:
            const EdgeInsets.all(16),
        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(14),
        ),
      ),
    );
  }

  void _showSuccess(
    String message,
  ) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          message,
          style:
              GoogleFonts.manrope(
            fontWeight:
                FontWeight.w700,
          ),
        ),
        backgroundColor: primary,
        behavior:
            SnackBarBehavior.floating,
        margin:
            const EdgeInsets.all(16),
        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(14),
        ),
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _nameController.dispose();
    _registrationController.dispose();
    _currentKmController.dispose();
    _pricingProfileController.dispose();
    _descriptionController.dispose();
    _featuresController.dispose();
    _branchIdsController.dispose();
    _sortOrderController.dispose();

    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          background,

      appBar: AppBar(
        backgroundColor:
            card,
        surfaceTintColor:
            Colors.transparent,
        elevation: 0,

        leading: IconButton(
          onPressed: _saving
              ? null
              : () =>
                  Navigator.pop(
                    context,
                  ),
          icon:
              const Icon(
            Icons
                .arrow_back_ios_new_rounded,
            size: 19,
            color: heading,
          ),
        ),

        title:
            Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              'Add Car',
              style:
                  GoogleFonts.manrope(
                fontSize: 19,
                fontWeight:
                    FontWeight.w800,
                color: heading,
              ),
            ),
            Text(
              'Add a vehicle to your fleet',
              style:
                  GoogleFonts.manrope(
                fontSize: 10,
                fontWeight:
                    FontWeight.w600,
                color: muted,
              ),
            ),
          ],
        ),

        bottom:
            PreferredSize(
          preferredSize:
              const Size.fromHeight(1),
          child:
              Container(
            height: 1,
            color: border,
          ),
        ),
      ),

      body:
          Form(
        key: _formKey,

        child:
            SingleChildScrollView(
          physics:
              const BouncingScrollPhysics(),

          padding:
              const EdgeInsets.fromLTRB(
            20,
            20,
            20,
            120,
          ),

          child:
              Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              _buildIntro(),

              const SizedBox(
                height: 22,
              ),

              _buildSection(
                title:
                    'Vehicle photos',
                subtitle:
                    'Add high-quality photos. Tap the star to choose the primary photo.',
                child:
                    _buildImageSection(),
              ),

              const SizedBox(
                height: 16,
              ),

              _buildSection(
                title:
                    'Basic information',
                subtitle:
                    'Vehicle information shown to customers.',
                child:
                    _buildBasicInformation(),
              ),

              const SizedBox(
                height: 16,
              ),

              _buildSection(
                title:
                    'Vehicle usage',
                subtitle:
                    'Keep the current odometer reading for fleet operations.',
                child:
                    _buildVehicleUsage(),
              ),

              const SizedBox(
                height: 16,
              ),

              _buildSection(
                title:
                    'Pricing',
                subtitle:
                    'Assign a reusable pricing profile to this vehicle.',
                child:
                    _buildPricingSection(),
              ),

              const SizedBox(
                height: 16,
              ),

              _buildSection(
                title:
                    'Description & features',
                subtitle:
                    'Add useful information about the vehicle.',
                child:
                    _buildDetailsSection(),
              ),

              const SizedBox(
                height: 16,
              ),

              _buildSection(
                title:
                    'Branches',
                subtitle:
                    'Assign this vehicle to one or more branches.',
                child:
                    _buildBranchSection(),
              ),

              const SizedBox(
                height: 16,
              ),

              _buildSection(
                title:
                    'Fleet settings',
                subtitle:
                    'Control visibility and vehicle availability.',
                child:
                    _buildFleetSettings(),
              ),

              const SizedBox(
                height: 24,
              ),

              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // INTRO
  // ============================================================

  Widget _buildIntro() {
    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(18),
      decoration:
          BoxDecoration(
        color:
            softAccent,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        border:
            Border.all(
          color: border,
        ),
      ),
      child:
          Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration:
                BoxDecoration(
              color:
                  card,
              borderRadius:
                  BorderRadius.circular(
                15,
              ),
            ),
            child:
                const Icon(
              Icons
                  .directions_car_filled_rounded,
              color:
                  primary,
              size: 24,
            ),
          ),

          const SizedBox(
            width: 13,
          ),

          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  'New fleet vehicle',
                  style:
                      GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight:
                        FontWeight.w800,
                    color:
                        heading,
                  ),
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  'Add vehicle details, current KM and photos.',
                  style:
                      GoogleFonts.manrope(
                    fontSize: 11,
                    height: 1.4,
                    fontWeight:
                        FontWeight.w500,
                    color:
                        body,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SECTION
  // ============================================================

  Widget _buildSection({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(18),
      decoration:
          BoxDecoration(
        color:
            card,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        border:
            Border.all(
          color: border,
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset:
                const Offset(
              0,
              5,
            ),
            color:
                Colors.black
                    .withOpacity(
              0.025,
            ),
          ),
        ],
      ),
      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style:
                GoogleFonts.manrope(
              fontSize: 16,
              fontWeight:
                  FontWeight.w800,
              color:
                  heading,
            ),
          ),

          const SizedBox(
            height: 3,
          ),

          Text(
            subtitle,
            style:
                GoogleFonts.manrope(
              fontSize: 10.5,
              height: 1.4,
              fontWeight:
                  FontWeight.w500,
              color:
                  muted,
            ),
          ),

          const SizedBox(
            height: 18,
          ),

          child,
        ],
      ),
    );
  }

  // ============================================================
  // IMAGE SECTION
  // ============================================================

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap:
              _saving
                  ? null
                  : _pickImages,
          child:
              Container(
            width:
                double.infinity,
            height: 150,
            decoration:
                BoxDecoration(
              color:
                  background,
              borderRadius:
                  BorderRadius.circular(
                18,
              ),
              border:
                  Border.all(
                color:
                    _selectedImages
                            .isEmpty
                        ? border
                        : primary.withOpacity(
                            0.25,
                          ),
              ),
            ),
            child:
                _selectedImages.isEmpty
                    ? Column(
                        mainAxisAlignment:
                            MainAxisAlignment
                                .center,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration:
                                BoxDecoration(
                              color:
                                  softAccent,
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                16,
                              ),
                            ),
                            child:
                                const Icon(
                              Icons
                                  .add_photo_alternate_outlined,
                              color:
                                  primary,
                              size: 26,
                            ),
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          Text(
                            'Add vehicle photos',
                            style:
                                GoogleFonts
                                    .manrope(
                              fontSize: 13,
                              fontWeight:
                                  FontWeight
                                      .w800,
                              color:
                                  heading,
                            ),
                          ),
                          const SizedBox(
                            height: 3,
                          ),
                          Text(
                            'Select multiple photos from your gallery',
                            style:
                                GoogleFonts
                                    .manrope(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color:
                                  muted,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment:
                            MainAxisAlignment
                                .center,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration:
                                BoxDecoration(
                              color:
                                  softAccent,
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                14,
                              ),
                            ),
                            child:
                                const Icon(
                              Icons
                                  .add_a_photo_outlined,
                              color:
                                  primary,
                              size: 23,
                            ),
                          ),
                          const SizedBox(
                            height: 9,
                          ),
                          Text(
                            'Add more photos',
                            style:
                                GoogleFonts
                                    .manrope(
                              fontSize: 12.5,
                              fontWeight:
                                  FontWeight
                                      .w800,
                              color:
                                  heading,
                            ),
                          ),
                          const SizedBox(
                            height: 3,
                          ),
                          Text(
                            '${_selectedImages.length} photo${_selectedImages.length == 1 ? '' : 's'} selected',
                            style:
                                GoogleFonts
                                    .manrope(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color:
                                  muted,
                            ),
                          ),
                        ],
                      ),
          ),
        ),

        if (_selectedImages
            .isNotEmpty) ...[
          const SizedBox(
            height: 15,
          ),

          Text(
            'Selected photos',
            style:
                GoogleFonts.manrope(
              fontSize: 12,
              fontWeight:
                  FontWeight.w800,
              color:
                  heading,
            ),
          ),

          const SizedBox(
            height: 10,
          ),

          GridView.builder(
            shrinkWrap: true,
            physics:
                const NeverScrollableScrollPhysics(),
            itemCount:
                _selectedImages.length,
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 9,
              mainAxisSpacing: 9,
              childAspectRatio: 1,
            ),
            itemBuilder:
                (_, index) {
              final isPrimary =
                  index ==
                      _primaryImageIndex;

              return Stack(
                children: [
                  Positioned.fill(
                    child:
                        ClipRRect(
                      borderRadius:
                          BorderRadius.circular(
                        14,
                      ),
                      child:
                          Image.memory(
                        _selectedImages[
                            index],
                        fit:
                            BoxFit.cover,
                      ),
                    ),
                  ),

                  Positioned(
                    top: 7,
                    left: 7,
                    child:
                        GestureDetector(
                      onTap: () =>
                          _setPrimaryImage(
                        index,
                      ),
                      child:
                          Container(
                        width: 31,
                        height: 31,
                        decoration:
                            BoxDecoration(
                          color:
                              isPrimary
                                  ? primary
                                  : Colors.black
                                      .withOpacity(
                                      0.55,
                                    ),
                          shape:
                              BoxShape.circle,
                        ),
                        child:
                            Icon(
                          isPrimary
                              ? Icons.star_rounded
                              : Icons
                                  .star_border_rounded,
                          color:
                              Colors.white,
                          size: 17,
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    top: 7,
                    right: 7,
                    child:
                        GestureDetector(
                      onTap: () =>
                          _removeImage(
                        index,
                      ),
                      child:
                          Container(
                        width: 31,
                        height: 31,
                        decoration:
                            BoxDecoration(
                          color:
                              Colors.black
                                  .withOpacity(
                            0.55,
                          ),
                          shape:
                              BoxShape.circle,
                        ),
                        child:
                            const Icon(
                          Icons.close_rounded,
                          color:
                              Colors.white,
                          size: 17,
                        ),
                      ),
                    ),
                  ),

                  if (isPrimary)
                    Positioned(
                      left: 7,
                      bottom: 7,
                      child:
                          Container(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration:
                            BoxDecoration(
                          color:
                              primary,
                          borderRadius:
                              BorderRadius.circular(
                            8,
                          ),
                        ),
                        child:
                            Text(
                          'PRIMARY',
                          style:
                              GoogleFonts
                                  .manrope(
                            fontSize: 8,
                            fontWeight:
                                FontWeight.w900,
                            color:
                                Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),

          const SizedBox(
            height: 9,
          ),

          Text(
            'Tap the star on any photo to make it the primary vehicle image.',
            style:
                GoogleFonts.manrope(
              fontSize: 9.5,
              fontWeight:
                  FontWeight.w500,
              color:
                  muted,
            ),
          ),
        ],
      ],
    );
  }

  // ============================================================
  // BASIC INFORMATION
  // ============================================================

  Widget _buildBasicInformation() {
    return Column(
      children: [
        _textField(
          controller:
              _nameController,
          label:
              'Car name',
          hint:
              'e.g. Hyundai Creta',
          icon:
              Icons
                  .directions_car_outlined,
          requiredField:
              true,
        ),

        const SizedBox(
          height: 14,
        ),

        Row(
          children: [
            Expanded(
              child:
                  _dropdownField<String>(
                label:
                    'Type',
                value:
                    _selectedType,
                items:
                    const [
                  'Hatchback',
                  'Sedan',
                  'SUV',
                  'MUV',
                  'Luxury',
                  'Sports',
                  'Convertible',
                  'Other',
                ],
                onChanged:
                    (value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    _selectedType =
                        value;
                  });
                },
              ),
            ),

            const SizedBox(
              width: 12,
            ),

            Expanded(
              child:
                  _dropdownField<int>(
                label:
                    'Seats',
                value:
                    _selectedSeats,
                items:
                    const [
                  2,
                  4,
                  5,
                  6,
                  7,
                  8,
                  9,
                ],
                itemLabel:
                    (value) =>
                        '$value Seats',
                onChanged:
                    (value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    _selectedSeats =
                        value;
                  });
                },
              ),
            ),
          ],
        ),

        const SizedBox(
          height: 14,
        ),

        Row(
          children: [
            Expanded(
              child:
                  _dropdownField<String>(
                label:
                    'Transmission',
                value:
                    _selectedTransmission,
                items:
                    const [
                  'Manual',
                  'Automatic',
                  'AMT',
                  'CVT',
                  'DCT',
                ],
                onChanged:
                    (value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    _selectedTransmission =
                        value;
                  });
                },
              ),
            ),

            const SizedBox(
              width: 12,
            ),

            Expanded(
              child:
                  _dropdownField<String>(
                label:
                    'Fuel',
                value:
                    _selectedFuel,
                items:
                    const [
                  'Petrol',
                  'Diesel',
                  'CNG',
                  'Electric',
                  'Hybrid',
                ],
                onChanged:
                    (value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    _selectedFuel =
                        value;
                  });
                },
              ),
            ),
          ],
        ),

        const SizedBox(
          height: 14,
        ),

        _textField(
          controller:
              _registrationController,
          label:
              'Registration number',
          hint:
              'e.g. MH12AB1234',
          icon:
              Icons
                  .confirmation_number_outlined,
          requiredField:
              true,
          textCapitalization:
              TextCapitalization
                  .characters,
        ),
      ],
    );
  }

  // ============================================================
  // VEHICLE USAGE
  // ============================================================

  Widget _buildVehicleUsage() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        _textField(
          controller:
              _currentKmController,
          label:
              'Current KM',
          hint:
              'e.g. 45230',
          icon:
              Icons.speed_rounded,
          requiredField:
              true,
          keyboardType:
              TextInputType.number,
        ),

        const SizedBox(
          height: 8,
        ),

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
                Icons.info_outline_rounded,
                color:
                    primary,
                size: 18,
              ),
            ),

            const SizedBox(
              width: 9,
            ),

            Expanded(
              child:
                  Text(
                'Enter the vehicle odometer reading at the time of adding the car. This can be updated later after pickup/return inspections.',
                style:
                    GoogleFonts.manrope(
                  fontSize: 10,
                  height: 1.4,
                  fontWeight:
                      FontWeight.w500,
                  color:
                      muted,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // PRICING
  // ============================================================

  Widget _buildPricingSection() {
    final profile =
        _selectedPricingProfile;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap:
              _isPricingLoading
                  ? null
                  : _selectPricingProfile,
          borderRadius:
              BorderRadius.circular(
            14,
          ),
          child:
              InputDecorator(
            decoration:
                InputDecoration(
              labelText:
                  'Pricing profile',

              prefixIcon:
                  const Icon(
                Icons
                    .price_change_outlined,
                color:
                    primary,
                size: 19,
              ),

              suffixIcon:
                  _isPricingLoading
                      ? const Padding(
                          padding:
                              EdgeInsets.all(
                            14,
                          ),
                          child:
                              SizedBox(
                            width: 16,
                            height: 16,
                            child:
                                CircularProgressIndicator(
                              strokeWidth:
                                  2,
                              color:
                                  primary,
                            ),
                          ),
                        )
                      : const Icon(
                          Icons
                              .keyboard_arrow_down_rounded,
                          color:
                              muted,
                        ),

              filled: true,
              fillColor:
                  background,

              border:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(
                  14,
                ),
                borderSide:
                    const BorderSide(
                  color:
                      border,
                ),
              ),

              enabledBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(
                  14,
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
                  14,
                ),
                borderSide:
                    const BorderSide(
                  color:
                      primary,
                  width:
                      1.3,
                ),
              ),
            ),

            child:
                profile == null
                    ? Text(
                        _pricingLoadError !=
                                null
                            ? 'Unable to load pricing profiles'
                            : 'Optional — assign pricing later',
                        style:
                            GoogleFonts.manrope(
                          fontSize:
                              12,
                          fontWeight:
                              FontWeight.w500,
                          color:
                              muted,
                        ),
                      )
                    : Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Text(
                            profile
                                    .name
                                    .isEmpty
                                ? profile.id
                                : profile
                                    .name,
                            maxLines:
                                1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style:
                                GoogleFonts
                                    .manrope(
                              fontSize:
                                  12.5,
                              fontWeight:
                                  FontWeight
                                      .w800,
                              color:
                                  heading,
                            ),
                          ),
                          const SizedBox(
                            height: 3,
                          ),
                          Text(
                            _pricingProfileSummary(
                              profile,
                            ),
                            maxLines:
                                1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style:
                                GoogleFonts
                                    .manrope(
                              fontSize:
                                  10.5,
                              fontWeight:
                                  FontWeight
                                      .w600,
                              color:
                                  body,
                            ),
                          ),
                        ],
                      ),
          ),
        ),

        const SizedBox(
          height: 9,
        ),

        Text(
          _pricingLoadError ??
              'The pricing profile controls hourly/daily rates, KM limits, extra KM charges, special dates and security deposit.',
          style:
              GoogleFonts.manrope(
            fontSize: 10,
            height: 1.4,
            color:
                muted,
            fontWeight:
                FontWeight.w500,
          ),
        ),

        const SizedBox(
          height: 5,
        ),

        Align(
          alignment:
              Alignment.centerRight,
          child:
              TextButton.icon(
            onPressed:
                _isPricingLoading
                    ? null
                    : _selectPricingProfile,
            icon:
                const Icon(
              Icons
                  .edit_outlined,
              size: 17,
            ),
            label:
                const Text(
              'Select pricing',
            ),
            style:
                TextButton.styleFrom(
              foregroundColor:
                  primary,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // DETAILS
  // ============================================================

  Widget _buildDetailsSection() {
    return Column(
      children: [
        _textField(
          controller:
              _descriptionController,
          label:
              'Description',
          hint:
              'Describe the vehicle...',
          icon:
              Icons
                  .description_outlined,
          maxLines:
              4,
        ),

        const SizedBox(
          height: 14,
        ),

        _textField(
          controller:
              _featuresController,
          label:
              'Features',
          hint:
              'AC, Bluetooth, Sunroof, Rear Camera',
          icon:
              Icons
                  .auto_awesome_outlined,
          maxLines:
              3,
        ),

        const SizedBox(
          height: 7,
        ),

        Align(
          alignment:
              Alignment.centerLeft,
          child:
              Text(
            'Separate multiple features with commas.',
            style:
                GoogleFonts.manrope(
              fontSize:
                  9.5,
              fontWeight:
                  FontWeight.w500,
              color:
                  muted,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // BRANCH
  // ============================================================

  Widget _buildBranchSection() {
    return Column(
      children: [
        _textField(
          controller:
              _branchIdsController,
          label:
              'Branch IDs',
          hint:
              'branch_001, branch_002',
          icon:
              Icons
                  .storefront_outlined,
          maxLines:
              2,
        ),

        const SizedBox(
          height: 7,
        ),

        Align(
          alignment:
              Alignment.centerLeft,
          child:
              Text(
            'Enter Firebase branch IDs separated by commas.',
            style:
                GoogleFonts.manrope(
              fontSize:
                  9.5,
              fontWeight:
                  FontWeight.w500,
              color:
                  muted,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // FLEET SETTINGS
  // ============================================================

  Widget _buildFleetSettings() {
    return Column(
      children: [
        _switchTile(
          icon:
              Icons.visibility_outlined,
          title:
              'Active vehicle',
          subtitle:
              'Allow this vehicle to appear in the fleet.',
          value:
              _isActive,
          onChanged:
              (value) {
            setState(() {
              _isActive =
                  value;

              if (!value) {
                _isAvailable =
                    false;

                _isFeatured =
                    false;
              }
            });
          },
        ),

        const Divider(
          height: 1,
          color:
              border,
        ),

        _switchTile(
          icon:
              Icons
                  .check_circle_outline_rounded,
          title:
              'Available for booking',
          subtitle:
              'Customers can currently book this vehicle.',
          value:
              _isAvailable,
          enabled:
              _isActive,
          onChanged:
              (value) {
            setState(() {
              _isAvailable =
                  value;
            });
          },
        ),

        const Divider(
          height: 1,
          color:
              border,
        ),

        _switchTile(
          icon:
              Icons
                  .star_border_rounded,
          title:
              'Featured vehicle',
          subtitle:
              'Show this vehicle in featured sections.',
          value:
              _isFeatured,
          enabled:
              _isActive,
          onChanged:
              (value) {
            setState(() {
              _isFeatured =
                  value;
            });
          },
        ),

        const SizedBox(
          height: 12,
        ),

        _textField(
          controller:
              _sortOrderController,
          label:
              'Sort order',
          hint:
              '0',
          icon:
              Icons
                  .sort_rounded,
          keyboardType:
              TextInputType.number,
        ),
      ],
    );
  }

  // ============================================================
  // SWITCH
  // ============================================================

  Widget _switchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>
        onChanged,
    bool enabled = true,
  }) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 10,
      ),
      child:
          Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration:
                BoxDecoration(
              color:
                  enabled
                      ? softAccent
                      : background,
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
            ),
            child:
                Icon(
              icon,
              size: 19,
              color:
                  enabled
                      ? primary
                      : muted,
            ),
          ),

          const SizedBox(
            width: 11,
          ),

          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      GoogleFonts.manrope(
                    fontSize:
                        12,
                    fontWeight:
                        FontWeight.w800,
                    color:
                        enabled
                            ? heading
                            : muted,
                  ),
                ),
                const SizedBox(
                  height: 2,
                ),
                Text(
                  subtitle,
                  style:
                      GoogleFonts.manrope(
                    fontSize:
                        9.5,
                    height:
                        1.35,
                    fontWeight:
                        FontWeight.w500,
                    color:
                        muted,
                  ),
                ),
              ],
            ),
          ),

          Switch(
            value:
                value,
            onChanged:
                enabled
                    ? onChanged
                    : null,
            activeColor:
                primary,
            activeTrackColor:
                accent.withOpacity(
              0.35,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TEXT FIELD
  // ============================================================

  Widget _textField({
    required TextEditingController
        controller,
    required String label,
    required String hint,
    required IconData icon,
    bool requiredField =
        false,
    TextInputType?
        keyboardType,
    int maxLines = 1,
    String? prefixText,
    TextCapitalization
        textCapitalization =
        TextCapitalization.none,
  }) {
    return TextFormField(
      controller:
          controller,

      keyboardType:
          keyboardType,

      maxLines:
          maxLines,

      textCapitalization:
          textCapitalization,

      style:
          GoogleFonts.manrope(
        fontSize:
            13,
        fontWeight:
            FontWeight.w600,
        color:
            heading,
      ),

      validator:
          requiredField
              ? (value) {
                  if (value ==
                          null ||
                      value
                          .trim()
                          .isEmpty) {
                    return '$label is required';
                  }

                  if (label ==
                          'Current KM' &&
                      int.tryParse(
                            value
                                .trim(),
                          ) ==
                          null) {
                    return 'Enter a valid KM value';
                  }

                  return null;
                }
              : null,

      decoration:
          InputDecoration(
        labelText:
            label,

        hintText:
            hint,

        prefixText:
            prefixText,

        prefixIcon:
            Icon(
          icon,
          size:
              19,
          color:
              muted,
        ),

        labelStyle:
            GoogleFonts.manrope(
          fontSize:
              12,
          fontWeight:
              FontWeight.w600,
          color:
              body,
        ),

        hintStyle:
            GoogleFonts.manrope(
          fontSize:
              12,
          fontWeight:
              FontWeight.w500,
          color:
              muted,
        ),

        errorStyle:
            GoogleFonts.manrope(
          fontSize:
              9.5,
          fontWeight:
              FontWeight.w600,
        ),

        filled:
            true,

        fillColor:
            background,

        contentPadding:
            const EdgeInsets
                .symmetric(
          horizontal:
              14,
          vertical:
              14,
        ),

        border:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            14,
          ),
          borderSide:
              const BorderSide(
            color:
                border,
          ),
        ),

        enabledBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            14,
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
            14,
          ),
          borderSide:
              const BorderSide(
            color:
                primary,
            width:
                1.3,
          ),
        ),

        errorBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            14,
          ),
          borderSide:
              const BorderSide(
            color:
                danger,
          ),
        ),

        focusedErrorBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            14,
          ),
          borderSide:
              const BorderSide(
            color:
                danger,
            width:
                1.3,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // DROPDOWN
  // ============================================================

  Widget _dropdownField<T>({
    required String label,
    required T value,
    required List<T> items,
    required ValueChanged<T?>
        onChanged,
    String Function(T value)?
        itemLabel,
  }) {
    return DropdownButtonFormField<T>(
      value:
          value,

      onChanged:
          onChanged,

      isExpanded:
          true,

      style:
          GoogleFonts.manrope(
        fontSize:
            12,
        fontWeight:
            FontWeight.w600,
        color:
            heading,
      ),

      icon:
          const Icon(
        Icons
            .keyboard_arrow_down_rounded,
        color:
            muted,
        size:
            20,
      ),

      decoration:
          InputDecoration(
        labelText:
            label,

        labelStyle:
            GoogleFonts.manrope(
          fontSize:
              12,
          fontWeight:
              FontWeight.w600,
          color:
              body,
        ),

        filled:
            true,

        fillColor:
            background,

        contentPadding:
            const EdgeInsets
                .symmetric(
          horizontal:
              13,
          vertical:
              13,
        ),

        border:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            14,
          ),
          borderSide:
              const BorderSide(
            color:
                border,
          ),
        ),

        enabledBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            14,
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
            14,
          ),
          borderSide:
              const BorderSide(
            color:
                primary,
            width:
                1.3,
          ),
        ),
      ),

      items:
          items.map(
        (item) {
          return DropdownMenuItem<T>(
            value:
                item,
            child:
                Text(
              itemLabel !=
                      null
                  ? itemLabel(
                      item,
                    )
                  : item
                      .toString(),
              overflow:
                  TextOverflow
                      .ellipsis,
            ),
          );
        },
      ).toList(),
    );
  }

  // ============================================================
  // SAVE BUTTON
  // ============================================================

  Widget _buildSaveButton() {
    return SizedBox(
      width:
          double.infinity,
      height:
          54,
      child:
          ElevatedButton(
        onPressed:
            _saving
                ? null
                : _saveCar,

        style:
            ElevatedButton
                .styleFrom(
          backgroundColor:
              primary,
          foregroundColor:
              Colors.white,
          disabledBackgroundColor:
              primary.withOpacity(
            0.55,
          ),
          elevation:
              0,
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              16,
            ),
          ),
        ),

        child:
            _saving
                ? Row(
                    mainAxisAlignment:
                        MainAxisAlignment
                            .center,
                    children: [
                      const SizedBox(
                        width:
                            21,
                        height:
                            21,
                        child:
                            CircularProgressIndicator(
                          color:
                              Colors.white,
                          strokeWidth:
                              2.2,
                        ),
                      ),
                      const SizedBox(
                        width:
                            10,
                      ),
                      Text(
                        'Saving vehicle...',
                        style:
                            GoogleFonts
                                .manrope(
                          fontSize:
                              13,
                          fontWeight:
                              FontWeight
                                  .w800,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment:
                        MainAxisAlignment
                            .center,
                    children: [
                      const Icon(
                        Icons
                            .check_rounded,
                        size:
                            20,
                      ),
                      const SizedBox(
                        width:
                            8,
                      ),
                      Text(
                        'Add Vehicle',
                        style:
                            GoogleFonts
                                .manrope(
                          fontSize:
                              13,
                          fontWeight:
                              FontWeight
                                  .w800,
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}