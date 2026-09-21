import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/app_config.dart';
import '../../../booking/models/booking.dart';
import '../../../booking/services/booking_service.dart';
import '../../../customer/models/customer.dart';
import '../../../customer/services/customer_service.dart';
import 'pickup_pending_screen.dart';
import 'return_pending_screen.dart';

/// Premium admin Booking 360° details screen.
///
/// Designed for the current booking lifecycle:
///
/// PENDING
///   -> CONFIRMED
///   -> PICKUP PENDING
///   -> ACTIVE
///   -> RETURN PENDING
///   -> COMPLETED
///
/// Terminal:
///   CANCELLED / REJECTED / NO SHOW
///
/// Important:
/// - Pickup Pending and Return Pending remain separate operational stages.
/// - This screen never silently performs a physical handover or return.
/// - Customer KYC status is shown prominently before operational actions.
/// - Customer documents are read from the tenant-scoped customer document when
///   available. Unknown document field names are handled defensively so older
///   customer records do not crash the screen.
/// - Booking data comes from BookingService, not a second booking collection.
class AdminBookingDetailsScreen extends StatefulWidget {
  const AdminBookingDetailsScreen({
    super.key,
    required this.booking,
    this.onBookingChanged,
    this.onOpenCustomer,
  });

  final Booking booking;

  /// Called after an action changes the booking.
  final ValueChanged<Booking>? onBookingChanged;

  /// Optional navigation hook to the existing Admin Customer Details screen.
  final ValueChanged<Customer>? onOpenCustomer;

  @override
  State<AdminBookingDetailsScreen> createState() =>
      _AdminBookingDetailsScreenState();
}

class _AdminBookingDetailsScreenState
    extends State<AdminBookingDetailsScreen> {
  static const Color background = Color(0xFFF6F8FB);
  static const Color card = Colors.white;
  static const Color heading = Color(0xFF18212F);
  static const Color body = Color(0xFF425066);
  static const Color muted = Color(0xFF758195);
  static const Color border = Color(0xFFE7EBF1);
  static const Color primary = Color(0xFF315CF6);
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color purple = Color(0xFF8B5CF6);
  static const Color teal = Color(0xFF0F9F9A);
  static const Color blue = Color(0xFF3B82F6);

  final BookingService _bookingService = BookingService.instance;
  final CustomerService _customerService = CustomerService.instance;

  late Booking _booking;

  Customer? _customer;
  Map<String, dynamic>? _customerRaw;

  bool _loading = true;
  bool _refreshing = false;
  bool _actionBusy = false;
  bool _paymentsLoading = false;
  String? _error;

  List<PaymentTransaction> _paymentTransactions = <PaymentTransaction>[];
  DateTime? _lastVerifiedAt;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _booking = widget.booking;
    _loadAll();
  }

  String get _tenantId => AppConfig.tenant.tenantId;

  Future<void> _loadAll({bool showLoader = true}) async {
    final generation = ++_loadGeneration;

    if (showLoader && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    if (_tenantId.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshing = false;
        _error = 'Tenant configuration is missing.';
      });
      return;
    }

    try {
      final results = await Future.wait<dynamic>([
        _bookingService.getBookingForAdmin(
          tenantId: _tenantId,
          bookingId: _booking.bookingId,
        ),
        _customerService.getCustomer(
          tenantId: _tenantId,
          customerId: _booking.customerId,
        ),
        _loadRawCustomer(),
        _bookingService.getBookingPaymentsForAdmin(
          tenantId: _tenantId,
          bookingId: _booking.bookingId,
        ),
      ]);

      if (!mounted || generation != _loadGeneration) return;

      final freshBooking = results[0] as Booking?;
      final customer = results[1] as Customer?;
      final raw = results[2] as Map<String, dynamic>?;
      final payments = results[3] as List<PaymentTransaction>;

      if (freshBooking == null) {
        throw Exception('Booking not found.');
      }

      if (freshBooking.tenantId.isNotEmpty &&
          freshBooking.tenantId != _tenantId) {
        throw Exception('Booking does not belong to the active tenant.');
      }

      setState(() {
        _booking = freshBooking;
        _customer = customer;
        _customerRaw = raw;
        _paymentTransactions = payments;
        _loading = false;
        _refreshing = false;
        _lastVerifiedAt = DateTime.now();
      });

      widget.onBookingChanged?.call(_booking);
    } catch (e) {
      if (!mounted || generation != _loadGeneration) return;

      setState(() {
        _loading = false;
        _refreshing = false;
        _error = _cleanError(e.toString());
      });
    }
  }

  Future<Map<String, dynamic>?> _loadRawCustomer() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('tenants')
          .doc(_tenantId)
          .collection('customers')
          .doc(_booking.customerId)
          .get();

      if (!doc.exists || doc.data() == null) return null;
      return Map<String, dynamic>.from(doc.data()!);
    } catch (_) {
      return null;
    }
  }

  Future<void> _refresh() async {
    if (_refreshing || _actionBusy) return;

    setState(() => _refreshing = true);
    await _loadAll(showLoader: false);
  }

  Future<void> _refreshPayments() async {
    if (_paymentsLoading || _actionBusy) return;

    setState(() => _paymentsLoading = true);
    try {
      final payments = await _bookingService.getBookingPaymentsForAdmin(
        tenantId: _tenantId,
        bookingId: _booking.bookingId,
      );

      if (!mounted) return;
      setState(() {
        _paymentTransactions = payments;
        _paymentsLoading = false;
        _lastVerifiedAt = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _paymentsLoading = false);
      _showMessage(_cleanError(e.toString()), error: true);
    }
  }

  String get _lastVerifiedText {
    final value = _lastVerifiedAt;
    if (value == null) return 'Not verified yet';

    final seconds = DateTime.now().difference(value).inSeconds;
    if (seconds < 10) return 'Verified just now';
    if (seconds < 60) return 'Verified ${seconds}s ago';

    final minutes = seconds ~/ 60;
    if (minutes < 60) return 'Verified ${minutes}m ago';

    return 'Verified at ${DateFormat('hh:mm a').format(value)}';
  }

  Future<Booking?> _revalidateBookingBeforeAction() async {
    final fresh = await _bookingService.getBookingForAdmin(
      tenantId: _tenantId,
      bookingId: _booking.bookingId,
    );

    if (fresh == null) {
      throw Exception('Booking no longer exists.');
    }

    if (fresh.tenantId.isNotEmpty && fresh.tenantId != _tenantId) {
      throw Exception('Booking does not belong to the active tenant.');
    }

    if (!mounted) return fresh;

    setState(() {
      _booking = fresh;
      _lastVerifiedAt = DateTime.now();
    });

    return fresh;
  }

  String _cleanError(String value) {
    return value
        .replaceFirst('Exception: ', '')
        .replaceFirst('Bad state: ', '')
        .trim();
  }

  // ============================================================
  // CUSTOMER / KYC
  // ============================================================

  String _customerValue(String key, [String fallback = '']) {
    final value = _customerRaw?[key];
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  String _nestedValue(
    String parent,
    String key, [
    String fallback = '',
  ]) {
    final raw = _customerRaw?[parent];
    if (raw is Map) {
      final value = raw[key];
      if (value == null) return fallback;
      final text = value.toString().trim();
      return text.isEmpty ? fallback : text;
    }
    return fallback;
  }

  String get _kycStatus {
    final value = _customer?.kycStatus.trim().toLowerCase();
    if (value != null && value.isNotEmpty) return value;
    return _customerValue('kycStatus', 'not_started').toLowerCase();
  }

  String get _kycLabel {
    switch (_kycStatus) {
      case 'verified':
        return 'KYC VERIFIED';
      case 'pending':
        return 'KYC PENDING';
      case 'rejected':
        return 'KYC REJECTED';
      default:
        return 'KYC NOT STARTED';
    }
  }

  Color get _kycColor {
    switch (_kycStatus) {
      case 'verified':
        return success;
      case 'pending':
        return warning;
      case 'rejected':
        return danger;
      default:
        return danger;
    }
  }

  bool get _kycVerified => _kycStatus == 'verified';

  String get _profileStatus {
    final completed = _customer?.profileCompleted ??
        (_customerRaw?['profileCompleted'] == true);
    return completed ? 'Complete' : 'Incomplete';
  }

  String get _licenseStatus {
    final candidates = [
      _customerValue('drivingLicenseStatus'),
      _customerValue('licenseStatus'),
      _nestedValue('drivingLicense', 'status'),
      _nestedValue('drivingLicenseDocument', 'status'),
    ];
    final value = candidates.firstWhere(
      (x) => x.isNotEmpty,
      orElse: () => '',
    );
    return value.isEmpty ? 'Not available' : _prettyStatus(value);
  }

  String get _governmentIdStatus {
    final candidates = [
      _customerValue('governmentIdStatus'),
      _customerValue('identityStatus'),
      _customerValue('documentStatus'),
      _nestedValue('governmentId', 'status'),
      _nestedValue('identityDocument', 'status'),
    ];
    final value = candidates.firstWhere(
      (x) => x.isNotEmpty,
      orElse: () => '',
    );
    return value.isEmpty ? 'Not available' : _prettyStatus(value);
  }

  String get _kycAttention {
    if (_kycVerified) return 'Customer KYC is verified.';
    if (_kycStatus == 'pending') {
      return 'KYC is under review. Verify required documents before pickup.';
    }
    if (_kycStatus == 'rejected') {
      return 'KYC was rejected. Review the customer documents before handover.';
    }
    return 'KYC has not been completed. Vehicle handover should not proceed until your rental policy requirements are satisfied.';
  }

  // ============================================================
  // LIFECYCLE
  // ============================================================

  bool get _pickupDue =>
      DateTime.now().isAfter(_booking.pickupDateTime) ||
      DateTime.now().isAtSameMomentAs(_booking.pickupDateTime);

  bool get _returnDue =>
      DateTime.now().isAfter(_booking.returnDateTime) ||
      DateTime.now().isAtSameMomentAs(_booking.returnDateTime);

  bool get _canConfirm =>
      _booking.status == BookingStatus.pending;

  bool get _canCancel =>
      _booking.status == BookingStatus.pending ||
      _booking.status == BookingStatus.confirmed ||
      _booking.status == BookingStatus.pickupPending;

  bool get _canNoShow =>
      _booking.status == BookingStatus.confirmed ||
      _booking.status == BookingStatus.pickupPending;

  bool get _canPreparePickup =>
      _booking.status == BookingStatus.confirmed && _pickupDue;

  bool get _canOpenPickupPending =>
      _booking.status == BookingStatus.pickupPending;

  bool get _canStartReturn =>
      _booking.status == BookingStatus.active;

  bool get _canOpenReturnPending =>
      _booking.status == BookingStatus.returnPending;

  bool get _isTerminal =>
      _booking.status == BookingStatus.completed ||
      _booking.status == BookingStatus.cancelled ||
      _booking.status == BookingStatus.rejected ||
      _booking.status == BookingStatus.noShow;

  Future<void> _confirmBooking() async {
    if (!_canConfirm) return;

    await _runAction(
      successMessage: 'Booking confirmed.',
      action: () => _bookingService.updateBookingStatusForAdmin(
        tenantId: _tenantId,
        bookingId: _booking.bookingId,
        status: BookingStatus.confirmed,
      ),
    );
  }

  Future<void> _preparePickup() async {
    if (!_canPreparePickup) return;

    final confirmed = await _confirm(
      title: 'Move booking to Pickup Pending?',
      message:
          'This will move the booking into the Pickup Pending operational queue. '
          'The vehicle will NOT be marked Active yet. Physical handover must be '
          'completed from the Pickup Pending screen.',
      confirmText: 'Open Pickup Pending',
      color: blue,
    );

    if (!confirmed || !mounted) return;

    if (_actionBusy) return;
    setState(() => _actionBusy = true);

    try {
      await _revalidateBookingBeforeAction();

      if (_booking.status != BookingStatus.confirmed) {
        throw Exception('Booking changed state. Refresh and try again.');
      }

      if (!_pickupDue) {
        throw Exception('Pickup is not due yet.');
      }

      await _bookingService.updateBookingStatusForAdmin(
        tenantId: _tenantId,
        bookingId: _booking.bookingId,
        status: BookingStatus.pickupPending,
      );

      await _loadAll(showLoader: false);

      if (!mounted) return;
      await _openPickupPendingScreen();

      if (!mounted) return;
      await _loadAll(showLoader: false);
    } catch (e) {
      if (!mounted) return;
      _showMessage(_cleanError(e.toString()), error: true);
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _openPickupPendingScreen() async {
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const PickupPendingScreen(),
      ),
    );

    if (!mounted) return;
    await _loadAll(showLoader: false);
  }

  Future<void> _startReturn() async {
    if (!_canStartReturn) return;

    final confirmed = await _confirm(
      title: 'Move booking to Return Pending?',
      message:
          'This will move the active rental into Return Pending. '
          'The vehicle will not be marked Completed until the physical return '
          'inspection is completed from the Return Pending screen.',
      confirmText: 'Open Return Pending',
      color: purple,
    );

    if (!confirmed || !mounted) return;

    if (_actionBusy) return;
    setState(() => _actionBusy = true);

    try {
      await _revalidateBookingBeforeAction();

      if (_booking.status != BookingStatus.active) {
        throw Exception('Booking changed state. Refresh and try again.');
      }

      await _bookingService.markReturnStartedForAdmin(
        tenantId: _tenantId,
        bookingId: _booking.bookingId,
      );

      await _loadAll(showLoader: false);

      if (!mounted) return;
      await _openReturnPendingScreen();

      if (!mounted) return;
      await _loadAll(showLoader: false);
    } catch (e) {
      if (!mounted) return;
      _showMessage(_cleanError(e.toString()), error: true);
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _openReturnPendingScreen() async {
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ReturnPendingScreen(),
      ),
    );

    if (!mounted) return;
    await _loadAll(showLoader: false);
  }

  Future<void> _openCurrentOperationalScreen() async {
    if (_booking.status == BookingStatus.pickupPending) {
      await _openPickupPendingScreen();
      return;
    }

    if (_booking.status == BookingStatus.returnPending) {
      await _openReturnPendingScreen();
    }
  }

  Future<void> _cancelBooking() async {
    if (!_canCancel) return;

    final reason = await _reasonDialog(
      title: 'Cancel booking',
      hint: 'Enter cancellation reason',
      confirmText: 'Cancel Booking',
    );

    if (reason == null) return;

    await _runAction(
      successMessage: 'Booking cancelled.',
      action: () => _bookingService.cancelBookingForAdmin(
        tenantId: _tenantId,
        bookingId: _booking.bookingId,
        reason: reason,
      ),
    );
  }

  Future<void> _rejectBooking() async {
    if (_booking.status != BookingStatus.pending) return;

    final reason = await _reasonDialog(
      title: 'Reject booking',
      hint: 'Enter rejection reason',
      confirmText: 'Reject Booking',
    );

    if (reason == null) return;

    await _runAction(
      successMessage: 'Booking rejected.',
      action: () => _bookingService.updateBookingStatusForAdmin(
        tenantId: _tenantId,
        bookingId: _booking.bookingId,
        status: BookingStatus.rejected,
      ),
    );
  }

  Future<void> _markNoShow() async {
    if (!_canNoShow) return;

    final reason = await _reasonDialog(
      title: 'Mark no-show',
      hint: 'Enter no-show reason',
      confirmText: 'Mark No-show',
    );

    if (reason == null) return;

    await _runAction(
      successMessage: 'Booking marked as no-show.',
      action: () => _bookingService.updateBookingStatusForAdmin(
        tenantId: _tenantId,
        bookingId: _booking.bookingId,
        status: BookingStatus.noShow,
      ),
    );
  }

  Future<void> _runAction({
    required Future<void> Function() action,
    required String successMessage,
  }) async {
    if (_actionBusy) return;

    setState(() => _actionBusy = true);

    try {
      // Always re-read immediately before a lifecycle/payment action.
      // This prevents acting on stale status data when another admin/device
      // has changed the booking.
      await _revalidateBookingBeforeAction();
      await action();
      await _loadAll(showLoader: false);

      if (!mounted) return;
      _showMessage(successMessage);
    } catch (e) {
      if (!mounted) return;
      _showMessage(_cleanError(e.toString()), error: true);
    } finally {
      if (mounted) {
        setState(() => _actionBusy = false);
      }
    }
  }


  // ============================================================
  // PAYMENT LEDGER ACTIONS
  // ============================================================

  Future<void> _addPayment() async {
    if (_actionBusy || _booking.isFinished || !_booking.hasBalance) return;

    final result = await _showPaymentDialog(
      maxAmount: _booking.balanceAmount,
      title: 'Record Payment',
      actionLabel: 'Record Payment',
    );
    if (result == null) return;

    setState(() => _actionBusy = true);

    try {
      await _revalidateBookingBeforeAction();

      final amount = result['amount'] as double;
      if (amount > _booking.balanceAmount + 0.009) {
        throw Exception('Payment amount exceeds the current outstanding balance.');
      }

      await _bookingService.addPaymentForAdmin(
        tenantId: _tenantId,
        bookingId: _booking.bookingId,
        amount: amount,
        method: result['method'] as PaymentMethodType,
        transactionReference: result['reference'] as String?,
        note: result['note'] as String?,
        paymentDate: DateTime.now(),
      );

      await _loadAll(showLoader: false);

      if (!mounted) return;
      _showMessage('Payment recorded in the booking ledger.');
    } catch (e) {
      if (!mounted) return;
      _showMessage(_cleanError(e.toString()), error: true);
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _editPayment(PaymentTransaction transaction) async {
    if (_actionBusy) return;

    final result = await _showEditPaymentDialog(transaction);
    if (result == null) return;

    final confirmed = await _confirm(
      title: 'Save payment changes?',
      message:
          'The existing transaction will be updated and the previous values will be kept in its audit history.',
      confirmText: 'Save Changes',
      color: primary,
    );
    if (!confirmed) return;

    setState(() => _actionBusy = true);

    try {
      await _revalidateBookingBeforeAction();

      await _bookingService.updatePaymentForAdmin(
        tenantId: _tenantId,
        bookingId: _booking.bookingId,
        paymentId: transaction.paymentId,
        amount: result['amount'] as double,
        method: result['method'] as PaymentMethodType,
        transactionReference: result['reference'] as String?,
        note: result['note'] as String?,
        razorpayPaymentId: result['razorpayPaymentId'] as String?,
        gatewayTransactionId: result['gatewayTransactionId'] as String?,
        paymentDate: result['paymentDate'] as DateTime?,
      );

      await _loadAll(showLoader: false);

      if (!mounted) return;
      _showMessage('Payment details updated and audit information recorded.');
    } catch (e) {
      if (!mounted) return;
      _showMessage(_cleanError(e.toString()), error: true);
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<Map<String, dynamic>?> _showEditPaymentDialog(
    PaymentTransaction transaction,
  ) async {
    return showDialog<Map<String, dynamic>>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (_) => _PaymentEditDialog(transaction: transaction),
    );
  }

  Future<void> _refundPayment() async {
    if (_actionBusy || _booking.paidAmount <= _booking.refundAmount + 0.009) {
      return;
    }

    final refundable =
        (_booking.paidAmount - _booking.refundAmount).clamp(0.0, double.infinity);

    final result = await _showPaymentDialog(
      maxAmount: refundable,
      title: 'Record Refund',
      actionLabel: 'Record Refund',
      isRefund: true,
    );
    if (result == null) return;

    final confirmed = await _confirm(
      title: 'Confirm refund?',
      message:
          'This will create a separate immutable refund transaction and update the booking payment summary.',
      confirmText: 'Record Refund',
      color: purple,
    );
    if (!confirmed) return;

    setState(() => _actionBusy = true);

    try {
      await _revalidateBookingBeforeAction();

      final amount = result['amount'] as double;
      final currentRefundable =
          (_booking.paidAmount - _booking.refundAmount).clamp(0.0, double.infinity);

      if (amount > currentRefundable + 0.009) {
        throw Exception('Refund amount exceeds the current refundable amount.');
      }

      await _bookingService.refundPaymentForAdmin(
        tenantId: _tenantId,
        bookingId: _booking.bookingId,
        amount: amount,
        method: PaymentMethodType.other,
        transactionReference: result['reference'] as String?,
        note: result['note'] as String?,
        paymentDate: DateTime.now(),
      );

      await _loadAll(showLoader: false);

      if (!mounted) return;
      _showMessage('Refund recorded in the payment ledger.');
    } catch (e) {
      if (!mounted) return;
      _showMessage(_cleanError(e.toString()), error: true);
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<Map<String, dynamic>?> _showPaymentDialog({
    required double maxAmount,
    required String title,
    required String actionLabel,
    bool isRefund = false,
  }) async {
    // Use a dedicated StatefulWidget instead of StatefulBuilder here.
    // This keeps the dialog's state inside its own route element and avoids
    // inherited-widget dependents surviving dialog deactivation.
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (_) => _PaymentEntryDialog(
        maxAmount: maxAmount,
        title: title,
        actionLabel: actionLabel,
        isRefund: isRefund,
      ),
    );

    return result;
  }

  // ============================================================
  // DIALOGS
  // ============================================================

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmText,
    required Color color,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: card,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: _text(title, size: 19, weight: FontWeight.w900),
          content: _text(
            message,
            size: 13,
            color: body,
            height: 1.5,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: _text(
                'Go Back',
                color: muted,
                weight: FontWeight.w800,
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _text(
                confirmText,
                color: Colors.white,
                weight: FontWeight.w800,
              ),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  Future<String?> _reasonDialog({
    required String title,
    required String hint,
    required String confirmText,
  }) async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: card,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: _text(title, size: 18, weight: FontWeight.w900),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: border),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: _text('Back', color: muted, weight: FontWeight.w800),
            ),
            ElevatedButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isEmpty) return;
                Navigator.pop(context, value);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: danger,
                elevation: 0,
              ),
              child: _text(
                confirmText,
                color: Colors.white,
                weight: FontWeight.w800,
              ),
            ),
          ],
        );
      },
    );

    controller.dispose();
    return result;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: background,
        appBar: _appBar(),
        body: const Center(
          child: CircularProgressIndicator(color: primary),
        ),
      );
    }

    if (_error != null && _booking.bookingId.isEmpty) {
      return Scaffold(
        backgroundColor: background,
        appBar: _appBar(),
        body: _errorState(),
      );
    }

    return Scaffold(
      backgroundColor: background,
      appBar: _appBar(),
      body: RefreshIndicator(
        color: primary,
        onRefresh: _refresh,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1100;

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                wide ? 32 : 16,
                20,
                wide ? 32 : 16,
                40,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1500),
                  child: wide ? _desktopLayout() : _mobileLayout(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _appBar() {
    return AppBar(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleSpacing: 18,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _text(
            'Booking Details',
            size: 18,
            weight: FontWeight.w900,
          ),
          _text(
            _booking.bookingId.isEmpty
                ? 'Booking'
                : _booking.bookingId,
            size: 11,
            color: muted,
            weight: FontWeight.w700,
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Center(
            child: _text(
              _lastVerifiedText,
              size: 9,
              color: muted,
              weight: FontWeight.w800,
            ),
          ),
        ),
        if (_refreshing)
          const Padding(
            padding: EdgeInsets.only(right: 18),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: primary,
              ),
            ),
          )
        else
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded, color: body),
          ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _desktopLayout() {
    return Column(
      children: [
        _hero(),
        const SizedBox(height: 16),
        _lifecycle(),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 7,
              child: Column(
                children: [
                  _vehicleCard(),
                  const SizedBox(height: 16),
                  _customerCard(),
                  const SizedBox(height: 16),
                  _scheduleCard(),
                  const SizedBox(height: 16),
                  _pricingCard(),
                  const SizedBox(height: 16),
                  _paymentCard(),
                  const SizedBox(height: 16),
                  _branchCard(),
                  const SizedBox(height: 16),
                  _notesCard(),
                ],
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 390,
              child: Column(
                children: [
                  _actionCard(),
                  const SizedBox(height: 16),
                  _kycCard(),
                  const SizedBox(height: 16),
                  _operationalReadiness(),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _mobileLayout() {
    return Column(
      children: [
        _hero(),
        const SizedBox(height: 14),
        _lifecycle(),
        const SizedBox(height: 14),
        _actionCard(),
        const SizedBox(height: 14),
        _kycCard(),
        const SizedBox(height: 14),
        _operationalReadiness(),
        const SizedBox(height: 14),
        _vehicleCard(),
        const SizedBox(height: 14),
        _customerCard(),
        const SizedBox(height: 14),
        _scheduleCard(),
        const SizedBox(height: 14),
        _pricingCard(),
        const SizedBox(height: 14),
        _paymentCard(),
        const SizedBox(height: 14),
        _paymentLedgerCard(),
        const SizedBox(height: 14),
        _branchCard(),
        const SizedBox(height: 14),
        _notesCard(),
      ],
    );
  }

  // ============================================================
  // HERO
  // ============================================================

  Widget _hero() {
    final color = _statusColor(_booking.status);

    return _card(
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              color.withOpacity(.045),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 650;

              final identity = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _vehicleAvatar(),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _pill(
                              _statusLabel(_booking.status),
                              color,
                              icon: _statusIcon(_booking.status),
                            ),
                            _pill(
                              _paymentLabel(_booking.paymentStatus),
                              _paymentColor(_booking.paymentStatus),
                              icon: Icons.payments_rounded,
                            ),
                            if (!_kycVerified)
                              _pill(
                                _kycLabel,
                                _kycColor,
                                icon: Icons.verified_user_outlined,
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _text(
                          _booking.car?.name.isNotEmpty == true
                              ? _booking.car!.name
                              : 'Vehicle',
                          size: 24,
                          weight: FontWeight.w900,
                        ),
                        const SizedBox(height: 5),
                        _text(
                          '${_booking.customerName.isEmpty ? 'Customer' : _booking.customerName}  •  ${_booking.bookingId}',
                          size: 12,
                          color: muted,
                          weight: FontWeight.w700,
                        ),
                      ],
                    ),
                  ),
                ],
              );

              final amount = Column(
                crossAxisAlignment:
                    compact ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                children: [
                  _text(
                    'BOOKING VALUE',
                    size: 9,
                    color: muted,
                    weight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                  const SizedBox(height: 4),
                  _text(
                    _money(_booking.totalAmount),
                    size: 23,
                    weight: FontWeight.w900,
                  ),
                  const SizedBox(height: 3),
                  _text(
                    '${_money(_booking.paidAmount)} paid  •  ${_money(_booking.balanceAmount)} due',
                    size: 10.5,
                    color: _booking.hasBalance ? danger : success,
                    weight: FontWeight.w800,
                  ),
                ],
              );

              return Column(
                children: [
                  identity,
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.verified_rounded,
                        size: 14,
                        color: success,
                      ),
                      const SizedBox(width: 6),
                      _text(
                        _lastVerifiedText,
                        size: 9.5,
                        color: muted,
                        weight: FontWeight.w800,
                      ),
                      const Spacer(),
                      if (_refreshing)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.8,
                            color: primary,
                          ),
                        ),
                    ],
                  ),
                  if (compact) ...[
                    const SizedBox(height: 18),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: amount,
                    ),
                  ] else ...[
                    const SizedBox(height: 16),
                    const Divider(color: border, height: 1),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _miniStat(
                          'PICKUP',
                          _dateTime(_booking.pickupDateTime),
                          Icons.login_rounded,
                          blue,
                        ),
                        _verticalDivider(),
                        _miniStat(
                          'RETURN',
                          _dateTime(_booking.returnDateTime),
                          Icons.logout_rounded,
                          purple,
                        ),
                        const Spacer(),
                        amount,
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _vehicleAvatar() {
    final image = _booking.car?.image ?? '';

    return Container(
      width: 74,
      height: 74,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: image.trim().isEmpty
          ? const Icon(
              Icons.directions_car_filled_rounded,
              size: 34,
              color: muted,
            )
          : Image.network(
              image,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.directions_car_filled_rounded,
                size: 34,
                color: muted,
              ),
            ),
    );
  }

  // ============================================================
  // LIFECYCLE
  // ============================================================

  Widget _lifecycle() {
    final statuses = <BookingStatus>[
      BookingStatus.pending,
      BookingStatus.confirmed,
      BookingStatus.pickupPending,
      BookingStatus.active,
      BookingStatus.returnPending,
      BookingStatus.completed,
    ];

    final currentIndex = _lifecycleIndex(_booking.status);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'Booking Lifecycle',
            'Operational state of this rental',
            Icons.timeline_rounded,
          ),
          const SizedBox(height: 18),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (int i = 0; i < statuses.length; i++) ...[
                  _lifecycleStep(
                    statuses[i],
                    i,
                    currentIndex,
                  ),
                  if (i != statuses.length - 1)
                    Container(
                      width: 42,
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 7),
                      color: i < currentIndex ? success : border,
                    ),
                ],
              ],
            ),
          ),
          if (_booking.status == BookingStatus.pickupPending)
            _alertStrip(
              'Pickup Pending',
              'Vehicle handover is required. Record the actual pickup only when the vehicle is physically handed over.',
              warning,
              Icons.key_rounded,
            ),
          if (_booking.status == BookingStatus.returnPending)
            _alertStrip(
              'Return Pending',
              'Vehicle return inspection is required before this booking can be completed.',
              purple,
              Icons.fact_check_rounded,
            ),
        ],
      ),
    );
  }

  Widget _lifecycleStep(
    BookingStatus status,
    int index,
    int currentIndex,
  ) {
    final isCurrent = index == currentIndex;
    final complete = index < currentIndex;

    final color = isCurrent
        ? _statusColor(status)
        : complete
            ? success
            : border;

    return SizedBox(
      width: 92,
      child: Column(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(isCurrent || complete ? .11 : .55),
              shape: BoxShape.circle,
              border: Border.all(
                color: color,
                width: isCurrent ? 2 : 1,
              ),
            ),
            child: Icon(
              complete
                  ? Icons.check_rounded
                  : _statusIcon(status),
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          _text(
            _statusLabel(status),
            size: 9.5,
            color: isCurrent ? heading : muted,
            weight: isCurrent ? FontWeight.w900 : FontWeight.w700,
            align: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ACTIONS
  // ============================================================

  Widget _actionCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'Operations',
            'Actions available for this booking',
            Icons.flash_on_rounded,
          ),
          const SizedBox(height: 15),
          if (_actionBusy)
            const LinearProgressIndicator(
              color: primary,
              backgroundColor: Color(0xFFE9EDF5),
            ),
          if (_actionBusy) const SizedBox(height: 14),
          ..._actionButtons(),
        ],
      ),
    );
  }

  List<Widget> _actionButtons() {
    final result = <Widget>[];

    if (_canConfirm) {
      result.add(
        _actionButton(
          'Confirm Booking',
          'Approve this booking and move it to Confirmed.',
          Icons.check_circle_outline_rounded,
          primary,
          _actionBusy ? null : _confirmBooking,
        ),
      );
    }

    if (_canPreparePickup) {
      result.add(
        _actionButton(
          'Open Pickup Pending',
          'Move this booking into the Pickup Pending queue. Physical handover is completed there.',
          Icons.key_rounded,
          blue,
          _actionBusy ? null : _preparePickup,
        ),
      );
    } else if (_booking.status == BookingStatus.confirmed) {
      result.add(
        _disabledAction(
          'Pickup Scheduled',
          _pickupDue
              ? 'Pickup is due, but another verification is currently required.'
              : 'Pickup action becomes available when the scheduled pickup time is reached.',
          _pickupDue
              ? Icons.verified_user_outlined
              : Icons.schedule_rounded,
        ),
      );
    }

    if (_canOpenPickupPending) {
      result.add(
        _actionButton(
          'Open Pickup Pending',
          _kycVerified
              ? 'Complete the physical handover, capture odometer, fuel, evidence, and activate the rental.'
              : 'Open the pickup queue. KYC must be verified before physical handover.',
          Icons.key_rounded,
          blue,
          _actionBusy ? null : _openCurrentOperationalScreen,
        ),
      );
    }

    if (_canStartReturn) {
      result.add(
        _actionButton(
          'Open Return Pending',
          'Move the active rental to Return Pending for physical return inspection.',
          Icons.assignment_return_rounded,
          purple,
          _actionBusy ? null : _startReturn,
        ),
      );
    }

    if (_canOpenReturnPending) {
      result.add(
        _actionButton(
          'Open Return Pending',
          'Complete the return inspection, charges, evidence, and close the rental.',
          Icons.fact_check_rounded,
          success,
          _actionBusy ? null : _openCurrentOperationalScreen,
        ),
      );
    }

    if (_canCancel) {
      result.add(
        _outlineAction(
          'Cancel Booking',
          Icons.cancel_outlined,
          danger,
          _actionBusy ? null : _cancelBooking,
        ),
      );
    }

    if (_booking.status == BookingStatus.pending) {
      result.add(
        _outlineAction(
          'Reject Booking',
          Icons.block_rounded,
          danger,
          _actionBusy ? null : _rejectBooking,
        ),
      );
    }

    if (_canNoShow) {
      result.add(
        _outlineAction(
          'Mark No-show',
          Icons.person_off_rounded,
          muted,
          _actionBusy ? null : _markNoShow,
        ),
      );
    }

    if (result.isEmpty) {
      result.add(
        _disabledAction(
          'No operational actions',
          _isTerminal
              ? 'This booking is in a terminal state.'
              : 'No action is currently available.',
          Icons.lock_outline_rounded,
        ),
      );
    }

    return [
      for (int i = 0; i < result.length; i++) ...[
        result[i],
        if (i != result.length - 1) const SizedBox(height: 9),
      ],
    ];
  }

  // ============================================================
  // KYC
  // ============================================================

  Widget _kycCard() {
    return _card(
      borderColor: _kycVerified ? border : _kycColor.withOpacity(.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBox(
                Icons.verified_user_rounded,
                _kycColor,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _text(
                      'Customer KYC',
                      size: 15,
                      weight: FontWeight.w900,
                    ),
                    const SizedBox(height: 2),
                    _text(
                      _kycLabel,
                      size: 10,
                      color: _kycColor,
                      weight: FontWeight.w900,
                      letterSpacing: .8,
                    ),
                  ],
                ),
              ),
              if (_kycVerified)
                const Icon(
                  Icons.verified_rounded,
                  color: success,
                  size: 22,
                ),
            ],
          ),
          const SizedBox(height: 14),
          _alertStrip(
            _kycVerified ? 'KYC ready' : 'KYC attention required',
            _kycAttention,
            _kycColor,
            _kycVerified
                ? Icons.check_circle_outline_rounded
                : Icons.warning_amber_rounded,
          ),
          const SizedBox(height: 14),
          _infoRow(
            'Profile',
            _profileStatus,
            valueColor:
                _profileStatus == 'Complete' ? success : warning,
          ),
          _infoRow(
            'Driving licence',
            _licenseStatus,
          ),
          _infoRow(
            'Government ID',
            _governmentIdStatus,
          ),
          if (_customer != null && widget.onOpenCustomer != null) ...[
            const SizedBox(height: 10),
            _outlineAction(
              'Open Customer Profile',
              Icons.person_outline_rounded,
              primary,
              _actionBusy
                  ? null
                  : () => widget.onOpenCustomer!(_customer!),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // READINESS
  // ============================================================

  Widget _operationalReadiness() {
    final pickupReady = _booking.status == BookingStatus.confirmed &&
        _pickupDue &&
        (_kycVerified || _customer == null);

    final returnReady = _booking.status == BookingStatus.returnPending;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'Operational Readiness',
            'What the team needs to verify',
            Icons.fact_check_outlined,
          ),
          const SizedBox(height: 15),
          _readiness(
            'Customer profile',
            _customer != null && (_customer!.profileCompleted),
            _customer == null ? 'Customer record unavailable' : null,
          ),
          _readiness(
            'KYC verification',
            _kycVerified,
            _kycVerified ? null : 'KYC is not verified',
          ),
          _readiness(
            'Pickup timing',
            _pickupDue,
            _pickupDue ? null : 'Pickup time has not been reached',
          ),
          _readiness(
            'Physical handover',
            _booking.actualPickupDateTime != null,
            _booking.actualPickupDateTime == null
                ? 'Vehicle has not been handed over'
                : null,
          ),
          _readiness(
            'Return inspection',
            returnReady
                ? false
                : _booking.actualReturnDateTime != null,
            returnReady
                ? 'Return inspection is pending'
                : null,
          ),
          _readiness(
            'Payment',
            !_booking.hasBalance,
            _booking.hasBalance
                ? '${_money(_booking.balanceAmount)} outstanding'
                : null,
          ),
          if (_booking.status == BookingStatus.confirmed &&
              !_kycVerified)
            _alertStrip(
              'KYC check',
              'The customer has not completed verified KYC. Follow your rental company policy before physical handover.',
              danger,
              Icons.security_rounded,
            ),
        ],
      ),
    );
  }

  // ============================================================
  // VEHICLE
  // ============================================================

  Widget _vehicleCard() {
    final car = _booking.car;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'Vehicle',
            'Historical vehicle snapshot from booking',
            Icons.directions_car_filled_rounded,
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _vehicleLargeImage(car?.image ?? ''),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _text(
                      car?.name.isNotEmpty == true
                          ? car!.name
                          : 'Vehicle not available',
                      size: 18,
                      weight: FontWeight.w900,
                    ),
                    const SizedBox(height: 4),
                    _text(
                      [
                        if (car?.type.isNotEmpty == true) car!.type,
                        if (car?.transmission.isNotEmpty == true)
                          car!.transmission,
                        if (car?.fuel.isNotEmpty == true) car!.fuel,
                      ].join('  •  '),
                      size: 11,
                      color: muted,
                      weight: FontWeight.w700,
                    ),
                    const SizedBox(height: 13),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _smallTag(
                          '${car?.seats ?? 0} Seats',
                          Icons.event_seat_rounded,
                        ),
                        if (_booking.rentalType.isNotEmpty)
                          _smallTag(
                            _prettyStatus(_booking.rentalType),
                            Icons.schedule_rounded,
                          ),
                        if (_booking.unlimitedKm)
                          _smallTag(
                            'Unlimited KM',
                            Icons.all_inclusive_rounded,
                          )
                        else
                          _smallTag(
                            '${_booking.includedKm} KM Included',
                            Icons.speed_rounded,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CUSTOMER
  // ============================================================

  Widget _customerCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'Customer',
            'Customer identity attached to this booking',
            Icons.person_rounded,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _customerAvatar(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _text(
                      _booking.customerName.isEmpty
                          ? (_customer?.fullName.isNotEmpty == true
                              ? _customer!.fullName
                              : 'Customer')
                          : _booking.customerName,
                      size: 17,
                      weight: FontWeight.w900,
                    ),
                    const SizedBox(height: 3),
                    _text(
                      _booking.customerPhone.isEmpty
                          ? (_customer?.phone ?? '—')
                          : _booking.customerPhone,
                      size: 11,
                      color: muted,
                      weight: FontWeight.w700,
                    ),
                  ],
                ),
              ),
              if (_customer != null)
                _pill(
                  _customer!.isActive ? 'ACTIVE ACCOUNT' : 'INACTIVE',
                  _customer!.isActive ? success : danger,
                ),
            ],
          ),
          const SizedBox(height: 17),
          const Divider(color: border, height: 1),
          const SizedBox(height: 13),
          _infoRow(
            'Email',
            _booking.customerEmail.isNotEmpty
                ? _booking.customerEmail
                : (_customer?.email ?? '—'),
          ),
          _infoRow('Customer ID', _booking.customerId),
          _infoRow('KYC', _kycLabel, valueColor: _kycColor),
          _infoRow(
            'Total bookings',
            '${_customer?.totalBookings ?? 0}',
          ),
          _infoRow(
            'Completed',
            '${_customer?.completedBookings ?? 0}',
            valueColor: success,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SCHEDULE
  // ============================================================

  Widget _scheduleCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'Rental Schedule',
            'Planned and actual timestamps',
            Icons.calendar_month_rounded,
          ),
          const SizedBox(height: 16),
          _timelineRow(
            'Pickup scheduled',
            _dateTime(_booking.pickupDateTime),
            Icons.login_rounded,
            blue,
          ),
          _timelineRow(
            'Actual pickup',
            _booking.actualPickupDateTime == null
                ? 'Not recorded'
                : _dateTime(_booking.actualPickupDateTime!),
            Icons.key_rounded,
            _booking.actualPickupDateTime == null ? muted : success,
          ),
          _timelineRow(
            'Return scheduled',
            _dateTime(_booking.returnDateTime),
            Icons.logout_rounded,
            purple,
          ),
          _timelineRow(
            'Actual return',
            _booking.actualReturnDateTime == null
                ? 'Not recorded'
                : _dateTime(_booking.actualReturnDateTime!),
            Icons.assignment_return_rounded,
            _booking.actualReturnDateTime == null ? muted : success,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PRICING
  // ============================================================

  Widget _pricingCard() {
  final couponCode = (_booking.couponCode ?? '').trim();

  return _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          'Pricing Breakdown',
          'Historical pricing snapshot',
          Icons.receipt_long_rounded,
        ),
        const SizedBox(height: 14),

        _amountRow(
          'Base rental',
          _booking.baseAmount,
        ),

        _amountRow(
          'Extra KM',
          _booking.extraKmAmount,
        ),

        _amountRow(
          'Extra time',
          _booking.extraTimeAmount,
        ),

        _amountRow(
          'Add-ons',
          _booking.addOnsAmount,
        ),

        _amountRow(
          'Protection',
          _booking.protectionAmount,
        ),

        _amountRow(
          'Tax',
          _booking.taxAmount,
        ),

        _amountRow(
          'Discount',
          -_booking.discountAmount,
          valueColor: success,
        ),

        _amountRow(
          'Security deposit',
          _booking.securityDeposit,
        ),

        const Divider(
          color: border,
          height: 20,
        ),

        _amountRow(
          'Total booking value',
          _booking.totalAmount,
          strong: true,
        ),

        if (couponCode.isNotEmpty)
          _infoRow(
            'Coupon',
            couponCode,
            valueColor: success,
          ),
      ],
    ),
  );
}

  // ============================================================
  // PAYMENT
  // ============================================================

  Widget _paymentCard() {
    final total = _booking.totalAmount <= 0 ? 1 : _booking.totalAmount;
    final progress =
        (_booking.paidAmount / total).clamp(0.0, 1.0);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'Payment',
            'Collection and balance status',
            Icons.account_balance_wallet_rounded,
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: _text(
                  _paymentLabel(_booking.paymentStatus),
                  size: 14,
                  weight: FontWeight.w900,
                  color: _paymentColor(_booking.paymentStatus),
                ),
              ),
              _text(
                '${(progress * 100).round()}% paid',
                size: 11,
                color: muted,
                weight: FontWeight.w800,
              ),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: progress,
              backgroundColor: const Color(0xFFE9EDF3),
              valueColor: AlwaysStoppedAnimation<Color>(
                _booking.hasBalance ? warning : success,
              ),
            ),
          ),
          const SizedBox(height: 15),
          _amountRow('Total', _booking.totalAmount, strong: true),
          _amountRow(
            'Paid',
            _booking.paidAmount,
            valueColor: success,
          ),
          _amountRow(
            'Refund',
            _booking.refundAmount,
            valueColor:
                _booking.hasRefund ? warning : muted,
          ),
          _amountRow(
            'Outstanding',
            _booking.balanceAmount,
            strong: true,
            valueColor:
                _booking.hasBalance ? danger : success,
          ),
          _infoRow(
            'Payment method',
            _booking.paymentMethod ?? 'Not recorded',
          ),
          _infoRow(
            'Payment ID',
            _booking.paymentId ?? 'Not recorded',
          ),
          _infoRow(
            'Order ID',
            _booking.paymentOrderId ?? 'Not recorded',
          ),
          _infoRow(
            'Transaction ID',
            _booking.paymentTransactionId ?? 'Not recorded',
          ),
        ],
      ),
    );
  }


  Widget _paymentLedgerCard() {
    final refundable =
        (_booking.paidAmount - _booking.refundAmount).clamp(0.0, double.infinity);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _sectionTitle(
                  'Payment Ledger',
                  'Immutable payment and refund transaction history',
                  Icons.receipt_long_rounded,
                ),
              ),
              IconButton(
                tooltip: 'Refresh payment history',
                onPressed: _paymentsLoading || _actionBusy ? null : _refreshPayments,
                icon: _paymentsLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: primary,
                        ),
                      )
                    : const Icon(Icons.refresh_rounded, color: body),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _amountRow(
                  'Paid',
                  _booking.paidAmount,
                  valueColor: success,
                  strong: true,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _amountRow(
                  'Refunded',
                  _booking.refundAmount,
                  valueColor: purple,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _amountRow(
                  'Refundable',
                  refundable,
                  valueColor: refundable > 0 ? warning : muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (!_booking.isFinished && _booking.hasBalance)
            _actionButton(
              'Add Payment',
              'Record an admin-collected payment through the ledger.',
              Icons.add_card_rounded,
              primary,
              _actionBusy ? null : _addPayment,
            ),
          if (!_booking.isFinished && refundable > 0) ...[
            const SizedBox(height: 9),
            _outlineAction(
              'Record Refund',
              Icons.currency_exchange_rounded,
              purple,
              _actionBusy ? null : _refundPayment,
            ),
          ],
          const SizedBox(height: 15),
          const Divider(color: border, height: 1),
          const SizedBox(height: 12),
          if (_paymentsLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: CircularProgressIndicator(color: primary),
              ),
            )
          else if (_paymentTransactions.isEmpty)
            _text(
              'No ledger transactions recorded for this booking.',
              size: 11,
              color: muted,
              weight: FontWeight.w700,
            )
          else
            ..._paymentTransactions.map(_paymentTransactionTile),
        ],
      ),
    );
  }

  Widget _paymentTransactionTile(PaymentTransaction transaction) {
    final refund = transaction.isRefund;
    final color = refund ? purple : success;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _iconBox(
            refund ? Icons.undo_rounded : Icons.payments_rounded,
            color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _text(
                        refund ? 'Refund' : 'Payment',
                        size: 11,
                        weight: FontWeight.w900,
                      ),
                    ),
                    _text(
                      '${refund ? '-' : '+'}${_money(transaction.amount)}',
                      size: 12,
                      color: color,
                      weight: FontWeight.w900,
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: _actionBusy ? null : () => _editPayment(transaction),
                      borderRadius: BorderRadius.circular(9),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: primary.withOpacity(.08),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(
                          Icons.edit_rounded,
                          size: 14,
                          color: primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                _text(
                  '${_prettyStatus(_paymentMethodToLabel(transaction.method))}  •  ${_prettyStatus(_paymentSourceToLabel(transaction.source))}',
                  size: 9.5,
                  color: muted,
                  weight: FontWeight.w700,
                ),
                if (transaction.transactionReference?.trim().isNotEmpty == true)
                  _infoRow(
                    'Reference',
                    transaction.transactionReference!.trim(),
                  ),
                if (transaction.razorpayPaymentId?.trim().isNotEmpty == true)
                  _infoRow(
                    'Razorpay Payment',
                    transaction.razorpayPaymentId!.trim(),
                  ),
                if (transaction.note?.trim().isNotEmpty == true)
                  _text(
                    transaction.note!.trim(),
                    size: 9.5,
                    color: body,
                    weight: FontWeight.w600,
                    height: 1.35,
                  ),
                if (transaction.paymentDate != null)
                  _text(
                    _dateTime(transaction.paymentDate!),
                    size: 9,
                    color: muted,
                    weight: FontWeight.w700,
                  ),
                if (transaction.recordedBy?.trim().isNotEmpty == true)
                  _text(
                    'Recorded by: ${transaction.recordedBy?.trim().isNotEmpty == true ? transaction.recordedBy!.trim() : 'Unknown'}',
                    size: 9,
                    color: muted,
                    weight: FontWeight.w700,
                  ),
                if (transaction.editedBy?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 2),
                  _text(
                    'Edited by: ${_paymentEditorLabel(transaction)} • ${transaction.editedByRole ?? 'admin'}${transaction.editedAt == null ? '' : ' • ${_dateTime(transaction.editedAt!)}'}',
                    size: 9,
                    color: primary,
                    weight: FontWeight.w800,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _paymentEditorLabel(PaymentTransaction transaction) {
    return transaction.editedByName?.trim().isNotEmpty == true
        ? transaction.editedByName!.trim()
        : (transaction.editedBy?.trim().isNotEmpty == true
            ? transaction.editedBy!.trim()
            : 'Unknown admin');
  }

  String _paymentMethodToLabel(PaymentMethodType method) {
    switch (method) {
      case PaymentMethodType.razorpay:
        return 'Razorpay';
      case PaymentMethodType.cash:
        return 'Cash';
      case PaymentMethodType.upi:
        return 'UPI';
      case PaymentMethodType.card:
        return 'Card';
      case PaymentMethodType.bankTransfer:
        return 'Bank Transfer';
      case PaymentMethodType.other:
        return 'Other';
    }
  }

  String _paymentSourceToLabel(PaymentSource source) {
    switch (source) {
      case PaymentSource.customer:
        return 'Customer';
      case PaymentSource.admin:
        return 'Admin';
      case PaymentSource.system:
        return 'System';
    }
  }

  // ============================================================
  // BRANCHES
  // ============================================================

  Widget _branchCard() {
    final pickup = _booking.pickupBranch;
    final drop = _booking.returnBranch;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'Branches',
            'Pickup and return locations',
            Icons.location_on_rounded,
          ),
          const SizedBox(height: 16),
          _branch(
            'Pickup',
            pickup?.name ?? 'Branch not available',
            pickup?.city ?? '',
            pickup?.address ?? '',
            pickup?.phone ?? '',
            blue,
            Icons.login_rounded,
          ),
          const SizedBox(height: 12),
          _branch(
            'Return',
            drop?.name ?? 'Branch not available',
            drop?.city ?? '',
            drop?.address ?? '',
            drop?.phone ?? '',
            purple,
            Icons.logout_rounded,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // NOTES
  // ============================================================

  Widget _notesCard() {
    final customerNote = _booking.customerNote.trim();
    final cancellation = _booking.cancellationReason.trim();
    final rejection = _booking.rejectionReason.trim();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'Booking Notes',
            'Customer and workflow notes',
            Icons.notes_rounded,
          ),
          const SizedBox(height: 14),
          if (customerNote.isNotEmpty)
            _noteBlock(
              'Customer note',
              customerNote,
              blue,
            ),
          if (cancellation.isNotEmpty)
            _noteBlock(
              'Cancellation reason',
              cancellation,
              danger,
            ),
          if (rejection.isNotEmpty)
            _noteBlock(
              'Rejection reason',
              rejection,
              danger,
            ),
          if (customerNote.isEmpty &&
              cancellation.isEmpty &&
              rejection.isEmpty)
            _text(
              'No booking notes recorded.',
              size: 12,
              color: muted,
              weight: FontWeight.w700,
            ),
          const SizedBox(height: 12),
          _infoRow(
            'Created',
            _booking.createdAt == null
                ? '—'
                : _dateTime(_booking.createdAt!),
          ),
          _infoRow(
            'Last updated',
            _booking.updatedAt == null
                ? '—'
                : _dateTime(_booking.updatedAt!),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SMALL UI
  // ============================================================

  Widget _card({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(18),
    Color? borderColor,
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: borderColor ?? border,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0818212F),
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionTitle(
    String title,
    String subtitle,
    IconData icon,
  ) {
    return Row(
      children: [
        _iconBox(icon, primary),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _text(
                title,
                size: 14.5,
                weight: FontWeight.w900,
              ),
              const SizedBox(height: 2),
              _text(
                subtitle,
                size: 10.5,
                color: muted,
                weight: FontWeight.w700,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _iconBox(IconData icon, Color color) {
    return Container(
      width: 39,
      height: 39,
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        icon,
        color: color,
        size: 19,
      ),
    );
  }

  Widget _pill(
    String label,
    Color color, {
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(.09),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: color.withOpacity(.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
          ],
          _text(
            label,
            size: 9,
            color: color,
            weight: FontWeight.w900,
            letterSpacing: .45,
          ),
        ],
      ),
    );
  }

  Widget _smallTag(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: muted),
          const SizedBox(width: 5),
          _text(
            label,
            size: 9.5,
            color: body,
            weight: FontWeight.w800,
          ),
        ],
      ),
    );
  }

  Widget _miniStat(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _iconBox(icon, color),
        const SizedBox(width: 9),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _text(
              label,
              size: 8.5,
              color: muted,
              weight: FontWeight.w900,
              letterSpacing: .8,
            ),
            const SizedBox(height: 3),
            _text(
              value,
              size: 10.5,
              color: heading,
              weight: FontWeight.w800,
            ),
          ],
        ),
      ],
    );
  }

  Widget _verticalDivider() {
    return Container(
      width: 1,
      height: 38,
      margin: const EdgeInsets.symmetric(horizontal: 22),
      color: border,
    );
  }

  Widget _infoRow(
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: _text(
              label,
              size: 10.5,
              color: muted,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Align(
              alignment: Alignment.centerRight,
              child: _text(
                value.isEmpty ? '—' : value,
                size: 10.5,
                color: valueColor ?? body,
                weight: FontWeight.w800,
                align: TextAlign.right,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _amountRow(
    String label,
    double value, {
    bool strong = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: _text(
              label,
              size: strong ? 11.5 : 10.5,
              color: strong ? heading : muted,
              weight: strong ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
          _text(
            _money(value),
            size: strong ? 12.5 : 10.5,
            color: valueColor ?? (strong ? heading : body),
            weight: strong ? FontWeight.w900 : FontWeight.w800,
          ),
        ],
      ),
    );
  }

  Widget _timelineRow(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(.09),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 17,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: _text(
              title,
              size: 10.5,
              color: muted,
              weight: FontWeight.w700,
            ),
          ),
          _text(
            value,
            size: 10.5,
            color: value == 'Not recorded' ? muted : heading,
            weight: FontWeight.w800,
            align: TextAlign.right,
          ),
        ],
      ),
    );
  }

  Widget _branch(
    String label,
    String name,
    String city,
    String address,
    String phone,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _iconBox(icon, color),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _text(
                  label.toUpperCase(),
                  size: 8.5,
                  color: color,
                  weight: FontWeight.w900,
                  letterSpacing: .8,
                ),
                const SizedBox(height: 3),
                _text(
                  name,
                  size: 12,
                  weight: FontWeight.w900,
                ),
                if (city.isNotEmpty)
                  _text(
                    city,
                    size: 10.5,
                    color: body,
                    weight: FontWeight.w700,
                  ),
                if (address.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  _text(
                    address,
                    size: 10,
                    color: muted,
                    weight: FontWeight.w600,
                    height: 1.35,
                  ),
                ],
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  _text(
                    phone,
                    size: 10,
                    color: primary,
                    weight: FontWeight.w800,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _noteBlock(
    String title,
    String value,
    Color color,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withOpacity(.055),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withOpacity(.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _text(
            title,
            size: 9,
            color: color,
            weight: FontWeight.w900,
            letterSpacing: .7,
          ),
          const SizedBox(height: 5),
          _text(
            value,
            size: 11,
            color: body,
            weight: FontWeight.w700,
            height: 1.45,
          ),
        ],
      ),
    );
  }

  Widget _alertStrip(
    String title,
    String message,
    Color color,
    IconData icon,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 15),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(.065),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: color.withOpacity(.16),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _text(
                  title,
                  size: 10,
                  color: color,
                  weight: FontWeight.w900,
                ),
                const SizedBox(height: 3),
                _text(
                  message,
                  size: 10,
                  color: body,
                  weight: FontWeight.w700,
                  height: 1.4,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _readiness(
    String title,
    bool complete, [
    String? warningText,
  ]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            complete
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 18,
            color: complete ? success : warning,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _text(
                  title,
                  size: 10.5,
                  color: complete ? body : heading,
                  weight: FontWeight.w800,
                ),
                if (!complete && warningText != null) ...[
                  const SizedBox(height: 2),
                  _text(
                    warningText,
                    size: 9,
                    color: muted,
                    weight: FontWeight.w600,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback? onPressed,
  ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: color,
          disabledBackgroundColor: color.withOpacity(.45),
          padding: const EdgeInsets.symmetric(
            horizontal: 13,
            vertical: 12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 19, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _text(
                    title,
                    size: 11,
                    color: Colors.white,
                    weight: FontWeight.w900,
                  ),
                  const SizedBox(height: 2),
                  _text(
                    subtitle,
                    size: 8.5,
                    color: Colors.white.withOpacity(.82),
                    weight: FontWeight.w600,
                    height: 1.25,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 12,
              color: Colors.white70,
            ),
          ],
        ),
      ),
    );
  }

  Widget _outlineAction(
    String title,
    IconData icon,
    Color color,
    VoidCallback? onPressed,
  ) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 17),
        label: _text(
          title,
          size: 10.5,
          color: onPressed == null ? muted : color,
          weight: FontWeight.w900,
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(
            color: onPressed == null ? border : color.withOpacity(.35),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
      ),
    );
  }

  Widget _disabledAction(
    String title,
    String subtitle,
    IconData icon,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: muted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _text(
                  title,
                  size: 10.5,
                  color: body,
                  weight: FontWeight.w900,
                ),
                const SizedBox(height: 2),
                _text(
                  subtitle,
                  size: 8.5,
                  color: muted,
                  weight: FontWeight.w600,
                  height: 1.3,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _vehicleLargeImage(String url) {
    return Container(
      width: 150,
      height: 100,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: url.trim().isEmpty
          ? const Icon(
              Icons.directions_car_filled_rounded,
              size: 42,
              color: muted,
            )
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.directions_car_filled_rounded,
                size: 42,
                color: muted,
              ),
            ),
    );
  }

  Widget _customerAvatar() {
    final image = _customer?.profileImageUrl ?? '';

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: primary.withOpacity(.09),
        shape: BoxShape.circle,
        border: Border.all(
          color: primary.withOpacity(.14),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: image.trim().isEmpty
          ? const Icon(
              Icons.person_rounded,
              color: primary,
              size: 25,
            )
          : Image.network(
              image,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.person_rounded,
                color: primary,
                size: 25,
              ),
            ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: _card(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: danger,
                size: 44,
              ),
              const SizedBox(height: 12),
              _text(
                'Unable to load booking',
                size: 17,
                weight: FontWeight.w900,
              ),
              const SizedBox(height: 5),
              _text(
                _error ?? 'Unknown error',
                size: 11,
                color: muted,
                align: TextAlign.center,
              ),
              const SizedBox(height: 15),
              ElevatedButton(
                onPressed: _loadAll,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  elevation: 0,
                ),
                child: _text(
                  'Retry',
                  color: Colors.white,
                  weight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessage(
    String message, {
    bool error = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: error ? danger : heading,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Row(
            children: [
              Icon(
                error
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 19,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _text(
                  message,
                  color: Colors.white,
                  size: 11,
                  weight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
  }

  Widget _text(
    String value, {
    double size = 12,
    Color color = heading,
    FontWeight weight = FontWeight.w600,
    double? height,
    double letterSpacing = 0,
    TextAlign align = TextAlign.left,
  }) {
    return Text(
      value,
      textAlign: align,
      style: GoogleFonts.manrope(
        fontSize: size,
        color: color,
        fontWeight: weight,
        height: height,
        letterSpacing: letterSpacing,
      ),
    );
  }

  InputDecoration _input(
    String label, {
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: background,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: primary, width: 1.4),
      ),
    );
  }

  String _money(double value) {
    final format = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    return format.format(value);
  }

  String _dateTime(DateTime value) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(value);
  }

  String _prettyStatus(String value) {
    final cleaned = value
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .trim();

    if (cleaned.isEmpty) return '—';

    return cleaned
        .split(RegExp(r'\s+'))
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  String _statusLabel(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return 'Pending';
      case BookingStatus.confirmed:
        return 'Confirmed';
      case BookingStatus.pickupPending:
        return 'Pickup Pending';
      case BookingStatus.active:
        return 'Active';
      case BookingStatus.returnPending:
        return 'Return Pending';
      case BookingStatus.completed:
        return 'Completed';
      case BookingStatus.cancelled:
        return 'Cancelled';
      case BookingStatus.rejected:
        return 'Rejected';
      case BookingStatus.noShow:
        return 'No Show';
    }
  }

  IconData _statusIcon(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return Icons.hourglass_top_rounded;
      case BookingStatus.confirmed:
        return Icons.check_circle_outline_rounded;
      case BookingStatus.pickupPending:
        return Icons.key_rounded;
      case BookingStatus.active:
        return Icons.directions_car_filled_rounded;
      case BookingStatus.returnPending:
        return Icons.assignment_return_rounded;
      case BookingStatus.completed:
        return Icons.task_alt_rounded;
      case BookingStatus.cancelled:
        return Icons.cancel_outlined;
      case BookingStatus.rejected:
        return Icons.block_rounded;
      case BookingStatus.noShow:
        return Icons.person_off_rounded;
    }
  }

  Color _statusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return warning;
      case BookingStatus.confirmed:
        return primary;
      case BookingStatus.pickupPending:
        return warning;
      case BookingStatus.active:
        return success;
      case BookingStatus.returnPending:
        return purple;
      case BookingStatus.completed:
        return success;
      case BookingStatus.cancelled:
      case BookingStatus.rejected:
      case BookingStatus.noShow:
        return danger;
    }
  }

  int _lifecycleIndex(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return 0;
      case BookingStatus.confirmed:
        return 1;
      case BookingStatus.pickupPending:
        return 2;
      case BookingStatus.active:
        return 3;
      case BookingStatus.returnPending:
        return 4;
      case BookingStatus.completed:
        return 5;
      case BookingStatus.cancelled:
      case BookingStatus.rejected:
      case BookingStatus.noShow:
        return 1;
    }
  }

  String _paymentLabel(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.pending:
        return 'Payment Pending';
      case PaymentStatus.partiallyPaid:
        return 'Partially Paid';
      case PaymentStatus.paid:
        return 'Paid';
      case PaymentStatus.failed:
        return 'Payment Failed';
      case PaymentStatus.refunded:
        return 'Refunded';
      case PaymentStatus.partiallyRefunded:
        return 'Partially Refunded';
    }
  }

  Color _paymentColor(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.pending:
      case PaymentStatus.partiallyPaid:
        return warning;
      case PaymentStatus.paid:
        return success;
      case PaymentStatus.failed:
        return danger;
      case PaymentStatus.refunded:
      case PaymentStatus.partiallyRefunded:
        return purple;
    }
  }
// ================================================================
// SAFE PAYMENT ENTRY DIALOG
// ================================================================

}
class _PaymentEntryDialog extends StatefulWidget {
  const _PaymentEntryDialog({
    required this.maxAmount,
    required this.title,
    required this.actionLabel,
    required this.isRefund,
  });

  final double maxAmount;
  final String title;
  final String actionLabel;
  final bool isRefund;

  @override
  State<_PaymentEntryDialog> createState() => _PaymentEntryDialogState();
}

class _PaymentEntryDialogState extends State<_PaymentEntryDialog> {
  late final TextEditingController _amountController;
  late final TextEditingController _referenceController;
  late final TextEditingController _noteController;

  PaymentMethodType _method = PaymentMethodType.cash;
  String? _validationError;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.maxAmount.toStringAsFixed(0),
    );
    _referenceController = TextEditingController();
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String _methodLabel(PaymentMethodType method) {
    switch (method) {
      case PaymentMethodType.cash:
        return 'Cash';
      case PaymentMethodType.upi:
        return 'UPI';
      case PaymentMethodType.card:
        return 'Card';
      case PaymentMethodType.bankTransfer:
        return 'Bank Transfer';
      case PaymentMethodType.razorpay:
        return 'Razorpay';
      case PaymentMethodType.other:
        return 'Other';
    }
  }

  void _close([Map<String, dynamic>? result]) {
    if (_closing) return;
    _closing = true;
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context, rootNavigator: true).pop(result);
  }

  void _submit() {
    if (_closing) return;

    final amount = double.tryParse(_amountController.text.trim());

    if (amount == null || amount <= 0) {
      setState(() {
        _validationError = 'Enter a valid amount greater than zero.';
      });
      return;
    }

    if (amount > widget.maxAmount + 0.009) {
      setState(() {
        _validationError =
            'Amount cannot be greater than ${_moneyStatic(widget.maxAmount)}.';
      });
      return;
    }

    _close({
      'amount': amount,
      'method': _method,
      'reference': _referenceController.text.trim().isEmpty
          ? null
          : _referenceController.text.trim(),
      'note': _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
    });
  }

  static String _moneyStatic(double value) {
    return '₹${value.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF2563EB);
    const headingColor = Color(0xFF111827);
    const bodyColor = Color(0xFF374151);
    const mutedColor = Color(0xFF6B7280);
    const borderColor = Color(0xFFE5E7EB);
    const backgroundColor = Color(0xFFF8FAFC);
    const cardColor = Colors.white;
    const dangerColor = Color(0xFFDC2626);
    final methods = <PaymentMethodType>[
      PaymentMethodType.cash,
      PaymentMethodType.upi,
      PaymentMethodType.card,
      PaymentMethodType.bankTransfer,
      PaymentMethodType.razorpay,
      PaymentMethodType.other,
    ];

    return AlertDialog(
      backgroundColor: cardColor,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      title: Text(
        widget.title,
        style: const TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w900,
          color: headingColor,
        ),
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: primaryColor.withOpacity(.14)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.verified_user_outlined, color: primaryColor, size: 18),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'This payment will be recorded in the booking payment ledger.',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: bodyColor,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: widget.isRefund ? 'Refund amount' : 'Payment amount',
                  hintText: 'Maximum ${_moneyStatic(widget.maxAmount)}',
                  filled: true,
                  fillColor: backgroundColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: borderColor),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Payment method',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: mutedColor,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: methods.map((item) {
                  final selected = _method == item;
                  return ChoiceChip(
                    label: Text(_methodLabel(item)),
                    selected: selected,
                    onSelected: _closing
                        ? null
                        : (_) => setState(() {
                              _method = item;
                              _validationError = null;
                            }),
                    selectedColor: primaryColor.withOpacity(.12),
                    backgroundColor: backgroundColor,
                    side: BorderSide(
                      color: selected ? primaryColor : borderColor,
                    ),
                    labelStyle: TextStyle(
                      color: selected ? primaryColor : bodyColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _referenceController,
                decoration: InputDecoration(
                  labelText: 'Transaction reference',
                  hintText: 'Optional',
                  filled: true,
                  fillColor: backgroundColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: borderColor),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Note',
                  hintText: widget.isRefund
                      ? 'Refund reason / gateway note'
                      : 'Payment note',
                  filled: true,
                  fillColor: backgroundColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: borderColor),
                  ),
                ),
              ),
              if (_validationError != null) ...[
                const SizedBox(height: 10),
                Text(
                  _validationError!,
                  style: const TextStyle(
                    color: dangerColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _closing ? null : () => _close(),
          child: const Text(
            'Cancel',
            style: TextStyle(
              color: mutedColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        ElevatedButton.icon(
          onPressed: _closing ? null : _submit,
          icon: const Icon(Icons.save_rounded, size: 17),
          label: Text(
            widget.actionLabel,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
}





class _PaymentEditDialog extends StatefulWidget {
  const _PaymentEditDialog({required this.transaction});

  final PaymentTransaction transaction;

  @override
  State<_PaymentEditDialog> createState() => _PaymentEditDialogState();
}

class _PaymentEditDialogState extends State<_PaymentEditDialog> {
  static const Color background = Color(0xFFF6F8FB);
  static const Color card = Colors.white;
  static const Color heading = Color(0xFF18212F);
  static const Color body = Color(0xFF425066);
  static const Color muted = Color(0xFF758195);
  static const Color border = Color(0xFFE7EBF1);
  static const Color primary = Color(0xFF315CF6);
  static const Color danger = Color(0xFFEF4444);

  late final TextEditingController _amountController;
  late final TextEditingController _referenceController;
  late final TextEditingController _gatewayController;
  late final TextEditingController _razorpayController;
  late final TextEditingController _noteController;

  late PaymentMethodType _method;
  late DateTime _paymentDate;
  String? _error;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _amountController =
        TextEditingController(text: widget.transaction.amount.toStringAsFixed(2));
    _referenceController =
        TextEditingController(text: widget.transaction.transactionReference ?? '');
    _gatewayController =
        TextEditingController(text: widget.transaction.gatewayTransactionId ?? '');
    _razorpayController =
        TextEditingController(text: widget.transaction.razorpayPaymentId ?? '');
    _noteController = TextEditingController(text: widget.transaction.note ?? '');
    _method = widget.transaction.method;
    _paymentDate = widget.transaction.paymentDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _gatewayController.dispose();
    _razorpayController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String _methodLabel(PaymentMethodType value) {
    switch (value) {
      case PaymentMethodType.cash:
        return 'Cash';
      case PaymentMethodType.upi:
        return 'UPI';
      case PaymentMethodType.card:
        return 'Card';
      case PaymentMethodType.bankTransfer:
        return 'Bank Transfer';
      case PaymentMethodType.razorpay:
        return 'Razorpay';
      case PaymentMethodType.other:
        return 'Other';
    }
  }

  String _dateTime(DateTime value) {
    final local = value.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}  $hh:$mm';
  }

  Future<void> _pickDateTime() async {
    if (_closing || !mounted) return;

    final date = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_paymentDate),
    );
    if (time == null || !mounted) return;

    setState(() {
      _paymentDate = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _close() {
    if (_closing || !mounted) return;
    _closing = true;
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context, rootNavigator: true).pop();
  }

  void _submit() {
    if (_closing || !mounted) return;

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid amount greater than zero.');
      return;
    }

    if (_method == PaymentMethodType.razorpay &&
        _razorpayController.text.trim().isEmpty) {
      setState(() => _error = 'Razorpay payment ID is required for Razorpay.');
      return;
    }

    _closing = true;
    FocusManager.instance.primaryFocus?.unfocus();

    Navigator.of(context, rootNavigator: true).pop({
      'amount': amount,
      'method': _method,
      'reference': _referenceController.text.trim().isEmpty
          ? null
          : _referenceController.text.trim(),
      'note': _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      'razorpayPaymentId': _razorpayController.text.trim().isEmpty
          ? null
          : _razorpayController.text.trim(),
      'gatewayTransactionId': _gatewayController.text.trim().isEmpty
          ? null
          : _gatewayController.text.trim(),
      'paymentDate': _paymentDate,
    });
  }

  InputDecoration _input(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: background,
      labelStyle: const TextStyle(color: muted, fontWeight: FontWeight.w700),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final methods = <PaymentMethodType>[
      PaymentMethodType.cash,
      PaymentMethodType.upi,
      PaymentMethodType.card,
      PaymentMethodType.bankTransfer,
      PaymentMethodType.razorpay,
      PaymentMethodType.other,
    ];

    return AlertDialog(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: const [
          Icon(Icons.edit_note_rounded, color: primary),
          SizedBox(width: 11),
          Expanded(
            child: Text(
              'Edit Payment',
              style: TextStyle(
                color: heading,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Audit protected',
                style: TextStyle(
                  color: primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Admin edit information and previous values are recorded by the payment update service.',
                style: TextStyle(color: body, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: _input(
                  widget.transaction.isRefund ? 'Refund amount' : 'Payment amount',
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Payment method',
                style: TextStyle(
                  color: muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: methods.map((item) {
                  final selected = _method == item;
                  return ChoiceChip(
                    label: Text(_methodLabel(item)),
                    selected: selected,
                    onSelected: (_) => setState(() {
                      _method = item;
                      _error = null;
                    }),
                    selectedColor: primary.withOpacity(.12),
                    backgroundColor: background,
                    side: BorderSide(
                      color: selected ? primary : border,
                    ),
                    labelStyle: TextStyle(
                      color: selected ? primary : body,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _referenceController,
                decoration: _input('Transaction reference', hint: 'Optional'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _gatewayController,
                decoration: _input('Gateway transaction ID', hint: 'Optional'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _razorpayController,
                decoration: _input(
                  'Razorpay payment ID',
                  hint: _method == PaymentMethodType.razorpay
                      ? 'Required for Razorpay'
                      : 'Optional',
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickDateTime,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_rounded,
                          size: 18, color: primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Payment date & time',
                              style: TextStyle(
                                color: muted,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _dateTime(_paymentDate),
                              style: const TextStyle(
                                color: heading,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: muted),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                maxLines: 4,
                decoration: _input(
                  'Note',
                  hint: 'Payment note / correction reason',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: danger,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _closing ? null : _close,
          child: const Text(
            'Cancel',
            style: TextStyle(color: muted, fontWeight: FontWeight.w800),
          ),
        ),
        ElevatedButton.icon(
          onPressed: _closing ? null : _submit,
          icon: const Icon(Icons.save_rounded, size: 17),
          label: const Text(
            'Save Changes',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}
