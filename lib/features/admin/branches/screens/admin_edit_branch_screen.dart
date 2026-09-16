import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/config/app_config.dart';
import '../../../../models/branch.dart';
import '../../../branches/services/branch_service.dart';

class AdminEditBranchScreen extends StatefulWidget {
  final Branch branch;

  const AdminEditBranchScreen({
    super.key,
    required this.branch,
  });

  @override
  State<AdminEditBranchScreen> createState() =>
      _AdminEditBranchScreenState();
}

class _AdminEditBranchScreenState
    extends State<AdminEditBranchScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _cityController;
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;

  bool _isActive = true;
  bool _isSaving = false;

  // ============================================================
  // FIXED PREMIUM PALETTE
  // ============================================================

  static const Color background = Color(0xFFF8FAF9);
  static const Color card = Color(0xFFFFFFFF);
  static const Color primary = Color(0xFF0F766E);
  static const Color accent = Color(0xFF14B8A6);
  static const Color softAccent = Color(0xFFE6FFFB);
  static const Color heading = Color(0xFF17201F);
  static const Color body = Color(0xFF66706E);
  static const Color muted = Color(0xFF94A09D);
  static const Color border = Color(0xFFE5EBE9);
  static const Color errorColor = Color(0xFFDC2626);

  String get tenantId {
    try {
      return AppConfig.tenant.tenantId.trim();
    } catch (_) {
      return '';
    }
  }

  @override
  void initState() {
    super.initState();

    _nameController =
        TextEditingController(text: widget.branch.name);

    _cityController =
        TextEditingController(text: widget.branch.city);

    _addressController =
        TextEditingController(text: widget.branch.address);

    _phoneController =
        TextEditingController(text: widget.branch.phone);

    _isActive = widget.branch.isActive;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _phoneController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              20,
              22,
              20,
              32,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),

                const SizedBox(height: 24),

                _buildFormCard(),

                const SizedBox(height: 18),

                _buildStatusCard(),

                const SizedBox(height: 26),

                _buildSaveButton(),

                const SizedBox(height: 12),

                _buildCancelButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // APP BAR
  // ============================================================

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        onPressed: _isSaving
            ? null
            : () => Navigator.pop(context),
        icon: const Icon(
          Icons.arrow_back_rounded,
          color: heading,
          size: 23,
        ),
      ),
      titleSpacing: 0,
      title: Text(
        'Edit Branch',
        style: GoogleFonts.manrope(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: heading,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: border,
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Update branch details',
          style: GoogleFonts.manrope(
            fontSize: 25,
            height: 1.15,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
            color: heading,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'Update the location information and availability of this branch.',
          style: GoogleFonts.manrope(
            fontSize: 12,
            height: 1.45,
            fontWeight: FontWeight.w500,
            color: body,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            color: softAccent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.tag_rounded,
                size: 14,
                color: primary,
              ),
              const SizedBox(width: 6),
              Text(
                'Branch ID: ${widget.branch.id}',
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // FORM CARD
  // ============================================================

  Widget _buildFormCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardTitle(
            icon: Icons.edit_location_alt_outlined,
            title: 'Branch details',
            subtitle: 'Update the information for this location',
          ),

          const SizedBox(height: 22),

          _buildField(
            controller: _nameController,
            label: 'Branch name',
            hint: 'e.g. Pune Main Branch',
            icon: Icons.storefront_outlined,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            validator: (value) {
              final text = value?.trim() ?? '';

              if (text.isEmpty) {
                return 'Branch name is required';
              }

              if (text.length < 2) {
                return 'Enter a valid branch name';
              }

              return null;
            },
          ),

          const SizedBox(height: 16),

          _buildField(
            controller: _cityController,
            label: 'City',
            hint: 'e.g. Pune',
            icon: Icons.location_city_outlined,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            validator: (value) {
              final text = value?.trim() ?? '';

              if (text.isEmpty) {
                return 'City is required';
              }

              return null;
            },
          ),

          const SizedBox(height: 16),

          _buildField(
            controller: _addressController,
            label: 'Full address',
            hint: 'Enter complete pickup / return address',
            icon: Icons.place_outlined,
            maxLines: 3,
            minLines: 3,
            textInputAction: TextInputAction.newline,
            textCapitalization: TextCapitalization.sentences,
            validator: (value) {
              final text = value?.trim() ?? '';

              if (text.isEmpty) {
                return 'Address is required';
              }

              if (text.length < 10) {
                return 'Please enter a complete address';
              }

              return null;
            },
          ),

          const SizedBox(height: 16),

          _buildField(
            controller: _phoneController,
            label: 'Branch phone',
            hint: 'e.g. +91 98765 43210',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            validator: (value) {
              final text = value?.trim() ?? '';

              if (text.isEmpty) {
                return 'Branch phone is required';
              }

              final digits = text.replaceAll(
                RegExp(r'[^0-9]'),
                '',
              );

              if (digits.length < 10) {
                return 'Enter a valid phone number';
              }

              return null;
            },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STATUS CARD
  // ============================================================

  Widget _buildStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _isActive ? softAccent : background,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: border),
            ),
            child: Icon(
              _isActive
                  ? Icons.check_circle_outline_rounded
                  : Icons.pause_circle_outline_rounded,
              color: _isActive ? primary : muted,
              size: 22,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Branch status',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: heading,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _isActive
                      ? 'Customers can use this branch for bookings.'
                      : 'This branch is unavailable for bookings.',
                  style: GoogleFonts.manrope(
                    fontSize: 10.5,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                    color: body,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          Switch.adaptive(
            value: _isActive,
            activeTrackColor: accent,
            onChanged: _isSaving
                ? null
                : (value) {
                    setState(() {
                      _isActive = value;
                    });
                  },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SAVE BUTTON
  // ============================================================

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _updateBranch,
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor:
              primary.withValues(alpha: 0.55),
          disabledForegroundColor: Colors.white70,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isSaving
            ? const SizedBox(
                width: 21,
                height: 21,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(
                    Colors.white,
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.save_outlined,
                    size: 19,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Save Changes',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ============================================================
  // CANCEL
  // ============================================================

  Widget _buildCancelButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: _isSaving
            ? null
            : () => Navigator.pop(context),
        style: OutlinedButton.styleFrom(
          foregroundColor: heading,
          side: const BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: Text(
          'Cancel',
          style: GoogleFonts.manrope(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CARD TITLE
  // ============================================================

  Widget _buildCardTitle({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: softAccent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: primary,
            size: 20,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: heading,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // FORM FIELD
  // ============================================================

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    TextCapitalization textCapitalization =
        TextCapitalization.none,
    int? maxLines = 1,
    int? minLines,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: heading,
          ),
        ),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          enabled: !_isSaving,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          maxLines: maxLines,
          minLines: minLines,
          validator: validator,
          style: GoogleFonts.manrope(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: heading,
          ),
          cursorColor: primary,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.manrope(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: muted,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(
                left: 12,
                right: 8,
              ),
              child: Icon(
                icon,
                size: 19,
                color: body,
              ),
            ),
            prefixIconConstraints:
                const BoxConstraints(
              minWidth: 45,
              minHeight: 45,
            ),
            filled: true,
            fillColor: background,
            contentPadding:
                const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: border,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: border,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: primary,
                width: 1.3,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: errorColor,
              ),
            ),
            focusedErrorBorder:
                OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: errorColor,
                width: 1.2,
              ),
            ),
            errorStyle: GoogleFonts.manrope(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: errorColor,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // UPDATE BRANCH
  // ============================================================

  Future<void> _updateBranch() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (tenantId.isEmpty) {
      _showError(
        'Tenant configuration is missing. Unable to update branch.',
      );
      return;
    }

    if (widget.branch.id.trim().isEmpty) {
      _showError(
        'Invalid branch ID. Unable to update branch.',
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final updatedBranch = widget.branch.copyWith(
        tenantId: tenantId,
        name: _nameController.text.trim(),
        city: _cityController.text.trim(),
        address: _addressController.text.trim(),
        phone: _phoneController.text.trim(),
        isActive: _isActive,
      );

      await BranchService.instance.updateBranch(
        tenantId: tenantId,
        branchId: widget.branch.id,
        branch: updatedBranch,
      );

      if (!mounted) return;

      Navigator.pop(
        context,
        true,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      _showError(
        'Unable to update branch. Please try again.',
      );
    }
  }

  // ============================================================
  // ERROR
  // ============================================================

  void _showError(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: heading,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}