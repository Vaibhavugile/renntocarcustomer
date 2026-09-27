import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../booking/services/booking_service.dart';

class CustomerTransactionDetailsScreen extends StatefulWidget {
  const CustomerTransactionDetailsScreen({
    super.key,
    required this.transaction,
    required this.tenantId,
  });

  final CustomerTransactionItem transaction;
  final String tenantId;

  @override
  State<CustomerTransactionDetailsScreen> createState() =>
      _CustomerTransactionDetailsScreenState();
}

class _CustomerTransactionDetailsScreenState
    extends State<CustomerTransactionDetailsScreen> {
  CustomerTransactionItem get transaction => widget.transaction;

  // ============================================================
  // COLORS
  // ============================================================

  static const Color background = Color(0xFFF7F8FA);
  static const Color cardColor = Colors.white;
  static const Color textPrimary = Color(0xFF111318);
  static const Color textSecondary = Color(0xFF70757D);
  static const Color borderColor = Color(0xFFE8EAEF);

  static const Color successColor = Color(0xFF159447);
  static const Color pendingColor = Color(0xFFE48B00);
  static const Color failedColor = Color(0xFFD93025);
  static const Color refundColor = Color(0xFF2D6CDF);
  static const Color neutralColor = Color(0xFF6B7280);

  // ============================================================
  // HELPERS
  // ============================================================

  String _money(double amount, String currency) {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: currency == 'INR' ? '₹' : currency,
      decimalDigits: 2,
    );

    return formatter.format(amount);
  }

  String _date(DateTime date) {
    return DateFormat(
      'dd MMMM yyyy, hh:mm a',
    ).format(date.toLocal());
  }

  String _shortDate(DateTime date) {
    return DateFormat(
      'dd MMM yyyy, hh:mm a',
    ).format(date.toLocal());
  }

  String _safe(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Not available';
    }

    return value.trim();
  }

  String _status() {
    return transaction.status
        .trim()
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');
  }

  bool _isFailed() {
    final status = _status();

    return status.contains('failed') ||
        status.contains('cancel');
  }

  bool _isPending() {
    final status = _status();

    return status.contains('pending') ||
        status.contains('created') ||
        status.contains('processing') ||
        status.contains('initiated');
  }

  bool _isSuccessful() {
    final status = _status();

    return status.contains('success') ||
        status.contains('successful') ||
        status.contains('paid') ||
        status.contains('captured');
  }

  Color _statusColor() {
    if (transaction.isRefund) {
      if (_isFailed()) {
        return failedColor;
      }

      if (_isPending()) {
        return pendingColor;
      }

      return refundColor;
    }

    if (_isFailed()) {
      return failedColor;
    }

    if (_isPending()) {
      return pendingColor;
    }

    if (_isSuccessful()) {
      return successColor;
    }

    return neutralColor;
  }

  IconData _statusIcon() {
    if (transaction.isRefund) {
      if (_isFailed()) {
        return Icons.error_outline_rounded;
      }

      if (_isPending()) {
        return Icons.hourglass_top_rounded;
      }

      return Icons.keyboard_return_rounded;
    }

    if (_isFailed()) {
      return Icons.close_rounded;
    }

    if (_isPending()) {
      return Icons.schedule_rounded;
    }

    if (_isSuccessful()) {
      return Icons.check_rounded;
    }

    return Icons.payment_rounded;
  }

  String _statusTitle() {
    if (transaction.isRefund) {
      if (_isFailed()) {
        return 'Refund failed';
      }

      if (_isPending()) {
        return 'Refund pending';
      }

      return 'Refund processed';
    }

    if (_isFailed()) {
      if (_status().contains('cancel')) {
        return 'Payment cancelled';
      }

      return 'Payment failed';
    }

    if (_isPending()) {
      return 'Payment pending';
    }

    if (_isSuccessful()) {
      return 'Payment successful';
    }

    return 'Payment attempt';
  }

  String _transactionType() {
    if (transaction.isRefund) {
      return 'Refund';
    }

    if (transaction.isAttempt) {
      return 'Payment Attempt';
    }

    return 'Payment';
  }

  String _amountPrefix() {
    if (transaction.isRefund) {
      return '-';
    }

    if (_isSuccessful()) {
      return '+';
    }

    return '';
  }

  // ============================================================
  // COPY
  // ============================================================

  Future<void> _copy(
    String value,
    String label,
  ) async {
    if (value.trim().isEmpty ||
        value == 'Not available') {
      return;
    }

    await Clipboard.setData(
      ClipboardData(text: value),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: textPrimary,
        elevation: 0,
        title: const Text(
          'Transaction Details',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Share',
            onPressed: _showShareInfo,
            icon: const Icon(
              Icons.share_rounded,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            35,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              _buildStatusHeader(),

              const SizedBox(height: 16),

              _buildAmountCard(),

              const SizedBox(height: 16),

              _buildTransactionOverview(),

              const SizedBox(height: 16),

              _buildBookingCard(),

              const SizedBox(height: 16),

              _buildPaymentInformation(),

              if (_hasGatewayInformation()) ...[
                const SizedBox(height: 16),
                _buildGatewayInformation(),
              ],

              if (_hasFailureInformation()) ...[
                const SizedBox(height: 16),
                _buildFailureCard(),
              ],

              if (transaction.isRefund) ...[
                const SizedBox(height: 16),
                _buildRefundInformation(),
              ],

              const SizedBox(height: 16),

              _buildTimeline(),

              const SizedBox(height: 16),

              _buildSecurityNote(),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // STATUS HEADER
  // ============================================================

  Widget _buildStatusHeader() {
    final color = _statusColor();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: color.withOpacity(.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _statusIcon(),
              color: color,
              size: 34,
            ),
          ),

          const SizedBox(height: 15),

          Text(
            _statusTitle(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: textPrimary,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            _date(transaction.date),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: color.withOpacity(.08),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              _transactionType(),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // AMOUNT
  // ============================================================

  Widget _buildAmountCard() {
    final color = transaction.isRefund
        ? refundColor
        : _statusColor();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            transaction.isRefund
                ? 'Refund Amount'
                : 'Transaction Amount',
            style: const TextStyle(
              color: textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 7),

          Text(
            '${_amountPrefix()}${_money(transaction.amount, transaction.currency)}',
            style: TextStyle(
              fontSize: 31,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: -.5,
            ),
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                size: 14,
                color: textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                _shortDate(transaction.date),
                style: const TextStyle(
                  fontSize: 12,
                  color: textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TRANSACTION OVERVIEW
  // ============================================================

  Widget _buildTransactionOverview() {
    return _sectionCard(
      title: 'Transaction Overview',
      icon: Icons.receipt_long_rounded,
      children: [
        _infoRow(
          'Transaction type',
          _transactionType(),
        ),
        _divider(),
        _infoRow(
          'Status',
          _statusTitle(),
          valueColor: _statusColor(),
        ),
        _divider(),
        _infoRow(
          'Amount',
          '${_amountPrefix()}${_money(transaction.amount, transaction.currency)}',
        ),
        _divider(),
        _infoRow(
          'Currency',
          _safe(transaction.currency),
        ),
        _divider(),
        _infoRow(
          'Date & time',
          _date(transaction.date),
        ),
      ],
    );
  }

  // ============================================================
  // BOOKING
  // ============================================================

  Widget _buildBookingCard() {
    return _sectionCard(
      title: 'Booking Information',
      icon: Icons.directions_car_filled_rounded,
      children: [
        _infoRow(
          'Booking ID',
          _safe(transaction.bookingId),
          trailing: _copyButton(
            transaction.bookingId,
            'Booking ID',
          ),
        ),
        _divider(),
        _infoRow(
          'Booking',
          'Rental booking',
        ),
        _divider(),
        _infoRow(
          'Tenant',
          widget.tenantId,
        ),
      ],
    );
  }

  // ============================================================
  // PAYMENT INFORMATION
  // ============================================================

  Widget _buildPaymentInformation() {
    return _sectionCard(
      title: 'Payment Information',
      icon: Icons.account_balance_wallet_rounded,
      children: [
        _infoRow(
          'Payment method',
          _safe(transaction.paymentMethod),
        ),
        _divider(),
        _infoRow(
          'Payment status',
          _statusTitle(),
          valueColor: _statusColor(),
        ),
        _divider(),
        _infoRow(
          'Transaction type',
          _transactionType(),
        ),
      ],
    );
  }

  // ============================================================
  // GATEWAY
  // ============================================================

  bool _hasGatewayInformation() {
    return _getString(
          transaction,
          'razorpayPaymentId',
        ) !=
        null ||
        _getString(
              transaction,
              'razorpayOrderId',
            ) !=
            null ||
        _getString(
              transaction,
              'razorpayRefundId',
            ) !=
            null ||
        _getString(
              transaction,
              'transactionId',
            ) !=
            null ||
        _getString(
              transaction,
              'gatewayReference',
            ) !=
            null;
  }

  Widget _buildGatewayInformation() {
    final paymentId = _getString(
      transaction,
      'razorpayPaymentId',
    );

    final orderId = _getString(
      transaction,
      'razorpayOrderId',
    );

    final refundId = _getString(
      transaction,
      'razorpayRefundId',
    );

    final transactionId = _getString(
      transaction,
      'transactionId',
    );

    final gatewayReference = _getString(
      transaction,
      'gatewayReference',
    );

    final gatewayStatus = _getString(
      transaction,
      'gatewayStatus',
    );

    return _sectionCard(
      title: 'Gateway Information',
      icon: Icons.account_balance_rounded,
      children: [
        if (paymentId != null)
          _copyInfoRow(
            'Razorpay Payment ID',
            paymentId,
          ),

        if (paymentId != null &&
            orderId != null)
          _divider(),

        if (orderId != null)
          _copyInfoRow(
            'Razorpay Order ID',
            orderId,
          ),

        if (refundId != null) ...[
          _divider(),
          _copyInfoRow(
            'Razorpay Refund ID',
            refundId,
          ),
        ],

        if (transactionId != null) ...[
          _divider(),
          _copyInfoRow(
            'Transaction ID',
            transactionId,
          ),
        ],

        if (gatewayReference != null) ...[
          _divider(),
          _copyInfoRow(
            'Gateway Reference',
            gatewayReference,
          ),
        ],

        if (gatewayStatus != null) ...[
          _divider(),
          _infoRow(
            'Gateway status',
            gatewayStatus,
          ),
        ],
      ],
    );
  }

  // ============================================================
  // FAILURE
  // ============================================================

  bool _hasFailureInformation() {
    final reason = transaction.failureReason;

    return _isFailed() ||
        (reason != null &&
            reason.trim().isNotEmpty);
  }

  Widget _buildFailureCard() {
    final reason =
        transaction.failureReason?.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(.045),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.red.withOpacity(.12),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: failedColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Text(
                  'Payment Issue',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Text(
            reason != null && reason.isNotEmpty
                ? reason
                : 'The payment could not be completed.',
            style: TextStyle(
              color: Colors.red.shade800,
              height: 1.45,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            'If money was deducted from your account, '
            'please check your bank/payment provider. '
            'The transaction status may update automatically.',
            style: TextStyle(
              color: Colors.red.shade700,
              height: 1.4,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // REFUND
  // ============================================================

  Widget _buildRefundInformation() {
    final refundId = _getString(
      transaction,
      'razorpayRefundId',
    );

    final refundStatus = _getString(
      transaction,
      'refundStatus',
    );

    final refundAmount = _getDouble(
      transaction,
      'refundAmount',
    );

    final refundDate = _getDateTime(
      transaction,
      'refundDate',
    );

    return _sectionCard(
      title: 'Refund Information',
      icon: Icons.keyboard_return_rounded,
      iconColor: refundColor,
      children: [
        _infoRow(
          'Refund status',
          refundStatus ??
              _statusTitle(),
          valueColor: _statusColor(),
        ),
        _divider(),

        if (refundAmount != null)
          _infoRow(
            'Refund amount',
            _money(
              refundAmount,
              transaction.currency,
            ),
            valueColor: refundColor,
          )
        else
          _infoRow(
            'Refund amount',
            _money(
              transaction.amount,
              transaction.currency,
            ),
            valueColor: refundColor,
          ),

        if (refundId != null) ...[
          _divider(),
          _copyInfoRow(
            'Refund ID',
            refundId,
          ),
        ],

        if (refundDate != null) ...[
          _divider(),
          _infoRow(
            'Refund date',
            _date(refundDate),
          ),
        ],
      ],
    );
  }

  // ============================================================
  // TIMELINE
  // ============================================================

  Widget _buildTimeline() {
    return _sectionCard(
      title: 'Transaction Timeline',
      icon: Icons.timeline_rounded,
      children: [
        _timelineItem(
          icon: Icons.receipt_long_rounded,
          title: 'Transaction created',
          subtitle: _date(transaction.date),
          color: neutralColor,
          isLast: !_isFailed() &&
              !_isPending(),
        ),

        if (_isPending())
          _timelineItem(
            icon: Icons.schedule_rounded,
            title: 'Payment processing',
            subtitle:
                'Payment is awaiting confirmation.',
            color: pendingColor,
            isLast: true,
          )
        else if (_isFailed())
          _timelineItem(
            icon: Icons.close_rounded,
            title: 'Transaction unsuccessful',
            subtitle: transaction.failureReason
                        ?.trim()
                        .isNotEmpty ==
                    true
                ? transaction.failureReason!
                : 'The transaction was not completed.',
            color: failedColor,
            isLast: true,
          )
        else if (transaction.isRefund)
          _timelineItem(
            icon: Icons.keyboard_return_rounded,
            title: 'Refund processed',
            subtitle:
                'Refund has been recorded for this transaction.',
            color: refundColor,
            isLast: true,
          )
        else
          _timelineItem(
            icon: Icons.check_circle_rounded,
            title: 'Payment confirmed',
            subtitle:
                'Payment was successfully recorded.',
            color: successColor,
            isLast: true,
          ),
      ],
    );
  }

  Widget _timelineItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isLast,
  }) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 32,
          child: Column(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: color.withOpacity(.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 15,
                  color: color,
                ),
              ),
              if (!isLast)
                Container(
                  width: 1.5,
                  height: 43,
                  color: borderColor,
                ),
            ],
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Padding(
            padding:
                const EdgeInsets.only(bottom: 18),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SECURITY
  // ============================================================

  Widget _buildSecurityNote() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.verified_user_outlined,
            size: 20,
            color: Color(0xFF5E6672),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Transaction information is provided '
              'from your booking payment records. '
              'For payment disputes or unexpected '
              'charges, contact the rental provider.',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 11.5,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SECTION CARD
  // ============================================================

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    Color? iconColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: (iconColor ?? textPrimary)
                      .withOpacity(.07),
                  borderRadius:
                      BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 19,
                  color:
                      iconColor ?? textPrimary,
                ),
              ),
              const SizedBox(width: 11),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: textPrimary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          ...children,
        ],
      ),
    );
  }

  // ============================================================
  // INFO ROW
  // ============================================================

  Widget _infoRow(
    String label,
    String value, {
    Color? valueColor,
    Widget? trailing,
  }) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          flex: 6,
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.end,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 12.5,
                    color:
                        valueColor ?? textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 5),
                trailing,
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _copyInfoRow(
    String label,
    String value,
  ) {
    return _infoRow(
      label,
      value,
      trailing: _copyButton(
        value,
        label,
      ),
    );
  }

  Widget _copyButton(
    String value,
    String label,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(7),
      onTap: () => _copy(value, label),
      child: const Padding(
        padding: EdgeInsets.all(3),
        child: Icon(
          Icons.copy_rounded,
          size: 14,
          color: textSecondary,
        ),
      ),
    );
  }

  Widget _divider() {
    return const Padding(
      padding: EdgeInsets.symmetric(
        vertical: 12,
      ),
      child: Divider(
        height: 1,
        thickness: .7,
        color: borderColor,
      ),
    );
  }
  // ============================================================
  // DYNAMIC FIELD HELPERS
  //
  // These helpers intentionally map to the REAL fields available
  // on CustomerTransactionItem.
  // ============================================================

  String? _getString(
    CustomerTransactionItem item,
    String field,
  ) {
    try {
      final dynamic value =
          _readDynamicField(item, field);

      if (value == null) {
        return null;
      }

      final String result =
          value.toString().trim();

      if (result.isEmpty) {
        return null;
      }

      return result;
    } catch (_) {
      return null;
    }
  }

  double? _getDouble(
    CustomerTransactionItem item,
    String field,
  ) {
    try {
      final dynamic value =
          _readDynamicField(item, field);

      if (value == null) {
        return null;
      }

      if (value is num) {
        return value.toDouble();
      }

      return double.tryParse(
        value.toString(),
      );
    } catch (_) {
      return null;
    }
  }

  DateTime? _getDateTime(
    CustomerTransactionItem item,
    String field,
  ) {
    try {
      final dynamic value =
          _readDynamicField(item, field);

      if (value == null) {
        return null;
      }

      if (value is DateTime) {
        return value;
      }

      return DateTime.tryParse(
        value.toString(),
      );
    } catch (_) {
      return null;
    }
  }

  dynamic _readDynamicField(
    CustomerTransactionItem item,
    String field,
  ) {
    switch (field) {
      // ==========================================================
      // RAZORPAY PAYMENT
      // ==========================================================

      case 'razorpayPaymentId':
        return item.razorpayPaymentId;

      case 'razorpayOrderId':
        return item.razorpayOrderId;

      // ==========================================================
      // RAZORPAY REFUND
      // ==========================================================

      case 'razorpayRefundId':
        return item.razorpayRefundId;

      // ==========================================================
      // TRANSACTION REFERENCE
      //
      // Your model uses transactionReference instead of
      // transactionId.
      // ==========================================================

      case 'transactionId':
        return item.transactionReference;

      case 'gatewayReference':
        return item.transactionReference;

      // ==========================================================
      // GATEWAY STATUS
      //
      // There is no gatewayStatus field in the model.
      // Use the normalized transaction status.
      // ==========================================================

      case 'gatewayStatus':
        return item.status;

      // ==========================================================
      // REFUND STATUS
      // ==========================================================

      case 'refundStatus':
        if (item.isRefund) {
          return item.status;
        }

        return null;

      // ==========================================================
      // REFUND AMOUNT
      // ==========================================================

      case 'refundAmount':
        if (item.isRefund) {
          return item.amount;
        }

        return null;

      // ==========================================================
      // REFUND DATE
      // ==========================================================

      case 'refundDate':
        if (item.isRefund) {
          return item.date;
        }

        return null;

      // ==========================================================
      // REAL MODEL FIELDS
      // ==========================================================

      case 'kind':
        return item.kind;

      case 'id':
        return item.id;

      case 'tenantId':
        return item.tenantId;

      case 'bookingId':
        return item.bookingId;

      case 'customerId':
        return item.customerId;

      case 'amount':
        return item.amount;

      case 'currency':
        return item.currency;

      case 'status':
        return item.status;

      case 'paymentMethod':
        return item.paymentMethod;

      case 'gateway':
        return item.gateway;

      case 'failureReason':
        return item.failureReason;

      case 'failureCode':
        return item.failureCode;

      case 'paymentType':
        return item.paymentType;

      case 'description':
        return item.description;

      case 'date':
        return item.date;

      case 'createdAt':
        return item.createdAt;

      default:
        return null;
    }
  }

  

  // ============================================================
  // SHARE
  // ============================================================

  void _showShareInfo() {
    final text = '''
Rentocar Transaction

Type: ${_transactionType()}
Status: ${_statusTitle()}
Amount: ${_money(transaction.amount, transaction.currency)}
Booking ID: ${transaction.bookingId}
Date: ${_date(transaction.date)}
Payment Method: ${_safe(transaction.paymentMethod)}
''';

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              10,
              20,
              25,
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Transaction Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                SelectableText(
                  text,
                  style: const TextStyle(
                    height: 1.5,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: text),
                      );

                      if (!context.mounted) return;

                      Navigator.pop(context);

                      ScaffoldMessenger.of(
                        this.context,
                      ).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Transaction details copied',
                          ),
                          behavior:
                              SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.copy_rounded,
                    ),
                    label: const Text(
                      'Copy Details',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}