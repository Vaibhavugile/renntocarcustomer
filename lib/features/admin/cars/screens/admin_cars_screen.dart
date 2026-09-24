import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/config/app_config.dart';
import '../../../cars/models/car.dart';
import '../../../cars/services/car_service.dart';
import 'admin_add_car_screen.dart';
import 'admin_edit_car_screen.dart';

class AdminCarsScreen extends StatefulWidget {
  const AdminCarsScreen({
    super.key,
  });

  @override
  State<AdminCarsScreen> createState() =>
      _AdminCarsScreenState();
}

class _AdminCarsScreenState
    extends State<AdminCarsScreen> {
  // ============================================================
  // COLORS
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
  // SERVICES
  // ============================================================

  final CarService _carService =
      CarService.instance;

  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController _searchController =
      TextEditingController();

  // ============================================================
  // STATE
  // ============================================================

  List<Car> _cars = [];

  bool _loading = true;

  String _searchQuery = '';

  // ============================================================
  // TENANT
  // ============================================================

  String get _tenantId {
    return AppConfig.tenant.tenantId;
  }

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _loadCars();

    _searchController.addListener(() {
      if (!mounted) return;

      setState(() {
        _searchQuery = _searchController.text
            .trim()
            .toLowerCase();
      });
    });
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD CARS
  // ============================================================

  Future<void> _loadCars() async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    try {
      final cars =
          await _carService.getAllCars(
        tenantId: _tenantId,
      );

      if (!mounted) return;

      setState(() {
        _cars = cars;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
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
  // FILTERED CARS
  // ============================================================

  List<Car> get _filteredCars {
    if (_searchQuery.isEmpty) {
      return _cars;
    }

    return _cars.where((car) {
      final name =
          car.name.toLowerCase();

      final type =
          car.type.toLowerCase();

      final fuel =
          car.fuel.toLowerCase();

      final transmission =
          car.transmission.toLowerCase();

      final registration =
          car.registrationNumber
              .toLowerCase();

      final status =
          car.status.toLowerCase();

      return name.contains(_searchQuery) ||
          type.contains(_searchQuery) ||
          fuel.contains(_searchQuery) ||
          transmission.contains(
            _searchQuery,
          ) ||
          registration.contains(
            _searchQuery,
          ) ||
          status.contains(_searchQuery);
    }).toList();
  }

  // ============================================================
  // STATISTICS
  // ============================================================

  int get _activeCount {
    return _cars
        .where((car) => car.isActive)
        .length;
  }

  int get _availableCount {
    return _cars
        .where(
          (car) =>
              car.isActive &&
              car.isAvailable,
        )
        .length;
  }

  int get _inactiveCount {
    return _cars
        .where((car) => !car.isActive)
        .length;
  }

  int get _featuredCount {
    return _cars
        .where(
          (car) =>
              car.isActive &&
              car.isFeatured,
        )
        .length;
  }

  // ============================================================
  // ERROR
  // ============================================================

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w600,
          ),
        ),
        behavior:
            SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ============================================================
  // ADD CAR
  // ============================================================

  Future<void> _addCar() async {
    final result =
        await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const AdminAddCarScreen(),
      ),
    );

    if (result == true && mounted) {
      await _loadCars();
    }
  }

  // ============================================================
  // EDIT CAR
  // ============================================================

  Future<void> _editCar(Car car) async {
    final result =
        await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AdminEditCarScreen(
          car: car,
        ),
      ),
    );

    if (result == true && mounted) {
      await _loadCars();
    }
  }

  // ============================================================
  // DEACTIVATE
  // ============================================================

  Future<void> _deactivateCar(
    Car car,
  ) async {
    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: card,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(20),
          ),
          title: Text(
            'Deactivate vehicle?',
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w800,
              color: heading,
            ),
          ),
          content: Text(
            '${car.name} will no longer be '
            'available to customers.',
            style: GoogleFonts.manrope(
              color: body,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: Text(
                'Cancel',
                style: GoogleFonts.manrope(
                  color: body,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              style:
                  ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor:
                    Colors.white,
                elevation: 0,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
              ),
              child: Text(
                'Deactivate',
                style: GoogleFonts.manrope(
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _carService.deactivateCar(
        tenantId: _tenantId,
        carId: car.id,
      );

      await _loadCars();
    } catch (e) {
      if (!mounted) return;

      _showError(
        e.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
    }
  }

  // ============================================================
  // ACTIVATE
  // ============================================================

  Future<void> _activateCar(
    Car car,
  ) async {
    try {
      await _carService.activateCar(
        tenantId: _tenantId,
        carId: car.id,
      );

      await _loadCars();
    } catch (e) {
      if (!mounted) return;

      _showError(
        e.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
    }
  }

  // ============================================================
  // FORMAT KM
  // ============================================================

  String _formatKm(int value) {
    if (value <= 0) {
      return '0';
    }

    final text = value.toString();

    final chars =
        text.split('').reversed.toList();

    final output = <String>[];

    for (int i = 0;
        i < chars.length;
        i++) {
      output.add(chars[i]);

      if (i == 2 &&
          i != chars.length - 1) {
        output.add(',');
      } else if (i > 2 &&
          (i - 2) % 2 == 0 &&
          i != chars.length - 1) {
        output.add(',');
      }
    }

    return output
        .reversed
        .join();
  }

  // ============================================================
  // FORMAT PRICE
  // ============================================================

  String _formatPrice(int value) {
    return '₹${_formatNumber(value)}';
  }

  String _formatNumber(int value) {
    if (value == 0) {
      return '0';
    }

    final text = value.abs().toString();

    final chars =
        text.split('').reversed.toList();

    final output = <String>[];

    for (int i = 0;
        i < chars.length;
        i++) {
      output.add(chars[i]);

      if (i == 2 &&
          i != chars.length - 1) {
        output.add(',');
      } else if (i > 2 &&
          (i - 2) % 2 == 0 &&
          i != chars.length - 1) {
        output.add(',');
      }
    }

    final result =
        output.reversed.join();

    return value < 0
        ? '-$result'
        : result;
  }

  // ============================================================
  // VEHICLE SUBTITLE
  // ============================================================

  String _vehicleSubtitle(
    Car car,
  ) {
    final parts = <String>[];

    if (car.type.trim().isNotEmpty) {
      parts.add(car.type.trim());
    }

    if (car.fuel.trim().isNotEmpty) {
      parts.add(car.fuel.trim());
    }

    if (car.transmission
        .trim()
        .isNotEmpty) {
      parts.add(
        car.transmission.trim(),
      );
    }

    return parts.isEmpty
        ? 'Vehicle'
        : parts.join(' • ');
  }

  // ============================================================
  // STATUS TEXT
  // ============================================================

  String _statusText(Car car) {
    if (!car.isActive) {
      return 'Inactive';
    }

    if (!car.isAvailable) {
      final status =
          car.status.trim();

      if (status.isNotEmpty) {
        return _capitalize(
          status.replaceAll(
            '_',
            ' ',
          ),
        );
      }

      return 'Unavailable';
    }

    return 'Available';
  }

  String _capitalize(String value) {
    if (value.isEmpty) {
      return value;
    }

    return value[0].toUpperCase() +
        value.substring(1);
  }

  // ============================================================
  // STATUS COLOR
  // ============================================================

  Color _statusColor(Car car) {
    if (!car.isActive) {
      return const Color(
        0xFF64748B,
      );
    }

    if (!car.isAvailable) {
      return const Color(
        0xFFF59E0B,
      );
    }

    return const Color(
      0xFF16A34A,
    );
  }

  // ============================================================
  // SHOW ACTIONS
  // ============================================================

  void _showCarActions(
    Car car,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: card,
      isScrollControlled: true,
      shape:
          const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.fromLTRB(
              20,
              14,
              20,
              24,
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Container(
                  width: 44,
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
                const SizedBox(
                  height: 20,
                ),

                Row(
                  children: [
                    _smallCarThumbnail(
                      car,
                    ),
                    const SizedBox(
                      width: 12,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Text(
                            car.name,
                            maxLines: 1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style:
                                GoogleFonts
                                    .manrope(
                              fontSize: 17,
                              fontWeight:
                                  FontWeight
                                      .w800,
                              color: heading,
                            ),
                          ),
                          const SizedBox(
                            height: 3,
                          ),
                          Text(
                            _vehicleSubtitle(
                              car,
                            ),
                            style:
                                GoogleFonts
                                    .manrope(
                              fontSize: 11,
                              fontWeight:
                                  FontWeight
                                      .w600,
                              color: body,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 18,
                ),

                _actionTile(
                  icon:
                      Icons.edit_outlined,
                  title: 'Edit vehicle',
                  subtitle:
                      'Update details, photos and pricing',
                  onTap: () async {
                    Navigator.pop(
                      sheetContext,
                    );

                    await _editCar(car);
                  },
                ),

                _actionTile(
                  icon:
                      Icons.photo_library_outlined,
                  title: 'View photos',
                  subtitle:
                      '${_imageCount(car)} photos',
                  onTap: () {
                    Navigator.pop(
                      sheetContext,
                    );

                    _showGallery(car);
                  },
                ),

                _actionTile(
                  icon: car.isActive
                      ? Icons
                          .visibility_off_outlined
                      : Icons
                          .visibility_outlined,
                  title: car.isActive
                      ? 'Deactivate vehicle'
                      : 'Activate vehicle',
                  subtitle: car.isActive
                      ? 'Hide this vehicle from customers'
                      : 'Make this vehicle active again',
                  onTap: () async {
                    Navigator.pop(
                      sheetContext,
                    );

                    if (car.isActive) {
                      await _deactivateCar(
                        car,
                      );
                    } else {
                      await _activateCar(
                        car,
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // ACTION TILE
  // ============================================================

  Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding:
          const EdgeInsets.symmetric(
        vertical: 4,
      ),
      leading: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: softAccent,
          borderRadius:
              BorderRadius.circular(14),
        ),
        child: Icon(
          icon,
          color: primary,
          size: 21,
        ),
      ),
      title: Text(
        title,
        style: GoogleFonts.manrope(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: heading,
        ),
      ),
      subtitle: Padding(
        padding:
            const EdgeInsets.only(
          top: 2,
        ),
        child: Text(
          subtitle,
          style: GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: muted,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // IMAGE COUNT
  // ============================================================

  int _imageCount(Car car) {
    final images =
        <String>{};

    if (car.image
        .trim()
        .isNotEmpty) {
      images.add(
        car.image.trim(),
      );
    }

    for (final image
        in car.images) {
      if (image
          .trim()
          .isNotEmpty) {
        images.add(
          image.trim(),
        );
      }
    }

    return images.length;
  }

  // ============================================================
  // ALL IMAGES
  // ============================================================

  List<String> _allImages(Car car) {
    final images =
        <String>[];

    if (car.image
        .trim()
        .isNotEmpty) {
      images.add(
        car.image.trim(),
      );
    }

    for (final image
        in car.images) {
      final value =
          image.trim();

      if (value.isNotEmpty &&
          !images.contains(value)) {
        images.add(value);
      }
    }

    return images;
  }

  // ============================================================
  // GALLERY
  // ============================================================

  void _showGallery(Car car) {
    final images =
        _allImages(car);

    if (images.isEmpty) {
      showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: card,
            shape:
                RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(
                20,
              ),
            ),
            title: Text(
              'No photos',
              style:
                  GoogleFonts.manrope(
                fontWeight:
                    FontWeight.w800,
                color: heading,
              ),
            ),
            content: Text(
              'No photos have been added '
              'for this vehicle yet.',
              style:
                  GoogleFonts.manrope(
                color: body,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(
                    context,
                  );
                },
                child: Text(
                  'Close',
                  style:
                      GoogleFonts.manrope(
                    fontWeight:
                        FontWeight.w700,
                    color: primary,
                  ),
                ),
              ),
            ],
          );
        },
      );

      return;
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor:
              Colors.transparent,
          insetPadding:
              const EdgeInsets.all(
            18,
          ),
          child: Container(
            constraints:
                const BoxConstraints(
              maxWidth: 600,
              maxHeight: 700,
            ),
            decoration:
                BoxDecoration(
              color: card,
              borderRadius:
                  BorderRadius.circular(
                24,
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets
                          .fromLTRB(
                    18,
                    16,
                    10,
                    12,
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
                              car.name,
                              style:
                                  GoogleFonts
                                      .manrope(
                                fontSize: 18,
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
                              '${images.length} photos',
                              style:
                                  GoogleFonts
                                      .manrope(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color:
                                    muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.pop(
                            dialogContext,
                          );
                        },
                        icon: const Icon(
                          Icons
                              .close_rounded,
                          color: heading,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(
                  height: 1,
                  color: border,
                ),
                Expanded(
                  child: GridView.builder(
                    padding:
                        const EdgeInsets.all(
                      16,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio:
                          1.25,
                    ),
                    itemCount:
                        images.length,
                    itemBuilder:
                        (context, index) {
                      return ClipRRect(
                        borderRadius:
                            BorderRadius
                                .circular(
                          16,
                        ),
                        child:
                            Image.network(
                          images[index],
                          fit: BoxFit.cover,
                          errorBuilder:
                              (
                            _,
                            __,
                            ___,
                          ) {
                            return Container(
                              color:
                                  softAccent,
                              child:
                                  const Icon(
                                Icons
                                    .broken_image_outlined,
                                color:
                                    primary,
                                size: 32,
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // SMALL THUMBNAIL
  // ============================================================

  Widget _smallCarThumbnail(
    Car car,
  ) {
    final image =
        car.image.trim();

    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: softAccent,
        borderRadius:
            BorderRadius.circular(14),
      ),
      clipBehavior:
          Clip.antiAlias,
      child: image.isEmpty
          ? const Icon(
              Icons
                  .directions_car_rounded,
              color: primary,
            )
          : Image.network(
              image,
              fit: BoxFit.cover,
              errorBuilder:
                  (_, __, ___) {
                return const Icon(
                  Icons
                      .directions_car_rounded,
                  color: primary,
                );
              },
            ),
    );
  }

  // ============================================================
  // MAIN IMAGE
  // ============================================================

  Widget _buildCarImage(
    Car car,
  ) {
    final image =
        car.image.trim();

    final imageCount =
        _imageCount(car);

    return Stack(
      children: [
        Container(
          width: 118,
          height: 94,
          decoration:
              BoxDecoration(
            color: softAccent,
            borderRadius:
                BorderRadius.circular(
              17,
            ),
          ),
          clipBehavior:
              Clip.antiAlias,
          child: image.isEmpty
              ? const Icon(
                  Icons
                      .directions_car_rounded,
                  color: primary,
                  size: 40,
                )
              : Image.network(
                  image,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (_, __, ___) {
                    return const Icon(
                      Icons
                          .directions_car_rounded,
                      color: primary,
                      size: 40,
                    );
                  },
                ),
        ),

        if (imageCount > 1)
          Positioned(
            right: 7,
            bottom: 7,
            child: Container(
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 7,
                vertical: 5,
              ),
              decoration:
                  BoxDecoration(
                color: Colors.black
                    .withOpacity(
                  0.68,
                ),
                borderRadius:
                    BorderRadius.circular(
                  10,
                ),
              ),
              child: Row(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  const Icon(
                    Icons
                        .photo_library_rounded,
                    color: Colors.white,
                    size: 12,
                  ),
                  const SizedBox(
                    width: 4,
                  ),
                  Text(
                    imageCount
                        .toString(),
                    style:
                        GoogleFonts.manrope(
                      color:
                          Colors.white,
                      fontSize: 10,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),

        if (car.isFeatured)
          Positioned(
            left: 7,
            top: 7,
            child: Container(
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 7,
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
              child: const Icon(
                Icons.star_rounded,
                color: Colors.white,
                size: 12,
              ),
            ),
          ),
      ],
    );
  }

  // ============================================================
  // STATUS BADGE
  // ============================================================

  Widget _statusBadge(
    Car car,
  ) {
    final color =
        _statusColor(car);

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration:
          BoxDecoration(
        color: color.withOpacity(
          0.10,
        ),
        borderRadius:
            BorderRadius.circular(
          10,
        ),
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration:
                BoxDecoration(
              color: color,
              shape:
                  BoxShape.circle,
            ),
          ),
          const SizedBox(
            width: 5,
          ),
          Text(
            _statusText(car),
            style:
                GoogleFonts.manrope(
              fontSize: 10,
              fontWeight:
                  FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SPEC
  // ============================================================

  Widget _spec({
    required IconData icon,
    required String text,
  }) {
    return Row(
      mainAxisSize:
          MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: muted,
        ),
        const SizedBox(
          width: 4,
        ),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style:
                GoogleFonts.manrope(
              fontSize: 10.5,
              fontWeight:
                  FontWeight.w700,
              color: body,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // CAR CARD
  // ============================================================

  Widget _buildCarCard(
    Car car,
  ) {
    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),
      decoration:
          BoxDecoration(
        color: card,
        borderRadius:
            BorderRadius.circular(
          22,
        ),
        border: Border.all(
          color: border,
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 22,
            offset:
                const Offset(0, 7),
            color: Colors.black
                .withOpacity(
              0.035,
            ),
          ),
        ],
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(
          14,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    _showGallery(car);
                  },
                  child:
                      _buildCarImage(car),
                ),

                const SizedBox(
                  width: 14,
                ),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              car.name,
                              maxLines: 1,
                              overflow:
                                  TextOverflow
                                      .ellipsis,
                              style:
                                  GoogleFonts
                                      .manrope(
                                fontSize: 16,
                                fontWeight:
                                    FontWeight
                                        .w800,
                                color:
                                    heading,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              _showCarActions(
                                car,
                              );
                            },
                            padding:
                                EdgeInsets.zero,
                            constraints:
                                const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                            icon:
                                const Icon(
                              Icons
                                  .more_horiz_rounded,
                              color: muted,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(
                        height: 2,
                      ),

                      Text(
                        _vehicleSubtitle(
                          car,
                        ),
                        maxLines: 1,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style:
                            GoogleFonts.manrope(
                          fontSize: 11.5,
                          fontWeight:
                              FontWeight.w600,
                          color: body,
                        ),
                      ),

                      if (car
                          .registrationNumber
                          .trim()
                          .isNotEmpty) ...[
                        const SizedBox(
                          height: 4,
                        ),
                        Text(
                          car
                              .registrationNumber,
                          style:
                              GoogleFonts
                                  .manrope(
                            fontSize: 10.5,
                            fontWeight:
                                FontWeight.w700,
                            color: muted,
                          ),
                        ),
                      ],

                      const SizedBox(
                        height: 9,
                      ),

                      Row(
                        children: [
                          _statusBadge(
                            car,
                          ),
                          const Spacer(),
                          if (car
                              .isFeatured)
                            Row(
                              mainAxisSize:
                                  MainAxisSize
                                      .min,
                              children: [
                                const Icon(
                                  Icons
                                      .star_rounded,
                                  size: 14,
                                  color:
                                      Color(
                                    0xFFF59E0B,
                                  ),
                                ),
                                const SizedBox(
                                  width: 3,
                                ),
                                Text(
                                  'Featured',
                                  style:
                                      GoogleFonts
                                          .manrope(
                                    fontSize:
                                        10,
                                    fontWeight:
                                        FontWeight
                                            .w800,
                                    color:
                                        Color(
                                      0xFFF59E0B,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 14,
            ),

            Container(
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              decoration:
                  BoxDecoration(
                color: background,
                borderRadius:
                    BorderRadius.circular(
                  14,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _spec(
                      icon:
                          Icons.speed_rounded,
                      text:
                          '${_formatKm(car.currentKm)} km',
                    ),
                  ),
                  Expanded(
                    child: _spec(
                      icon:
                          Icons.event_seat_outlined,
                      text:
                          '${car.seats} Seats',
                    ),
                  ),
                  Expanded(
                    child: _spec(
                      icon:
                          Icons.local_gas_station_outlined,
                      text:
                          car.fuel.isEmpty
                              ? 'Fuel'
                              : car.fuel,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Text(
                        'Daily rental',
                        style:
                            GoogleFonts
                                .manrope(
                          fontSize: 10,
                          fontWeight:
                              FontWeight
                                  .w600,
                          color: muted,
                        ),
                      ),
                      const SizedBox(
                        height: 2,
                      ),
                      Text(
                        _formatPrice(
                          car.pricePerDay,
                        ),
                        style:
                            GoogleFonts
                                .manrope(
                          fontSize: 16,
                          fontWeight:
                              FontWeight
                                  .w800,
                          color: heading,
                        ),
                      ),
                      Text(
                        '/ day',
                        style:
                            GoogleFonts
                                .manrope(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ),

                OutlinedButton.icon(
                  onPressed: () {
                    _editCar(car);
                  },
                  style:
                      OutlinedButton
                          .styleFrom(
                    foregroundColor:
                        primary,
                    side:
                        const BorderSide(
                      color: border,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius
                              .circular(
                        12,
                      ),
                    ),
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                  ),
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 15,
                  ),
                  label: Text(
                    'Edit',
                    style:
                        GoogleFonts
                            .manrope(
                      fontSize: 11,
                      fontWeight:
                          FontWeight
                              .w800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'Your fleet',
                style:
                    GoogleFonts.manrope(
                  fontSize: 28,
                  fontWeight:
                      FontWeight.w800,
                  color: heading,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(
                height: 5,
              ),
              Text(
                'Manage vehicles, photos, '
                'availability and fleet status.',
                style:
                    GoogleFonts.manrope(
                  fontSize: 12.5,
                  fontWeight:
                      FontWeight.w500,
                  color: body,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SEARCH
  // ============================================================

  Widget _buildSearch() {
    return Container(
      decoration:
          BoxDecoration(
        color: card,
        borderRadius:
            BorderRadius.circular(
          16,
        ),
        border: Border.all(
          color: border,
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset:
                const Offset(0, 6),
            color: Colors.black
                .withOpacity(
              0.035,
            ),
          ),
        ],
      ),
      child: TextField(
        controller:
            _searchController,
        textInputAction:
            TextInputAction.search,
        style:
            GoogleFonts.manrope(
          fontSize: 14,
          color: heading,
          fontWeight:
              FontWeight.w600,
        ),
        decoration:
            InputDecoration(
          hintText:
              'Search by car, type, registration or fuel...',
          hintStyle:
              GoogleFonts.manrope(
            fontSize: 12.5,
            color: muted,
            fontWeight:
                FontWeight.w500,
          ),
          prefixIcon:
              const Icon(
            Icons.search_rounded,
            color: muted,
          ),
          suffixIcon:
              _searchQuery.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        _searchController
                            .clear();
                      },
                      icon:
                          const Icon(
                        Icons
                            .close_rounded,
                        color: muted,
                      ),
                    )
                  : null,
          border:
              InputBorder.none,
          contentPadding:
              const EdgeInsets
                  .symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // STATS
  // ============================================================

  Widget _buildStats() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _statCard(
                icon: Icons
                    .directions_car_filled_rounded,
                label: 'Total',
                value:
                    _cars.length.toString(),
              ),
            ),
            const SizedBox(
              width: 10,
            ),
            Expanded(
              child: _statCard(
                icon: Icons
                    .check_circle_outline_rounded,
                label: 'Available',
                value:
                    _availableCount
                        .toString(),
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
              child: _statCard(
                icon: Icons
                    .star_outline_rounded,
                label: 'Featured',
                value:
                    _featuredCount
                        .toString(),
              ),
            ),
            const SizedBox(
              width: 10,
            ),
            Expanded(
              child: _statCard(
                icon: Icons
                    .pause_circle_outline_rounded,
                label: 'Inactive',
                value:
                    _inactiveCount
                        .toString(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // STAT CARD
  // ============================================================

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding:
          const EdgeInsets.all(
        14,
      ),
      decoration:
          BoxDecoration(
        color: card,
        borderRadius:
            BorderRadius.circular(
          16,
        ),
        border: Border.all(
          color: border,
        ),
      ),
      child: Row(
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
              size: 19,
            ),
          ),
          const SizedBox(
            width: 10,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  value,
                  style:
                      GoogleFonts.manrope(
                    fontSize: 19,
                    fontWeight:
                        FontWeight.w800,
                    color: heading,
                  ),
                ),
                const SizedBox(
                  height: 1,
                ),
                Text(
                  label,
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
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SECTION HEADER
  // ============================================================

  Widget _buildSectionHeader() {
    return Row(
      mainAxisAlignment:
          MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'All vehicles',
          style:
              GoogleFonts.manrope(
            fontSize: 17,
            fontWeight:
                FontWeight.w800,
            color: heading,
          ),
        ),
        Text(
          '${_filteredCars.length} vehicles',
          style:
              GoogleFonts.manrope(
            fontSize: 11,
            fontWeight:
                FontWeight.w600,
            color: muted,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // LOADING
  // ============================================================

  Widget _buildLoading() {
    return Container(
      height: 220,
      alignment:
          Alignment.center,
      child:
          const CircularProgressIndicator(
        color: primary,
        strokeWidth: 2.5,
      ),
    );
  }

  // ============================================================
  // EMPTY
  // ============================================================

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(
        28,
      ),
      decoration:
          BoxDecoration(
        color: card,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        border: Border.all(
          color: border,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration:
                const BoxDecoration(
              color: softAccent,
              shape: BoxShape.circle,
            ),
            child:
                const Icon(
              Icons
                  .directions_car_outlined,
              color: primary,
              size: 30,
            ),
          ),
          const SizedBox(
            height: 16,
          ),
          Text(
            _searchQuery.isEmpty
                ? 'No vehicles yet'
                : 'No vehicles found',
            style:
                GoogleFonts.manrope(
              fontSize: 16,
              fontWeight:
                  FontWeight.w800,
              color: heading,
            ),
          ),
          const SizedBox(
            height: 6,
          ),
          Text(
            _searchQuery.isEmpty
                ? 'Add your first vehicle '
                    'to start building the fleet.'
                : 'Try a different search term.',
            textAlign:
                TextAlign.center,
            style:
                GoogleFonts.manrope(
              fontSize: 12,
              height: 1.5,
              color: body,
            ),
          ),
          if (_searchQuery.isEmpty) ...[
            const SizedBox(
              height: 18,
            ),
            ElevatedButton.icon(
              onPressed: _addCar,
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    primary,
                foregroundColor:
                    Colors.white,
                elevation: 0,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
              ),
              icon: const Icon(
                Icons.add_rounded,
              ),
              label: Text(
                'Add Car',
                style:
                    GoogleFonts.manrope(
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
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
        elevation: 0,
        scrolledUnderElevation:
            0,

        leading:
            IconButton(
          icon:
              const Icon(
            Icons
                .arrow_back_ios_new_rounded,
            size: 19,
          ),
          color: heading,
          onPressed: () {
            Navigator.pop(
              context,
            );
          },
        ),

        title: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              'Cars',
              style:
                  GoogleFonts.manrope(
                fontSize: 20,
                fontWeight:
                    FontWeight.w800,
                color: heading,
              ),
            ),
            Text(
              'Fleet management',
              style:
                  GoogleFonts.manrope(
                fontSize: 10.5,
                fontWeight:
                    FontWeight.w500,
                color: muted,
              ),
            ),
          ],
        ),

        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed:
                _loading
                    ? null
                    : _loadCars,
            icon:
                const Icon(
              Icons.refresh_rounded,
              color: primary,
            ),
          ),
          const SizedBox(
            width: 8,
          ),
        ],
      ),

      floatingActionButton:
          FloatingActionButton.extended(
        onPressed: _addCar,
        backgroundColor:
            primary,
        foregroundColor:
            Colors.white,
        elevation: 4,
        icon: const Icon(
          Icons.add_rounded,
        ),
        label: Text(
          'Add Car',
          style:
              GoogleFonts.manrope(
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ),

      body:
          RefreshIndicator(
        color: primary,
        onRefresh: _loadCars,
        child:
            CustomScrollView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding:
                  const EdgeInsets
                      .fromLTRB(
                20,
                8,
                20,
                120,
              ),
              sliver:
                  SliverList(
                delegate:
                    SliverChildListDelegate(
                  [
                    _buildHeader(),

                    const SizedBox(
                      height: 20,
                    ),

                    _buildSearch(),

                    const SizedBox(
                      height: 16,
                    ),

                    _buildStats(),

                    const SizedBox(
                      height: 24,
                    ),

                    _buildSectionHeader(),

                    const SizedBox(
                      height: 12,
                    ),

                    if (_loading)
                      _buildLoading()
                    else if (
                        _filteredCars
                            .isEmpty)
                      _buildEmptyState()
                    else
                      ..._filteredCars
                          .map(
                        _buildCarCard,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}