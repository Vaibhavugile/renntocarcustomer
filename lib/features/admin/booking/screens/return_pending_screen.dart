import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/app_config.dart';
import '../../../booking/models/booking.dart';
import '../../../booking/services/booking_service.dart';

/// Premium operational Return Pending screen.
///
/// Flow:
/// ACTIVE -> RETURN PENDING -> physical return inspection -> COMPLETED
///
/// Return is never completed automatically. The inspection is revalidated and
/// persisted through BookingService.recordReturnInspectionForAdmin().
class ReturnPendingScreen extends StatefulWidget {
  const ReturnPendingScreen({super.key});

  @override
  State<ReturnPendingScreen> createState() => _ReturnPendingScreenState();
}

class _ReturnPendingScreenState extends State<ReturnPendingScreen> {
  static const background = Color(0xFFF6F8F7);
  static const card = Colors.white;
  static const primary = Color(0xFF0F766E);
  static const purple = Color(0xFF7C3AED);
  static const warning = Color(0xFFB45309);
  static const danger = Color(0xFFB91C1C);
  static const success = Color(0xFF15803D);
  static const heading = Color(0xFF17201F);
  static const body = Color(0xFF66706E);
  static const muted = Color(0xFF94A09D);
  static const border = Color(0xFFE3E9E7);

  final BookingService _service = BookingService.instance;
  String get _tenantId => AppConfig.tenant.tenantId;

  List<Booking> _bookings = <Booking>[];
  bool _loading = true;
  bool _working = false;
  String _search = '';
  String _sort = 'return';
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
      final list = all.where((b) => b.status == BookingStatus.returnPending).toList();
      _sortList(list);
      if (!mounted) return;
      setState(() { _bookings = list; _loading = false; _working = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _working = false; });
      _message(_cleanError(e), error: true);
    }
  }

  void _sortList(List<Booking> list) {
    if (_sort == 'return') list.sort((a, b) => a.returnDateTime.compareTo(b.returnDateTime));
    if (_sort == 'overdue') list.sort((a, b) => _overdueScore(b).compareTo(_overdueScore(a)));
    if (_sort == 'updated') list.sort((a, b) => (b.updatedAt ?? b.pickupDateTime).compareTo(a.updatedAt ?? a.pickupDateTime));
  }

  int _overdueScore(Booking b) => DateTime.now().isAfter(b.returnDateTime) ? DateTime.now().difference(b.returnDateTime).inMinutes : 0;

  List<Booking> get _filtered {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return _bookings;
    return _bookings.where((b) => b.bookingId.toLowerCase().contains(q) || b.customerName.toLowerCase().contains(q) || b.customerPhone.toLowerCase().contains(q) || b.customerEmail.toLowerCase().contains(q) || b.carId.toLowerCase().contains(q) || (b.car?.name ?? '').toLowerCase().contains(q) || (b.car?.registrationNumber ?? '').toLowerCase().contains(q) || b.returnBranchId.toLowerCase().contains(q)).toList();
  }

  int get _dueToday => _bookings.where((b) {
    final n = DateTime.now();
    return b.returnDateTime.year == n.year && b.returnDateTime.month == n.month && b.returnDateTime.day == n.day;
  }).length;

  int get _overdue => _bookings.where((b) => DateTime.now().isAfter(b.returnDateTime)).length;
  double get _pendingAmount => _bookings.fold<double>(0, (s, b) => s + (b.totalAmount - b.paidAmount));

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

  Future<void> _openInspection(Booking booking) async {
    if (_working) return;
    Booking fresh;
    try {
      fresh = await _revalidate(booking);
    } catch (e) {
      _message(_cleanError(e), error: true);
      await _load(refresh: true);
      return;
    }
    if (fresh.status != BookingStatus.returnPending) { _message('Booking changed state. Refreshing.', error: true); await _load(refresh: true); return; }

    final inspection = await _service.getInspectionDataForAdmin(
      tenantId: _tenantId,
      bookingId: fresh.bookingId,
    );
    final startingOdometer = _toInt(
      inspection?['odometerStart'] ??
          (inspection?['pickupInspection'] is Map
              ? (inspection!['pickupInspection'] as Map)['startingOdometer']
              : null),
    );
    if (startingOdometer <= 0) {
      _message('Pickup odometer is missing. Complete pickup handover before return.', error: true);
      return;
    }

    final result = await showDialog<ReturnInspectionResult>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (_) => ReturnInspectionDialog(
        booking: fresh,
        startingOdometer: startingOdometer,
      ),
    );
    if (result == null || !mounted) return;

    setState(() => _working = true);
    try {
      final latest = await _revalidate(fresh);
      if (latest.status != BookingStatus.returnPending) throw Exception('Booking has already changed state. Refresh the list.');

      final included = latest.unlimitedKm ? 0 : (latest.includedKm ?? 0);
      // The service reads the authoritative pickup odometer and calculates actual/extra KM.
      // The screen only supplies the measured return odometer and the final billing inputs.
      await _service.recordReturnInspectionForAdmin(
        tenantId: _tenantId,
        bookingId: latest.bookingId,
        endingOdometer: result.endingOdometer,
        extraKmCharge: result.extraKmCharge,
        includedKm: included,
        photoUrls: result.photoUrls,
        damagePhotoUrls: result.damagePhotoUrls,
        damagesFound: result.damagesFound,
        fuelLevel: result.fuelLevel,
        notes: result.notes,
        fuelCharge: result.fuelCharge,
        damageCharge: result.damageCharge,
        lateCharge: result.lateCharge,
        otherCharge: result.otherCharge,
        securityDepositAdjustment: result.securityDepositAdjustment,
        customerAcknowledgement: result.customerAcknowledgement,
      );

      if (!mounted) return;
      _message('Return inspection completed. Booking is now Completed.');
      await _load(refresh: true);
    } catch (e) {
      if (mounted) _message(_cleanError(e), error: true);
      await _load(refresh: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _verifyAndRefresh(Booking booking) async {
    try {
      await _revalidate(booking);
      if (mounted) _message('Booking verified. It is still Return Pending.');
    } catch (e) {
      if (mounted) _message(_cleanError(e), error: true);
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
          ElevatedButton(onPressed: () => Navigator.of(context, rootNavigator: true).pop(true), style: ElevatedButton.styleFrom(backgroundColor: purple, foregroundColor: Colors.white, elevation: 0), child: const Text('Continue')),
        ],
      ),
    );
    return result ?? false;
  }

  int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  void _message(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(16), backgroundColor: error ? danger : primary, content: Text(text)));
  }

  String _cleanError(Object e) => e.toString().replaceFirst('Exception: ', '').trim();
  String _date(DateTime d) => DateFormat('dd MMM yyyy').format(d);
  String _time(DateTime d) => DateFormat('hh:mm a').format(d);
  String _money(double n) => '₹${n.toStringAsFixed(0)}';

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Return Pending', style: GoogleFonts.manrope(fontSize: 19, fontWeight: FontWeight.w900, color: heading)), Text('${_bookings.length} vehicles awaiting physical return', style: GoogleFonts.manrope(fontSize: 9.5, color: muted, fontWeight: FontWeight.w700))]),
        actions: [if (_working) const Padding(padding: EdgeInsets.all(18), child: SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2))) else IconButton(onPressed: () => _load(refresh: true), icon: const Icon(Icons.refresh_rounded)), const SizedBox(width: 8)],
      ),
      body: RefreshIndicator(
        color: primary,
        onRefresh: () => _load(refresh: true),
        child: _loading ? const Center(child: CircularProgressIndicator(color: primary)) : CustomScrollView(physics: const AlwaysScrollableScrollPhysics(), slivers: [
          SliverToBoxAdapter(child: _dashboard()),
          SliverToBoxAdapter(child: _filters()),
          if (list.isEmpty) const SliverFillRemaining(hasScrollBody: false, child: _EmptyReturnState()) else SliverPadding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 30), sliver: SliverList.builder(itemCount: list.length, itemBuilder: (_, i) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _bookingCard(list[i])))),
        ]),
      ),
    );
  }

  Widget _dashboard() => Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 12), child: LayoutBuilder(builder: (_, c) {
    final data = [('Pending', _bookings.length, Icons.assignment_return_rounded, purple), ('Today', _dueToday, Icons.today_rounded, primary), ('Overdue', _overdue, Icons.warning_amber_rounded, danger), ('Balance', _money(_pendingAmount), Icons.payments_rounded, warning)];
    return GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: data.length, gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: c.maxWidth > 850 ? 4 : 2, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: c.maxWidth > 850 ? 2.4 : 2.1), itemBuilder: (_, i) { final v = data[i]; return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(17), border: Border.all(color: border)), child: Row(children: [Icon(v.$3 as IconData, color: v.$4 as Color, size: 19), const SizedBox(width: 9), Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${v.$2}', style: GoogleFonts.manrope(fontSize: 17, fontWeight: FontWeight.w900, color: heading)), Text(v.$1 as String, style: GoogleFonts.manrope(fontSize: 8.5, fontWeight: FontWeight.w800, color: muted))]))])); });
  }));

  Widget _filters() => Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 14), child: Row(children: [Expanded(child: TextField(onChanged: (v) => setState(() => _search = v), decoration: InputDecoration(hintText: 'Search booking, customer, phone, vehicle...', hintStyle: GoogleFonts.manrope(fontSize: 10, color: muted), prefixIcon: const Icon(Icons.search_rounded, color: muted), filled: true, fillColor: card, border: _outline(), enabledBorder: _outline(), focusedBorder: _outline(primary)))), const SizedBox(width: 8), Container(height: 50, padding: const EdgeInsets.symmetric(horizontal: 8), decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(15), border: Border.all(color: border)), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: _sort, items: const [DropdownMenuItem(value: 'return', child: Text('Return time')), DropdownMenuItem(value: 'overdue', child: Text('Overdue first')), DropdownMenuItem(value: 'updated', child: Text('Recently updated'))], onChanged: (v) { if (v == null) return; setState(() { _sort = v; _sortList(_bookings); }); })))]));
  OutlineInputBorder _outline([Color? c]) => OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: c ?? border));

  Widget _bookingCard(Booking b) {
    final overdue = DateTime.now().isAfter(b.returnDateTime);
    final balance = b.totalAmount - b.paidAmount;
    final vehicle = b.car?.name.isNotEmpty == true ? b.car!.name : b.carId;
    final reg = b.car?.registrationNumber ?? '';
    return Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(21), border: Border.all(color: border)), child: Column(children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 58, height: 58, decoration: BoxDecoration(color: const Color(0xFFF3EEFF), borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.directions_car_filled_rounded, color: purple, size: 28)), const SizedBox(width: 11), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(vehicle, style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w900, color: heading)), const SizedBox(height: 3), Text(reg.isEmpty ? b.carId : reg, style: GoogleFonts.manrope(fontSize: 9, fontWeight: FontWeight.w800, color: muted)), const SizedBox(height: 5), Text(b.customerName.isEmpty ? 'Customer' : b.customerName, style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w800, color: body)), Text(b.customerPhone, style: GoogleFonts.manrope(fontSize: 9, color: muted))])), _badge(overdue ? 'OVERDUE' : 'RETURN PENDING', overdue ? danger : warning)]),
      const SizedBox(height: 12),
      Container(padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)), child: Row(children: [Expanded(child: _mini('PICKUP', '${_date(b.pickupDateTime)}\n${_time(b.pickupDateTime)}', Icons.login_rounded, primary)), Container(width: 1, height: 42, color: border), Expanded(child: _mini('RETURN', '${_date(b.returnDateTime)}\n${_time(b.returnDateTime)}', Icons.logout_rounded, overdue ? danger : purple)), Container(width: 1, height: 42, color: border), Expanded(child: _mini('PAYMENT', balance <= 0 ? 'Paid' : '${_money(balance)} due', Icons.payments_rounded, balance <= 0 ? success : warning))])),
      const SizedBox(height: 11),
      Row(children: [Expanded(child: OutlinedButton.icon(onPressed: () => _details(b), icon: const Icon(Icons.visibility_outlined, size: 15), label: const Text('Details'))), const SizedBox(width: 7), Expanded(flex: 2, child: ElevatedButton.icon(onPressed: _working ? null : () => _openInspection(b), icon: const Icon(Icons.fact_check_rounded, size: 16), label: const Text('Complete Return'), style: ElevatedButton.styleFrom(backgroundColor: purple, foregroundColor: Colors.white, elevation: 0))), const SizedBox(width: 7), PopupMenuButton<String>(onSelected: (v) { if (v == 'start') _verifyAndRefresh(b); }, itemBuilder: (_) => const [PopupMenuItem(value: 'start', child: Text('Open return process'))], child: Container(width: 43, height: 42, alignment: Alignment.center, decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12), border: Border.all(color: border)), child: const Icon(Icons.more_horiz_rounded, color: body)))])
    ]));
  }

  Widget _mini(String title, String value, IconData icon, Color color) => Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon, size: 12, color: color), const SizedBox(width: 4), Text(title, style: GoogleFonts.manrope(fontSize: 7, fontWeight: FontWeight.w900, color: muted))]), const SizedBox(height: 4), Text(value, style: GoogleFonts.manrope(fontSize: 8.5, height: 1.35, fontWeight: FontWeight.w800, color: heading))]));
  Widget _badge(String text, Color color) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), decoration: BoxDecoration(color: color.withOpacity(.09), borderRadius: BorderRadius.circular(9)), child: Text(text, style: GoogleFonts.manrope(fontSize: 7.5, fontWeight: FontWeight.w900, color: color)));

  Future<void> _details(Booking b) async => showModalBottomSheet<void>(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => _ReturnPreviewSheet(booking: b, date: _date, time: _time, money: _money));
}

class _EmptyReturnState extends StatelessWidget {
  const _EmptyReturnState();
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(30), child: Column(mainAxisSize: MainAxisSize.min, children: [Container(width: 64, height: 64, decoration: BoxDecoration(color: const Color(0xFFF3EEFF), borderRadius: BorderRadius.circular(20)), child: const Icon(Icons.assignment_turned_in_outlined, color: Color(0xFF7C3AED), size: 30)), const SizedBox(height: 14), Text('No return pending bookings', style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w900)), const SizedBox(height: 5), Text('There are currently no vehicles waiting for physical return inspection.', textAlign: TextAlign.center, style: GoogleFonts.manrope(fontSize: 10, color: const Color(0xFF66706E), height: 1.4))])));
}

class _ReturnPreviewSheet extends StatelessWidget {
  final Booking booking; final String Function(DateTime) date; final String Function(DateTime) time; final String Function(double) money;
  const _ReturnPreviewSheet({required this.booking, required this.date, required this.time, required this.money});
  @override
  @override
  Widget build(BuildContext context) {
    final balance = booking.totalAmount - booking.paidAmount;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 22),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3E9E7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Return readiness',
                      style: GoogleFonts.manrope(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF17201F),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              _row('Booking', booking.bookingId),
              _row('Customer', booking.customerName),
              _row('Phone', booking.customerPhone),
              _row('Vehicle', booking.car?.name ?? booking.carId),
              _row('Registration', booking.car?.registrationNumber ?? 'Not available'),
              _row('Pickup', '${date(booking.pickupDateTime)} • ${time(booking.pickupDateTime)}'),
              _row('Return', '${date(booking.returnDateTime)} • ${time(booking.returnDateTime)}'),
              _row('Return branch', booking.returnBranch?.name ?? booking.returnBranchId),
              _row('Starting KM', 'Read from pickup inspection at completion'),
              _row('Payment', balance <= 0 ? 'Paid' : '${money(balance)} due'),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3EEFF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'Return completion calculates actual KM from the saved pickup odometer, validates the ending odometer, records charges and inspection evidence, then closes the booking.',
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF17201F),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String l, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: Text(l, style: GoogleFonts.manrope(fontSize: 9.5, color: const Color(0xFF94A09D)))), const SizedBox(width: 12), Flexible(child: Text(v.isEmpty ? 'Not available' : v, textAlign: TextAlign.right, style: GoogleFonts.manrope(fontSize: 9.5, fontWeight: FontWeight.w800, color: const Color(0xFF17201F))) )]));
}

class ReturnInspectionResult {
  final int endingOdometer;
  final double extraKmCharge;
  final double fuelCharge;
  final List<String> photoUrls;
  final List<String> damagePhotoUrls;
  final List<String> damagesFound;
  final String fuelLevel;
  final String notes;
  final double damageCharge;
  final double lateCharge;
  final double otherCharge;
  final double securityDepositAdjustment;
  final String? customerAcknowledgement;

  const ReturnInspectionResult({
    required this.endingOdometer,
    required this.extraKmCharge,
    required this.fuelCharge,
    required this.photoUrls,
    required this.damagePhotoUrls,
    required this.damagesFound,
    required this.fuelLevel,
    required this.notes,
    required this.damageCharge,
    required this.lateCharge,
    required this.otherCharge,
    required this.securityDepositAdjustment,
    required this.customerAcknowledgement,
  });
}


class ReturnInspectionDialog extends StatefulWidget {
  final Booking booking;
  final int startingOdometer;

  const ReturnInspectionDialog({
    super.key,
    required this.booking,
    required this.startingOdometer,
  });

  @override
  State<ReturnInspectionDialog> createState() => _ReturnInspectionDialogState();
}

class _ReturnInspectionDialogState extends State<ReturnInspectionDialog> {
  static const primary = Color(0xFF7C3AED);
  static const heading = Color(0xFF17201F);
  static const body = Color(0xFF66706E);
  static const muted = Color(0xFF94A09D);
  static const background = Color(0xFFF6F8F7);
  static const border = Color(0xFFE3E9E7);
  static const danger = Color(0xFFB91C1C);
  static const success = Color(0xFF15803D);

  final _endingKm = TextEditingController();
  final _fuelCharge = TextEditingController(text: '0');
  final _damageCharge = TextEditingController(text: '0');
  final _lateCharge = TextEditingController(text: '0');
  final _otherCharge = TextEditingController(text: '0');
  final _depositAdjustment = TextEditingController(text: '0');
  final _photosUrl = TextEditingController();
  final _damagePhotosUrl = TextEditingController();
  final _damages = TextEditingController();
  final _notes = TextEditingController();
  final _ack = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  final List<_ReturnPhoto> _returnPhotos = <_ReturnPhoto>[];
  final List<_ReturnPhoto> _damagePhotos = <_ReturnPhoto>[];

  String _fuel = 'Full';
  bool _closing = false;
  bool _uploading = false;
  double _uploadProgress = 0;
  String? _error;

  @override
  void dispose() {
    _endingKm.dispose();
    _fuelCharge.dispose();
    _damageCharge.dispose();
    _lateCharge.dispose();
    _otherCharge.dispose();
    _depositAdjustment.dispose();
    _photosUrl.dispose();
    _damagePhotosUrl.dispose();
    _damages.dispose();
    _notes.dispose();
    _ack.dispose();
    super.dispose();
  }

  double _d(TextEditingController c) =>
      double.tryParse(c.text.trim()) ?? -1;

  int? get _ending => int.tryParse(_endingKm.text.trim());

  int get _included =>
      widget.booking.unlimitedKm ? 0 : (widget.booking.includedKm ?? 0);

  int get _actualKm =>
      _ending == null ? 0 : (_ending! - widget.startingOdometer);

  int get _extraKm => widget.booking.unlimitedKm
      ? 0
      : (_actualKm > _included ? _actualKm - _included : 0);

  double get _calculatedExtraKmCharge =>
      _extraKm * widget.booking.extraKmRate;

  double get _totalAdditionalCharges {
    final values = [
      _calculatedExtraKmCharge,
      _d(_fuelCharge) < 0 ? 0 : _d(_fuelCharge),
      _d(_damageCharge) < 0 ? 0 : _d(_damageCharge),
      _d(_lateCharge) < 0 ? 0 : _d(_lateCharge),
      _d(_otherCharge) < 0 ? 0 : _d(_otherCharge),
    ];
    return values.fold<double>(0, (a, b) => a + b);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 900),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.12),
                blurRadius: 35,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            children: [
              _header(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _vehicleSummary(),
                      const SizedBox(height: 18),
                      _sectionTitle('Return odometer', Icons.speed_rounded),
                      const SizedBox(height: 10),
                      _field(
                        _endingKm,
                        'Ending odometer',
                        'Must not be lower than ${widget.startingOdometer} KM',
                        TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      _kmPreview(),
                      const SizedBox(height: 20),
                      _sectionTitle('Return condition', Icons.local_gas_station_rounded),
                      const SizedBox(height: 9),
                      _fuelSelector(),
                      const SizedBox(height: 20),
                      _sectionTitle('Return evidence', Icons.photo_library_rounded),
                      const SizedBox(height: 7),
                      Text(
                        'Capture the vehicle condition at return. You can take photos with the camera or select multiple photos from the gallery.',
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          color: body,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _photoSection(
                        title: 'Return photos',
                        subtitle: 'Exterior, interior, dashboard, fuel and overall condition.',
                        photos: _returnPhotos,
                        requiredPhoto: true,
                        onCamera: () => _pickPhoto(ImageSource.camera, damage: false),
                        onGallery: () => _pickPhoto(ImageSource.gallery, damage: false, multi: true),
                        onRemove: (i) => setState(() => _returnPhotos.removeAt(i)),
                      ),
                      const SizedBox(height: 13),
                      _photoSection(
                        title: 'Damage photos',
                        subtitle: 'Capture new damage or condition differences found during inspection.',
                        photos: _damagePhotos,
                        requiredPhoto: false,
                        onCamera: () => _pickPhoto(ImageSource.camera, damage: true),
                        onGallery: () => _pickPhoto(ImageSource.gallery, damage: true, multi: true),
                        onRemove: (i) => setState(() => _damagePhotos.removeAt(i)),
                      ),
                      const SizedBox(height: 10),
                      _urlFallback(
                        _photosUrl,
                        'Existing return photo URLs (optional)',
                        'Paste comma-separated URLs if evidence already exists elsewhere.',
                      ),
                      const SizedBox(height: 10),
                      _urlFallback(
                        _damagePhotosUrl,
                        'Existing damage photo URLs (optional)',
                        'Paste comma-separated URLs if applicable.',
                      ),
                      const SizedBox(height: 20),
                      _sectionTitle('Charges & settlement', Icons.receipt_long_rounded),
                      const SizedBox(height: 10),
                      _chargeGrid(),
                      const SizedBox(height: 12),
                      _chargeSummary(),
                      const SizedBox(height: 20),
                      _sectionTitle('Inspection notes', Icons.fact_check_rounded),
                      const SizedBox(height: 10),
                      _field(
                        _damages,
                        'Damages found',
                        'One damage item per line.',
                        TextInputType.multiline,
                        maxLines: 4,
                      ),
                      const SizedBox(height: 11),
                      _field(
                        _notes,
                        'Inspection notes',
                        'Fuel, cleanliness, accessories, damage observations...',
                        TextInputType.multiline,
                        maxLines: 4,
                      ),
                      const SizedBox(height: 11),
                      _field(
                        _ack,
                        'Customer acknowledgement',
                        'Optional acknowledgement / settlement reference.',
                        TextInputType.multiline,
                        maxLines: 2,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        _errorBanner(),
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
        padding: const EdgeInsets.fromLTRB(20, 18, 14, 16),
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
                  colors: [Color(0xFFEDE9FE), Color(0xFFF5F3FF)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.fact_check_rounded, color: primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Complete Return Inspection',
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: heading,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${widget.booking.customerName.isEmpty ? 'Customer' : widget.booking.customerName} • ${widget.booking.car?.name ?? widget.booking.carId}',
                    maxLines: 1,
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
            colors: [Color(0xFFF8F7FF), Color(0xFFF3EEFF)],
          ),
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: const Color(0xFFE4DDFB)),
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE4DDFB)),
              ),
              child: const Icon(
                Icons.directions_car_filled_rounded,
                color: primary,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
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
                    widget.booking.car?.registrationNumber ?? 'Registration unavailable',
                    style: GoogleFonts.manrope(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: muted,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 6,
                    runSpacing: 5,
                    children: [
                      _smallBadge('START ${widget.startingOdometer} KM', primary),
                      _smallBadge(
                        widget.booking.unlimitedKm
                            ? 'UNLIMITED KM'
                            : 'INCLUDED $_included KM',
                        success,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _smallBadge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(.09),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: GoogleFonts.manrope(
            fontSize: 7.5,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      );

  Widget _sectionTitle(String title, IconData icon) => Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: const Color(0xFFF3EEFF),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: primary, size: 16),
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

  Widget _kmPreview() => AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: border),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: _metric('START', '${widget.startingOdometer} KM')),
                _divider(),
                Expanded(child: _metric('END', _ending == null ? '—' : '${_ending} KM')),
                _divider(),
                Expanded(child: _metric('ACTUAL', _ending == null ? '—' : '$_actualKm KM')),
                _divider(),
                Expanded(
                  child: _metric(
                    'EXTRA',
                    widget.booking.unlimitedKm ? 'Unlimited' : (_ending == null ? '—' : '$_extraKm KM'),
                  ),
                ),
              ],
            ),
            if (_ending != null && _actualKm >= 0 && !widget.booking.unlimitedKm) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: _extraKm > 0 ? const Color(0xFFFFF7ED) : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _extraKm > 0
                      ? 'Extra KM charge preview: ₹${_calculatedExtraKmCharge.toStringAsFixed(0)}'
                      : 'Within included KM allowance',
                  style: GoogleFonts.manrope(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    color: _extraKm > 0 ? const Color(0xFFB45309) : success,
                  ),
                ),
              ),
            ],
          ],
        ),
      );

  Widget _divider() => Container(
        width: 1,
        height: 30,
        color: border,
      );

  Widget _metric(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.manrope(fontSize: 7, fontWeight: FontWeight.w900, color: muted)),
            const SizedBox(height: 3),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.manrope(fontSize: 8.5, fontWeight: FontWeight.w900, color: heading)),
          ],
        ),
      );

  Widget _fuelSelector() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fuel at return',
            style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w900, color: heading),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: ['Empty', '¼ Tank', '½ Tank', '¾ Tank', 'Full'].map(
              (v) => ChoiceChip(
                label: Text(v, style: GoogleFonts.manrope(fontSize: 9, fontWeight: FontWeight.w800)),
                selected: _fuel == v,
                selectedColor: const Color(0xFFEDE9FE),
                backgroundColor: background,
                side: BorderSide(color: _fuel == v ? const Color(0xFFC4B5FD) : border),
                onSelected: _uploading ? null : (_) => setState(() => _fuel = v),
              ),
            ).toList(),
          ),
        ],
      );

  Widget _chargeGrid() => Column(
        children: [
          Row(
            children: [
              Expanded(child: _field(_fuelCharge, 'Fuel charge', '0', TextInputType.number)),
              const SizedBox(width: 8),
              Expanded(child: _field(_damageCharge, 'Damage charge', '0', TextInputType.number)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _field(_lateCharge, 'Late return', '0', TextInputType.number)),
              const SizedBox(width: 8),
              Expanded(child: _field(_otherCharge, 'Other charge', '0', TextInputType.number)),
            ],
          ),
          const SizedBox(height: 8),
          _field(
            _depositAdjustment,
            'Security deposit adjustment',
            '0 — positive/negative settlement amount',
            TextInputType.numberWithOptions(decimal: true, signed: true),
          ),
        ],
      );

  Widget _chargeSummary() => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(0xFFFAF9FF),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFFE4DDFB)),
        ),
        child: Row(
          children: [
            const Icon(Icons.receipt_long_rounded, color: primary, size: 18),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                'Additional charges',
                style: GoogleFonts.manrope(fontSize: 9, fontWeight: FontWeight.w800, color: body),
              ),
            ),
            Text(
              '₹${_totalAdditionalCharges.toStringAsFixed(0)}',
              style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w900, color: heading),
            ),
          ],
        ),
      );

  Widget _photoSection({
    required String title,
    required String subtitle,
    required List<_ReturnPhoto> photos,
    required bool requiredPhoto,
    required VoidCallback onCamera,
    required VoidCallback onGallery,
    required ValueChanged<int> onRemove,
  }) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: GoogleFonts.manrope(fontSize: 10.5, fontWeight: FontWeight.w900, color: heading)),
                      const SizedBox(height: 3),
                      Text(subtitle, style: GoogleFonts.manrope(fontSize: 8.5, color: muted, height: 1.3)),
                    ],
                  ),
                ),
                if (photos.isNotEmpty) _smallBadge('${photos.length} PHOTO${photos.length == 1 ? '' : 'S'}', primary),
              ],
            ),
            if (photos.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 112,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: photos.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => _photoTile(photos[i], () => onRemove(i)),
                ),
              ),
            ],
            if (photos.isNotEmpty) const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _photoAction(Icons.photo_camera_rounded, 'Take photo', onCamera, true)),
                const SizedBox(width: 8),
                Expanded(child: _photoAction(Icons.photo_library_rounded, 'Upload photos', onGallery, false)),
              ],
            ),
            if (requiredPhoto && photos.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'At least one return photo is required.',
                  style: GoogleFonts.manrope(fontSize: 8.5, color: danger, fontWeight: FontWeight.w800),
                ),
              ),
          ],
        ),
      );

  Widget _photoAction(IconData icon, String label, VoidCallback onTap, bool filled) =>
      SizedBox(
        height: 43,
        child: filled
            ? ElevatedButton.icon(
                onPressed: _uploading ? null : onTap,
                icon: Icon(icon, size: 16),
                label: Text(label),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              )
            : OutlinedButton.icon(
                onPressed: _uploading ? null : onTap,
                icon: Icon(icon, size: 16, color: primary),
                label: Text(label),
                style: OutlinedButton.styleFrom(
                  foregroundColor: heading,
                  side: const BorderSide(color: border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
      );

  Widget _photoTile(_ReturnPhoto photo, VoidCallback remove) => Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: FutureBuilder<Uint8List>(
              future: photo.file.readAsBytes(),
              builder: (_, snap) {
                if (snap.hasData) {
                  return Image.memory(snap.data!, width: 108, height: 108, fit: BoxFit.cover);
                }
                return Container(
                  width: 108,
                  height: 108,
                  color: const Color(0xFFE9EFED),
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(strokeWidth: 2, color: primary),
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
                decoration: BoxDecoration(color: Colors.black.withOpacity(.68), shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      );

  Widget _urlFallback(TextEditingController controller, String label, String hint) =>
      TextField(
        controller: controller,
        enabled: !_uploading,
        maxLines: 2,
        keyboardType: TextInputType.url,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: const Icon(Icons.link_rounded, size: 18),
          filled: true,
          fillColor: background,
          border: _outline(),
          enabledBorder: _outline(),
          focusedBorder: _outline(primary),
        ),
      );

  Widget _field(TextEditingController c, String label, String hint, TextInputType type, {int maxLines = 1}) =>
      TextField(
        controller: c,
        enabled: !_uploading,
        keyboardType: type,
        maxLines: maxLines,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: background,
          border: _outline(),
          enabledBorder: _outline(),
          focusedBorder: _outline(primary),
        ),
      );

  OutlineInputBorder _outline([Color? color]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: color ?? border, width: color == null ? 1 : 1.3),
      );

  Widget _errorBanner() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline_rounded, color: danger, size: 17),
            const SizedBox(width: 8),
            Expanded(child: Text(_error!, style: GoogleFonts.manrope(fontSize: 9.5, color: danger, fontWeight: FontWeight.w700, height: 1.35)),
            ),
          ],
        ),
      );

  Widget _uploadProgressCard() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFAF9FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE4DDFB)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: primary),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Uploading return evidence...',
                    style: GoogleFonts.manrope(fontSize: 9.5, fontWeight: FontWeight.w900, color: heading),
                  ),
                ),
                Text(
                  '${(_uploadProgress * 100).round()}%',
                  style: GoogleFonts.manrope(fontSize: 9, fontWeight: FontWeight.w900, color: primary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _uploadProgress,
                minHeight: 5,
                backgroundColor: const Color(0xFFE9E5FF),
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
                    foregroundColor: heading,
                    side: const BorderSide(color: border),
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _closing || _uploading ? null : _submit,
                  icon: _uploading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.verified_rounded, size: 17),
                  label: Text(_uploading ? 'Uploading...' : 'Complete Return'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
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
    if (_uploading || _closing) return;

    try {
      if (source == ImageSource.gallery && multi) {
        final files = await _picker.pickMultiImage(
          imageQuality: 82,
          maxWidth: 1800,
          maxHeight: 1800,
        );
        if (!mounted || files.isEmpty) return;
        setState(() {
          final target = damage ? _damagePhotos : _returnPhotos;
          target.addAll(files.map(_ReturnPhoto.new));
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
          final target = damage ? _damagePhotos : _returnPhotos;
          target.add(_ReturnPhoto(file));
          _error = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not access images: ${_cleanError(e)}');
    }
  }

  Future<List<String>> _uploadPhotos(
    List<_ReturnPhoto> photos,
    String folder,
  ) async {
    final urls = <String>[];

    for (var i = 0; i < photos.length; i++) {
      final photo = photos[i];
      final bytes = await photo.file.readAsBytes();
      final extension = _extension(photo.file.name);
      final path =
          'tenants/${AppConfig.tenant.tenantId}/bookings/${widget.booking.bookingId}/return/$folder/${DateTime.now().microsecondsSinceEpoch}_$i$extension';

      final ref = FirebaseStorage.instance.ref().child(path);
      final task = ref.putData(
        bytes,
        SettableMetadata(contentType: _contentType(extension)),
      );

      task.snapshotEvents.listen((snapshot) {
        if (!mounted || !_uploading || snapshot.totalBytes <= 0) return;
        final local =
            (i + snapshot.bytesTransferred / snapshot.totalBytes) /
                (photos.length * 1.0);
        setState(() => _uploadProgress = local.clamp(0.0, 1.0));
      });

      await task;
      urls.add(await ref.getDownloadURL());

      if (mounted) {
        setState(() => _uploadProgress = ((i + 1) / photos.length).clamp(0.0, 1.0));
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

  void _submit() async {
    if (_closing || _uploading) return;

    final ending = _ending;
    final charges = [
      _d(_fuelCharge),
      _d(_damageCharge),
      _d(_lateCharge),
      _d(_otherCharge),
      _d(_depositAdjustment),
    ];

    if (ending == null || ending < 0) {
      setState(() => _error = 'Enter a valid ending odometer.');
      return;
    }
    if (ending < widget.startingOdometer) {
      setState(() => _error =
          'Ending odometer cannot be lower than pickup odometer (${widget.startingOdometer} KM).');
      return;
    }
    if (charges.take(4).any((v) => v < 0)) {
      setState(() => _error = 'Return charges cannot be negative.');
      return;
    }
    if (_returnPhotos.isEmpty && _urlList(_photosUrl.text).isEmpty) {
      setState(() => _error =
          'Add at least one return photo using camera, gallery, or an existing URL.');
      return;
    }

    setState(() {
      _error = null;
      _uploading = true;
      _uploadProgress = 0;
    });

    try {
      FocusManager.instance.primaryFocus?.unfocus();

      final returnUrls = <String>[
        ..._urlList(_photosUrl.text),
        if (_returnPhotos.isNotEmpty)
          ...await _uploadPhotos(_returnPhotos, 'return'),
      ];

      final damageUrls = <String>[
        ..._urlList(_damagePhotosUrl.text),
        if (_damagePhotos.isNotEmpty)
          ...await _uploadPhotos(_damagePhotos, 'damage'),
      ];

      if (!mounted) return;

      _closing = true;
      setState(() => _uploading = false);

      Navigator.of(context, rootNavigator: true).pop(
        ReturnInspectionResult(
          endingOdometer: ending,
          extraKmCharge: _calculatedExtraKmCharge,
          fuelCharge: charges[0],
          photoUrls: returnUrls,
          damagePhotoUrls: damageUrls,
          damagesFound: _damages.text
              .split('\n')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(),
          fuelLevel: _fuel,
          notes: _notes.text.trim(),
          damageCharge: charges[1],
          lateCharge: charges[2],
          otherCharge: charges[3],
          securityDepositAdjustment: charges[4],
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

  void _close() {
    if (_closing || _uploading) return;
    _closing = true;
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context, rootNavigator: true).pop();
  }

  String _cleanError(Object error) =>
      error.toString().replaceFirst('Exception: ', '').trim();
}

class _ReturnPhoto {
  final XFile file;
  const _ReturnPhoto(this.file);
}
