import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/config/app_config.dart';
import '../../../cars/models/car.dart';
import '../../../cars/services/car_service.dart';

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

  final CarService _carService =
      CarService.instance;

  final TextEditingController _searchController =
      TextEditingController();

  List<Car> _cars = [];

  bool _loading = true;

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCars();

    _searchController.addListener(() {
      setState(() {
        _searchQuery =
            _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String get _tenantId {
    return AppConfig.tenant.tenantId;
  }

  Future<void> _loadCars() async {
    setState(() {
      _loading = true;
    });

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
          car.registrationNumber.toLowerCase();

      return name.contains(_searchQuery) ||
          type.contains(_searchQuery) ||
          fuel.contains(_searchQuery) ||
          transmission.contains(_searchQuery) ||
          registration.contains(_searchQuery);
    }).toList();
  }

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

  void _showError(String message) {
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
      ),
    );
  }

  Future<void> _deactivateCar(
    Car car,
  ) async {
    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Deactivate vehicle?',
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w800,
              color: heading,
            ),
          ),
          content: Text(
            '${car.name} will no longer be available to customers.',
            style: GoogleFonts.manrope(
              color: body,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child: Text(
                'Cancel',
                style: GoogleFonts.manrope(
                  color: body,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              style:
                  ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor:
                    Colors.white,
              ),
              child: Text(
                'Deactivate',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

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

  void _showCarActions(
    Car car,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: card,
      shape:
          const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.fromLTRB(
              20,
              18,
              20,
              24,
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Container(
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

                const SizedBox(height: 20),

                Text(
                  car.name,
                  style: GoogleFonts.manrope(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: heading,
                  ),
                ),

                const SizedBox(height: 18),

                _actionTile(
                  icon: Icons.edit_outlined,
                  title: 'Edit vehicle',
                  onTap: () {
                    Navigator.pop(context);

                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Edit vehicle will be connected next.',
                          style:
                              GoogleFonts.manrope(
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                        behavior:
                            SnackBarBehavior
                                .floating,
                      ),
                    );
                  },
                ),

                _actionTile(
                  icon:
                      car.isActive
                          ? Icons
                              .visibility_off_outlined
                          : Icons
                              .visibility_outlined,
                  title:
                      car.isActive
                          ? 'Deactivate vehicle'
                          : 'Activate vehicle',
                  onTap: () async {
                    Navigator.pop(context);

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

  Widget _actionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding:
          const EdgeInsets.symmetric(
        vertical: 3,
      ),
      leading: Container(
        width: 42,
        height: 42,
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
      title: Text(
        title,
        style: GoogleFonts.manrope(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: heading,
        ),
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 19,
          ),
          color: heading,
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              'Cars',
              style: GoogleFonts.manrope(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: heading,
              ),
            ),
            Text(
              'Fleet management',
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w500,
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
            icon: Icon(
              Icons.refresh_rounded,
              color: primary,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton:
          FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(
            SnackBar(
              content: Text(
                'Add Car screen will be connected next.',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w600,
                ),
              ),
              behavior:
                  SnackBarBehavior.floating,
            ),
          );
        },
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(
          Icons.add_rounded,
        ),
        label: Text(
          'Add Car',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: primary,
        onRefresh: _loadCars,
        child: CustomScrollView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding:
                  const EdgeInsets.fromLTRB(
                20,
                8,
                20,
                120,
              ),
              sliver: SliverList(
                delegate:
                    SliverChildListDelegate(
                  [
                    _buildHeader(),

                    const SizedBox(height: 20),

                    _buildSearch(),

                    const SizedBox(height: 16),

                    _buildStats(),

                    const SizedBox(height: 24),

                    _buildSectionHeader(),

                    const SizedBox(height: 12),

                    if (_loading)
                      _buildLoading()
                    else if (_filteredCars.isEmpty)
                      _buildEmptyState()
                    else
                      ..._filteredCars.map(
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

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          'Your fleet',
          style: GoogleFonts.manrope(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: heading,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Manage vehicles, availability and fleet status.',
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: body,
          ),
        ),
      ],
    );
  }

  Widget _buildSearch() {
    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color: border,
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 6),
            color:
                Colors.black.withOpacity(
              0.035,
            ),
          ),
        ],
      ),
      child: TextField(
        controller:
            _searchController,
        style: GoogleFonts.manrope(
          fontSize: 14,
          color: heading,
          fontWeight: FontWeight.w600,
        ),
        decoration:
            InputDecoration(
          hintText:
              'Search by car, type or registration...',
          hintStyle:
              GoogleFonts.manrope(
            fontSize: 13,
            color: muted,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: const Icon(
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
                      icon: const Icon(
                        Icons
                            .close_rounded,
                        color: muted,
                      ),
                    )
                  : null,
          border:
              InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildStats() {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            icon:
                Icons.directions_car_filled_rounded,
            label: 'Total',
            value:
                _cars.length.toString(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            icon:
                Icons.check_circle_outline_rounded,
            label: 'Available',
            value:
                _availableCount.toString(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            icon:
                Icons.pause_circle_outline_rounded,
            label: 'Inactive',
            value:
                _inactiveCount.toString(),
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding:
          const EdgeInsets.all(14),
      decoration:
          BoxDecoration(
        color: card,
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color: border,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: primary,
            size: 20,
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: heading,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Row(
      mainAxisAlignment:
          MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'All vehicles',
          style: GoogleFonts.manrope(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: heading,
          ),
        ),
        Text(
          '${_filteredCars.length} vehicles',
          style: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: muted,
          ),
        ),
      ],
    );
  }

  Widget _buildLoading() {
    return Container(
      height: 180,
      alignment:
          Alignment.center,
      child: const CircularProgressIndicator(
        color: primary,
        strokeWidth: 2.5,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(28),
      decoration:
          BoxDecoration(
        color: card,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: border,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration:
                BoxDecoration(
              color: softAccent,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.directions_car_outlined,
              color: primary,
              size: 30,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty
                ? 'No vehicles yet'
                : 'No vehicles found',
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: heading,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _searchQuery.isEmpty
                ? 'Add your first vehicle to start building the fleet.'
                : 'Try a different search term.',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 12,
              height: 1.5,
              color: body,
            ),
          ),
        ],
      ),
    );
  }

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
            BorderRadius.circular(20),
        border: Border.all(
          color: border,
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 20,
            offset: const Offset(0, 7),
            color:
                Colors.black.withOpacity(
              0.035,
            ),
          ),
        ],
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                _buildCarImage(car),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              car.name,
                              maxLines: 1,
                              overflow:
                                  TextOverflow.ellipsis,
                              style:
                                  GoogleFonts.manrope(
                                fontSize: 16,
                                fontWeight:
                                    FontWeight.w800,
                                color: heading,
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

                      const SizedBox(height: 3),

                      Text(
                        _vehicleSubtitle(car),
                        style:
                            GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight:
                              FontWeight.w600,
                          color: body,
                        ),
                      ),

                      if (car
                          .registrationNumber
                          .isNotEmpty) ...[
                        const SizedBox(
                          height: 4,
                        ),
                        Text(
                          car.registrationNumber,
                          style:
                              GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight:
                                FontWeight.w600,
                            color: muted,
                          ),
                        ),
                      ],

                      const SizedBox(
                        height: 10,
                      ),

                      Row(
                        children: [
                          _statusBadge(car),
                          const Spacer(),
                          Text(
                            '₹${_formatPrice(car.pricePerDay)}/day',
                            style:
                                GoogleFonts.manrope(
                              fontSize: 13,
                              fontWeight:
                                  FontWeight.w800,
                              color: primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 13),

            Container(
              height: 1,
              color: border,
            ),

            const SizedBox(height: 11),

            Row(
              children: [
                _spec(
                  Icons.people_outline_rounded,
                  '${car.seats} Seats',
                ),
                const SizedBox(width: 14),
                _spec(
                  Icons.settings_outlined,
                  car.transmission,
                ),
                const SizedBox(width: 14),
                _spec(
                  Icons.local_gas_station_outlined,
                  car.fuel,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarImage(
    Car car,
  ) {
    final imageUrl =
        car.image.trim();

    return Container(
      width: 108,
      height: 82,
      decoration:
          BoxDecoration(
        color: softAccent,
        borderRadius:
            BorderRadius.circular(16),
      ),
      clipBehavior:
          Clip.antiAlias,
      child: imageUrl.isEmpty
          ? const Icon(
              Icons.directions_car_rounded,
              color: primary,
              size: 42,
            )
          : Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder:
                  (
                    context,
                    error,
                    stackTrace,
                  ) {
                return const Icon(
                  Icons
                      .directions_car_rounded,
                  color: primary,
                  size: 42,
                );
              },
              loadingBuilder:
                  (
                    context,
                    child,
                    progress,
                  ) {
                if (progress == null) {
                  return child;
                }

                return const Center(
                  child:
                      CircularProgressIndicator(
                    color: primary,
                    strokeWidth: 2,
                  ),
                );
              },
            ),
    );
  }

  Widget _statusBadge(
    Car car,
  ) {
    String label;
    Color backgroundColor;
    Color textColor;

    if (!car.isActive) {
      label = 'Inactive';
      backgroundColor =
          const Color(0xFFF1F3F2);
      textColor = muted;
    } else if (!car.isAvailable) {
      label = _statusLabel(
        car.status,
      );
      backgroundColor =
          const Color(0xFFFFF7E6);
      textColor =
          const Color(0xFF9A6B00);
    } else {
      label = 'Available';
      backgroundColor = softAccent;
      textColor = primary;
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration:
          BoxDecoration(
        color: backgroundColor,
        borderRadius:
            BorderRadius.circular(20),
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
              color: textColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(
    String status,
  ) {
    switch (status
        .trim()
        .toLowerCase()) {
      case 'booked':
        return 'Booked';

      case 'maintenance':
        return 'Maintenance';

      case 'inactive':
        return 'Inactive';

      case 'available':
        return 'Available';

      default:
        if (status.isEmpty) {
          return 'Unavailable';
        }

        return status[0].toUpperCase() +
            status.substring(1);
    }
  }

  Widget _spec(
    IconData icon,
    String text,
  ) {
    return Expanded(
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: muted,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  GoogleFonts.manrope(
                fontSize: 10,
                fontWeight:
                    FontWeight.w700,
                color: body,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _vehicleSubtitle(
    Car car,
  ) {
    final parts = <String>[];

    if (car.type.isNotEmpty) {
      parts.add(car.type);
    }

    if (car.transmission.isNotEmpty) {
      parts.add(car.transmission);
    }

    return parts.join(' • ');
  }

  String _formatPrice(
    int value,
  ) {
    final text =
        value.toString();

    if (text.length <= 3) {
      return text;
    }

    final buffer =
        StringBuffer();

    var count = 0;

    for (
      var i = text.length - 1;
      i >= 0;
      i--
    ) {
      buffer.write(text[i]);
      count++;

      if (count == 3 &&
          i != 0) {
        buffer.write(',');
      } else if (
          count > 3 &&
          (count - 3) % 2 == 0 &&
          i != 0) {
        buffer.write(',');
      }
    }

    return buffer
        .toString()
        .split('')
        .reversed
        .join();
  }
}