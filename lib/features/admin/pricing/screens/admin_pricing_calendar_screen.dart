import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../../pricing/models/km_pricing_package.dart';
import '../../../pricing/models/pricing_profile.dart';
import '../../../pricing/services/pricing_profile_service.dart';

/// Premium Airbnb-style pricing calendar for a reusable PricingProfile.
///
/// Important: this screen deliberately uses the existing PricingProfile /
/// SpecialRate model. It does not introduce a second pricing engine.
///
/// Bulk rules are materialized into single-date SpecialRate overrides. This
/// keeps the existing customer/admin booking calculation compatible because
/// PricingProfile.priceFor(date) already resolves SpecialRate before falling
/// back to the package's normal price.
class AdminPricingCalendarScreen extends StatefulWidget {
  final PricingProfile profile;

  const AdminPricingCalendarScreen({
    super.key,
    required this.profile,
  });

  @override
  State<AdminPricingCalendarScreen> createState() =>
      _AdminPricingCalendarScreenState();
}

class _AdminPricingCalendarScreenState
    extends State<AdminPricingCalendarScreen> {
  static const Color background = Color(0xFFF8FAF9);
  static const Color card = Color(0xFFFFFFFF);
  static const Color primary = Color(0xFF0F766E);
  static const Color accent = Color(0xFF14B8A6);
  static const Color softAccent = Color(0xFFE6FFFB);
  static const Color heading = Color(0xFF17201F);
  static const Color body = Color(0xFF66706E);
  static const Color muted = Color(0xFF94A09D);
  static const Color border = Color(0xFFE5EBE9);
  static const String _calendarPrefix = '__CALENDAR__|';

  late PricingProfile _profile;
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDate = DateTime.now();
  RentalType _rentalType = RentalType.daily;
  bool _saving = false;

  final Set<DateTime> _selectedDates = <DateTime>{};

  String get tenantId => AppConfig.tenant.tenantId;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    _rentalType = _profile.dailyEnabled
        ? RentalType.daily
        : RentalType.hourly;
    _selectedDate = _dateOnly(_selectedDate);
  }

  List<KmPricingPackage> get _packages =>
      _profile.packagesFor(_rentalType)
          .where((package) => package.isActive && package.supportsRentalType(_rentalType.value))
          .toList(growable: false);

  DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _money(double value) {
    if (!value.isFinite) return '₹0';
    if (value == value.roundToDouble()) return '₹${value.toInt()}';
    return '₹${value.toStringAsFixed(0)}';
  }

  String _monthLabel(DateTime date) {
    const months = <String>[
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _shortDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')} ${_monthLabel(date).split(' ').first.substring(0, 3)} ${date.year}';

  String _priceLabel(double price) =>
      _rentalType == RentalType.hourly ? '${_money(price)}/h' : _money(price);

  bool _isCalendarRate(SpecialRate rate) => rate.name.startsWith(_calendarPrefix);

  String _calendarReason(SpecialRate rate) {
    if (!_isCalendarRate(rate)) return rate.name;
    final parts = rate.name.split('|');
    return parts.length > 1 && parts[1].trim().isNotEmpty
        ? parts.sublist(1).join('|').trim()
        : 'Calendar override';
  }

  SpecialRate? _calendarRateForDate(DateTime date) {
    for (final rate in _profile.specialRates) {
      if (_isCalendarRate(rate) && rate.containsDate(date)) return rate;
    }
    return null;
  }

  SpecialRate? _businessSpecialForDate(DateTime date) {
    for (final rate in _profile.specialRates) {
      if (_isCalendarRate(rate)) continue;
      if (rate.containsDate(date)) return rate;
    }
    return null;
  }

  double _baseEffectivePrice(DateTime date, KmPricingPackage package) {
    final special = _businessSpecialForDate(date);
    final override = special?.priceFor(
      rentalType: _rentalType,
      packageId: package.id,
    );

    if (override != null && override.isFinite && override >= 0) {
      return override;
    }

    return package.rateFor(_rentalType.value);
  }

  double _currentPrice(DateTime date, KmPricingPackage package) {
    final calendar = _calendarRateForDate(date);
    final override = calendar?.priceFor(
      rentalType: _rentalType,
      packageId: package.id,
    );

    if (override != null && override.isFinite && override >= 0) {
      return override;
    }

    return _baseEffectivePrice(date, package);
  }

  String _priceSource(DateTime date, KmPricingPackage package) {
    final calendar = _calendarRateForDate(date);
    if (calendar?.priceFor(
          rentalType: _rentalType,
          packageId: package.id,
        ) !=
        null) {
      return _calendarReason(calendar!);
    }

    final special = _businessSpecialForDate(date);
    if (special?.priceFor(
          rentalType: _rentalType,
          packageId: package.id,
        ) !=
        null) {
      return special!.name;
    }

    return 'Base package price';
  }

  List<DateTime> _monthDays(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = first.weekday - DateTime.monday;
    final total = ((leading + daysInMonth + 6) ~/ 7) * 7;

    return List<DateTime>.generate(
      total,
      (index) => first.subtract(Duration(days: leading)).add(Duration(days: index)),
    );
  }

  void _changeMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + delta,
      );
      _selectedDates.clear();
    });
  }

  void _toggleDateSelection(DateTime date) {
    final normalized = _dateOnly(date);
    setState(() {
      if (_selectedDates.any((item) => _sameDate(item, normalized))) {
        _selectedDates.removeWhere((item) => _sameDate(item, normalized));
      } else {
        _selectedDates.add(normalized);
      }
      _selectedDate = normalized;
    });
  }

  Future<void> _openDateDetails(DateTime date) async {
    setState(() => _selectedDate = _dateOnly(date));

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _dateDetailsSheet(date),
    );
  }

  Widget _dateDetailsSheet(DateTime date) {
    final calendar = _calendarRateForDate(date);
    final special = _businessSpecialForDate(date);

    return SafeArea(
      child: Container(
        constraints: const BoxConstraints(maxHeight: 760),
        decoration: const BoxDecoration(
          color: background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: border,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _shortDate(date),
                          style: const TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: heading,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_rentalType.label} pricing • ${_profile.name}',
                          style: const TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 12,
                            color: body,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            if (calendar != null || special != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: softAccent,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFBFEDE6)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome_rounded, color: primary, size: 18),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          calendar != null
                              ? 'Calendar override • ${_calendarReason(calendar)}'
                              : 'Special pricing • ${special!.name}',
                          style: const TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 11.5,
                            color: heading,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                shrinkWrap: true,
                itemCount: _packages.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, index) {
                  final package = _packages[index];
                  final base = _baseEffectivePrice(date, package);
                  final current = _currentPrice(date, package);
                  final changed = (current - base).abs() > 0.0001;
                  return _detailPackageCard(
                    package: package,
                    base: base,
                    current: current,
                    source: _priceSource(date, package),
                    changed: changed,
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 18),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _editSingleDate(date);
                  },
                  icon: const Icon(Icons.edit_calendar_rounded, size: 19),
                  label: const Text('Edit This Date'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailPackageCard({
    required KmPricingPackage package,
    required double base,
    required double current,
    required String source,
    required bool changed,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: softAccent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.route_rounded, color: primary, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      package.name,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: heading,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      package.unlimitedKm
                          ? 'Unlimited KM'
                          : '${package.safeIncludedKm} KM included',
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: muted,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _priceLabel(current),
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _miniInfo('Base', _priceLabel(base))),
              const SizedBox(width: 8),
              Expanded(child: _miniInfo('Source', source, compact: true)),
              if (changed) ...[
                const SizedBox(width: 8),
                _changeBadge(current - base),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniInfo(String label, String value, {bool compact = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              color: muted,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: compact ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: heading,
            ),
          ),
        ],
      ),
    );
  }

  Widget _changeBadge(double value) {
    final positive = value >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: positive ? softAccent : const Color(0xFFFFF3F1),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        '${positive ? '+' : ''}${_money(value)}',
        style: TextStyle(
          fontFamily: 'Manrope',
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: positive ? primary : const Color(0xFFB42318),
        ),
      ),
    );
  }

  Future<void> _editSingleDate(DateTime date) async {
    await _openBulkEditor(
      initialDates: <DateTime>{_dateOnly(date)},
      title: 'Edit ${_shortDate(date)}',
      forceDateSelection: true,
    );
  }

  Future<void> _openBulkEditor({
    Set<DateTime>? initialDates,
    String title = 'Bulk Price Update',
    bool forceDateSelection = false,
  }) async {
    final dates = <DateTime>{
      ...?initialDates?.map(_dateOnly),
    };

    final result = await showModalBottomSheet<_BulkEditResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BulkEditSheet(
        title: title,
        packages: _packages,
        rentalType: _rentalType,
        initialDates: dates,
        forceDateSelection: forceDateSelection,
        month: _visibleMonth,
        profile: _profile,
        basePrice: _baseEffectivePrice,
      ),
    );

    if (result == null || !mounted) return;
    await _applyBulkEdit(result);
  }

  Future<void> _applyBulkEdit(_BulkEditResult result) async {
    final affected = result.dates.map(_dateOnly).toSet();
    if (affected.isEmpty) {
      _showSnack('Select at least one date.', error: true);
      return;
    }

    if (result.selectedPackageIds.isEmpty) {
      _showSnack('Select at least one package.', error: true);
      return;
    }

    setState(() => _saving = true);

    try {
      final affectedDates = affected.toList()..sort();

      // Remove only previous calendar-generated overrides for affected dates.
      final retained = _profile.specialRates.where((rate) {
        if (!_isCalendarRate(rate)) return true;
        return !affectedDates.any(rate.containsDate);
      }).toList();

      final newRates = <SpecialRate>[];

      for (final date in affectedDates) {
        final hourlyPrices = <String, double>{};
        final dailyPrices = <String, double>{};

        // Preserve the current effective value for every package. We then
        // change only the rental type + packages selected in this operation.
        for (final package in _profile.hourlyPackages.where((p) => p.isActive)) {
          hourlyPrices[package.id] = _baseEffectivePriceForType(
            date,
            package,
            RentalType.hourly,
          );
        }
        for (final package in _profile.dailyPackages.where((p) => p.isActive)) {
          dailyPrices[package.id] = _baseEffectivePriceForType(
            date,
            package,
            RentalType.daily,
          );
        }

        final targetPackages = _packages.where(
          (package) => result.selectedPackageIds.contains(package.id),
        );

        for (final package in targetPackages) {
          final currentBase = _baseEffectivePriceForType(
            date,
            package,
            _rentalType,
          );
          final next = result.mode == _BulkMode.adjustment
              ? currentBase + result.adjustment
              : result.exactPrice;

          if (!next.isFinite || next < 0) {
            throw Exception('Price cannot be negative for ${package.name}.');
          }

          if (_rentalType == RentalType.hourly) {
            hourlyPrices[package.id] = next;
          } else {
            dailyPrices[package.id] = next;
          }
        }

        newRates.add(
          SpecialRate(
            id: 'calendar_${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}_${DateTime.now().microsecondsSinceEpoch}',
            name: '$_calendarPrefix${result.reason}',
            startDate: date,
            endDate: date,
            isActive: true,
            hourlyPrices: Map<String, double>.unmodifiable(hourlyPrices),
            dailyPrices: Map<String, double>.unmodifiable(dailyPrices),
          ),
        );
      }

      // Rebuild the profile explicitly so newer pricing-rule fields such as
      // minimumHoursByPackageId / minimumDaysByPackageId / extraHourRateByPackageId
      // are never lost when saving a calendar-only change.
      final updated = PricingProfile(
        id: _profile.id,
        tenantId: _profile.tenantId,
        vehicleId: _profile.vehicleId,
        pricingGroupId: _profile.pricingGroupId,
        name: _profile.name,
        currency: _profile.currency,
        hourlyPackages: _profile.hourlyPackages,
        dailyPackages: _profile.dailyPackages,
        specialRates: <SpecialRate>[
          ...newRates,
          ...retained,
        ],
        securityDeposit: _profile.securityDeposit,
        minimumHoursByPackageId: _profile.minimumHoursByPackageId,
        minimumDaysByPackageId: _profile.minimumDaysByPackageId,
        extraHourRateByPackageId: _profile.extraHourRateByPackageId,
        isActive: _profile.isActive,
      );

      await PricingProfileService.instance.updatePricingProfile(
        tenantId: tenantId,
        pricingProfileId: _profile.id,
        profile: updated,
      );

      if (!mounted) return;
      setState(() {
        _profile = updated;
        _selectedDates
          ..clear()
          ..addAll(affectedDates);
        _saving = false;
      });

      _showSnack(
        result.mode == _BulkMode.adjustment
            ? '${affectedDates.length} date${affectedDates.length == 1 ? '' : 's'} updated with ${result.adjustment >= 0 ? '+' : ''}${_money(result.adjustment)}.'
            : '${affectedDates.length} date${affectedDates.length == 1 ? '' : 's'} updated to ${_money(result.exactPrice)}.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showSnack(e.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  double _baseEffectivePriceForType(
    DateTime date,
    KmPricingPackage package,
    RentalType type,
  ) {
    for (final rate in _profile.specialRates) {
      if (_isCalendarRate(rate)) continue;
      if (!rate.containsDate(date)) continue;
      final value = rate.priceFor(
        rentalType: type,
        packageId: package.id,
      );
      if (value != null && value.isFinite && value >= 0) return value;
    }
    return package.rateFor(type.value);
  }

  void _showSnack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontWeight: FontWeight.w700,
            ),
          ),
          backgroundColor: error ? const Color(0xFFB42318) : primary,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
  }

  Widget _topSummary() {
    final activeSpecials = _profile.specialRates.where((x) => x.isActive).length;
    final calendarOverrides = _profile.specialRates.where(_isCalendarRate).length;

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: softAccent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.calendar_month_rounded, color: primary, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _profile.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: heading,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _profile.pricingGroupId.isEmpty
                          ? 'Shared pricing profile'
                          : _profile.pricingGroupId,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: muted,
                      ),
                    ),
                  ],
                ),
              ),
              _statusPill(_profile.isActive ? 'Active' : 'Inactive'),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(child: _summaryStat('Packages', '${_packages.length}')),
              const SizedBox(width: 8),
              Expanded(child: _summaryStat('Special rules', '$activeSpecials')),
              const SizedBox(width: 8),
              Expanded(child: _summaryStat('Calendar edits', '$calendarOverrides')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontFamily: 'Manrope', fontSize: 8.5, color: muted, fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(fontFamily: 'Manrope', fontSize: 14, color: heading, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _statusPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: softAccent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(fontFamily: 'Manrope', fontSize: 9, fontWeight: FontWeight.w900, color: primary),
      ),
    );
  }

  Widget _rentalToggle() {
    final canHourly = _profile.hourlyEnabled;
    final canDaily = _profile.dailyEnabled;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4F2),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          if (canDaily)
            Expanded(child: _toggleButton(RentalType.daily, 'Daily', Icons.today_rounded)),
          if (canHourly)
            Expanded(child: _toggleButton(RentalType.hourly, 'Hourly', Icons.schedule_rounded)),
        ],
      ),
    );
  }

  Widget _toggleButton(RentalType type, String label, IconData icon) {
    final selected = _rentalType == type;
    return GestureDetector(
      onTap: () {
        if (selected) return;
        setState(() {
          _rentalType = type;
          _selectedDates.clear();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? card : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: selected
              ? const [BoxShadow(color: Color(0x0D17201F), blurRadius: 12, offset: Offset(0, 4))]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: selected ? primary : muted),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: selected ? heading : muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _packageStrip() {
    return SizedBox(
      height: 78,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _packages.length,
        separatorBuilder: (_, __) => const SizedBox(width: 9),
        itemBuilder: (_, index) {
          final package = _packages[index];
          final price = package.rateFor(_rentalType.value);
          return Container(
            width: 165,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                Container(
                  width: 31,
                  height: 31,
                  decoration: BoxDecoration(color: softAccent, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.route_rounded, size: 16, color: primary),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(package.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Manrope', fontSize: 10.5, fontWeight: FontWeight.w900, color: heading)),
                      const SizedBox(height: 2),
                      Text(package.unlimitedKm ? 'Unlimited KM' : '${package.safeIncludedKm} KM', style: const TextStyle(fontFamily: 'Manrope', fontSize: 8.5, fontWeight: FontWeight.w600, color: muted)),
                    ],
                  ),
                ),
                Text(_priceLabel(price), style: const TextStyle(fontFamily: 'Manrope', fontSize: 11, fontWeight: FontWeight.w900, color: primary)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _calendarHeader() {
    return Row(
      children: [
        IconButton(
          onPressed: () => _changeMonth(-1),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                _monthLabel(_visibleMonth),
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'Manrope', fontSize: 18, fontWeight: FontWeight.w900, color: heading),
              ),
              const SizedBox(height: 2),
              const Text('Tap a date for full pricing details', style: TextStyle(fontFamily: 'Manrope', fontSize: 9.5, color: muted, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        TextButton(
          onPressed: () {
            final today = _dateOnly(DateTime.now());
            setState(() {
              _visibleMonth = DateTime(today.year, today.month);
              _selectedDate = today;
              _selectedDates.clear();
            });
          },
          child: const Text('Today'),
        ),
        IconButton(
          onPressed: () => _changeMonth(1),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }

  Widget _calendarGrid() {
    final days = _monthDays(_visibleMonth);
    const labels = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

    return Container(
      padding: const EdgeInsets.fromLTRB(9, 10, 9, 12),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Row(
            children: labels
                .map((label) => Expanded(
                      child: Center(
                        child: Text(label, style: const TextStyle(fontFamily: 'Manrope', fontSize: 8, fontWeight: FontWeight.w900, color: muted)),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: days.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 5,
              mainAxisSpacing: 5,
              mainAxisExtent: 72,
            ),
            itemBuilder: (_, index) {
              final date = days[index];
              return _dayCell(date, isCurrentMonth: date.month == _visibleMonth.month);
            },
          ),
        ],
      ),
    );
  }

  Widget _dayCell(DateTime date, {required bool isCurrentMonth}) {
    final selected = _selectedDates.any((item) => _sameDate(item, date));
    final focused = _sameDate(_selectedDate, date);
    final today = _sameDate(DateTime.now(), date);
    final calendar = _calendarRateForDate(date);
    final special = _businessSpecialForDate(date);
    final packages = _packages;
    final prices = packages.take(3).map((p) => _currentPrice(date, p)).toList();
    final hasOverride = calendar != null;
    final hasSpecial = special != null;

    return GestureDetector(
      onTap: () => _openDateDetails(date),
      onLongPress: () => _toggleDateSelection(date),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 5),
        decoration: BoxDecoration(
          color: selected ? softAccent : (focused ? const Color(0xFFF1F8F6) : card),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected ? primary : (today ? accent : border),
            width: selected || today ? 1.4 : 1,
          ),
        ),
        child: Opacity(
          opacity: isCurrentMonth ? 1 : 0.35,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${date.day}',
                    style: TextStyle(fontFamily: 'Manrope', fontSize: 11, fontWeight: FontWeight.w900, color: today ? primary : heading),
                  ),
                  const Spacer(),
                  if (hasOverride)
                    const Icon(Icons.auto_awesome_rounded, size: 10, color: primary)
                  else if (hasSpecial)
                    const Icon(Icons.local_offer_outlined, size: 10, color: primary),
                ],
              ),
              const Spacer(),
              for (var priceIndex = 0; priceIndex < prices.length; priceIndex++)
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    '${priceIndex + 1}. ${_priceLabel(prices[priceIndex])}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Manrope', fontSize: 7.6, fontWeight: FontWeight.w900, color: hasOverride ? primary : heading),
                  ),
                ),
              if (packages.length > 2)
                Text(packages.length > 3 ? 'Tap for ${packages.length} packages' : 'Tap for details', style: const TextStyle(fontFamily: 'Manrope', fontSize: 7, color: muted, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _selectionBar() {
    if (_selectedDates.isEmpty) return const SizedBox.shrink();

    final dates = _selectedDates.toList()..sort();
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: heading,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: const Color(0xFF2B3432), borderRadius: BorderRadius.circular(11)),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${dates.length} date${dates.length == 1 ? '' : 's'} selected', style: const TextStyle(fontFamily: 'Manrope', color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(
                  dates.length == 1 ? _shortDate(dates.first) : '${_shortDate(dates.first)} → ${_shortDate(dates.last)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Manrope', color: Color(0xFFB8C1BE), fontSize: 9, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _openBulkEditor(initialDates: _selectedDates),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('Edit Prices'),
          ),
        ],
      ),
    );
  }

  Widget _quickActions() {
    return Row(
      children: [
        Expanded(
          child: _actionButton(
            icon: Icons.weekend_rounded,
            title: 'Weekend Rule',
            subtitle: 'Sat + Sun',
            onTap: _weekendRule,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _actionButton(
            icon: Icons.date_range_rounded,
            title: 'Date Range',
            subtitle: 'Select dates',
            onTap: () => _openBulkEditor(),
          ),
        ),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: softAccent, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: primary, size: 19),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontFamily: 'Manrope', fontSize: 10.5, fontWeight: FontWeight.w900, color: heading)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontFamily: 'Manrope', fontSize: 8.5, fontWeight: FontWeight.w600, color: muted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 18, color: muted),
          ],
        ),
      ),
    );
  }

  Future<void> _weekendRule() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 3, 12, 31),
      initialDateRange: DateTimeRange(
        start: DateTime(_visibleMonth.year, _visibleMonth.month, 1),
        end: DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0),
      ),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: primary, surface: card),
        ),
        child: child!,
      ),
    );
    if (range == null || !mounted) return;

    final dates = <DateTime>{};
    var cursor = _dateOnly(range.start);
    final end = _dateOnly(range.end);
    while (!cursor.isAfter(end)) {
      if (cursor.weekday == DateTime.saturday || cursor.weekday == DateTime.sunday) {
        dates.add(cursor);
      }
      cursor = cursor.add(const Duration(days: 1));
    }

    if (dates.isEmpty) {
      _showSnack('No Saturday or Sunday exists in the selected range.', error: true);
      return;
    }

    await _openBulkEditor(
      initialDates: dates,
      title: 'Weekend Price Rule',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Pricing Calendar',
          style: TextStyle(fontFamily: 'Manrope', fontSize: 20, fontWeight: FontWeight.w900, color: heading),
        ),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: 18),
              child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
        children: [
          _topSummary(),
          const SizedBox(height: 13),
          _rentalToggle(),
          const SizedBox(height: 13),
          _packageStrip(),
          const SizedBox(height: 14),
          _quickActions(),
          const SizedBox(height: 14),
          _calendarHeader(),
          _calendarGrid(),
          const SizedBox(height: 10),
          _selectionBar(),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F5F3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 17, color: primary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Prices are saved on the shared pricing profile. Customer and admin booking calculations continue using the same date-by-date PricingProfile.priceFor() logic.',
                    style: TextStyle(fontFamily: 'Manrope', fontSize: 9.5, height: 1.35, fontWeight: FontWeight.w600, color: body),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _BulkMode { adjustment, exact }

class _BulkEditResult {
  final Set<DateTime> dates;
  final Set<String> selectedPackageIds;
  final _BulkMode mode;
  final double adjustment;
  final double exactPrice;
  final String reason;

  const _BulkEditResult({
    required this.dates,
    required this.selectedPackageIds,
    required this.mode,
    required this.adjustment,
    required this.exactPrice,
    required this.reason,
  });
}

class _BulkEditSheet extends StatefulWidget {
  final String title;
  final List<KmPricingPackage> packages;
  final RentalType rentalType;
  final Set<DateTime> initialDates;
  final bool forceDateSelection;
  final DateTime month;
  final PricingProfile profile;
  final double Function(DateTime, KmPricingPackage) basePrice;

  const _BulkEditSheet({
    required this.title,
    required this.packages,
    required this.rentalType,
    required this.initialDates,
    required this.forceDateSelection,
    required this.month,
    required this.profile,
    required this.basePrice,
  });

  @override
  State<_BulkEditSheet> createState() => _BulkEditSheetState();
}

class _BulkEditSheetState extends State<_BulkEditSheet> {
  static const Color background = Color(0xFFF8FAF9);
  static const Color card = Color(0xFFFFFFFF);
  static const Color primary = Color(0xFF0F766E);
  static const Color softAccent = Color(0xFFE6FFFB);
  static const Color heading = Color(0xFF17201F);
  static const Color body = Color(0xFF66706E);
  static const Color muted = Color(0xFF94A09D);
  static const Color border = Color(0xFFE5EBE9);

  late Set<DateTime> _dates;
  late Set<String> _packages;
  _BulkMode _mode = _BulkMode.adjustment;
  final _amountController = TextEditingController(text: '200');
  final _reasonController = TextEditingController();
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  bool _allPackages = true;

  @override
  void initState() {
    super.initState();
    _dates = widget.initialDates.map(_dateOnly).toSet();
    _packages = widget.packages.map((p) => p.id).toSet();
    _reasonController.text = widget.title.contains('Weekend')
        ? 'Weekend +₹${_amountController.text}'
        : 'Calendar price adjustment';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  String _money(double value) {
    if (value == value.roundToDouble()) return '₹${value.toInt()}';
    return '₹${value.toStringAsFixed(0)}';
  }

  String _shortDate(DateTime date) => '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3, 12, 31),
      initialDateRange: _rangeStart != null && _rangeEnd != null
          ? DateTimeRange(start: _rangeStart!, end: _rangeEnd!)
          : DateTimeRange(
              start: DateTime(widget.month.year, widget.month.month, 1),
              end: DateTime(widget.month.year, widget.month.month + 1, 0),
            ),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: primary, surface: card),
        ),
        child: child!,
      ),
    );
    if (result == null) return;

    final selected = <DateTime>{};
    var cursor = _dateOnly(result.start);
    final end = _dateOnly(result.end);
    while (!cursor.isAfter(end)) {
      selected.add(cursor);
      cursor = cursor.add(const Duration(days: 1));
    }

    setState(() {
      _rangeStart = _dateOnly(result.start);
      _rangeEnd = _dateOnly(result.end);
      _dates = selected;
    });
  }

  Future<void> _pickWeekdays() async {
    final weekdays = <int>{};
    final labels = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    final selected = await showDialog<Set<int>>(
      context: context,
      builder: (context) {
        final local = <int>{DateTime.saturday, DateTime.sunday};
        return StatefulBuilder(
          builder: (context, setLocal) => AlertDialog(
            title: const Text('Choose weekdays'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(7, (index) {
                final weekday = index + 1;
                return CheckboxListTile(
                  dense: true,
                  value: local.contains(weekday),
                  title: Text(labels[index]),
                  onChanged: (value) {
                    setLocal(() {
                      if (value == true) {
                        local.add(weekday);
                      } else {
                        local.remove(weekday);
                      }
                    });
                  },
                );
              }),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(onPressed: () => Navigator.pop(context, local), child: const Text('Apply')),
            ],
          ),
        );
      },
    );

    if (selected == null || selected.isEmpty) return;
    weekdays.addAll(selected);

    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 3, 12, 31),
      initialDateRange: DateTimeRange(
        start: DateTime(widget.month.year, widget.month.month, 1),
        end: DateTime(widget.month.year, widget.month.month + 1, 0),
      ),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: primary, surface: card)),
        child: child!,
      ),
    );
    if (range == null) return;

    final dates = <DateTime>{};
    var cursor = _dateOnly(range.start);
    final end = _dateOnly(range.end);
    while (!cursor.isAfter(end)) {
      if (weekdays.contains(cursor.weekday)) dates.add(cursor);
      cursor = cursor.add(const Duration(days: 1));
    }

    setState(() {
      _rangeStart = _dateOnly(range.start);
      _rangeEnd = _dateOnly(range.end);
      _dates = dates;
    });
  }

  String _previewText() {
    if (_dates.isEmpty) return 'No dates selected';
    final list = _dates.toList()..sort();
    if (list.length == 1) return _shortDate(list.first);
    return '${_shortDate(list.first)} → ${_shortDate(list.last)} • ${list.length} dates';
  }

  void _submit() {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || !amount.isFinite) return;
    if (_dates.isEmpty || _packages.isEmpty) return;

    Navigator.pop(
      context,
      _BulkEditResult(
        dates: _dates,
        selectedPackageIds: _packages,
        mode: _mode,
        adjustment: _mode == _BulkMode.adjustment ? amount : 0,
        exactPrice: _mode == _BulkMode.exact ? amount : 0,
        reason: _reasonController.text.trim().isEmpty
            ? 'Calendar price adjustment'
            : _reasonController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 780),
          decoration: const BoxDecoration(
            color: background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(width: 44, height: 5, decoration: BoxDecoration(color: border, borderRadius: BorderRadius.circular(20))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 17, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(widget.title, style: const TextStyle(fontFamily: 'Manrope', fontSize: 19, fontWeight: FontWeight.w900, color: heading)),
                    ),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  children: [
                    _sectionLabel('1. Dates'),
                    const SizedBox(height: 8),
                    if (!widget.forceDateSelection)
                      Row(
                        children: [
                          Expanded(child: _choiceButton('Date range', Icons.date_range_rounded, _pickRange)),
                          const SizedBox(width: 8),
                          Expanded(child: _choiceButton('Weekdays', Icons.event_repeat_rounded, _pickWeekdays)),
                        ],
                      ),
                    if (!widget.forceDateSelection) const SizedBox(height: 9),
                    _infoBox(Icons.calendar_month_rounded, _previewText()),
                    const SizedBox(height: 18),
                    _sectionLabel('2. Packages'),
                    const SizedBox(height: 8),
                    _packageSelector(),
                    const SizedBox(height: 18),
                    _sectionLabel('3. Price action'),
                    const SizedBox(height: 8),
                    _modeToggle(),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      decoration: InputDecoration(
                        labelText: _mode == _BulkMode.adjustment ? 'Adjustment amount' : 'New price',
                        prefixText: '₹ ',
                        helperText: _mode == _BulkMode.adjustment
                            ? 'Use +200 to increase or -200 to decrease.'
                            : 'The selected packages will use this exact price.',
                        filled: true,
                        fillColor: card,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: border)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _sectionLabel('4. Label / reason'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _reasonController,
                      decoration: InputDecoration(
                        labelText: 'Example: Weekend +₹200',
                        filled: true,
                        fillColor: card,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: border)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _previewCard(),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 53,
                      child: ElevatedButton.icon(
                        onPressed: _submit,
                        icon: const Icon(Icons.check_rounded),
                        label: Text(_mode == _BulkMode.adjustment ? 'Apply Price Adjustment' : 'Set New Price'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(text, style: const TextStyle(fontFamily: 'Manrope', fontSize: 12, fontWeight: FontWeight.w900, color: heading));

  Widget _choiceButton(String title, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(15), border: Border.all(color: border)),
        child: Row(children: [Icon(icon, size: 17, color: primary), const SizedBox(width: 7), Expanded(child: Text(title, style: const TextStyle(fontFamily: 'Manrope', fontSize: 10, fontWeight: FontWeight.w800, color: heading))), const Icon(Icons.chevron_right_rounded, size: 17, color: muted)]),
      ),
    );
  }

  Widget _infoBox(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: softAccent, borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFFBFEDE6))),
      child: Row(children: [Icon(icon, size: 17, color: primary), const SizedBox(width: 8), Expanded(child: Text(text, style: const TextStyle(fontFamily: 'Manrope', fontSize: 10, fontWeight: FontWeight.w800, color: heading)))]),
    );
  }

  Widget _packageSelector() {
    return Column(
      children: [
        CheckboxListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          dense: true,
          value: _allPackages,
          title: const Text('All packages', style: TextStyle(fontFamily: 'Manrope', fontSize: 11, fontWeight: FontWeight.w800)),
          subtitle: const Text('Apply to every package in this rental mode', style: TextStyle(fontFamily: 'Manrope', fontSize: 8.5, color: muted)),
          onChanged: (value) {
            setState(() {
              _allPackages = value == true;
              _packages = _allPackages ? widget.packages.map((p) => p.id).toSet() : <String>{};
            });
          },
          activeColor: primary,
        ),
        if (!_allPackages)
          ...widget.packages.map(
            (package) => CheckboxListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              dense: true,
              value: _packages.contains(package.id),
              title: Text(package.name, style: const TextStyle(fontFamily: 'Manrope', fontSize: 10.5, fontWeight: FontWeight.w800)),
              subtitle: Text('${package.unlimitedKm ? 'Unlimited KM' : '${package.safeIncludedKm} KM'} • ${_money(package.rateFor(widget.rentalType.value))}${widget.rentalType == RentalType.hourly ? '/h' : '/day'}', style: const TextStyle(fontFamily: 'Manrope', fontSize: 8.5, color: muted)),
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _packages.add(package.id);
                  } else {
                    _packages.remove(package.id);
                  }
                  _allPackages = _packages.length == widget.packages.length;
                });
              },
              activeColor: primary,
            ),
          ),
      ],
    );
  }

  Widget _modeToggle() {
    return Row(
      children: [
        Expanded(child: _modeButton(_BulkMode.adjustment, 'Adjust', '+ / - amount')),
        const SizedBox(width: 8),
        Expanded(child: _modeButton(_BulkMode.exact, 'Set exact', 'Replace price')),
      ],
    );
  }

  Widget _modeButton(_BulkMode mode, String title, String subtitle) {
    final selected = _mode == mode;
    return InkWell(
      onTap: () => setState(() => _mode = mode),
      borderRadius: BorderRadius.circular(15),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: selected ? softAccent : card, borderRadius: BorderRadius.circular(15), border: Border.all(color: selected ? primary : border, width: selected ? 1.4 : 1)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontFamily: 'Manrope', fontSize: 10.5, fontWeight: FontWeight.w900, color: selected ? primary : heading)), const SizedBox(height: 2), Text(subtitle, style: const TextStyle(fontFamily: 'Manrope', fontSize: 8.5, color: muted, fontWeight: FontWeight.w600))]),
      ),
    );
  }

  Widget _previewCard() {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final first = widget.packages.where((p) => _packages.contains(p.id)).take(2).toList();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(17), border: Border.all(color: border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Preview', style: TextStyle(fontFamily: 'Manrope', fontSize: 11, fontWeight: FontWeight.w900, color: heading)),
          const SizedBox(height: 8),
          Text('${_dates.length} date${_dates.length == 1 ? '' : 's'} • ${_packages.length} package${_packages.length == 1 ? '' : 's'}', style: const TextStyle(fontFamily: 'Manrope', fontSize: 9, color: muted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 9),
          ...first.map((package) {
            final base = widget.basePrice(_dates.isEmpty ? DateTime.now() : _dates.first, package);
            final result = _mode == _BulkMode.adjustment ? base + amount : amount;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(child: Text(package.name, style: const TextStyle(fontFamily: 'Manrope', fontSize: 10, fontWeight: FontWeight.w800, color: heading))),
                  Text('${_money(base)} → ${_money(result)}', style: const TextStyle(fontFamily: 'Manrope', fontSize: 10, fontWeight: FontWeight.w900, color: primary)),
                ],
              ),
            );
          }),
          if (_packages.length > 2)
            Text('+ ${_packages.length - 2} more packages', style: const TextStyle(fontFamily: 'Manrope', fontSize: 8.5, color: muted, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
