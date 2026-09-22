import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/booking.dart';
import '../services/booking_service.dart';

/// Customer-facing read-only 360° booking details screen.
///
/// It intentionally mirrors the information structure of the admin Booking
/// Details screen while removing all administrative mutation controls.
/// Customers can see the booking snapshot, pricing, payment summary,
/// transaction history, branches, notes and pickup/return inspection evidence.
class CustomerBookingDetailsScreen extends StatefulWidget {
  const CustomerBookingDetailsScreen({
    super.key,
    required this.booking,
    required this.tenantId,
  });

  final Booking booking;
  final String tenantId;

  @override
  State<CustomerBookingDetailsScreen> createState() =>
      _CustomerBookingDetailsScreenState();
}

class _CustomerBookingDetailsScreenState
    extends State<CustomerBookingDetailsScreen> {
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
  static const Color blue = Color(0xFF3B82F6);
  static const Color teal = Color(0xFF0F9F9A);

  final BookingService _bookingService = BookingService.instance;

  late Booking _booking;
  bool _loading = true;
  bool _refreshing = false;
  String? _error;

  Map<String, dynamic>? _inspectionData;
  List<PaymentTransaction> _payments = <PaymentTransaction>[];
  DateTime? _verifiedAt;

  @override
  void initState() {
    super.initState();
    _booking = widget.booking;
    _load();
  }

  Future<void> _load({bool fullLoader = true}) async {
    if (!mounted) return;
    setState(() {
      if (fullLoader) _loading = true;
      _refreshing = !fullLoader;
      _error = null;
    });

    try {
      final results = await Future.wait<dynamic>([
        _bookingService.getBooking(
          tenantId: widget.tenantId,
          bookingId: _booking.bookingId,
        ),
        _bookingService.getInspectionDataForCustomer(
          tenantId: widget.tenantId,
          bookingId: _booking.bookingId,
        ),
        _bookingService.getBookingPaymentsForCustomer(
          tenantId: widget.tenantId,
          bookingId: _booking.bookingId,
        ),
      ]);

      final fresh = results[0] as Booking?;
      if (fresh == null) throw Exception('Booking not found.');

      if (!mounted) return;
      setState(() {
        _booking = fresh;
        _inspectionData = results[1] as Map<String, dynamic>?;
        _payments = results[2] as List<PaymentTransaction>;
        _loading = false;
        _refreshing = false;
        _verifiedAt = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshing = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 8,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _text('Booking Details', size: 18, weight: FontWeight.w900),
            _text(
              _booking.bookingId,
              size: 10,
              color: muted,
              weight: FontWeight.w700,
            ),
          ],
        ),
        actions: [
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
              tooltip: 'Refresh booking',
              onPressed: () => _load(fullLoader: false),
              icon: const Icon(Icons.refresh_rounded, color: body),
            ),
          const SizedBox(width: 6),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: primary))
          : _error != null
              ? _errorView()
              : RefreshIndicator(
                  color: primary,
                  onRefresh: () => _load(fullLoader: false),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final content = constraints.maxWidth >= 980
                          ? _desktopLayout()
                          : _mobileLayout();
                      return SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1180),
                            child: content,
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: muted),
            const SizedBox(height: 14),
            _text('Unable to load booking', size: 18, weight: FontWeight.w900),
            const SizedBox(height: 7),
            _text(_error ?? 'Unknown error', size: 12, color: body, align: TextAlign.center),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => _load(),
              style: FilledButton.styleFrom(backgroundColor: primary),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _desktopLayout() {
    return Column(
      children: [
        _hero(),
        const SizedBox(height: 16),
        _lifecycle(),
        const SizedBox(height: 16),
        _inspectionActions(),
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
                  _paymentLedgerCard(),
                  const SizedBox(height: 16),
                  _branchCard(),
                  const SizedBox(height: 16),
                  _notesCard(),
                ],
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 350,
              child: Column(
                children: [
                  _inspectionSummaryCard(),
                  const SizedBox(height: 16),
                  _bookingSummaryCard(),
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
        _inspectionActions(),
        const SizedBox(height: 14),
        _inspectionSummaryCard(),
        const SizedBox(height: 14),
        _bookingSummaryCard(),
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

  Widget _hero() {
    final statusColor = _statusColor(_booking.status);
    return _card(
      padding: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, statusColor.withOpacity(.045)],
          ),
        ),
        child: Column(
          children: [
            LayoutBuilder(
              builder: (context, c) {
                final compact = c.maxWidth < 650;
                final identity = Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _vehicleAvatar(),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 7,
                            runSpacing: 7,
                            children: [
                              _pill(_statusLabel(_booking.status), statusColor, icon: _statusIcon(_booking.status)),
                              _pill(_paymentLabel(_booking.paymentStatus), _paymentColor(_booking.paymentStatus), icon: Icons.payments_rounded),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _text(
                            _booking.car?.name.isNotEmpty == true ? _booking.car!.name : 'Vehicle',
                            size: 22,
                            weight: FontWeight.w900,
                          ),
                          const SizedBox(height: 4),
                          _text(
                            '${_booking.customerName.isEmpty ? 'Customer' : _booking.customerName}  •  ${_booking.bookingId}',
                            size: 11,
                            color: muted,
                            weight: FontWeight.w700,
                          ),
                        ],
                      ),
                    ),
                  ],
                );

                final amount = Column(
                  crossAxisAlignment: compact ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                  children: [
                    _text('BOOKING VALUE', size: 8.5, color: muted, weight: FontWeight.w900, letterSpacing: 1.1),
                    const SizedBox(height: 3),
                    _text(_money(_booking.totalAmount), size: 23, weight: FontWeight.w900),
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
                    const SizedBox(height: 14),
                    const Divider(color: border, height: 1),
                    const SizedBox(height: 14),
                    if (compact)
                      Align(alignment: Alignment.centerLeft, child: amount)
                    else
                      Row(
                        children: [
                          _miniStat('PICKUP', _dateTime(_booking.pickupDateTime), Icons.login_rounded, blue),
                          _verticalDivider(),
                          _miniStat('RETURN', _dateTime(_booking.returnDateTime), Icons.logout_rounded, purple),
                          const Spacer(),
                          amount,
                        ],
                      ),
                  ],
                );
              },
            ),
            if (_verifiedAt != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.verified_rounded, size: 14, color: success),
                  const SizedBox(width: 6),
                  _text('Booking data verified ${DateFormat('hh:mm a').format(_verifiedAt!)}', size: 9.5, color: muted, weight: FontWeight.w800),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _lifecycle() {
    const statuses = [
      BookingStatus.pending,
      BookingStatus.confirmed,
      BookingStatus.pickupPending,
      BookingStatus.active,
      BookingStatus.returnPending,
      BookingStatus.completed,
    ];
    final current = _lifecycleIndex(_booking.status);

    return _card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (int i = 0; i < statuses.length; i++) ...[
              _lifecycleStep(statuses[i], i, current),
              if (i != statuses.length - 1)
                Container(width: 30, height: 1, color: border),
            ],
          ],
        ),
      ),
    );
  }

  Widget _lifecycleStep(BookingStatus status, int index, int current) {
    final active = index == current;
    final done = index < current;
    final color = active ? _statusColor(status) : done ? success : border;
    return SizedBox(
      width: 88,
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(active || done ? .11 : .55),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: active ? 2 : 1),
            ),
            child: Icon(done ? Icons.check_rounded : _statusIcon(status), size: 17, color: color),
          ),
          const SizedBox(height: 7),
          _text(_statusLabel(status), size: 8.8, color: active ? heading : muted, weight: active ? FontWeight.w900 : FontWeight.w700, align: TextAlign.center),
        ],
      ),
    );
  }

  Widget _inspectionActions() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Vehicle Inspection', 'View the same pickup and return evidence recorded by the rental team.', Icons.fact_check_rounded),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, c) {
              final compact = c.maxWidth < 650;
              final buttons = [
                _inspectionButton('View Pickup Inspection', Icons.fact_check_outlined, blue, 'pickup'),
                _inspectionButton('View Return Inspection', Icons.assignment_return_outlined, purple, 'return'),
              ];
              return compact
                  ? Column(children: [buttons[0], const SizedBox(height: 9), buttons[1]])
                  : Row(children: [Expanded(child: buttons[0]), const SizedBox(width: 10), Expanded(child: buttons[1])]);
            },
          ),
        ],
      ),
    );
  }

  Widget _inspectionButton(String label, IconData icon, Color color, String type) {
    return OutlinedButton.icon(
      onPressed: () => _showInspection(type),
      icon: Icon(icon, color: color),
      label: _text(label, size: 11, color: color, weight: FontWeight.w900),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        backgroundColor: color.withOpacity(.045),
        side: BorderSide(color: color.withOpacity(.25)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
    );
  }

  Future<void> _showInspection(String type) async {
    final raw = _inspectionData?[type == 'pickup' ? 'pickupInspection' : 'returnInspection'];
    final data = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};

    if (type == 'pickup' && data.isEmpty) {
      data['odometerStart'] = _inspectionData?['odometerStart'];
    }
    if (type == 'return' && data.isEmpty) {
      data['odometerStart'] = _inspectionData?['odometerStart'];
      data['odometerEnd'] = _inspectionData?['odometerEnd'];
      data['actualKm'] = _inspectionData?['actualKm'];
      data['includedKm'] = _inspectionData?['includedKm'];
      data['extraKm'] = _inspectionData?['extraKm'];
      data['extraKmCharge'] = _inspectionData?['extraKmCharge'];
      data['fuelCharge'] = _inspectionData?['fuelCharge'];
      data['damageCharge'] = _inspectionData?['damageCharge'];
      data['lateCharge'] = _inspectionData?['lateCharge'];
      data['otherCharge'] = _inspectionData?['otherCharge'];
      data['securityDepositAdjustment'] = _inspectionData?['securityDepositAdjustment'];
    }

    await showDialog<void>(
      context: context,
      builder: (_) => _CustomerInspectionDialog(
        title: type == 'pickup' ? 'Pickup Inspection' : 'Return Inspection',
        data: data,
        isPickup: type == 'pickup',
      ),
    );
  }

  Widget _vehicleCard() {
    final car = _booking.car;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Vehicle', 'Vehicle snapshot attached to your booking.', Icons.directions_car_filled_rounded),
          const SizedBox(height: 15),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _vehicleLargeImage(car?.image ?? ''),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _text(car?.name.isNotEmpty == true ? car!.name : 'Vehicle not available', size: 17, weight: FontWeight.w900),
                    const SizedBox(height: 4),
                    _text([
                      if (car?.type.isNotEmpty == true) car!.type,
                      if (car?.transmission.isNotEmpty == true) car!.transmission,
                      if (car?.fuel.isNotEmpty == true) car!.fuel,
                    ].join('  •  '), size: 10.5, color: muted, weight: FontWeight.w700),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        _smallTag('${car?.seats ?? 0} Seats', Icons.event_seat_rounded),
                        if (_booking.rentalType.isNotEmpty) _smallTag(_pretty(_booking.rentalType), Icons.schedule_rounded),
                        _smallTag(_booking.unlimitedKm ? 'Unlimited KM' : '${_booking.includedKm} KM Included', Icons.speed_rounded),
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

  Widget _customerCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Customer', 'Customer information attached to this booking.', Icons.person_rounded),
          const SizedBox(height: 15),
          Row(
            children: [
              _avatar(_booking.customerName),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _text(_booking.customerName.isEmpty ? 'Customer' : _booking.customerName, size: 16, weight: FontWeight.w900),
                    const SizedBox(height: 3),
                    _text(_booking.customerPhone.isEmpty ? 'Phone not available' : _booking.customerPhone, size: 10.5, color: muted, weight: FontWeight.w700),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: border, height: 1),
          const SizedBox(height: 12),
          _infoRow('Email', _booking.customerEmail.isEmpty ? '—' : _booking.customerEmail),
          _infoRow('Customer ID', _booking.customerId),
        ],
      ),
    );
  }

  Widget _scheduleCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Rental Schedule', 'Planned and actual timestamps.', Icons.calendar_month_rounded),
          const SizedBox(height: 14),
          _timelineRow('Pickup scheduled', _dateTime(_booking.pickupDateTime), Icons.login_rounded, blue),
          _timelineRow('Actual pickup', _booking.actualPickupDateTime == null ? 'Not recorded' : _dateTime(_booking.actualPickupDateTime!), Icons.key_rounded, _booking.actualPickupDateTime == null ? muted : success),
          _timelineRow('Return scheduled', _dateTime(_booking.returnDateTime), Icons.logout_rounded, purple),
          _timelineRow('Actual return', _booking.actualReturnDateTime == null ? 'Not recorded' : _dateTime(_booking.actualReturnDateTime!), Icons.assignment_return_rounded, _booking.actualReturnDateTime == null ? muted : success),
        ],
      ),
    );
  }

  Widget _pricingCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Pricing Breakdown', 'Full booking amount breakdown. Amounts are read-only on customer side.', Icons.receipt_long_rounded),
          const SizedBox(height: 14),
          _amountRow('Base rental', _booking.baseAmount),
          _amountRow('Extra KM', _booking.extraKmAmount),
          _amountRow('Extra time', _booking.extraTimeAmount),
          _amountRow('Add-ons', _booking.addOnsAmount),
          _amountRow('Protection', _booking.protectionAmount),
          _amountRow('Tax', _booking.taxAmount),
          _amountRow('Discount', -_booking.discountAmount, valueColor: success),
          _amountRow('Security deposit', _booking.securityDeposit),
          const Divider(color: border, height: 20),
          _amountRow('Total booking value', _booking.totalAmount, strong: true),
          if ((_booking.couponCode ?? '').trim().isNotEmpty) _infoRow('Coupon', _booking.couponCode ?? '', valueColor: success),
        ],
      ),
    );
  }

  Widget _paymentCard() {
    final total = _booking.totalAmount <= 0 ? 1.0 : _booking.totalAmount;
    final progress = (_booking.paidAmount / total).clamp(0.0, 1.0);
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Payment', 'Current payment and outstanding balance.', Icons.account_balance_wallet_rounded),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _text(_paymentLabel(_booking.paymentStatus), size: 14, weight: FontWeight.w900, color: _paymentColor(_booking.paymentStatus))),
              _text('${(progress * 100).round()}% paid', size: 10.5, color: muted, weight: FontWeight.w800),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: progress,
              backgroundColor: const Color(0xFFE9EDF3),
              valueColor: AlwaysStoppedAnimation<Color>(_booking.hasBalance ? warning : success),
            ),
          ),
          const SizedBox(height: 14),
          _amountRow('Total', _booking.totalAmount, strong: true),
          _amountRow('Paid', _booking.paidAmount, valueColor: success),
          _amountRow('Refund', _booking.refundAmount, valueColor: _booking.hasRefund ? warning : muted),
          _amountRow('Outstanding', _booking.balanceAmount, strong: true, valueColor: _booking.hasBalance ? danger : success),
          _infoRow('Payment method', _booking.paymentMethod ?? 'Not recorded'),
          _infoRow('Payment ID', _booking.paymentId ?? 'Not recorded'),
          _infoRow('Order ID', _booking.paymentOrderId ?? 'Not recorded'),
          _infoRow('Transaction ID', _booking.paymentTransactionId ?? 'Not recorded'),
        ],
      ),
    );
  }

  Widget _paymentLedgerCard() {
    final refundable = (_booking.paidAmount - _booking.refundAmount).clamp(0.0, double.infinity);
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Payment Ledger', 'Payment and refund transaction history.', Icons.receipt_long_rounded),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _amountRow('Paid', _booking.paidAmount, valueColor: success, strong: true)),
              const SizedBox(width: 12),
              Expanded(child: _amountRow('Refunded', _booking.refundAmount, valueColor: purple)),
              const SizedBox(width: 12),
              Expanded(child: _amountRow('Refundable', refundable, valueColor: refundable > 0 ? warning : muted)),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: border, height: 1),
          const SizedBox(height: 12),
          if (_payments.isEmpty)
            _text('No payment ledger entries recorded.', size: 11, color: muted, weight: FontWeight.w700)
          else
            ..._payments.map(_paymentTransactionTile),
        ],
      ),
    );
  }

  Widget _paymentTransactionTile(PaymentTransaction payment) {
    final refund = payment.isRefund;
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: (refund ? purple : success).withOpacity(.10), shape: BoxShape.circle),
            child: Icon(refund ? Icons.currency_exchange_rounded : Icons.payments_rounded, size: 18, color: refund ? purple : success),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _text(refund ? 'Refund' : 'Payment', size: 11, weight: FontWeight.w900),
                const SizedBox(height: 2),
                _text(_paymentMethod(payment.method), size: 9.5, color: muted, weight: FontWeight.w700),
                if (payment.paymentDate != null) _text(_dateTime(payment.paymentDate!), size: 9, color: muted),
              ],
            ),
          ),
          _text('${refund ? '-' : ''}${_money(payment.amount)}', size: 12, weight: FontWeight.w900, color: refund ? purple : success),
        ],
      ),
    );
  }

  Widget _inspectionSummaryCard() {
    final pickup = _map('pickupInspection');
    final returned = _map('returnInspection');
    final pickupPhotos = _list(pickup['photoUrls']);
    final returnPhotos = _list(returned['photoUrls']);
    final damagePhotos = _list(returned['damagePhotoUrls']);
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Inspection Summary', 'Evidence captured during pickup and return.', Icons.camera_alt_rounded),
          const SizedBox(height: 13),
          _summaryInspectionRow('Pickup', pickup.isNotEmpty ? 'Recorded' : 'Not recorded', pickupPhotos.length, blue),
          const SizedBox(height: 9),
          _summaryInspectionRow('Return', returned.isNotEmpty ? 'Recorded' : 'Not recorded', returnPhotos.length, purple),
          const SizedBox(height: 9),
          _summaryInspectionRow('Damage photos', '${damagePhotos.length} photos', damagePhotos.length, danger),
        ],
      ),
    );
  }

  Widget _summaryInspectionRow(String title, String value, int photos, Color color) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(color: color.withOpacity(.045), borderRadius: BorderRadius.circular(13), border: Border.all(color: color.withOpacity(.13))),
      child: Row(
        children: [
          Icon(Icons.photo_library_outlined, size: 18, color: color),
          const SizedBox(width: 9),
          Expanded(child: _text(title, size: 10.5, weight: FontWeight.w900)),
          _text(value, size: 9.5, color: muted, weight: FontWeight.w800),
        ],
      ),
    );
  }

  Widget _bookingSummaryCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Booking Summary', 'Important booking information.', Icons.info_outline_rounded),
          const SizedBox(height: 13),
          _infoRow('Booking ID', _booking.bookingId),
          _infoRow('Rental type', _pretty(_booking.rentalType)),
          _infoRow('KM package', _booking.unlimitedKm ? 'Unlimited KM' : '${_booking.includedKm} KM included'),
          _infoRow('Extra KM rate', _money(_booking.extraKmRate)),
          _infoRow('Created', _booking.createdAt == null ? '—' : _dateTime(_booking.createdAt!)),
          _infoRow('Last updated', _booking.updatedAt == null ? '—' : _dateTime(_booking.updatedAt!)),
        ],
      ),
    );
  }

  Widget _branchCard() {
    final pickup = _booking.pickupBranch;
    final drop = _booking.returnBranch;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Branches', 'Pickup and return locations.', Icons.location_on_rounded),
          const SizedBox(height: 14),
          _branch('Pickup', pickup?.name ?? 'Branch not available', pickup?.city ?? '', pickup?.address ?? '', pickup?.phone ?? '', blue, Icons.login_rounded),
          const SizedBox(height: 12),
          _branch('Return', drop?.name ?? 'Branch not available', drop?.city ?? '', drop?.address ?? '', drop?.phone ?? '', purple, Icons.logout_rounded),
        ],
      ),
    );
  }

  Widget _notesCard() {
    final note = _booking.customerNote.trim();
    final cancellation = _booking.cancellationReason.trim();
    final rejection = _booking.rejectionReason.trim();
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Booking Notes', 'Notes and workflow information.', Icons.notes_rounded),
          const SizedBox(height: 13),
          if (note.isNotEmpty) _noteBlock('Customer note', note, blue),
          if (cancellation.isNotEmpty) _noteBlock('Cancellation reason', cancellation, danger),
          if (rejection.isNotEmpty) _noteBlock('Rejection reason', rejection, danger),
          if (note.isEmpty && cancellation.isEmpty && rejection.isEmpty) _text('No booking notes recorded.', size: 11, color: muted, weight: FontWeight.w700),
        ],
      ),
    );
  }

  Widget _card({required Widget child, EdgeInsetsGeometry padding = const EdgeInsets.all(18)}) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: const [BoxShadow(color: Color(0x0718212F), blurRadius: 18, offset: Offset(0, 6))],
      ),
      child: child,
    );
  }

  Widget _sectionTitle(String title, String subtitle, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: primary.withOpacity(.08), borderRadius: BorderRadius.circular(11)), child: Icon(icon, size: 18, color: primary)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_text(title, size: 14, weight: FontWeight.w900), const SizedBox(height: 2), _text(subtitle, size: 9.5, color: muted, weight: FontWeight.w700)])),
      ],
    );
  }

  Widget _amountRow(String label, double value, {Color? valueColor, bool strong = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: _text(label, size: strong ? 11.5 : 10.5, color: strong ? heading : body, weight: strong ? FontWeight.w900 : FontWeight.w700)),
          _text(_money(value), size: strong ? 12.5 : 10.5, color: valueColor ?? heading, weight: FontWeight.w900),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 112, child: _text(label, size: 9.5, color: muted, weight: FontWeight.w700)),
          Expanded(child: _text(value, size: 10, color: valueColor ?? body, weight: FontWeight.w800, align: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _timelineRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(width: 32, height: 32, decoration: BoxDecoration(color: color.withOpacity(.08), shape: BoxShape.circle), child: Icon(icon, size: 16, color: color)),
          const SizedBox(width: 10),
          Expanded(child: _text(label, size: 10.5, color: muted, weight: FontWeight.w700)),
          _text(value, size: 10.5, weight: FontWeight.w900),
        ],
      ),
    );
  }

  Widget _branch(String label, String name, String city, String address, String phone, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(15), border: Border.all(color: border)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withOpacity(.08), shape: BoxShape.circle), child: Icon(icon, size: 18, color: color)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_text(label.toUpperCase(), size: 8, color: color, weight: FontWeight.w900, letterSpacing: .8), const SizedBox(height: 3), _text(name, size: 11.5, weight: FontWeight.w900), if (city.isNotEmpty) _text(city, size: 9.5, color: body, weight: FontWeight.w700), if (address.isNotEmpty) _text(address, size: 9.5, color: muted, weight: FontWeight.w600), if (phone.isNotEmpty) _text(phone, size: 9.5, color: primary, weight: FontWeight.w800)])),
        ],
      ),
    );
  }

  Widget _noteBlock(String title, String value, Color color) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withOpacity(.05), borderRadius: BorderRadius.circular(13), border: Border.all(color: color.withOpacity(.13))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_text(title, size: 9, color: color, weight: FontWeight.w900), const SizedBox(height: 5), _text(value, size: 10.5, color: body, weight: FontWeight.w700, height: 1.4)]),
    );
  }

  Widget _miniStat(String label, String value, IconData icon, Color color) {
    return Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 30, height: 30, decoration: BoxDecoration(color: color.withOpacity(.08), borderRadius: BorderRadius.circular(9)), child: Icon(icon, size: 15, color: color)), const SizedBox(width: 8), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_text(label, size: 7.5, color: color, weight: FontWeight.w900, letterSpacing: .8), _text(value, size: 9.5, weight: FontWeight.w800)])]);
  }

  Widget _verticalDivider() => Container(width: 1, height: 35, margin: const EdgeInsets.symmetric(horizontal: 14), color: border);

  Widget _pill(String label, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(.08), borderRadius: BorderRadius.circular(9), border: Border.all(color: color.withOpacity(.16))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 5)], _text(label, size: 8.5, color: color, weight: FontWeight.w900)]),
    );
  }

  Widget _smallTag(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(9), border: Border.all(color: border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 12, color: muted), const SizedBox(width: 4), _text(label, size: 8.5, color: body, weight: FontWeight.w800)]),
    );
  }

  Widget _avatar(String name) {
    final letter = name.trim().isEmpty ? 'C' : name.trim()[0].toUpperCase();
    return Container(width: 46, height: 46, decoration: BoxDecoration(color: primary.withOpacity(.09), shape: BoxShape.circle), alignment: Alignment.center, child: _text(letter, size: 18, color: primary, weight: FontWeight.w900));
  }

  Widget _vehicleAvatar() {
    final image = _booking.car?.image ?? '';
    return ClipRRect(borderRadius: BorderRadius.circular(15), child: SizedBox(width: 72, height: 64, child: image.isEmpty ? Container(color: background, child: const Icon(Icons.directions_car_filled_rounded, color: muted, size: 29)) : Image.network(image, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: background, child: const Icon(Icons.directions_car_filled_rounded, color: muted, size: 29)))));
  }

  Widget _vehicleLargeImage(String image) {
    return ClipRRect(borderRadius: BorderRadius.circular(15), child: SizedBox(width: 112, height: 88, child: image.isEmpty ? Container(color: background, child: const Icon(Icons.directions_car_filled_rounded, color: muted, size: 34)) : Image.network(image, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: background, child: const Icon(Icons.directions_car_filled_rounded, color: muted, size: 34)))));
  }

  Widget _text(String value, {double size = 12, Color color = heading, FontWeight weight = FontWeight.w700, TextAlign align = TextAlign.left, double height = 1.2, double letterSpacing = 0}) {
    return Text(value, textAlign: align, style: TextStyle(fontFamily: 'Manrope', fontSize: size, fontWeight: weight, color: color, height: height, letterSpacing: letterSpacing));
  }

  String _money(double value) => '₹${NumberFormat('#,##0.00').format(value)}';

  String _dateTime(DateTime value) => DateFormat('dd MMM yyyy, hh:mm a').format(value.toLocal());

  String _pretty(String value) {
    final words = value.replaceAll('_', ' ').split(' ').where((e) => e.isNotEmpty).toList();
    return words.map((word) => '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}').join(' ');
  }

  Map<String, dynamic> _map(dynamic raw) => raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};

  List<String> _list(dynamic raw) {
    if (raw is Iterable) return raw.map((e) => e?.toString().trim() ?? '').where((e) => e.isNotEmpty).toList();
    return const [];
  }

  int _lifecycleIndex(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending: return 0;
      case BookingStatus.confirmed: return 1;
      case BookingStatus.pickupPending: return 2;
      case BookingStatus.active: return 3;
      case BookingStatus.returnPending: return 4;
      case BookingStatus.completed: return 5;
      case BookingStatus.cancelled:
      case BookingStatus.rejected:
      case BookingStatus.noShow: return 1;
    }
  }

  String _statusLabel(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending: return 'Pending';
      case BookingStatus.confirmed: return 'Confirmed';
      case BookingStatus.pickupPending: return 'Pickup Pending';
      case BookingStatus.active: return 'Active';
      case BookingStatus.returnPending: return 'Return Pending';
      case BookingStatus.completed: return 'Completed';
      case BookingStatus.cancelled: return 'Cancelled';
      case BookingStatus.rejected: return 'Rejected';
      case BookingStatus.noShow: return 'No Show';
    }
  }

  IconData _statusIcon(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending: return Icons.hourglass_top_rounded;
      case BookingStatus.confirmed: return Icons.check_circle_outline_rounded;
      case BookingStatus.pickupPending: return Icons.key_rounded;
      case BookingStatus.active: return Icons.directions_car_filled_rounded;
      case BookingStatus.returnPending: return Icons.assignment_return_rounded;
      case BookingStatus.completed: return Icons.task_alt_rounded;
      case BookingStatus.cancelled: return Icons.cancel_outlined;
      case BookingStatus.rejected: return Icons.block_rounded;
      case BookingStatus.noShow: return Icons.person_off_rounded;
    }
  }

  Color _statusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
      case BookingStatus.pickupPending: return warning;
      case BookingStatus.confirmed: return primary;
      case BookingStatus.active:
      case BookingStatus.completed: return success;
      case BookingStatus.returnPending: return purple;
      case BookingStatus.cancelled:
      case BookingStatus.rejected:
      case BookingStatus.noShow: return danger;
    }
  }

  String _paymentLabel(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.pending: return 'Payment Pending';
      case PaymentStatus.partiallyPaid: return 'Partially Paid';
      case PaymentStatus.paid: return 'Paid';
      case PaymentStatus.failed: return 'Payment Failed';
      case PaymentStatus.refunded: return 'Refunded';
      case PaymentStatus.partiallyRefunded: return 'Partially Refunded';
    }
  }

  Color _paymentColor(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.pending:
      case PaymentStatus.partiallyPaid: return warning;
      case PaymentStatus.paid: return success;
      case PaymentStatus.failed: return danger;
      case PaymentStatus.refunded:
      case PaymentStatus.partiallyRefunded: return purple;
    }
  }

  String _paymentMethod(PaymentMethodType method) {
    switch (method) {
      case PaymentMethodType.razorpay: return 'Razorpay';
      case PaymentMethodType.cash: return 'Cash';
      case PaymentMethodType.upi: return 'UPI';
      case PaymentMethodType.card: return 'Card';
      case PaymentMethodType.bankTransfer: return 'Bank Transfer';
      case PaymentMethodType.other: return 'Other';
    }
  }
}

class _CustomerInspectionDialog extends StatelessWidget {
  const _CustomerInspectionDialog({required this.title, required this.data, required this.isPickup});

  final String title;
  final Map<String, dynamic> data;
  final bool isPickup;

  static const Color background = Color(0xFFF6F8FB);
  static const Color heading = Color(0xFF18212F);
  static const Color body = Color(0xFF425066);
  static const Color muted = Color(0xFF758195);
  static const Color border = Color(0xFFE7EBF1);
  static const Color primary = Color(0xFF315CF6);
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color purple = Color(0xFF8B5CF6);

  String _value(String key, [String fallback = '—']) {
    final value = data[key];
    if (value == null || value.toString().trim().isEmpty) return fallback;
    return value.toString();
  }

  List<String> _list(String key) {
    final raw = data[key];
    if (raw is Iterable) return raw.map((e) => e?.toString().trim() ?? '').where((e) => e.isNotEmpty).toList();
    return const [];
  }

  double _number(String key) {
    final raw = data[key];
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw?.toString() ?? '') ?? 0;
  }

  String _money(double value) => '₹${value.toStringAsFixed(2)}';

  String _inspectedAt() {
    final raw = data['inspectedAt'] ?? data['completedAt'];
    if (raw == null) return '—';
    DateTime? date;
    if (raw is Timestamp) date = raw.toDate();
    if (raw is DateTime) date = raw;
    if (date == null) date = DateTime.tryParse(raw.toString());
    return date == null ? raw.toString() : DateFormat('dd MMM yyyy, hh:mm a').format(date.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final photos = _list('photoUrls');
    final damagePhotos = _list('damagePhotoUrls');
    final damages = _list('damagesFound').isNotEmpty ? _list('damagesFound') : _list('existingDamage');
    final additional = _number('extraKmCharge') + _number('fuelCharge') + _number('damageCharge') + _number('lateCharge') + _number('otherCharge');
    final starting = _value('startingOdometer', _value('odometerStart'));
    final ending = _value('endingOdometer', _value('odometerEnd'));

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980, maxHeight: 900),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 10, 16),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: border))),
                child: Row(
                  children: [
                    Container(width: 38, height: 38, decoration: BoxDecoration(color: (isPickup ? primary : purple).withOpacity(.09), borderRadius: BorderRadius.circular(11)), child: Icon(isPickup ? Icons.fact_check_rounded : Icons.assignment_return_rounded, color: isPickup ? primary : purple, size: 19)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_text(title, size: 15, weight: FontWeight.w900), _text(isPickup ? 'Pickup vehicle condition and handover evidence' : 'Return vehicle condition and final inspection evidence', size: 9.5, color: muted, weight: FontWeight.w700)])),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: body)),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _detailGrid([
                        _detail('Starting odometer', starting),
                        if (!isPickup || ending != '—') _detail('Ending odometer', ending),
                        if (!isPickup) _detail('Actual KM', _value('actualKm')),
                        _detail('Included KM', _value('includedKm')),
                        if (!isPickup) _detail('Extra KM', _value('extraKm')),
                        _detail('Fuel level', _value('fuelLevel')),
                        _detail('Inspected by', _value('inspectedByName', _value('inspectedBy'))),
                        _detail('Inspected at', _inspectedAt()),
                      ]),
                      const SizedBox(height: 16),
                      _evidenceSection(context, 'Vehicle Photos', 'Photos recorded during the inspection.', photos, isPickup ? primary : purple),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(15), border: Border.all(color: border)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [Icon(Icons.warning_amber_rounded, color: damagePhotos.isNotEmpty || damages.isNotEmpty ? danger : muted, size: 19), const SizedBox(width: 8), _text('Damage / existing-condition evidence', size: 12, weight: FontWeight.w900)]),
                          if (damages.isNotEmpty) ...[
                            const SizedBox(height: 11),
                            Wrap(spacing: 7, runSpacing: 7, children: damages.map((item) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6), decoration: BoxDecoration(color: danger.withOpacity(.07), borderRadius: BorderRadius.circular(9), border: Border.all(color: danger.withOpacity(.14))), child: _text(item, size: 9, color: danger, weight: FontWeight.w800))).toList()),
                          ],
                          const SizedBox(height: 11),
                          _gallery(context, damagePhotos, 'Damage Photos'),
                        ]),
                      ),
                      if (!isPickup) ...[
                        const SizedBox(height: 16),
                        _detailGrid([
                          _detail('Extra KM charge', _money(_number('extraKmCharge'))),
                          _detail('Fuel charge', _money(_number('fuelCharge'))),
                          _detail('Damage charge', _money(_number('damageCharge'))),
                          _detail('Late charge', _money(_number('lateCharge'))),
                          _detail('Other charge', _money(_number('otherCharge'))),
                          _detail('Additional charges', _money(additional)),
                          _detail('Security deposit adjustment', _money(_number('securityDepositAdjustment')), valueColor: purple),
                        ]),
                      ],
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(15), border: Border.all(color: border)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          _text('Inspection notes', size: 9, color: muted, weight: FontWeight.w900),
                          const SizedBox(height: 5),
                          _text(_value('notes', 'No notes recorded.'), size: 10.5, color: body, weight: FontWeight.w700, height: 1.4),
                          const SizedBox(height: 12),
                          _text('Customer acknowledgement', size: 9, color: muted, weight: FontWeight.w900),
                          const SizedBox(height: 5),
                          _text(_value('customerAcknowledgement', 'Not recorded.'), size: 10.5, color: body, weight: FontWeight.w700, height: 1.4),
                        ]),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _evidenceSection(BuildContext context, String title, String subtitle, List<String> photos, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(15), border: Border.all(color: border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(Icons.photo_library_rounded, color: color, size: 19), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_text(title, size: 12, weight: FontWeight.w900), _text(subtitle, size: 9, color: muted, weight: FontWeight.w700)]))]),
        const SizedBox(height: 11),
        _gallery(context, photos, title),
      ]),
    );
  }

  Widget _gallery(BuildContext context, List<String> photos, String title) {
    if (photos.isEmpty) {
      return Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: border)), child: _text('No $title recorded.', size: 10, color: muted, weight: FontWeight.w700, align: TextAlign.center));
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: photos.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1.15),
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () => showDialog<void>(context: context, builder: (_) => _FullscreenImageViewer(images: photos, initialIndex: index, title: title)),
          child: ClipRRect(borderRadius: BorderRadius.circular(11), child: Stack(fit: StackFit.expand, children: [Image.network(photos[index], fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: background, child: const Icon(Icons.broken_image_outlined, color: muted))), Positioned(right: 6, bottom: 6, child: Container(width: 26, height: 26, decoration: BoxDecoration(color: Colors.black.withOpacity(.45), shape: BoxShape.circle), child: const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 15))) ])),
        );
      },
    );
  }

  Widget _detailGrid(List<_CustomerDetail> details) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 560 ? 1 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: details.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, mainAxisExtent: 58, crossAxisSpacing: 10, mainAxisSpacing: 10),
          itemBuilder: (_, i) => Container(padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12), border: Border.all(color: border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_text(details[i].label, size: 8.5, color: muted, weight: FontWeight.w800), const SizedBox(height: 4), _text(details[i].value, size: 10.5, color: details[i].valueColor ?? heading, weight: FontWeight.w900)])),
        );
      },
    );
  }

  static _CustomerDetail _detail(String label, String value, {Color? valueColor}) => _CustomerDetail(label, value, valueColor);

  Widget _text(String value, {double size = 12, Color color = heading, FontWeight weight = FontWeight.w700, TextAlign align = TextAlign.left, double height = 1.2}) {
    return Text(value, textAlign: align, style: TextStyle(fontFamily: 'Manrope', fontSize: size, fontWeight: weight, color: color, height: height));
  }
}

class _CustomerDetail {
  const _CustomerDetail(this.label, this.value, this.valueColor);
  final String label;
  final String value;
  final Color? valueColor;
}

class _FullscreenImageViewer extends StatefulWidget {
  const _FullscreenImageViewer({required this.images, required this.initialIndex, required this.title});
  final List<String> images;
  final int initialIndex;
  final String title;

  @override
  State<_FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<_FullscreenImageViewer> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.images.length,
            onPageChanged: (index) => setState(() => _index = index),
            itemBuilder: (_, index) => InteractiveViewer(minScale: .7, maxScale: 4, child: Center(child: Image.network(widget.images[index], fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Colors.white, size: 60)))),
          ),
          Positioned(top: 18, left: 18, child: SafeArea(child: Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7), decoration: BoxDecoration(color: Colors.black.withOpacity(.5), borderRadius: BorderRadius.circular(10)), child: Text('${widget.title}  ${_index + 1}/${widget.images.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11))))),
          Positioned(top: 12, right: 12, child: SafeArea(child: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28)))),
        ],
      ),
    );
  }
}
