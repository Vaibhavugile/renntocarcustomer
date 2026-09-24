import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/config/app_config.dart';
import '../../../cars/models/car.dart';
import '../../../cars/services/car_service.dart';
import '../../../pricing/models/pricing_profile.dart';
import '../../../pricing/services/pricing_profile_service.dart';

class AdminEditCarScreen extends StatefulWidget {
  final Car car;

  const AdminEditCarScreen({
    super.key,
    required this.car,
  });

  @override
  State<AdminEditCarScreen> createState() =>
      _AdminEditCarScreenState();
}

class _AdminEditCarScreenState
    extends State<AdminEditCarScreen> {
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

  // ============================================================
  // FORM
  // ============================================================

  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController
      _registrationController;
  late final TextEditingController _currentKmController;
  late final TextEditingController _priceController;
  late final TextEditingController _sortOrderController;
  late final TextEditingController
      _descriptionController;
  late final TextEditingController
      _featuresController;
  late final TextEditingController
      _branchIdsController;

  late String _type;
  late int _seats;
  late String _transmission;
  late String _fuel;

  late bool _isActive;
  late bool _isAvailable;
  late bool _isFeatured;

  // ============================================================
  // PRICING PROFILE
  // ============================================================

  final TextEditingController
      _pricingProfileSearchController =
      TextEditingController();

  List<PricingProfile> _pricingProfiles =
      <PricingProfile>[];

  PricingProfile? _selectedPricingProfile;

  bool _loadingPricingProfiles = false;
  String? _pricingLoadError;

  // ============================================================
  // IMAGE MANAGEMENT
  // ============================================================

  final ImagePicker _imagePicker =
      ImagePicker();

  /// Existing Firebase Storage URLs.
  final List<String> _existingImages =
      <String>[];

  /// Newly selected local images.
  final List<XFile> _newImages =
      <XFile>[];

  /// Existing primary image.
  String _primaryImage = '';

  /// Whether an existing image was removed.
  final Set<String> _removedImages =
      <String>{};

  // ============================================================
  // STATE
  // ============================================================

  bool _isSaving = false;
  double _uploadProgress = 0;

  // ============================================================
  // OPTIONS
  // ============================================================

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

  final List<String> _transmissions =
      <String>[
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

  // ============================================================
  // TENANT
  // ============================================================

  String get _tenantId =>
      AppConfig.tenant.tenantId.trim();

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    final car = widget.car;

    _nameController =
        TextEditingController(
      text: car.name,
    );

    _registrationController =
        TextEditingController(
      text: car.registrationNumber,
    );

    _currentKmController =
        TextEditingController(
      text: car.currentKm.toString(),
    );

    _priceController =
        TextEditingController(
      text: car.pricePerDay.toString(),
    );

    _sortOrderController =
        TextEditingController(
      text: car.sortOrder.toString(),
    );

    _descriptionController =
        TextEditingController(
      text: car.description,
    );

    _featuresController =
        TextEditingController(
      text: car.features.join(', '),
    );

    _branchIdsController =
        TextEditingController(
      text: car.branchIds.join(', '),
    );

    _type = _types.contains(car.type)
        ? car.type
        : _types.first;

    _seats =
        _seatOptions.contains(car.seats)
            ? car.seats
            : 5;

    _transmission =
        _transmissions.contains(
      car.transmission,
    )
            ? car.transmission
            : _transmissions.first;

    _fuel = _fuels.contains(car.fuel)
        ? car.fuel
        : _fuels.first;

    _isActive = car.isActive;
    _isAvailable = car.isAvailable;
    _isFeatured = car.isFeatured;

    _primaryImage = car.image;

    _existingImages.addAll(
      car.images.where(
        (image) => image.trim().isNotEmpty,
      ),
    );

    /*
     * Make sure the primary image is also represented
     * in the image collection when appropriate.
     */
    if (_primaryImage.isNotEmpty &&
        !_existingImages.contains(
          _primaryImage,
        )) {
      _existingImages.insert(
        0,
        _primaryImage,
      );
    }

    _loadPricingProfiles();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _nameController.dispose();
    _registrationController.dispose();
    _currentKmController.dispose();
    _priceController.dispose();
    _sortOrderController.dispose();
    _descriptionController.dispose();
    _featuresController.dispose();
    _branchIdsController.dispose();
    _pricingProfileSearchController.dispose();

    super.dispose();
  }

  // ============================================================
  // PICK IMAGES
  // ============================================================

  Future<void> _pickImages() async {
    if (_isSaving) return;

    try {
      final List<XFile> picked =
          await _imagePicker.pickMultiImage(
        imageQuality: 90,
      );

      if (picked.isEmpty) {
        return;
      }

      const int maxImages = 12;

      final total =
          _existingImages.length +
          _newImages.length;

      final remaining =
          maxImages - total;

      if (remaining <= 0) {
        _showError(
          'Maximum 12 vehicle images allowed.',
        );
        return;
      }

      final selected =
          picked.take(remaining).toList();

      if (!mounted) return;

      setState(() {
        _newImages.addAll(selected);
      });
    } catch (e) {
      _showError(
        'Unable to select images.',
      );
    }
  }

  // ============================================================
  // PICK PRIMARY IMAGE
  // ============================================================

  Future<void> _pickPrimaryImage() async {
    if (_isSaving) return;

    try {
      final XFile? picked =
          await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      if (picked == null) {
        return;
      }

      if (!mounted) return;

      setState(() {
        _newImages.insert(0, picked);
      });
    } catch (_) {
      _showError(
        'Unable to select primary image.',
      );
    }
  }

  // ============================================================
  // REMOVE EXISTING IMAGE
  // ============================================================

  void _removeExistingImage(
    String url,
  ) {
    if (_isSaving) return;

    setState(() {
      _removedImages.add(url);

      if (_primaryImage == url) {
        _primaryImage = '';
      }
    });
  }

  // ============================================================
  // REMOVE NEW IMAGE
  // ============================================================

  void _removeNewImage(
    int index,
  ) {
    if (_isSaving) return;

    if (index < 0 ||
        index >= _newImages.length) {
      return;
    }

    setState(() {
      _newImages.removeAt(index);
    });
  }

  // ============================================================
  // SET EXISTING IMAGE AS PRIMARY
  // ============================================================

  void _setExistingPrimary(
    String url,
  ) {
    if (_isSaving) return;

    if (_removedImages.contains(url)) {
      return;
    }

    setState(() {
      _primaryImage = url;
    });
  }

  // ============================================================
  // PRICING PROFILE LOADING
  // ============================================================

  Future<void> _loadPricingProfiles() async {
    if (_tenantId.isEmpty) {
      if (!mounted) return;

      setState(() {
        _pricingLoadError =
            'Tenant configuration is missing.';
      });

      return;
    }

    setState(() {
      _loadingPricingProfiles = true;
      _pricingLoadError = null;
    });

    try {
      final profiles =
          await PricingProfileService
              .instance
              .getAllPricingProfiles(
        tenantId: _tenantId,
        activeOnly: false,
      );

      PricingProfile? selected;

      final currentId =
          widget.car.pricingProfileId.trim();

      if (currentId.isNotEmpty) {
        for (final profile in profiles) {
          if (profile.id.trim() ==
              currentId) {
            selected = profile;
            break;
          }
        }

        if (selected == null) {
          selected =
              await PricingProfileService
                  .instance
                  .getPricingProfileById(
            tenantId: _tenantId,
            pricingProfileId: currentId,
          );
        }
      }

      if (!mounted) return;

      setState(() {
        _pricingProfiles =
            List<PricingProfile>.from(
          profiles,
        );

        if (selected != null &&
            !_pricingProfiles.any(
              (item) =>
                  item.id == selected!.id,
            )) {
          _pricingProfiles.add(
            selected!,
          );
        }

        _selectedPricingProfile =
            selected;

        _loadingPricingProfiles = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingPricingProfiles = false;
        _pricingLoadError =
            'Unable to load pricing profiles.';
      });
    }
  }

  // ============================================================
  // PRICING PROFILE PICKER
  // ============================================================

  Future<void>
      _openPricingProfilePicker() async {
    FocusScope.of(context).unfocus();

    if (_loadingPricingProfiles) {
      _showError(
        'Pricing profiles are still loading.',
      );
      return;
    }

    if (_pricingProfiles.isEmpty) {
      await _loadPricingProfiles();

      if (!mounted) return;

      if (_pricingProfiles.isEmpty) {
        _showError(
          _pricingLoadError ??
              'No pricing profiles available.',
        );
        return;
      }
    }

    _pricingProfileSearchController.clear();

    final selected =
        await showModalBottomSheet<
            PricingProfile>(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          Colors.transparent,
      builder: (context) {
        return _PricingProfilePickerSheet(
          profiles: _pricingProfiles,
          selectedProfileId:
              _selectedPricingProfile?.id,
          searchController:
              _pricingProfileSearchController,
        );
      },
    );

    if (selected == null ||
        !mounted) {
      return;
    }

    setState(() {
      _selectedPricingProfile =
          selected;
    });
  }

  // ============================================================
  // UPLOAD SINGLE IMAGE
  // ============================================================

  Future<String> _uploadImage(
    XFile image,
    String carId,
    int index,
  ) async {
    final file =
        File(image.path);

    final bytes =
        await file.length();

    if (bytes <= 0) {
      throw Exception(
        'Selected image is empty.',
      );
    }

    final extension =
        image.path
            .split('.')
            .last
            .toLowerCase();

    final safeExtension =
        extension == 'png'
            ? 'png'
            : 'jpg';

    final ref =
        FirebaseStorage.instance
            .ref()
            .child('tenants')
            .child(_tenantId)
            .child('cars')
            .child(carId)
            .child(
              'gallery_${DateTime.now().millisecondsSinceEpoch}_$index.$safeExtension',
            );

    final metadata =
        SettableMetadata(
      contentType:
          safeExtension == 'png'
              ? 'image/png'
              : 'image/jpeg',
      cacheControl:
          'public,max-age=31536000',
    );

    final task =
        ref.putFile(
      file,
      metadata,
    );

    task.snapshotEvents.listen(
      (snapshot) {
        if (!mounted) return;

        if (snapshot.totalBytes > 0) {
          setState(() {
            _uploadProgress =
                snapshot.bytesTransferred /
                    snapshot.totalBytes;
          });
        }
      },
    );

    await task;

    return ref.getDownloadURL();
  }

  // ============================================================
  // UPLOAD ALL NEW IMAGES
  // ============================================================

  Future<List<String>>
      _uploadNewImages(
    String carId,
  ) async {
    final urls = <String>[];

    for (int i = 0;
        i < _newImages.length;
        i++) {
      final url =
          await _uploadImage(
        _newImages[i],
        carId,
        i,
      );

      urls.add(url);

      if (!mounted) return urls;

      setState(() {
        _uploadProgress =
            (i + 1) /
                _newImages.length;
      });
    }

    return urls;
  }

  // ============================================================
  // UPDATE CAR
  // ============================================================

  Future<void> _updateCar() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!
        .validate()) {
      return;
    }

    if (_tenantId.isEmpty) {
      _showError(
        'Tenant configuration is missing.',
      );
      return;
    }

    final carId =
        widget.car.id.trim();

    if (carId.isEmpty) {
      _showError(
        'Car ID is missing.',
      );
      return;
    }

    final price =
        int.tryParse(
      _priceController.text.trim(),
    );

    if (price == null ||
        price < 0) {
      _showError(
        'Enter a valid display price.',
      );
      return;
    }

    final currentKm =
        int.tryParse(
      _currentKmController.text.trim(),
    );

    if (currentKm == null ||
        currentKm < 0) {
      _showError(
        'Enter a valid current KM.',
      );
      return;
    }

    final sortOrder =
        int.tryParse(
      _sortOrderController.text.trim(),
    );

    if (sortOrder == null ||
        sortOrder < 0) {
      _showError(
        'Enter a valid sort order.',
      );
      return;
    }

    final pricingProfileId =
        _selectedPricingProfile
                ?.id
                .trim() ??
            '';

    if (pricingProfileId.isEmpty) {
      _showError(
        'Please select a pricing profile.',
      );
      return;
    }

    PricingProfile? verifiedProfile;

    try {
      verifiedProfile =
          await PricingProfileService
              .instance
              .getPricingProfileById(
        tenantId: _tenantId,
        pricingProfileId:
            pricingProfileId,
      );
    } catch (_) {}

    if (verifiedProfile == null) {
      _showError(
        'Selected pricing profile no longer exists.',
      );
      return;
    }

    if (!verifiedProfile.isActive) {
      _showError(
        'Selected pricing profile is inactive.',
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _uploadProgress = 0;
    });

    try {
      // ========================================================
      // FEATURES
      // ========================================================

      final features =
          _featuresController.text
              .split(',')
              .map(
                (item) => item.trim(),
              )
              .where(
                (item) =>
                    item.isNotEmpty,
              )
              .toSet()
              .toList();

      // ========================================================
      // BRANCHES
      // ========================================================

      final branchIds =
          _branchIdsController.text
              .split(',')
              .map(
                (item) => item.trim(),
              )
              .where(
                (item) =>
                    item.isNotEmpty,
              )
              .toSet()
              .toList();

      // ========================================================
      // EXISTING IMAGES
      // ========================================================

      final retainedImages =
          _existingImages
              .where(
                (url) =>
                    !_removedImages
                        .contains(url),
              )
              .toList();

      // ========================================================
      // UPLOAD NEW IMAGES
      // ========================================================

      final newUrls =
          await _uploadNewImages(
        carId,
      );

      final allImages =
          <String>[
        ...retainedImages,
        ...newUrls,
      ];

      // ========================================================
      // DETERMINE PRIMARY IMAGE
      // ========================================================

      String primaryImage =
          _primaryImage.trim();

      /*
       * If the old primary image was removed,
       * use the first available image.
       */
      if (primaryImage.isEmpty ||
          _removedImages.contains(
            primaryImage,
          )) {
        if (newUrls.isNotEmpty) {
          primaryImage =
              newUrls.first;
        } else if (allImages.isNotEmpty) {
          primaryImage =
              allImages.first;
        }
      }

      /*
       * If a new image was selected and the old
       * primary is still being used, keep old primary.
       *
       * The first newly uploaded image is made
       * primary only when no primary exists.
       */

      // ========================================================
      // STATUS
      // ========================================================

      final status = !_isActive
          ? 'inactive'
          : (!_isAvailable
              ? 'unavailable'
              : 'available');

      // ========================================================
      // UPDATED CAR
      // ========================================================

      final updatedCar = Car(
        id: carId,
        tenantId: _tenantId,

        name:
            _nameController.text.trim(),

        type: _type,

        transmission:
            _transmission,

        seats: _seats,

        fuel: _fuel,

        pricingProfileId:
            pricingProfileId,

        pricePerDay: price,

        image: primaryImage,

        images: allImages,

        registrationNumber:
            _registrationController
                .text
                .trim(),

        currentKm: currentKm,

        description:
            _descriptionController
                .text
                .trim(),

        features: features,

        branchIds: branchIds,

        status: status,

        isAvailable:
            _isAvailable,

        isFeatured:
            _isFeatured,

        isActive:
            _isActive,

        sortOrder: sortOrder,
      );

      // ========================================================
      // SAVE CAR
      // ========================================================

      await CarService.instance
          .updateCar(
        tenantId: _tenantId,
        carId: carId,
        car: updatedCar,
      );

      // ========================================================
      // ENSURE PRICING CONNECTION
      // ========================================================

      final carRef =
          FirebaseFirestore.instance
              .collection('tenants')
              .doc(_tenantId)
              .collection('cars')
              .doc(carId);

      await carRef.set(
        <String, dynamic>{
          'tenantId': _tenantId,
          'pricingProfileId':
              pricingProfileId,
          'image': primaryImage,
          'images': allImages,
          'currentKm': currentKm,
          'updatedAt':
              FieldValue.serverTimestamp(),
        },
        SetOptions(
          merge: true,
        ),
      );

      // ========================================================
      // VERIFY
      // ========================================================

      final saved =
          await carRef.get();

      final savedData =
          saved.data() ?? {};

      final savedPricingId =
          savedData[
                  'pricingProfileId']
              ?.toString()
              .trim() ??
          '';

      if (savedPricingId !=
          pricingProfileId) {
        throw Exception(
          'Pricing profile connection could not be verified.',
        );
      }

      if (!mounted) return;

      setState(() {
        _isSaving = false;
        _uploadProgress = 1;
        _selectedPricingProfile =
            verifiedProfile;
      });

      _showSuccess(
        'Car updated successfully.',
      );

      Navigator.pop(
        context,
        updatedCar,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      _showError(
        'Unable to update car. '
        '${_cleanError(e)}',
      );
    }
  }

  // ============================================================
  // CLEAN ERROR
  // ============================================================

  String _cleanError(
    Object error,
  ) {
    final message =
        error.toString()
            .replaceFirst(
              'Exception: ',
              '',
            )
            .trim();

    return message.isEmpty
        ? 'Please try again.'
        : message;
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
            background,
        surfaceTintColor:
            Colors.transparent,
        elevation: 0,

        leading: IconButton(
          onPressed: _isSaving
              ? null
              : () =>
                  Navigator.pop(
                    context,
                  ),
          icon: const Icon(
            Icons
                .arrow_back_rounded,
            color: heading,
          ),
        ),

        title: Text(
          'Edit Car',
          style:
              GoogleFonts.manrope(
            color: heading,
            fontSize: 20,
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ),

      body: SafeArea(
        child: Form(
          key: _formKey,

          child: ListView(
            padding:
                const EdgeInsets.fromLTRB(
              20,
              8,
              20,
              120,
            ),

            children: [
              _buildCarHeader(),

              const SizedBox(
                height: 18,
              ),

              _buildImageSection(),

              const SizedBox(
                height: 16,
              ),

              _buildPricingConnectionSection(),

              const SizedBox(
                height: 16,
              ),

              _buildBasicInformation(),

              const SizedBox(
                height: 16,
              ),

              _buildVehicleDetails(),

              const SizedBox(
                height: 16,
              ),

              _buildPricingSection(),

              const SizedBox(
                height: 16,
              ),

              _buildBranchSection(),

              const SizedBox(
                height: 16,
              ),

              _buildStatusSection(),

              const SizedBox(
                height: 16,
              ),

              _buildDisplayOrder(),
            ],
          ),
        ),
      ),

      bottomNavigationBar:
          _buildSaveButton(),
    );
  }

  // ============================================================
  // CAR HEADER
  // ============================================================

  Widget _buildCarHeader() {
    return Container(
      padding:
          const EdgeInsets.all(18),

      decoration:
          BoxDecoration(
        color: card,
        borderRadius:
            BorderRadius.circular(22),
        border:
            Border.all(
          color: border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withValues(
              alpha: 0.03,
            ),
            blurRadius: 18,
            offset:
                const Offset(0, 7),
          ),
        ],
      ),

      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration:
                BoxDecoration(
              color: softAccent,
              borderRadius:
                  BorderRadius.circular(
                17,
              ),
            ),
            child: const Icon(
              Icons
                  .directions_car_filled_rounded,
              color: primary,
              size: 29,
            ),
          ),

          const SizedBox(
            width: 14,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Edit Vehicle',
                  style:
                      GoogleFonts.manrope(
                    color: heading,
                    fontSize: 18,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  widget.car.name.isEmpty
                      ? 'Vehicle details'
                      : widget.car.name,
                  style:
                      GoogleFonts.manrope(
                    color: body,
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),

                const SizedBox(
                  height: 3,
                ),

                Text(
                  widget.car.registrationNumber,
                  style:
                      GoogleFonts.manrope(
                    color: muted,
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w600,
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
  // IMAGE SECTION
  // ============================================================

  Widget _buildImageSection() {
    final activeExisting =
        _existingImages
            .where(
              (url) =>
                  !_removedImages
                      .contains(url),
            )
            .toList();

    final totalImages =
        activeExisting.length +
        _newImages.length;

    return _buildSection(
      title: 'Vehicle Photos',
      icon: Icons
          .photo_library_rounded,
      children: [
        Text(
          'Add high-quality photos of this vehicle.',
          style:
              GoogleFonts.manrope(
            color: body,
            fontSize: 12,
            fontWeight:
                FontWeight.w500,
          ),
        ),

        const SizedBox(
          height: 14,
        ),

        if (totalImages == 0)
          _buildEmptyImageBox()
        else
          _buildImageGrid(
            activeExisting,
          ),

        const SizedBox(
          height: 14,
        ),

        Row(
          children: [
            Expanded(
              child: _imageActionButton(
                icon: Icons
                    .add_photo_alternate_rounded,
                title: 'Add Photos',
                onTap:
                    _pickImages,
              ),
            ),

            const SizedBox(
              width: 10,
            ),

            Expanded(
              child: _imageActionButton(
                icon: Icons
                    .image_search_rounded,
                title: 'Set Primary',
                onTap:
                    _pickPrimaryImage,
              ),
            ),
          ],
        ),

        const SizedBox(
          height: 9,
        ),

        _helperText(
          '$totalImages / 12 photos • Tap an existing photo to make it primary.',
        ),

        if (_isSaving &&
            _newImages.isNotEmpty) ...[
          const SizedBox(
            height: 14,
          ),

          ClipRRect(
            borderRadius:
                BorderRadius.circular(
              10,
            ),
            child:
                LinearProgressIndicator(
              value:
                  _uploadProgress,
              minHeight: 7,
              backgroundColor:
                  border,
              color: primary,
            ),
          ),

          const SizedBox(
            height: 7,
          ),

          Text(
            'Uploading photos '
            '${(_uploadProgress * 100).round()}%',
            style:
                GoogleFonts.manrope(
              color: primary,
              fontSize: 11,
              fontWeight:
                  FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyImageBox() {
    return InkWell(
      onTap: _pickImages,
      borderRadius:
          BorderRadius.circular(18),

      child: Container(
        height: 180,
        width: double.infinity,

        decoration:
            BoxDecoration(
          color: background,
          borderRadius:
              BorderRadius.circular(
            18,
          ),
          border:
              Border.all(
            color: border,
          ),
        ),

        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration:
                  BoxDecoration(
                color: softAccent,
                borderRadius:
                    BorderRadius.circular(
                  18,
                ),
              ),
              child: const Icon(
                Icons
                    .add_photo_alternate_rounded,
                color: primary,
                size: 29,
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            Text(
              'Add vehicle photos',
              style:
                  GoogleFonts.manrope(
                color: heading,
                fontSize: 14,
                fontWeight:
                    FontWeight.w800,
              ),
            ),

            const SizedBox(
              height: 4,
            ),

            Text(
              'Gallery • JPG / PNG',
              style:
                  GoogleFonts.manrope(
                color: muted,
                fontSize: 11,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageGrid(
    List<String> activeExisting,
  ) {
    return GridView.builder(
      shrinkWrap: true,
      physics:
          const NeverScrollableScrollPhysics(),

      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 9,
        mainAxisSpacing: 9,
        childAspectRatio: 1,
      ),

      itemCount:
          activeExisting.length +
          _newImages.length,

      itemBuilder:
          (context, index) {
        if (index <
            activeExisting.length) {
          final url =
              activeExisting[index];

          final isPrimary =
              url == _primaryImage;

          return _buildExistingImageTile(
            url,
            isPrimary,
          );
        }

        final localIndex =
            index -
                activeExisting.length;

        return _buildNewImageTile(
          localIndex,
        );
      },
    );
  }

  Widget _buildExistingImageTile(
    String url,
    bool isPrimary,
  ) {
    return GestureDetector(
      onTap: () =>
          _setExistingPrimary(
        url,
      ),

      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius:
                BorderRadius.circular(
              16,
            ),

            child:
                Image.network(
              url,
              fit: BoxFit.cover,

              errorBuilder:
                  (_, __, ___) {
                return Container(
                  color: background,
                  child: const Icon(
                    Icons
                        .broken_image_outlined,
                    color: muted,
                  ),
                );
              },
            ),
          ),

          if (isPrimary)
            Positioned(
              left: 7,
              top: 7,
              child: Container(
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 8,
                  vertical: 5,
                ),
                decoration:
                    BoxDecoration(
                  color: primary,
                  borderRadius:
                      BorderRadius.circular(
                    9,
                  ),
                ),
                child: Text(
                  'PRIMARY',
                  style:
                      GoogleFonts.manrope(
                    color:
                        Colors.white,
                    fontSize: 8,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ),
            ),

          Positioned(
            right: 7,
            top: 7,
            child: GestureDetector(
              onTap: () =>
                  _removeExistingImage(
                url,
              ),
              child: Container(
                width: 29,
                height: 29,
                decoration:
                    const BoxDecoration(
                  color: Colors.black54,
                  shape:
                      BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color:
                      Colors.white,
                  size: 17,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewImageTile(
    int index,
  ) {
    final image =
        _newImages[index];

    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius:
              BorderRadius.circular(
            16,
          ),
          child: Image.file(
            File(image.path),
            fit: BoxFit.cover,
          ),
        ),

        Positioned(
          left: 7,
          top: 7,
          child: Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 7,
              vertical: 4,
            ),
            decoration:
                BoxDecoration(
              color: accent,
              borderRadius:
                  BorderRadius.circular(
                8,
              ),
            ),
            child: Text(
              'NEW',
              style:
                  GoogleFonts.manrope(
                color: Colors.white,
                fontSize: 8,
                fontWeight:
                    FontWeight.w900,
              ),
            ),
          ),
        ),

        Positioned(
          right: 7,
          top: 7,
          child: GestureDetector(
            onTap: () =>
                _removeNewImage(
              index,
            ),
            child: Container(
              width: 29,
              height: 29,
              decoration:
                  const BoxDecoration(
                color: Colors.black54,
                shape:
                    BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 17,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _imageActionButton({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: _isSaving
          ? null
          : onTap,
      borderRadius:
          BorderRadius.circular(14),

      child: Container(
        height: 48,
        decoration:
            BoxDecoration(
          color: softAccent,
          borderRadius:
              BorderRadius.circular(
            14,
          ),
          border:
              Border.all(
            color:
                accent.withValues(
              alpha: 0.25,
            ),
          ),
        ),

        child: Row(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: primary,
              size: 19,
            ),
            const SizedBox(
              width: 7,
            ),
            Text(
              title,
              style:
                  GoogleFonts.manrope(
                color: primary,
                fontSize: 12,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BASIC INFORMATION
  // ============================================================

  Widget _buildBasicInformation() {
    return _buildSection(
      title: 'Basic Information',
      icon:
          Icons.directions_car_rounded,
      children: [
        _buildTextField(
          controller:
              _nameController,
          label: 'Car Name',
          hint: 'e.g. Hyundai Creta',
          icon:
              Icons.drive_eta_rounded,
          validator: (value) {
            if (value == null ||
                value.trim().isEmpty) {
              return 'Car name is required';
            }

            return null;
          },
        ),

        const SizedBox(
          height: 14,
        ),

        _buildDropdown<String>(
          label: 'Vehicle Type',
          value: _type,
          items: _types,
          icon:
              Icons.category_rounded,
          onChanged: (value) {
            if (value == null) {
              return;
            }

            setState(() {
              _type = value;
            });
          },
        ),

        const SizedBox(
          height: 14,
        ),

        Row(
          children: [
            Expanded(
              child:
                  _buildDropdown<int>(
                label: 'Seats',
                value: _seats,
                items: _seatOptions,
                icon:
                    Icons.event_seat_rounded,
                itemLabel:
                    (value) =>
                        '$value Seats',
                onChanged:
                    (value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    _seats = value;
                  });
                },
              ),
            ),

            const SizedBox(
              width: 12,
            ),

            Expanded(
              child:
                  _buildDropdown<String>(
                label:
                    'Transmission',
                value:
                    _transmission,
                items:
                    _transmissions,
                icon:
                    Icons.settings_rounded,
                onChanged:
                    (value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    _transmission =
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

        _buildDropdown<String>(
          label: 'Fuel Type',
          value: _fuel,
          items: _fuels,
          icon:
              Icons.local_gas_station_rounded,
          onChanged: (value) {
            if (value == null) {
              return;
            }

            setState(() {
              _fuel = value;
            });
          },
        ),
      ],
    );
  }

  // ============================================================
  // VEHICLE DETAILS
  // ============================================================

  Widget _buildVehicleDetails() {
    return _buildSection(
      title: 'Vehicle Details',
      icon: Icons.badge_rounded,
      children: [
        _buildTextField(
          controller:
              _registrationController,
          label:
              'Registration Number',
          hint: 'MH12AB1234',
          icon:
              Icons.confirmation_number_rounded,
          textCapitalization:
              TextCapitalization
                  .characters,
          validator: (value) {
            if (value == null ||
                value.trim().isEmpty) {
              return 'Registration number is required';
            }

            return null;
          },
        ),

        const SizedBox(
          height: 14,
        ),

        _buildTextField(
          controller:
              _currentKmController,
          label: 'Current KM',
          hint: 'e.g. 42500',
          icon:
              Icons.speed_rounded,
          keyboardType:
              TextInputType.number,
          validator: (value) {
            if (value == null ||
                value.trim().isEmpty) {
              return 'Current KM is required';
            }

            final km =
                int.tryParse(
              value.trim(),
            );

            if (km == null ||
                km < 0) {
              return 'Enter valid KM';
            }

            return null;
          },
        ),

        const SizedBox(
          height: 7,
        ),

        _helperText(
          'Update this whenever the vehicle odometer changes.',
        ),

        const SizedBox(
          height: 14,
        ),

        _buildTextField(
          controller:
              _descriptionController,
          label: 'Description',
          hint:
              'Short description of the vehicle',
          icon:
              Icons.notes_rounded,
          maxLines: 4,
        ),

        const SizedBox(
          height: 14,
        ),

        _buildTextField(
          controller:
              _featuresController,
          label: 'Features',
          hint:
              'AC, Bluetooth, Rear Camera',
          icon:
              Icons.auto_awesome_rounded,
          maxLines: 2,
        ),

        const SizedBox(
          height: 7,
        ),

        _helperText(
          'Separate multiple features with commas.',
        ),
      ],
    );
  }

  // ============================================================
  // PRICING
  // ============================================================

  Widget _buildPricingSection() {
    return _buildSection(
      title:
          'Vehicle Display Pricing',
      icon:
          Icons.payments_rounded,
      children: [
        _buildTextField(
          controller:
              _priceController,
          label:
              'Display Price / Day',
          hint: '2499',
          icon:
              Icons.currency_rupee_rounded,
          keyboardType:
              TextInputType.number,
          validator: (value) {
            if (value == null ||
                value.trim().isEmpty) {
              return 'Display price is required';
            }

            final parsed =
                int.tryParse(
              value.trim(),
            );

            if (parsed == null ||
                parsed < 0) {
              return 'Enter valid price';
            }

            return null;
          },
        ),

        const SizedBox(
          height: 8,
        ),

        _buildInfoBox(
          text:
              'This is the listing/display price. Booking calculations use the connected pricing profile.',
        ),
      ],
    );
  }

  // ============================================================
  // BRANCH
  // ============================================================

  Widget _buildBranchSection() {
    return _buildSection(
      title: 'Branch Assignment',
      icon:
          Icons.location_on_rounded,
      children: [
        _buildTextField(
          controller:
              _branchIdsController,
          label: 'Branch IDs',
          hint:
              'branch_001, branch_002',
          icon:
              Icons.store_rounded,
          maxLines: 2,
        ),

        const SizedBox(
          height: 7,
        ),

        _helperText(
          'Separate multiple branch IDs with commas.',
        ),
      ],
    );
  }

  // ============================================================
  // STATUS
  // ============================================================

  Widget _buildStatusSection() {
    return _buildSection(
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
                _isAvailable =
                    false;
              }
            });
          },
        ),

        const SizedBox(
          height: 8,
        ),

        _buildSwitchTile(
          title: 'Available',
          subtitle:
              'Vehicle can currently be booked',
          value: _isAvailable,
          enabled: _isActive,
          onChanged: (value) {
            setState(() {
              _isAvailable =
                  value;
            });
          },
        ),

        const SizedBox(
          height: 8,
        ),

        _buildSwitchTile(
          title: 'Featured Car',
          subtitle:
              'Show this vehicle in featured sections',
          value: _isFeatured,
          onChanged: (value) {
            setState(() {
              _isFeatured =
                  value;
            });
          },
        ),
      ],
    );
  }

  // ============================================================
  // SORT ORDER
  // ============================================================

  Widget _buildDisplayOrder() {
    return _buildSection(
      title: 'Display Order',
      icon:
          Icons.sort_rounded,
      children: [
        _buildTextField(
          controller:
              _sortOrderController,
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
                int.tryParse(
              value.trim(),
            );

            if (parsed == null ||
                parsed < 0) {
              return 'Enter valid number';
            }

            return null;
          },
        ),
      ],
    );
  }

  // ============================================================
  // PRICING CONNECTION
  // ============================================================

  Widget _buildPricingConnectionSection() {
    final profile =
        _selectedPricingProfile;

    return _buildSection(
      title:
          'Pricing Profile Connection',
      icon:
          Icons.link_rounded,
      children: [
        Text(
          'Connect this vehicle to an existing pricing profile.',
          style:
              GoogleFonts.manrope(
            color: body,
            fontSize: 12,
            fontWeight:
                FontWeight.w500,
          ),
        ),

        const SizedBox(
          height: 14,
        ),

        if (_loadingPricingProfiles)
          const Center(
            child:
                CircularProgressIndicator(
              color: primary,
            ),
          )
        else
          InkWell(
            onTap:
                _openPricingProfilePicker,
            borderRadius:
                BorderRadius.circular(
              16,
            ),
            child: Container(
              padding:
                  const EdgeInsets.all(
                15,
              ),
              decoration:
                  BoxDecoration(
                color: background,
                borderRadius:
                    BorderRadius.circular(
                  16,
                ),
                border:
                    Border.all(
                  color: profile == null
                      ? border
                      : primary,
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
                        12,
                      ),
                    ),
                    child: Icon(
                      profile == null
                          ? Icons
                              .price_change_outlined
                          : Icons
                              .check_circle_rounded,
                      color:
                          profile == null
                              ? muted
                              : primary,
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
                          profile == null
                              ? 'Select Pricing Profile'
                              : profile.name,
                          style:
                              GoogleFonts
                                  .manrope(
                            color:
                                heading,
                            fontSize:
                                14,
                            fontWeight:
                                FontWeight
                                    .w800,
                          ),
                        ),

                        const SizedBox(
                          height: 3,
                        ),

                        Text(
                          profile == null
                              ? 'Choose pricing for this vehicle'
                              : profile.id,
                          maxLines: 1,
                          overflow:
                              TextOverflow
                                  .ellipsis,
                          style:
                              GoogleFonts
                                  .manrope(
                            color:
                                body,
                            fontSize:
                                11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Icon(
                    Icons
                        .keyboard_arrow_down_rounded,
                    color: body,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ============================================================
  // SAVE BUTTON
  // ============================================================

  Widget _buildSaveButton() {
    return SafeArea(
      minimum:
          const EdgeInsets.fromLTRB(
        20,
        10,
        20,
        16,
      ),
      child: SizedBox(
        height: 56,
        child: ElevatedButton(
          onPressed:
              _isSaving
                  ? null
                  : _updateCar,
          style:
              ElevatedButton.styleFrom(
            backgroundColor:
                primary,
            disabledBackgroundColor:
                primary.withValues(
              alpha: 0.55,
            ),
            foregroundColor:
                Colors.white,
            elevation: 0,
            shape:
                RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(
                17,
              ),
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
                      MainAxisAlignment
                          .center,
                  children: [
                    const Icon(
                      Icons
                          .check_circle_outline_rounded,
                      size: 21,
                    ),
                    const SizedBox(
                      width: 9,
                    ),
                    Text(
                      'Save Car Changes',
                      style:
                          GoogleFonts
                              .manrope(
                        fontSize:
                            14,
                        fontWeight:
                            FontWeight
                                .w800,
                      ),
                    ),
                  ],
                ),
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
      padding:
          const EdgeInsets.all(18),

      decoration:
          BoxDecoration(
        color: card,
        borderRadius:
            BorderRadius.circular(
          22,
        ),
        border:
            Border.all(
          color: border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withValues(
              alpha: 0.025,
            ),
            blurRadius: 18,
            offset:
                const Offset(0, 7),
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

              Text(
                title,
                style:
                    GoogleFonts.manrope(
                  color: heading,
                  fontSize: 16,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 17,
          ),

          ...children,
        ],
      ),
    );
  }

  // ============================================================
  // TEXT FIELD
  // ============================================================

  Widget _buildTextField({
    required TextEditingController
        controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    TextCapitalization
        textCapitalization =
        TextCapitalization.none,
    int maxLines = 1,
    String? Function(String?)?
        validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType:
          keyboardType,
      textCapitalization:
          textCapitalization,
      maxLines: maxLines,
      validator: validator,

      style:
          GoogleFonts.manrope(
        color: heading,
        fontSize: 13,
        fontWeight:
            FontWeight.w600,
      ),

      decoration:
          InputDecoration(
        labelText: label,
        hintText: hint,

        labelStyle:
            GoogleFonts.manrope(
          color: body,
          fontSize: 12,
          fontWeight:
              FontWeight.w600,
        ),

        hintStyle:
            GoogleFonts.manrope(
          color: muted,
          fontSize: 12,
        ),

        prefixIcon: Icon(
          icon,
          color: primary,
          size: 20,
        ),

        filled: true,
        fillColor: background,

        border:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            15,
          ),
          borderSide:
              const BorderSide(
            color: border,
          ),
        ),

        enabledBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            15,
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
            15,
          ),
          borderSide:
              const BorderSide(
            color: primary,
            width: 1.3,
          ),
        ),

        errorBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            15,
          ),
          borderSide:
              const BorderSide(
            color: Colors.redAccent,
          ),
        ),

        focusedErrorBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            15,
          ),
          borderSide:
              const BorderSide(
            color: Colors.redAccent,
            width: 1.3,
          ),
        ),

        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 15,
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
    required ValueChanged<T?>
        onChanged,
    String Function(T)?
        itemLabel,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,

      decoration:
          InputDecoration(
        labelText: label,

        prefixIcon: Icon(
          icon,
          color: primary,
          size: 20,
        ),

        filled: true,
        fillColor: background,

        border:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            15,
          ),
          borderSide:
              const BorderSide(
            color: border,
          ),
        ),

        enabledBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            15,
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
            15,
          ),
          borderSide:
              const BorderSide(
            color: primary,
            width: 1.3,
          ),
        ),
      ),

      items: items
          .map(
            (item) =>
                DropdownMenuItem<T>(
              value: item,
              child: Text(
                itemLabel
                        ?.call(item) ??
                    item.toString(),
                overflow:
                    TextOverflow.ellipsis,
                style:
                    GoogleFonts.manrope(
                  color: heading,
                  fontSize: 12,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ),
          )
          .toList(),

      onChanged: onChanged,
    );
  }

  // ============================================================
  // SWITCH
  // ============================================================

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>
        onChanged,
    bool enabled = true,
  }) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 11,
      ),
      decoration:
          BoxDecoration(
        color: background,
        borderRadius:
            BorderRadius.circular(
          15,
        ),
        border:
            Border.all(
          color: border,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  title,
                  style:
                      GoogleFonts.manrope(
                    color: enabled
                        ? heading
                        : muted,
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  subtitle,
                  style:
                      GoogleFonts.manrope(
                    color: muted,
                    fontSize: 10.5,
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
                enabled
                    ? onChanged
                    : null,
            activeColor:
                primary,
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
      padding:
          const EdgeInsets.all(12),
      decoration:
          BoxDecoration(
        color: softAccent,
        borderRadius:
            BorderRadius.circular(
          13,
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: primary,
            size: 17,
          ),
          const SizedBox(
            width: 8,
          ),
          Expanded(
            child: Text(
              text,
              style:
                  GoogleFonts.manrope(
                color: body,
                fontSize: 10.5,
                height: 1.4,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HELPER TEXT
  // ============================================================

  Widget _helperText(
    String text,
  ) {
    return Text(
      text,
      style:
          GoogleFonts.manrope(
        color: muted,
        fontSize: 10.5,
        fontWeight:
            FontWeight.w500,
      ),
    );
  }

  // ============================================================
  // SUCCESS
  // ============================================================

  void _showSuccess(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        behavior:
            SnackBarBehavior.floating,
        backgroundColor:
            primary,
        margin:
            const EdgeInsets.all(16),
        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(
            14,
          ),
        ),
        content: Row(
          children: [
            const Icon(
              Icons
                  .check_circle_rounded,
              color: Colors.white,
            ),
            const SizedBox(
              width: 10,
            ),
            Expanded(
              child: Text(
                message,
                style:
                    GoogleFonts.manrope(
                  color:
                      Colors.white,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  void _showError(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        behavior:
            SnackBarBehavior.floating,
        backgroundColor:
            Colors.red.shade700,
        margin:
            const EdgeInsets.all(16),
        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(
            14,
          ),
        ),
        content: Row(
          children: [
            const Icon(
              Icons
                  .error_outline_rounded,
              color: Colors.white,
            ),
            const SizedBox(
              width: 10,
            ),
            Expanded(
              child: Text(
                message,
                style:
                    GoogleFonts.manrope(
                  color:
                      Colors.white,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// PRICING PROFILE PICKER
// ============================================================================

class _PricingProfilePickerSheet
    extends StatefulWidget {
  final List<PricingProfile> profiles;
  final String? selectedProfileId;
  final TextEditingController
      searchController;

  const _PricingProfilePickerSheet({
    required this.profiles,
    required this.selectedProfileId,
    required this.searchController,
  });

  @override
  State<_PricingProfilePickerSheet>
      createState() =>
          _PricingProfilePickerSheetState();
}

class _PricingProfilePickerSheetState
    extends State<
        _PricingProfilePickerSheet> {
  String _query = '';

  @override
  void initState() {
    super.initState();

    widget.searchController
        .addListener(
      _onSearchChanged,
    );
  }

  @override
  void dispose() {
    widget.searchController
        .removeListener(
      _onSearchChanged,
    );

    super.dispose();
  }

  void _onSearchChanged() {
    if (!mounted) return;

    setState(() {
      _query = widget
          .searchController.text
          .trim()
          .toLowerCase();
    });
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final filtered =
        widget.profiles.where(
      (profile) {
        if (_query.isEmpty) {
          return true;
        }

        return profile.name
                .toLowerCase()
                .contains(_query) ||
            profile.id
                .toLowerCase()
                .contains(_query);
      },
    ).toList();

    return SafeArea(
      child: Container(
        height:
            MediaQuery.of(context)
                    .size
                    .height *
                0.82,
        decoration:
            const BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.vertical(
            top: Radius.circular(26),
          ),
        ),
        child: Column(
          children: [
            const SizedBox(
              height: 12,
            ),

            Container(
              width: 42,
              height: 4,
              decoration:
                  BoxDecoration(
                color: const Color(
                  0xFFE5EBE9,
                ),
                borderRadius:
                    BorderRadius.circular(
                  20,
                ),
              ),
            ),

            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                20,
                20,
                20,
                12,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Pricing Profile',
                    style:
                        GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.w800,
                      color:
                          const Color(
                        0xFF17201F,
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 4,
                  ),

                  Text(
                    'Choose the pricing configuration for this car.',
                    style:
                        GoogleFonts.manrope(
                      fontSize: 11,
                      color:
                          const Color(
                        0xFF66706E,
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 14,
                  ),

                  TextField(
                    controller:
                        widget
                            .searchController,
                    decoration:
                        InputDecoration(
                      hintText:
                          'Search pricing profile...',
                      prefixIcon:
                          const Icon(
                        Icons.search_rounded,
                      ),
                      filled: true,
                      fillColor:
                          const Color(
                        0xFFF8FAF9,
                      ),
                      border:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius
                                .circular(
                          14,
                        ),
                        borderSide:
                            BorderSide
                                .none,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child:
                  filtered.isEmpty
                      ? Center(
                          child: Text(
                            'No pricing profiles found.',
                            style:
                                GoogleFonts
                                    .manrope(
                              color:
                                  const Color(
                                0xFF66706E,
                              ),
                              fontWeight:
                                  FontWeight
                                      .w600,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding:
                              const EdgeInsets
                                  .fromLTRB(
                            20,
                            4,
                            20,
                            20,
                          ),
                          itemCount:
                              filtered.length,
                          separatorBuilder:
                              (_, __) =>
                                  const SizedBox(
                            height: 8,
                          ),
                          itemBuilder:
                              (context,
                                  index) {
                            final profile =
                                filtered[
                                    index];

                            final selected =
                                profile.id ==
                                    widget
                                        .selectedProfileId;

                            return InkWell(
                              onTap: () {
                                Navigator.pop(
                                  context,
                                  profile,
                                );
                              },
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                16,
                              ),
                              child:
                                  Container(
                                padding:
                                    const EdgeInsets
                                        .all(
                                  15,
                                ),
                                decoration:
                                    BoxDecoration(
                                  color:
                                      selected
                                          ? const Color(
                                              0xFFE6FFFB,
                                            )
                                          : const Color(
                                              0xFFF8FAF9,
                                            ),
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    16,
                                  ),
                                  border:
                                      Border.all(
                                    color:
                                        selected
                                            ? const Color(
                                                0xFF0F766E,
                                              )
                                            : const Color(
                                                0xFFE5EBE9,
                                              ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width:
                                          42,
                                      height:
                                          42,
                                      decoration:
                                          BoxDecoration(
                                        color:
                                            selected
                                                ? const Color(
                                                    0xFF0F766E,
                                                  )
                                                : Colors
                                                    .white,
                                        borderRadius:
                                            BorderRadius
                                                .circular(
                                          12,
                                        ),
                                      ),
                                      child:
                                          Icon(
                                        selected
                                            ? Icons
                                                .check_rounded
                                            : Icons
                                                .payments_outlined,
                                        color:
                                            selected
                                                ? Colors
                                                    .white
                                                : const Color(
                                                    0xFF0F766E,
                                                  ),
                                      ),
                                    ),

                                    const SizedBox(
                                      width:
                                          11,
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
                                                .name,
                                            maxLines:
                                                1,
                                            overflow:
                                                TextOverflow
                                                    .ellipsis,
                                            style:
                                                GoogleFonts
                                                    .manrope(
                                              color:
                                                  const Color(
                                                0xFF17201F,
                                              ),
                                              fontSize:
                                                  13,
                                              fontWeight:
                                                  FontWeight
                                                      .w800,
                                            ),
                                          ),
                                          const SizedBox(
                                            height:
                                                3,
                                          ),
                                          Text(
                                            profile
                                                .id,
                                            maxLines:
                                                1,
                                            overflow:
                                                TextOverflow
                                                    .ellipsis,
                                            style:
                                                GoogleFonts
                                                    .manrope(
                                              color:
                                                  const Color(
                                                0xFF0F766E,
                                              ),
                                              fontSize:
                                                  10,
                                              fontWeight: FontWeight.w700
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    if (selected)
                                      const Icon(
                                        Icons
                                            .check_circle_rounded,
                                        color:
                                            Color(
                                          0xFF0F766E,
                                        ),
                                      ),
                                  ],
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
}