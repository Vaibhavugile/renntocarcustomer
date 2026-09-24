import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../../pricing/models/pricing_profile.dart';
import '../../../pricing/services/pricing_profile_service.dart';
import 'admin_add_pricing_profile_screen.dart';
import 'admin_edit_pricing_profile_screen.dart';

/// Admin list for the simplified car-rental pricing model.
///
/// Pricing model:
/// - Hourly packages
/// - Daily packages
/// - Special date-range overrides
/// - Security deposit
///
/// No weekend / weekly / monthly rental types are used here.
class AdminPricingProfilesScreen extends StatefulWidget {
  const AdminPricingProfilesScreen({super.key});

  @override
  State<AdminPricingProfilesScreen> createState() =>
      _AdminPricingProfilesScreenState();
}

class _AdminPricingProfilesScreenState
    extends State<AdminPricingProfilesScreen> {
  static const Color background = Color(0xFFF8FAF9);
  static const Color card = Color(0xFFFFFFFF);
  static const Color primary = Color(0xFF0F766E);
  static const Color accent = Color(0xFF14B8A6);
  static const Color softAccent = Color(0xFFE6FFFB);
  static const Color heading = Color(0xFF17201F);
  static const Color body = Color(0xFF66706E);
  static const Color muted = Color(0xFF94A09D);
  static const Color border = Color(0xFFE5EBE9);

  final PricingProfileService _service = PricingProfileService.instance;
  final TextEditingController _searchController = TextEditingController();

  List<PricingProfile> _profiles = const [];
  List<PricingProfile> _filteredProfiles = const [];

  /// Number of cars currently pointing to each pricing profile.
  /// Loaded from the cars collection so the profile list reflects
  /// the new reusable-profile architecture.
  Map<String, int> _connectedCarCounts = const {};

  bool _loading = true;
  bool _refreshing = false;
  String? _error;

  String get tenantId => AppConfig.tenant.tenantId;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applySearch);
    _load();
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_applySearch)
      ..dispose();
    super.dispose();
  }

  Future<void> _load({bool refresh = false}) async {
    if (refresh) {
      if (mounted) setState(() => _refreshing = true);
    } else {
      if (mounted) {
        setState(() {
          _loading = true;
          _error = null;
        });
      }
    }

    try {
      final profiles = await _service.getAllPricingProfiles(
        tenantId: tenantId,
      );

      final counts = await _loadConnectedCarCounts(profiles);

      if (!mounted) return;

      setState(() {
        _profiles = profiles;
        _connectedCarCounts = counts;
        _loading = false;
        _refreshing = false;
        _error = null;
      });
      _applySearch();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _refreshing = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<Map<String, int>> _loadConnectedCarCounts(
    List<PricingProfile> profiles,
  ) async {
    final counts = <String, int>{
      for (final profile in profiles) profile.id.trim(): 0,
    };

    if (counts.isEmpty) return counts;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('tenants')
          .doc(tenantId)
          .collection('cars')
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final profileId =
            data['pricingProfileId']?.toString().trim() ?? '';

        if (profileId.isNotEmpty &&
            counts.containsKey(profileId)) {
          counts[profileId] =
              (counts[profileId] ?? 0) + 1;
        }
      }
    } catch (_) {
      // Connected-car count is supplementary. The profile list
      // remains usable if this optional read fails.
    }

    return counts;
  }

  int _connectedCars(PricingProfile profile) {
    return _connectedCarCounts[profile.id.trim()] ?? 0;
  }

  void _applySearch() {
    final q = _searchController.text.trim().toLowerCase();

    final result = _profiles.where((p) {
      if (q.isEmpty) return true;

      final haystack = <String>[
        p.id,
        p.name,
        p.tenantId,
        p.pricingGroupId,
        p.currency,
        ...p.hourlyPackages.map((x) => '${x.id} ${x.name}'),
        ...p.dailyPackages.map((x) => '${x.id} ${x.name}'),
        ...p.specialRates.map((x) => x.name),
        p.securityDeposit.type.label,
      ].join(' ').toLowerCase();

      return haystack.contains(q);
    }).toList(growable: false);

    if (mounted) {
      setState(() => _filteredProfiles = result);
    }
  }

  int get _activeCount => _profiles.where((p) => p.isActive).length;

  int get _inactiveCount => _profiles.length - _activeCount;

  int get _specialCount =>
      _profiles.fold<int>(0, (sum, p) => sum + p.specialRates.where((x) => x.isActive).length);

  int get _groupCount {
    final groups = _profiles
        .map((p) => p.pricingGroupId.trim())
        .where((x) => x.isNotEmpty)
        .toSet();
    return groups.length;
  }

  Future<void> _add() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AdminAddPricingProfileScreen(),
      ),
    );

    if (result == true && mounted) {
      await _load(refresh: true);
    }
  }

  Future<void> _edit(PricingProfile profile) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminEditPricingProfileScreen(profile: profile),
      ),
    );

    if (result == true && mounted) {
      await _load(refresh: true);
    }
  }

  Future<void> _toggle(PricingProfile profile) async {
    final activate = !profile.isActive;

    final confirmed = await _confirm(
      title: activate ? 'Activate pricing?' : 'Deactivate pricing?',
      message: activate
          ? 'This pricing profile will be available for new bookings.'
          : 'This pricing profile will no longer be available for new bookings.',
      confirmText: activate ? 'Activate' : 'Deactivate',
      destructive: !activate,
    );

    if (!confirmed || !mounted) return;

    try {
      if (activate) {
        await _service.activatePricingProfile(
          tenantId: tenantId,
          pricingProfileId: profile.id,
        );
      } else {
        await _service.deactivatePricingProfile(
          tenantId: tenantId,
          pricingProfileId: profile.id,
        );
      }

      _snack(
        activate ? 'Pricing profile activated.' : 'Pricing profile deactivated.',
      );
      await _load(refresh: true);
    } catch (e) {
      _snack(
        e.toString().replaceFirst('Exception: ', ''),
        error: true,
      );
    }
  }

  Future<void> _delete(PricingProfile profile) async {
    final confirmed = await _confirm(
      title: 'Delete pricing profile?',
      message:
          'This permanently deletes the saved pricing configuration. Existing bookings keep their own pricing snapshots.',
      confirmText: 'Delete',
      destructive: true,
    );

    if (!confirmed || !mounted) return;

    try {
      await _service.deletePricingProfile(
        tenantId: tenantId,
        pricingProfileId: profile.id,
      );

      _snack('Pricing profile deleted.');
      await _load(refresh: true);
    } catch (e) {
      _snack(
        e.toString().replaceFirst('Exception: ', ''),
        error: true,
      );
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmText,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: heading,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 13.5,
            height: 1.45,
            color: body,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Manrope',
                color: body,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: destructive ? heading : primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              confirmText,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;

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
          backgroundColor: error ? Colors.red.shade700 : primary,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
      );
  }

  String _currencySymbol(String currency) {
    switch (currency.toUpperCase()) {
      case 'INR':
        return '₹';
      case 'USD':
        return r'$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'AED':
        return 'د.إ';
      case 'SAR':
        return '﷼';
      default:
        return currency;
    }
  }

  String _money(double value, String currency) {
    final safe = value.isFinite && value >= 0 ? value : 0;
    final rounded = safe.round();
    final formatted = rounded.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return '${_currencySymbol(currency)}$formatted';
  }

  String _vehicleLabel(PricingProfile p) {
    if (p.vehicleId.trim().isEmpty) return 'Shared pricing group';
    return p.vehicleId;
  }

  String _depositLabel(PricingProfile p) {
    final d = p.securityDeposit;

    switch (d.type) {
      case DepositType.none:
        return 'No deposit';
      case DepositType.cash:
      case DepositType.online:
      case DepositType.bankTransfer:
        return '${d.type.label} ${_money(d.monetaryAmount, p.currency)}';
      case DepositType.vehicleAsset:
        return 'Customer bike';
      case DepositType.otherAsset:
        return 'Other asset';
    }
  }

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 20,
        title: const Text(
          'Pricing Profiles',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: heading,
          ),
        ),
        actions: [
          if (_refreshing)
            const Padding(
              padding: EdgeInsets.only(right: 20),
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
              onPressed: () => _load(refresh: true),
              icon: const Icon(
                Icons.refresh_rounded,
                color: heading,
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Add Pricing',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: primary),
              )
            : _error != null
                ? _errorState()
                : RefreshIndicator(
                    color: primary,
                    onRefresh: () => _load(refresh: true),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
                      children: [
                        _intro(),
                        const SizedBox(height: 16),
                        _stats(),
                        const SizedBox(height: 18),
                        _search(),
                        const SizedBox(height: 16),
                        if (_filteredProfiles.isEmpty)
                          _empty()
                        else
                          ..._filteredProfiles.map(_profileCard),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _intro() {
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: softAccent,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.price_change_outlined,
              color: primary,
              size: 25,
            ),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Simple Vehicle Pricing',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: heading,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Shared hourly and daily pricing for multiple cars, with special dates and security deposits.',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 12.5,
                    height: 1.4,
                    color: body,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stats() {
    final connectedCars =
        _connectedCarCounts.values.fold<int>(
      0,
      (sum, count) => sum + count,
    );

    return Row(
      children: [
        Expanded(
          child: _stat(
            'Profiles',
            '${_profiles.length}',
            Icons.price_change_outlined,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _stat(
            'Active',
            '$_activeCount',
            Icons.check_circle_outline,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _stat(
            'Cars',
            '$connectedCars',
            Icons.directions_car_outlined,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _stat(
            'Special',
            '$_specialCount',
            Icons.event_available_outlined,
          ),
        ),
      ],
    );
  }

  Widget _stat(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: primary),
          const SizedBox(height: 9),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: heading,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _search() {
    return TextField(
      controller: _searchController,
      style: const TextStyle(
        fontFamily: 'Manrope',
        fontSize: 14,
        color: heading,
      ),
      decoration: InputDecoration(
        hintText: 'Search profile, group or package...',
        hintStyle: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 13,
          color: muted,
        ),
        prefixIcon: const Icon(Icons.search_rounded, color: muted),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                onPressed: _searchController.clear,
                icon: const Icon(Icons.close_rounded, color: muted),
              ),
        filled: true,
        fillColor: card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primary, width: 1.2),
        ),
      ),
    );
  }

  Widget _profileCard(PricingProfile p) {
    final hourly = p.hourlyPackages.where((x) => x.isActive).toList();
    final daily = p.dailyPackages.where((x) => x.isActive).toList();
    final specials = p.specialRates.where((x) => x.isActive).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: softAccent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.directions_car_outlined,
                  color: primary,
                  size: 23,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: heading,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      p.pricingGroupId.trim().isEmpty
                          ? _vehicleLabel(p)
                          : 'Group: ${p.pricingGroupId}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: body,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      p.id,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 10.5,
                        color: muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _status(p.isActive),
            ],
          ),
          const SizedBox(height: 12),
          _connectionBanner(p),
          const SizedBox(height: 16),
          _packageSummary(
            title: 'Hourly',
            packages: hourly,
            currency: p.currency,
            empty: 'No hourly package',
          ),
          const SizedBox(height: 9),
          _packageSummary(
            title: 'Daily',
            packages: daily,
            currency: p.currency,
            empty: 'No daily package',
          ),
          const SizedBox(height: 13),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _chip(
                Icons.route_outlined,
                '${hourly.length + daily.length} packages',
              ),
              if (specials.isNotEmpty)
                _chip(
                  Icons.event_available_outlined,
                  '${specials.length} special',
                ),
              _chip(
                Icons.account_balance_wallet_outlined,
                _depositLabel(p),
              ),
              _chip(
                Icons.directions_car_outlined,
                '${_connectedCars(p)} connected',
              ),
            ],
          ),
          if (specials.isNotEmpty) ...[
            const SizedBox(height: 12),
            _specialPreview(specials, p.currency),
          ],
          const SizedBox(height: 16),
          const Divider(height: 1, color: border),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _edit(p),
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: heading,
                    side: const BorderSide(color: border),
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: 'Manrope',
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _toggle(p),
                  icon: Icon(
                    p.isActive
                        ? Icons.pause_outlined
                        : Icons.check_rounded,
                    size: 17,
                  ),
                  label: Text(p.isActive ? 'Deactivate' : 'Activate'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: p.isActive ? heading : primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: 'Manrope',
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 46,
                height: 44,
                child: OutlinedButton(
                  onPressed: () => _delete(p),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(color: Colors.red.shade100),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Icon(Icons.delete_outline_rounded, size: 19),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _connectionBanner(PricingProfile profile) {
    final count = _connectedCars(profile);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 11,
      ),
      decoration: BoxDecoration(
        color: count > 0 ? softAccent : background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: count > 0
              ? accent.withValues(alpha: 0.20)
              : border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: count > 0 ? card : Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              count > 0
                  ? Icons.directions_car_rounded
                  : Icons.link_off_rounded,
              size: 18,
              color: count > 0 ? primary : muted,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  count == 0
                      ? 'No cars connected'
                      : '$count car${count == 1 ? '' : 's'} connected',
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: heading,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  count == 0
                      ? 'Connect cars from Edit Pricing Profile.'
                      : 'All connected cars use this profile pricing.',
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: body,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 19,
            color: muted,
          ),
        ],
      ),
    );
  }

  Widget _packageSummary({
    required String title,
    required List<dynamic> packages,
    required String currency,
    required String empty,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: packages.isEmpty
          ? Row(
              children: [
                Icon(
                  title == 'Hourly'
                      ? Icons.schedule_outlined
                      : Icons.today_outlined,
                  size: 17,
                  color: muted,
                ),
                const SizedBox(width: 8),
                Text(
                  '$title  •  $empty',
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: muted,
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      title == 'Hourly'
                          ? Icons.schedule_outlined
                          : Icons.today_outlined,
                      size: 17,
                      color: primary,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: body,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${packages.length} package${packages.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: packages.take(4).map((raw) {
                    final package = raw as dynamic;
                    final rate = title == 'Hourly'
                        ? package.safeHourlyRate as double
                        : package.safeDailyRate as double;
                    final km = package.unlimitedKm as bool
                        ? 'Unlimited'
                        : '${package.safeIncludedKm} KM';
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: card,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: border),
                      ),
                      child: Text(
                        '${package.name}  ${_money(rate, currency)}  •  $km',
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: heading,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                if (packages.length > 4) ...[
                  const SizedBox(height: 6),
                  Text(
                    '+ ${packages.length - 4} more package${packages.length - 4 == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: primary,
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _specialPreview(List<SpecialRate> rates, String currency) {
    final first = rates.first;
    final hourly = first.hourlyPrices.length;
    final daily = first.dailyPrices.length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: softAccent,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: accent.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.event_available_outlined,
            color: primary,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${first.name}  •  ${_date(first.startDate)} - ${_date(first.endDate)}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: heading,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$hourly H / $daily D',
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _status(bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active ? softAccent : background,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: active ? accent.withValues(alpha: 0.25) : border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: active ? accent : muted,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            active ? 'Active' : 'Inactive',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: active ? primary : body,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13.5, color: primary),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: body,
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty() {
    final searched = _searchController.text.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: softAccent,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.price_change_outlined,
              color: primary,
              size: 29,
            ),
          ),
          const SizedBox(height: 15),
          Text(
            searched ? 'No pricing found' : 'No pricing profiles yet',
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: heading,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            searched
                ? 'Try another profile, group or package name.'
                : 'Create a reusable pricing profile, then connect one or many cars to it.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12.5,
              height: 1.5,
              color: body,
            ),
          ),
          if (!searched) ...[
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _add,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Pricing Profile'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontFamily: 'Manrope',
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_off_outlined,
                color: Colors.red.shade700,
                size: 28,
              ),
            ),
            const SizedBox(height: 15),
            const Text(
              'Unable to load pricing',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: heading,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Something went wrong.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 12.5,
                height: 1.5,
                color: body,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
