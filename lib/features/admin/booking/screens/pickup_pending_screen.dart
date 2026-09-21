import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/app_config.dart';
import '../../../booking/models/booking.dart';
import '../../../booking/services/booking_service.dart';
import '../../../customer/models/customer.dart';
import '../../../customer/services/customer_service.dart';

/// Premium operational Pickup Pending screen.
///
/// Flow:
/// CONFIRMED -> PICKUP PENDING -> physical handover -> ACTIVE
///
/// This screen deliberately does NOT automate the physical handover.
/// The final handover is revalidated and recorded through BookingService.
class PickupPendingScreen extends StatefulWidget {
  const PickupPendingScreen({super.key});

  @override
  State<PickupPendingScreen> createState() => _PickupPendingScreenState();
}

class _PickupPendingScreenState extends State<PickupPendingScreen> {
  static const background = Color(0xFFF6F8F7);
  static const card = Colors.white;
  static const primary = Color(0xFF0F766E);
  static const warning = Color(0xFFB45309);
  static const success = Color(0xFF15803D);
  static const danger = Color(0xFFB91C1C);
  static const heading = Color(0xFF17201F);
  static const body = Color(0xFF66706E);
  static const muted = Color(0xFF94A09D);
  static const border = Color(0xFFE3E9E7);

  final BookingService _service = BookingService.instance;
  final CustomerService _customerService = CustomerService.instance;

  String get _tenantId => AppConfig.tenant.tenantId;

  List<Booking> _bookings = <Booking>[];
  bool _loading = true;
  bool _working = false;
  String _search = '';
  String _sort = 'pickup';
  DateTime? _lastVerifiedAt;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    final generation = ++_loadGeneration;
    if (!mounted) return;
    setState(() {
      if (!refresh) _loading = true;
      _working = refresh;
    });

    try {
      if (_tenantId.trim().isEmpty) throw Exception('Tenant configuration is missing.');
      final all = await _service.getAllBookingsForAdmin(tenantId: _tenantId);
      final list = all.where((b) => b.status == BookingStatus.pickupPending).toList();
      _sortList(list);

      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _bookings = list;
        _lastVerifiedAt = DateTime.now();
        _loading = false;
        _working = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _working = false;
      });
      _message(_cleanError(e), error: true);
    }
  }

  void _sortList(List<Booking> list) {
    if (_sort == 'pickup') {
      list.sort((a, b) => a.pickupDateTime.compareTo(b.pickupDateTime));
    } else if (_sort == 'overdue') {
      list.sort((a, b) => _overdueScore(b).compareTo(_overdueScore(a)));
    } else {
      list.sort((a, b) => (b.updatedAt ?? b.pickupDateTime).compareTo(a.updatedAt ?? a.pickupDateTime));
    }
  }

  int _overdueScore(Booking b) {
    final now = DateTime.now();
    if (!now.isAfter(b.pickupDateTime)) return 0;
    return now.difference(b.pickupDateTime).inMinutes;
  }

  List<Booking> get _filtered {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return _bookings;
    return _bookings.where((b) {
      return b.bookingId.toLowerCase().contains(q) ||
          b.customerName.toLowerCase().contains(q) ||
          b.customerPhone.toLowerCase().contains(q) ||
          b.customerEmail.toLowerCase().contains(q) ||
          b.carId.toLowerCase().contains(q) ||
          (b.car?.name ?? '').toLowerCase().contains(q) ||
          (b.car?.registrationNumber ?? '').toLowerCase().contains(q) ||
          b.pickupBranchId.toLowerCase().contains(q);
    }).toList();
  }

  int get _dueToday => _bookings.where((b) {
        final n = DateTime.now();
        return b.pickupDateTime.year == n.year &&
            b.pickupDateTime.month == n.month &&
            b.pickupDateTime.day == n.day;
      }).length;

  int get _overdue => _bookings.where((b) => DateTime.now().isAfter(b.pickupDateTime)).length;

  double get _pendingAmount => _bookings.fold<double>(0, (sum, b) => sum + (b.totalAmount - b.paidAmount));

  Future<Booking> _revalidate(Booking booking) async {
    final fresh = await _service.getBookingForAdmin(
      tenantId: _tenantId,
      bookingId: booking.bookingId,
    );
    if (fresh == null) throw Exception('Booking no longer exists.');
    if (fresh.tenantId.isNotEmpty && fresh.tenantId != _tenantId) {
      throw Exception('Booking does not belong to the active tenant.');
    }
    if (!mounted) return fresh;
    setState(() => _lastVerifiedAt = DateTime.now());
    return fresh;
  }

  Future<void> _openHandover(Booking booking) async {
    if (_working) return;

    Booking fresh;
    try {
      fresh = await _revalidate(booking);
    } catch (e) {
      _message(_cleanError(e), error: true);
      await _load(refresh: true);
      return;
    }

    if (fresh.status != BookingStatus.pickupPending) {
      _message('This booking changed state. Refreshing the list.', error: true);
      await _load(refresh: true);
      return;
    }

    if (DateTime.now().isBefore(fresh.pickupDateTime)) {
      _message('Pickup is not due yet.', error: true);
      return;
    }

    final customer = await _customerService.getCustomer(
      tenantId: _tenantId,
      customerId: fresh.customerId,
    );
    if (customer == null) {
      _message('Customer record could not be verified. Physical handover is blocked.', error: true);
      return;
    }
    if (customer.kycStatus.trim().toLowerCase() != 'verified') {
      _message('Customer KYC must be verified before physical handover.', error: true);
      return;
    }

    final result = await showDialog<PickupHandoverResult>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (_) => PickupHandoverDialog(booking: fresh),
    );
    if (result == null || !mounted) return;

    setState(() => _working = true);
    try {
      final latest = await _revalidate(fresh);
      if (latest.status != BookingStatus.pickupPending) {
        throw Exception('Booking has already changed state. Refresh the list.');
      }
      if (DateTime.now().isBefore(latest.pickupDateTime)) {
        throw Exception('Pickup is not due yet.');
      }

      await _service.recordPickupHandoverForAdmin(
        tenantId: _tenantId,
        bookingId: latest.bookingId,
        startingOdometer: result.startingOdometer,
        photoUrls: result.photoUrls,
        damagePhotoUrls: result.damagePhotoUrls,
        existingDamage: result.existingDamage,
        fuelLevel: result.fuelLevel,
        notes: result.notes,
        customerAcknowledgement: result.customerAcknowledgement,
      );

      if (!mounted) return;
      _message('Vehicle handover recorded. Booking is now Active.');
      await _load(refresh: true);
    } catch (e) {
      if (!mounted) return;
      _message(_cleanError(e), error: true);
      await _load(refresh: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _cancel(Booking booking) async {
    final reason = await _reasonDialog('Cancel booking', 'Enter the cancellation reason.');
    if (reason == null || !mounted) return;

    try {
      setState(() => _working = true);
      final latest = await _revalidate(booking);
      if (latest.status != BookingStatus.pickupPending) {
        throw Exception('Booking changed state. Refresh the list.');
      }
      await _service.cancelBookingForAdmin(
        tenantId: _tenantId,
        bookingId: booking.bookingId,
        reason: reason,
      );
      if (!mounted) return;
      _message('Booking cancelled.');
      await _load(refresh: true);
    } catch (e) {
      if (mounted) _message(_cleanError(e), error: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _noShow(Booking booking) async {
    if (!await _confirm('Mark no-show?', 'Use this only when your no-show policy allows it.')) return;
    try {
      setState(() => _working = true);
      final latest = await _revalidate(booking);
      if (latest.status != BookingStatus.pickupPending) {
        throw Exception('Booking changed state. Refresh the list.');
      }
      await _service.updateBookingStatusForAdmin(
        tenantId: _tenantId,
        bookingId: latest.bookingId,
        status: BookingStatus.noShow,
      );
      if (!mounted) return;
      _message('Booking marked as no-show.');
      await _load(refresh: true);
    } catch (e) {
      if (mounted) _message(_cleanError(e), error: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<bool> _confirm(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(title, style: GoogleFonts.manrope(fontWeight: FontWeight.w900, color: heading)),
        content: Text(message, style: GoogleFonts.manrope(color: body, height: 1.45)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context, rootNavigator: true).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: primary, elevation: 0),
            child: const Text('Continue', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<String?> _reasonDialog(String title, String hint) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (_) => _ReasonDialog(title: title, hint: hint, controller: controller),
    );
    controller.dispose();
    return result;
  }

  void _message(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        backgroundColor: error ? danger : primary,
        content: Text(text),
      ));
  }

  String _cleanError(Object error) => error.toString().replaceFirst('Exception: ', '').trim();

  String _date(DateTime value) => DateFormat('dd MMM yyyy').format(value);
  String _time(DateTime value) => DateFormat('hh:mm a').format(value);
  String _money(double value) => '₹${value.toStringAsFixed(0)}';

  Color _paymentColor(Booking b) {
    switch (b.paymentStatus) {
      case PaymentStatus.paid:
        return success;
      case PaymentStatus.partiallyPaid:
        return warning;
      default:
        return danger;
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Pickup Pending', style: GoogleFonts.manrope(fontSize: 19, fontWeight: FontWeight.w900, color: heading)),
          Text('${_bookings.length} awaiting handover • ${_lastVerifiedAt == null ? 'Not verified' : 'Verified ' + DateFormat('hh:mm a').format(_lastVerifiedAt!)}', style: GoogleFonts.manrope(fontSize: 9.5, color: muted, fontWeight: FontWeight.w700)),
        ]),
        actions: [
          if (_working) const Padding(padding: EdgeInsets.all(18), child: SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2)))
          else IconButton(onPressed: () => _load(refresh: true), icon: const Icon(Icons.refresh_rounded)),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: primary,
        onRefresh: () => _load(refresh: true),
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: primary))
            : CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _dashboard()),
                  SliverToBoxAdapter(child: _filters()),
                  if (list.isEmpty)
                    const SliverFillRemaining(hasScrollBody: false, child: _EmptyState(title: 'No pickup pending bookings', subtitle: 'All scheduled vehicle handovers are currently clear.'))
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
                      sliver: SliverList.builder(
                        itemCount: list.length,
                        itemBuilder: (_, i) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _bookingCard(list[i])),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _dashboard() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: LayoutBuilder(builder: (_, c) {
          final values = [
            ('Pending', _bookings.length, Icons.key_rounded, warning),
            ('Today', _dueToday, Icons.today_rounded, primary),
            ('Overdue', _overdue, Icons.warning_amber_rounded, danger),
            ('Balance', _money(_pendingAmount), Icons.payments_rounded, success),
          ];
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: values.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: c.maxWidth > 850 ? 4 : 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: c.maxWidth > 850 ? 2.4 : 2.1,
            ),
            itemBuilder: (_, i) {
              final v = values[i];
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(17), border: Border.all(color: border)),
                child: Row(children: [
                  Icon(v.$3 as IconData, color: v.$4 as Color, size: 19),
                  const SizedBox(width: 9),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('${v.$2}', style: GoogleFonts.manrope(fontSize: 17, fontWeight: FontWeight.w900, color: heading)),
                    Text(v.$1 as String, style: GoogleFonts.manrope(fontSize: 8.5, fontWeight: FontWeight.w800, color: muted)),
                  ])),
                ]),
              );
            },
          );
        }),
      );

  Widget _filters() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Row(children: [
          Expanded(child: TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'Search booking, customer, phone, vehicle...',
              hintStyle: GoogleFonts.manrope(fontSize: 10, color: muted),
              prefixIcon: const Icon(Icons.search_rounded, color: muted),
              filled: true,
              fillColor: card,
              border: _outline(),
              enabledBorder: _outline(),
              focusedBorder: _outline(primary),
            ),
          )),
          const SizedBox(width: 8),
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(15), border: Border.all(color: border)),
            child: DropdownButtonHideUnderline(child: DropdownButton<String>(
              value: _sort,
              items: const [
                DropdownMenuItem(value: 'pickup', child: Text('Pickup time')),
                DropdownMenuItem(value: 'overdue', child: Text('Overdue first')),
                DropdownMenuItem(value: 'updated', child: Text('Recently updated')),
              ],
              onChanged: (v) { if (v == null) return; setState(() { _sort = v; _sortList(_bookings); }); },
            )),
          ),
        ]),
      );

  OutlineInputBorder _outline([Color? color]) => OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: color ?? border));

  Widget _bookingCard(Booking b) {
    final overdue = DateTime.now().isAfter(b.pickupDateTime);
    final balance = b.totalAmount - b.paidAmount;
    final vehicle = b.car?.name.isNotEmpty == true ? b.car!.name : b.carId;
    final reg = b.car?.registrationNumber ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(21), border: Border.all(color: border)),
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 58, height: 58, decoration: BoxDecoration(color: const Color(0xFFE6FFFB), borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.directions_car_filled_rounded, color: primary, size: 28)),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(vehicle, style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w900, color: heading)),
            const SizedBox(height: 3),
            Text(reg.isEmpty ? b.carId : reg, style: GoogleFonts.manrope(fontSize: 9, fontWeight: FontWeight.w800, color: muted)),
            const SizedBox(height: 5),
            Text(b.customerName.isEmpty ? 'Customer' : b.customerName, style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w800, color: body)),
            Text(b.customerPhone, style: GoogleFonts.manrope(fontSize: 9, color: muted)),
          ])),
          _badge(overdue ? 'OVERDUE' : 'PICKUP PENDING', overdue ? danger : warning),
        ]),
        const SizedBox(height: 12),
        Container(padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)), child: Row(children: [
          Expanded(child: _mini('PICKUP', '${_date(b.pickupDateTime)}\n${_time(b.pickupDateTime)}', Icons.login_rounded, overdue ? danger : primary)),
          Container(width: 1, height: 42, color: border),
          Expanded(child: _mini('RETURN', '${_date(b.returnDateTime)}\n${_time(b.returnDateTime)}', Icons.logout_rounded, body)),
          Container(width: 1, height: 42, color: border),
          Expanded(child: _mini('PAYMENT', balance <= 0 ? 'Paid' : '${_money(balance)} due', Icons.payments_rounded, _paymentColor(b))),
        ])),
        const SizedBox(height: 11),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: () => _details(b), icon: const Icon(Icons.visibility_outlined, size: 15), label: const Text('Details'))),
          const SizedBox(width: 7),
          Expanded(flex: 2, child: ElevatedButton.icon(onPressed: _working ? null : () => _openHandover(b), icon: const Icon(Icons.key_rounded, size: 16), label: const Text('Start Handover'), style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white, elevation: 0))),
          const SizedBox(width: 7),
          PopupMenuButton<String>(onSelected: (v) { if (v == 'cancel') _cancel(b); if (v == 'noshow') _noShow(b); }, itemBuilder: (_) => const [PopupMenuItem(value: 'cancel', child: Text('Cancel booking')), PopupMenuItem(value: 'noshow', child: Text('Mark no-show'))], child: Container(width: 43, height: 42, alignment: Alignment.center, decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12), border: Border.all(color: border)), child: const Icon(Icons.more_horiz_rounded, color: body)),),
        ]),
      ]),
    );
  }

  Widget _mini(String title, String value, IconData icon, Color color) => Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon, size: 12, color: color), const SizedBox(width: 4), Text(title, style: GoogleFonts.manrope(fontSize: 7, fontWeight: FontWeight.w900, color: muted))]), const SizedBox(height: 4), Text(value, style: GoogleFonts.manrope(fontSize: 8.5, height: 1.35, fontWeight: FontWeight.w800, color: heading))]));

  Widget _badge(String text, Color color) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), decoration: BoxDecoration(color: color.withOpacity(.09), borderRadius: BorderRadius.circular(9)), child: Text(text, style: GoogleFonts.manrope(fontSize: 7.5, fontWeight: FontWeight.w900, color: color)));

  Future<void> _details(Booking b) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BookingPreviewSheet(booking: b, date: _date, time: _time, money: _money, onClose: () => Navigator.of(context).pop()),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  const _EmptyState({required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(30), child: Column(mainAxisSize: MainAxisSize.min, children: [Container(width: 64, height: 64, decoration: BoxDecoration(color: const Color(0xFFE6FFFB), borderRadius: BorderRadius.circular(20)), child: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF0F766E), size: 30)), const SizedBox(height: 14), Text(title, style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w900)), const SizedBox(height: 5), Text(subtitle, textAlign: TextAlign.center, style: GoogleFonts.manrope(fontSize: 10, color: const Color(0xFF66706E), height: 1.4))])));
}

class _BookingPreviewSheet extends StatelessWidget {
  final Booking booking;
  final String Function(DateTime) date;
  final String Function(DateTime) time;
  final String Function(double) money;
  final VoidCallback onClose;
  const _BookingPreviewSheet({required this.booking, required this.date, required this.time, required this.money, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final balance = booking.totalAmount - booking.paidAmount;
    return SafeArea(child: Container(padding: const EdgeInsets.fromLTRB(18, 10, 18, 22), decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(26))), child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE3E9E7), borderRadius: BorderRadius.circular(10)))),
      const SizedBox(height: 15),
      Row(children: [Expanded(child: Text('Pickup readiness', style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF17201F)))), IconButton(onPressed: onClose, icon: const Icon(Icons.close_rounded))]),
      _row('Booking', booking.bookingId),
      _row('Customer', booking.customerName),
      _row('Phone', booking.customerPhone),
      _row('Vehicle', booking.car?.name ?? booking.carId),
      _row('Registration', booking.car?.registrationNumber ?? 'Not available'),
      _row('Pickup', '${date(booking.pickupDateTime)} • ${time(booking.pickupDateTime)}'),
      _row('Return', '${date(booking.returnDateTime)} • ${time(booking.returnDateTime)}'),
      _row('Pickup branch', booking.pickupBranch?.name ?? booking.pickupBranchId),
      _row('Payment', balance <= 0 ? 'Paid' : '${money(balance)} due'),
      _row('Rental type', booking.rentalType),
      const SizedBox(height: 12),
      Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFE6FFFB), borderRadius: BorderRadius.circular(14)), child: Text('Physical handover remains manual. Verify KYC, vehicle condition, starting odometer and handover evidence before completing pickup.', style: GoogleFonts.manrope(fontSize: 10, height: 1.45, fontWeight: FontWeight.w700, color: const Color(0xFF17201F)))),
    ]))));
  }

  Widget _row(String label, String value) => Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: Text(label, style: GoogleFonts.manrope(fontSize: 9.5, color: const Color(0xFF94A09D)))), const SizedBox(width: 12), Flexible(child: Text(value.isEmpty ? 'Not available' : value, textAlign: TextAlign.right, style: GoogleFonts.manrope(fontSize: 9.5, fontWeight: FontWeight.w800, color: const Color(0xFF17201F))) )]));
}

class _ReasonDialog extends StatefulWidget {
  final String title;
  final String hint;
  final TextEditingController controller;
  const _ReasonDialog({required this.title, required this.hint, required this.controller});
  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}
class _ReasonDialogState extends State<_ReasonDialog> {
  bool _closing = false;
  @override
  Widget build(BuildContext context) => AlertDialog(backgroundColor: Colors.white, surfaceTintColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)), title: Text(widget.title, style: GoogleFonts.manrope(fontWeight: FontWeight.w900)), content: TextField(controller: widget.controller, maxLines: 4, decoration: InputDecoration(hintText: widget.hint, border: const OutlineInputBorder())), actions: [TextButton(onPressed: _closing ? null : () { _closing = true; Navigator.of(context, rootNavigator: true).pop(); }, child: const Text('Cancel')), ElevatedButton(onPressed: _closing ? null : () { final value = widget.controller.text.trim(); if (value.isEmpty) return; _closing = true; Navigator.of(context, rootNavigator: true).pop(value); }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F766E), foregroundColor: Colors.white, elevation: 0), child: const Text('Save'))]);
}

class PickupHandoverResult {
  final int startingOdometer;
  final List<String> photoUrls;
  final List<String> damagePhotoUrls;
  final List<String> existingDamage;
  final String fuelLevel;
  final String notes;
  final String? customerAcknowledgement;
  const PickupHandoverResult({required this.startingOdometer, required this.photoUrls, required this.damagePhotoUrls, required this.existingDamage, required this.fuelLevel, required this.notes, required this.customerAcknowledgement});
}

class PickupHandoverDialog extends StatefulWidget {
  final Booking booking;
  const PickupHandoverDialog({super.key, required this.booking});

  @override
  State<PickupHandoverDialog> createState() => _PickupHandoverDialogState();
}

class _PickupHandoverDialogState extends State<PickupHandoverDialog> {
  final _km = TextEditingController();
  final _damage = TextEditingController();
  final _notes = TextEditingController();
  final _ack = TextEditingController();
  final _handoverUrl = TextEditingController();
  final _damageUrl = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  final List<_PickupPhoto> _handoverPhotos = <_PickupPhoto>[];
  final List<_PickupPhoto> _damagePhotos = <_PickupPhoto>[];

  String _fuel = 'Full';
  bool _closing = false;
  bool _uploading = false;
  double _uploadProgress = 0;
  String? _error;

  static const primary = Color(0xFF0F766E);
  static const heading = Color(0xFF17201F);
  static const body = Color(0xFF66706E);
  static const muted = Color(0xFF94A09D);
  static const background = Color(0xFFF6F8F7);
  static const border = Color(0xFFE3E9E7);
  static const danger = Color(0xFFB91C1C);

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _km.dispose();
    _damage.dispose();
    _notes.dispose();
    _ack.dispose();
    _handoverUrl.dispose();
    _damageUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 850),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.12),
                blurRadius: 40,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            children: [
              _header(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _vehicleSummary(),
                      const SizedBox(height: 18),
                      _sectionTitle('Vehicle readiness', Icons.speed_rounded),
                      const SizedBox(height: 10),
                      _field(_km, 'Starting odometer', 'e.g. 48210',
                          TextInputType.number),
                      const SizedBox(height: 13),
                      _fuelSelector(),
                      const SizedBox(height: 22),
                      _sectionTitle('Handover evidence', Icons.photo_camera_rounded),
                      const SizedBox(height: 7),
                      Text(
                        'Take photos directly from the camera or select them from the device. Photos are uploaded securely before handover is completed.',
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          color: body,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _photoSection(
                        title: 'Handover photos',
                        subtitle: 'Front, rear, both sides, dashboard and vehicle condition.',
                        photos: _handoverPhotos,
                        requiredPhoto: true,
                        onCamera: () => _pickPhoto(
                          ImageSource.camera,
                          damage: false,
                        ),
                        onGallery: () => _pickPhoto(
                          ImageSource.gallery,
                          damage: false,
                          multi: true,
                        ),
                        onRemove: (i) => setState(() => _handoverPhotos.removeAt(i)),
                      ),
                      const SizedBox(height: 13),
                      _photoSection(
                        title: 'Existing damage photos',
                        subtitle: 'Capture scratches, dents or other pre-existing damage.',
                        photos: _damagePhotos,
                        requiredPhoto: false,
                        onCamera: () => _pickPhoto(
                          ImageSource.camera,
                          damage: true,
                        ),
                        onGallery: () => _pickPhoto(
                          ImageSource.gallery,
                          damage: true,
                          multi: true,
                        ),
                        onRemove: (i) => setState(() => _damagePhotos.removeAt(i)),
                      ),
                      const SizedBox(height: 13),
                      _urlFallback(
                        _handoverUrl,
                        'Existing handover photo URLs (optional)',
                        'Paste comma-separated URLs if photos were uploaded elsewhere.',
                      ),
                      const SizedBox(height: 10),
                      _urlFallback(
                        _damageUrl,
                        'Existing damage photo URLs (optional)',
                        'Paste comma-separated URLs if applicable.',
                      ),
                      const SizedBox(height: 22),
                      _sectionTitle('Inspection notes', Icons.fact_check_rounded),
                      const SizedBox(height: 10),
                      _field(
                        _damage,
                        'Existing damage',
                        'One item per line, e.g. front bumper scratch.',
                        TextInputType.multiline,
                        maxLines: 4,
                      ),
                      const SizedBox(height: 11),
                      _field(
                        _notes,
                        'Handover notes',
                        'Fuel, cleanliness, accessories, observations...',
                        TextInputType.multiline,
                        maxLines: 4,
                      ),
                      const SizedBox(height: 11),
                      _field(
                        _ack,
                        'Customer acknowledgement',
                        'Optional acknowledgement / signed confirmation reference.',
                        TextInputType.multiline,
                        maxLines: 3,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        _errorBox(_error!),
                      ],
                      if (_uploading) ...[
                        const SizedBox(height: 12),
                        _uploadProgressCard(),
                      ],
                    ],
                  ),
                ),
              ),
              _footer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() => Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          border: Border(bottom: BorderSide(color: border)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F766E), Color(0xFF115E59)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.key_rounded,
                color: Colors.white,
                size: 25,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vehicle Handover',
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: heading,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Pickup Pending • Physical handover verification',
                    style: GoogleFonts.manrope(
                      fontSize: 9.5,
                      color: muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Close',
              onPressed: _closing || _uploading ? null : _close,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      );

  Widget _vehicleSummary() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF0FDFA), Color(0xFFF8FAFA)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFCDEDE8)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: border),
              ),
              child: const Icon(
                Icons.directions_car_filled_rounded,
                color: primary,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.booking.car?.name ?? widget.booking.carId,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: heading,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${widget.booking.car?.registrationNumber ?? 'Registration unavailable'} • ${widget.booking.customerName}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 9.5,
                      color: body,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _sectionTitle(String title, IconData icon) => Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: const Color(0xFFE6FFFB),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: primary),
          ),
          const SizedBox(width: 9),
          Text(
            title,
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: heading,
            ),
          ),
        ],
      );

  Widget _fuelSelector() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fuel at pickup',
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: heading,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: ['Empty', '¼ Tank', '½ Tank', '¾ Tank', 'Full']
                .map(
                  (v) => ChoiceChip(
                    label: Text(
                      v,
                      style: GoogleFonts.manrope(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    selected: _fuel == v,
                    selectedColor: const Color(0xFFD9F5F0),
                    backgroundColor: background,
                    side: BorderSide(
                      color: _fuel == v ? const Color(0xFF8DD9CF) : border,
                    ),
                    onSelected: _uploading
                        ? null
                        : (_) => setState(() => _fuel = v),
                  ),
                )
                .toList(),
          ),
        ],
      );

  Widget _photoSection({
    required String title,
    required String subtitle,
    required List<_PickupPhoto> photos,
    required bool requiredPhoto,
    required VoidCallback onCamera,
    required VoidCallback onGallery,
    required ValueChanged<int> onRemove,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.manrope(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    color: heading,
                  ),
                ),
              ),
              if (requiredPhoto)
                _smallBadge('REQUIRED', primary)
              else
                _smallBadge('OPTIONAL', muted),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: GoogleFonts.manrope(
              fontSize: 8.5,
              color: muted,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 11),
          if (photos.isNotEmpty)
            SizedBox(
              height: 108,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => _photoTile(
                  photos[i],
                  () => onRemove(i),
                ),
              ),
            ),
          if (photos.isNotEmpty) const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _photoAction(
                  icon: Icons.photo_camera_rounded,
                  label: 'Take photo',
                  onPressed: _uploading ? null : onCamera,
                  filled: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _photoAction(
                  icon: Icons.photo_library_rounded,
                  label: 'Upload photos',
                  onPressed: _uploading ? null : onGallery,
                ),
              ),
            ],
          ),
          if (requiredPhoto && photos.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Add at least one handover photo before completing pickup.',
                style: GoogleFonts.manrope(
                  fontSize: 8.5,
                  color: danger,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _photoTile(_PickupPhoto photo, VoidCallback remove) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: FutureBuilder<Uint8List>(
            future: photo.file.readAsBytes(),
            builder: (_, snap) {
              if (snap.hasData) {
                return Image.memory(
                  snap.data!,
                  width: 108,
                  height: 108,
                  fit: BoxFit.cover,
                );
              }
              return Container(
                width: 108,
                height: 108,
                color: const Color(0xFFE9EFED),
                alignment: Alignment.center,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: primary,
                ),
              );
            },
          ),
        ),
        Positioned(
          right: 5,
          top: 5,
          child: InkWell(
            onTap: _uploading ? null : remove,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 27,
              height: 27,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(.68),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ),
        Positioned(
          left: 5,
          bottom: 5,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(.62),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              photo.file.name.length > 15
                  ? '${photo.file.name.substring(0, 12)}...'
                  : photo.file.name,
              style: GoogleFonts.manrope(
                color: Colors.white,
                fontSize: 6.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _photoAction({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool filled = false,
  }) {
    return SizedBox(
      height: 43,
      child: filled
          ? ElevatedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 17),
              label: Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 17),
              label: Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: primary,
                side: const BorderSide(color: Color(0xFF9DD8D1)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
    );
  }

  Widget _urlFallback(
    TextEditingController controller,
    String label,
    String hint,
  ) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.url,
      maxLines: 2,
      style: GoogleFonts.manrope(fontSize: 9.5, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: const Icon(Icons.link_rounded, size: 17, color: muted),
        filled: true,
        fillColor: Colors.white,
        labelStyle: GoogleFonts.manrope(fontSize: 9, color: body),
        hintStyle: GoogleFonts.manrope(fontSize: 8.5, color: muted),
        border: _inputBorder(),
        enabledBorder: _inputBorder(),
        focusedBorder: _inputBorder(primary),
      ),
    );
  }

  OutlineInputBorder _inputBorder([Color? color]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color ?? border),
      );

  Widget _field(
    TextEditingController c,
    String label,
    String hint,
    TextInputType type, {
    int maxLines = 1,
  }) =>
      TextField(
        controller: c,
        keyboardType: type,
        maxLines: maxLines,
        style: GoogleFonts.manrope(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: heading,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: GoogleFonts.manrope(fontSize: 9, color: body),
          hintStyle: GoogleFonts.manrope(fontSize: 8.5, color: muted),
          filled: true,
          fillColor: background,
          border: _inputBorder(),
          enabledBorder: _inputBorder(),
          focusedBorder: _inputBorder(primary),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        ),
      );

  Widget _smallBadge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: GoogleFonts.manrope(
            fontSize: 6.5,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      );

  Widget _errorBox(String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F2),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline_rounded, size: 17, color: danger),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.manrope(
                  fontSize: 9,
                  color: danger,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _uploadProgressCard() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFEFFAF8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFCDEDE8)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: primary,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Uploading evidence...',
                    style: GoogleFonts.manrope(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      color: heading,
                    ),
                  ),
                ),
                Text(
                  '${(_uploadProgress * 100).round()}%',
                  style: GoogleFonts.manrope(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _uploadProgress,
                minHeight: 5,
                backgroundColor: const Color(0xFFDCEDEA),
                color: primary,
              ),
            ),
          ],
        ),
      );

  Widget _footer() => Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 15),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
          border: Border(top: BorderSide(color: border)),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _closing || _uploading ? null : _close,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: body,
                    side: const BorderSide(color: border),
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _closing || _uploading ? null : _submit,
                  icon: _uploading
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.verified_rounded, size: 18),
                  label: Text(
                    _uploading ? 'Uploading...' : 'Complete Handover',
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Future<void> _pickPhoto(
    ImageSource source, {
    required bool damage,
    bool multi = false,
  }) async {
    if (_closing || _uploading) return;

    try {
      if (multi && source == ImageSource.gallery) {
        final files = await _picker.pickMultiImage(
          imageQuality: 82,
          maxWidth: 1800,
          maxHeight: 1800,
        );
        if (!mounted || files.isEmpty) return;
        setState(() {
          final target = damage ? _damagePhotos : _handoverPhotos;
          target.addAll(files.map(_PickupPhoto.new));
          _error = null;
        });
      } else {
        final file = await _picker.pickImage(
          source: source,
          imageQuality: 82,
          maxWidth: 1800,
          maxHeight: 1800,
        );
        if (!mounted || file == null) return;
        setState(() {
          final target = damage ? _damagePhotos : _handoverPhotos;
          target.add(_PickupPhoto(file));
          _error = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not access images: ${_cleanError(e)}');
    }
  }

  Future<List<String>> _uploadPhotos(
    List<_PickupPhoto> photos,
    String folder,
  ) async {
    final urls = <String>[];

    for (var i = 0; i < photos.length; i++) {
      final photo = photos[i];
      final bytes = await photo.file.readAsBytes();
      final extension = _extension(photo.file.name);
      final path =
          'tenants/${AppConfig.tenant.tenantId}/bookings/${widget.booking.bookingId}/pickup/$folder/${DateTime.now().microsecondsSinceEpoch}_$i$extension';

      final ref = FirebaseStorage.instance.ref().child(path);
      final task = ref.putData(
        bytes,
        SettableMetadata(contentType: _contentType(extension)),
      );

      task.snapshotEvents.listen((snapshot) {
        if (!mounted || !_uploading) return;
        final local = (i + snapshot.bytesTransferred / snapshot.totalBytes) /
            (photos.length * 1.0);
        setState(() => _uploadProgress = local.clamp(0.0, 1.0));
      });

      await task;
      urls.add(await ref.getDownloadURL());

      if (mounted) {
        setState(() {
          _uploadProgress =
              ((i + 1) / photos.length).clamp(0.0, 1.0);
        });
      }
    }

    return urls;
  }

  String _extension(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0) return '.jpg';
    final value = name.substring(dot).toLowerCase();
    const allowed = ['.jpg', '.jpeg', '.png', '.webp', '.heic'];
    return allowed.contains(value) ? value : '.jpg';
  }

  String _contentType(String extension) {
    switch (extension) {
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.heic':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }

  List<String> _urlList(String text) => text
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  Future<void> _submit() async {
    if (_closing || _uploading) return;

    final km = int.tryParse(_km.text.trim());
    if (km == null || km < 0) {
      setState(() => _error = 'Enter a valid starting odometer.');
      return;
    }

    if (_handoverPhotos.isEmpty && _urlList(_handoverUrl.text).isEmpty) {
      setState(() => _error =
          'Add at least one handover photo using camera, gallery, or an existing URL.');
      return;
    }

    setState(() {
      _error = null;
      _uploading = true;
      _uploadProgress = 0;
    });

    try {
      FocusManager.instance.primaryFocus?.unfocus();

      final handoverUrls = <String>[
        ..._urlList(_handoverUrl.text),
        if (_handoverPhotos.isNotEmpty)
          ...await _uploadPhotos(_handoverPhotos, 'handover'),
      ];

      final damageUrls = <String>[
        ..._urlList(_damageUrl.text),
        if (_damagePhotos.isNotEmpty)
          ...await _uploadPhotos(_damagePhotos, 'damage'),
      ];

      if (!mounted) return;

      _closing = true;
      setState(() => _uploading = false);

      Navigator.of(context, rootNavigator: true).pop(
        PickupHandoverResult(
          startingOdometer: km,
          photoUrls: handoverUrls,
          damagePhotoUrls: damageUrls,
          existingDamage: _damage.text
              .split('\n')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(),
          fuelLevel: _fuel,
          notes: _notes.text.trim(),
          customerAcknowledgement:
              _ack.text.trim().isEmpty ? null : _ack.text.trim(),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _uploadProgress = 0;
        _error = 'Photo upload failed: ${_cleanError(e)}';
      });
    }
  }

  String _cleanError(Object error) =>
      error.toString().replaceFirst('Exception: ', '').trim();

  void _close() {
    if (_closing || _uploading) return;
    _closing = true;
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context, rootNavigator: true).pop();
  }
}

class _PickupPhoto {
  final XFile file;
  const _PickupPhoto(this.file);
}

