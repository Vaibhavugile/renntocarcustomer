import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
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

  PricingResult? _result;

  bool _isLoading = true;
  bool _isContinuing = false;
  String? _errorMessage;

  // Simple security-deposit selection. Asset deposits never add a cash
  // amount to the rental payable total.
  String _securityDepositType = 'cash';
  final TextEditingController _securityDepositDetailsController =
      TextEditingController();

  String get _tenantId => AppConfig.tenant.tenantId;

  @override
  void initState() {
    super.initState();
    _calculatePricing();
  }

  @override
  void dispose() {
    _securityDepositDetailsController.dispose();
    super.dispose();
  }

  void _calculatePricing() {
    try {
      final PricingConfig? config =
          PricingManager.instance.pricing;

      if (config == null) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Pricing configuration is unavailable. Please try again.';
        });
        return;
      }

      final result = _pricingEngine.calculate(
        config: config,
        pricingProfileId:
            widget.pricingProfile.id,
        pickupDateTime:
            widget.pickupDateTime,
        returnDateTime:
            widget.returnDateTime,

        // During booking actual KM is not known.
        actualKm: 0,

        // We don't assume any planned KM.
        plannedKm: 0,

        // The exact Firebase KM package selected
        // by the customer.
        selectedKmPackageId:
            widget.selectedKmPackage.id,

        unlimitedKm:
            widget.selectedKmPackage.unlimitedKm,

        // Deposit is included in amount payable.
        includeSecurityDeposit: true,
      );

      if (result.pricingProfileId.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Unable to calculate pricing for this booking.';
        });
        return;
      }

      setState(() {
        _result = result;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Something went wrong while calculating the price.';
      });
    }
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

  Future<void> _continue() async {
    if (_result == null) {
      return;
    }

    setState(() {
      _isContinuing = true;
    });

    // Small async boundary keeps the button responsive
    // while the next screen is prepared.
    await Future<void>.delayed(
      const Duration(milliseconds: 120),
    );

    if (!mounted) return;

    final result = _result!;

    final depositAmount = _selectedDepositAmount(result);
    final depositDetails = _securityDepositDetailsController.text.trim();

    if (_requiresDepositDetails && depositDetails.isEmpty) {
      setState(() {
        _isContinuing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the deposit details.')),
      );
      return;
    }

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
          pricingProfile: widget.pricingProfile,
          selectedKmPackage: widget.selectedKmPackage,
          pricingResult: result,
          securityDepositType: _securityDepositType,
          securityDepositDetails: depositDetails,
          securityDepositAmount: depositAmount,
        ),
      ),
    );
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
          'Price Summary',
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        20,
        8,
        20,
        120,
      ),
      children: [
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
        _buildDepositSelection(result),
        const SizedBox(height: 14),
        _buildTotalCard(result),
      ],
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
    final package = widget.selectedKmPackage;

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

  bool get _isMonetaryDeposit =>
      _securityDepositType == 'cash' ||
      _securityDepositType == 'upi' ||
      _securityDepositType == 'bank_transfer';

  bool get _requiresDepositDetails =>
      _securityDepositType == 'bike' ||
      _securityDepositType == 'car' ||
      _securityDepositType == 'other';

  double _selectedDepositAmount(PricingResult result) {
    return _isMonetaryDeposit ? result.securityDeposit : 0;
  }

  String _depositLabel(String value) {
    switch (value) {
      case 'cash':
        return 'Cash';
      case 'upi':
        return 'UPI';
      case 'bank_transfer':
        return 'Bank Transfer';
      case 'bike':
        return 'Bike';
      case 'car':
        return 'Car';
      case 'other':
        return 'Other';
      case 'none':
        return 'No Deposit';
      default:
        return value;
    }
  }

  Widget _buildDepositSelection(PricingResult result) {
    final options = <String>[
      'cash',
      'upi',
      'bank_transfer',
      'bike',
      'car',
      'other',
      'none',
    ];

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Security Deposit',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: heading,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Choose how the refundable deposit will be provided.',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 10.5,
              color: muted,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _securityDepositType,
            decoration: InputDecoration(
              labelText: 'Deposit type',
              filled: true,
              fillColor: background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: border),
              ),
            ),
            items: options
                .map(
                  (value) => DropdownMenuItem<String>(
                    value: value,
                    child: Text(_depositLabel(value)),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _securityDepositType = value;
                if (!_requiresDepositDetails) {
                  _securityDepositDetailsController.clear();
                }
              });
            },
          ),
          const SizedBox(height: 10),
          if (_isMonetaryDeposit)
            _buildPriceRow(
              'Cash deposit payable',
              result.securityDeposit,
            )
          else if (_requiresDepositDetails) ...[
            TextField(
              controller: _securityDepositDetailsController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Deposit details',
                hintText: 'Example: Personal bike / vehicle held as security',
                filled: true,
                fillColor: background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: border),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'No asset value, registration number or valuation is required.',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 10.5,
                color: muted,
              ),
            ),
          ] else
            const Text(
              'No cash security deposit will be added to the payable amount.',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 11,
                color: body,
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
                _money(result.total + _selectedDepositAmount(result)),
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          if (_selectedDepositAmount(result) > 0) ...[
            const SizedBox(height: 7),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Includes ${_money(_selectedDepositAmount(result))} '
                'refundable deposit',
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 7),
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                'No cash deposit added to payable amount',
                style: TextStyle(
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
                _isContinuing ? null : _continue,
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
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });

                _calculatePricing();
              },
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