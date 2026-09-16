import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/config/app_config.dart';
import '../../../../models/branch.dart';
import '../../../branches/services/branch_service.dart';
import 'admin_add_branch_screen.dart';
import 'admin_edit_branch_screen.dart';
class AdminBranchesScreen extends StatefulWidget {
  const AdminBranchesScreen({
    super.key,
  });

  @override
  State<AdminBranchesScreen> createState() =>
      _AdminBranchesScreenState();
}

class _AdminBranchesScreenState
    extends State<AdminBranchesScreen> {
  // ============================================================
  // PREMIUM PALETTE
  // ============================================================

  static const Color primary =
      Color(0xFF0F766E);

  static const Color accent =
      Color(0xFF14B8A6);

  static const Color background =
      Color(0xFFF8FAF9);

  static const Color card =
      Color(0xFFFFFFFF);

  static const Color softAccent =
      Color(0xFFE6FFFB);

  static const Color heading =
      Color(0xFF17201F);

  static const Color body =
      Color(0xFF66706E);

  static const Color muted =
      Color(0xFF94A09D);

  static const Color border =
      Color(0xFFE5EBE9);

  // ============================================================
  // STATE
  // ============================================================

  final TextEditingController _searchController =
      TextEditingController();

  List<Branch> _branches = [];

  bool _isLoading = true;
  bool _isRefreshing = false;

  String _searchQuery = '';

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _searchController.addListener(
      _onSearchChanged,
    );

    _loadBranches();
  }

  @override
  void dispose() {
    _searchController.removeListener(
      _onSearchChanged,
    );

    _searchController.dispose();

    super.dispose();
  }

  // ============================================================
  // TENANT
  // ============================================================

  String get _tenantId =>
      AppConfig.tenant.tenantId;

  // ============================================================
  // SEARCH
  // ============================================================

  void _onSearchChanged() {
    if (!mounted) return;

    setState(() {
      _searchQuery =
          _searchController.text.trim().toLowerCase();
    });
  }

  // ============================================================
  // LOAD
  // ============================================================

  Future<void> _loadBranches({
    bool refreshing = false,
  }) async {
    if (_tenantId.trim().isEmpty) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });

      _showError(
        'Tenant configuration is missing.',
      );

      return;
    }

    if (refreshing) {
      setState(() {
        _isRefreshing = true;
      });
    } else {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final branches =
          await BranchService.instance
              .getAllBranches(_tenantId);

      if (!mounted) return;

      setState(() {
        _branches = branches;
        _isLoading = false;
        _isRefreshing = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });

      _showError(
        'Unable to load branches. Please try again.',
      );
    }
  }

  // ============================================================
  // FILTERED BRANCHES
  // ============================================================

  List<Branch> get _filteredBranches {
    if (_searchQuery.isEmpty) {
      return _branches;
    }

    return _branches.where((branch) {
      final name =
          branch.name.toLowerCase();

      final city =
          branch.city.toLowerCase();

      final address =
          branch.address.toLowerCase();

      final phone =
          branch.phone.toLowerCase();

      return name.contains(_searchQuery) ||
          city.contains(_searchQuery) ||
          address.contains(_searchQuery) ||
          phone.contains(_searchQuery);
    }).toList();
  }

  // ============================================================
  // COUNTS
  // ============================================================

  int get _totalBranches =>
      _branches.length;

  int get _activeBranches =>
      _branches.where(
        (branch) => branch.isActive,
      ).length;

  int get _inactiveBranches =>
      _branches.where(
        (branch) => !branch.isActive,
      ).length;

  // ============================================================
  // ACTIVATE / DEACTIVATE
  // ============================================================

  Future<void> _toggleBranch(
    Branch branch,
  ) async {
    final action =
        branch.isActive
            ? 'deactivate'
            : 'activate';

    final confirmed =
        await _showConfirmationDialog(
      branch: branch,
      action: action,
    );

    if (!confirmed) {
      return;
    }

    try {
      if (branch.isActive) {
        await BranchService.instance
            .deactivateBranch(
          tenantId: _tenantId,
          branchId: branch.id,
        );
      } else {
        await BranchService.instance
            .activateBranch(
          tenantId: _tenantId,
          branchId: branch.id,
        );
      }

      await _loadBranches();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            branch.isActive
                ? 'Branch deactivated.'
                : 'Branch activated.',
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w700,
            ),
          ),
          backgroundColor: primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(14),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      _showError(
        'Unable to update branch status.',
      );
    }
  }

  // ============================================================
  // CONFIRMATION
  // ============================================================

  Future<bool> _showConfirmationDialog({
    required Branch branch,
    required String action,
  }) async {
    final isDeactivate =
        action == 'deactivate';

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: card,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(22),
          ),
          title: Text(
            isDeactivate
                ? 'Deactivate Branch?'
                : 'Activate Branch?',
            style: GoogleFonts.manrope(
              color: heading,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            isDeactivate
                ? 'Customers will no longer be able to use this branch for new bookings.'
                : 'This branch will become available for use again.',
            style: GoogleFonts.manrope(
              color: body,
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          actionsPadding:
              const EdgeInsets.fromLTRB(
            20,
            0,
            20,
            16,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: Text(
                'Cancel',
                style: GoogleFonts.manrope(
                  color: body,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
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
                isDeactivate
                    ? 'Deactivate'
                    : 'Activate',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  // ============================================================
  // COMING SOON ADD
  // ============================================================

  Future<void> _addBranch() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const AdminAddBranchScreen(),
      ),
    );

    if (result == true && mounted) {
      await _loadBranches();
    }
  }

  // ============================================================
  // EDIT
  // ============================================================
Future<void> _editBranch(
  Branch branch,
) async {
  final result = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => AdminEditBranchScreen(
        branch: branch,
      ),
    ),
  );

  if (result == true && mounted) {
    await _loadBranches();
  }
}

  // ============================================================
  // ERROR
  // ============================================================

  void _showError(
    String message,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor:
            Colors.red.shade700,
        behavior:
            SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(14),
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,

      appBar: AppBar(
        backgroundColor: background,
        surfaceTintColor:
            Colors.transparent,
        elevation: 0,

        leading: IconButton(
          onPressed: () =>
              Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: heading,
          ),
        ),

        title: Text(
          'Branches',
          style: GoogleFonts.manrope(
            color: heading,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),

      body: _isLoading
          ? const Center(
              child:
                  CircularProgressIndicator(
                color: primary,
              ),
            )
          : RefreshIndicator(
              color: primary,
              onRefresh: () =>
                  _loadBranches(
                refreshing: true,
              ),
              child: ListView(
                physics:
                    const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  110,
                ),
                children: [
                  _buildHeader(),

                  const SizedBox(height: 18),

                  _buildStats(),

                  const SizedBox(height: 18),

                  _buildSearch(),

                  const SizedBox(height: 18),

                  if (_filteredBranches.isEmpty)
                    _buildEmptyState()
                  else
                    ..._filteredBranches
                        .map(
                          (branch) =>
                              Padding(
                            padding:
                                const EdgeInsets.only(
                              bottom: 14,
                            ),
                            child:
                                _buildBranchCard(
                              branch,
                            ),
                          ),
                        ),
                ],
              ),
            ),

      floatingActionButton:
          FloatingActionButton.extended(
        onPressed:
            _isRefreshing ? null : _addBranch,
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(
          Icons.add_rounded,
        ),
        label: Text(
          'Add Branch',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primary,
        borderRadius:
            BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color:
                primary.withValues(alpha: 0.16),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white
                  .withValues(alpha: 0.12),
              borderRadius:
                  BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.store_rounded,
              color: Colors.white,
              size: 27,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Branch Management',
                  style: GoogleFonts.manrope(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage pickup and return locations.',
                  style: GoogleFonts.manrope(
                    color: Colors.white
                        .withValues(alpha: 0.78),
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STATS
  // ============================================================

  Widget _buildStats() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon:
                Icons.account_tree_rounded,
            title: 'Total',
            value:
                _totalBranches.toString(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            icon:
                Icons.check_circle_rounded,
            title: 'Active',
            value:
                _activeBranches.toString(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            icon:
                Icons.pause_circle_rounded,
            title: 'Inactive',
            value:
                _inactiveBranches.toString(),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius:
            BorderRadius.circular(18),
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
            size: 21,
          ),

          const SizedBox(height: 10),

          Text(
            value,
            style: GoogleFonts.manrope(
              color: heading,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 2),

          Text(
            title,
            style: GoogleFonts.manrope(
              color: muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SEARCH
  // ============================================================

  Widget _buildSearch() {
    return TextField(
      controller: _searchController,
      style: GoogleFonts.manrope(
        color: heading,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText:
            'Search branches...',
        hintStyle:
            GoogleFonts.manrope(
          color: muted,
          fontSize: 13,
          fontWeight:
              FontWeight.w500,
        ),

        prefixIcon: const Icon(
          Icons.search_rounded,
          color: primary,
        ),

        suffixIcon:
            _searchQuery.isNotEmpty
                ? IconButton(
                    onPressed: () {
                      _searchController.clear();
                    },
                    icon: const Icon(
                      Icons.close_rounded,
                      color: muted,
                    ),
                  )
                : null,

        filled: true,
        fillColor: card,

        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),

        border:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(16),
          borderSide:
              const BorderSide(
            color: border,
          ),
        ),

        enabledBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(16),
          borderSide:
              const BorderSide(
            color: border,
          ),
        ),

        focusedBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(16),
          borderSide:
              const BorderSide(
            color: primary,
            width: 1.4,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BRANCH CARD
  // ============================================================

  Widget _buildBranchCard(
    Branch branch,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: card,
        borderRadius:
            BorderRadius.circular(21),
        border: Border.all(
          color: border,
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(
              alpha: 0.025,
            ),
            blurRadius: 16,
            offset:
                const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: branch.isActive
                      ? softAccent
                      : Colors.grey.shade100,
                  borderRadius:
                      BorderRadius.circular(15),
                ),
                child: Icon(
                  Icons.location_on_rounded,
                  color: branch.isActive
                      ? primary
                      : muted,
                  size: 24,
                ),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            branch.name.isEmpty
                                ? 'Unnamed Branch'
                                : branch.name,
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                            style:
                                GoogleFonts.manrope(
                              color: heading,
                              fontSize: 16,
                              fontWeight:
                                  FontWeight.w800,
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        _statusBadge(
                          branch.isActive,
                        ),
                      ],
                    ),

                    const SizedBox(height: 5),

                    Row(
                      children: [
                        const Icon(
                          Icons
                              .location_city_rounded,
                          size: 14,
                          color: muted,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            branch.city.isEmpty
                                ? 'City not set'
                                : branch.city,
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                            style:
                                GoogleFonts.manrope(
                              color: body,
                              fontSize: 12,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: background,
              borderRadius:
                  BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                _buildDetailRow(
                  icon:
                      Icons.home_work_outlined,
                  text:
                      branch.address.isEmpty
                          ? 'Address not provided'
                          : branch.address,
                ),

                const SizedBox(height: 9),

                _buildDetailRow(
                  icon:
                      Icons.phone_outlined,
                  text:
                      branch.phone.isEmpty
                          ? 'Phone not provided'
                          : branch.phone,
                ),
              ],
            ),
          ),

          const SizedBox(height: 13),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _editBranch(branch),
                  icon: const Icon(
                    Icons.edit_rounded,
                    size: 17,
                  ),
                  label: Text(
                    'Edit',
                    style:
                        GoogleFonts.manrope(
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                  style:
                      OutlinedButton.styleFrom(
                    foregroundColor:
                        primary,
                    side:
                        const BorderSide(
                      color: border,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        13,
                      ),
                    ),
                    padding:
                        const EdgeInsets
                            .symmetric(
                      vertical: 13,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () =>
                      _toggleBranch(branch),
                  icon: Icon(
                    branch.isActive
                        ? Icons
                            .pause_circle_outline_rounded
                        : Icons
                            .check_circle_outline_rounded,
                    size: 17,
                  ),
                  label: Text(
                    branch.isActive
                        ? 'Deactivate'
                        : 'Activate',
                    style:
                        GoogleFonts.manrope(
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        branch.isActive
                            ? Colors
                                .orange
                                .shade700
                            : primary,
                    foregroundColor:
                        Colors.white,
                    elevation: 0,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        13,
                      ),
                    ),
                    padding:
                        const EdgeInsets
                            .symmetric(
                      vertical: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DETAIL ROW
  // ============================================================

  Widget _buildDetailRow({
    required IconData icon,
    required String text,
  }) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.manrope(
              color: body,
              fontSize: 12,
              height: 1.35,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // STATUS BADGE
  // ============================================================

  Widget _statusBadge(
    bool isActive,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: isActive
            ? softAccent
            : Colors.grey.shade100,
        borderRadius:
            BorderRadius.circular(30),
      ),
      child: Text(
        isActive
            ? 'Active'
            : 'Inactive',
        style: GoogleFonts.manrope(
          color: isActive
              ? primary
              : muted,
          fontSize: 10,
          fontWeight:
              FontWeight.w800,
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    final bool searching =
        _searchQuery.isNotEmpty;

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 45,
      ),
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
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: softAccent,
              borderRadius:
                  BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.store_outlined,
              color: primary,
              size: 32,
            ),
          ),

          const SizedBox(height: 17),

          Text(
            searching
                ? 'No branches found'
                : 'No branches yet',
            style: GoogleFonts.manrope(
              color: heading,
              fontSize: 17,
              fontWeight:
                  FontWeight.w800,
            ),
          ),

          const SizedBox(height: 7),

          Text(
            searching
                ? 'Try a different branch name, city or phone number.'
                : 'Create your first rental branch to start assigning vehicles and bookings.',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              color: body,
              fontSize: 12.5,
              height: 1.45,
              fontWeight:
                  FontWeight.w500,
            ),
          ),

          if (!searching) ...[
            const SizedBox(height: 18),

            ElevatedButton.icon(
              onPressed: _addBranch,
              icon: const Icon(
                Icons.add_rounded,
                size: 18,
              ),
              label: Text(
                'Add First Branch',
                style:
                    GoogleFonts.manrope(
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    primary,
                foregroundColor:
                    Colors.white,
                elevation: 0,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    13,
                  ),
                ),
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 18,
                  vertical: 13,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// TEMPORARY PLACEHOLDER SCREENS
// ============================================================================
//
// We will replace these with the real Add/Edit Branch screens next.
// Keeping them here temporarily lets the Branch List compile immediately.
// ============================================================================
