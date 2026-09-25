import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import 'package:customer_app_car_rental/features/cars/models/car.dart';
import '../../../models/branch.dart';
import '../../pricing/models/km_pricing_package.dart';
import '../../pricing/models/pricing_config.dart';
import '../../pricing/models/pricing_profile.dart';
import '../../pricing/manager/pricing_manager.dart';
import 'pricing_screen.dart';

class BranchSelectionScreen extends StatefulWidget {
  final Car car;
  final String tenantId;
  final DateTime pickupDateTime;
  final DateTime returnDateTime;
  final String rentalType;
  final PricingProfile pricingProfile;
  final KmPricingPackage selectedPackage;

  const BranchSelectionScreen({
    super.key,
    required this.car,
    required this.tenantId,
    required this.pickupDateTime,
    required this.returnDateTime,
    required this.rentalType,
    required this.pricingProfile,
    required this.selectedPackage,
  });

  @override
  State<BranchSelectionScreen> createState() =>
      _BranchSelectionScreenState();
}

class _BranchSelectionScreenState extends State<BranchSelectionScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Branch> _branches = [];
  String? _selectedBranchId;

  late PricingProfile _pricingProfile;
  late KmPricingPackage _selectedPackage;
  late RentalType _rentalType;
  bool _pricingReady = false;

  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isContinuing = false;
  String? _errorMessage;

  DateTime? _lastCheckedAt;

  // Fixed premium palette.
  static const Color primary = Color(0xFF0F766E);
  static const Color accent = Color(0xFF14B8A6);
  static const Color background = Color(0xFFF8FAF9);
  static const Color card = Color(0xFFFFFFFF);
  static const Color softAccent = Color(0xFFE6FFFB);
  static const Color heading = Color(0xFF17201F);
  static const Color body = Color(0xFF66706E);
  static const Color muted = Color(0xFF94A09D);
  static const Color border = Color(0xFFE5EBE9);

  String get _tenantId {
    final passedTenantId = widget.tenantId.trim();
    if (passedTenantId.isNotEmpty) return passedTenantId;
    return AppConfig.tenant.tenantId;
  }

  bool get _busy => _isLoading || _isRefreshing || _isContinuing;

  bool get _canContinue =>
      !_busy && _pricingReady && _selectedBranch != null;

  @override
  void initState() {
    super.initState();

    _pricingProfile = widget.pricingProfile;
    _selectedPackage = widget.selectedPackage;
    _rentalType =
        RentalType.fromString(widget.rentalType) ?? RentalType.daily;

    _pricingReady = _pricingProfile.getPackage(
          _selectedPackage.id,
          rentalType: _rentalType,
        ) !=
        null;

    _loadBranches();
  }

  Future<void> _loadBranches({bool preserveSelection = true}) async {
    if (!mounted) return;

    final previousSelection =
        preserveSelection ? _selectedBranchId : null;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final snapshot = await _firestore
          .collection('tenants')
          .doc(_tenantId)
          .collection('branches')
          .where('isActive', isEqualTo: true)
          .get();

      final branches = snapshot.docs
          .map(
            (doc) => Branch.fromMap(
              doc.id,
              doc.data(),
            ),
          )
          .where((branch) => branch.isActive)
          .toList();

      branches.sort(
        (a, b) => a.name.toLowerCase().compareTo(
              b.name.toLowerCase(),
            ),
      );

      String? selectedBranchId;

      // Preserve a valid selection after refresh.
      if (previousSelection != null &&
          branches.any((branch) => branch.id == previousSelection)) {
        selectedBranchId = previousSelection;
      } else if (branches.length == 1) {
        // If there is only one active branch, automatically select it.
        selectedBranchId = branches.first.id;
      }

      if (!mounted) return;

      setState(() {
        _branches = branches;
        _selectedBranchId = selectedBranchId;
        _isLoading = false;
        _lastCheckedAt = DateTime.now();
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _lastCheckedAt = DateTime.now();
        _errorMessage =
            'Unable to load pickup locations. Please try again.';
      });
    }
  }

  Future<void> _refreshBranches({bool showMessage = true}) async {
    if (_isRefreshing || _isContinuing) return;

    if (mounted) {
      setState(() {
        _isRefreshing = true;
        _errorMessage = null;
      });
    }

    await _loadBranches();

    if (!mounted) return;

    setState(() {
      _isRefreshing = false;
    });

    if (showMessage && _errorMessage == null && _branches.isNotEmpty) {
      _showSnackBar(
        'Pickup locations refreshed.',
        icon: Icons.sync_rounded,
      );
    } else if (showMessage && _errorMessage == null && _branches.isEmpty) {
      _showSnackBar(
        'No active pickup locations are available.',
        icon: Icons.location_off_outlined,
        isError: true,
      );
    }
  }

  Branch? get _selectedBranch {
    if (_selectedBranchId == null) return null;

    try {
      return _branches.firstWhere(
        (branch) => branch.id == _selectedBranchId,
      );
    } catch (_) {
      return null;
    }
  }

  Future<Branch> _revalidateSelectedBranch(String branchId) async {
    final branchDoc = await _firestore
        .collection('tenants')
        .doc(_tenantId)
        .collection('branches')
        .doc(branchId)
        .get();

    if (!branchDoc.exists || branchDoc.data() == null) {
      throw Exception('BRANCH_NOT_FOUND');
    }

    final branch = Branch.fromMap(
      branchDoc.id,
      branchDoc.data()!,
    );

    if (!branch.isActive) {
      throw Exception('BRANCH_INACTIVE');
    }

    return branch;
  }

  String _formatRate(double value) {
    if (value == value.roundToDouble()) return '₹${value.toInt()}';
    return '₹${value.toStringAsFixed(0)}';
  }

  String get _packagePriceText {
    final price = _pricingProfile.priceFor(
      rentalType: _rentalType,
      package: _selectedPackage,
      date: widget.pickupDateTime,
    );
    return _rentalType == RentalType.hourly
        ? '${_formatRate(price)} / hour'
        : '${_formatRate(price)} / day';
  }

  Widget _buildBookingSummary() {
    final duration =
        widget.returnDateTime.difference(widget.pickupDateTime);
    final minutes = duration.inMinutes.clamp(0, 100000000);
    final days = minutes ~/ (24 * 60);
    final remaining = minutes % (24 * 60);
    final hours = remaining ~/ 60;
    final mins = remaining % 60;

    final durationText = _rentalType == RentalType.hourly
        ? '${(minutes / 60).ceil()} hour${(minutes / 60).ceil() == 1 ? '' : 's'}'
        : [
            if (days > 0) '$days day${days == 1 ? '' : 's'}',
            if (hours > 0) '$hours hr',
            if (mins > 0) '$mins min',
          ].join(' + ');

    final kmText = _selectedPackage.unlimitedKm
        ? 'Unlimited KM'
        : '${_selectedPackage.includedKm ?? 0} KM included';

    final extraKmText =
        _selectedPackage.unlimitedKm ||
                _selectedPackage.extraKmRate <= 0
            ? null
            : '${_formatRate(_selectedPackage.extraKmRate)} / extra KM';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: softAccent,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.sell_rounded,
                  color: primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedPackage.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: heading,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_rentalType.label} • $_packagePriceText',
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: primary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.verified_rounded,
                color: primary,
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _summaryChip(kmText),
              if (extraKmText != null) _summaryChip(extraKmText),
              _summaryChip(
                durationText.isEmpty
                    ? 'Selected duration'
                    : durationText,
              ),
            ],
          ),
          const SizedBox(height: 9),
          const Text(
            'The selected package will be used for the final pricing calculation.',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: body,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: border),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          color: body,
        ),
      ),
    );
  }

  bool _packageSupportsRentalType(
    KmPricingPackage package,
    RentalType type,
  ) {
    switch (type) {
      case RentalType.hourly:
        return package.supportsHourly;
      case RentalType.daily:
        return package.supportsDaily;
    }
  }

  Future<void> _continue() async {
    final selected = _selectedBranch;

    if (selected == null) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Please select a pickup location to continue.';
      });
      return;
    }

    if (_isContinuing) return;

    setState(() {
      _isContinuing = true;
      _errorMessage = null;
    });

    try {
      // Re-check the selected branch immediately before moving forward.
      // This prevents a stale branch from being used if an admin changed
      // its active status while the customer was on this screen.
      final branch = await _revalidateSelectedBranch(selected.id);

      if (!mounted) return;

      // Keep the local list synchronized with the server-side truth.
      final refreshedBranches = List<Branch>.from(_branches);
      final index = refreshedBranches.indexWhere(
        (item) => item.id == branch.id,
      );

      if (index >= 0) {
        refreshedBranches[index] = branch;
      }

      setState(() {
        _branches = refreshedBranches;
        _selectedBranchId = branch.id;
        _isContinuing = false;
        _lastCheckedAt = DateTime.now();
      });

      final freshProfile =
          await PricingManager.instance.loadPricingForCar(
        tenantId: _tenantId,
        pricingProfileId: widget.car.pricingProfileId,
      );

      if (!mounted) return;

      if (freshProfile == null || !freshProfile.isActive) {
        setState(() {
          _isContinuing = false;
          _pricingReady = false;
          _errorMessage =
              'This vehicle pricing is no longer available. Please go back and try again.';
        });
        return;
      }

      final freshPackage = freshProfile.getPackage(
        _selectedPackage.id,
        rentalType: _rentalType,
      );

      if (freshPackage == null || !freshPackage.isActive) {
        setState(() {
          _isContinuing = false;
          _pricingProfile = freshProfile;
          _pricingReady = false;
          _errorMessage =
              'The selected package is no longer available. Please go back and select another package.';
        });
        _showSnackBar(
          'The selected pricing package changed. Please review it again.',
          icon: Icons.sync_problem_rounded,
          isError: true,
        );
        return;
      }

      if (!_packageSupportsRentalType(freshPackage, _rentalType)) {
        setState(() {
          _isContinuing = false;
          _pricingReady = false;
          _errorMessage =
              'The selected package is not available for this rental type.';
        });
        return;
      }

      setState(() {
        _pricingProfile = freshProfile;
        _selectedPackage = freshPackage;
        _pricingReady = true;
        _isContinuing = false;
        _lastCheckedAt = DateTime.now();
      });

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PricingScreen(
            car: widget.car,
            tenantId: _tenantId,
            branch: branch,
            pickupDateTime: widget.pickupDateTime,
            returnDateTime: widget.returnDateTime,
            pricingProfile: freshProfile,
            selectedKmPackage: freshPackage,
            rentalType: _rentalType,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isContinuing = false;

        if (e.toString().contains('BRANCH_INACTIVE')) {
          _errorMessage =
              'This pickup location is no longer available. Please select another location.';
        } else if (e.toString().contains('BRANCH_NOT_FOUND')) {
          _errorMessage =
              'This pickup location could not be found. Please refresh and select another location.';
        } else {
          _errorMessage =
              'Unable to confirm this pickup location. Please try again.';
        }
      });

      // Automatically synchronize the screen after a failed revalidation.
      await _loadBranches();
    }
  }

  void _selectBranch(Branch branch) {
    if (_isContinuing || _isRefreshing) return;

    setState(() {
      _selectedBranchId = branch.id;
      _errorMessage = null;
    });
  }

  void _resetSelection() {
    if (_isContinuing || _isRefreshing) return;

    setState(() {
      if (_branches.length == 1) {
        _selectedBranchId = _branches.first.id;
      } else {
        _selectedBranchId = null;
      }
      _errorMessage = null;
    });
  }

  void _showSnackBar(
    String message, {
    IconData icon = Icons.info_outline_rounded,
    bool isError = false,
  }) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          backgroundColor: isError ? const Color(0xFF8E2424) : heading,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Row(
            children: [
              Icon(
                icon,
                color: Colors.white,
                size: 19,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  String _formatDateTime(DateTime dateTime) {
    final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';

    return '${dateTime.day.toString().padLeft(2, '0')}/'
        '${dateTime.month.toString().padLeft(2, '0')}/'
        '${dateTime.year} • '
        '$hour:$minute $period';
  }

  String _lastCheckedText() {
    final checkedAt = _lastCheckedAt;
    if (checkedAt == null) return 'Checking live branch availability…';

    final now = DateTime.now();
    final difference = now.difference(checkedAt);

    if (difference.inSeconds < 10) return 'Updated just now';
    if (difference.inMinutes < 1) {
      return 'Updated ${difference.inSeconds}s ago';
    }
    if (difference.inMinutes < 60) {
      return 'Updated ${difference.inMinutes}m ago';
    }

    return 'Updated at '
        '${checkedAt.hour.toString().padLeft(2, '0')}:'
        '${checkedAt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedBranch;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: heading,
          ),
        ),
        title: const Text(
          'Pickup Location',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: heading,
          ),
        ),
        centerTitle: false,
        actions: [
          if (!_isLoading)
            IconButton(
              tooltip: 'Refresh pickup locations',
              onPressed: _busy ? null : () => _refreshBranches(),
              icon: _isRefreshing
                  ? const SizedBox(
                      width: 19,
                      height: 19,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: primary,
                      ),
                    )
                  : const Icon(
                      Icons.refresh_rounded,
                      color: heading,
                    ),
            ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: primary,
                ),
              )
            : RefreshIndicator(
                color: primary,
                onRefresh: () => _refreshBranches(showMessage: false),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    8,
                    20,
                    128,
                  ),
                  children: [
                    _buildTripSummary(),
                    const SizedBox(height: 14),
                    _buildBookingSummary(),
                    const SizedBox(height: 14),
                    _buildAvailabilityStatus(),
                    const SizedBox(height: 24),
                    _buildTitle(),
                    const SizedBox(height: 14),
                    if (_errorMessage != null) _buildError(),
                    if (_branches.isEmpty)
                      _buildEmptyState()
                    else ...[
                      if (selected != null) ...[
                        _buildSelectedSummary(selected),
                        const SizedBox(height: 14),
                      ],
                      ..._branches.map(
                        (branch) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildBranchCard(branch),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
      bottomNavigationBar:
          _branches.isEmpty ? null : _buildBottomButton(),
    );
  }

  Widget _buildTripSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: softAccent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.directions_car_filled_rounded,
              color: primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.car.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: heading,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDateTime(widget.pickupDateTime),
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: body,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Return • ${_formatDateTime(widget.returnDateTime)}',
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityStatus() {
    final hasBranches = _branches.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 11,
      ),
      decoration: BoxDecoration(
        color: hasBranches ? softAccent : const Color(0xFFFFF8F5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasBranches
              ? const Color(0xFFCDEFEA)
              : const Color(0xFFF0DDD2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: hasBranches
                  ? const Color(0xFF16A34A)
                  : const Color(0xFFD97706),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasBranches
                      ? '${_branches.length} active pickup location${_branches.length == 1 ? '' : 's'}'
                      : 'No active pickup locations',
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: heading,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _lastCheckedText(),
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: body,
                  ),
                ),
              ],
            ),
          ),
          if (_isRefreshing)
            const SizedBox(
              width: 17,
              height: 17,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: primary,
              ),
            )
          else
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Refresh',
              onPressed: _isContinuing ? null : _refreshBranches,
              icon: const Icon(
                Icons.sync_rounded,
                color: primary,
                size: 19,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Where would you like to pick up?',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: heading,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _branches.length == 1
                    ? 'Your pickup location is ready.'
                    : 'Choose a convenient pickup location.',
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: body,
                ),
              ),
            ],
          ),
        ),
        if (_branches.length > 1 && _selectedBranchId != null)
          TextButton(
            onPressed: _busy ? null : _resetSelection,
            style: TextButton.styleFrom(
              foregroundColor: primary,
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
            ),
            child: const Text(
              'Reset',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSelectedSummary(Branch branch) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: heading,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: accent,
              size: 21,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Selected pickup location',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFB8C5C2),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  branch.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.verified_rounded,
            color: accent,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildBranchCard(Branch branch) {
    final isSelected = _selectedBranchId == branch.id;

    return InkWell(
      onTap: () => _selectBranch(branch),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primary : border,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: isSelected ? 0.055 : 0.025,
              ),
              blurRadius: isSelected ? 14 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected ? primary : softAccent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.location_on_rounded,
                color: isSelected ? Colors.white : primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          branch.name,
                          style: const TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: heading,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildRadio(isSelected),
                    ],
                  ),
                  const SizedBox(height: 7),
                  if (branch.city.isNotEmpty)
                    Text(
                      branch.city,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: primary,
                      ),
                    ),
                  if (branch.address.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      branch.address,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 12,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                        color: body,
                      ),
                    ),
                  ],
                  if (branch.phone.isNotEmpty) ...[
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        const Icon(
                          Icons.phone_outlined,
                          size: 15,
                          color: muted,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            branch.phone,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: body,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (isSelected) ...[
                    const SizedBox(height: 11),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: softAccent,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: primary,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'Selected for this booking',
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadio(bool selected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? primary : border,
          width: 2,
        ),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: primary,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildError() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFF1D6D6),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFB42318),
            size: 19,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: Color(0xFF8E2424),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: _busy ? null : () => _refreshBranches(),
            icon: const Icon(
              Icons.refresh_rounded,
              color: Color(0xFF8E2424),
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 22,
        vertical: 30,
      ),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.location_off_outlined,
            size: 42,
            color: muted,
          ),
          const SizedBox(height: 12),
          const Text(
            'No pickup locations available',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: heading,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'There are currently no active branches for this rental.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12,
              height: 1.45,
              fontWeight: FontWeight.w500,
              color: body,
            ),
          ),
          const SizedBox(height: 17),
          OutlinedButton.icon(
            onPressed: _isContinuing || _isRefreshing
                ? null
                : () => _refreshBranches(),
            icon: _isRefreshing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: primary,
                    ),
                  )
                : const Icon(
                    Icons.refresh_rounded,
                    size: 17,
                  ),
            label: const Text(
              'Check Again',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: primary,
              side: const BorderSide(color: border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton() {
    final hasSelection = _selectedBranch != null;
    final enabled =
        hasSelection && !_isContinuing && !_isRefreshing;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(
        20,
        10,
        20,
        16,
      ),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SizedBox(
          height: 54,
          child: ElevatedButton(
            onPressed: enabled ? _continue : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              disabledBackgroundColor: const Color(0xFFD9E2E0),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _isContinuing || _isRefreshing
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _branches.length == 1
                            ? 'Continue'
                            : 'Continue with Pickup Location',
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 19,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
