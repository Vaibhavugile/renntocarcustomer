import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import 'package:customer_app_car_rental/features/cars/models/car.dart';
import '../../../models/branch.dart';
import 'km_package_screen.dart';

class BranchSelectionScreen extends StatefulWidget {
  final Car car;
  final String tenantId;
  final DateTime pickupDateTime;
  final DateTime returnDateTime;

  const BranchSelectionScreen({
    super.key,
    required this.car,
    required this.tenantId,
    required this.pickupDateTime,
    required this.returnDateTime,
  });

  @override
  State<BranchSelectionScreen> createState() =>
      _BranchSelectionScreenState();
}

class _BranchSelectionScreenState
    extends State<BranchSelectionScreen> {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  List<Branch> _branches = [];
  String? _selectedBranchId;

  bool _isLoading = true;
  bool _isContinuing = false;
  String? _errorMessage;

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

  String get _tenantId => AppConfig.tenant.tenantId;

  @override
  void initState() {
    super.initState();

    _loadBranches();
  }

  Future<void> _loadBranches() async {
    if (!mounted) return;

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

      if (!mounted) return;

      String? selectedBranchId;

      // If there is only one active branch,
      // automatically select it.
      if (branches.length == 1) {
        selectedBranchId = branches.first.id;
      }

      setState(() {
        _branches = branches;
        _selectedBranchId = selectedBranchId;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage =
            'Unable to load pickup locations. Please try again.';
      });
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

  Future<void> _continue() async {
    if (_selectedBranch == null) {
      setState(() {
        _errorMessage =
            'Please select a pickup location to continue.';
      });
      return;
    }

    setState(() {
      _isContinuing = true;
      _errorMessage = null;
    });

    try {
      // Re-check that the selected branch is still active.
      final branchDoc = await _firestore
          .collection('tenants')
          .doc(_tenantId)
          .collection('branches')
          .doc(_selectedBranch!.id)
          .get();

      if (!branchDoc.exists) {
        throw Exception('BRANCH_NOT_FOUND');
      }

      final branch =
          Branch.fromMap(branchDoc.id, branchDoc.data()!);

      if (!branch.isActive) {
        throw Exception('BRANCH_INACTIVE');
      }

      if (!mounted) return;

      setState(() {
        _isContinuing = false;
      });

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => KmPackageScreen(
            car: widget.car,
            tenantId: _tenantId,
            branch: branch,
            pickupDateTime: widget.pickupDateTime,
            returnDateTime: widget.returnDateTime,
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
        } else {
          _errorMessage =
              'Unable to confirm this pickup location. Please try again.';
        }
      });

      await _loadBranches();
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final hour = dateTime.hour % 12 == 0
        ? 12
        : dateTime.hour % 12;

    final minute =
        dateTime.minute.toString().padLeft(2, '0');

    final period = dateTime.hour >= 12 ? 'PM' : 'AM';

    return '${dateTime.day.toString().padLeft(2, '0')}/'
        '${dateTime.month.toString().padLeft(2, '0')}/'
        '${dateTime.year} • '
        '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
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
                onRefresh: _loadBranches,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    8,
                    20,
                    120,
                  ),
                  children: [
                    _buildTripSummary(),
                    const SizedBox(height: 24),
                    _buildTitle(),
                    const SizedBox(height: 14),
                    if (_errorMessage != null)
                      _buildError(),
                    if (_branches.isEmpty)
                      _buildEmptyState()
                    else
                      ..._branches.map(
                        (branch) => Padding(
                          padding:
                              const EdgeInsets.only(bottom: 12),
                          child: _buildBranchCard(branch),
                        ),
                      ),
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
              crossAxisAlignment:
                  CrossAxisAlignment.start,
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
                  '${_formatDateTime(widget.pickupDateTime)}',
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

  Widget _buildTitle() {
    return Column(
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
    );
  }

  Widget _buildBranchCard(Branch branch) {
    final isSelected =
        _selectedBranchId == branch.id;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedBranchId = branch.id;
          _errorMessage = null;
        });
      },
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
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? primary
                    : softAccent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.location_on_rounded,
                color:
                    isSelected ? Colors.white : primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
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
                        Text(
                          branch.phone,
                          style: const TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: body,
                          ),
                        ),
                      ],
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
        crossAxisAlignment:
            CrossAxisAlignment.start,
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
      child: const Column(
        children: [
          Icon(
            Icons.location_off_outlined,
            size: 42,
            color: muted,
          ),
          SizedBox(height: 12),
          Text(
            'No pickup locations available',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: heading,
            ),
          ),
          SizedBox(height: 6),
          Text(
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
        ],
      ),
    );
  }

  Widget _buildBottomButton() {
    final hasSelection = _selectedBranch != null;

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
            onPressed:
                hasSelection && !_isContinuing
                    ? _continue
                    : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              disabledBackgroundColor:
                  const Color(0xFFD9E2E0),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _isContinuing
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
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