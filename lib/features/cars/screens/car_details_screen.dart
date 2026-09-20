import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../booking/screens/date_time_screen.dart';
import '../../pricing/manager/pricing_manager.dart';
import '../../pricing/models/km_pricing_package.dart';
import '../../pricing/models/pricing_profile.dart';
import '../models/car.dart';

/// Customer-facing vehicle details screen.
///
/// Pricing is intentionally aligned with the simplified rental model:
/// - Rental types: hourly + daily only
/// - Each rental type uses KM packages
/// - Daily packages define included KM per day
/// - Extra KM is charged from the selected package
/// - Date-range special rates can override normal prices
/// - Security deposit is displayed separately from the trip total
///
/// This screen is presentation-only. The final amount is recalculated by the
/// booking/pricing flow after the customer selects dates, package and options.
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
  static const Color primary = Color(0xFF0F766E);
  static const Color accent = Color(0xFF14B8A6);
  static const Color background = Color(0xFFF8FAF9);
  static const Color card = Color(0xFFFFFFFF);
  static const Color softAccent = Color(0xFFE6FFFB);
  static const Color heading = Color(0xFF17201F);
  static const Color body = Color(0xFF66706E);
  static const Color muted = Color(0xFF94A09D);
  static const Color border = Color(0xFFE5EBE9);

  PricingProfile? _pricingProfile;
  KmPricingPackage? _selectedPackage;

  bool _isFavorite = false;
  bool _showAllPackages = false;
  bool _isPricingLoading = true;
  String? _pricingError;

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
        throw Exception('Tenant configuration is missing.');
      }

      final pricingProfileId = widget.car.pricingProfileId.trim();
      if (pricingProfileId.isEmpty) {
        throw Exception(
          'Pricing profile is not configured for this vehicle.',
        );
      }

      final pricing = await PricingManager.instance.loadPricingForCar(
        tenantId: tenantId,
        pricingProfileId: pricingProfileId,
      );

      if (!mounted) return;

      if (pricing == null) {
        setState(() {
          _pricingProfile = null;
          _selectedPackage = null;
          _isPricingLoading = false;
          _pricingError =
              'Pricing details are unavailable for this vehicle.';
        });
        return;
      }

      // Prefer a daily package for the customer-facing vehicle summary,
      // because daily rental is the most common display price.
      final packages = <KmPricingPackage>[
        ...pricing.dailyPackages,
      ];

      KmPricingPackage? selected;
      if (packages.isNotEmpty) {
        selected = packages.firstWhere(
          (p) => p.isActive,
          orElse: () => packages.first,
        );
      }

      setState(() {
        _pricingProfile = pricing;
        _selectedPackage = selected;
        _isPricingLoading = false;
        _pricingError = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _pricingProfile = null;
        _selectedPackage = null;
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

  @override
  Widget build(BuildContext context) {
    final car = widget.car;

    return Scaffold(
      backgroundColor: background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: _buildContent(car, _pricingProfile),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(car),
    );
  }

  // ---------------------------------------------------------------------------
  // APP BAR
  // ---------------------------------------------------------------------------

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
            iconColor: _isFavorite ? Colors.redAccent : heading,
            onTap: () {
              setState(() => _isFavorite = !_isFavorite);
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
      color: Colors.white.withValues(alpha: 0.94),
      shape: const CircleBorder(),
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

  Widget _buildHeroImage() {
    final car = widget.car;

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          car.image,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: const Color(0xFFEFF4F3),
            child: const Center(
              child: Icon(
                Icons.directions_car_outlined,
                size: 72,
                color: muted,
              ),
            ),
          ),
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;

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
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.58),
              ],
            ),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 22,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  car.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _availabilityBadge(car.isAvailable),
            ],
          ),
        ),
      ],
    );
  }

  Widget _availabilityBadge(bool isAvailable) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isAvailable ? 'AVAILABLE' : 'UNAVAILABLE',
        style: TextStyle(
          color: isAvailable ? primary : Colors.redAccent,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CONTENT
  // ---------------------------------------------------------------------------

  Widget _buildContent(Car car, PricingProfile? pricing) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitleSection(car, pricing),
          const SizedBox(height: 22),
          _buildSpecs(car),
          const SizedBox(height: 24),
          _buildRentalTypesSection(pricing),
          const SizedBox(height: 24),
          _buildPackagesSection(pricing),
          const SizedBox(height: 24),
          _buildSpecialRatesSection(pricing),
          const SizedBox(height: 24),
          _buildDepositSection(pricing),
          const SizedBox(height: 24),
          _buildRentalInformation(),
          const SizedBox(height: 24),
          _buildPricingNote(),
        ],
      ),
    );
  }

  Widget _buildTitleSection(
    Car car,
    PricingProfile? pricing,
  ) {
    final package = _selectedPackage;
    final dailyRate = package?.safeDailyRate ??
        _firstPositiveDailyRate(pricing) ??
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
        if (dailyRate > 0) ...[
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
                package != null ? 'per day • ${package.name}' : 'per day',
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
      ],
    );
  }

  double? _firstPositiveDailyRate(PricingProfile? pricing) {
    if (pricing == null) return null;

    for (final package in pricing.dailyPackages) {
      if (package.safeDailyRate > 0) return package.safeDailyRate;
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // CAR SPECS
  // ---------------------------------------------------------------------------

  Widget _buildSpecs(Car car) {
    return Container(
      padding: const EdgeInsets.all(18),
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
            borderRadius: BorderRadius.circular(13),
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
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: muted,
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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

  // ---------------------------------------------------------------------------
  // RENTAL TYPES
  // ---------------------------------------------------------------------------

  Widget _buildRentalTypesSection(PricingProfile? pricing) {
    if (pricing == null) return _buildPricingUnavailable();

    final hourly = pricing.hourlyPackages.any((p) => p.isActive && p.safeHourlyRate > 0);
    final daily = pricing.dailyPackages.any((p) => p.isActive && p.safeDailyRate > 0);

    if (!hourly && !daily) {
      return _buildPricingUnavailable(
        message: 'No active hourly or daily rental pricing is configured.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          'Rental options',
          'Choose hourly or daily rental during booking',
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (hourly)
              Expanded(
                child: _rentalTypeCard(
                  Icons.schedule_outlined,
                  'Hourly',
                  'Flexible short trips',
                ),
              ),
            if (hourly && daily) const SizedBox(width: 10),
            if (daily)
              Expanded(
                child: _rentalTypeCard(
                  Icons.today_outlined,
                  'Daily',
                  'KM included per day',
                  highlighted: true,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _rentalTypeCard(
    IconData icon,
    String title,
    String subtitle, {
    bool highlighted = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlighted ? softAccent : card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: highlighted ? primary : border,
          width: highlighted ? 1.2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: highlighted ? Colors.white : background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: heading,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: body,
                    fontSize: 9,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PACKAGES
  // ---------------------------------------------------------------------------

  Widget _buildPackagesSection(PricingProfile? pricing) {
    if (pricing == null) return const SizedBox.shrink();

    final packages = pricing.dailyPackages
        .where((p) => p.isActive)
        .toList();

    final hourlyPackages = pricing.hourlyPackages
        .where((p) => p.isActive)
        .toList();

    if (packages.isEmpty && hourlyPackages.isEmpty) {
      return const SizedBox.shrink();
    }

    final visibleDaily = _showAllPackages
        ? packages
        : packages.take(3).toList();

    final remaining = packages.length - visibleDaily.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          'KM packages',
          'Select the package that fits your rental',
        ),
        const SizedBox(height: 12),
        if (packages.isNotEmpty)
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
                for (var i = 0; i < visibleDaily.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _packageCard(
                    visibleDaily[i],
                    rentalType: 'daily',
                  ),
                ],
                if (remaining > 0) ...[
                  const SizedBox(height: 10),
                  _smallExpandButton(
                    expanded: _showAllPackages,
                    label: _showAllPackages
                        ? 'Show fewer packages'
                        : 'View all ${packages.length} daily packages',
                    onTap: () {
                      setState(() {
                        _showAllPackages = !_showAllPackages;
                      });
                    },
                  ),
                ],
                if (hourlyPackages.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _packageSubheading(
                    'Hourly packages',
                    '${hourlyPackages.length} active package${hourlyPackages.length == 1 ? '' : 's'}',
                  ),
                  const SizedBox(height: 8),
                  for (var i = 0; i < hourlyPackages.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    _hourlyPackageCard(hourlyPackages[i]),
                  ],
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _packageCard(
    KmPricingPackage package, {
    required String rentalType,
  }) {
    final selected = _selectedPackage?.id == package.id;
    final kmText = package.unlimitedKm
        ? 'Unlimited KM'
        : '${_formatKm(package.safeIncludedKm)} KM included per day';

    final rate = package.safeDailyRate;
    final extra = package.unlimitedKm
        ? 'No extra KM charge'
        : '₹${_formatAmount(package.safeExtraKmRate)} / KM extra';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          setState(() {
            _selectedPackage = package;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? softAccent : const Color(0xFFF3F6F5),
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
                    Text(
                      package.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: heading,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
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
                      '₹${_formatAmount(rate)} / day',
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
                  Text(
                    extra,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
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

  Widget _hourlyPackageCard(KmPricingPackage package) {
    final rate = package.safeHourlyRate;
    final kmText = package.unlimitedKm
        ? 'Unlimited KM'
        : '${_formatKm(package.safeIncludedKm)} KM included';

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.schedule_outlined,
            size: 18,
            color: primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  package.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: heading,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
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
              ],
            ),
          ),
          Text(
            '₹${_formatAmount(rate)} / hr',
            style: const TextStyle(
              color: primary,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _packageSubheading(String title, String subtitle) {
    return Row(
      children: [
        const Icon(
          Icons.access_time_rounded,
          color: primary,
          size: 17,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: heading,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Text(
          subtitle,
          style: const TextStyle(
            color: muted,
            fontSize: 8,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // SPECIAL RATES
  // ---------------------------------------------------------------------------

  Widget _buildSpecialRatesSection(PricingProfile? pricing) {
    if (pricing == null) return const SizedBox.shrink();

    final rates = pricing.specialRates
        .where((rate) => rate.isActive)
        .toList();

    if (rates.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: border),
          ),
          child: Column(
            children: [
              for (var i = 0; i < rates.length; i++) ...[
                if (i > 0) const Divider(height: 20, color: border),
                _specialRateRow(rates[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _specialRateRow(SpecialRate rate) {
    final dateText =
        '${_formatDate(rate.startDate)} – ${_formatDate(rate.endDate)}';

    final hourly = _firstMapValue(rate.hourlyPrices);
    final daily = _firstMapValue(rate.dailyPrices);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: softAccent,
            borderRadius: BorderRadius.circular(12),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                rate.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
              const SizedBox(height: 5),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (hourly != null)
                    _rateChip('Hourly ₹${_formatAmount(hourly)}'),
                  if (daily != null)
                    _rateChip('Daily ₹${_formatAmount(daily)}'),
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
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: border),
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

  double? _firstMapValue(Map<String, double> values) {
    for (final value in values.values) {
      if (value >= 0) return value;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // SECURITY DEPOSIT
  // ---------------------------------------------------------------------------

  Widget _buildDepositSection(PricingProfile? pricing) {
    if (pricing == null) return const SizedBox.shrink();

    final deposit = pricing.securityDeposit;
    final isNone = deposit.type == DepositType.none;

    String title;
    String subtitle;
    String amount = '';

    if (isNone) {
      title = 'No security deposit';
      subtitle = 'No separate security deposit is configured.';
    } else if (deposit.isMonetary) {
      title = 'Refundable security deposit';
      subtitle = deposit.paymentMethod.isNotEmpty
          ? 'Collected separately • ${deposit.paymentMethod}'
          : 'Collected separately from the rental amount.';
      amount = '₹${_formatAmount(deposit.amount)}';
    } else {
      title = deposit.type == DepositType.vehicleAsset
          ? 'Vehicle / bike as security'
          : 'Other asset as security';

      subtitle = deposit.minimumAssetValue > 0
          ? 'Minimum asset value ₹${_formatAmount(deposit.minimumAssetValue)}'
          : 'Asset details will be collected during the booking process.';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F6F5),
              borderRadius: BorderRadius.circular(14),
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
                  subtitle,
                  style: const TextStyle(
                    color: body,
                    fontSize: 10,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (amount.isNotEmpty) ...[
            const SizedBox(width: 10),
            Text(
              amount,
              style: const TextStyle(
                color: heading,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // RENTAL INFORMATION
  // ---------------------------------------------------------------------------

  Widget _buildRentalInformation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          'Rental information',
          'The final amount is calculated during booking',
        ),
        const SizedBox(height: 13),
        Container(
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: border),
          ),
          child: const Column(
            children: [
              _StaticInfoRow(
                icon: Icons.payments_outlined,
                title: 'Pricing',
                value: 'Package based',
              ),
              Divider(height: 1, color: border),
              _StaticInfoRow(
                icon: Icons.speed_outlined,
                title: 'Extra KM',
                value: 'Package rate',
              ),
              Divider(height: 1, color: border),
              _StaticInfoRow(
                icon: Icons.event_repeat_outlined,
                title: 'Special dates',
                value: 'Date-range rules',
              ),
              Divider(height: 1, color: border),
              _StaticInfoRow(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Deposit',
                value: 'Separate from trip total',
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // NOTE
  // ---------------------------------------------------------------------------

  Widget _buildPricingNote() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F6F5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.verified_outlined,
            size: 18,
            color: primary,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'The final booking price is calculated after you select rental dates, time, rental type, KM package, add-ons, protection, discounts and applicable taxes. The security deposit remains separate from the trip total.',
              style: TextStyle(
                color: body,
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

  // ---------------------------------------------------------------------------
  // SECTION TITLE / SMALL UI
  // ---------------------------------------------------------------------------

  Widget _sectionTitle(
    String title,
    String subtitle,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: heading,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: const TextStyle(
            color: muted,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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

  Widget _buildPricingUnavailable({String? message}) {
    if (_isPricingLoading) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
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
              message ??
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

  // ---------------------------------------------------------------------------
  // BOTTOM ACTION
  // ---------------------------------------------------------------------------

  Widget _buildBottomBar(Car car) {
    final enabled = car.isAvailable &&
        !_isPricingLoading &&
        _pricingProfile != null;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          20,
          12,
          20,
          12,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: border),
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
            onPressed: enabled ? _chooseDateTime : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Color(0xFFD7DEDC),
              disabledForegroundColor: Color(0xFF7D8986),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(17),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  enabled
                      ? 'Choose date & time'
                      : _isPricingLoading
                          ? 'Loading pricing...'
                          : 'Currently unavailable',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (enabled) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_rounded,
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

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DateTimeScreen(
          car: widget.car,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FORMATTING
  // ---------------------------------------------------------------------------

  String _formatAmount(double value) {
    if (!value.isFinite) return '0';

    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }

  String _formatKm(int value) {
    if (value >= 1000 && value % 1000 == 0) {
      return '${value ~/ 1000}K';
    }
    return value.toString();
  }

  String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }
}

class _StaticInfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _StaticInfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  static const Color primary = Color(0xFF0F766E);
  static const Color heading = Color(0xFF17201F);
  static const Color body = Color(0xFF66706E);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: body,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
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
    );
  }
}
