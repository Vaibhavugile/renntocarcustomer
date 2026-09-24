import 'package:flutter/material.dart';

import '../models/admin_model.dart';
import '../services/admin_service.dart';

class AdminsScreen extends StatefulWidget {
  final String tenantId;

  const AdminsScreen({
    super.key,
    required this.tenantId,
  });

  @override
  State<AdminsScreen> createState() => _AdminsScreenState();
}

class _AdminsScreenState extends State<AdminsScreen> {
  final AdminService _adminService =
      AdminService.instance;

  final TextEditingController _searchController =
      TextEditingController();

  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // ADD ADMIN DIALOG
  // ============================================================

  Future<void> _showAddAdminDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return _AddAdminDialog(
          tenantId: widget.tenantId,
          adminService: _adminService,
        );
      },
    );
  }

  // ============================================================
  // EDIT ADMIN DIALOG
  // ============================================================

  Future<void> _showEditAdminDialog(
    Admin admin,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) {
        return _EditAdminDialog(
          tenantId: widget.tenantId,
          admin: admin,
          adminService: _adminService,
        );
      },
    );
  }

  // ============================================================
  // REMOVE ADMIN
  // ============================================================

  Future<void> _removeAdmin(
    Admin admin,
  ) async {
    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text(
            'Remove Admin?',
          ),
          content: const Text(
            'This customer will lose admin access. '
            'Their customer account and booking data will '
            'not be deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              child: const Text(
                'Remove Admin',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _adminService.removeAdmin(
        tenantId: widget.tenantId,
        adminId: admin.adminId,
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        'Admin access removed successfully.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        error.toString().replaceFirst(
              'Exception: ',
              '',
            ),
        isError: true,
      );
    }
  }

  // ============================================================
  // STATUS TOGGLE
  // ============================================================

  Future<void> _toggleAdminStatus(
    Admin admin,
  ) async {
    try {
      await _adminService.setAdminStatus(
        tenantId: widget.tenantId,
        adminId: admin.adminId,
        isActive: !admin.isActive,
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        admin.isActive
            ? 'Admin deactivated.'
            : 'Admin activated.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        error.toString().replaceFirst(
              'Exception: ',
              '',
            ),
        isError: true,
      );
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(
            seconds: 3,
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
      backgroundColor:
          const Color(0xFFF7F8FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor:
            const Color(0xFF111827),
        title: const Text(
          'Admins',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          Padding(
            padding:
                const EdgeInsets.only(
              right: 16,
            ),
            child: FilledButton.icon(
              onPressed:
                  _showAddAdminDialog,
              icon: const Icon(
                Icons.person_add_alt_1,
                size: 19,
              ),
              label: const Text(
                'Add Admin',
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Admin>>(
        stream: _adminService.watchAdmins(
          tenantId: widget.tenantId,
        ),
        builder: (
          context,
          snapshot,
        ) {
          if (snapshot.connectionState ==
                  ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return _ErrorView(
              message:
                  'Unable to load admins.',
              onRetry: () {
                setState(() {});
              },
            );
          }

          final admins =
              snapshot.data ?? [];

          final filteredAdmins =
              admins.where(
            (admin) {
              if (_searchQuery
                  .trim()
                  .isEmpty) {
                return true;
              }

              return admin.adminId
                  .toLowerCase()
                  .contains(
                    _searchQuery
                        .toLowerCase(),
                  );
            },
          ).toList();

          return SingleChildScrollView(
            padding:
                const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                _buildHeader(
                  admins.length,
                ),
                const SizedBox(height: 20),
                _buildStats(admins),
                const SizedBox(height: 24),
                _buildSearch(),
                const SizedBox(height: 20),
                if (filteredAdmins.isEmpty)
                  _EmptyAdmins(
                    onAddAdmin:
                        _showAddAdminDialog,
                  )
                else
                  ...filteredAdmins.map(
                    (admin) {
                      return Padding(
                        padding:
                            const EdgeInsets.only(
                          bottom: 14,
                        ),
                        child:
                            _AdminCard(
                          admin: admin,
                          onEdit: () =>
                              _showEditAdminDialog(
                            admin,
                          ),
                          onToggleStatus: () =>
                              _toggleAdminStatus(
                            admin,
                          ),
                          onRemove: () =>
                              _removeAdmin(
                            admin,
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader(
    int totalAdmins,
  ) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Text(
                'Admin Management',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  color:
                      Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '$totalAdmins admin'
                '${totalAdmins == 1 ? '' : 's'} '
                'have access to this tenant.',
                style: const TextStyle(
                  fontSize: 14,
                  color:
                      Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // STATS
  // ============================================================

  Widget _buildStats(
    List<Admin> admins,
  ) {
    final active = admins
        .where(
          (admin) => admin.isActive,
        )
        .length;

    final inactive = admins.length -
        active;

    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final width =
            constraints.maxWidth;

        final cardWidth =
            width >= 900
                ? (width - 32) / 3
                : width >= 600
                    ? (width - 16) / 2
                    : width;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: cardWidth,
              child: _StatCard(
                title: 'Total Admins',
                value:
                    admins.length
                        .toString(),
                icon:
                    Icons.admin_panel_settings,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _StatCard(
                title: 'Active',
                value:
                    active.toString(),
                icon:
                    Icons.verified_user,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _StatCard(
                title: 'Inactive',
                value:
                    inactive.toString(),
                icon:
                    Icons.person_off,
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // SEARCH
  // ============================================================

  Widget _buildSearch() {
    return TextField(
      controller:
          _searchController,
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
      decoration:
          InputDecoration(
        hintText:
            'Search admins...',
        prefixIcon:
            const Icon(
          Icons.search,
        ),
        suffixIcon:
            _searchQuery.isNotEmpty
                ? IconButton(
                    onPressed: () {
                      _searchController
                          .clear();

                      setState(() {
                        _searchQuery =
                            '';
                      });
                    },
                    icon:
                        const Icon(
                      Icons.clear,
                    ),
                  )
                : null,
        filled: true,
        fillColor:
            Colors.white,
        border:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            14,
          ),
          borderSide:
              BorderSide.none,
        ),
      ),
    );
  }
}

// ============================================================
// ADMIN CARD
// ============================================================

class _AdminCard extends StatelessWidget {
  final Admin admin;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;
  final VoidCallback onRemove;

  const _AdminCard({
    required this.admin,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.all(18),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color:
              const Color(0xFFE5E7EB),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withOpacity(0.035),
            blurRadius: 18,
            offset:
                const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration:
                BoxDecoration(
              color: const Color(
                0xFFEEF2FF,
              ),
              borderRadius:
                  BorderRadius.circular(
                15,
              ),
            ),
            child: const Icon(
              Icons.person,
              color:
                  Color(0xFF4F46E5),
              size: 25,
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
                    Text(
                      admin.adminId,
                      style:
                          const TextStyle(
                        fontSize: 16,
                        fontWeight:
                            FontWeight.w700,
                        color: Color(
                          0xFF111827,
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 8,
                    ),
                    _StatusBadge(
                      isActive:
                          admin.isActive,
                    ),
                  ],
                ),
                const SizedBox(
                  height: 5,
                ),
                Text(
                  'Role: ${_prettyRole(admin.roleId)}',
                  style:
                      const TextStyle(
                    fontSize: 13,
                    color:
                        Color(0xFF6B7280),
                  ),
                ),
                if (admin.createdAt !=
                    null)
                  Padding(
                    padding:
                        const EdgeInsets
                            .only(
                      top: 3,
                    ),
                    child: Text(
                      'Added ${_formatDate(admin.createdAt!)}',
                      style:
                          const TextStyle(
                        fontSize: 12,
                        color: Color(
                          0xFF9CA3AF,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  onEdit();
                  break;

                case 'toggle':
                  onToggleStatus();
                  break;

                case 'remove':
                  onRemove();
                  break;
              }
            },
            itemBuilder:
                (context) {
              return [
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading:
                        Icon(
                      Icons.edit_outlined,
                    ),
                    title:
                        Text('Edit Admin'),
                  ),
                ),
                PopupMenuItem(
                  value: 'toggle',
                  child: ListTile(
                    leading:
                        Icon(
                      Icons
                          .power_settings_new,
                    ),
                    title: Text(
                      admin.isActive
                          ? 'Deactivate'
                          : 'Activate',
                    ),
                  ),
                ),
                const PopupMenuItem(
                  value: 'remove',
                  child: ListTile(
                    leading:
                        Icon(
                      Icons
                          .delete_outline,
                    ),
                    title:
                        Text('Remove Admin'),
                  ),
                ),
              ];
            },
          ),
        ],
      ),
    );
  }

  String _prettyRole(
    String role,
  ) {
    if (role.trim().isEmpty) {
      return 'Admin';
    }

    return role
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (word) {
            if (word.isEmpty) {
              return word;
            }

            return word[0].toUpperCase() +
                word.substring(1);
          },
        )
        .join(' ');
  }

  String _formatDate(
    DateTime date,
  ) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}

// ============================================================
// STATUS BADGE
// ============================================================

class _StatusBadge extends StatelessWidget {
  final bool isActive;

  const _StatusBadge({
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration:
          BoxDecoration(
        color: isActive
            ? const Color(
                0xFFECFDF3,
              )
            : const Color(
                0xFFFEF2F2,
              ),
        borderRadius:
            BorderRadius.circular(
          20,
        ),
      ),
      child: Text(
        isActive
            ? 'Active'
            : 'Inactive',
        style: TextStyle(
          fontSize: 11,
          fontWeight:
              FontWeight.w700,
          color: isActive
              ? const Color(
                  0xFF047857,
                )
              : const Color(
                  0xFFB91C1C,
                ),
        ),
      ),
    );
  }
}

// ============================================================
// STAT CARD
// ============================================================

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.all(18),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color:
              const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration:
                BoxDecoration(
              color: const Color(
                0xFFF3F4F6,
              ),
              borderRadius:
                  BorderRadius.circular(
                13,
              ),
            ),
            child: Icon(
              icon,
              color:
                  const Color(0xFF4F46E5),
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style:
                    const TextStyle(
                  fontSize: 12,
                  color:
                      Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style:
                    const TextStyle(
                  fontSize: 22,
                  fontWeight:
                      FontWeight.w800,
                  color:
                      Color(0xFF111827),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// ADD ADMIN DIALOG
// ============================================================

class _AddAdminDialog extends StatefulWidget {
  final String tenantId;
  final AdminService adminService;

  const _AddAdminDialog({
    required this.tenantId,
    required this.adminService,
  });

  @override
  State<_AddAdminDialog> createState() =>
      _AddAdminDialogState();
}

class _AddAdminDialogState
    extends State<_AddAdminDialog> {
  final TextEditingController
      _searchController =
      TextEditingController();

  List<Map<String, dynamic>>
      _customers = [];

  Map<String, dynamic>? _selectedCustomer;

  String _role = 'admin';

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD CUSTOMERS
  // ============================================================

  Future<void> _loadCustomers({
    String search = '',
  }) async {
    setState(() {
      _loading = true;
    });

    try {
      final customers =
          await widget.adminService
              .getAvailableCustomers(
        tenantId:
            widget.tenantId,
        search: search,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _customers = customers;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
      });

      _showError(
        error.toString()
            .replaceFirst(
          'Exception: ',
          '',
        ),
      );
    }
  }

  // ============================================================
  // ADD
  // ============================================================

  Future<void> _addAdmin() async {
    final customer =
        _selectedCustomer;

    if (customer == null) {
      _showError(
        'Please select a customer.',
      );
      return;
    }

    final customerId =
        customer['customerId']
            ?.toString();

    if (customerId == null ||
        customerId.isEmpty) {
      _showError(
        'Invalid customer.',
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await widget.adminService
          .addAdmin(
        tenantId:
            widget.tenantId,
        customerId:
            customerId,
        roleId: _role,
      );

      if (!mounted) {
        return;
      }

      Navigator.pop(context);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'Admin added successfully.',
          ),
          behavior:
              SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
      });

      _showError(
        error.toString()
            .replaceFirst(
          'Exception: ',
          '',
        ),
      );
    }
  }

  void _showError(
    String message,
  ) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior:
            SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Add Admin',
        style: TextStyle(
          fontWeight: FontWeight.w700,
        ),
      ),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Select an existing customer',
              style: TextStyle(
                fontSize: 13,
                color:
                    Color(0xFF6B7280),
              ),
            ),
            const SizedBox(
              height: 12,
            ),
            TextField(
              controller:
                  _searchController,
              onChanged: (value) {
                _loadCustomers(
                  search: value,
                );
              },
              decoration:
                  InputDecoration(
                hintText:
                    'Search name, phone or email',
                prefixIcon:
                    const Icon(
                  Icons.search,
                ),
                border:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
              ),
            ),
            const SizedBox(
              height: 14,
            ),
            if (_loading)
              const SizedBox(
                height: 180,
                child: Center(
                  child:
                      CircularProgressIndicator(),
                ),
              )
            else if (_customers.isEmpty)
              const SizedBox(
                height: 150,
                child: Center(
                  child: Text(
                    'No available customers found.',
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints:
                    const BoxConstraints(
                  maxHeight: 280,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount:
                      _customers.length,
                  separatorBuilder:
                      (_, __) =>
                          const Divider(
                    height: 1,
                  ),
                  itemBuilder:
                      (context, index) {
                    final customer =
                        _customers[index];

                    final selected =
                        identical(
                      _selectedCustomer,
                      customer,
                    );

                    final name =
                        customer[
                                    'fullName']
                                ?.toString() ??
                            'Customer';

                    final phone =
                        customer[
                                    'phone']
                                ?.toString() ??
                            '';

                    final email =
                        customer[
                                    'email']
                                ?.toString() ??
                            '';

                    return ListTile(
                      onTap: () {
                        setState(() {
                          _selectedCustomer =
                              customer;
                        });
                      },
                      leading:
                          CircleAvatar(
                        child: Text(
                          name
                              .trim()
                              .isEmpty
                              ? '?'
                              : name
                                  .trim()
                                  .substring(
                                    0,
                                    1,
                                  )
                                  .toUpperCase(),
                        ),
                      ),
                      title:
                          Text(
                        name,
                        style:
                            const TextStyle(
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                      subtitle:
                          Text(
                        [
                          phone,
                          email,
                        ].where(
                          (value) =>
                              value
                                  .isNotEmpty,
                        ).join(' • '),
                      ),
                      trailing:
                          Radio<
                              String>(
                        value:
                            customer[
                                'customerId'],
                        groupValue:
                            _selectedCustomer?[
                                'customerId'],
                        onChanged:
                            (_) {
                          setState(() {
                            _selectedCustomer =
                                customer;
                          });
                        },
                      ),
                      selected:
                          selected,
                    );
                  },
                ),
              ),
            const SizedBox(
              height: 18,
            ),
            DropdownButtonFormField<
                String>(
              initialValue: _role,
              decoration:
                  InputDecoration(
                labelText: 'Role',
                border:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'admin',
                  child:
                      Text('Admin'),
                ),
                DropdownMenuItem(
                  value: 'manager',
                  child:
                      Text('Manager'),
                ),
                DropdownMenuItem(
                  value: 'staff',
                  child:
                      Text('Staff'),
                ),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  _role = value;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving
              ? null
              : () {
                  Navigator.pop(
                    context,
                  );
                },
          child:
              const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving
              ? null
              : _addAdmin,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : const Text(
                  'Add Admin',
                ),
        ),
      ],
    );
  }
}

// ============================================================
// EDIT ADMIN DIALOG
// ============================================================

class _EditAdminDialog extends StatefulWidget {
  final String tenantId;
  final Admin admin;
  final AdminService adminService;

  const _EditAdminDialog({
    required this.tenantId,
    required this.admin,
    required this.adminService,
  });

  @override
  State<_EditAdminDialog> createState() =>
      _EditAdminDialogState();
}

class _EditAdminDialogState
    extends State<_EditAdminDialog> {
  late String _role;
  late bool _isActive;

  bool _saving = false;

  @override
  void initState() {
    super.initState();

    _role = widget.admin.roleId;
    _isActive =
        widget.admin.isActive;
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
    });

    try {
      await widget.adminService
          .updateAdmin(
        tenantId:
            widget.tenantId,
        adminId:
            widget.admin.adminId,
        roleId: _role,
        isActive: _isActive,
      );

      if (!mounted) {
        return;
      }

      Navigator.pop(context);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'Admin updated successfully.',
          ),
          behavior:
              SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            error.toString()
                .replaceFirst(
              'Exception: ',
              '',
            ),
          ),
          behavior:
              SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Edit Admin',
        style: TextStyle(
          fontWeight: FontWeight.w700,
        ),
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Container(
              padding:
                  const EdgeInsets.all(14),
              decoration:
                  BoxDecoration(
                color: const Color(
                  0xFFF9FAFB,
                ),
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    child: Icon(
                      Icons.person,
                    ),
                  ),
                  const SizedBox(
                    width: 12,
                  ),
                  Expanded(
                    child: Text(
                      widget.admin.adminId,
                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(
              height: 18,
            ),
            DropdownButtonFormField<
                String>(
              initialValue:
                  _availableRole(
                _role,
              ),
              decoration:
                  InputDecoration(
                labelText: 'Role',
                border:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'admin',
                  child:
                      Text('Admin'),
                ),
                DropdownMenuItem(
                  value: 'manager',
                  child:
                      Text('Manager'),
                ),
                DropdownMenuItem(
                  value: 'staff',
                  child:
                      Text('Staff'),
                ),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  _role = value;
                });
              },
            ),
            const SizedBox(
              height: 12,
            ),
            SwitchListTile(
              contentPadding:
                  EdgeInsets.zero,
              title:
                  const Text(
                'Active',
                style:
                    TextStyle(
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
              subtitle:
                  const Text(
                'Allow this user to access admin features.',
              ),
              value: _isActive,
              onChanged:
                  _saving
                      ? null
                      : (value) {
                          setState(() {
                            _isActive =
                                value;
                          });
                        },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving
              ? null
              : () {
                  Navigator.pop(
                    context,
                  );
                },
          child:
              const Text('Cancel'),
        ),
        FilledButton(
          onPressed:
              _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : const Text(
                  'Save Changes',
                ),
        ),
      ],
    );
  }

  String _availableRole(
    String role,
  ) {
    const roles = [
      'admin',
      'manager',
      'staff',
    ];

    if (roles.contains(role)) {
      return role;
    }

    return 'admin';
  }
}

// ============================================================
// EMPTY STATE
// ============================================================

class _EmptyAdmins extends StatelessWidget {
  final VoidCallback onAddAdmin;

  const _EmptyAdmins({
    required this.onAddAdmin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(
        vertical: 60,
        horizontal: 20,
      ),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color:
              const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration:
                BoxDecoration(
              color: const Color(
                0xFFEEF2FF,
              ),
              borderRadius:
                  BorderRadius.circular(
                18,
              ),
            ),
            child: const Icon(
              Icons
                  .admin_panel_settings_outlined,
              size: 32,
              color:
                  Color(0xFF4F46E5),
            ),
          ),
          const SizedBox(
            height: 16,
          ),
          const Text(
            'No admins found',
            style: TextStyle(
              fontSize: 18,
              fontWeight:
                  FontWeight.w700,
            ),
          ),
          const SizedBox(
            height: 6,
          ),
          const Text(
            'Select an existing customer to give them admin access.',
            textAlign:
                TextAlign.center,
            style: TextStyle(
              color:
                  Color(0xFF6B7280),
            ),
          ),
          const SizedBox(
            height: 20,
          ),
          FilledButton.icon(
            onPressed:
                onAddAdmin,
            icon:
                const Icon(
              Icons.person_add_alt_1,
            ),
            label:
                const Text(
              'Add Admin',
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// ERROR
// ============================================================

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(24),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color:
                  Color(0xFFDC2626),
            ),
            const SizedBox(
              height: 12,
            ),
            Text(
              message,
              textAlign:
                  TextAlign.center,
            ),
            const SizedBox(
              height: 16,
            ),
            FilledButton(
              onPressed:
                  onRetry,
              child:
                  const Text(
                'Retry',
              ),
            ),
          ],
        ),
      ),
    );
  }
}