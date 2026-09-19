import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../../cars/models/car.dart';
import '../../../cars/services/car_service.dart';
import '../../../pricing/models/pricing_profile.dart';
import '../../../pricing/services/pricing_profile_service.dart';
import 'admin_add_pricing_profile_screen.dart';
import 'admin_edit_pricing_profile_screen.dart';

class AdminPricingProfilesScreen extends StatefulWidget {
  const AdminPricingProfilesScreen({
    super.key,
  });

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

  final PricingProfileService _pricingService =
      PricingProfileService.instance;

  final CarService _carService =
      CarService.instance;

  final TextEditingController _searchController =
      TextEditingController();

  final Map<String, String> _vehicleNames = {};

  List<PricingProfile> _profiles = [];
  List<PricingProfile> _filteredProfiles = [];

  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;

  String get tenantId => AppConfig.tenant.tenantId;

  @override
  void initState() {
    super.initState();

    _searchController.addListener(
      _applySearch,
    );

    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData({
    bool refresh = false,
  }) async {
    if (refresh) {
      setState(() {
        _isRefreshing = true;
      });
    } else {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final results = await Future.wait([
        _pricingService.getAllPricingProfiles(
          tenantId: tenantId,
        ),
        _carService.getAllCars(
          tenantId: tenantId,
        ),
      ]);

      final profiles =
          results[0] as List<PricingProfile>;

      final cars =
          results[1] as List<Car>;

      final vehicleNames = <String, String>{};

      for (final car in cars) {
        vehicleNames[car.id] = car.name;
      }

      if (!mounted) return;

      setState(() {
        _profiles = profiles;
        _vehicleNames
          ..clear()
          ..addAll(vehicleNames);
        _errorMessage = null;
        _isLoading = false;
        _isRefreshing = false;
      });

      _applySearch();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage =
            e.toString().replaceFirst(
                  'Exception: ',
                  '',
                );
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  void _applySearch() {
    final query =
        _searchController.text.trim().toLowerCase();

    final filtered = _profiles.where((profile) {
      if (query.isEmpty) {
        return true;
      }

      final vehicleName =
          _vehicleNames[profile.vehicleId] ?? '';

      final rentalTypes = _enabledRentalTypes(profile)
          .map(_rentalTypeLabel)
          .join(' ');

      return profile.name
              .toLowerCase()
              .contains(query) ||
          profile.vehicleId
              .toLowerCase()
              .contains(query) ||
          vehicleName
              .toLowerCase()
              .contains(query) ||
          profile.currency
              .toLowerCase()
              .contains(query) ||
          rentalTypes.toLowerCase().contains(query) ||
          'v${profile.pricingVersion}'.contains(query) ||
          _specialRulesLabel(profile).toLowerCase().contains(query);
    }).toList();

    if (!mounted) return;

    setState(() {
      _filteredProfiles = filtered;
    });
  }

  int get _activeCount {
    return _profiles
        .where((profile) => profile.isActive)
        .length;
  }

  int get _inactiveCount {
    return _profiles
        .where((profile) => !profile.isActive)
        .length;
  }

  Future<void> _addPricingProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const AdminAddPricingProfileScreen(),
      ),
    );

    if (result == true && mounted) {
      await _loadData(
        refresh: true,
      );
    }
  }

  Future<void> _editPricingProfile(
    PricingProfile profile,
  ) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AdminEditPricingProfileScreen(
          profile: profile,
        ),
      ),
    );

    if (result == true && mounted) {
      await _loadData(
        refresh: true,
      );
    }
  }

  Future<void> _toggleProfile(
    PricingProfile profile,
  ) async {
    final activating = !profile.isActive;

    final action =
        activating ? 'activate' : 'deactivate';

    final confirmed =
        await _showConfirmationDialog(
      title: activating
          ? 'Activate pricing?'
          : 'Deactivate pricing?',
      message: activating
          ? 'This pricing profile will become available for the vehicle.'
          : 'This pricing profile will no longer be used for new bookings.',
      confirmLabel:
          activating ? 'Activate' : 'Deactivate',
    );

    if (!confirmed || !mounted) {
      return;
    }

    try {
      if (activating) {
        await _pricingService
            .activatePricingProfile(
          tenantId: tenantId,
          pricingProfileId: profile.id,
        );
      } else {
        await _pricingService
            .deactivatePricingProfile(
          tenantId: tenantId,
          pricingProfileId: profile.id,
        );
      }

      if (!mounted) return;

      _showSnackBar(
        activating
            ? 'Pricing profile activated.'
            : 'Pricing profile deactivated.',
      );

      await _loadData(
        refresh: true,
      );
    } catch (e) {
      if (!mounted) return;

      _showSnackBar(
        'Unable to $action pricing profile.',
        isError: true,
      );
    }
  }

  Future<bool> _showConfirmationDialog({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: card,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: heading,
            ),
          ),
          content: Text(
            message,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 14,
              height: 1.5,
              color: body,
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
              onPressed: () =>
                  Navigator.pop(context, false),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  color: body,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(12),
                ),
              ),
              child: Text(
                confirmLabel,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  void _showSnackBar(
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor:
              isError ? Colors.red.shade700 : primary,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  String _vehicleName(
    PricingProfile profile,
  ) {
    return _vehicleNames[profile.vehicleId] ??
        'Vehicle not found';
  }

  String _formatMoney(
    double value,
  ) {
    final rounded = value.round();

    final currency =
        AppConfig.tenant.business.currency.trim().isEmpty
            ? 'INR'
            : AppConfig.tenant.business.currency.trim().toUpperCase();

    final symbol = _currencySymbol(currency);

    return '$symbol${rounded.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]},',
        )}';
  }

  String _currencySymbol(String currency) {
    switch (currency) {
      case 'INR':
        return '₹';
      case 'USD':
        return r'$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'AED':
        return 'د.إ ';
      case 'SAR':
        return '﷼ ';
      default:
        return '$currency ';
    }
  }

  String _kmModeLabel(
    KmPricingMode mode,
  ) {
    switch (mode) {
      case KmPricingMode.included:
        return 'Included KM';
      case KmPricingMode.perKm:
        return 'Per KM';
      case KmPricingMode.unlimited:
        return 'Unlimited KM';
      case KmPricingMode.package:
        return 'KM Packages';
      case KmPricingMode.slabs:
        return 'KM Slabs';
    }
  }

  IconData _kmModeIcon(
    KmPricingMode mode,
  ) {
    switch (mode) {
      case KmPricingMode.included:
        return Icons.route_outlined;
      case KmPricingMode.perKm:
        return Icons.speed_outlined;
      case KmPricingMode.unlimited:
        return Icons.all_inclusive;
      case KmPricingMode.package:
        return Icons.inventory_2_outlined;
      case KmPricingMode.slabs:
        return Icons.stacked_bar_chart_outlined;
    }
  }


  String _rentalTypeLabel(RentalType type) {
    switch (type) {
      case RentalType.hourly:
        return 'Hourly';
      case RentalType.daily:
        return 'Daily';
      case RentalType.weekend:
        return 'Weekend';
    }
  }

  IconData _rentalTypeIcon(RentalType type) {
    switch (type) {
      case RentalType.hourly:
        return Icons.schedule_outlined;
      case RentalType.daily:
        return Icons.today_outlined;
      case RentalType.weekend:
        return Icons.weekend_outlined;
    }
  }

  List<RentalType> _enabledRentalTypes(PricingProfile profile) {
    final types = <RentalType>[];
    for (final type in RentalType.values) {
      if (profile.isRentalTypeEnabled(type)) {
        types.add(type);
      }
    }
    return types;
  }

  String _pricingVersionLabel(PricingProfile profile) {
    return 'v${profile.pricingVersion}';
  }

  String _specialRulesLabel(PricingProfile profile) {
    final count = profile.specialPricingRules
        .where((rule) => rule.enabled)
        .length;
    return '$count special rule${count == 1 ? '' : 's'}';
  }

  String _depositSummary(PricingProfile profile) {
    final config = profile.depositConfig;
    if (!config.required) return 'No deposit';
    return 'Deposit ${_formatMoney(config.defaultAmount)}';
  }

  Future<void> _deletePricingProfile(PricingProfile profile) async {
    final confirmed = await _showConfirmationDialog(
      title: 'Delete pricing profile?',
      message:
          'This will permanently delete this pricing profile. Existing bookings keep their stored pricing snapshots.',
      confirmLabel: 'Delete',
    );

    if (!confirmed || !mounted) return;

    try {
      await _pricingService.deletePricingProfile(
        tenantId: tenantId,
        pricingProfileId: profile.id,
      );

      if (!mounted) return;
      _showSnackBar('Pricing profile deleted.');
      await _loadData(refresh: true);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    }
  }

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
          if (_isRefreshing)
            const Padding(
              padding: EdgeInsets.only(
                right: 20,
              ),
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
              onPressed: () =>
                  _loadData(refresh: true),
              icon: const Icon(
                Icons.refresh_rounded,
                color: heading,
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton:
          FloatingActionButton.extended(
        onPressed: _addPricingProfile,
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(
          Icons.add_rounded,
        ),
        label: const Text(
          'Add Pricing',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: primary,
                ),
              )
            : _errorMessage != null
                ? _buildErrorState()
                : RefreshIndicator(
                    color: primary,
                    onRefresh: () =>
                        _loadData(refresh: true),
                    child: ListView(
                      physics:
                          const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        20,
                        4,
                        20,
                        110,
                      ),
                      children: [
                        _buildIntro(),
                        const SizedBox(height: 18),
                        _buildStats(),
                        const SizedBox(height: 20),
                        _buildSearch(),
                        const SizedBox(height: 18),
                        if (_filteredProfiles.isEmpty)
                          _buildEmptyState()
                        else
                          ..._filteredProfiles.map(
                            _buildPricingCard,
                          ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildIntro() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.035,
            ),
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
              borderRadius:
                  BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.payments_outlined,
              color: primary,
              size: 25,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Vehicle Pricing',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: heading,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Manage rates, KM rules, deposits and pricing packages.',
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

  Widget _buildStats() {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            label: 'Total',
            value: _profiles.length.toString(),
            icon: Icons.price_change_outlined,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statCard(
            label: 'Active',
            value: _activeCount.toString(),
            icon: Icons.check_circle_outline,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statCard(
            label: 'Inactive',
            value: _inactiveCount.toString(),
            icon: Icons.pause_circle_outline,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statCard(
            label: 'Special',
            value: _profiles.fold<int>(
              0,
              (sum, profile) =>
                  sum +
                  profile.specialPricingRules
                      .where((rule) => rule.enabled)
                      .length,
            ).toString(),
            icon: Icons.event_available_outlined,
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: border,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: primary,
            size: 20,
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: heading,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return TextField(
      controller: _searchController,
      style: const TextStyle(
        fontFamily: 'Manrope',
        fontSize: 14,
        color: heading,
      ),
      decoration: InputDecoration(
        hintText:
            'Search pricing or vehicle...',
        hintStyle: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 13,
          color: muted,
        ),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: muted,
        ),
        suffixIcon:
            _searchController.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () =>
                        _searchController.clear(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: muted,
                    ),
                  ),
        filled: true,
        fillColor: card,
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: border,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: primary,
            width: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildPricingCard(
    PricingProfile profile,
  ) {
    final vehicleName =
        _vehicleName(profile);

    return Container(
      margin: const EdgeInsets.only(
        bottom: 14,
      ),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.03,
            ),
            blurRadius: 15,
            offset: const Offset(0, 6),
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
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: softAccent,
                  borderRadius:
                      BorderRadius.circular(14),
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
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: heading,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      vehicleName,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: body,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      profile.id,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 10.5,
                        color: muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _statusBadge(
                profile.isActive,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
            decoration: BoxDecoration(
              color: background,
              borderRadius:
                  BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _rateItem(
                    label: 'Hourly',
                    value:
                        _formatMoney(
                      profile.hourlyRate,
                    ),
                  ),
                ),
                _verticalDivider(),
                Expanded(
                  child: _rateItem(
                    label: 'Daily',
                    value:
                        _formatMoney(
                      profile.dailyRate,
                    ),
                  ),
                ),
                _verticalDivider(),
                Expanded(
                  child: _rateItem(
                    label: 'Weekly',
                    value:
                        _formatMoney(
                      profile.weeklyRate,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _infoChip(
                icon: _kmModeIcon(
                  profile.kmPricingMode,
                ),
                text: _kmModeLabel(
                  profile.kmPricingMode,
                ),
              ),
              if (profile.includedKmPerDay > 0)
                _infoChip(
                  icon: Icons.route_outlined,
                  text:
                      '${profile.includedKmPerDay} KM/day',
                ),
              if (profile.securityDeposit > 0)
                _infoChip(
                  icon:
                      Icons.account_balance_wallet_outlined,
                  text:
                      'Deposit ${_formatMoney(profile.securityDeposit)}',
                ),
              if (profile.kmPackages.isNotEmpty)
                _infoChip(
                  icon: Icons.inventory_2_outlined,
                  text: '${profile.kmPackages.length} packages',
                ),
              _infoChip(
                icon: Icons.layers_outlined,
                text: _pricingVersionLabel(profile),
              ),
              _infoChip(
                icon: Icons.event_available_outlined,
                text: _specialRulesLabel(profile),
              ),
              _infoChip(
                icon: Icons.account_balance_wallet_outlined,
                text: _depositSummary(profile),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: _enabledRentalTypes(profile)
                .map(
                  (type) => _rentalTypeChip(
                    type,
                    profile.rentalPricingFor(type),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 17),
          const Divider(
            height: 1,
            color: border,
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _editPricingProfile(profile),
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
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _toggleProfile(profile),
                  icon: Icon(
                    profile.isActive
                        ? Icons.pause_outlined
                        : Icons.check_rounded,
                    size: 17,
                  ),
                  label: Text(
                    profile.isActive ? 'Deactivate' : 'Activate',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        profile.isActive ? heading : primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: 'Manrope',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 46,
                height: 44,
                child: OutlinedButton(
                  onPressed: () => _deletePricingProfile(profile),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(color: Colors.red.shade100),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    size: 19,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rateItem({
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: muted,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: heading,
          ),
        ),
      ],
    );
  }

  Widget _verticalDivider() {
    return Container(
      width: 1,
      height: 32,
      margin:
          const EdgeInsets.symmetric(
        horizontal: 7,
      ),
      color: border,
    );
  }

  Widget _statusBadge(
    bool isActive,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: isActive
            ? softAccent
            : background,
        borderRadius:
            BorderRadius.circular(30),
        border: Border.all(
          color: isActive
              ? accent.withValues(
                  alpha: 0.25,
                )
              : border,
        ),
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isActive
                  ? accent
                  : muted,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isActive ? 'Active' : 'Inactive',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: isActive
                  ? primary
                  : body,
            ),
          ),
        ],
      ),
    );
  }

  Widget _rentalTypeChip(
    RentalType type,
    RentalTypePricing pricing,
  ) {
    final enabled = pricing.enabled;
    final rate = pricing.rate;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: enabled ? softAccent : background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: enabled ? accent.withValues(alpha: 0.22) : border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _rentalTypeIcon(type),
            size: 13,
            color: enabled ? primary : muted,
          ),
          const SizedBox(width: 5),
          Text(
            '${_rentalTypeLabel(type)} ${rate > 0 ? _formatMoney(rate) : 'Configured'}',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: enabled ? primary : body,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip({
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius:
            BorderRadius.circular(10),
        border: Border.all(
          color: border,
        ),
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: primary,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: body,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasSearch =
        _searchController.text.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: card,
        borderRadius:
            BorderRadius.circular(22),
        border: Border.all(
          color: border,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: softAccent,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.price_change_outlined,
              color: primary,
              size: 29,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            hasSearch
                ? 'No pricing found'
                : 'No pricing profiles yet',
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: heading,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            hasSearch
                ? 'Try another pricing profile or vehicle name.'
                : 'Create your first vehicle pricing profile to get started.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12.5,
              height: 1.5,
              color: body,
            ),
          ),
          if (!hasSearch) ...[
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed:
                  _addPricingProfile,
              icon: const Icon(
                Icons.add_rounded,
                size: 18,
              ),
              label: const Text(
                'Add Pricing Profile',
              ),
              style:
                  ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 13,
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(12),
                ),
                textStyle:
                    const TextStyle(
                  fontFamily: 'Manrope',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.red.withValues(
                  alpha: 0.08,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons
                    .cloud_off_outlined,
                color: Colors.red.shade700,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
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
              _errorMessage ??
                  'Something went wrong.',
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
              onPressed: _loadData,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label: const Text(
                'Try Again',
              ),
              style:
                  ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}