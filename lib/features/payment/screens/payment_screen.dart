import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

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
  // ============================================================
  // COLORS
  // ============================================================

  static const Color primary = Color(0xFF0F766E);
  static const Color accent = Color(0xFF14B8A6);
  static const Color background = Color(0xFFF8FAF9);
  static const Color card = Colors.white;
  static const Color softAccent = Color(0xFFE6FFFB);
  static const Color heading = Color(0xFF17201F);
  static const Color body = Color(0xFF66706E);
  static const Color muted = Color(0xFF94A09D);
  static const Color border = Color(0xFFE5EBE9);

  // ============================================================
  // STATE
  // ============================================================

  bool _isProcessing = false;
  bool _isRefreshing = false;
  bool _razorpayOpened = false;

  Booking? _latestBooking;

  String? _lastCheckedText;

  String? _activeOrderId;
  String? _activePaymentAttemptId;

  double? _activePaymentAmount;

  // Selected payment amount for this checkout.
  // null = Pay Remaining.
  double? _requestedPaymentAmount;

  // Customer's preferred Razorpay payment category.
  // Razorpay still decides the methods actually available at checkout.
  String _selectedPaymentMethod = 'UPI';

  // ============================================================
  // SERVICES
  // ============================================================

  final BookingService _bookingService =
      BookingService();

  late final Razorpay _razorpay;

  final FirebaseFunctions _functions =
      FirebaseFunctions.instance;

  // ============================================================
  // TENANT
  // ============================================================

  String get _tenantId =>
      AppConfig.tenant.tenantId;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _razorpay = Razorpay();

    _razorpay.on(
      Razorpay.EVENT_PAYMENT_SUCCESS,
      _handlePaymentSuccess,
    );

    _razorpay.on(
      Razorpay.EVENT_PAYMENT_ERROR,
      _handlePaymentError,
    );

    _razorpay.on(
      Razorpay.EVENT_EXTERNAL_WALLET,
      _handleExternalWallet,
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  // ============================================================
  // ACTIVE BOOKING
  // ============================================================

  Booking get _activeBooking =>
      _latestBooking ?? widget.booking;

  // A customer-side booking is only a temporary in-memory object until
  // Razorpay payment is successfully verified. Existing bookings have a
  // Firestore bookingId and continue to use the existing payment flow.
  bool get _isNewBooking =>
      widget.booking.bookingId.trim().isEmpty;

  // ============================================================
  // OUTSTANDING
  // ============================================================

  double get _outstandingAmount {
    final booking = _activeBooking;

    final balance =
        booking.totalAmount -
        booking.paidAmount +
        booking.refundAmount;

    return balance < 0 ? 0 : balance;
  }

  // ============================================================
  // REFRESH BOOKING
  // ============================================================

  Future<void> _refreshBooking() async {
    if (_isRefreshing || _isProcessing) {
      return;
    }

    if (_isNewBooking) {
      _showMessage(
        'This booking is not created yet. It will be created after successful payment.',
      );
      return;
    }

    setState(() {
      _isRefreshing = true;
    });

    try {
      final ref = FirebaseFirestore
          .instance
          .collection('tenants')
          .doc(_tenantId)
          .collection('bookings')
          .doc(widget.booking.bookingId);

      final snapshot =
          await ref.get();

      if (!snapshot.exists ||
          snapshot.data() == null) {
        throw Exception(
          'Booking not found.',
        );
      }

      final data =
          snapshot.data()!;

      if ((data['tenantId']
                  ?.toString() ??
              '') !=
          _tenantId) {
        throw Exception(
          'Invalid tenant booking.',
        );
      }

      final latest =
          Booking.fromMap(
        snapshot.id,
        data,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _latestBooking = latest;
        _lastCheckedText =
            _formatTime(
          DateTime.now(),
        );
      });

      _showMessage(
        'Booking payment status refreshed.',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showMessage(
        _cleanError(e),
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  // ============================================================
  // START RAZORPAY PAYMENT
  // ============================================================

  Future<void> _completePayment({
    double? requestedAmount,
  }) async {
    if (_isProcessing || _isRefreshing) {
      return;
    }

    if (_razorpayOpened) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _requestedPaymentAmount = requestedAmount;
    });

    try {
      // --------------------------------------------------------
      // IMPORTANT PAYMENT-FIRST RULE
      // --------------------------------------------------------
      //
      // NEW CUSTOMER BOOKING:
      //
      //   widget.booking is only an in-memory booking snapshot.
      //   DO NOT read/create tenants/{tenantId}/bookings here.
      //
      // EXISTING BOOKING:
      //
      //   Read the latest Firestore booking and use the existing
      //   createRazorpayOrder flow.
      // --------------------------------------------------------

      late Booking paymentBooking;

      if (_isNewBooking) {
        paymentBooking = widget.booking;

        if (paymentBooking.tenantId != _tenantId) {
          throw Exception(
            'Invalid booking tenant.',
          );
        }

        if (paymentBooking.customerId.trim().isEmpty) {
          throw Exception(
            'Customer information is missing.',
          );
        }

        if (paymentBooking.totalAmount <= 0) {
          throw Exception(
            'Invalid booking amount.',
          );
        }
      } else {
        final bookingRef =
            FirebaseFirestore.instance
                .collection('tenants')
                .doc(_tenantId)
                .collection('bookings')
                .doc(widget.booking.bookingId);

        final snapshot = await bookingRef.get();

        if (!snapshot.exists || snapshot.data() == null) {
          throw Exception(
            'Booking not found.',
          );
        }

        final data = snapshot.data()!;

        if ((data['tenantId']?.toString() ?? '') != _tenantId) {
          throw Exception(
            'Invalid tenant booking.',
          );
        }

        paymentBooking = Booking.fromMap(
          snapshot.id,
          data,
        );

        if (mounted) {
          setState(() {
            _latestBooking = paymentBooking;
          });
        }

        // ------------------------------------------------------
        // BLOCK TERMINAL BOOKINGS
        // ------------------------------------------------------

        if (paymentBooking.status == BookingStatus.cancelled ||
            paymentBooking.status == BookingStatus.rejected ||
            paymentBooking.status == BookingStatus.completed ||
            paymentBooking.status == BookingStatus.noShow) {
          throw Exception(
            'This booking is no longer available for payment.',
          );
        }

        // ------------------------------------------------------
        // ALREADY PAID
        // ------------------------------------------------------

        if (paymentBooking.paymentStatus == PaymentStatus.paid ||
            paymentBooking.balanceAmount <= 0.009) {
          if (!mounted) {
            return;
          }

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => PaymentSuccessScreen(
                booking: paymentBooking,
                paymentId: paymentBooking.paymentId,
              ),
            ),
          );

          return;
        }
      }

      // --------------------------------------------------------
      // CREATE RAZORPAY ORDER
      // --------------------------------------------------------
      //
      // NEW BOOKING:
      //   createRazorpayCheckoutOrder
      //
      // EXISTING BOOKING:
      //   createRazorpayOrder
      // --------------------------------------------------------

      final callable = _functions.httpsCallable(
        _isNewBooking
            ? 'createRazorpayCheckoutOrder'
            : 'createRazorpayOrder',
      );

      final callData = <String, dynamic>{
        'tenantId': _tenantId,
      };

      if (_isNewBooking) {
        // IMPORTANT: Firebase Callable Functions only accept
        // JSON-safe values. Booking.toMap() contains Firestore
        // Timestamp values, so do NOT send the complete Booking map.
        //
        // The checkout endpoint only needs these primitive values.
        // The real booking is still created only after successful
        // Razorpay signature verification.
        callData['booking'] = <String, dynamic>{
          'tenantId': paymentBooking.tenantId,
          'customerId': paymentBooking.customerId,
          'totalAmount': paymentBooking.totalAmount,
        };
      } else {
        callData['bookingId'] = paymentBooking.bookingId;
      }

      // Omit the field for Pay Remaining / full checkout.
      // Send it only when the customer selected another amount.
      if (requestedAmount != null) {
        callData['requestedAmount'] = requestedAmount;
      }

      final result = await callable.call(callData);

      final response = Map<String, dynamic>.from(
        result.data as Map,
      );

      if (response['success'] != true) {
        throw Exception(
          'Unable to create Razorpay order.',
        );
      }

      // --------------------------------------------------------
      // RESPONSE
      // --------------------------------------------------------

      final keyId = response['keyId']?.toString().trim();

      final orderId = response['orderId']?.toString().trim();

      final currency = response['currency']
          ?.toString()
          .trim()
          .toUpperCase();

      // Existing flow returns paymentAttemptId.
      // New checkout flow returns checkoutAttemptId.
      final paymentAttemptId =
          (response['paymentAttemptId'] ??
                  response['checkoutAttemptId'])
              ?.toString()
              .trim();

      final amountPaise = _toInt(
        response['amount'],
      );

      final amountRupees = _toDouble(
        response['amountRupees'],
      );

      // --------------------------------------------------------
      // VALIDATE BACKEND RESPONSE
      // --------------------------------------------------------

      if (keyId == null || keyId.isEmpty) {
        throw Exception(
          'Razorpay Key ID was not returned by the server.',
        );
      }

      if (orderId == null || orderId.isEmpty) {
        throw Exception(
          'Razorpay order ID was not returned by the server.',
        );
      }

      if (amountPaise <= 0) {
        throw Exception(
          'Invalid Razorpay payment amount.',
        );
      }

      if (currency == null || currency.isEmpty) {
        throw Exception(
          'Payment currency was not returned by the server.',
        );
      }

      // --------------------------------------------------------
      // STORE ACTIVE PAYMENT DETAILS
      // --------------------------------------------------------

      _activeOrderId = orderId;
      _activePaymentAttemptId = paymentAttemptId;
      _activePaymentAmount = amountRupees > 0
          ? amountRupees
          : amountPaise / 100.0;

      // --------------------------------------------------------
      // OPEN RAZORPAY
      // --------------------------------------------------------

      final user = await _getCurrentUserDetails(
        paymentBooking,
      );

      final options = <String, dynamic>{
        'key': keyId,
        'amount': amountPaise,
        'currency': currency,
        'name': user['name'] ?? 'Rentocar',
        'description': _isNewBooking
            ? 'Car rental booking payment'
            : 'Car rental booking ${paymentBooking.bookingId}',
        'order_id': orderId,
        'timeout': 300,
        'prefill': {
          'name': user['name'] ?? '',
          'contact': user['contact'] ?? '',
          'email': user['email'] ?? '',
        },
        'notes': {
          'tenantId': _tenantId,
          if (!_isNewBooking)
            'bookingId': paymentBooking.bookingId,
          if (_isNewBooking)
            'flow': 'new_customer_booking',
        },
        'theme': {
          'color': '#0F766E',
        },
      };

      _razorpayOpened = true;

      _razorpay.open(options);
    } on FirebaseFunctionsException catch (e) {
      _razorpayOpened = false;

      if (!mounted) {
        return;
      }

      _showMessage(
        e.message ?? 'Unable to start payment.',
        error: true,
      );
    } catch (e) {
      _razorpayOpened = false;

      if (!mounted) {
        return;
      }

      _showMessage(
        _cleanError(e),
        error: true,
      );
    } finally {
      if (mounted && !_razorpayOpened) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  // ============================================================
  // CURRENT CUSTOMER DETAILS
  // ============================================================

  Future<Map<String, String>>
      _getCurrentUserDetails(
    Booking booking,
  ) async {
    return {
      'name':
          booking.customerName,
      'contact':
          booking.customerPhone,
      'email':
          booking.customerEmail,
    };
  }

  // ============================================================
  // RAZORPAY SUCCESS
  // ============================================================

  Future<void> _handlePaymentSuccess(
    PaymentSuccessResponse response,
  ) async {
    _razorpayOpened = false;

    final paymentId = response.paymentId?.trim();
    final orderId = response.orderId?.trim();
    final signature = response.signature?.trim();

    // ----------------------------------------------------------
    // Validate Razorpay response
    // ----------------------------------------------------------

    if (paymentId == null || paymentId.isEmpty) {
      await _paymentVerificationFailed(
        'Razorpay did not return a payment ID.',
      );
      return;
    }

    if (orderId == null || orderId.isEmpty) {
      await _paymentVerificationFailed(
        'Razorpay did not return an order ID.',
      );
      return;
    }

    if (signature == null || signature.isEmpty) {
      await _paymentVerificationFailed(
        'Razorpay did not return a payment signature.',
      );
      return;
    }

    if (_activeOrderId != null && _activeOrderId != orderId) {
      await _paymentVerificationFailed(
        'Payment order mismatch. Please try again.',
      );
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // --------------------------------------------------------
      // 1. BACKEND SIGNATURE VERIFICATION
      // --------------------------------------------------------
      //
      // NO booking is created before this succeeds.
      // --------------------------------------------------------

      final callable = _functions.httpsCallable(
        'verifyRazorpaySignature',
      );

      final result = await callable.call({
        'tenantId': _tenantId,
        'orderId': orderId,
        'paymentId': paymentId,
        'signature': signature,
      });

      final data = Map<String, dynamic>.from(
        result.data as Map,
      );

      final verified = data['verified'] == true;

      if (!verified) {
        throw Exception(
          'Payment verification failed.',
        );
      }

      // --------------------------------------------------------
      // 2. NEW BOOKING: CREATE THE REAL BOOKING NOW
      // --------------------------------------------------------
      //
      // This is the first point at which the Firestore booking is
      // created for the customer booking flow.
      //
      // BookingService creates an AUTO-GENERATED Firestore document
      // ID and writes that ID into bookingId. This matches the
      // requirement that the customer never types a booking ID.
      // --------------------------------------------------------

      late Booking latestBooking;
      late DocumentReference<Map<String, dynamic>> bookingRef;

      if (_isNewBooking) {
        final createdBooking =
            await _bookingService.createBooking(
          tenantId: _tenantId,
          booking: widget.booking,
        );

        latestBooking = createdBooking;

        bookingRef = FirebaseFirestore.instance
            .collection('tenants')
            .doc(_tenantId)
            .collection('bookings')
            .doc(createdBooking.bookingId);

        if (createdBooking.tenantId != _tenantId) {
          throw Exception(
            'Invalid tenant booking created after payment.',
          );
        }
      } else {
        // ------------------------------------------------------
        // 2B. EXISTING BOOKING: LOAD LATEST BOOKING
        // ------------------------------------------------------

        bookingRef = FirebaseFirestore.instance
            .collection('tenants')
            .doc(_tenantId)
            .collection('bookings')
            .doc(widget.booking.bookingId);

        final bookingSnapshot = await bookingRef.get();

        if (!bookingSnapshot.exists ||
            bookingSnapshot.data() == null) {
          throw Exception(
            'Booking could not be found after payment verification.',
          );
        }

        latestBooking = Booking.fromMap(
          bookingSnapshot.id,
          bookingSnapshot.data()!,
        );

        if (latestBooking.tenantId != _tenantId) {
          throw Exception(
            'Invalid tenant booking.',
          );
        }

        if (latestBooking.status == BookingStatus.cancelled ||
            latestBooking.status == BookingStatus.rejected ||
            latestBooking.status == BookingStatus.completed ||
            latestBooking.status == BookingStatus.noShow) {
          throw Exception(
            'This booking is no longer available for payment.',
          );
        }
      }

      // --------------------------------------------------------
      // 3. CALCULATE THE AMOUNT TO RECORD
      // --------------------------------------------------------

      final currentBalance = latestBooking.balanceAmount;

      if (currentBalance <= 0.009) {
        throw Exception(
          'This booking has already been fully paid.',
        );
      }

      final paymentAmount =
          _activePaymentAmount ?? currentBalance;

      // Never record more than the current balance.
      final amountToRecord = paymentAmount > currentBalance
          ? currentBalance
          : paymentAmount;

      if (amountToRecord <= 0) {
        throw Exception(
          'Invalid payment amount.',
        );
      }

      // --------------------------------------------------------
      // 4. RECORD VERIFIED RAZORPAY PAYMENT
      // --------------------------------------------------------
      //
      // BookingService also protects against duplicate Razorpay
      // payment IDs.
      // --------------------------------------------------------

      final transaction =
          await _bookingService.addVerifiedCustomerPayment(
        tenantId: _tenantId,
        bookingId: latestBooking.bookingId,
        amount: amountToRecord,
        method: PaymentMethodType.razorpay,
        transactionReference: paymentId,
        gateway: 'razorpay',
        razorpayOrderId: orderId,
        razorpayPaymentId: paymentId,
        razorpaySignature: signature,
        gatewayTransactionId: paymentId,
        gatewayStatus: 'captured',
        gatewayMethod: 'razorpay',
        note: 'Verified Razorpay customer payment.',
        paymentDate: DateTime.now(),
        currency: 'INR',
      );

      // --------------------------------------------------------
      // 5. REFRESH FINAL BOOKING
      // --------------------------------------------------------

      final refreshed = await bookingRef.get();

      final savedBooking =
          refreshed.exists && refreshed.data() != null
              ? Booking.fromMap(
                  refreshed.id,
                  refreshed.data()!,
                )
              : latestBooking;

      // --------------------------------------------------------
      // 6. CONFIRM AFTER PAYMENT LEDGER IS SAVED
      // --------------------------------------------------------

      if (savedBooking.balanceAmount <= 0.009) {
        await bookingRef.update({
          'status': BookingStatus.confirmed.name,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // --------------------------------------------------------
      // 7. FETCH FINAL BOOKING
      // --------------------------------------------------------

      final finalSnapshot = await bookingRef.get();

      final finalBooking =
          finalSnapshot.exists && finalSnapshot.data() != null
              ? Booking.fromMap(
                  finalSnapshot.id,
                  finalSnapshot.data()!,
                )
              : savedBooking;

      if (!mounted) {
        return;
      }

      setState(() {
        _latestBooking = finalBooking;
        _lastCheckedText = _formatTime(DateTime.now());
        _activeOrderId = null;
        _activePaymentAttemptId = null;
        _activePaymentAmount = null;
        _requestedPaymentAmount = null;
      });

      // --------------------------------------------------------
      // 8. SUCCESS SCREEN
      // --------------------------------------------------------

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentSuccessScreen(
            booking: finalBooking,
            paymentId:
                transaction.razorpayPaymentId ?? paymentId,
          ),
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      await _paymentVerificationFailed(
        e.message ?? 'Payment verification failed.',
      );
    } catch (e) {
      await _paymentVerificationFailed(
        _cleanError(e),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  // ============================================================
  // PAYMENT ERROR
  // ============================================================

  void _handlePaymentError(
    PaymentFailureResponse response,
  ) {
    _razorpayOpened =
        false;

    if (!mounted) {
      return;
    }

    final message =
        response.message
                ?.trim()
                .isNotEmpty ==
            true
        ? response.message!
        : 'Payment was not completed.';

    setState(() {
      _isProcessing =
          false;
    });

    _showMessage(
      message,
      error: true,
    );
  }

  // ============================================================
  // EXTERNAL WALLET
  // ============================================================

  void _handleExternalWallet(
    ExternalWalletResponse response,
  ) {
    _razorpayOpened =
        false;

    if (!mounted) {
      return;
    }

    final wallet =
        response.walletName
                ?.trim()
                .isNotEmpty ==
            true
        ? response.walletName!
        : 'External wallet';

    setState(() {
      _isProcessing =
          false;
    });

    _showMessage(
      '$wallet payment flow was selected.',
    );
  }

  // ============================================================
  // VERIFICATION FAILED
  // ============================================================

  Future<void> _paymentVerificationFailed(
    String message,
  ) async {
    _razorpayOpened =
        false;

    if (!mounted) {
      return;
    }

    setState(() {
      _isProcessing =
          false;
      _activeOrderId =
          null;
      _activePaymentAttemptId =
          null;
      _activePaymentAmount =
          null;
    });

    _showMessage(
      message,
      error: true,
    );
  }

  // ============================================================
  // SNACKBAR
  // ============================================================

  void _showMessage(
    String message, {
    bool error = false,
  }) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style:
                const TextStyle(
              fontFamily:
                  'Manrope',
              fontWeight:
                  FontWeight.w600,
            ),
          ),
          backgroundColor:
              error
                  ? const Color(
                      0xFFB42318,
                    )
                  : primary,
          behavior:
              SnackBarBehavior
                  .floating,
          margin:
              const EdgeInsets.all(
            16,
          ),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              14,
            ),
          ),
        ),
      );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _cleanError(
    Object error,
  ) {
    return error
        .toString()
        .replaceFirst(
          'Exception: ',
          '',
        )
        .trim();
  }

  double _toDouble(
    dynamic value,
  ) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ??
              '',
        ) ??
        0;
  }

  int _toInt(
    dynamic value,
  ) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ??
              '',
        ) ??
        0;
  }

  String _formatAmount(
    double amount,
  ) {
    return '₹${amount.toStringAsFixed(0)}';
  }

  String _formatTime(
    DateTime date,
  ) {
    final hour =
        date.hour % 12 == 0
            ? 12
            : date.hour % 12;

    final minute =
        date.minute
            .toString()
            .padLeft(
              2,
              '0',
            );

    final period =
        date.hour >= 12
            ? 'PM'
            : 'AM';

    return '$hour:$minute $period';
  }

  String _formatDate(
    DateTime date,
  ) {
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

    return '${date.day} '
        '${months[date.month - 1]} '
        '${date.year}';
  }

  String _depositLabel(
    String type,
  ) {
    switch (
        type.trim().toLowerCase()) {
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
      case '':
        return 'No Deposit';

      default:
        return type
            .replaceAll(
              '_',
              ' ',
            )
            .split(' ')
            .where(
              (e) =>
                  e.isNotEmpty,
            )
            .map(
              (e) =>
                  '${e[0].toUpperCase()}'
                  '${e.substring(1)}',
            )
            .join(' ');
    }
  }

  bool _isMonetaryDeposit(
    Booking booking,
  ) {
    final type =
        booking
            .securityDepositType
            .trim()
            .toLowerCase();

    return type ==
            'cash' ||
        type == 'upi' ||
        type ==
            'bank_transfer';
  }

  // ============================================================
  // SECURITY DEPOSIT
  // ============================================================

  Widget _buildSecurityDeposit(
    Booking booking,
  ) {
    final type =
        booking
            .securityDepositType
            .trim()
            .toLowerCase();

    final amount =
        booking.securityDeposit;

    final details =
        booking
            .securityDepositDetails
            .trim();

    final hasDeposit =
        type.isNotEmpty &&
        type != 'none';

    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(
        18,
      ),
      decoration:
          BoxDecoration(
        color: card,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        border:
            Border.all(
          color: border,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Security deposit',
            style:
                TextStyle(
              fontFamily:
                  'Manrope',
              fontSize: 16,
              fontWeight:
                  FontWeight.w800,
              color:
                  heading,
            ),
          ),
          const SizedBox(
            height: 5,
          ),
          Text(
            hasDeposit
                ? 'Deposit is kept separate from the rental charges.'
                : 'No security deposit selected.',
            style:
                const TextStyle(
              fontFamily:
                  'Manrope',
              fontSize: 11,
              color:
                  body,
              fontWeight:
                  FontWeight.w500,
            ),
          ),
          const SizedBox(
            height: 14,
          ),
          _depositRow(
            'Deposit type',
            _depositLabel(type),
          ),
          if (hasDeposit &&
              _isMonetaryDeposit(
                booking,
              )) ...[
            const SizedBox(
              height: 10,
            ),
            _depositRow(
              'Deposit amount',
              _formatAmount(
                amount,
              ),
            ),
          ],
          if (hasDeposit &&
              details.isNotEmpty) ...[
            const SizedBox(
              height: 10,
            ),
            _depositRow(
              'Deposit details',
              details,
            ),
          ],
        ],
      ),
    );
  }

  Widget _depositRow(
    String label,
    String value,
  ) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style:
                const TextStyle(
              fontFamily:
                  'Manrope',
              fontSize: 12,
              color:
                  body,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(
          width: 14,
        ),
        Flexible(
          child: Text(
            value,
            textAlign:
                TextAlign.right,
            style:
                const TextStyle(
              fontFamily:
                  'Manrope',
              fontSize: 13,
              color:
                  heading,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final booking =
        _activeBooking;

    final total =
        booking.totalAmount;

    final outstanding =
        _outstandingAmount;

    return Scaffold(
      backgroundColor:
          background,
      appBar: AppBar(
        backgroundColor:
            background,
        elevation: 0,
        centerTitle: false,
        title:
            const Text(
          'Payment',
          style:
              TextStyle(
            fontFamily:
                'Manrope',
            fontSize: 22,
            fontWeight:
                FontWeight.w800,
            color:
                heading,
          ),
        ),
        iconTheme:
            const IconThemeData(
          color: heading,
        ),
        actions: [
          IconButton(
            tooltip:
                'Refresh payment status',
            onPressed:
                _isProcessing ||
                        _isRefreshing
                    ? null
                    : _refreshBooking,
            icon:
                _isRefreshing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child:
                            CircularProgressIndicator(
                          strokeWidth:
                              2,
                          color:
                              primary,
                        ),
                      )
                    : const Icon(
                        Icons
                            .refresh_rounded,
                      ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child:
                  SingleChildScrollView(
                padding:
                    const EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  24,
                ),
                child:
                    Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    _buildBookingSummary(
                      booking,
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                    _buildAmountCard(
                      total,
                      outstanding,
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                    _buildSecurityDeposit(
                      booking,
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                    _buildPaymentStatus(
                      booking,
                      outstanding,
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                    if (outstanding > 0.009)
                      _buildPaymentOptions(
                        outstanding,
                      ),
                    if (outstanding > 0.009)
                      const SizedBox(
                        height: 20,
                      ),
                    _buildPaymentMethod(),
                    const SizedBox(
                      height: 20,
                    ),
                    _buildSecureInfo(),
                  ],
                ),
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BOOKING SUMMARY
  // ============================================================

  Widget _buildBookingSummary(
    Booking booking,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(
        18,
      ),
      decoration:
          BoxDecoration(
        color: card,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        border:
            Border.all(
          color: border,
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(
              0.035,
            ),
            blurRadius: 18,
            offset:
                const Offset(
              0,
              7,
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration:
                    BoxDecoration(
                  color:
                      softAccent,
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),
                child:
                    const Icon(
                  Icons
                      .directions_car_rounded,
                  color:
                      primary,
                  size: 25,
                ),
              ),
              const SizedBox(
                width: 13,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.car
                              ?.name ??
                          'Car Rental',
                      style:
                          const TextStyle(
                        fontFamily:
                            'Manrope',
                        fontSize: 16,
                        fontWeight:
                            FontWeight.w800,
                        color:
                            heading,
                      ),
                    ),
                    const SizedBox(
                      height: 3,
                    ),
                    Text(
                      'Booking #${booking.bookingId}',
                      style:
                          const TextStyle(
                        fontFamily:
                            'Manrope',
                        fontSize: 12,
                        color:
                            muted,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 18,
          ),
          const Divider(
            height: 1,
            color: border,
          ),
          const SizedBox(
            height: 16,
          ),
          _infoRow(
            Icons
                .calendar_today_outlined,
            'Pickup',
            _formatDate(
              booking
                  .pickupDateTime,
            ),
          ),
          const SizedBox(
            height: 12,
          ),
          _infoRow(
            Icons
                .event_available_outlined,
            'Return',
            _formatDate(
              booking
                  .returnDateTime,
            ),
          ),
          const SizedBox(
            height: 12,
          ),
          _infoRow(
            Icons
                .location_on_outlined,
            'Pickup branch',
            booking.pickupBranch
                    ?.name ??
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
        const SizedBox(
          width: 10,
        ),
        Text(
          title,
          style:
              const TextStyle(
            fontFamily:
                'Manrope',
            fontSize: 13,
            color:
                body,
            fontWeight:
                FontWeight.w600,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign:
                TextAlign.right,
            style:
                const TextStyle(
              fontFamily:
                  'Manrope',
              fontSize: 13,
              color:
                  heading,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // AMOUNT CARD
  // ============================================================

  Widget _buildAmountCard(
    double total,
    double outstanding,
  ) {
    final booking =
        _activeBooking;

    final isPaid =
        outstanding <=
                0.009 ||
            booking.paymentStatus ==
                PaymentStatus.paid;

    return Container(
      padding:
          const EdgeInsets.all(
        20,
      ),
      decoration:
          BoxDecoration(
        color: primary,
        borderRadius:
            BorderRadius.circular(
          22,
        ),
        boxShadow: [
          BoxShadow(
            color:
                primary.withOpacity(
              0.18,
            ),
            blurRadius: 20,
            offset:
                const Offset(
              0,
              10,
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'TOTAL PAYABLE',
            style:
                TextStyle(
              fontFamily:
                  'Manrope',
              fontSize: 11,
              letterSpacing:
                  1.1,
              color:
                  Colors.white70,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
          const SizedBox(
            height: 7,
          ),
          Text(
            _formatAmount(
              isPaid
                  ? booking
                      .totalAmount
                  : outstanding,
            ),
            style:
                const TextStyle(
              fontFamily:
                  'Manrope',
              fontSize: 32,
              color:
                  Colors.white,
              fontWeight:
                  FontWeight.w900,
            ),
          ),
          const SizedBox(
            height: 5,
          ),
          const Text(
            'Final amount payable for this booking',
            style:
                TextStyle(
              fontFamily:
                  'Manrope',
              fontSize: 12,
              color:
                  Colors.white70,
              fontWeight:
                  FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PAYMENT STATUS
  // ============================================================

  Widget _buildPaymentStatus(
    Booking booking,
    double outstanding,
  ) {
    final paid =
        booking.paidAmount;

    final isPaid =
        outstanding <=
                0.009 ||
            booking.paymentStatus ==
                PaymentStatus.paid;

    return Container(
      padding:
          const EdgeInsets.all(
        17,
      ),
      decoration:
          BoxDecoration(
        color: card,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        border:
            Border.all(
          color: border,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration:
                    BoxDecoration(
                  color:
                      softAccent,
                  borderRadius:
                      BorderRadius.circular(
                    13,
                  ),
                ),
                child: Icon(
                  isPaid
                      ? Icons
                          .verified_rounded
                      : Icons
                          .account_balance_wallet_outlined,
                  color:
                      primary,
                  size: 21,
                ),
              ),
              const SizedBox(
                width: 11,
              ),
              Expanded(
                child:
                    Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPaid
                          ? 'Payment completed'
                          : 'Payment status',
                      style:
                          const TextStyle(
                        fontFamily:
                            'Manrope',
                        fontSize: 14,
                        fontWeight:
                            FontWeight.w800,
                        color:
                            heading,
                      ),
                    ),
                    const SizedBox(
                      height: 3,
                    ),
                    Text(
                      isPaid
                          ? 'This booking has no outstanding balance.'
                          : '${_formatAmount(outstanding)} remaining',
                      style:
                          const TextStyle(
                        fontFamily:
                            'Manrope',
                        fontSize: 11,
                        fontWeight:
                            FontWeight.w600,
                        color:
                            body,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip:
                    'Refresh payment status',
                onPressed:
                    _isProcessing ||
                            _isRefreshing
                        ? null
                        : _refreshBooking,
                icon:
                    _isRefreshing
                        ? const SizedBox(
                            width: 19,
                            height: 19,
                            child:
                                CircularProgressIndicator(
                              strokeWidth:
                                  2,
                              color:
                                  primary,
                            ),
                          )
                        : const Icon(
                            Icons
                                .refresh_rounded,
                            color:
                                primary,
                          ),
              ),
            ],
          ),
          const SizedBox(
            height: 13,
          ),
          const Divider(
            height: 1,
            color: border,
          ),
          const SizedBox(
            height: 12,
          ),
          Row(
            children: [
              Expanded(
                child:
                    _paymentMetric(
                  'Paid',
                  _formatAmount(
                    paid,
                  ),
                ),
              ),
              const SizedBox(
                width: 10,
              ),
              Expanded(
                child:
                    _paymentMetric(
                  'Balance',
                  _formatAmount(
                    outstanding,
                  ),
                ),
              ),
            ],
          ),
          if (_lastCheckedText !=
              null) ...[
            const SizedBox(
              height: 9,
            ),
            Align(
              alignment:
                  Alignment.centerLeft,
              child: Text(
                'Last checked $_lastCheckedText',
                style:
                    const TextStyle(
                  fontFamily:
                      'Manrope',
                  fontSize: 10,
                  fontWeight:
                      FontWeight.w600,
                  color:
                      muted,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _paymentMetric(
    String label,
    String value,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(
        11,
      ),
      decoration:
          BoxDecoration(
        color: background,
        borderRadius:
            BorderRadius.circular(
          12,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style:
                const TextStyle(
              fontFamily:
                  'Manrope',
              fontSize: 10,
              color:
                  muted,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
          const SizedBox(
            height: 3,
          ),
          Text(
            value,
            style:
                const TextStyle(
              fontFamily:
                  'Manrope',
              fontSize: 13,
              color:
                  heading,
              fontWeight:
                  FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }


  // ============================================================
  // PAYMENT AMOUNT OPTIONS
  // ============================================================

  Widget _buildPaymentOptions(
    double outstanding,
  ) {
    final selected =
        _requestedPaymentAmount;

    final isRemainingSelected =
        selected == null;

    final isCustomSelected =
        selected != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: card,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: border,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose payment amount',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: heading,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'You can pay the full remaining balance or any smaller amount.',
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 11,
              height: 1.4,
              color: body,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),

          _paymentAmountChoice(
            icon:
                Icons.account_balance_wallet_rounded,
            title: 'Pay remaining',
            subtitle:
                'Pay the complete outstanding balance',
            amount:
                _formatAmount(outstanding),
            selected:
                isRemainingSelected,
            onTap: () {
              if (!mounted) return;

              setState(() {
                _requestedPaymentAmount =
                    null;
              });
            },
          ),

          const SizedBox(height: 10),

          _paymentAmountChoice(
            icon:
                Icons.edit_rounded,
            title: 'Pay other amount',
            subtitle:
                'Choose an amount up to the balance',
            amount:
                isCustomSelected
                    ? _formatAmount(selected)
                    : 'Choose',
            selected:
                isCustomSelected,
            onTap:
                _showCustomAmountDialog,
          ),
        ],
      ),
    );
  }

  Widget _paymentAmountChoice({
    required IconData icon,
    required String title,
    required String subtitle,
    required String amount,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap:
          _isProcessing
              ? null
              : onTap,
      borderRadius:
          BorderRadius.circular(16),
      child: AnimatedContainer(
        duration:
            const Duration(
          milliseconds: 180,
        ),
        padding:
            const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:
              selected
                  ? softAccent
                  : background,
          borderRadius:
              BorderRadius.circular(16),
          border: Border.all(
            color:
                selected
                    ? accent
                    : border,
            width:
                selected ? 1.3 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration:
                  BoxDecoration(
                color:
                    selected
                        ? primary
                        : Colors.white,
                borderRadius:
                    BorderRadius.circular(13),
              ),
              child: Icon(
                icon,
                size: 20,
                color:
                    selected
                        ? Colors.white
                        : primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style:
                        const TextStyle(
                      fontFamily:
                          'Manrope',
                      fontSize: 13,
                      fontWeight:
                          FontWeight.w800,
                      color:
                          heading,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style:
                        const TextStyle(
                      fontFamily:
                          'Manrope',
                      fontSize: 10,
                      color:
                          body,
                      fontWeight:
                          FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment:
                  CrossAxisAlignment.end,
              children: [
                Text(
                  amount,
                  style:
                      const TextStyle(
                    fontFamily:
                        'Manrope',
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w900,
                    color:
                        heading,
                  ),
                ),
                const SizedBox(height: 5),
                Icon(
                  selected
                      ? Icons
                          .radio_button_checked_rounded
                      : Icons
                          .radio_button_off_rounded,
                  size: 19,
                  color:
                      selected
                          ? primary
                          : muted,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PAYMENT AMOUNT SHEET
  // ============================================================

  Future<void> _showPaymentAmountSheet() async {
    if (_isProcessing ||
        _isRefreshing) {
      return;
    }

    final booking =
        _activeBooking;

    final outstanding =
        _outstandingAmount;

    if (outstanding <= 0.009) {
      _showMessage(
        'There is no outstanding amount.',
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor:
          Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            padding:
                const EdgeInsets.fromLTRB(
              20,
              10,
              20,
              20,
            ),
            decoration:
                const BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration:
                        BoxDecoration(
                      color:
                          border,
                      borderRadius:
                          BorderRadius.circular(
                        10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Make a payment',
                  style: TextStyle(
                    fontFamily:
                        'Manrope',
                    fontSize: 20,
                    fontWeight:
                        FontWeight.w900,
                    color:
                        heading,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Booking #${booking.bookingId}',
                  style: const TextStyle(
                    fontFamily:
                        'Manrope',
                    fontSize: 11,
                    color:
                        muted,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),

                Container(
                  width:
                      double.infinity,
                  padding:
                      const EdgeInsets.all(16),
                  decoration:
                      BoxDecoration(
                    color:
                        softAccent,
                    borderRadius:
                        BorderRadius.circular(
                      16,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons
                            .account_balance_wallet_rounded,
                        color:
                            primary,
                      ),
                      const SizedBox(width: 11),
                      const Expanded(
                        child: Text(
                          'Outstanding balance',
                          style:
                              TextStyle(
                            fontFamily:
                                'Manrope',
                            fontSize:
                                12,
                            fontWeight:
                                FontWeight.w700,
                            color:
                                body,
                          ),
                        ),
                      ),
                      Text(
                        _formatAmount(
                          outstanding,
                        ),
                        style:
                            const TextStyle(
                          fontFamily:
                              'Manrope',
                          fontSize:
                              17,
                          fontWeight:
                              FontWeight.w900,
                          color:
                              heading,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                _sheetAction(
                  icon:
                      Icons
                          .check_circle_outline_rounded,
                  title:
                      'Pay remaining',
                  subtitle:
                      'Pay ${_formatAmount(outstanding)} now',
                  onTap: () {
                    Navigator.pop(
                      sheetContext,
                    );
                    _completePayment();
                  },
                ),

                const SizedBox(height: 10),

                _sheetAction(
                  icon:
                      Icons
                          .edit_outlined,
                  title:
                      'Pay other amount',
                  subtitle:
                      'Enter any amount up to ${_formatAmount(outstanding)}',
                  onTap: () {
                    Navigator.pop(
                      sheetContext,
                    );
                    _showCustomAmountDialog();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sheetAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius:
          BorderRadius.circular(16),
      child: Container(
        width:
            double.infinity,
        padding:
            const EdgeInsets.all(15),
        decoration:
            BoxDecoration(
          color:
              background,
          borderRadius:
              BorderRadius.circular(16),
          border:
              Border.all(
            color:
                border,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration:
                  BoxDecoration(
                color:
                    softAccent,
                borderRadius:
                    BorderRadius.circular(13),
              ),
              child: Icon(
                icon,
                color:
                    primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style:
                        const TextStyle(
                      fontFamily:
                          'Manrope',
                      fontSize: 13,
                      fontWeight:
                          FontWeight.w800,
                      color:
                          heading,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style:
                        const TextStyle(
                      fontFamily:
                          'Manrope',
                      fontSize: 10,
                      color:
                          body,
                      fontWeight:
                          FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons
                  .arrow_forward_ios_rounded,
              size: 15,
              color:
                  muted,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CUSTOM PAYMENT AMOUNT DIALOG
  // ============================================================

  Future<void> _showCustomAmountDialog() async {
    if (_isProcessing ||
        _isRefreshing) {
      return;
    }

    final outstanding =
        _outstandingAmount;

    if (outstanding <= 0.009) {
      _showMessage(
        'There is no outstanding amount.',
      );
      return;
    }

    final controller =
        TextEditingController(
      text:
          _requestedPaymentAmount !=
                  null
              ? _requestedPaymentAmount!
                  .toStringAsFixed(0)
              : '',
    );

    final formKey =
        GlobalKey<FormState>();

    final result =
        await showDialog<double>(
      context: context,
      barrierDismissible:
          false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor:
              Colors.white,
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              24,
            ),
          ),
          title:
              const Text(
            'Pay other amount',
            style:
                TextStyle(
              fontFamily:
                  'Manrope',
              fontSize: 19,
              fontWeight:
                  FontWeight.w900,
              color:
                  heading,
            ),
          ),
          content:
              Form(
            key:
                formKey,
            child:
                Column(
              mainAxisSize:
                  MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Enter an amount between ₹1 and ${_formatAmount(outstanding)}.',
                  style:
                      const TextStyle(
                    fontFamily:
                        'Manrope',
                    fontSize: 11,
                    height: 1.4,
                    color:
                        body,
                    fontWeight:
                        FontWeight.w500,
                  ),
                ),
                const SizedBox(
                  height: 16,
                ),
                TextFormField(
                  controller:
                      controller,
                  autofocus:
                      true,
                  keyboardType:
                      const TextInputType
                          .numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction:
                      TextInputAction.done,
                  style:
                      const TextStyle(
                    fontFamily:
                        'Manrope',
                    fontSize: 20,
                    fontWeight:
                        FontWeight.w800,
                    color:
                        heading,
                  ),
                  decoration:
                      InputDecoration(
                    prefixText:
                        '₹ ',
                    prefixStyle:
                        const TextStyle(
                      fontFamily:
                          'Manrope',
                      fontSize: 20,
                      fontWeight:
                          FontWeight.w800,
                      color:
                          heading,
                    ),
                    hintText:
                        '0',
                    filled:
                        true,
                    fillColor:
                        background,
                    border:
                        OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(
                        15,
                      ),
                      borderSide:
                          const BorderSide(
                        color:
                            border,
                      ),
                    ),
                    enabledBorder:
                        OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(
                        15,
                      ),
                      borderSide:
                          const BorderSide(
                        color:
                            border,
                      ),
                    ),
                    focusedBorder:
                        OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(
                        15,
                      ),
                      borderSide:
                          const BorderSide(
                        color:
                            primary,
                        width:
                            1.4,
                      ),
                    ),
                  ),
                  validator:
                      (value) {
                    final amount =
                        double.tryParse(
                      (value ?? '')
                          .trim(),
                    );

                    if (amount ==
                            null ||
                        !amount
                            .isFinite) {
                      return 'Enter a valid amount.';
                    }

                    if (amount <= 0) {
                      return 'Amount must be greater than ₹0.';
                    }

                    if (amount >
                        outstanding +
                            0.01) {
                      return 'Amount cannot exceed ${_formatAmount(outstanding)}.';
                    }

                    return null;
                  },
                  onFieldSubmitted:
                      (_) {
                    if (formKey
                        .currentState!
                        .validate()) {
                      final amount =
                          double.parse(
                        controller
                            .text
                            .trim(),
                      );

                      Navigator.pop(
                        dialogContext,
                        double.parse(
                          amount
                              .toStringAsFixed(
                            2,
                          ),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          actionsPadding:
              const EdgeInsets.fromLTRB(
            20,
            0,
            20,
            18,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child:
                  const Text(
                'Cancel',
                style:
                    TextStyle(
                  fontFamily:
                      'Manrope',
                  fontWeight:
                      FontWeight.w700,
                  color:
                      body,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (!formKey
                    .currentState!
                    .validate()) {
                  return;
                }

                final amount =
                    double.parse(
                  controller
                      .text
                      .trim(),
                );

                Navigator.pop(
                  dialogContext,
                  double.parse(
                    amount
                        .toStringAsFixed(
                      2,
                    ),
                  ),
                );
              },
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    primary,
                foregroundColor:
                    Colors.white,
                elevation:
                    0,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    13,
                  ),
                ),
              ),
              child:
                  const Text(
                'Continue',
                style:
                    TextStyle(
                  fontFamily:
                      'Manrope',
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (!mounted ||
        result == null) {
      return;
    }

    if (result <= 0 ||
        result >
            _outstandingAmount +
                0.01) {
      _showMessage(
        'Please enter a valid amount.',
        error: true,
      );
      return;
    }

    setState(() {
      _requestedPaymentAmount =
          result;
    });

    await _showPaymentConfirmation(
      result,
    );
  }

  // ============================================================
  // PAYMENT CONFIRMATION
  // ============================================================

  Future<void> _showPaymentConfirmation(
    double amount,
  ) async {
    final outstanding =
        _outstandingAmount;

    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor:
              Colors.white,
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              24,
            ),
          ),
          title:
              const Text(
            'Confirm payment',
            style:
                TextStyle(
              fontFamily:
                  'Manrope',
              fontSize: 19,
              fontWeight:
                  FontWeight.w900,
              color:
                  heading,
            ),
          ),
          content:
              Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              _confirmRow(
                'Payment now',
                _formatAmount(amount),
              ),
              const SizedBox(
                height: 10,
              ),
              _confirmRow(
                'Balance after payment',
                _formatAmount(
                  (outstanding -
                          amount)
                      .clamp(
                    0,
                    double.infinity,
                  ),
                ),
              ),
              const SizedBox(
                height: 16,
              ),
              const Text(
                'The final amount is validated again by the backend before the Razorpay order is created.',
                style:
                    TextStyle(
                  fontFamily:
                      'Manrope',
                  fontSize: 10,
                  height: 1.4,
                  color:
                      body,
                  fontWeight:
                      FontWeight.w500,
                ),
              ),
            ],
          ),
          actionsPadding:
              const EdgeInsets.fromLTRB(
            20,
            0,
            20,
            18,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child:
                  const Text(
                'Cancel',
                style:
                    TextStyle(
                  fontFamily:
                      'Manrope',
                  fontWeight:
                      FontWeight.w700,
                  color:
                      body,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    primary,
                foregroundColor:
                    Colors.white,
                elevation:
                    0,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    13,
                  ),
                ),
              ),
              child:
                  const Text(
                'Pay with Razorpay',
                style:
                    TextStyle(
                  fontFamily:
                      'Manrope',
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true ||
        !mounted) {
      return;
    }

    await _completePayment(
      requestedAmount:
          amount,
    );
  }

  Widget _confirmRow(
    String label,
    String value,
  ) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style:
                const TextStyle(
              fontFamily:
                  'Manrope',
              fontSize: 11,
              color:
                  body,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style:
              const TextStyle(
            fontFamily:
                'Manrope',
            fontSize: 14,
            color:
                heading,
            fontWeight:
                FontWeight.w900,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // PAYMENT METHOD
  // ============================================================

  Widget _buildPaymentMethod() {
    const methods = <Map<String, dynamic>>[
      {
        'title': 'UPI',
        'subtitle': 'Google Pay, PhonePe, Paytm & other UPI apps',
        'icon': Icons.account_balance_wallet_rounded,
      },
      {
        'title': 'Scan QR',
        'subtitle': 'Use a UPI QR option when provided by checkout',
        'icon': Icons.qr_code_scanner_rounded,
      },
      {
        'title': 'Cards',
        'subtitle': 'Credit, debit and supported RuPay cards',
        'icon': Icons.credit_card_rounded,
      },
      {
        'title': 'Net Banking',
        'subtitle': 'Pay through your supported bank',
        'icon': Icons.account_balance_rounded,
      },
      {
        'title': 'Wallets',
        'subtitle': 'Supported wallets available in Razorpay',
        'icon': Icons.wallet_rounded,
      },
      {
        'title': 'EMI / Pay Later',
        'subtitle': 'Only when enabled and eligible at checkout',
        'icon': Icons.payments_outlined,
      },
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose payment method',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: heading,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Select your preferred method. Razorpay will show the methods currently available for this transaction.',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 10.5,
              height: 1.4,
              color: body,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          ...methods.map((method) {
            final title = method['title'] as String;
            final selected = _selectedPaymentMethod == title;
            final icon = method['icon'] as IconData;
            final subtitle = method['subtitle'] as String;

            return Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: InkWell(
                borderRadius: BorderRadius.circular(15),
                onTap: _isProcessing
                    ? null
                    : () {
                        setState(() {
                          _selectedPaymentMethod = title;
                        });
                      },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: selected ? softAccent : background,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: selected ? accent : border,
                      width: selected ? 1.3 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: selected ? primary : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          icon,
                          size: 19,
                          color: selected ? Colors.white : primary,
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: heading,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 9.5,
                                height: 1.3,
                                color: body,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        selected
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        size: 20,
                        color: selected ? primary : muted,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSecurePaymentNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: softAccent,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              color: primary,
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Secure Razorpay checkout',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    color: heading,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Your payment is verified on the server before the booking balance is updated. Your Razorpay secret key is never stored in the app.',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 9.5,
                    height: 1.4,
                    color: body,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SECURE INFO
  // ============================================================

  Widget _buildSecureInfo() {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons
              .verified_user_outlined,
          size: 20,
          color: primary,
        ),
        const SizedBox(
          width: 10,
        ),
        Expanded(
          child: Text(
            'Your payment is securely verified by the server before it is added to the booking payment ledger. Your Razorpay secret credentials never leave the backend.',
            style:
                const TextStyle(
              fontFamily:
                  'Manrope',
              fontSize: 12,
              height: 1.45,
              color:
                  body,
              fontWeight:
                  FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // BOTTOM BAR
  // ============================================================

  Widget _buildBottomBar() {
    final booking =
        _activeBooking;

    final outstanding =
        _outstandingAmount;

    final isPaid =
        outstanding <=
                0.009 ||
            booking.paymentStatus ==
                PaymentStatus.paid;

    return Container(
      padding:
          const EdgeInsets.fromLTRB(
        20,
        14,
        20,
        18,
      ),
      decoration:
          BoxDecoration(
        color: card,
        border:
            const Border(
          top: BorderSide(
            color: border,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(
              0.04,
            ),
            blurRadius: 15,
            offset:
                const Offset(
              0,
              -5,
            ),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Text(
                  isPaid
                      ? 'Paid'
                      : 'Balance',
                  style:
                      const TextStyle(
                    fontFamily:
                        'Manrope',
                    fontSize: 11,
                    color:
                        muted,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
                const SizedBox(
                  height: 2,
                ),
                Text(
                  _formatAmount(
                    isPaid
                        ? booking
                            .totalAmount
                        : outstanding,
                  ),
                  style:
                      const TextStyle(
                    fontFamily:
                        'Manrope',
                    fontSize: 18,
                    color:
                        heading,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(
            width: 14,
          ),
          Expanded(
            child: SizedBox(
              height: 54,
              child:
                  ElevatedButton(
                onPressed:
                    (_isProcessing ||
                            _isRefreshing ||
                            isPaid)
                        ? null
                        : _showPaymentAmountSheet,
                style:
                    ElevatedButton.styleFrom(
                  backgroundColor:
                      primary,
                  foregroundColor:
                      Colors.white,
                  disabledBackgroundColor:
                      primary.withOpacity(
                    0.55,
                  ),
                  elevation: 0,
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                      16,
                    ),
                  ),
                ),
                child:
                    _isProcessing
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child:
                                CircularProgressIndicator(
                              strokeWidth:
                                  2.5,
                              valueColor:
                                  AlwaysStoppedAnimation<
                                      Color>(
                                Colors
                                    .white,
                              ),
                            ),
                          )
                        : Text(
                            isPaid
                                ? 'Payment Completed'
                                : 'Choose Payment Amount',
                            style:
                                const TextStyle(
                              fontFamily:
                                  'Manrope',
                              fontSize: 14,
                              fontWeight:
                                  FontWeight.w800,
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

// ============================================================================
// PAYMENT SUCCESS SCREEN
// ============================================================================

class PaymentSuccessScreen
    extends StatelessWidget {
  final Booking booking;
  final String? paymentId;

  const PaymentSuccessScreen({
    super.key,
    required this.booking,
    this.paymentId,
  });

  static const Color primary =
      Color(0xFF0F766E);

  static const Color background =
      Color(0xFFF8FAF9);

  static const Color heading =
      Color(0xFF17201F);

  static const Color body =
      Color(0xFF66706E);

  static const Color softAccent =
      Color(0xFFE6FFFB);

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          background,
      body: SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.all(
            24,
          ),
          child: Column(
            children: [
              const Spacer(),

              Container(
                width: 88,
                height: 88,
                decoration:
                    const BoxDecoration(
                  color:
                      softAccent,
                  shape:
                      BoxShape.circle,
                ),
                child:
                    const Icon(
                  Icons
                      .check_rounded,
                  color:
                      primary,
                  size: 52,
                ),
              ),

              const SizedBox(
                height: 26,
              ),

              const Text(
                'Payment Successful',
                textAlign:
                    TextAlign.center,
                style:
                    TextStyle(
                  fontFamily:
                      'Manrope',
                  fontSize: 27,
                  fontWeight:
                      FontWeight.w900,
                  color:
                      heading,
                ),
              ),

              const SizedBox(
                height: 10,
              ),

              Text(
                booking.balanceAmount <= 0.009
                    ? 'Your payment has been verified and your booking is confirmed.'
                    : 'Your payment has been verified and your remaining balance has been updated.',
                textAlign:
                    TextAlign.center,
                style:
                    TextStyle(
                  fontFamily:
                      'Manrope',
                  fontSize: 14,
                  height: 1.5,
                  color:
                      body,
                  fontWeight:
                      FontWeight.w500,
                ),
              ),

              const SizedBox(
                height: 28,
              ),

              _detailCard(),

              const Spacer(),

              SizedBox(
                width:
                    double.infinity,
                height: 54,
                child:
                    ElevatedButton(
                  onPressed: () {
                    Navigator.of(
                      context,
                    ).popUntil(
                      (route) =>
                          route.isFirst,
                    );
                  },
                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        primary,
                    foregroundColor:
                        Colors.white,
                    elevation:
                        0,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        16,
                      ),
                    ),
                  ),
                  child:
                      const Text(
                    'Back to Home',
                    style:
                        TextStyle(
                      fontFamily:
                          'Manrope',
                      fontSize: 14,
                      fontWeight:
                          FontWeight.w800,
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
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(
        18,
      ),
      decoration:
          BoxDecoration(
        color:
            Colors.white,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        border:
            Border.all(
          color:
              const Color(
            0xFFE5EBE9,
          ),
        ),
      ),
      child: Column(
        children: [
          _row(
            'Booking ID',
            booking.bookingId,
          ),

          if (paymentId !=
              null) ...[
            const SizedBox(
              height: 12,
            ),
            _row(
              'Payment ID',
              paymentId!,
            ),
          ],

          const SizedBox(
            height: 12,
          ),

          _row(
            'Status',
            booking.balanceAmount <= 0.009
                ? 'Confirmed'
                : 'Partially Paid',
          ),

          const SizedBox(
            height: 12,
          ),

          _row(
            'Paid',
            '₹${booking.paidAmount.toStringAsFixed(0)}',
          ),

          if (booking.balanceAmount > 0.009) ...[
            const SizedBox(
              height: 12,
            ),
            _row(
              'Remaining',
              '₹${booking.balanceAmount.toStringAsFixed(0)}',
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(
    String label,
    String value,
  ) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style:
              const TextStyle(
            fontFamily:
                'Manrope',
            fontSize: 12,
            color:
                body,
            fontWeight:
                FontWeight.w600,
          ),
        ),
        const Spacer(),
        const SizedBox(
          width: 15,
        ),
        Flexible(
          child: Text(
            value,
            textAlign:
                TextAlign.right,
            style:
                const TextStyle(
              fontFamily:
                  'Manrope',
              fontSize: 12,
              color:
                  heading,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
