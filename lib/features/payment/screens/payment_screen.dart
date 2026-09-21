import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../booking/models/booking.dart';
import '../../booking/services/booking_service.dart';

class PaymentScreen extends StatefulWidget {
  final Booking booking;

  const PaymentScreen({
    super.key,
    required this.booking,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}


class _PaymentScreenState extends State<PaymentScreen> {
  static const Color primary = Color(0xFF0F766E);
  static const Color accent = Color(0xFF14B8A6);
  static const Color background = Color(0xFFF8FAF9);
  static const Color card = Color(0xFFFFFFFF);
  static const Color softAccent = Color(0xFFE6FFFB);
  static const Color heading = Color(0xFF17201F);
  static const Color body = Color(0xFF66706E);
  static const Color muted = Color(0xFF94A09D);
  static const Color border = Color(0xFFE5EBE9);

  bool _isProcessing = false;
  bool _isRefreshing = false;
  Booking? _latestBooking;
  String? _lastCheckedText;

  final BookingService _bookingService = BookingService();

  String get _tenantId => AppConfig.tenant.tenantId;

  Future<void> _refreshBooking() async {
    if (_isRefreshing || _isProcessing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      final ref = FirebaseFirestore.instance
          .collection('tenants')
          .doc(_tenantId)
          .collection('bookings')
          .doc(widget.booking.bookingId);

      final snapshot = await ref.get();

      if (!snapshot.exists || snapshot.data() == null) {
        throw Exception('Booking not found.');
      }

      final data = snapshot.data()!;
      if ((data['tenantId']?.toString() ?? '') != _tenantId) {
        throw Exception('Invalid tenant booking.');
      }

      final latest = Booking.fromMap(snapshot.id, data);

      if (!mounted) return;
      setState(() {
        _latestBooking = latest;
        _lastCheckedText = _formatTime(DateTime.now());
      });

      _showMessage('Booking payment status refreshed.');
    } catch (e) {
      if (!mounted) return;
      _showMessage(
        e.toString().replaceFirst('Exception: ', ''),
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Booking get _activeBooking => _latestBooking ?? widget.booking;

  double get _outstandingAmount {
    final booking = _activeBooking;
    final balance = booking.totalAmount - booking.paidAmount + booking.refundAmount;
    return balance < 0 ? 0 : balance;
  }

  Future<void> _completePayment() async {
    if (_isProcessing || _isRefreshing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final bookingRef = FirebaseFirestore.instance
          .collection('tenants')
          .doc(_tenantId)
          .collection('bookings')
          .doc(widget.booking.bookingId);

      // Always read the latest booking immediately before payment.
      final snapshot = await bookingRef.get();

      if (!snapshot.exists || snapshot.data() == null) {
        throw Exception('Booking not found.');
      }

      final data = snapshot.data()!;
      if ((data['tenantId']?.toString() ?? '') != _tenantId) {
        throw Exception('Invalid tenant booking.');
      }

      final latestBooking = Booking.fromMap(snapshot.id, data);

      if (latestBooking.status == BookingStatus.cancelled ||
          latestBooking.status == BookingStatus.rejected ||
          latestBooking.status == BookingStatus.completed ||
          latestBooking.status == BookingStatus.noShow) {
        throw Exception(
          'This booking is no longer available for payment.',
        );
      }

      if (latestBooking.paymentStatus == PaymentStatus.paid ||
          latestBooking.balanceAmount <= 0.009) {
        if (mounted) {
          setState(() => _latestBooking = latestBooking);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => PaymentSuccessScreen(
                booking: latestBooking,
                paymentId: latestBooking.paymentId,
              ),
            ),
          );
        }
        return;
      }

      final amount = latestBooking.balanceAmount;
      if (amount <= 0) {
        throw Exception('There is no outstanding payment for this booking.');
      }

      /*
       * IMPORTANT:
       *
       * Do not update paidAmount/paymentStatus directly here.
       * BookingService records an immutable PaymentTransaction in:
       * tenants/{tenantId}/bookings/{bookingId}/payments/{paymentId}
       * and updates the booking payment summary atomically.
       *
       * This current screen still represents the existing Firebase/manual
       * payment flow. When Razorpay is connected, its verified gateway IDs
       * should be supplied to this same ledger method instead.
       */
      final transaction = await _bookingService.addVerifiedCustomerPayment(
        tenantId: _tenantId,
        bookingId: latestBooking.bookingId,
        amount: amount,
        method: PaymentMethodType.other,
        transactionReference:
            'manual_${DateTime.now().millisecondsSinceEpoch}',
        note: 'Customer payment completed from payment screen.',
        paymentDate: DateTime.now(),
      );

      // A fully paid booking becomes confirmed. PaymentService/BookingService
      // owns the financial summary; this only advances the booking lifecycle.
      await bookingRef.update({
        'status': BookingStatus.confirmed.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final refreshed = await bookingRef.get();
      final savedBooking = refreshed.exists && refreshed.data() != null
          ? Booking.fromMap(refreshed.id, refreshed.data()!)
          : latestBooking;

      if (!mounted) return;

      setState(() {
        _latestBooking = savedBooking;
        _lastCheckedText = _formatTime(DateTime.now());
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentSuccessScreen(
            booking: savedBooking,
            paymentId: transaction.paymentId,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      final raw = e.toString().replaceFirst('Exception: ', '');
      String message = raw.isEmpty
          ? 'Unable to complete the payment. Please try again.'
          : raw;

      if (raw.toLowerCase().contains('already been recorded')) {
        message = 'This payment has already been recorded. Please refresh the payment status.';
      }

      _showMessage(message, error: true);
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: error ? const Color(0xFFB42318) : primary,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  String _formatTime(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  String _formatAmount(double amount) {
    return '₹${amount.toStringAsFixed(0)}';
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final booking = _activeBooking;

    final total = booking.totalAmount;
    final outstanding = _outstandingAmount;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Payment',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: heading,
          ),
        ),
        iconTheme: const IconThemeData(
          color: heading,
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh payment status',
            onPressed: _isProcessing || _isRefreshing ? null : _refreshBooking,
            icon: _isRefreshing
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: primary,
                      ),
                    ),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBookingSummary(booking),
                    const SizedBox(height: 20),
                    _buildAmountCard(total, outstanding),
                    const SizedBox(height: 20),
                    _buildPaymentStatus(booking, outstanding),
                    const SizedBox(height: 20),
                    _buildPaymentMethod(),
                    const SizedBox(height: 20),
                    _buildSecureInfo(),
                  ],
                ),
              ),
            ),
            _buildBottomBar(total),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingSummary(Booking booking) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: softAccent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.directions_car_rounded,
                  color: primary,
                  size: 25,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.car?.name ?? 'Car Rental',
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: heading,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Booking #${booking.bookingId}',
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 12,
                        color: muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(
            height: 1,
            color: border,
          ),
          const SizedBox(height: 16),
          _infoRow(
            Icons.calendar_today_outlined,
            'Pickup',
            _formatDate(booking.pickupDateTime),
          ),
          const SizedBox(height: 12),
          _infoRow(
            Icons.event_available_outlined,
            'Return',
            _formatDate(booking.returnDateTime),
          ),
          const SizedBox(height: 12),
          _infoRow(
            Icons.location_on_outlined,
            'Pickup branch',
            booking.pickupBranch?.name ??
                booking.pickupBranchId,
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
    return Row(
      children: [
        Icon(
          icon,
          size: 19,
          color: primary,
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 13,
            color: body,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 13,
              color: heading,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAmountCard(double total, double outstanding) {
    final booking = _activeBooking;
    final isPaid = outstanding <= 0.009 || booking.paymentStatus == PaymentStatus.paid;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primary,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.18),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TOTAL PAYABLE',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 11,
              letterSpacing: 1.1,
              color: Colors.white70,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            _formatAmount(isPaid ? booking.totalAmount : outstanding),
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 32,
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Including applicable charges and security deposit',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentStatus(Booking booking, double outstanding) {
    final paid = booking.paidAmount;
    final isPaid = outstanding <= 0.009 || booking.paymentStatus == PaymentStatus.paid;

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: softAccent,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  isPaid ? Icons.verified_rounded : Icons.account_balance_wallet_outlined,
                  color: primary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPaid ? 'Payment completed' : 'Payment status',
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: heading,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isPaid
                          ? 'This booking has no outstanding balance.'
                          : '${_formatAmount(outstanding)} remaining',
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
              IconButton(
                tooltip: 'Refresh payment status',
                onPressed: _isProcessing || _isRefreshing ? null : _refreshBooking,
                icon: _isRefreshing
                    ? const SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: primary,
                        ),
                      )
                    : const Icon(Icons.refresh_rounded, color: primary),
              ),
            ],
          ),
          const SizedBox(height: 13),
          const Divider(height: 1, color: border),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _paymentMetric('Paid', _formatAmount(paid))),
              const SizedBox(width: 10),
              Expanded(child: _paymentMetric('Balance', _formatAmount(outstanding))),
            ],
          ),
          if (_lastCheckedText != null) ...[
            const SizedBox(height: 9),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Last checked $_lastCheckedText',
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: muted,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _paymentMetric(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(
            fontFamily: 'Manrope', fontSize: 10, color: muted, fontWeight: FontWeight.w600,
          )),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(
            fontFamily: 'Manrope', fontSize: 13, color: heading, fontWeight: FontWeight.w900,
          )),
        ],
      ),
    );
  }

  Widget _buildPaymentMethod() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment method',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: heading,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: softAccent,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: accent.withOpacity(0.18),
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.payments_outlined,
                  color: primary,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payment confirmation',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: heading,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'The payment is recorded in the booking payment ledger.',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 11,
                          color: body,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.check_circle_rounded,
                  color: primary,
                  size: 21,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecureInfo() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.verified_user_outlined,
          size: 20,
          color: primary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Your payment is recorded as a transaction against this booking. When the full balance is paid, the booking is confirmed.',
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12,
              height: 1.45,
              color: body,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(double total) {
    final booking = _activeBooking;
    final outstanding = _outstandingAmount;
    final isPaid = outstanding <= 0.009 || booking.paymentStatus == PaymentStatus.paid;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        20,
        14,
        20,
        18,
      ),
      decoration: BoxDecoration(
        color: card,
        border: const Border(
          top: BorderSide(
            color: border,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isPaid ? 'Paid' : 'Balance',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 11,
                    color: muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatAmount(isPaid ? booking.totalAmount : outstanding),
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 18,
                    color: heading,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed:
                    (_isProcessing || _isRefreshing || isPaid) ? null : _completePayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      primary.withOpacity(0.55),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(16),
                  ),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor:
                              AlwaysStoppedAnimation<
                                  Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Text(
                        isPaid ? 'Payment Completed' : 'Complete Payment',
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PaymentSuccessScreen extends StatelessWidget {
  final Booking booking;
  final String? paymentId;

  const PaymentSuccessScreen({
    super.key,
    required this.booking,
    this.paymentId,
  });

  static const Color primary = Color(0xFF0F766E);
  static const Color background = Color(0xFFF8FAF9);
  static const Color heading = Color(0xFF17201F);
  static const Color body = Color(0xFF66706E);
  static const Color softAccent = Color(0xFFE6FFFB);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 88,
                height: 88,
                decoration: const BoxDecoration(
                  color: softAccent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: primary,
                  size: 52,
                ),
              ),
              const SizedBox(height: 26),
              const Text(
                'Payment Successful',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                  color: heading,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Your booking has been confirmed successfully.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 14,
                  height: 1.5,
                  color: body,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 28),
              _detailCard(),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context)
                        .popUntil((route) => route.isFirst);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Back to Home',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE5EBE9),
        ),
      ),
      child: Column(
        children: [
          _row(
            'Booking ID',
            booking.bookingId,
          ),
          if (paymentId != null) ...[
            const SizedBox(height: 12),
            _row(
              'Payment ID',
              paymentId!,
            ),
          ],
          const SizedBox(height: 12),
          _row(
            'Status',
            'Confirmed',
          ),
          const SizedBox(height: 12),
          _row(
            'Paid',
            '₹${booking.paidAmount.toStringAsFixed(0)}',
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 12,
            color: body,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        const SizedBox(width: 15),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12,
              color: heading,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}