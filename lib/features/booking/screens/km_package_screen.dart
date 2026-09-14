import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../cars/models/car.dart';
import '../../pricing/models/km_pricing_package.dart';
import '../../pricing/models/pricing_profile.dart';
import '../../pricing/manager/pricing_manager.dart';
import '../../../models/branch.dart';
import 'pricing_screen.dart';

class KmPackageScreen extends StatefulWidget {
  final Car car;
  final String tenantId;
  final Branch branch;
  final DateTime pickupDateTime;
  final DateTime returnDateTime;

  const KmPackageScreen({
    super.key,
    required this.car,
    required this.tenantId,
    required this.branch,
    required this.pickupDateTime,
    required this.returnDateTime,
  });

  @override
  State<KmPackageScreen> createState() => _KmPackageScreenState();
}

class _KmPackageScreenState extends State<KmPackageScreen> {
  static const Color primary = Color(0xFF0F766E);
  static const Color accent = Color(0xFF14B8A6);
  static const Color background = Color(0xFFF8FAF9);
  static const Color card = Color(0xFFFFFFFF);
  static const Color softAccent = Color(0xFFE6FFFB);
  static const Color heading = Color(0xFF17201F);
  static const Color body = Color(0xFF66706E);
  static const Color muted = Color(0xFF94A09D);
  static const Color border = Color(0xFFE5EBE9);

  String get _tenantId => AppConfig.tenant.tenantId;

  PricingProfile? _pricingProfile;
  KmPricingPackage? _selectedPackage;

  bool _isLoading = true;
  bool _isContinuing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPricing();
  }

  Future<void> _loadPricing() async {
    try {
      final profile =
          await PricingManager.instance.loadPricingForCar(
        tenantId: _tenantId,
        pricingProfileId: widget.car.pricingProfileId,
      );

      if (!mounted) return;

      if (profile == null) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Pricing is currently unavailable for this vehicle.';
        });
        return;
      }

      final packages = profile.kmPackages;

      KmPricingPackage? initialPackage;

      if (packages.isNotEmpty) {
        initialPackage = packages.first;
      }

      setState(() {
        _pricingProfile = profile;
        _selectedPackage = initialPackage;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage =
            'Unable to load KM packages. Please try again.';
      });
    }
  }

  Future<void> _continue() async {
    final package = _selectedPackage;

    if (package == null) {
      setState(() {
        _errorMessage =
            'Please select a KM package to continue.';
      });
      return;
    }

    setState(() {
      _isContinuing = true;
      _errorMessage = null;
    });

    // The pricing profile was loaded from Firebase.
    // Before moving forward, make sure the selected package
    // still exists in the current pricing profile.
    try {
      final profile =
          await PricingManager.instance.loadPricingForCar(
        tenantId: _tenantId,
        pricingProfileId: widget.car.pricingProfileId,
      );

      if (!mounted) return;

      if (profile == null) {
        setState(() {
          _isContinuing = false;
          _errorMessage =
              'Vehicle pricing is no longer available.';
        });
        return;
      }

      final freshPackage =
          profile.getPackage(package.id);

      if (freshPackage == null) {
        setState(() {
          _isContinuing = false;
          _errorMessage =
              'This KM package is no longer available. Please select another package.';
          _pricingProfile = profile;
          _selectedPackage =
              profile.kmPackages.isNotEmpty
                  ? profile.kmPackages.first
                  : null;
        });
        return;
      }

      setState(() {
        _isContinuing = false;
        _pricingProfile = profile;
        _selectedPackage = freshPackage;
      });

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PricingScreen(
            car: widget.car,
            tenantId: _tenantId,
            branch: widget.branch,
            pickupDateTime: widget.pickupDateTime,
            returnDateTime: widget.returnDateTime,
            pricingProfile: profile,
            selectedKmPackage: freshPackage,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isContinuing = false;
        _errorMessage =
            'Unable to confirm pricing. Please try again.';
      });
    }
  }

  String _formatRate(double value) {
    if (value == value.roundToDouble()) {
      return '₹${value.toInt()}';
    }

    return '₹${value.toStringAsFixed(2)}';
  }

  String _formatKm(KmPricingPackage package) {
    if (package.unlimitedKm) {
      return 'Unlimited KM';
    }

    if (package.includedKm == null) {
      return 'KM package';
    }

    return '${package.includedKm} KM included';
  }

  String _extraKmText(KmPricingPackage package) {
    if (package.unlimitedKm ||
        package.extraKmRate <= 0) {
      return 'No extra KM charge';
    }

    return '${_formatRate(package.extraKmRate)} / extra KM';
  }

  String _formatDateTime(DateTime dateTime) {
    final hour =
        dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;

    final minute =
        dateTime.minute.toString().padLeft(2, '0');

    final period =
        dateTime.hour >= 12 ? 'PM' : 'AM';

    return '${dateTime.day.toString().padLeft(2, '0')}/'
        '${dateTime.month.toString().padLeft(2, '0')}/'
        '${dateTime.year} • '
        '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: heading,
          ),
        ),
        title: const Text(
          'Choose KM Package',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: heading,
          ),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: primary,
                ),
              )
            : _buildBody(),
      ),
      bottomNavigationBar:
          _isLoading || _pricingProfile == null
              ? null
              : _buildBottomButton(),
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null &&
        _pricingProfile == null) {
      return _buildFullError();
    }

    final packages =
        _pricingProfile?.kmPackages ?? [];

    if (packages.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      color: primary,
      onRefresh: _loadPricing,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          20,
          8,
          20,
          120,
        ),
        children: [
          _buildTripSummary(),
          const SizedBox(height: 24),
          _buildHeading(),
          const SizedBox(height: 14),
          if (_errorMessage != null) ...[
            _buildError(),
            const SizedBox(height: 12),
          ],
          ...packages.map(
            (package) => Padding(
              padding:
                  const EdgeInsets.only(bottom: 12),
              child: _buildPackageCard(package),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: softAccent,
                  borderRadius:
                      BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.directions_car_filled_rounded,
                  color: primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.car.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: heading,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.branch.name,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(
            height: 1,
            color: border,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 16,
                color: muted,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  _formatDateTime(
                    widget.pickupDateTime,
                  ),
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: body,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.keyboard_return_rounded,
                size: 16,
                color: muted,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  _formatDateTime(
                    widget.returnDateTime,
                  ),
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: body,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeading() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select your KM package',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: heading,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Choose the distance package that best fits your trip.',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: body,
          ),
        ),
      ],
    );
  }

  Widget _buildPackageCard(
    KmPricingPackage package,
  ) {
    final isSelected =
        _selectedPackage?.id == package.id;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedPackage = package;
          _errorMessage = null;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration:
            const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isSelected ? primary : border,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha:
                    isSelected ? 0.055 : 0.025,
              ),
              blurRadius:
                  isSelected ? 15 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(
                    milliseconds: 200,
                  ),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? primary
                        : softAccent,
                    borderRadius:
                        BorderRadius.circular(14),
                  ),
                  child: Icon(
                    package.unlimitedKm
                        ? Icons.all_inclusive_rounded
                        : Icons.speed_rounded,
                    color: isSelected
                        ? Colors.white
                        : primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              package.name,
                              style: const TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 15,
                                fontWeight:
                                    FontWeight.w800,
                                color: heading,
                              ),
                            ),
                          ),
                          _buildRadio(isSelected),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _formatKm(package),
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: isSelected
                    ? softAccent
                    : background,
                borderRadius:
                    BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildPriceItem(
                      'Hourly',
                      package.hourlyRate,
                    ),
                  ),
                  _buildVerticalDivider(),
                  Expanded(
                    child: _buildPriceItem(
                      'Daily',
                      package.dailyRate,
                    ),
                  ),
                  _buildVerticalDivider(),
                  Expanded(
                    child: _buildPriceItem(
                      'Weekend',
                      package.weekendRate,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.add_road_rounded,
                  size: 16,
                  color: muted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _extraKmText(package),
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: body,
                    ),
                  ),
                ),
                if (package.unlimitedKm)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: softAccent,
                      borderRadius:
                          BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'UNLIMITED',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: primary,
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

  Widget _buildPriceItem(
    String label,
    double value,
  ) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: muted,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          _formatRate(value),
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: heading,
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 28,
      color: border,
    );
  }

  Widget _buildRadio(bool selected) {
    return AnimatedContainer(
      duration:
          const Duration(milliseconds: 180),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? primary : border,
          width: 2,
        ),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 10,
                height: 10,
                decoration:
                    const BoxDecoration(
                  shape: BoxShape.circle,
                  color: primary,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFF1D6D6),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFB42318),
            size: 19,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: Color(0xFF8E2424),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.price_change_outlined,
              size: 48,
              color: muted,
            ),
            const SizedBox(height: 16),
            const Text(
              'Pricing unavailable',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: heading,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              _errorMessage ??
                  'Unable to load pricing.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 13,
                color: body,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadPricing,
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Try Again',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: const [
            Icon(
              Icons.route_outlined,
              size: 48,
              color: muted,
            ),
            SizedBox(height: 16),
            Text(
              'No KM packages available',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: heading,
              ),
            ),
            SizedBox(height: 7),
            Text(
              'There are currently no KM packages configured for this vehicle.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 13,
                height: 1.4,
                color: body,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButton() {
    final hasSelection =
        _selectedPackage != null;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(
        20,
        10,
        20,
        16,
      ),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: 0.06,
              ),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SizedBox(
          height: 54,
          child: ElevatedButton(
            onPressed:
                hasSelection && !_isContinuing
                    ? _continue
                    : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              disabledBackgroundColor:
                  const Color(0xFFD9E2E0),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(14),
              ),
            ),
            child: _isContinuing
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Continue',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 19,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}