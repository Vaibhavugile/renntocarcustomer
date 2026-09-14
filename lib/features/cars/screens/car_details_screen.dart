import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../pricing/manager/pricing_manager.dart';
import '../../pricing/models/km_pricing_package.dart';
import '../../pricing/models/pricing_profile.dart';
import '../models/car.dart';
import '../../booking/screens/date_time_screen.dart';

class CarDetailsScreen extends StatefulWidget {
  final Car car;

  const CarDetailsScreen({
    super.key,
    required this.car,
  });

  @override
  State<CarDetailsScreen> createState() =>
      _CarDetailsScreenState();
}

class _CarDetailsScreenState
    extends State<CarDetailsScreen> {
  static const Color primary =
      Color(0xFF0F766E);

  static const Color accent =
      Color(0xFF14B8A6);

  static const Color background =
      Color(0xFFF8FAF9);

  static const Color card =
      Color(0xFFFFFFFF);

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

  PricingProfile? _pricingProfile;

  bool _isFavorite = false;

  bool _showAllRates = false;
  bool _showAllKmPackages = false;

  bool _isPricingLoading = true;

  String? _pricingError;

  // Customer's selected KM pricing package.
  KmPricingPackage? _selectedKmPackage;

  bool _unlimitedKmSelected = false;

  String get _tenantId => AppConfig.tenant.tenantId;

  @override
  void initState() {
    super.initState();
    _loadPricingProfile();
  }

  Future<void> _loadPricingProfile() async {
    if (!mounted) return;

    setState(() {
      _isPricingLoading = true;
      _pricingError = null;
    });

    try {
      final tenantId = _tenantId.trim();

      if (tenantId.isEmpty) {
        throw Exception(
          'Tenant configuration is missing.',
        );
      }

      final pricingProfileId =
          widget.car.pricingProfileId.trim();

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

      KmPricingPackage? selectedPackage;

      if (pricing.kmPricingMode == KmPricingMode.package &&
          pricing.kmPackages.isNotEmpty) {
        try {
          selectedPackage = pricing.kmPackages.firstWhere(
            (package) => !package.unlimitedKm,
          );
        } catch (_) {
          selectedPackage = pricing.kmPackages.first;
        }
      }

      setState(() {
        _pricingProfile = pricing;
        _selectedKmPackage = selectedPackage;
        _unlimitedKmSelected =
            selectedPackage?.unlimitedKm ?? false;
        _isPricingLoading = false;
        _pricingError = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _pricingProfile = null;
        _selectedKmPackage = null;
        _unlimitedKmSelected = false;
        _isPricingLoading = false;
        _pricingError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final car = widget.car;

    return Scaffold(
      backgroundColor: background,
      body: CustomScrollView(
        physics:
            const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: _buildContent(
              car,
              _pricingProfile,
            ),
          ),
        ],
      ),
      bottomNavigationBar:
          _buildBottomBar(car),
    );
  }

  // ------------------------------------------------------------
  // APP BAR
  // ------------------------------------------------------------

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 310,
      pinned: true,
      backgroundColor: background,
      foregroundColor: heading,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: _circleButton(
          icon: Icons.arrow_back_rounded,
          onTap: () {
            Navigator.pop(context);
          },
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: _circleButton(
            icon: _isFavorite
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            iconColor: _isFavorite
                ? Colors.redAccent
                : heading,
            onTap: () {
              setState(() {
                _isFavorite = !_isFavorite;
              });
            },
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: _buildHeroImage(),
      ),
    );
  }

  Widget _circleButton({
    required IconData icon,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return Material(
      color: Colors.white.withValues(
        alpha: 0.94,
      ),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder:
            const CircleBorder(),
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

  // ------------------------------------------------------------
  // HERO IMAGE
  // ------------------------------------------------------------

  Widget _buildHeroImage() {
    final car = widget.car;

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          car.image,
          fit: BoxFit.cover,
          errorBuilder: (
            context,
            error,
            stackTrace,
          ) {
            return Container(
              color: const Color(0xFFEFF4F3),
              child: const Center(
                child: Icon(
                  Icons
                      .directions_car_outlined,
                  size: 72,
                  color: muted,
                ),
              ),
            );
          },
          loadingBuilder: (
            context,
            child,
            loadingProgress,
          ) {
            if (loadingProgress == null) {
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

        // Image overlay
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin:
                  Alignment.topCenter,
              end:
                  Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValues(
                  alpha: 0.58,
                ),
              ],
            ),
          ),
        ),

        Positioned(
          left: 20,
          right: 20,
          bottom: 22,
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  car.name,
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    height: 1.05,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _availabilityBadge(
                car.isAvailable,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _availabilityBadge(
    bool isAvailable,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: Colors.white
            .withValues(alpha: 0.94),
        borderRadius:
            BorderRadius.circular(12),
      ),
      child: Text(
        isAvailable
            ? 'AVAILABLE'
            : 'UNAVAILABLE',
        style: TextStyle(
          color: isAvailable
              ? primary
              : Colors.redAccent,
          fontSize: 9,
          fontWeight:
              FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // CONTENT
  // ------------------------------------------------------------

  Widget _buildContent(
    Car car,
    PricingProfile? pricing,
  ) {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        20,
        22,
        20,
        36,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _buildTitleSection(
            car,
            pricing,
          ),

          const SizedBox(height: 22),

          _buildSpecs(car),

          const SizedBox(height: 24),

          _buildPricingSection(
            pricing,
          ),

          const SizedBox(height: 24),

          _buildKmSection(
            pricing,
          ),

          const SizedBox(height: 24),

          _buildDepositSection(
            pricing,
          ),

          const SizedBox(height: 24),

          _buildRentalInformation(
            pricing,
          ),

          const SizedBox(height: 24),

          _buildPricingNote(),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // TITLE
  // ------------------------------------------------------------

  Widget _buildTitleSection(
    Car car,
    PricingProfile? pricing,
  ) {
    final package = _selectedKmPackage;

    final dailyRate = package?.dailyRate ??
        pricing?.dailyRate ??
        car.pricePerDay.toDouble();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                car.type.toUpperCase(),
                style: const TextStyle(
                  color: primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                car.name,
                style: const TextStyle(
                  color: heading,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₹${_formatAmount(dailyRate)}',
              style: const TextStyle(
                color: primary,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              package != null
                  ? 'per day • ${package.name}'
                  : 'starting / day',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: body,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // CAR SPECS
  // ------------------------------------------------------------

  Widget _buildSpecs(Car car) {
    return Container(
      padding:
          const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: card,
        borderRadius:
            BorderRadius.circular(22),
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
              car.transmission,
            ),
          ),
          _verticalDivider(),
          Expanded(
            child: _specItem(
              Icons.event_seat_outlined,
              'Seats',
              '${car.seats}',
            ),
          ),
          _verticalDivider(),
          Expanded(
            child: _specItem(
              Icons.local_gas_station_outlined,
              'Fuel',
              car.fuel,
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
          width: 40,
          height: 40,
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
            fontWeight:
                FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow:
              TextOverflow.ellipsis,
          style: const TextStyle(
            color: heading,
            fontSize: 11,
            fontWeight:
                FontWeight.w800,
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

  // ------------------------------------------------------------
  // PRICING
  // ------------------------------------------------------------

  Widget _buildPricingSection(PricingProfile? pricing) {
    if (pricing == null) return _buildPricingUnavailable();

    final package = _selectedKmPackage;
    final hourly = package?.hourlyRate ?? pricing.hourlyRate;
    final daily = package?.dailyRate ?? pricing.dailyRate;
    final weekend = package?.weekendRate ?? pricing.weekendRate;
    final weekly = package?.weeklyRate ?? pricing.weeklyRate;
    final monthly = package?.monthlyRate ?? pricing.monthlyRate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          'Rental pricing',
          package == null
              ? 'Current rates for this vehicle'
              : '${package.name} package selected',
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0717201F),
                blurRadius: 18,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: Column(
            children: [
              _selectedRateHeader(package: package, daily: daily),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                child: _showAllRates
                    ? Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Column(
                          children: [
                            _compactRateRow(
                              Icons.schedule_outlined,
                              'Hourly',
                              '₹${_formatAmount(hourly)}',
                              'per hour',
                            ),
                            _compactRateRow(
                              Icons.today_outlined,
                              'Daily',
                              '₹${_formatAmount(daily)}',
                              'per day',
                              highlighted: true,
                            ),
                            _compactRateRow(
                              Icons.date_range_outlined,
                              'Weekend',
                              '₹${_formatAmount(weekend)}',
                              'weekend rate',
                            ),
                            _compactRateRow(
                              Icons.view_week_outlined,
                              'Weekly',
                              '₹${_formatAmount(weekly)}',
                              'per week',
                            ),
                            _compactRateRow(
                              Icons.calendar_month_outlined,
                              'Monthly',
                              '₹${_formatAmount(monthly)}',
                              'per month',
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: 8),
              _smallExpandButton(
                expanded: _showAllRates,
                label: _showAllRates
                    ? 'Hide hourly, daily & more'
                    : 'View hourly, daily, weekend, weekly & monthly',
                onTap: () {
                  setState(() => _showAllRates = !_showAllRates);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _selectedRateHeader({
    required KmPricingPackage? package,
    required double daily,
  }) {
    final title = package == null
        ? 'Current daily price'
        : package.unlimitedKm
            ? 'Unlimited KM'
            : '${_formatKm(package.includedKm ?? 0)} KM package';

    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: softAccent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.payments_outlined,
            color: primary,
            size: 21,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: heading,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                package?.name ?? 'Vehicle pricing',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: body,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _isPricingLoading
                  ? '—'
                  : '₹${_formatAmount(daily)}',
              style: const TextStyle(
                color: primary,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Text(
              'per day',
              style: TextStyle(
                color: muted,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _compactRateRow(
    IconData icon,
    String title,
    String value,
    String subtitle, {
    bool highlighted = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: highlighted ? softAccent : background,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: highlighted ? primary : border,
          width: highlighted ? 1.1 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 17,
            color: highlighted ? primary : body,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: heading,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(
              color: muted,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            style: TextStyle(
              color: highlighted ? primary : heading,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallExpandButton({
    required bool expanded,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 5),
              Icon(
                expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: primary,
                size: 17,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPricingUnavailable() {
    if (_isPricingLoading) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: border,
          ),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
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
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F0),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFF1E0C9),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFF9A6B28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _pricingError ??
                  'Pricing details are currently unavailable for this vehicle.',
              style: const TextStyle(
                color: Color(0xFF765522),
                fontSize: 11,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _loadPricingProfile,
            child: const Text(
              'Retry',
              style: TextStyle(
                color: primary,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // KM
  // ------------------------------------------------------------

  Widget _buildKmSection(PricingProfile? pricing) {
    if (pricing == null) return const SizedBox.shrink();

    final packages = [...pricing.kmPackages];

    if (pricing.kmPricingMode != KmPricingMode.package ||
        packages.isEmpty) {
      return _buildLegacyKmSection(pricing);
    }

    final selected = _selectedKmPackage ?? packages.first;
    final remaining = packages
        .where((package) => package.id != selected.id)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          'KM package',
          'Choose the allowance that fits your trip',
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0717201F),
                blurRadius: 18,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: Column(
            children: [
              // The selected/first package is always shown first.
              _kmPackageCard(selected),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                child: _showAllKmPackages && remaining.isNotEmpty
                    ? Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Column(
                          children: remaining
                              .map(
                                (package) => Padding(
                                  padding:
                                      const EdgeInsets.only(top: 8),
                                  child: _kmPackageCard(package),
                                ),
                              )
                              .toList(),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              if (remaining.isNotEmpty) ...[
                const SizedBox(height: 8),
                _smallExpandButton(
                  expanded: _showAllKmPackages,
                  label: _showAllKmPackages
                      ? 'Show selected package only'
                      : 'View all ${packages.length} KM packages',
                  onTap: () {
                    setState(() {
                      _showAllKmPackages = !_showAllKmPackages;
                    });
                  },
                ),
              ],
              const SizedBox(height: 9),
              _buildSelectedKmSummary(pricing),
              const SizedBox(height: 9),
              _buildExtraKmInfo(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _kmPackageCard(
    KmPricingPackage package,
  ) {
    final selected = _selectedKmPackage?.id == package.id;

    final kmText = package.unlimitedKm
        ? 'Unlimited KM'
        : '${_formatKm(package.includedKm ?? 0)} KM included';

    final dailyText = package.dailyRate > 0
        ? '₹${_formatAmount(package.dailyRate)} / day'
        : 'Daily pricing available';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          setState(() {
            _selectedKmPackage = package;
            _unlimitedKmSelected = package.unlimitedKm;
            _showAllKmPackages = false;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? softAccent
                : const Color(0xFFF3F6F5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? primary : border,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  package.unlimitedKm
                      ? Icons.all_inclusive_rounded
                      : Icons.speed_rounded,
                  size: 18,
                  color: primary,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            package.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: heading,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (package.name.toLowerCase() == 'basic') ...[
                          const SizedBox(width: 7),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: primary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'STARTER',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 7,
                                fontWeight: FontWeight.w900,
                                letterSpacing: .4,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      kmText,
                      style: const TextStyle(
                        color: body,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dailyText,
                      style: const TextStyle(
                        color: primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 19,
                    color: selected ? primary : muted,
                  ),
                  const SizedBox(height: 5),
                  if (!package.unlimitedKm)
                    Text(
                      '₹${_formatAmount(package.extraKmRate)}/KM extra',
                      style: const TextStyle(
                        color: body,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  else
                    const Text(
                      'No extra KM',
                      style: TextStyle(
                        color: body,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExtraKmInfo() {
    final package = _selectedKmPackage;

    if (package == null) {
      return const SizedBox.shrink();
    }

    final text = package.unlimitedKm
        ? 'Unlimited KM selected. No extra KM charge applies.'
        : 'After ${_formatKm(package.includedKm ?? 0)} KM, extra usage is charged at ₹${_formatAmount(package.extraKmRate)} / KM.';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F6F5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: body,
                fontSize: 9,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Legacy KM UI is retained for Firebase pricing profiles that use a
  // non-package KM pricing mode.
  Widget _buildLegacyKmSection(
    PricingProfile pricing,
  ) {
    final options = [...pricing.kmOptions]..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          'KM policy',
          'Flexible KM allowances for your booking',
        ),
        const SizedBox(height: 13),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose your KM allowance',
                style: TextStyle(
                  color: heading,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              if (options.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: options.map((km) {
                    return _kmOptionChip(
                      label: '${_formatKm(km)} KM',
                      selected: !_unlimitedKmSelected &&
                          pricing.includedKmPerDay == km,
                      onTap: () {
                        setState(() {
                          _unlimitedKmSelected = false;
                        });
                      },
                    );
                  }).toList(),
                ),
              if (pricing.unlimitedKmEnabled) ...[
                const SizedBox(height: 10),
                _unlimitedKmCard(
                  surcharge: pricing.unlimitedKmSurcharge,
                  selected: _unlimitedKmSelected,
                  onTap: () {
                    setState(() {
                      _unlimitedKmSelected = true;
                      _selectedKmPackage = null;
                    });
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _kmOptionChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(
            horizontal: 13,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: selected ? softAccent : const Color(0xFFF3F6F5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? primary : border,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 15,
                color: selected ? primary : muted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: heading,
                  fontSize: 10,
                  fontWeight:
                      selected ? FontWeight.w900 : FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _unlimitedKmCard({
    required double surcharge,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 13,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: selected ? softAccent : const Color(0xFFF3F6F5),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: selected ? primary : border,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.all_inclusive_rounded,
                size: 18,
                color: primary,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Unlimited KM',
                  style: TextStyle(
                    color: heading,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                surcharge > 0
                    ? '+₹${_formatAmount(surcharge)} / day'
                    : 'Included',
                style: const TextStyle(
                  color: primary,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 18,
                color: selected ? primary : muted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatKm(int value) {
    if (value >= 1000 && value % 1000 == 0) {
      return '${value ~/ 1000}K';
    }

    return value.toString();
  }

  Widget _buildSelectedKmSummary(
    PricingProfile pricing,
  ) {
    final package = _selectedKmPackage;

    final String value;
    final String extra;

    if (package != null) {
      value = package.unlimitedKm
          ? 'Unlimited KM'
          : '${_formatKm(package.includedKm ?? 0)} KM';

      extra = package.unlimitedKm
          ? 'No extra KM charge'
          : '₹${_formatAmount(package.extraKmRate)} / KM after allowance';
    } else if (_unlimitedKmSelected) {
      value = 'Unlimited KM';
      extra = 'Unlimited legacy pricing';
    } else {
      value = 'Default allowance';
      extra = 'Based on vehicle pricing policy';
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 11,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            size: 17,
            color: primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Selected package',
                  style: TextStyle(
                    color: body,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: heading,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Text(
            extra,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: primary,
              fontSize: 8,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // SECURITY DEPOSIT
  // ------------------------------------------------------------

  Widget _buildDepositSection(
    PricingProfile? pricing,
  ) {
    if (pricing == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding:
          const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: card,
        borderRadius:
            BorderRadius.circular(22),
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
              color: const Color(
                0xFFF3F6F5,
              ),
              borderRadius:
                  BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons
                  .account_balance_wallet_outlined,
              color: primary,
            ),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Security deposit',
                  style: TextStyle(
                    color: heading,
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Refundable security deposit may apply to the booking.',
                  style: TextStyle(
                    color: body,
                    fontSize: 10,
                    height: 1.4,
                    fontWeight:
                        FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '₹${_formatAmount(pricing.securityDeposit)}',
            style: const TextStyle(
              color: heading,
              fontSize: 14,
              fontWeight:
                  FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // RENTAL INFORMATION
  // ------------------------------------------------------------

  Widget _buildRentalInformation(
    PricingProfile? pricing,
  ) {
    if (pricing == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          'Rental information',
          'Important pricing conditions',
        ),

        const SizedBox(height: 13),

        Container(
          decoration: BoxDecoration(
            color: card,
            borderRadius:
                BorderRadius.circular(22),
            border: Border.all(
              color: border,
            ),
          ),
          child: Column(
            children: [
              _infoRow(
                Icons
                    .hourglass_bottom_outlined,
                'Grace period',
                '${pricing.gracePeriodMinutes} minutes',
              ),
              _divider(),
              _infoRow(
                Icons
                    .access_time_rounded,
                'Extra hour',
                '₹${_formatAmount(pricing.extraHourRate)}',
              ),
              _divider(),
              _infoRow(
                Icons
                    .event_repeat_outlined,
                'Extra day',
                '₹${_formatAmount(pricing.extraDayRate)}',
              ),
              _divider(),
              _infoRow(
                Icons
                    .schedule_outlined,
                'Late return',
                '₹${_formatAmount(pricing.lateReturnRate)}',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _priceRow({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    bool highlighted = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: highlighted ? softAccent : background,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              icon,
              color: highlighted ? primary : body,
              size: 21,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: heading,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: highlighted ? primary : heading,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String title,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: accent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: body,
                fontSize: 11,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: heading,
              fontSize: 11,
              fontWeight:
                  FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return const Divider(
      height: 1,
      thickness: 1,
      color: border,
    );
  }

  // ------------------------------------------------------------
  // NOTE
  // ------------------------------------------------------------

  Widget _buildPricingNote() {
    return Container(
      padding:
          const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(
          0xFFF3F6F5,
        ),
        borderRadius:
            BorderRadius.circular(18),
      ),
      child: const Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            Icons
                .verified_outlined,
            size: 18,
            color: primary,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'The final booking price is calculated after you select your rental dates, time, KM/package, add-ons, protection, discounts and applicable taxes.',
              style: TextStyle(
                color: body,
                fontSize: 10,
                height: 1.5,
                fontWeight:
                    FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // SECTION TITLE
  // ------------------------------------------------------------

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
            fontWeight:
                FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: const TextStyle(
            color: muted,
            fontSize: 10,
            fontWeight:
                FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // BOTTOM BUTTON
  // ------------------------------------------------------------

  Widget _buildBottomBar(Car car) {
    return SafeArea(
      top: false,
      child: Container(
        padding:
            const EdgeInsets.fromLTRB(
          20,
          12,
          20,
          12,
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
              blurRadius: 16,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: SizedBox(
          height: 54,
          child: ElevatedButton(
            onPressed: car.isAvailable &&
                    !_isPricingLoading &&
                    _pricingProfile != null
                ? _chooseDateTime
                : null,
            style: ElevatedButton
                .styleFrom(
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
              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(
                  17,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                Text(
                  car.isAvailable &&
                          !_isPricingLoading &&
                          _pricingProfile !=
                              null
                      ? 'Choose date & time'
                      : _isPricingLoading
                          ? 'Loading pricing...'
                          : 'Currently unavailable',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                if (car.isAvailable &&
                    !_isPricingLoading &&
                    _pricingProfile !=
                        null) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons
                        .arrow_forward_rounded,
                    size: 18,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _chooseDateTime() {
    if (!widget.car.isAvailable ||
        _isPricingLoading ||
        _pricingProfile == null) {
      return;
    }

    /*
     * Continue into the real booking flow.
     *
     * The selected vehicle is passed to DateTimeScreen.
     * DateTimeScreen performs the live Firebase availability
     * check for this specific vehicle and then continues to
     * branch selection → pricing → review → payment.
     *
     * The selected KM package remains part of this screen's
     * pricing UI. The final booking pricing is calculated again
     * in the pricing flow before the booking is created.
     */
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DateTimeScreen(
          car: widget.car,
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // HELPERS
  // ------------------------------------------------------------

  String _formatAmount(double value) {
    if (value == value.roundToDouble()) {
      return value
          .toInt()
          .toString();
    }

    return value.toStringAsFixed(2);
  }
}