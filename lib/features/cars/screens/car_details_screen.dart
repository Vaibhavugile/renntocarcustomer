
import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../booking/screens/date_time_screen.dart';
import '../../pricing/manager/pricing_manager.dart';
import '../../pricing/models/km_pricing_package.dart';
import '../../pricing/models/pricing_profile.dart';
import '../models/car.dart';

/// Premium customer-facing car details screen.
///
/// IMPORTANT:
/// - This screen is PRESENTATION ONLY.
/// - It does NOT select a rental package.
/// - It only displays the first hourly/daily package as an example.
/// - Package selection happens later in the booking flow.
/// - Final pricing is calculated by the booking/pricing flow.
class CarDetailsScreen extends StatefulWidget {
  final Car car;

  const CarDetailsScreen({
    super.key,
    required this.car,
  });

  @override
  State<CarDetailsScreen> createState() => _CarDetailsScreenState();
}

class _CarDetailsScreenState extends State<CarDetailsScreen> {
  // ===========================================================================
  // THEME
  // ===========================================================================

  static const Color primary = Color(0xFF0F766E);
  static const Color primaryDark = Color(0xFF0B5F59);
  static const Color accent = Color(0xFF14B8A6);

  static const Color background = Color(0xFFF7F9F8);
  static const Color card = Colors.white;
  static const Color softAccent = Color(0xFFE8F8F5);

  static const Color heading = Color(0xFF17201F);
  static const Color body = Color(0xFF66706E);
  static const Color muted = Color(0xFF94A09D);
  static const Color border = Color(0xFFE3EAE8);

  static const Color success = Color(0xFF15803D);
  static const Color successBg = Color(0xFFEAF8EF);

  static const Color warning = Color(0xFF9A6B28);
  static const Color warningBg = Color(0xFFFFF8F0);

  // ===========================================================================
  // STATE
  // ===========================================================================

  PricingProfile? _pricingProfile;

  bool _isPricingLoading = true;
  String? _pricingError;

  bool _isFavorite = false;

  // Customer chooses rental basis here. Package selection remains later.
  bool _isHourly = false;

  final PageController _imageController = PageController();

  int _currentImageIndex = 0;

  // ===========================================================================
  // GETTERS
  // ===========================================================================

  String get _tenantId => AppConfig.tenant.tenantId;

  Car get _car => widget.car;

  // ===========================================================================
  // IMAGE LIST
  // ===========================================================================

  List<String> get _imageUrls {
    final urls = <String>[];

    final primaryImage = _car.image.trim();

    if (primaryImage.isNotEmpty) {
      urls.add(primaryImage);
    }

    for (final image in _car.images) {
      final url = image.trim();

      if (url.isEmpty) continue;

      if (!urls.contains(url)) {
        urls.add(url);
      }
    }

    return urls;
  }

  // ===========================================================================
  // INIT
  // ===========================================================================

  @override
  void initState() {
    super.initState();

    _loadPricingProfile();
  }

  @override
  void dispose() {
    _imageController.dispose();

    super.dispose();
  }

  // ===========================================================================
  // PRICING
  // ===========================================================================

  Future<void> _loadPricingProfile() async {
    if (!mounted) return;

    setState(() {
      _isPricingLoading = true;
      _pricingError = null;
    });

    try {
      final tenantId = _tenantId.trim();

      if (tenantId.isEmpty) {
        throw Exception('Tenant configuration is missing.');
      }

      final pricingProfileId = _car.pricingProfileId.trim();

      if (pricingProfileId.isEmpty) {
        throw Exception(
          'Pricing profile is not configured for this vehicle.',
        );
      }

      final pricing =
          await PricingManager.instance.loadPricingForCar(
        tenantId: tenantId,
        pricingProfileId: pricingProfileId,
      );

      if (!mounted) return;

      if (pricing == null) {
        setState(() {
          _pricingProfile = null;
          _isPricingLoading = false;
          _pricingError =
              'Pricing details are unavailable for this vehicle.';
        });

        return;
      }

      final hasDaily = pricing.dailyPackages.any(
        (package) => package.isActive && package.safeDailyRate > 0,
      );
      final hasHourly = pricing.hourlyPackages.any(
        (package) => package.isActive && package.safeHourlyRate > 0,
      );

      setState(() {
        _pricingProfile = pricing;
        _isPricingLoading = false;
        _pricingError = null;
        // Daily is the default when available; otherwise use hourly.
        _isHourly = !hasDaily && hasHourly;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _pricingProfile = null;
        _isPricingLoading = false;
        _pricingError = _cleanError(e);
      });
    }
  }

  String _cleanError(Object error) {
    final text = error.toString();

    if (text.startsWith('Exception: ')) {
      return text.substring(11);
    }

    return text;
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,

      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),

        slivers: [
          _buildHeroAppBar(),

          SliverToBoxAdapter(
            child: _buildContent(),
          ),
        ],
      ),

      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // ===========================================================================
  // HERO / IMAGE GALLERY
  // ===========================================================================

  Widget _buildHeroAppBar() {
    final images = _imageUrls;

    return SliverAppBar(
      expandedHeight: 360,

      pinned: true,

      backgroundColor: background,
      foregroundColor: heading,

      elevation: 0,

      surfaceTintColor: Colors.transparent,

      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: _circleButton(
          icon: Icons.arrow_back_rounded,
          onTap: () => Navigator.pop(context),
        ),
      ),

      actions: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: _circleButton(
            icon: _isFavorite
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            iconColor:
                _isFavorite ? Colors.redAccent : heading,
            onTap: () {
              setState(() {
                _isFavorite = !_isFavorite;
              });
            },
          ),
        ),
      ],

      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            _buildImageGallery(images),

            _buildHeroGradient(),

            _buildHeroBottomInfo(),

            if (images.length > 1)
              Positioned(
                bottom: 102,
                left: 0,
                right: 0,
                child: _buildImageIndicator(images.length),
              ),

            if (images.length > 1)
              Positioned(
                right: 18,
                bottom: 22,
                child: _buildImageCount(images.length),
              ),
          ],
        ),
      ),
    );
  }

  Widget _circleButton({
    required IconData icon,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.95),

      shape: const CircleBorder(),

      elevation: 1,

      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,

        child: SizedBox(
          width: 42,
          height: 42,

          child: Icon(
            icon,
            color: iconColor ?? heading,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildImageGallery(List<String> images) {
    if (images.isEmpty) {
      return _imagePlaceholder();
    }

    return PageView.builder(
      controller: _imageController,

      itemCount: images.length,

      onPageChanged: (index) {
        if (!mounted) return;

        setState(() {
          _currentImageIndex = index;
        });
      },

      itemBuilder: (_, index) {
        final url = images[index];

        return GestureDetector(
          onTap: () {
            _openFullScreenGallery(
              images,
              index,
            );
          },

          child: Hero(
            tag: 'car-image-${_car.id}-$index',

            child: Image.network(
              url,

              fit: BoxFit.cover,

              width: double.infinity,
              height: double.infinity,

              errorBuilder: (_, __, ___) {
                return _imagePlaceholder();
              },

              loadingBuilder: (_, child, progress) {
                if (progress == null) {
                  return child;
                }

                return Container(
                  color: const Color(0xFFEFF4F3),

                  child: const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: primary,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: const Color(0xFFEFF4F3),

      child: const Center(
        child: Icon(
          Icons.directions_car_outlined,
          size: 76,
          color: muted,
        ),
      ),
    );
  }

  Widget _buildHeroGradient() {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,

            colors: [
              Colors.black.withValues(alpha: 0.05),
              Colors.transparent,
              Colors.black.withValues(alpha: 0.78),
            ],

            stops: const [
              0,
              0.42,
              1,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroBottomInfo() {
    return Positioned(
      left: 20,
      right: 20,
      bottom: 24,

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,

        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),

                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(9),
                  ),

                  child: Text(
                    _car.type.toUpperCase(),

                    style: const TextStyle(
                      color: primary,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  _car.name,

                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,

                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          _availabilityBadge(
            _car.isAvailable,
          ),
        ],
      ),
    );
  }

  Widget _availabilityBadge(bool available) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 8,
      ),

      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,

        children: [
          Container(
            width: 7,
            height: 7,

            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: available
                  ? success
                  : Colors.redAccent,
            ),
          ),

          const SizedBox(width: 6),

          Text(
            available ? 'AVAILABLE' : 'UNAVAILABLE',

            style: TextStyle(
              color: available
                  ? success
                  : Colors.redAccent,

              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageIndicator(int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,

      children: List.generate(
        count > 7 ? 7 : count,
        (index) {
          final selected =
              index == _currentImageIndex;

          return AnimatedContainer(
            duration: const Duration(
              milliseconds: 180,
            ),

            margin: const EdgeInsets.symmetric(
              horizontal: 3,
            ),

            width: selected ? 20 : 6,
            height: 5,

            decoration: BoxDecoration(
              color: Colors.white.withValues(
                alpha: selected ? 0.95 : 0.55,
              ),

              borderRadius:
                  BorderRadius.circular(10),
            ),
          );
        },
      ),
    );
  }

  Widget _buildImageCount(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),

      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(10),
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,

        children: [
          const Icon(
            Icons.photo_library_outlined,
            color: Colors.white,
            size: 14,
          ),

          const SizedBox(width: 5),

          Text(
            '${_currentImageIndex + 1}/$count',

            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // FULL SCREEN GALLERY
  // ===========================================================================

  void _openFullScreenGallery(
    List<String> images,
    int initialIndex,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _CarImageGalleryScreen(
          images: images,
          initialIndex: initialIndex,
          carName: _car.name,
        ),
      ),
    );
  }

  // ===========================================================================
  // MAIN CONTENT
  // ===========================================================================

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        22,
        20,
        38,
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          _buildTitleAndPricing(),

          const SizedBox(height: 22),

          _buildVehicleRunning(),

          const SizedBox(height: 26),

          _buildDescription(),

          const SizedBox(height: 26),

          _buildSpecs(),

          const SizedBox(height: 26),

          _buildRentalOptions(),

          const SizedBox(height: 26),

          _buildPackagePreview(),


          if (_hasSpecialRates) ...[
            const SizedBox(height: 26),
            _buildSpecialRates(),
          ],

          const SizedBox(height: 26),

          _buildDeposit(),

          const SizedBox(height: 26),

          _buildRentalInformation(),

          const SizedBox(height: 26),

          _buildBookingNote(),
        ],
      ),
    );
  }

  // ===========================================================================
  // TITLE + BASE PRICES
  // ===========================================================================

  Widget _buildTitleAndPricing() {
    final pricing = _pricingProfile;

    final hourly =
        _firstHourlyPackage(pricing);

    final daily =
        _firstDailyPackage(pricing);

    final dailyFallback =
        _car.pricePerDay.toDouble();

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [
        Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [
                  Text(
                    _car.type.toUpperCase(),

                    style: const TextStyle(
                      color: primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    _car.name,

                    style: const TextStyle(
                      color: heading,
                      fontSize: 25,
                      height: 1.08,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),

        _buildStartingPriceCard(
          hourly: hourly,
          daily: daily,
          dailyFallback: dailyFallback,
        ),
      ],
    );
  }

  Widget _buildStartingPriceCard({
    required KmPricingPackage? hourly,
    required KmPricingPackage? daily,
    required double dailyFallback,
  }) {
    final hasHourly =
        hourly != null &&
        hourly.safeHourlyRate > 0;

    final hasDaily =
        daily != null
            ? daily.safeDailyRate > 0
            : dailyFallback > 0;

    if (!hasHourly && !hasDaily) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,

          colors: [
            Color(0xFFE9FAF7),
            Color(0xFFF5FBFA),
          ],
        ),

        borderRadius: BorderRadius.circular(22),

        border: Border.all(
          color: const Color(0xFFCDECE6),
        ),
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          const Row(
            children: [
              Icon(
                Icons.local_offer_outlined,
                size: 17,
                color: primary,
              ),

              SizedBox(width: 7),

              Text(
                'STARTING PRICE',

                style: TextStyle(
                  color: primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.9,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              if (hasHourly)
                Expanded(
                  child: _priceColumn(
                    icon:
                        Icons.schedule_outlined,
                    label: 'Hourly',
                    amount:
                        '₹${_formatAmount(hourly!.safeHourlyRate)}',
                    suffix: '/ hour',
                  ),
                ),

              if (hasHourly && hasDaily)
                Container(
                  width: 1,
                  height: 58,
                  color: const Color(
                    0xFFD6EAE6,
                  ),
                ),

              if (hasDaily)
                Expanded(
                  child: _priceColumn(
                    icon:
                        Icons.today_outlined,
                    label: 'Daily',
                    amount:
                        '₹${_formatAmount(
                      daily?.safeDailyRate ??
                          dailyFallback,
                    )}',
                    suffix: '/ day',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _priceColumn({
    required IconData icon,
    required String label,
    required String amount,
    required String suffix,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 5,
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 15,
                color: primary,
              ),

              const SizedBox(width: 5),

              Text(
                label,

                style: const TextStyle(
                  color: body,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          Text(
            amount,

            style: const TextStyle(
              color: heading,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),

          Text(
            suffix,

            style: const TextStyle(
              color: muted,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // CURRENT VEHICLE RUNNING
  // ===========================================================================

  Widget _buildVehicleRunning() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: softAccent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.speed_rounded,
              color: primary,
              size: 23,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CURRENT VEHICLE RUNNING',
                  style: TextStyle(
                    color: muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatNumber(_car.currentKm)} KM',
                  style: const TextStyle(
                    color: heading,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 9,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: successBg,
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Text(
              'ODOMETER',
              style: TextStyle(
                color: success,
                fontSize: 8,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // DESCRIPTION
  // ===========================================================================

  Widget _buildDescription() {
    final description = _car.description.trim();

    if (description.isEmpty && _car.features.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          'About this vehicle',
          'Everything you should know before booking',
        ),
        const SizedBox(height: 12),
        if (description.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(21),
              border: Border.all(color: border),
            ),
            child: Text(
              description,
              style: const TextStyle(
                color: body,
                fontSize: 12,
                height: 1.65,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        if (_car.features.isNotEmpty) ...[
          if (description.isNotEmpty) const SizedBox(height: 13),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _car.features.map((feature) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: softAccent,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: const Color(0xFFCDECE6),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      color: primary,
                      size: 14,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      feature,
                      style: const TextStyle(
                        color: heading,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  // ===========================================================================
  // SPECS
  // ===========================================================================

  Widget _buildSpecs() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: card,

        borderRadius: BorderRadius.circular(22),

        border: Border.all(
          color: border,
        ),

        boxShadow: const [
          BoxShadow(
            color: Color(0x0717201F),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),

      child: Row(
        children: [
          Expanded(
            child: _specItem(
              Icons.settings_outlined,
              'Transmission',
              _car.transmission,
            ),
          ),

          _verticalDivider(),

          Expanded(
            child: _specItem(
              Icons.event_seat_outlined,
              'Seats',
              '${_car.seats}',
            ),
          ),

          _verticalDivider(),

          Expanded(
            child: _specItem(
              Icons.local_gas_station_outlined,
              'Fuel',
              _car.fuel,
            ),
          ),
        ],
      ),
    );
  }

  Widget _specItem(
    IconData icon,
    String label,
    String value,
  ) {
    return Column(
      children: [
        Container(
          width: 42,
          height: 42,

          decoration: BoxDecoration(
            color: softAccent,
            borderRadius:
                BorderRadius.circular(13),
          ),

          child: Icon(
            icon,
            size: 19,
            color: primary,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          label,

          textAlign: TextAlign.center,

          maxLines: 1,
          overflow:
              TextOverflow.ellipsis,

          style: const TextStyle(
            color: muted,
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 3),

        Text(
          value.isEmpty ? '—' : value,

          textAlign: TextAlign.center,

          maxLines: 1,
          overflow:
              TextOverflow.ellipsis,

          style: const TextStyle(
            color: heading,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _verticalDivider() {
    return Container(
      width: 1,
      height: 58,
      color: border,
    );
  }

  // ===========================================================================
  // RENTAL OPTIONS
  // ===========================================================================

  Widget _buildRentalOptions() {
    final pricing = _pricingProfile;

    if (pricing == null) {
      return _buildPricingUnavailable();
    }

    final hourly =
        _firstHourlyPackage(pricing);

    final daily =
        _firstDailyPackage(pricing);

    final hasHourly =
        hourly != null &&
        hourly.safeHourlyRate > 0;

    final hasDaily =
        daily != null &&
        daily.safeDailyRate > 0;

    if (!hasHourly && !hasDaily) {
      return _buildPricingUnavailable(
        message:
            'No active hourly or daily rental pricing is configured.',
      );
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [
        _sectionTitle(
          'Choose rental basis',
          'Select how you want to rent this vehicle. Package selection happens later.',
        ),

        const SizedBox(height: 13),

        Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [
            if (hasHourly)
              Expanded(
                child: _rentalOptionCard(
                  icon: Icons.schedule_rounded,
                  title: 'Hourly',
                  price:
                      '₹${_formatAmount(hourly!.safeHourlyRate)}',
                  suffix: '/ hour',
                  subtitle:
                      'Flexible short rentals',
                  includedKm:
                      hourly.safeIncludedKm,
                  unlimited:
                      hourly.unlimitedKm,
                  extraKm:
                      hourly.safeExtraKmRate,
                  selected: _isHourly,
                  onTap: () {
                    setState(() {
                      _isHourly = true;
                    });
                  },
                ),
              ),

            if (hasHourly && hasDaily)
              const SizedBox(width: 10),

            if (hasDaily)
              Expanded(
                child: _rentalOptionCard(
                  icon: Icons.today_rounded,
                  title: 'Daily',
                  price:
                      '₹${_formatAmount(daily!.safeDailyRate)}',
                  suffix: '/ day',
                  subtitle:
                      'Ideal for longer trips',
                  includedKm:
                      daily.safeIncludedKm,
                  unlimited:
                      daily.unlimitedKm,
                  extraKm:
                      daily.safeExtraKmRate,
                  selected: !_isHourly,
                  onTap: () {
                    setState(() {
                      _isHourly = false;
                    });
                  },
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _rentalOptionCard({
    required IconData icon,
    required String title,
    required String price,
    required String suffix,
    required String subtitle,
    required int includedKm,
    required bool unlimited,
    required double extraKm,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(15),

      decoration: BoxDecoration(
        color: selected ? softAccent : card,

        borderRadius:
            BorderRadius.circular(20),

        border: Border.all(
          color: selected ? accent : border,
          width: selected ? 1.5 : 1,
        ),

        boxShadow: const [
          BoxShadow(
            color: Color(0x0617201F),
            blurRadius: 15,
            offset: Offset(0, 6),
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
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: selected ? primary : softAccent,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  icon,
                  color: selected ? Colors.white : primary,
                  size: 19,
                ),
              ),
              const Spacer(),
              if (selected)
                Container(
                  width: 25,
                  height: 25,
                  decoration: const BoxDecoration(
                    color: primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          Text(
            title,

            style: const TextStyle(
              color: heading,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 3),

          Text(
            subtitle,

            maxLines: 2,
            overflow:
                TextOverflow.ellipsis,

            style: const TextStyle(
              color: muted,
              fontSize: 9,
              height: 1.25,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            price,

            style: const TextStyle(
              color: primary,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),

          Text(
            suffix,

            style: const TextStyle(
              color: muted,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 12),

          Container(
            width: double.infinity,
            height: 1,
            color: border,
          ),

          const SizedBox(height: 11),

          _kmLine(
            icon: Icons.speed_rounded,
            title: unlimited
                ? 'Unlimited KM'
                : '${_formatKm(includedKm)} KM included',
            positive: true,
          ),

          const SizedBox(height: 7),

          _kmLine(
            icon:
                Icons.add_road_rounded,
            title: unlimited
                ? 'No extra KM charge'
                : '₹${_formatAmount(extraKm)} / KM extra',
            positive: true,
          ),
        ],
      ),
      ),
    );
  }

  Widget _kmLine({
    required IconData icon,
    required String title,
    required bool positive,
  }) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [
        Icon(
          icon,
          size: 14,
          color: positive
              ? success
              : muted,
        ),

        const SizedBox(width: 6),

        Expanded(
          child: Text(
            title,

            style: TextStyle(
              color: positive
                  ? heading
                  : body,
              fontSize: 9,
              height: 1.25,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // FIRST PACKAGE PREVIEW
  // ===========================================================================

  Widget _buildPackagePreview() {
    final pricing = _pricingProfile;

    if (pricing == null) {
      return const SizedBox.shrink();
    }

    final hourly =
        _firstHourlyPackage(pricing);

    final daily =
        _firstDailyPackage(pricing);

    if (hourly == null && daily == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [
        _sectionTitle(
          'Available packages',
          'A quick look at the first package in each rental type',
        ),

        const SizedBox(height: 13),

        if (daily != null)
          _packagePreviewCard(
            package: daily,
            rentalType: 'Daily',
          ),

        if (daily != null && hourly != null)
          const SizedBox(height: 10),

        if (hourly != null)
          _packagePreviewCard(
            package: hourly,
            rentalType: 'Hourly',
          ),
      ],
    );
  }

  Widget _packagePreviewCard({
    required KmPricingPackage package,
    required String rentalType,
  }) {
    final isHourly =
        rentalType.toLowerCase() ==
            'hourly';

    final rate = isHourly
        ? package.safeHourlyRate
        : package.safeDailyRate;

    final rateSuffix =
        isHourly ? '/ hr' : '/ day';

    final kmText = package.unlimitedKm
        ? 'Unlimited KM'
        : '${_formatKm(package.safeIncludedKm)} KM included';

    final extraText =
        package.unlimitedKm
            ? 'No extra KM charge'
            : '₹${_formatAmount(package.safeExtraKmRate)} / KM extra';

    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: card,

        borderRadius:
            BorderRadius.circular(20),

        border: Border.all(
          color: border,
        ),
      ),

      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,

            decoration: BoxDecoration(
              color: softAccent,
              borderRadius:
                  BorderRadius.circular(14),
            ),

            child: Icon(
              isHourly
                  ? Icons.schedule_rounded
                  : Icons.today_rounded,
              color: primary,
              size: 20,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Row(
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 4,
                      ),

                      decoration: BoxDecoration(
                        color: softAccent,
                        borderRadius:
                            BorderRadius.circular(7),
                      ),

                      child: Text(
                        rentalType.toUpperCase(),

                        style: const TextStyle(
                          color: primary,
                          fontSize: 8,
                          fontWeight:
                              FontWeight.w900,
                          letterSpacing: .5,
                        ),
                      ),
                    ),

                    const SizedBox(width: 7),

                    Expanded(
                      child: Text(
                        package.name,

                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,

                        style:
                            const TextStyle(
                          color: heading,
                          fontSize: 12,
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 7),

                Text(
                  kmText,

                  style: const TextStyle(
                    color: body,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  extraText,

                  style: const TextStyle(
                    color: muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          Column(
            crossAxisAlignment:
                CrossAxisAlignment.end,

            children: [
              Text(
                '₹${_formatAmount(rate)}',

                style: const TextStyle(
                  color: primary,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),

              const SizedBox(height: 2),

              Text(
                rateSuffix,

                style: const TextStyle(
                  color: muted,
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SPECIAL RATES
  // ===========================================================================

  bool get _hasSpecialRates {
    final pricing = _pricingProfile;

    if (pricing == null) {
      return false;
    }

    return pricing.specialRates
        .any((rate) => rate.isActive);
  }

  Widget _buildSpecialRates() {
    final pricing = _pricingProfile;

    if (pricing == null) {
      return const SizedBox.shrink();
    }

    final rates = pricing.specialRates
        .where((rate) => rate.isActive)
        .toList();

    if (rates.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [
        _sectionTitle(
          'Special rates',
          'Date-based pricing may apply on selected dates',
        ),

        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(16),

          decoration: BoxDecoration(
            color: card,

            borderRadius:
                BorderRadius.circular(21),

            border: Border.all(
              color: border,
            ),
          ),

          child: Column(
            children: [
              for (var i = 0;
                  i < rates.length;
                  i++) ...[
                if (i > 0)
                  const Divider(
                    height: 20,
                    color: border,
                  ),

                _specialRateRow(
                  rates[i],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _specialRateRow(
    SpecialRate rate,
  ) {
    final dateText =
        '${_formatDate(rate.startDate)} – ${_formatDate(rate.endDate)}';

    final hourly =
        _firstMapValue(rate.hourlyPrices);

    final daily =
        _firstMapValue(rate.dailyPrices);

    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [
        Container(
          width: 40,
          height: 40,

          decoration: BoxDecoration(
            color: softAccent,
            borderRadius:
                BorderRadius.circular(12),
          ),

          child: const Icon(
            Icons.event_available_outlined,
            color: primary,
            size: 19,
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              Text(
                rate.name,

                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,

                style: const TextStyle(
                  color: heading,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),

              const SizedBox(height: 3),

              Text(
                dateText,

                style: const TextStyle(
                  color: muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 6),

              Wrap(
                spacing: 6,
                runSpacing: 5,

                children: [
                  if (hourly != null)
                    _rateChip(
                      'Hourly ₹${_formatAmount(hourly)}',
                    ),

                  if (daily != null)
                    _rateChip(
                      'Daily ₹${_formatAmount(daily)}',
                    ),

                  if (rate.extraKmRate != null &&
                      rate.extraKmRate! >= 0)
                    _rateChip(
                      'Extra KM ₹${_formatAmount(rate.extraKmRate!)}',
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _rateChip(String text) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),

      decoration: BoxDecoration(
        color: background,
        borderRadius:
            BorderRadius.circular(8),
        border:
            Border.all(color: border),
      ),

      child: Text(
        text,

        style: const TextStyle(
          color: body,
          fontSize: 8,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  // ===========================================================================
  // SECURITY DEPOSIT
  // ===========================================================================

  Widget _buildDeposit() {
    final pricing = _pricingProfile;

    if (pricing == null) {
      return const SizedBox.shrink();
    }

    final deposit = pricing.securityDeposit;

    final isNone =
        deposit.type == DepositType.none;

    String title;
    String subtitle;
    String amount = '';

    if (isNone) {
      title = 'No security deposit';

      subtitle =
          'No separate security deposit is configured.';
    } else if (deposit.isMonetary) {
      title =
          'Refundable security deposit';

      subtitle =
          deposit.paymentMethod.isNotEmpty
              ? 'Collected separately • ${deposit.paymentMethod}'
              : 'Collected separately from the rental amount.';

      amount =
          '₹${_formatAmount(deposit.amount)}';
    } else {
      title = deposit.type ==
              DepositType.vehicleAsset
          ? 'Vehicle / asset as security'
          : 'Other asset as security';

      subtitle =
          deposit.minimumAssetValue > 0
              ? 'Minimum asset value ₹${_formatAmount(deposit.minimumAssetValue)}'
              : 'Asset details will be collected during booking.';
    }

    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: card,

        borderRadius:
            BorderRadius.circular(21),

        border: Border.all(
          color: border,
        ),
      ),

      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,

            decoration: BoxDecoration(
              color: softAccent,
              borderRadius:
                  BorderRadius.circular(14),
            ),

            child: Icon(
              isNone
                  ? Icons.verified_outlined
                  : Icons.account_balance_wallet_outlined,
              color: primary,
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Text(
                  title,

                  style: const TextStyle(
                    color: heading,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  subtitle,

                  style: const TextStyle(
                    color: body,
                    fontSize: 9,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          if (amount.isNotEmpty)
            Padding(
              padding:
                  const EdgeInsets.only(
                left: 8,
              ),

              child: Text(
                amount,

                style: const TextStyle(
                  color: heading,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // RENTAL INFORMATION
  // ===========================================================================

  Widget _buildRentalInformation() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [
        _sectionTitle(
          'Good to know',
          'Everything important before you book',
        ),

        const SizedBox(height: 12),

        Container(
          decoration: BoxDecoration(
            color: card,

            borderRadius:
                BorderRadius.circular(21),

            border: Border.all(
              color: border,
            ),
          ),

          child: Column(
            children: [
              _infoRow(
                icon:
                    Icons.payments_outlined,
                title: 'Pricing',
                value:
                    'Package based',
              ),

              _infoDivider(),

              _infoRow(
                icon:
                    Icons.speed_outlined,
                title: 'Included KM',
                value:
                    'Depends on package',
              ),

              _infoDivider(),

              _infoRow(
                icon:
                    Icons.add_road_outlined,
                title: 'Extra KM',
                value:
                    'Package rate',
              ),

              _infoDivider(),

              _infoRow(
                icon:
                    Icons.event_repeat_outlined,
                title: 'Special dates',
                value:
                    'Date-based rules',
              ),

              _infoDivider(),

              _infoRow(
                icon:
                    Icons.account_balance_wallet_outlined,
                title: 'Deposit',
                value:
                    'Separate from trip total',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),

      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,

            decoration: BoxDecoration(
              color: background,
              borderRadius:
                  BorderRadius.circular(10),
            ),

            child: Icon(
              icon,
              size: 16,
              color: primary,
            ),
          ),

          const SizedBox(width: 11),

          Expanded(
            child: Text(
              title,

              style: const TextStyle(
                color: body,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          Text(
            value,

            style: const TextStyle(
              color: heading,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoDivider() {
    return const Divider(
      height: 1,
      color: border,
    );
  }

  // ===========================================================================
  // BOOKING NOTE
  // ===========================================================================

  Widget _buildBookingNote() {
    return Container(
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: warningBg,

        borderRadius:
            BorderRadius.circular(18),

        border: Border.all(
          color: const Color(0xFFF1E0C9),
        ),
      ),

      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: warning,
          ),

          const SizedBox(width: 10),

          const Expanded(
            child: Text(
              'The final booking price is calculated after you choose your dates, rental type, package, add-ons, protection, discounts and applicable taxes. The security deposit is separate from the rental total.',
              style: TextStyle(
                color: Color(0xFF765522),
                fontSize: 10,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // BOTTOM BOOK NOW
  // ===========================================================================

  Widget _buildBottomBar() {
    final enabled =
        _car.isAvailable &&
        !_isPricingLoading &&
        _pricingProfile != null;

    return SafeArea(
      top: false,

      child: Container(
        padding:
            const EdgeInsets.fromLTRB(
          20,
          11,
          20,
          11,
        ),

        decoration: const BoxDecoration(
          color: Colors.white,

          border: Border(
            top: BorderSide(
              color: border,
            ),
          ),

          boxShadow: [
            BoxShadow(
              color: Color(0x0A17201F),
              blurRadius: 18,
              offset: Offset(0, -6),
            ),
          ],
        ),

        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize:
                    MainAxisSize.min,

                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [
                  const Text(
                    'Ready to ride?',

                    style: TextStyle(
                      color: muted,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 2),

                  Text(
                    enabled
                        ? (_isHourly
                            ? 'Hourly rental selected'
                            : 'Daily rental selected')
                        : _isPricingLoading
                            ? 'Loading pricing...'
                            : 'Currently unavailable',

                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,

                    style: const TextStyle(
                      color: heading,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            SizedBox(
              height: 52,

              child: ElevatedButton(
                onPressed:
                    enabled ? _bookNow : null,

                style:
                    ElevatedButton.styleFrom(
                  backgroundColor: primary,

                  foregroundColor:
                      Colors.white,

                  disabledBackgroundColor:
                      const Color(
                    0xFFD7DEDC,
                  ),

                  disabledForegroundColor:
                      const Color(
                    0xFF7D8986,
                  ),

                  elevation: 0,

                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 21,
                  ),

                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(17),
                  ),
                ),

                child: Row(
                  mainAxisSize:
                      MainAxisSize.min,

                  children: [
                    Text(
                      enabled
                          ? 'BOOK NOW'
                          : _isPricingLoading
                              ? 'LOADING'
                              : 'UNAVAILABLE',

                      style:
                          const TextStyle(
                        fontSize: 12,
                        fontWeight:
                            FontWeight.w900,
                        letterSpacing: .2,
                      ),
                    ),

                    if (enabled) ...[
                      const SizedBox(width: 7),

                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 17,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _bookNow() {
    if (!_car.isAvailable) {
      return;
    }

    if (_isPricingLoading) {
      return;
    }

    if (_pricingProfile == null) {
      return;
    }

    Navigator.push(
      context,

      MaterialPageRoute(
        builder: (_) => DateTimeScreen(
          car: _car,
        ),
      ),
    );
  }

  // ===========================================================================
  // PRICING HELPERS
  // ===========================================================================

  KmPricingPackage? _firstHourlyPackage(
    PricingProfile? pricing,
  ) {
    if (pricing == null) {
      return null;
    }

    for (final package
        in pricing.hourlyPackages) {
      if (!package.isActive) {
        continue;
      }

      if (package.safeHourlyRate <= 0) {
        continue;
      }

      return package;
    }

    return null;
  }

  KmPricingPackage? _firstDailyPackage(
    PricingProfile? pricing,
  ) {
    if (pricing == null) {
      return null;
    }

    for (final package
        in pricing.dailyPackages) {
      if (!package.isActive) {
        continue;
      }

      if (package.safeDailyRate <= 0) {
        continue;
      }

      return package;
    }

    return null;
  }

  // ===========================================================================
  // SECTION TITLE
  // ===========================================================================

  Widget _sectionTitle(
    String title,
    String subtitle,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [
        Text(
          title,

          style: const TextStyle(
            color: heading,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),

        const SizedBox(height: 4),

        Text(
          subtitle,

          style: const TextStyle(
            color: muted,
            fontSize: 10,
            height: 1.3,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // PRICING UNAVAILABLE
  // ===========================================================================

  Widget _buildPricingUnavailable({
    String? message,
  }) {
    if (_isPricingLoading) {
      return Container(
        padding: const EdgeInsets.all(18),

        decoration: BoxDecoration(
          color: card,

          borderRadius:
              BorderRadius.circular(20),

          border: Border.all(
            color: border,
          ),
        ),

        child: const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,

              child:
                  CircularProgressIndicator(
                strokeWidth: 2,
                color: primary,
              ),
            ),

            SizedBox(width: 12),

            Expanded(
              child: Text(
                'Loading live pricing...',
                style: TextStyle(
                  color: body,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(17),

      decoration: BoxDecoration(
        color: warningBg,

        borderRadius:
            BorderRadius.circular(20),

        border: Border.all(
          color: const Color(0xFFF1E0C9),
        ),
      ),

      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: warning,
          ),

          const SizedBox(width: 11),

          Expanded(
            child: Text(
              message ??
                  _pricingError ??
                  'Pricing details are currently unavailable.',

              style: const TextStyle(
                color: Color(0xFF765522),
                fontSize: 10,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          const SizedBox(width: 5),

          TextButton(
            onPressed:
                _loadPricingProfile,

            child: const Text(
              'Retry',

              style: TextStyle(
                color: primary,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // FORMATTING
  // ===========================================================================

  String _formatAmount(double value) {
    if (!value.isFinite) {
      return '0';
    }

    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }

  String _formatNumber(int value) {
    final text = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      if (i > 0 && (text.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(text[i]);
    }
    return buffer.toString();
  }

  String _formatKm(int value) {
    if (value >= 1000 &&
        value % 1000 == 0) {
      return '${value ~/ 1000}K';
    }

    return value.toString();
  }

  String _formatDate(DateTime value) {
    final day =
        value.day.toString().padLeft(2, '0');

    final month =
        value.month.toString().padLeft(2, '0');

    return '$day/$month/${value.year}';
  }

  double? _firstMapValue(
    Map<String, double> values,
  ) {
    for (final value in values.values) {
      if (value >= 0) {
        return value;
      }
    }

    return null;
  }
}

// ============================================================================
// FULL SCREEN IMAGE GALLERY
// ============================================================================

class _CarImageGalleryScreen
    extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final String carName;

  const _CarImageGalleryScreen({
    required this.images,
    required this.initialIndex,
    required this.carName,
  });

  @override
  State<_CarImageGalleryScreen> createState() =>
      _CarImageGalleryScreenState();
}

class _CarImageGalleryScreenState
    extends State<_CarImageGalleryScreen> {
  late final PageController
      _controller;

  late int _currentIndex;

  @override
  void initState() {
    super.initState();

    _currentIndex =
        widget.initialIndex;

    _controller = PageController(
      initialPage:
          widget.initialIndex,
    );
  }

  @override
  void dispose() {
    _controller.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,

        title: Text(
          widget.carName,

          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),

        actions: [
          Padding(
            padding:
                const EdgeInsets.only(
              right: 16,
            ),

            child: Center(
              child: Text(
                '${_currentIndex + 1}/${widget.images.length}',

                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),

      body: PageView.builder(
        controller: _controller,

        itemCount:
            widget.images.length,

        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },

        itemBuilder: (_, index) {
          return InteractiveViewer(
            minScale: 1,
            maxScale: 4,

            child: Center(
              child: Image.network(
                widget.images[index],

                fit: BoxFit.contain,

                errorBuilder:
                    (_, __, ___) {
                  return const Icon(
                    Icons
                        .broken_image_outlined,
                    color: Colors.white54,
                    size: 70,
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

