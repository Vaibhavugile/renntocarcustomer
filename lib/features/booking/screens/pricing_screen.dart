import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../cars/models/car.dart';
import '../../pricing/models/km_pricing_package.dart';
import '../../pricing/models/pricing_config.dart';
import '../../pricing/models/pricing_profile.dart';
import '../../pricing/manager/pricing_manager.dart';
import '../../pricing/engine/pricing_engine.dart';
import '../../../models/branch.dart';
import 'review_booking_screen.dart';

class PricingScreen extends StatefulWidget {
  final Car car;
  final String tenantId;
  final Branch branch;
  final DateTime pickupDateTime;
  final DateTime returnDateTime;
  final PricingProfile pricingProfile;
  final KmPricingPackage selectedKmPackage;

  const PricingScreen({
    super.key,
    required this.car,
    required this.tenantId,
    required this.branch,
    required this.pickupDateTime,
    required this.returnDateTime,
    required this.pricingProfile,
    required this.selectedKmPackage,
  });

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  static const Color primary = Color(0xFF0F766E);
  static const Color accent = Color(0xFF14B8A6);
  static const Color background = Color(0xFFF8FAF9);
  static const Color card = Color(0xFFFFFFFF);
  static const Color softAccent = Color(0xFFE6FFFB);
  static const Color heading = Color(0xFF17201F);
  static const Color body = Color(0xFF66706E);
  static const Color muted = Color(0xFF94A09D);
  static const Color border = Color(0xFFE5EBE9);

  final PricingEngine _pricingEngine =
      const PricingEngine();

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  PricingResult? _result;
  PricingProfile? _freshPricingProfile;
  KmPricingPackage? _freshSelectedPackage;

  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isContinuing = false;
  bool _isStale = false;
  DateTime? _lastCheckedAt;
  String? _errorMessage;

  String get _tenantId => widget.tenantId;

  @override
  void initState() {
    super.initState();
    _calculatePricing();
  }

  Future<void> _calculatePricing({
    bool showRefreshMessage = false,
  }) async {
    if (_isRefreshing && !showRefreshMessage) return;

    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      // Always reload the pricing profile from the tenant pricing source.
      // Do not rely only on the PricingProfile passed from KmPackageScreen.
      final profile =
          await PricingManager.instance.loadPricingForCar(
        tenantId: _tenantId,
        pricingProfileId: widget.car.pricingProfileId,
      );

      if (!mounted) return;

      if (profile == null) {
        setState(() {
          _isLoading = false;
          _isStale = true;
          _errorMessage =
              'Pricing is currently unavailable for this vehicle.';
        });
        return;
      }

      final freshPackage =
          profile.getPackage(widget.selectedKmPackage.id);

      if (freshPackage == null) {
        setState(() {
          _isLoading = false;
          _isStale = true;
          _freshPricingProfile = profile;
          _freshSelectedPackage = null;
          _errorMessage =
              'The selected KM package is no longer available. Please go back and select another package.';
        });
        return;
      }

      final config = PricingManager.instance.pricing;

      if (config == null) {
        setState(() {
          _isLoading = false;
          _isStale = true;
          _errorMessage =
              'Pricing configuration is unavailable. Please try again.';
        });
        return;
      }

      if (widget.returnDateTime.isBefore(widget.pickupDateTime) ||
          widget.returnDateTime.isAtSameMomentAs(widget.pickupDateTime)) {
        setState(() {
          _isLoading = false;
          _isStale = true;
          _errorMessage =
              'The return time must be after the pickup time.';
        });
        return;
      }

      final result = _pricingEngine.calculate(
        config: config,
        pricingProfileId: profile.id,
        pickupDateTime: widget.pickupDateTime,
        returnDateTime: widget.returnDateTime,
        actualKm: 0,
        plannedKm: 0,
        selectedKmPackageId: freshPackage.id,
        unlimitedKm: freshPackage.unlimitedKm,
        includeSecurityDeposit: true,
      );

      if (result.pricingProfileId.isEmpty) {
        setState(() {
          _isLoading = false;
          _isStale = true;
          _errorMessage =
              'Unable to calculate pricing for this booking.';
        });
        return;
      }

      setState(() {
        _result = result;
        _freshPricingProfile = profile;
        _freshSelectedPackage = freshPackage;
        _isLoading = false;
        _isStale = false;
        _lastCheckedAt = DateTime.now();
        _errorMessage = null;
      });

      if (showRefreshMessage && mounted) {
        _showSnackBar(
          'Pricing refreshed and verified.',
          icon: Icons.check_circle_outline_rounded,
        );
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isStale = true;
        _errorMessage =
            'Something went wrong while calculating the current price.';
      });
    }
  }

  Future<void> _refreshPricing() async {
    if (_isRefreshing || _isContinuing) return;

    setState(() {
      _isRefreshing = true;
      _errorMessage = null;
    });

    try {
      await _calculatePricing(showRefreshMessage: true);
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<bool> _revalidateBranch() async {
    try {
      final branchDoc = await _firestore
          .collection('tenants')
          .doc(_tenantId)
          .collection('branches')
          .doc(widget.branch.id)
          .get();

      if (!branchDoc.exists || branchDoc.data() == null) {
        _errorMessage =
            'This pickup branch is no longer available. Please go back and select another branch.';
        return false;
      }

      final data = branchDoc.data()!;
      final isActive = data['isActive'] == true;

      if (!isActive) {
        _errorMessage =
            'This pickup branch is currently unavailable. Please select another branch.';
        return false;
      }

      return true;
    } catch (_) {
      _errorMessage =
          'Unable to verify the pickup branch. Please try again.';
      return false;
    }
  }

  Future<void> _continue() async {
    if (_isContinuing || _isRefreshing) return;

    setState(() {
      _isContinuing = true;
      _errorMessage = null;
    });

    try {
      // Re-check the branch because availability can change while
      // the customer is reviewing the price.
      final branchValid = await _revalidateBranch();
      if (!branchValid) {
        if (mounted) {
          setState(() {
            _isContinuing = false;
            _isStale = true;
          });
        }
        return;
      }

      // Recalculate from the current tenant pricing source immediately
      // before creating the review payload.
      final profile =
          await PricingManager.instance.loadPricingForCar(
        tenantId: _tenantId,
        pricingProfileId: widget.car.pricingProfileId,
      );

      if (!mounted) return;

      if (profile == null) {
        setState(() {
          _isContinuing = false;
          _isStale = true;
          _errorMessage =
              'Vehicle pricing is no longer available.';
        });
        return;
      }

      final freshPackage =
          profile.getPackage(widget.selectedKmPackage.id);

      if (freshPackage == null) {
        setState(() {
          _isContinuing = false;
          _isStale = true;
          _freshPricingProfile = profile;
          _freshSelectedPackage = null;
          _errorMessage =
              'This KM package is no longer available. Please go back and select another package.';
        });
        return;
      }

      final config = PricingManager.instance.pricing;

      if (config == null) {
        setState(() {
          _isContinuing = false;
          _isStale = true;
          _errorMessage =
              'Pricing configuration is unavailable. Please try again.';
        });
        return;
      }

      if (widget.returnDateTime.isBefore(widget.pickupDateTime) ||
          widget.returnDateTime.isAtSameMomentAs(widget.pickupDateTime)) {
        setState(() {
          _isContinuing = false;
          _isStale = true;
          _errorMessage =
              'The return time must be after the pickup time.';
        });
        return;
      }

      final freshResult = _pricingEngine.calculate(
        config: config,
        pricingProfileId: profile.id,
        pickupDateTime: widget.pickupDateTime,
        returnDateTime: widget.returnDateTime,
        actualKm: 0,
        plannedKm: 0,
        selectedKmPackageId: freshPackage.id,
        unlimitedKm: freshPackage.unlimitedKm,
        includeSecurityDeposit: true,
      );

      if (freshResult.pricingProfileId.isEmpty) {
        setState(() {
          _isContinuing = false;
          _isStale = true;
          _errorMessage =
              'Unable to verify the final booking price.';
        });
        return;
      }

      if (!mounted) return;

      setState(() {
        _result = freshResult;
        _freshPricingProfile = profile;
        _freshSelectedPackage = freshPackage;
        _lastCheckedAt = DateTime.now();
        _isStale = false;
      });

      await Future<void>.delayed(
        const Duration(milliseconds: 80),
      );

      if (!mounted) return;

      setState(() {
        _isContinuing = false;
      });

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReviewBookingScreen(
            car: widget.car,
            tenantId: _tenantId,
            branch: widget.branch,
            pickupDateTime: widget.pickupDateTime,
            returnDateTime: widget.returnDateTime,
            pricingProfile: profile,
            selectedKmPackage: freshPackage,
            pricingResult: freshResult,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isContinuing = false;
        _isStale = true;
        _errorMessage =
            'Unable to verify the current booking price. Please try again.';
      });
    }
  }

  void _showSnackBar(
    String message, {
    IconData icon = Icons.info_outline_rounded,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          elevation: 0,
          backgroundColor: heading,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 19),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  String _lastCheckedText() {
    final checked = _lastCheckedAt;
    if (checked == null) return 'Not checked yet';

    final hour = checked.hour % 12 == 0 ? 12 : checked.hour % 12;
    final minute = checked.minute.toString().padLeft(2, '0');
    final period = checked.hour >= 12 ? 'PM' : 'AM';

    return 'Last checked $hour:$minute $period';
  }

  String _money(double value) {
    if (value == value.roundToDouble()) {
      return '₹${value.toInt()}';
    }

    return '₹${value.toStringAsFixed(2)}';
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

  String _durationText(PricingResult result) {
    final hours = result.durationHours;

    if (hours < 24) {
      final roundedHours = hours.ceil();
      return '$roundedHours '
          '${roundedHours == 1 ? 'hour' : 'hours'}';
    }

    final days = result.rentalDays;

    return '$days '
        '${days == 1 ? 'day' : 'days'}';
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
          onPressed: _isContinuing || _isRefreshing ? null : () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: heading,
          ),
        ),
        title: const Text(
          'Price Summary',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: heading,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh pricing',
            onPressed: _isRefreshing || _isContinuing
                ? null
                : _refreshPricing,
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: primary,
                    ),
                  )
                : const Icon(
                    Icons.refresh_rounded,
                    color: heading,
                  ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: primary,
                ),
              )
            : _errorMessage != null
                ? _buildErrorState()
                : _buildContent(),
      ),
      bottomNavigationBar:
          _result == null || _errorMessage != null
              ? null
              : _buildBottomButton(),
    );
  }

  Widget _buildContent() {
    final result = _result!;

    return RefreshIndicator(
      color: primary,
      onRefresh: _refreshPricing,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          20,
          8,
          20,
          120,
        ),
        children: [
          _buildPricingStatus(),
          const SizedBox(height: 12),
          _buildCarCard(),
        const SizedBox(height: 14),
        _buildTripCard(),
        const SizedBox(height: 20),
        _buildSelectedPackage(),
        const SizedBox(height: 20),
        _buildPriceBreakdown(result),
        const SizedBox(height: 14),
        _buildDepositCard(result),
        const SizedBox(height: 14),
          _buildTotalCard(result),
        ],
      ),
    );
  }

  Widget _buildPricingStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 11,
      ),
      decoration: BoxDecoration(
        color: _isStale ? const Color(0xFFFFF8ED) : softAccent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isStale
              ? const Color(0xFFF1D39B)
              : const Color(0xFFC8EEE8),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isStale
                ? Icons.warning_amber_rounded
                : Icons.verified_rounded,
            size: 18,
            color: _isStale
                ? const Color(0xFF9A6700)
                : primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isStale
                      ? 'Price needs verification'
                      : 'Live pricing verified',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: _isStale
                        ? const Color(0xFF7A5200)
                        : heading,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _lastCheckedText(),
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: body,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _isRefreshing || _isContinuing
                ? null
                : _refreshPricing,
            style: TextButton.styleFrom(
              foregroundColor: primary,
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Refresh',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: softAccent,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.directions_car_filled_rounded,
              color: primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  widget.car.name,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: heading,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.car.type} • '
                  '${widget.car.transmission}',
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: body,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripCard() {
    final result = _result!;

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
              const Icon(
                Icons.location_on_outlined,
                size: 19,
                color: primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.branch.name,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: heading,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(
            height: 1,
            color: border,
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            Icons.login_rounded,
            'Pickup',
            _formatDateTime(
              widget.pickupDateTime,
            ),
          ),
          const SizedBox(height: 9),
          _buildInfoRow(
            Icons.keyboard_return_rounded,
            'Return',
            _formatDateTime(
              widget.returnDateTime,
            ),
          ),
          const SizedBox(height: 9),
          _buildInfoRow(
            Icons.schedule_rounded,
            'Duration',
            _durationText(result),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String title,
    String value,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 17,
          color: muted,
        ),
        const SizedBox(width: 8),
        Text(
          '$title:',
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: muted,
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: body,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedPackage() {
    final package = _freshSelectedPackage ?? widget.selectedKmPackage;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: softAccent,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFC8EEE8),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: primary,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              package.unlimitedKm
                  ? Icons.all_inclusive_rounded
                  : Icons.speed_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'KM PACKAGE',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                    color: primary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  package.name,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: heading,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  package.unlimitedKm
                      ? 'Unlimited KM'
                      : '${package.includedKm ?? 0} KM included',
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: body,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.check_circle_rounded,
            color: primary,
            size: 23,
          ),
        ],
      ),
    );
  }

  Widget _buildPriceBreakdown(
    PricingResult result,
  ) {
    final rows = <Widget>[
      _buildPriceRow(
        'Rental',
        result.rentalPrice,
      ),
    ];

    if (result.extraKmCharge > 0) {
      rows.add(
        _buildPriceRow(
          'Extra KM',
          result.extraKmCharge,
        ),
      );
    }

    if (result.extraTimeCharge > 0) {
      rows.add(
        _buildPriceRow(
          'Extra Time',
          result.extraTimeCharge,
        ),
      );
    }

    if (result.addOnTotal > 0) {
      rows.add(
        _buildPriceRow(
          'Add-ons',
          result.addOnTotal,
        ),
      );
    }

    if (result.protectionTotal > 0) {
      rows.add(
        _buildPriceRow(
          'Protection',
          result.protectionTotal,
        ),
      );
    }

    if (result.discountAmount > 0) {
      rows.add(
        _buildPriceRow(
          'Discount',
          -result.discountAmount,
          valueColor: primary,
        ),
      );
    }

    rows.add(
      _buildPriceRow(
        'Tax',
        result.taxAmount,
      ),
    );

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'PRICE BREAKDOWN',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: muted,
            ),
          ),
          const SizedBox(height: 14),
          ..._withDividers(rows),
          const SizedBox(height: 12),
          const Divider(
            height: 1,
            color: border,
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Trip Total',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: heading,
                  ),
                ),
              ),
              Text(
                _money(result.total),
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _withDividers(
    List<Widget> items,
  ) {
    final result = <Widget>[];

    for (int i = 0; i < items.length; i++) {
      result.add(items[i]);

      if (i != items.length - 1) {
        result.add(
          const SizedBox(height: 10),
        );
      }
    }

    return result;
  }

  Widget _buildPriceRow(
    String label,
    double amount, {
    Color? valueColor,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: body,
            ),
          ),
        ),
        Text(
          amount < 0
              ? '- ${_money(amount.abs())}'
              : _money(amount),
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: valueColor ?? heading,
          ),
        ),
      ],
    );
  }

  Widget _buildDepositCard(
    PricingResult result,
  ) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: primary,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Refundable Security Deposit',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: heading,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Refunded according to the rental terms.',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: muted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _money(result.securityDeposit),
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: heading,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalCard(
    PricingResult result,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Amount payable',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
              ),
              Text(
                _money(result.amountPayable),
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          if (result.securityDeposit > 0) ...[
            const SizedBox(height: 7),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Includes ${_money(result.securityDeposit)} '
                'refundable deposit',
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomButton() {
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
                _isContinuing || _isRefreshing || _isStale
                    ? null
                    : _continue,
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
                : const Row(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      Text(
                        'Review Booking',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(
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

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.calculate_outlined,
              size: 48,
              color: muted,
            ),
            const SizedBox(height: 16),
            const Text(
              'Unable to calculate price',
              textAlign: TextAlign.center,
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
                  'Pricing is currently unavailable.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 13,
                color: body,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isRefreshing || _isContinuing
                  ? null
                  : _refreshPricing,
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
}