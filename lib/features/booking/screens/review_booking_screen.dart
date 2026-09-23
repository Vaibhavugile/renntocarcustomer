import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../cars/models/car.dart';
import '../../customer/models/customer.dart';
import '../../customer/services/customer_service.dart';
import '../../pricing/models/km_pricing_package.dart';
import '../../pricing/models/pricing_profile.dart';
import '../../pricing/engine/pricing_engine.dart';
import '../models/booking.dart';
import '../../../models/branch.dart';
import '../services/booking_service.dart';
import '../../payment/screens/payment_screen.dart';

class ReviewBookingScreen extends StatefulWidget {
  final Car car;
  final String tenantId;
  final Branch branch;
  final DateTime pickupDateTime;
  final DateTime returnDateTime;
  final PricingProfile pricingProfile;
  final KmPricingPackage selectedKmPackage;
  final PricingResult pricingResult;

  /// Simple security deposit selected before this review screen.
  /// Monetary types: cash, upi, bank_transfer.
  /// Non-monetary types: bike, car, other.
  final String securityDepositType;
  final double? securityDepositAmount;
  final String securityDepositDetails;

  const ReviewBookingScreen({
    super.key,
    required this.car,
    required this.tenantId,
    required this.branch,
    required this.pickupDateTime,
    required this.returnDateTime,
    required this.pricingProfile,
    required this.selectedKmPackage,
    required this.pricingResult,
    this.securityDepositType = 'none',
    this.securityDepositAmount,
    this.securityDepositDetails = '',
  });

  @override
  State<ReviewBookingScreen> createState() =>
      _ReviewBookingScreenState();
}

class _ReviewBookingScreenState
    extends State<ReviewBookingScreen> {
  static const Color primary = Color(0xFF0F766E);
  static const Color accent = Color(0xFF14B8A6);
  static const Color background = Color(0xFFF8FAF9);
  static const Color card = Color(0xFFFFFFFF);
  static const Color softAccent = Color(0xFFE6FFFB);
  static const Color heading = Color(0xFF17201F);
  static const Color body = Color(0xFF66706E);
  static const Color muted = Color(0xFF94A09D);
  static const Color border = Color(0xFFE5EBE9);

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  final CustomerService _customerService =
      CustomerService();

  final BookingService _bookingService =
      BookingService();

  final _formKey =
      GlobalKey<FormState>();

  final TextEditingController _nameController =
      TextEditingController();

  final TextEditingController _emailController =
      TextEditingController();

  final TextEditingController _phoneController =
      TextEditingController();

  final TextEditingController _noteController =
      TextEditingController();

  Customer? _customer;

  bool _loadingCustomer = true;
  bool _isCreatingBooking = false;
  bool _termsAccepted = false;

  String? _errorMessage;

  String get _tenantId =>
      AppConfig.tenant.tenantId;

  bool get _isMonetaryDeposit =>
      widget.securityDepositType == 'cash' ||
      widget.securityDepositType == 'upi' ||
      widget.securityDepositType == 'bank_transfer';

  double get _selectedDepositAmount =>
      _isMonetaryDeposit
          ? (widget.securityDepositAmount ?? widget.pricingResult.securityDeposit)
          : 0.0;

  double get _selectedTotalAmount =>
      widget.pricingResult.total + _selectedDepositAmount;

  String _depositLabel(String type) {
    switch (type) {
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
      default:
        return 'No Deposit';
    }
  }

  @override
  void initState() {
    super.initState();
    _loadCustomer();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomer() async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        throw Exception(
          'User is not authenticated.',
        );
      }

      final customer =
          await _customerService
              .getCurrentCustomer(
        tenantId: _tenantId,
      );

      if (!mounted) return;

      _customer = customer;

      _nameController.text =
          customer?.fullName ?? '';

      _emailController.text =
          customer?.email ?? '';

      _phoneController.text =
          customer?.phone.isNotEmpty == true
              ? customer!.phone
              : (user.phoneNumber ?? '');

      setState(() {
        _loadingCustomer = false;
      });
    } catch (_) {
      if (!mounted) return;

      final user = _auth.currentUser;

      _phoneController.text =
          user?.phoneNumber ?? '';

      setState(() {
        _loadingCustomer = false;
        _errorMessage =
            'Unable to load your customer details.';
      });
    }
  }

  String _money(double amount) {
    if (amount == amount.roundToDouble()) {
      return '₹${amount.toInt()}';
    }

    return '₹${amount.toStringAsFixed(2)}';
  }

  String _formatDateTime(DateTime dateTime) {
    final hour =
        dateTime.hour % 12 == 0
            ? 12
            : dateTime.hour % 12;

    final minute =
        dateTime.minute
            .toString()
            .padLeft(2, '0');

    final period =
        dateTime.hour >= 12
            ? 'PM'
            : 'AM';

    return '${dateTime.day.toString().padLeft(2, '0')}/'
        '${dateTime.month.toString().padLeft(2, '0')}/'
        '${dateTime.year} • '
        '$hour:$minute $period';
  }

  String _durationText() {
    final minutes =
        widget.pricingResult.durationMinutes;

    if (minutes < 60) {
      return '$minutes minutes';
    }

    final hours =
        widget.pricingResult.durationHours;

    if (hours < 24) {
      final rounded =
          hours.ceil();

      return '$rounded '
          '${rounded == 1 ? 'hour' : 'hours'}';
    }

    final days =
        widget.pricingResult.rentalDays;

    return '$days '
        '${days == 1 ? 'day' : 'days'}';
  }

  Future<void> _confirmBooking() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_termsAccepted) {
      setState(() {
        _errorMessage =
            'Please accept the booking terms to continue.';
      });
      return;
    }

    final user = _auth.currentUser;

    if (user == null) {
      setState(() {
        _errorMessage =
            'Your session has expired. Please login again.';
      });
      return;
    }

    setState(() {
      _isCreatingBooking = true;
      _errorMessage = null;
    });

    try {
      /*
       * Make sure the customer record exists before creating
       * the booking.
       *
       * Customer records are tenant-scoped.
       */
      await _customerService
          .createCustomerIfNotExists(
        tenantId: _tenantId,
      );

      final customer =
          await _customerService
              .getCurrentCustomer(
        tenantId: _tenantId,
      );

      if (customer == null) {
        throw Exception(
          'Customer profile could not be loaded.',
        );
      }

      /*
       * Save the minimum booking details entered here.
       *
       * Full KYC/profile remains separate and can be completed
       * later during the pickup workflow.
       */
      final updatedCustomer =
          customer.copyWith(
        fullName:
            _nameController.text.trim(),
        email:
            _emailController.text.trim(),
        updatedAt:
            DateTime.now(),
      );

      await _customerService.updateCustomer(
        tenantId: _tenantId,
        customer: updatedCustomer,
      );

      /*
       * Historical pricing snapshot.
       *
       * The booking keeps the exact values used at booking time
       * so future pricing changes do not alter this booking.
       */
      final pricing =
          BookingPricingSnapshot(
        pricingProfileId:
            widget.pricingResult
                .pricingProfileId,

        kmPackageId:
            widget.pricingResult
                .selectedKmPackageId,

        kmPackageName:
            widget.pricingResult
                .selectedKmPackageName,

        includedKm:
            widget.pricingResult.includedKm,

        unlimitedKm:
            widget.pricingResult.unlimitedKm,

        extraKmRate:
            widget.pricingResult
                    .selectedKmPackageExtraKmRate ??
                widget.pricingProfile.extraKmRate,

        baseAmount:
            widget.pricingResult.rentalPrice,

        extraKmAmount:
            widget.pricingResult.extraKmCharge,

        extraTimeAmount:
            widget.pricingResult.extraTimeCharge,

        addOnsAmount:
            widget.pricingResult.addOnTotal,

        protectionAmount:
            widget.pricingResult.protectionTotal,

        discountAmount:
            widget.pricingResult.discountAmount,

        taxAmount:
            widget.pricingResult.taxAmount,

        securityDeposit:
            widget.pricingResult.securityDeposit,

        totalAmount:
            widget.pricingResult.total,
      );

      /*
       * Build the Booking object.
       *
       * BookingService will create the booking ID and timestamps.
       */
      final booking = Booking(
        bookingId: '',

        tenantId: _tenantId,

        customerId: user.uid,

        carId: widget.car.id,

        branchId: widget.branch.id,

        status:
            BookingStatus.pending,

        paymentStatus:
            PaymentStatus.pending,

        pickupDateTime:
            widget.pickupDateTime,

        returnDateTime:
            widget.returnDateTime,

        actualPickupDateTime:
            null,

        actualReturnDateTime:
            null,

        pickupBranchId:
            widget.branch.id,

        /*
         * We currently use the same branch for pickup
         * and return.
         *
         * A separate return-branch selector can be added
         * later without changing the booking architecture.
         */
        returnBranchId:
            widget.branch.id,

        pickupBranch:
            BookingBranchSnapshot(
          branchId:
              widget.branch.id,
          name:
              widget.branch.name,
          city:
              widget.branch.city,
          address:
              widget.branch.address,
          phone:
              widget.branch.phone,
        ),

        returnBranch:
            BookingBranchSnapshot(
          branchId:
              widget.branch.id,
          name:
              widget.branch.name,
          city:
              widget.branch.city,
          address:
              widget.branch.address,
          phone:
              widget.branch.phone,
        ),

        /*
         * BookingService also creates/validates the historical
         * car snapshot, so we can leave this null.
         */
        car: null,

        kmPackageId:
            widget.pricingResult
                .selectedKmPackageId,

        kmPackageName:
            widget.pricingResult
                .selectedKmPackageName,

        includedKm:
            widget.pricingResult.includedKm,

        unlimitedKm:
            widget.pricingResult.unlimitedKm,

        extraKmRate:
            widget.pricingResult
                    .selectedKmPackageExtraKmRate ??
                widget.selectedKmPackage.extraKmRate,

        pricingProfileId:
            widget.pricingResult
                .pricingProfileId,

        baseAmount:
            widget.pricingResult.rentalPrice,

        extraKmAmount:
            widget.pricingResult.extraKmCharge,

        extraTimeAmount:
            widget.pricingResult.extraTimeCharge,

        addOnsAmount:
            widget.pricingResult.addOnTotal,

        protectionAmount:
            widget.pricingResult.protectionTotal,

        discountAmount:
            widget.pricingResult.discountAmount,

        taxAmount:
            widget.pricingResult.taxAmount,

        securityDeposit:
            _selectedDepositAmount,

        totalAmount:
            _selectedTotalAmount,

        securityDepositType:
            widget.securityDepositType,

        securityDepositDetails:
            widget.securityDepositDetails.trim(),

        pricing:
            pricing,

        paidAmount: 0,

        refundAmount: 0,

        paymentId: null,

        paymentOrderId: null,

        paymentTransactionId: null,

        paymentMethod: null,

        couponCode: null,

        customerName:
            _nameController.text.trim(),

        customerPhone:
            _phoneController.text.trim(),

        customerEmail:
            _emailController.text.trim(),

        customerNote:
            _noteController.text.trim(),

        cancellationReason: '',

        rejectionReason: '',

        /*
         * Pending expiry will eventually be controlled by
         * the backend/Cloud Function.
         *
         * Keep it null here so the server can become the
         * authoritative source later.
         */
        expiresAt: null,

        createdAt: null,

        updatedAt: null,
      );

      /*
       * IMPORTANT:
       *
       * BookingService performs the final availability check
       * immediately before saving.
       */
      final savedBooking =
          await _bookingService
              .createBooking(
        tenantId: _tenantId,
        booking: booking,
      );

      if (!mounted) return;

      setState(() {
        _isCreatingBooking = false;
      });

      /*
       * Payment comes immediately after booking creation.
       *
       * For now payment is a simple Firebase-only/manual
       * completion step. Later this screen can be replaced
       * by Razorpay or another payment gateway without
       * changing the booking creation flow.
       */
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentScreen(
            booking: savedBooking,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      String message =
          'Unable to create your booking. Please try again.';

      final error =
          e.toString().toLowerCase();

      if (error.contains('not available')) {
        message =
            'Sorry, this car is no longer available for the selected time. Please choose another time.';
      } else if (error.contains('authenticated')) {
        message =
            'Your session has expired. Please login again.';
      } else if (error.contains('tenant mismatch')) {
        message =
            'Unable to verify the rental account. Please restart the booking.';
      } else if (error.contains('customer identity')) {
        message =
            'Unable to verify your customer account.';
      }

      setState(() {
        _isCreatingBooking = false;
        _errorMessage = message;
      });
    }
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
          onPressed: _isCreatingBooking
              ? null
              : () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: heading,
          ),
        ),
        title: const Text(
          'Review Booking',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: heading,
          ),
        ),
      ),
      body: _loadingCustomer
          ? const Center(
              child: CircularProgressIndicator(
                color: primary,
              ),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding:
                    const EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  130,
                ),
                children: [
                  _buildHeader(),
                  const SizedBox(height: 18),
                  if (_errorMessage != null) ...[
                    _buildError(),
                    const SizedBox(height: 14),
                  ],
                  _buildVehicleSection(),
                  const SizedBox(height: 14),
                  _buildTripSection(),
                  const SizedBox(height: 14),
                  _buildPackageSection(),
                  const SizedBox(height: 14),
                  _buildCustomerSection(),
                  const SizedBox(height: 14),
                  _buildPriceSection(),
                  const SizedBox(height: 14),
                  _buildTermsSection(),
                ],
              ),
            ),
      bottomNavigationBar:
          _buildBottomButton(),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: const [
        Text(
          'Almost there',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: heading,
          ),
        ),
        SizedBox(height: 5),
        Text(
          'Review your trip details before confirming your booking.',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 12.5,
            height: 1.4,
            fontWeight: FontWeight.w500,
            color: body,
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleSection() {
    return _sectionCard(
      title: 'VEHICLE',
      icon: Icons.directions_car_filled_rounded,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: softAccent,
              borderRadius:
                  BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.directions_car_filled_rounded,
              color: primary,
              size: 27,
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
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: heading,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.car.type} • '
                  '${widget.car.transmission} • '
                  '${widget.car.seats} seats',
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
        ],
      ),
    );
  }

  Widget _buildTripSection() {
    return _sectionCard(
      title: 'TRIP DETAILS',
      icon: Icons.route_rounded,
      child: Column(
        children: [
          _detailRow(
            Icons.location_on_outlined,
            'Pickup location',
            widget.branch.name,
          ),
          const SizedBox(height: 11),
          _detailRow(
            Icons.login_rounded,
            'Pickup',
            _formatDateTime(
              widget.pickupDateTime,
            ),
          ),
          const SizedBox(height: 11),
          _detailRow(
            Icons.keyboard_return_rounded,
            'Return',
            _formatDateTime(
              widget.returnDateTime,
            ),
          ),
          const SizedBox(height: 11),
          _detailRow(
            Icons.schedule_rounded,
            'Duration',
            _durationText(),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageSection() {
    final package =
        widget.selectedKmPackage;

    return _sectionCard(
      title: 'KM PACKAGE',
      icon: Icons.speed_rounded,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: softAccent,
          borderRadius:
              BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.speed_rounded,
              color: primary,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    package.name,
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: heading,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    package.unlimitedKm
                        ? 'Unlimited KM'
                        : '${package.includedKm ?? 0} KM included',
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: body,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              package.unlimitedKm
                  ? '∞'
                  : '${package.includedKm ?? 0} KM',
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerSection() {
    return _sectionCard(
      title: 'YOUR DETAILS',
      icon: Icons.person_outline_rounded,
      child: Column(
        children: [
          _inputField(
            controller: _nameController,
            label: 'Full name',
            icon: Icons.person_outline_rounded,
            validator: (value) {
              if (value == null ||
                  value.trim().isEmpty) {
                return 'Please enter your name';
              }

              if (value.trim().length < 2) {
                return 'Please enter a valid name';
              }

              return null;
            },
          ),
          const SizedBox(height: 12),
          _inputField(
            controller: _phoneController,
            label: 'Phone number',
            icon: Icons.phone_outlined,
            keyboardType:
                TextInputType.phone,
            readOnly: true,
            validator: (value) {
              if (value == null ||
                  value.trim().isEmpty) {
                return 'Phone number is required';
              }

              return null;
            },
          ),
          const SizedBox(height: 12),
          _inputField(
            controller: _emailController,
            label: 'Email address',
            icon: Icons.email_outlined,
            keyboardType:
                TextInputType.emailAddress,
            validator: (value) {
              final email =
                  value?.trim() ?? '';

              if (email.isEmpty) {
                return null;
              }

              if (!email.contains('@') ||
                  !email.contains('.')) {
                return 'Enter a valid email address';
              }

              return null;
            },
          ),
          const SizedBox(height: 12),
          _inputField(
            controller: _noteController,
            label: 'Booking note (optional)',
            icon: Icons.notes_rounded,
            maxLines: 3,
          ),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Full KYC and additional profile details can be completed later.',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 10.5,
                height: 1.4,
                fontWeight: FontWeight.w500,
                color: muted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool readOnly = false,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      readOnly: readOnly,
      maxLines: maxLines,
      style: const TextStyle(
        fontFamily: 'Manrope',
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: heading,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 12,
          color: muted,
        ),
        prefixIcon: Icon(
          icon,
          size: 19,
          color: muted,
        ),
        filled: true,
        fillColor: background,
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(13),
          borderSide:
              const BorderSide(
            color: border,
          ),
        ),
        enabledBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(13),
          borderSide:
              const BorderSide(
            color: border,
          ),
        ),
        focusedBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(13),
          borderSide:
              const BorderSide(
            color: primary,
            width: 1.4,
          ),
        ),
        errorBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(13),
          borderSide:
              const BorderSide(
            color: Color(0xFFE4A4A4),
          ),
        ),
      ),
    );
  }

  Widget _buildPriceSection() {
    final result =
        widget.pricingResult;

    return _sectionCard(
      title: 'PRICE SUMMARY',
      icon: Icons.receipt_long_outlined,
      child: Column(
        children: [
          _priceRow(
            'Rental',
            result.rentalPrice,
          ),
          if (result.extraKmCharge > 0) ...[
            const SizedBox(height: 10),
            _priceRow(
              'Extra KM',
              result.extraKmCharge,
            ),
          ],
          if (result.extraTimeCharge > 0) ...[
            const SizedBox(height: 10),
            _priceRow(
              'Extra Time',
              result.extraTimeCharge,
            ),
          ],
          if (result.addOnTotal > 0) ...[
            const SizedBox(height: 10),
            _priceRow(
              'Add-ons',
              result.addOnTotal,
            ),
          ],
          if (result.protectionTotal > 0) ...[
            const SizedBox(height: 10),
            _priceRow(
              'Protection',
              result.protectionTotal,
            ),
          ],
          if (result.discountAmount > 0) ...[
            const SizedBox(height: 10),
            _priceRow(
              'Discount',
              -result.discountAmount,
              valueColor: primary,
            ),
          ],
          const SizedBox(height: 10),
          _priceRow(
            'GST / Tax',
            result.taxAmount,
          ),
          const SizedBox(height: 14),
          const Divider(
            height: 1,
            color: border,
          ),
          const SizedBox(height: 14),
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
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Container(
            padding:
                const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: background,
              borderRadius:
                  BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 17,
                  color: muted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Security deposit (${_depositLabel(widget.securityDepositType)})',
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: body,
                    ),
                  ),
                ),
                Text(
                  _money(
                    _selectedDepositAmount,
                  ),
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: heading,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsSection() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: card,
        borderRadius:
            BorderRadius.circular(17),
        border: Border.all(
          color: border,
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: _termsAccepted,
              activeColor: primary,
              side: const BorderSide(
                color: muted,
              ),
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(5),
              ),
              onChanged:
                  _isCreatingBooking
                      ? null
                      : (value) {
                          setState(() {
                            _termsAccepted =
                                value ?? false;
                            _errorMessage = null;
                          });
                        },
            ),
          ),
          const SizedBox(width: 9),
          const Expanded(
            child: Padding(
              padding:
                  EdgeInsets.only(top: 2),
              child: Text(
                'I confirm that the booking details are correct and agree to the rental and cancellation terms.',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 11,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                  color: body,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: border,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 17,
                color: primary,
              ),
              const SizedBox(width: 7),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _detailRow(
    IconData icon,
    String title,
    String value,
  ) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 17,
          color: muted,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: muted,
          ),
        ),
        const SizedBox(width: 8),
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

  Widget _priceRow(
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
              fontSize: 12,
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
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color:
                valueColor ?? heading,
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F5),
        borderRadius:
            BorderRadius.circular(14),
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
                fontSize: 11.5,
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

  Widget _buildBottomButton() {
    final amount =
        _selectedTotalAmount;

    return SafeArea(
      minimum:
          const EdgeInsets.fromLTRB(
        20,
        10,
        20,
        16,
      ),
      child: Container(
        padding:
            const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: card,
          borderRadius:
              BorderRadius.circular(18),
          border: Border.all(
            color: border,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black
                  .withValues(alpha: 0.06),
              blurRadius: 20,
              offset:
                  const Offset(0, -4),
            ),
          ],
        ),
        child: SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed:
                _isCreatingBooking
                    ? null
                    : _confirmBooking,
            style:
                ElevatedButton.styleFrom(
              backgroundColor: primary,
              disabledBackgroundColor:
                  const Color(0xFFD9E2E0),
              foregroundColor:
                  Colors.white,
              elevation: 0,
              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(
                  14,
                ),
              ),
            ),
            child: _isCreatingBooking
                ? const SizedBox(
                    width: 23,
                    height: 23,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color:
                          Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment:
                        MainAxisAlignment
                            .center,
                    children: [
                      const Text(
                        'Confirm Booking',
                        style:
                            TextStyle(
                          fontFamily:
                              'Manrope',
                          fontSize: 14,
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),
                      const SizedBox(
                        width: 8,
                      ),
                      Text(
                        '• ${_money(amount)}',
                        style:
                            const TextStyle(
                          fontFamily:
                              'Manrope',
                          fontSize: 13,
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
