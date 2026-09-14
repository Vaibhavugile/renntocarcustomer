import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../booking/models/booking.dart';

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

  String get _tenantId => AppConfig.tenant.tenantId;

  Future<void> _completePayment() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final bookingRef = FirebaseFirestore.instance
          .collection('tenants')
          .doc(_tenantId)
          .collection('bookings')
          .doc(widget.booking.bookingId);

      final snapshot = await bookingRef.get();

      if (!snapshot.exists) {
        throw Exception('Booking not found.');
      }

      final data = snapshot.data();

      if (data == null) {
        throw Exception('Unable to load booking.');
      }

      final bookingTenantId = data['tenantId']?.toString() ?? '';

      if (bookingTenantId != _tenantId) {
        throw Exception('Invalid tenant booking.');
      }

      final currentStatus = data['status']?.toString() ?? '';
      final currentPaymentStatus =
          data['paymentStatus']?.toString() ?? '';

      if (currentStatus == 'cancelled' ||
          currentStatus == 'rejected' ||
          currentStatus == 'completed') {
        throw Exception(
          'This booking is no longer available for payment.',
        );
      }

      if (currentPaymentStatus == 'paid') {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => PaymentSuccessScreen(
                booking: widget.booking,
              ),
            ),
          );
        }
        return;
      }

      final totalAmount = _toDouble(
        data['totalAmount'],
      );

      final paymentId =
          'manual_${DateTime.now().millisecondsSinceEpoch}';

      await bookingRef.update({
        'paymentStatus': 'paid',
        'paidAmount': totalAmount,
        'paymentMethod': 'manual',
        'paymentId': paymentId,
        'paymentTransactionId': paymentId,
        'paymentOrderId': null,
        'status': 'confirmed',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentSuccessScreen(
            booking: widget.booking,
            paymentId: paymentId,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
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
    final booking = widget.booking;

    final total = booking.totalAmount;

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
                    _buildAmountCard(total),
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

  Widget _buildAmountCard(double total) {
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
            _formatAmount(total),
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
                        'Manual Payment',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: heading,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Payment will be recorded as completed',
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
            'Your booking will be confirmed after completing this payment step.',
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
                const Text(
                  'Payable',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 11,
                    color: muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatAmount(total),
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
                    _isProcessing ? null : _completePayment,
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
                    : const Text(
                        'Complete Payment',
                        style: TextStyle(
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