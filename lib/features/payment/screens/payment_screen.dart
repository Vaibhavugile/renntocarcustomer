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

  Future<void> _completePayment() async {
    if (_isProcessing ||
        _isRefreshing) {
      return;
    }

    if (_razorpayOpened) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // --------------------------------------------------------
      // ALWAYS FETCH THE LATEST BOOKING
      // --------------------------------------------------------

      final bookingRef =
          FirebaseFirestore
              .instance
              .collection('tenants')
              .doc(_tenantId)
              .collection('bookings')
              .doc(
                widget.booking.bookingId,
              );

      final snapshot =
          await bookingRef.get();

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

      final latestBooking =
          Booking.fromMap(
        snapshot.id,
        data,
      );

      if (mounted) {
        setState(() {
          _latestBooking =
              latestBooking;
        });
      }

      // --------------------------------------------------------
      // BLOCK TERMINAL BOOKINGS
      // --------------------------------------------------------

      if (latestBooking.status ==
              BookingStatus.cancelled ||
          latestBooking.status ==
              BookingStatus.rejected ||
          latestBooking.status ==
              BookingStatus.completed ||
          latestBooking.status ==
              BookingStatus.noShow) {
        throw Exception(
          'This booking is no longer available for payment.',
        );
      }

      // --------------------------------------------------------
      // ALREADY PAID
      // --------------------------------------------------------

      if (latestBooking.paymentStatus ==
              PaymentStatus.paid ||
          latestBooking.balanceAmount <=
              0.009) {
        if (!mounted) {
          return;
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                PaymentSuccessScreen(
              booking:
                  latestBooking,
              paymentId:
                  latestBooking.paymentId,
            ),
          ),
        );

        return;
      }

      // --------------------------------------------------------
      // CALL BACKEND
      //
      // IMPORTANT:
      // We do NOT send amount.
      //
      // Backend calculates amount directly from Firestore.
      // --------------------------------------------------------

      final callable =
          _functions.httpsCallable(
        'createRazorpayOrder',
      );

      final result =
          await callable.call({
        'tenantId':
            _tenantId,
        'bookingId':
            latestBooking.bookingId,
      });

      final response =
          Map<String, dynamic>.from(
        result.data as Map,
      );

      if (response['success'] !=
          true) {
        throw Exception(
          'Unable to create Razorpay order.',
        );
      }

      // --------------------------------------------------------
      // RESPONSE
      // --------------------------------------------------------

      final keyId =
          response['keyId']
              ?.toString()
              .trim();

      final orderId =
          response['orderId']
              ?.toString()
              .trim();

      final currency =
          response['currency']
              ?.toString()
              .trim()
              .toUpperCase();

      final paymentAttemptId =
          response[
                'paymentAttemptId'
              ]
              ?.toString()
              .trim();

      final amountPaise =
          _toInt(
        response['amount'],
      );

      final amountRupees =
          _toDouble(
        response['amountRupees'],
      );

      // --------------------------------------------------------
      // VALIDATE BACKEND RESPONSE
      // --------------------------------------------------------

      if (keyId == null ||
          keyId.isEmpty) {
        throw Exception(
          'Razorpay Key ID was not returned by the server.',
        );
      }

      if (orderId == null ||
          orderId.isEmpty) {
        throw Exception(
          'Razorpay order ID was not returned by the server.',
        );
      }

      if (amountPaise <= 0) {
        throw Exception(
          'Invalid Razorpay payment amount.',
        );
      }

      if (currency == null ||
          currency.isEmpty) {
        throw Exception(
          'Payment currency was not returned by the server.',
        );
      }

      // --------------------------------------------------------
      // STORE ACTIVE PAYMENT DETAILS
      // --------------------------------------------------------

      _activeOrderId =
          orderId;

      _activePaymentAttemptId =
          paymentAttemptId;

      _activePaymentAmount =
          amountRupees > 0
              ? amountRupees
              : amountPaise /
                  100.0;

      // --------------------------------------------------------
      // OPEN RAZORPAY
      // --------------------------------------------------------

      final user =
          await _getCurrentUserDetails(
        latestBooking,
      );

      final options =
          <String, dynamic>{
        'key':
            keyId,

        'amount':
            amountPaise,

        'currency':
            currency,

        'name':
            user['name'] ??
                'Rentocar',

        'description':
            'Car rental booking ${latestBooking.bookingId}',

        'order_id':
            orderId,

        'timeout':
            300,

        'prefill': {
          'name':
              user['name'] ??
                  '',
          'contact':
              user['contact'] ??
                  '',
          'email':
              user['email'] ??
                  '',
        },

        'notes': {
          'tenantId':
              _tenantId,
          'bookingId':
              latestBooking.bookingId,
        },

        'theme': {
          'color':
              '#0F766E',
        },
      };

      _razorpayOpened =
          true;

      _razorpay.open(
        options,
      );
    } on FirebaseFunctionsException catch (e) {
      _razorpayOpened =
          false;

      if (!mounted) {
        return;
      }

      _showMessage(
        e.message ??
            'Unable to start payment.',
        error: true,
      );
    } catch (e) {
      _razorpayOpened =
          false;

      if (!mounted) {
        return;
      }

      _showMessage(
        _cleanError(e),
        error: true,
      );
    } finally {
      if (mounted &&
          !_razorpayOpened) {
        setState(() {
          _isProcessing =
              false;
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
    _razorpayOpened =
        false;

    final paymentId =
        response.paymentId
            ?.trim();

    final orderId =
        response.orderId
            ?.trim();

    final signature =
        response.signature
            ?.trim();

    // ----------------------------------------------------------
    // Validate Razorpay response
    // ----------------------------------------------------------

    if (paymentId == null ||
        paymentId.isEmpty) {
      await _paymentVerificationFailed(
        'Razorpay did not return a payment ID.',
      );

      return;
    }

    if (orderId == null ||
        orderId.isEmpty) {
      await _paymentVerificationFailed(
        'Razorpay did not return an order ID.',
      );

      return;
    }

    if (signature == null ||
        signature.isEmpty) {
      await _paymentVerificationFailed(
        'Razorpay did not return a payment signature.',
      );

      return;
    }

    if (_activeOrderId != null &&
        _activeOrderId != orderId) {
      await _paymentVerificationFailed(
        'Payment order mismatch. Please try again.',
      );

      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isProcessing =
          true;
    });

    try {
      // --------------------------------------------------------
      // BACKEND SIGNATURE VERIFICATION
      // --------------------------------------------------------

      final callable =
          _functions.httpsCallable(
        'verifyRazorpaySignature',
      );

      final result =
          await callable.call({
        'tenantId':
            _tenantId,

        'orderId':
            orderId,

        'paymentId':
            paymentId,

        'signature':
            signature,
      });

      final data =
          Map<String, dynamic>.from(
        result.data as Map,
      );

      final verified =
          data['verified'] ==
              true;

      if (!verified) {
        throw Exception(
          'Payment verification failed.',
        );
      }

      // --------------------------------------------------------
      // FETCH LATEST BOOKING AGAIN
      // --------------------------------------------------------

      final bookingRef =
          FirebaseFirestore
              .instance
              .collection('tenants')
              .doc(_tenantId)
              .collection('bookings')
              .doc(
                widget.booking.bookingId,
              );

      final bookingSnapshot =
          await bookingRef.get();

      if (!bookingSnapshot.exists ||
          bookingSnapshot.data() ==
              null) {
        throw Exception(
          'Booking could not be found after payment verification.',
        );
      }

      final latestBooking =
          Booking.fromMap(
        bookingSnapshot.id,
        bookingSnapshot.data()!,
      );

      if (latestBooking.tenantId !=
          _tenantId) {
        throw Exception(
          'Invalid tenant booking.',
        );
      }

      // --------------------------------------------------------
      // GET CURRENT OUTSTANDING AMOUNT
      // --------------------------------------------------------

      final currentBalance =
          latestBooking.balanceAmount;

      if (currentBalance <=
          0.009) {
        throw Exception(
          'This booking has already been fully paid.',
        );
      }

      final paymentAmount =
          _activePaymentAmount ??
              currentBalance;

      // --------------------------------------------------------
      // SAFETY CHECK
      //
      // Never record more than the current outstanding balance.
      // --------------------------------------------------------

      final amountToRecord =
          paymentAmount >
                  currentBalance
              ? currentBalance
              : paymentAmount;

      if (amountToRecord <=
          0) {
        throw Exception(
          'Invalid payment amount.',
        );
      }

      // --------------------------------------------------------
      // RECORD VERIFIED RAZORPAY PAYMENT
      //
      // BookingService already supports:
      //
      // PaymentMethodType.razorpay
      // razorpayOrderId
      // razorpayPaymentId
      // razorpaySignature
      // gateway
      // gatewayStatus
      // gatewayMethod
      //
      // It also prevents duplicate Razorpay payment IDs.
      // --------------------------------------------------------

      final transaction =
          await _bookingService
              .addVerifiedCustomerPayment(
        tenantId:
            _tenantId,

        bookingId:
            latestBooking.bookingId,

        amount:
            amountToRecord,

        method:
            PaymentMethodType.razorpay,

        transactionReference:
            paymentId,

        gateway:
            'razorpay',

        razorpayOrderId:
            orderId,

        razorpayPaymentId:
            paymentId,

        razorpaySignature:
            signature,

        gatewayTransactionId:
            paymentId,

        gatewayStatus:
            'captured',

        gatewayMethod:
            'razorpay',

        note:
            'Verified Razorpay customer payment.',

        paymentDate:
            DateTime.now(),

        currency:
            'INR',
      );

      // --------------------------------------------------------
      // REFRESH BOOKING
      // --------------------------------------------------------

      final refreshed =
          await bookingRef.get();

      final savedBooking =
          refreshed.exists &&
                  refreshed.data() !=
                      null
              ? Booking.fromMap(
                  refreshed.id,
                  refreshed.data()!,
                )
              : latestBooking;

      // --------------------------------------------------------
      // CONFIRM ONLY AFTER PAYMENT LEDGER IS SUCCESSFULLY SAVED
      // --------------------------------------------------------

      if (savedBooking.balanceAmount <=
          0.009) {
        await bookingRef.update({
          'status':
              BookingStatus.confirmed.name,
          'updatedAt':
              FieldValue
                  .serverTimestamp(),
        });
      }

      // --------------------------------------------------------
      // FETCH FINAL BOOKING
      // --------------------------------------------------------

      final finalSnapshot =
          await bookingRef.get();

      final finalBooking =
          finalSnapshot.exists &&
                  finalSnapshot.data() !=
                      null
              ? Booking.fromMap(
                  finalSnapshot.id,
                  finalSnapshot.data()!,
                )
              : savedBooking;

      if (!mounted) {
        return;
      }

      setState(() {
        _latestBooking =
            finalBooking;

        _lastCheckedText =
            _formatTime(
          DateTime.now(),
        );

        _activeOrderId =
            null;

        _activePaymentAttemptId =
            null;

        _activePaymentAmount =
            null;
      });

      // --------------------------------------------------------
      // SUCCESS SCREEN
      // --------------------------------------------------------

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PaymentSuccessScreen(
            booking:
                finalBooking,

            paymentId:
                transaction
                    .razorpayPaymentId ??
                paymentId,
          ),
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      await _paymentVerificationFailed(
        e.message ??
            'Payment verification failed.',
      );
    } catch (e) {
      await _paymentVerificationFailed(
        _cleanError(e),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing =
              false;
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
  // PAYMENT METHOD
  // ============================================================

  Widget _buildPaymentMethod() {
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
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment method',
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
            height: 14,
          ),
          Container(
            padding:
                const EdgeInsets.all(
              14,
            ),
            decoration:
                BoxDecoration(
              color:
                  softAccent,
              borderRadius:
                  BorderRadius.circular(
                15,
              ),
              border:
                  Border.all(
                color:
                    accent.withOpacity(
                  0.18,
                ),
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons
                      .account_balance_wallet_outlined,
                  color:
                      primary,
                ),
                SizedBox(
                  width: 12,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Razorpay Secure Payment',
                        style:
                            TextStyle(
                          fontFamily:
                              'Manrope',
                          fontSize: 14,
                          fontWeight:
                              FontWeight.w800,
                          color:
                              heading,
                        ),
                      ),
                      SizedBox(
                        height: 3,
                      ),
                      Text(
                        'Pay securely using UPI, cards, net banking and supported wallets.',
                        style:
                            TextStyle(
                          fontFamily:
                              'Manrope',
                          fontSize: 11,
                          color:
                              body,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons
                      .verified_rounded,
                  color:
                      primary,
                  size: 21,
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
                        : _completePayment,
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
                                : 'Pay with Razorpay',
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

              const Text(
                'Your payment has been verified and your booking is confirmed.',
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
            'Confirmed',
          ),

          const SizedBox(
            height: 12,
          ),

          _row(
            'Paid',
            '₹${booking.paidAmount.toStringAsFixed(0)}',
          ),
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
