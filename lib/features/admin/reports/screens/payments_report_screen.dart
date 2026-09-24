import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/config/app_config.dart';
import '../../../booking/models/booking.dart';
import 'package:customer_app_car_rental/features/admin/booking/screens/admin_booking_details_screen.dart';
import '../../../booking/services/booking_service.dart';

/// Premium tenant-scoped Payments & Revenue Report.
///
/// Features:
/// - Today / yesterday / week / month / custom date filtering
/// - Payment-date based reporting
/// - Revenue / collected / pending / refund summaries
/// - Security deposit due tracking
/// - Payment-method breakdown
/// - Outstanding bookings
/// - Payment transaction ledger
/// - Customer + vehicle + booking information
/// - Click transaction/booking -> Admin Booking Details
/// - PDF export
/// - Share report
/// - Responsive desktop/tablet/mobile UI
///
/// IMPORTANT:
/// Current payment transactions do not contain an explicit
/// rent-vs-security-deposit allocation. Therefore this screen does not
/// fabricate deposit collection values. Security deposit is reported as
/// booking-level deposit due.
class PaymentsReportScreen extends StatefulWidget {
  const PaymentsReportScreen({
    super.key,
  });

  @override
  State<PaymentsReportScreen> createState() =>
      _PaymentsReportScreenState();
}

enum _ReportPreset {
  today,
  yesterday,
  thisWeek,
  lastWeek,
  thisMonth,
  lastMonth,
  thisYear,
  custom,
}

class _PaymentsReportScreenState
    extends State<PaymentsReportScreen> {
  static const Color background = Color(0xFFF6F8FA);
  static const Color card = Colors.white;
  static const Color heading = Color(0xFF17201F);
  static const Color body = Color(0xFF53615E);
  static const Color muted = Color(0xFF8A9693);
  static const Color border = Color(0xFFE3E9E7);

  static const Color primary = Color(0xFF0F766E);
  static const Color accent = Color(0xFF14B8A6);
  static const Color softPrimary = Color(0xFFE7F8F5);

  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFDC2626);
  static const Color purple = Color(0xFF7C3AED);
  static const Color blue = Color(0xFF2563EB);

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final BookingService _bookingService =
      BookingService.instance;

  _ReportPreset _preset = _ReportPreset.thisMonth;

  DateTime _fromDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );

  DateTime _toDate = DateTime.now();

  bool _loading = true;
  bool _refreshing = false;
  bool _exporting = false;

  String? _error;

  List<_PaymentReportRow> _rows = <_PaymentReportRow>[];

  double _totalBusiness = 0;
  double _rentalRevenue = 0;
  double _amountCollected = 0;
  double _pendingAmount = 0;
  double _totalRefunded = 0;
  double _securityDepositDue = 0;

  int _bookingCount = 0;
  int _paidBookingCount = 0;
  int _partialBookingCount = 0;
  int _pendingBookingCount = 0;

  final Map<String, double> _methodTotals =
      <String, double>{};

  final Map<String, Booking> _bookingCache =
      <String, Booking>{};

  String get _tenantId {
    try {
      return AppConfig.tenant.tenantId.trim();
    } catch (_) {
      return '';
    }
  }

  String get _businessName {
    try {
      final business =
          AppConfig.tenant.business.name.trim();

      if (business.isNotEmpty) {
        return business;
      }

      final appName =
          AppConfig.tenant.branding.appName.trim();

      if (appName.isNotEmpty) {
        return appName;
      }
    } catch (_) {}

    return 'Rental Business';
  }

  DateTime get _rangeStart => DateTime(
        _fromDate.year,
        _fromDate.month,
        _fromDate.day,
      );

  DateTime get _rangeEnd => DateTime(
        _toDate.year,
        _toDate.month,
        _toDate.day,
        23,
        59,
        59,
        999,
      );

  String get _rangeLabel {
    final formatter = DateFormat('dd MMM yyyy');

    if (_isSameDay(_rangeStart, _rangeEnd)) {
      return formatter.format(_rangeStart);
    }

    return '${formatter.format(_rangeStart)} – '
        '${formatter.format(_rangeEnd)}';
  }

  @override
  void initState() {
    super.initState();
    _applyPreset(_ReportPreset.thisMonth, reload: false);
    _loadReport();
  }

  // ============================================================
  // DATE RANGE
  // ============================================================

  void _applyPreset(
    _ReportPreset preset, {
    bool reload = true,
  }) {
    final now = DateTime.now();

    DateTime start;
    DateTime end;

    switch (preset) {
      case _ReportPreset.today:
        start = DateTime(
          now.year,
          now.month,
          now.day,
        );
        end = start;
        break;

      case _ReportPreset.yesterday:
        final yesterday =
            now.subtract(const Duration(days: 1));

        start = DateTime(
          yesterday.year,
          yesterday.month,
          yesterday.day,
        );

        end = start;
        break;

      case _ReportPreset.thisWeek:
        final dayOffset =
            now.weekday - DateTime.monday;

        start = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(
          Duration(days: dayOffset),
        );

        end = now;
        break;

      case _ReportPreset.lastWeek:
        final currentMonday = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(
          Duration(
            days: now.weekday - DateTime.monday,
          ),
        );

        start = currentMonday.subtract(
          const Duration(days: 7),
        );

        end = currentMonday.subtract(
          const Duration(days: 1),
        );

        break;

      case _ReportPreset.thisMonth:
        start = DateTime(
          now.year,
          now.month,
          1,
        );

        end = now;
        break;

      case _ReportPreset.lastMonth:
        final firstThisMonth = DateTime(
          now.year,
          now.month,
          1,
        );

        final lastMonthEnd =
            firstThisMonth.subtract(
          const Duration(days: 1),
        );

        start = DateTime(
          lastMonthEnd.year,
          lastMonthEnd.month,
          1,
        );

        end = lastMonthEnd;
        break;

      case _ReportPreset.thisYear:
        start = DateTime(
          now.year,
          1,
          1,
        );

        end = now;
        break;

      case _ReportPreset.custom:
        return;
    }

    setState(() {
      _preset = preset;
      _fromDate = start;
      _toDate = end;
    });

    if (reload) {
      _loadReport();
    }
  }

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    setState(() {
      _preset = _ReportPreset.custom;
      _fromDate = picked;

      if (_toDate.isBefore(_fromDate)) {
        _toDate = picked;
      }
    });
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate,
      firstDate: _fromDate,
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    setState(() {
      _preset = _ReportPreset.custom;
      _toDate = picked;
    });
  }

  // ============================================================
  // LOAD REPORT
  // ============================================================

  Future<void> _loadReport({
    bool refresh = false,
  }) async {
    if (_tenantId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Tenant configuration is missing.';
      });
      return;
    }

    if (mounted) {
      setState(() {
        if (refresh) {
          _refreshing = true;
        } else {
          _loading = true;
        }

        _error = null;
      });
    }

    try {
      /*
       * We intentionally read the tenant's bookings and their payment
       * ledgers instead of creating a second reporting collection.
       *
       * This keeps the report consistent with the existing BookingService
       * ledger:
       *
       * tenants/{tenantId}/bookings/{bookingId}/payments/{paymentId}
       */
      final bookingSnapshot = await _firestore
          .collection('tenants')
          .doc(_tenantId)
          .collection('bookings')
          .get();

      final bookings = <Booking>[];

      for (final document in bookingSnapshot.docs) {
        try {
          final booking = Booking.fromMap(
            document.id,
            document.data(),
          );

          if (booking.tenantId.isNotEmpty &&
              booking.tenantId != _tenantId) {
            continue;
          }

          bookings.add(booking);
          _bookingCache[booking.bookingId] = booking;
        } catch (_) {
          // Ignore malformed legacy booking records.
        }
      }

      final rows = <_PaymentReportRow>[];

      for (final booking in bookings) {
        final paymentSnapshot = await _firestore
            .collection('tenants')
            .doc(_tenantId)
            .collection('bookings')
            .doc(booking.bookingId)
            .collection('payments')
            .orderBy(
              'paymentDate',
              descending: true,
            )
            .get();

        for (final paymentDoc
            in paymentSnapshot.docs) {
          try {
            final transaction =
                PaymentTransaction.fromMap(
              paymentDoc.id,
              paymentDoc.data(),
            );

            final paymentDate =
                transaction.paymentDate;

            if (paymentDate == null) {
              continue;
            }

            if (paymentDate.isBefore(_rangeStart) ||
                paymentDate.isAfter(_rangeEnd)) {
              continue;
            }

            rows.add(
              _PaymentReportRow(
                booking: booking,
                transaction: transaction,
              ),
            );
          } catch (_) {
            // Ignore malformed payment transactions.
          }
        }
      }

      rows.sort(
        (a, b) =>
            b.paymentDate.compareTo(a.paymentDate),
      );

      _calculateSummary(
        rows: rows,
        allBookings: bookings,
      );

      if (!mounted) return;

      setState(() {
        _rows = rows;
        _loading = false;
        _refreshing = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _refreshing = false;
        _error = _cleanError(e);
      });
    }
  }

  void _calculateSummary({
  required List<_PaymentReportRow> rows,
  required List<Booking> allBookings,
}) {
  double collected = 0;
  double refunded = 0;

  final methods = <String, double>{};

  for (final row in rows) {
    final transaction = row.transaction;

    if (transaction.isRefund) {
      final refundValue = transaction.refundAmount > 0
          ? transaction.refundAmount
          : transaction.amount;

      refunded += refundValue;
    } else {
      collected += transaction.amount;

      final method = _prettyMethod(
        transaction.method.toString(),
      );

      methods[method] =
          (methods[method] ?? 0) + transaction.amount;
    }
  }

  // Get unique bookings having payment activity in the selected period.
  final selectedBookingIds = rows
      .map((e) => e.booking.bookingId)
      .where((id) => id.isNotEmpty)
      .toSet();

  double business = 0;
  double rentalRevenue = 0;
  double depositDue = 0;

  int paidBookings = 0;
  int partialBookings = 0;
  int pendingBookings = 0;

  for (final booking in allBookings) {
    if (!selectedBookingIds.contains(booking.bookingId)) {
      continue;
    }

    business += booking.totalAmount;
    rentalRevenue += booking.totalAmount;
    depositDue += booking.securityDeposit;

    switch (booking.paymentStatus) {
      case PaymentStatus.paid:
        paidBookings++;
        break;

      case PaymentStatus.partiallyPaid:
        partialBookings++;
        break;

      case PaymentStatus.pending:
      case PaymentStatus.refunded:
      case PaymentStatus.partiallyRefunded:
      case PaymentStatus.failed:
        pendingBookings++;
        break;
    }
  }

  // Calculate outstanding balance from the latest booking state.
  double pending = 0;

  for (final booking in allBookings) {
    if (!selectedBookingIds.contains(booking.bookingId)) {
      continue;
    }

    final isExcludedStatus =
        booking.status == BookingStatus.cancelled ||
        booking.status == BookingStatus.rejected ||
        booking.status == BookingStatus.noShow;

    if (!isExcludedStatus && booking.balanceAmount > 0.009) {
      pending += booking.balanceAmount;
    }
  }

  if (!mounted) return;

  setState(() {
    _totalBusiness = business;
    _rentalRevenue = rentalRevenue;
    _amountCollected = collected;
    _pendingAmount = pending;
    _totalRefunded = refunded;
    _securityDepositDue = depositDue;

    _bookingCount = selectedBookingIds.length;
    _paidBookingCount = paidBookings;
    _partialBookingCount = partialBookings;
    _pendingBookingCount = pendingBookings;

    _methodTotals
      ..clear()
      ..addAll(methods);
  });
}

  // ============================================================
  // BOOKING DETAILS
  // ============================================================

  Future<void> _openBooking(
    Booking booking,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminBookingDetailsScreen(
          booking: booking,
          onBookingChanged: (_) {
            // Details screen handles its own refresh.
          },
        ),
      ),
    );

    if (!mounted) return;

    await _loadReport(refresh: true);
  }

  // ============================================================
  // EXPORT
  // ============================================================

  Future<void> _exportPdf() async {
    if (_exporting) return;

    setState(() => _exporting = true);

    try {
      final document = await _buildPdf();

      await Printing.sharePdf(
        bytes: await document.save(),
        filename:
            'payments_report_${DateFormat('yyyyMMdd').format(_fromDate)}_'
            '${DateFormat('yyyyMMdd').format(_toDate)}.pdf',
      );
    } catch (e) {
      if (mounted) {
        _showMessage(
          'Unable to export PDF: ${_cleanError(e)}',
          error: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  Future<pw.Document> _buildPdf() async {
    final document = pw.Document();

    final generatedAt =
        DateFormat('dd MMM yyyy, hh:mm a')
            .format(DateTime.now());

    final money = (double value) =>
        'Rs ${value.toStringAsFixed(2)}';

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) {
          return [
            pw.Container(
              padding: const pw.EdgeInsets.all(18),
              decoration: pw.BoxDecoration(
                color: PdfColors.teal,
                borderRadius:
                    pw.BorderRadius.circular(12),
              ),
              child: pw.Column(
                crossAxisAlignment:
                    pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    _businessName,
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 19,
                      fontWeight:
                          pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'Payments & Revenue Report',
                    style: const pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 12,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Period: $_rangeLabel',
                    style: const pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 9,
                    ),
                  ),
                  pw.Text(
                    'Generated: $generatedAt',
                    style: const pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 8,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 18),

            _pdfSectionTitle('Financial Summary'),

            pw.Table(
              border: pw.TableBorder.all(
                color: PdfColors.grey300,
              ),
              children: [
                _pdfRow(
                  'Total Business',
                  money(_totalBusiness),
                ),
                _pdfRow(
                  'Rental Revenue',
                  money(_rentalRevenue),
                ),
                _pdfRow(
                  'Amount Collected',
                  money(_amountCollected),
                ),
                _pdfRow(
                  'Pending Amount',
                  money(_pendingAmount),
                ),
                _pdfRow(
                  'Security Deposit Due',
                  money(_securityDepositDue),
                ),
                _pdfRow(
                  'Total Refunded',
                  money(_totalRefunded),
                ),
                _pdfRow(
                  'Net Collected',
                  money(
                    _amountCollected -
                        _totalRefunded,
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 18),

            _pdfSectionTitle(
              'Booking Statistics',
            ),

            pw.Table(
              border: pw.TableBorder.all(
                color: PdfColors.grey300,
              ),
              children: [
                _pdfRow(
                  'Bookings',
                  '$_bookingCount',
                ),
                _pdfRow(
                  'Paid',
                  '$_paidBookingCount',
                ),
                _pdfRow(
                  'Partially Paid',
                  '$_partialBookingCount',
                ),
                _pdfRow(
                  'Pending',
                  '$_pendingBookingCount',
                ),
              ],
            ),

            pw.SizedBox(height: 18),

            _pdfSectionTitle(
              'Payment Methods',
            ),

            if (_methodTotals.isEmpty)
              pw.Text(
                'No payment transactions found.',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey600,
                ),
              )
            else
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                ),
                children: _methodTotals.entries
                    .map(
                      (entry) => _pdfRow(
                        entry.key,
                        money(entry.value),
                      ),
                    )
                    .toList(),
              ),

            pw.SizedBox(height: 20),

            _pdfSectionTitle(
              'Payment Transactions',
            ),

            if (_rows.isEmpty)
              pw.Text(
                'No transactions found for this period.',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey600,
                ),
              )
            else
              pw.TableHelper.fromTextArray(
                headers: const [
                  'Date',
                  'Customer',
                  'Booking',
                  'Vehicle',
                  'Type',
                  'Method',
                  'Amount',
                ],
                headerStyle: pw.TextStyle(
                  fontSize: 7,
                  fontWeight:
                      pw.FontWeight.bold,
                ),
                cellStyle: const pw.TextStyle(
                  fontSize: 6.5,
                ),
                headerDecoration:
                    const pw.BoxDecoration(
                  color: PdfColors.grey200,
                ),
                data: _rows.map((row) {
                  final booking =
                      row.booking;

                  final isRefund =
                      row.transaction.isRefund;

                  final amount =
                      row.transaction.amount;

                  return [
                    DateFormat('dd/MM/yyyy')
                        .format(
                      row.paymentDate,
                    ),
                    booking.customerName,
                    booking.bookingId,
                    _vehicleName(booking),
                    isRefund
                        ? 'Refund'
                        : 'Payment',
                    _prettyMethod(
                      row.transaction.method
                          .toString(),
                    ),
                    '${isRefund ? '-' : ''}'
                        '${money(amount)}',
                  ];
                }).toList(),
              ),

            pw.SizedBox(height: 16),

            pw.Text(
              'Security deposit note: the current payment ledger '
              'does not store explicit rent/deposit allocation per '
              'transaction. Security deposit is therefore reported '
              'from the booking-level security deposit field.',
              style: const pw.TextStyle(
                fontSize: 7,
                color: PdfColors.grey600,
              ),
            ),
          ];
        },
      ),
    );

    return document;
  }

  pw.Widget _pdfSectionTitle(
    String title,
  ) {
    return pw.Padding(
      padding:
          const pw.EdgeInsets.only(bottom: 8),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  pw.TableRow _pdfRow(
    String label,
    String value,
  ) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding:
              const pw.EdgeInsets.all(7),
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight:
                  pw.FontWeight.bold,
            ),
          ),
        ),
        pw.Padding(
          padding:
              const pw.EdgeInsets.all(7),
          child: pw.Text(
            value,
            style: const pw.TextStyle(
              fontSize: 8,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _shareReport() async {
    if (_rows.isEmpty) {
      _showMessage(
        'There are no transactions to share.',
      );
      return;
    }

    try {
      final summary = '''
$_businessName
Payments & Revenue Report

Period: $_rangeLabel

Total Business: ${_money(_totalBusiness)}
Rental Revenue: ${_money(_rentalRevenue)}
Amount Collected: ${_money(_amountCollected)}
Pending Amount: ${_money(_pendingAmount)}
Security Deposit Due: ${_money(_securityDepositDue)}
Refunded: ${_money(_totalRefunded)}
Net Collected: ${_money(_amountCollected - _totalRefunded)}

Bookings: $_bookingCount
Paid: $_paidBookingCount
Partially Paid: $_partialBookingCount
Pending: $_pendingBookingCount
''';

      await SharePlus.instance.share(
        ShareParams(
          text: summary,
          subject:
              'Payments Report - $_businessName',
        ),
      );
    } catch (e) {
      if (mounted) {
        _showMessage(
          'Unable to share report: ${_cleanError(e)}',
          error: true,
        );
      }
    }
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final width =
        MediaQuery.sizeOf(context).width;

    final isMobile = width < 720;
    final isTablet =
        width >= 720 && width < 1100;

    return Scaffold(
      backgroundColor: background,
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        color: primary,
        onRefresh: () =>
            _loadReport(refresh: true),
        child: CustomScrollView(
          physics:
              const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: _buildHeader(
                isMobile: isMobile,
              ),
            ),

            SliverToBoxAdapter(
              child: _buildDateFilters(
                isMobile: isMobile,
              ),
            ),

            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child:
                      CircularProgressIndicator(
                    color: primary,
                  ),
                ),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildErrorState(),
              )
            else
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.fromLTRB(
                    20,
                    0,
                    20,
                    40,
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      _buildKpis(
                        isMobile: isMobile,
                      ),
                      const SizedBox(height: 22),
                      _buildFinancialOverview(
                        isMobile: isMobile,
                      ),
                      const SizedBox(height: 22),
                      _buildPaymentMethods(
                        isMobile: isMobile,
                      ),
                      const SizedBox(height: 22),
                      _buildOutstanding(
                        isMobile: isMobile,
                      ),
                      const SizedBox(height: 22),
                      _buildTransactions(
                        isMobile: isMobile,
                        isTablet: isTablet,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: card,
      surfaceTintColor:
          Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_rounded,
          color: heading,
        ),
        onPressed: () =>
            Navigator.of(context).pop(),
      ),
      titleSpacing: 0,
      title: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            'Payments & Reports',
            style: GoogleFonts.manrope(
              color: heading,
              fontSize: 17,
              fontWeight:
                  FontWeight.w900,
            ),
          ),
          Text(
            _rangeLabel,
            style: GoogleFonts.manrope(
              color: muted,
              fontSize: 9.5,
              fontWeight:
                  FontWeight.w700,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: _refreshing
              ? null
              : () => _loadReport(
                    refresh: true,
                  ),
          icon: _refreshing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2,
                    color: primary,
                  ),
                )
              : const Icon(
                  Icons.refresh_rounded,
                  color: heading,
                ),
        ),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize:
            const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: border,
        ),
      ),
    );
  }

  Widget _buildHeader({
    required bool isMobile,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        isMobile ? 22 : 30,
        20,
        20,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            'Financial overview',
            style: GoogleFonts.manrope(
              color: heading,
              fontSize:
                  isMobile ? 25 : 30,
              fontWeight:
                  FontWeight.w900,
              letterSpacing: -0.7,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Track rental business, collections, pending balances, '
            'refunds and payment activity.',
            style: GoogleFonts.manrope(
              color: body,
              fontSize: 12,
              height: 1.45,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilters({
    required bool isMobile,
  }) {
    return Container(
      margin:
          const EdgeInsets.fromLTRB(
        20,
        0,
        20,
        22,
      ),
      padding:
          const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: card,
        borderRadius:
            BorderRadius.circular(20),
        border:
            Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(
              .025,
            ),
            blurRadius: 22,
            offset:
                const Offset(0, 7),
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
                width: 40,
                height: 40,
                decoration:
                    BoxDecoration(
                  color: softPrimary,
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
                child: const Icon(
                  Icons.date_range_rounded,
                  color: primary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Report period',
                      style:
                          GoogleFonts.manrope(
                        color: heading,
                        fontSize: 13,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Report transactions by payment date',
                      style:
                          GoogleFonts.manrope(
                        color: muted,
                        fontSize: 9.5,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _smallLabel(
                '$_rangeLabel',
                primary,
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection:
                  Axis.horizontal,
              children: [
                _presetChip(
                  'Today',
                  _ReportPreset.today,
                ),
                _presetChip(
                  'Yesterday',
                  _ReportPreset.yesterday,
                ),
                _presetChip(
                  'This Week',
                  _ReportPreset.thisWeek,
                ),
                _presetChip(
                  'Last Week',
                  _ReportPreset.lastWeek,
                ),
                _presetChip(
                  'This Month',
                  _ReportPreset.thisMonth,
                ),
                _presetChip(
                  'Last Month',
                  _ReportPreset.lastMonth,
                ),
                _presetChip(
                  'This Year',
                  _ReportPreset.thisYear,
                ),
                _presetChip(
                  'Custom',
                  _ReportPreset.custom,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (isMobile)
            Column(
              children: [
                _dateButton(
                  title: 'From',
                  date: _fromDate,
                  onTap: _pickFromDate,
                ),
                const SizedBox(height: 9),
                _dateButton(
                  title: 'To',
                  date: _toDate,
                  onTap: _pickToDate,
                ),
                const SizedBox(height: 10),
                _applyButton(),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: _dateButton(
                    title: 'From',
                    date: _fromDate,
                    onTap: _pickFromDate,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _dateButton(
                    title: 'To',
                    date: _toDate,
                    onTap: _pickToDate,
                  ),
                ),
                const SizedBox(width: 10),
                _applyButton(),
              ],
            ),
        ],
      ),
    );
  }

  Widget _presetChip(
    String label,
    _ReportPreset preset,
  ) {
    final selected = _preset == preset;

    return Padding(
      padding:
          const EdgeInsets.only(right: 7),
      child: InkWell(
        borderRadius:
            BorderRadius.circular(12),
        onTap: () {
          if (preset == _ReportPreset.custom) {
            setState(() {
              _preset =
                  _ReportPreset.custom;
            });
            return;
          }

          _applyPreset(preset);
        },
        child: Container(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 13,
          ),
          decoration: BoxDecoration(
            color: selected
                ? primary
                : background,
            borderRadius:
                BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? primary
                  : border,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.manrope(
              color: selected
                  ? Colors.white
                  : body,
              fontSize: 10,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  Widget _dateButton({
    required String title,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius:
          BorderRadius.circular(13),
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 11,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius:
              BorderRadius.circular(13),
          border:
              Border.all(color: border),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_rounded,
              size: 16,
              color: primary,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style:
                        GoogleFonts.manrope(
                      color: muted,
                      fontSize: 8.5,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat(
                      'dd MMM yyyy',
                    ).format(date),
                    style:
                        GoogleFonts.manrope(
                      color: heading,
                      fontSize: 11,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: muted,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _applyButton() {
    return SizedBox(
      height: 44,
      child: ElevatedButton.icon(
        onPressed: () =>
            _loadReport(),
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor:
              Colors.white,
          elevation: 0,
          padding:
              const EdgeInsets.symmetric(
            horizontal: 17,
          ),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(13),
          ),
        ),
        icon: const Icon(
          Icons.filter_alt_rounded,
          size: 17,
        ),
        label: Text(
          'Apply',
          style: GoogleFonts.manrope(
            fontSize: 11,
            fontWeight:
                FontWeight.w900,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // KPI
  // ============================================================

  Widget _buildKpis({
    required bool isMobile,
  }) {
    final cards = [
      _KpiData(
        title: 'Total Business',
        value: _money(_totalBusiness),
        subtitle: 'Selected period',
        icon: Icons.business_center_rounded,
        color: primary,
      ),
      _KpiData(
        title: 'Collected',
        value: _money(_amountCollected),
        subtitle: 'Actual payments',
        icon: Icons.account_balance_wallet_rounded,
        color: success,
      ),
      _KpiData(
        title: 'Pending',
        value: _money(_pendingAmount),
        subtitle: 'Outstanding',
        icon: Icons.pending_actions_rounded,
        color: warning,
      ),
      _KpiData(
        title: 'Refunded',
        value: _money(_totalRefunded),
        subtitle: 'Refund transactions',
        icon: Icons.currency_exchange_rounded,
        color: purple,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = isMobile
            ? 2
            : constraints.maxWidth > 1000
                ? 4
                : 2;

        final spacing = 12.0;

        final width =
            (constraints.maxWidth -
                    spacing * (columns - 1)) /
                columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards
              .map(
                (data) => SizedBox(
                  width: width,
                  child: _kpiCard(data),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _kpiCard(
    _KpiData data,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: card,
        borderRadius:
            BorderRadius.circular(18),
        border:
            Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(.02),
            blurRadius: 18,
            offset:
                const Offset(0, 6),
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
                width: 38,
                height: 38,
                decoration:
                    BoxDecoration(
                  color: data.color
                      .withOpacity(.09),
                  borderRadius:
                      BorderRadius.circular(
                    11,
                  ),
                ),
                child: Icon(
                  data.icon,
                  color: data.color,
                  size: 20,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.more_horiz_rounded,
                color: muted,
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            data.title,
            style: GoogleFonts.manrope(
              color: muted,
              fontSize: 9.5,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            data.value,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style: GoogleFonts.manrope(
              color: heading,
              fontSize: 19,
              fontWeight:
                  FontWeight.w900,
              letterSpacing: -.4,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            data.subtitle,
            style: GoogleFonts.manrope(
              color: body,
              fontSize: 8.5,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FINANCIAL OVERVIEW
  // ============================================================

  Widget _buildFinancialOverview({
    required bool isMobile,
  }) {
    return _sectionCard(
      title: 'Financial overview',
      subtitle:
          'Business value, collections and outstanding balance.',
      icon: Icons.analytics_rounded,
      child: Column(
        children: [
          _financialRow(
            'Rental revenue',
            _rentalRevenue,
            color: primary,
          ),
          _financialRow(
            'Amount collected',
            _amountCollected,
            color: success,
          ),
          _financialRow(
            'Pending amount',
            _pendingAmount,
            color: warning,
          ),
          _financialRow(
            'Security deposit due',
            _securityDepositDue,
            color: blue,
          ),
          _financialRow(
            'Refunded',
            _totalRefunded,
            color: purple,
          ),
          const Divider(
            height: 24,
            color: border,
          ),
          _financialRow(
            'Net collected',
            _amountCollected -
                _totalRefunded,
            color: heading,
            strong: true,
          ),
        ],
      ),
    );
  }

  Widget _financialRow(
    String label,
    double value, {
    required Color color,
    bool strong = false,
  }) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 7,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.manrope(
                color: strong
                    ? heading
                    : body,
                fontSize: 11,
                fontWeight: strong
                    ? FontWeight.w900
                    : FontWeight.w700,
              ),
            ),
          ),
          Text(
            _money(value),
            style: GoogleFonts.manrope(
              color: color,
              fontSize:
                  strong ? 15 : 12,
              fontWeight:
                  FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // METHODS
  // ============================================================

  Widget _buildPaymentMethods({
    required bool isMobile,
  }) {
    final entries =
        _methodTotals.entries.toList()
          ..sort(
            (a, b) =>
                b.value.compareTo(
              a.value,
            ),
          );

    return _sectionCard(
      title: 'Payment methods',
      subtitle:
          'Collected amount grouped by payment method.',
      icon: Icons.payments_rounded,
      child: entries.isEmpty
          ? _emptyInline(
              'No payment transactions found.',
            )
          : Column(
              children: entries
                  .map(
                    (entry) =>
                        _methodRow(
                      entry.key,
                      entry.value,
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _methodRow(
    String method,
    double amount,
  ) {
    final total =
        _amountCollected <= 0
            ? 1
            : _amountCollected;

    final percentage =
        (amount / total)
            .clamp(0.0, 1.0);

    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 14,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  method,
                  style:
                      GoogleFonts.manrope(
                    color: heading,
                    fontSize: 10.5,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ),
              Text(
                _money(amount),
                style:
                    GoogleFonts.manrope(
                  color: heading,
                  fontSize: 11,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(percentage * 100).round()}%',
                style:
                    GoogleFonts.manrope(
                  color: muted,
                  fontSize: 9,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius:
                BorderRadius.circular(99),
            child:
                LinearProgressIndicator(
              minHeight: 6,
              value: percentage,
              backgroundColor:
                  background,
              valueColor:
                  const AlwaysStoppedAnimation<
                      Color>(
                primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // OUTSTANDING
  // ============================================================

  Widget _buildOutstanding({
    required bool isMobile,
  }) {
    final outstanding =
        <_PaymentReportRow>[];

    final bookingIds =
        _rows
            .map(
              (row) =>
                  row.booking.bookingId,
            )
            .toSet();

    for (final bookingId
        in bookingIds) {
      final booking =
          _bookingCache[bookingId];

      if (booking == null) continue;

      if (booking.balanceAmount <=
          0.009) {
        continue;
      }

      if (booking.status ==
              BookingStatus.cancelled ||
          booking.status ==
              BookingStatus.rejected ||
          booking.status ==
              BookingStatus.noShow) {
        continue;
      }

      outstanding.add(
        _PaymentReportRow(
          booking: booking,
          transaction:
              _rows.firstWhere(
            (row) =>
                row.booking.bookingId ==
                bookingId,
          ).transaction,
        ),
      );
    }

    outstanding.sort(
      (a, b) => b.booking.balanceAmount
          .compareTo(
        a.booking.balanceAmount,
      ),
    );

    return _sectionCard(
      title: 'Outstanding payments',
      subtitle:
          'Bookings with an unpaid balance in the selected report set.',
      icon: Icons.warning_amber_rounded,
      child: outstanding.isEmpty
          ? _emptyInline(
              'No outstanding payments.',
            )
          : Column(
              children: outstanding
                  .take(10)
                  .map(
                    (row) =>
                        _outstandingRow(
                      row.booking,
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _outstandingRow(
    Booking booking,
  ) {
    return InkWell(
      borderRadius:
          BorderRadius.circular(14),
      onTap: () =>
          _openBooking(booking),
      child: Container(
        margin:
            const EdgeInsets.only(
          bottom: 9,
        ),
        padding:
            const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: background,
          borderRadius:
              BorderRadius.circular(14),
          border:
              Border.all(color: border),
        ),
        child: Row(
          children: [
            _avatar(
              Icons.person_outline_rounded,
              warning,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    booking.customerName
                            .trim()
                            .isEmpty
                        ? 'Customer'
                        : booking.customerName,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        GoogleFonts.manrope(
                      color: heading,
                      fontSize: 10.5,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${booking.bookingId} • '
                    '${_vehicleName(booking)}',
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        GoogleFonts.manrope(
                      color: muted,
                      fontSize: 8.5,
                      fontWeight:
                          FontWeight.w700,
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
                  _money(
                    booking.balanceAmount,
                  ),
                  style:
                      GoogleFonts.manrope(
                    color: warning,
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 17,
                  color: muted,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TRANSACTIONS
  // ============================================================

  Widget _buildTransactions({
    required bool isMobile,
    required bool isTablet,
  }) {
    return _sectionCard(
      title: 'Payment transactions',
      subtitle:
          '${_rows.length} transactions • Tap a row to open Booking Details',
      icon: Icons.receipt_long_rounded,
      trailing: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          _exportButton(
            icon:
                Icons.picture_as_pdf_rounded,
            label: 'PDF',
            onTap: _exportPdf,
          ),
          const SizedBox(width: 7),
          _exportButton(
            icon:
                Icons.share_rounded,
            label: 'Share',
            onTap: _shareReport,
          ),
        ],
      ),
      child: _rows.isEmpty
          ? _emptyInline(
              'No payment transactions found for this period.',
            )
          : Column(
              children: [
                if (!isMobile)
                  _desktopTransactionHeader(
                    isTablet: isTablet,
                  ),
                ..._rows.map(
                  (row) =>
                      _transactionRow(
                    row,
                    isMobile: isMobile,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _desktopTransactionHeader({
    required bool isTablet,
  }) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      margin:
          const EdgeInsets.only(
        bottom: 6,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius:
            BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: _headerText('Date'),
          ),
          Expanded(
            flex: 3,
            child:
                _headerText('Customer'),
          ),
          Expanded(
            flex: 2,
            child:
                _headerText('Booking'),
          ),
          Expanded(
            flex: 2,
            child:
                _headerText('Vehicle'),
          ),
          SizedBox(
            width: 78,
            child:
                _headerText('Type'),
          ),
          SizedBox(
            width: 85,
            child:
                _headerText('Amount'),
          ),
          const SizedBox(width: 18),
        ],
      ),
    );
  }

  Widget _transactionRow(
    _PaymentReportRow row, {
    required bool isMobile,
  }) {
    final booking = row.booking;
    final transaction =
        row.transaction;

    final refund =
        transaction.isRefund;

    final amount =
        transaction.amount;

    final color =
        refund ? purple : success;

    return InkWell(
      borderRadius:
          BorderRadius.circular(14),
      onTap: () =>
          _openBooking(booking),
      child: Container(
        margin:
            const EdgeInsets.only(
          bottom: 7,
        ),
        padding:
            const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: card,
          borderRadius:
              BorderRadius.circular(14),
          border:
              Border.all(color: border),
        ),
        child: isMobile
            ? _mobileTransaction(
                row,
              )
            : _desktopTransaction(
                row,
                color: color,
                refund: refund,
                amount: amount,
              ),
      ),
    );
  }

  Widget _desktopTransaction(
    _PaymentReportRow row, {
    required Color color,
    required bool refund,
    required double amount,
  }) {
    final booking = row.booking;

    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            DateFormat('dd MMM')
                .format(
              row.paymentDate,
            ),
            style: GoogleFonts.manrope(
              color: body,
              fontSize: 9,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: _customerCell(
            booking,
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            booking.bookingId,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style: GoogleFonts.manrope(
              color: heading,
              fontSize: 9,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            _vehicleName(booking),
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style: GoogleFonts.manrope(
              color: body,
              fontSize: 9,
              fontWeight:
                  FontWeight.w700,
            ),
          ),
        ),
        SizedBox(
          width: 78,
          child: _typePill(
            refund
                ? 'Refund'
                : 'Payment',
            color,
          ),
        ),
        SizedBox(
          width: 85,
          child: Text(
            '${refund ? '-' : '+'}'
            '${_money(amount)}',
            textAlign: TextAlign.right,
            style: GoogleFonts.manrope(
              color: color,
              fontSize: 10.5,
              fontWeight:
                  FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Icon(
          Icons.chevron_right_rounded,
          size: 18,
          color: muted,
        ),
      ],
    );
  }

  Widget _mobileTransaction(
    _PaymentReportRow row,
  ) {
    final booking = row.booking;
    final transaction =
        row.transaction;

    final refund =
        transaction.isRefund;

    final color =
        refund ? purple : success;

    return Column(
      children: [
        Row(
          children: [
            _avatar(
              refund
                  ? Icons.currency_exchange_rounded
                  : Icons.payments_rounded,
              color,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    booking.customerName
                            .trim()
                            .isEmpty
                        ? 'Customer'
                        : booking.customerName,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        GoogleFonts.manrope(
                      color: heading,
                      fontSize: 11,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${booking.bookingId} • '
                    '${_vehicleName(booking)}',
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        GoogleFonts.manrope(
                      color: muted,
                      fontSize: 8.5,
                      fontWeight:
                          FontWeight.w700,
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
                  '${refund ? '-' : '+'}'
                  '${_money(transaction.amount)}',
                  style:
                      GoogleFonts.manrope(
                    color: color,
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  DateFormat(
                    'dd MMM • hh:mm a',
                  ).format(
                    row.paymentDate,
                  ),
                  style:
                      GoogleFonts.manrope(
                    color: muted,
                    fontSize: 8,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _typePill(
              refund
                  ? 'Refund'
                  : 'Payment',
              color,
            ),
            const SizedBox(width: 6),
            _typePill(
              _prettyMethod(
                transaction.method
                    .toString(),
              ),
              blue,
            ),
            const Spacer(),
            const Icon(
              Icons.open_in_new_rounded,
              color: muted,
              size: 15,
            ),
          ],
        ),
      ],
    );
  }

  Widget _customerCell(
    Booking booking,
  ) {
    return Row(
      children: [
        _avatar(
          Icons.person_outline_rounded,
          primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            booking.customerName
                    .trim()
                    .isEmpty
                ? 'Customer'
                : booking.customerName,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style: GoogleFonts.manrope(
              color: heading,
              fontSize: 9,
              fontWeight:
                  FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _typePill(
    String label,
    Color color,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color:
            color.withOpacity(.08),
        borderRadius:
            BorderRadius.circular(8),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow:
            TextOverflow.ellipsis,
        style: GoogleFonts.manrope(
          color: color,
          fontSize: 7.5,
          fontWeight:
              FontWeight.w900,
        ),
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  Widget _sectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius:
            BorderRadius.circular(20),
        border:
            Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(.02),
            blurRadius: 20,
            offset:
                const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration:
                    BoxDecoration(
                  color: softPrimary,
                  borderRadius:
                      BorderRadius.circular(
                    11,
                  ),
                ),
                child: Icon(
                  icon,
                  color: primary,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style:
                          GoogleFonts.manrope(
                        color: heading,
                        fontSize: 13,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style:
                          GoogleFonts.manrope(
                        color: muted,
                        fontSize: 9,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null)
                trailing,
            ],
          ),
          const SizedBox(height: 15),
          child,
        ],
      ),
    );
  }

  Widget _exportButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius:
          BorderRadius.circular(10),
      onTap: _exporting ? null : onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 9,
          vertical: 7,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius:
              BorderRadius.circular(10),
          border:
              Border.all(color: border),
        ),
        child: Row(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: primary,
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.manrope(
                color: heading,
                fontSize: 8,
                fontWeight:
                    FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyInline(
    String message,
  ) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(
        vertical: 28,
        horizontal: 18,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius:
            BorderRadius.circular(14),
        border:
            Border.all(color: border),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.receipt_long_outlined,
            color: muted,
            size: 28,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign:
                TextAlign.center,
            style: GoogleFonts.manrope(
              color: muted,
              fontSize: 10,
              fontWeight:
                  FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(28),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration:
                  BoxDecoration(
                color:
                    danger.withOpacity(.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: danger,
                size: 28,
              ),
            ),
            const SizedBox(height: 13),
            Text(
              'Unable to load report',
              style: GoogleFonts.manrope(
                color: heading,
                fontSize: 16,
                fontWeight:
                    FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              _error ?? 'Unknown error',
              textAlign:
                  TextAlign.center,
              style: GoogleFonts.manrope(
                color: body,
                fontSize: 10.5,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
            const SizedBox(height: 15),
            ElevatedButton(
              onPressed: () =>
                  _loadReport(),
              style:
                  ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor:
                    Colors.white,
                elevation: 0,
              ),
              child: const Text(
                'Try Again',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatar(
    IconData icon,
    Color color,
  ) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color:
            color.withOpacity(.09),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: color,
        size: 17,
      ),
    );
  }

  Widget _smallLabel(
    String text,
    Color color,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color:
            color.withOpacity(.08),
        borderRadius:
            BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: GoogleFonts.manrope(
          color: color,
          fontSize: 7.5,
          fontWeight:
              FontWeight.w900,
        ),
      ),
    );
  }

  Widget _headerText(String text) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.manrope(
        color: muted,
        fontSize: 7.5,
        fontWeight:
            FontWeight.w900,
        letterSpacing: .3,
      ),
    );
  }

  String _vehicleName(
    Booking booking,
  ) {
    try {
      final car = booking.car;

      if (car != null) {
        final dynamic value =
            car.name;

        if (value != null &&
            value
                .toString()
                .trim()
                .isNotEmpty) {
          return value
              .toString()
              .trim();
        }
      }
    } catch (_) {}

    return booking.carId.isEmpty
        ? 'Vehicle'
        : booking.carId;
  }

  String _prettyMethod(
    String value,
  ) {
    final normalized = value
        .replaceAll(
          'PaymentMethodType.',
          '',
        )
        .replaceAll('_', ' ')
        .trim();

    if (normalized.isEmpty) {
      return 'Other';
    }

    return normalized
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}'
                  '${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  String _money(double amount) {
    if (amount == amount.roundToDouble()) {
      return '₹${amount.toStringAsFixed(0)}';
    }

    return '₹${amount.toStringAsFixed(2)}';
  }

  String _cleanError(
    Object error,
  ) {
    return error
        .toString()
        .replaceFirst(
          'Exception: ',
          '',
        )
        .replaceFirst(
          'Bad state: ',
          '',
        )
        .trim();
  }

  bool _isSameDay(
    DateTime a,
    DateTime b,
  ) {
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day;
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
          behavior:
              SnackBarBehavior.floating,
          backgroundColor:
              error ? danger : heading,
          margin:
              const EdgeInsets.fromLTRB(
            18,
            0,
            18,
            18,
          ),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              13,
            ),
          ),
          content: Text(
            message,
            style: GoogleFonts.manrope(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight:
                  FontWeight.w700,
            ),
          ),
        ),
      );
  }
}

// ============================================================
// REPORT ROW
// ============================================================

class _PaymentReportRow {
  const _PaymentReportRow({
    required this.booking,
    required this.transaction,
  });

  final Booking booking;
  final PaymentTransaction transaction;

  DateTime get paymentDate =>
      transaction.paymentDate ??
      transaction.createdAt ??
      DateTime.fromMillisecondsSinceEpoch(
        0,
      );
}

// ============================================================
// KPI DATA
// ============================================================

class _KpiData {
  const _KpiData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
}