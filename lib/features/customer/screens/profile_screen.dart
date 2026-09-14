import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/customer.dart';
import '../services/customer_service.dart';
import 'kyc_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const String _tenantId = 'tenant_001';

  static const Color background = Color(0xFFF8FAF9);
  static const Color card = Color(0xFFFFFFFF);
  static const Color primary = Color(0xFF0F766E);
  static const Color accent = Color(0xFF14B8A6);
  static const Color softAccent = Color(0xFFE6FFFB);
  static const Color heading = Color(0xFF17201F);
  static const Color body = Color(0xFF66706E);
  static const Color muted = Color(0xFF94A09D);
  static const Color border = Color(0xFFE5EBE9);

  final CustomerService _customerService = CustomerService();

  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _dobController = TextEditingController();

  final _address1Controller = TextEditingController();
  final _address2Controller = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _postalController = TextEditingController();

  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  final _emergencyRelationshipController = TextEditingController();

  Customer? _customer;

  String _gender = '';
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadCustomer();
  }

  Future<void> _loadCustomer({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() => _loading = true);
    }

    try {
      final customer = await _customerService.getCurrentCustomer(
        tenantId: _tenantId,
      );

      if (!mounted) return;

      if (customer != null) {
        _customer = customer;
        _populateFields(customer);
      }
    } catch (e) {
      if (mounted) {
        _showMessage(
          'Unable to load your profile. Please try again.',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _populateFields(Customer customer) {
    // Always hydrate every controller from the latest Firebase document.
    // Empty/null nested objects must also clear old local values.
    _nameController.text = customer.fullName;
    _emailController.text = customer.email;
    _dobController.text = customer.dateOfBirth;
    _gender = customer.gender;

    final address = customer.address;
    _address1Controller.text = address?.addressLine1 ?? '';
    _address2Controller.text = address?.addressLine2 ?? '';
    _cityController.text = address?.city ?? '';
    _stateController.text = address?.state ?? '';
    _postalController.text = address?.postalCode ?? '';

    final emergency = customer.emergencyContact;
    _emergencyNameController.text = emergency?.name ?? '';
    _emergencyPhoneController.text = emergency?.phone ?? '';
    _emergencyRelationshipController.text =
        emergency?.relationship ?? '';
  }

  int _calculateCompletion() {
    int completed = 0;
    const total = 6;

    if (_nameController.text.trim().isNotEmpty) completed++;
    if (_emailController.text.trim().isNotEmpty) completed++;
    if (_dobController.text.trim().isNotEmpty) completed++;
    if (_gender.trim().isNotEmpty) completed++;

    if (_address1Controller.text.trim().isNotEmpty &&
        _cityController.text.trim().isNotEmpty &&
        _stateController.text.trim().isNotEmpty) {
      completed++;
    }

    if (_emergencyNameController.text.trim().isNotEmpty &&
        _emergencyPhoneController.text.trim().isNotEmpty) {
      completed++;
    }

    return ((completed / total) * 100).round();
  }

  bool get _isKycVerified => _customer?.kycStatus == 'verified';

  String get _kycStatusTitle {
    switch (_customer?.kycStatus) {
      case 'verified':
        return 'KYC Verified';
      case 'pending':
        return 'Verification Pending';
      case 'rejected':
        return 'Verification Rejected';
      default:
        return 'Verification Not Started';
    }
  }

  String get _kycStatusSubtitle {
    switch (_customer?.kycStatus) {
      case 'verified':
        return 'Your documents have been verified.';
      case 'pending':
        return 'Your documents are currently under review.';
      case 'rejected':
        return 'Please review your documents and submit them again.';
      default:
        return 'Complete verification before vehicle pickup.';
    }
  }

  Future<void> _openKyc() async {
    // Important: save the profile first. This makes KYC navigation safe even
    // when the user filled the profile fields but did not press "Save Profile".
    // The KYC screen then only changes KYC/document fields and cannot erase
    // the profile data.
    if (_customer == null) {
      _showMessage(
        'Customer account could not be loaded.',
        isError: true,
      );
      return;
    }

    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_saving) return;

    setState(() => _saving = true);

    try {
      final addressIsStarted =
          _address1Controller.text.trim().isNotEmpty ||
          _address2Controller.text.trim().isNotEmpty ||
          _cityController.text.trim().isNotEmpty ||
          _stateController.text.trim().isNotEmpty ||
          _postalController.text.trim().isNotEmpty;

      final address = addressIsStarted
          ? CustomerAddress(
              addressLine1: _address1Controller.text.trim(),
              addressLine2: _address2Controller.text.trim(),
              city: _cityController.text.trim(),
              state: _stateController.text.trim(),
              postalCode: _postalController.text.trim(),
              country: 'India',
            )
          : null;

      final emergencyIsStarted =
          _emergencyNameController.text.trim().isNotEmpty ||
          _emergencyPhoneController.text.trim().isNotEmpty ||
          _emergencyRelationshipController.text.trim().isNotEmpty;

      final emergency = emergencyIsStarted
          ? EmergencyContact(
              name: _emergencyNameController.text.trim(),
              phone: _emergencyPhoneController.text.trim(),
              relationship: _emergencyRelationshipController.text.trim(),
            )
          : null;

      final completion = _calculateCompletion();

      final updatedCustomer = _customer!.copyWith(
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        dateOfBirth: _dobController.text.trim(),
        gender: _gender,
        address: address,
        emergencyContact: emergency,
        profileCompleted: completion >= 100,
        updatedAt: DateTime.now(),
      );

      await _customerService.updateCustomer(
        tenantId: _tenantId,
        customer: updatedCustomer,
      );

      if (!mounted) return;
      setState(() {
        _customer = updatedCustomer;
        _saving = false;
      });

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const KycScreen(
            tenantId: _tenantId,
          ),
        ),
      );

      if (!mounted) return;

      // KYC may have changed only kycStatus. Refresh the complete customer
      // document so the profile always reflects the latest Firebase state.
      await _loadCustomer(showLoader: false);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _showMessage(
          'Unable to save your profile. Please try again.',
          isError: true,
        );
      }
    }
  }

  Future<void> _pickDate() async {
    DateTime initial = DateTime(1995, 1, 1);

    if (_dobController.text.isNotEmpty) {
      final parsed = DateTime.tryParse(_dobController.text);
      if (parsed != null) initial = parsed;
    }

    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now) ? DateTime(1995, 1, 1) : initial,
      firstDate: DateTime(1940),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: heading,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      _dobController.text =
          '${picked.year.toString().padLeft(4, '0')}-'
          '${picked.month.toString().padLeft(2, '0')}-'
          '${picked.day.toString().padLeft(2, '0')}';

      setState(() {});
    }
  }

  Future<void> _saveProfile() async {
    if (_saving) return;

    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_customer == null) {
      _showMessage(
        'Customer account could not be loaded.',
        isError: true,
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final addressIsStarted =
          _address1Controller.text.trim().isNotEmpty ||
          _address2Controller.text.trim().isNotEmpty ||
          _cityController.text.trim().isNotEmpty ||
          _stateController.text.trim().isNotEmpty ||
          _postalController.text.trim().isNotEmpty;

      final address = addressIsStarted
          ? CustomerAddress(
              addressLine1: _address1Controller.text.trim(),
              addressLine2: _address2Controller.text.trim(),
              city: _cityController.text.trim(),
              state: _stateController.text.trim(),
              postalCode: _postalController.text.trim(),
              country: 'India',
            )
          : null;

      final emergencyIsStarted =
          _emergencyNameController.text.trim().isNotEmpty ||
          _emergencyPhoneController.text.trim().isNotEmpty ||
          _emergencyRelationshipController.text.trim().isNotEmpty;

      final emergency = emergencyIsStarted
          ? EmergencyContact(
              name: _emergencyNameController.text.trim(),
              phone: _emergencyPhoneController.text.trim(),
              relationship:
                  _emergencyRelationshipController.text.trim(),
            )
          : null;

      final completion = _calculateCompletion();

      final updatedCustomer = _customer!.copyWith(
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        dateOfBirth: _dobController.text.trim(),
        gender: _gender,
        address: address,
        emergencyContact: emergency,
        profileCompleted: completion >= 100,
        updatedAt: DateTime.now(),
      );

      await _customerService.updateCustomer(
        tenantId: _tenantId,
        customer: updatedCustomer,
      );

      final refreshed =
          await _customerService.getCurrentCustomer(
        tenantId: _tenantId,
      );

      if (!mounted) return;

      setState(() {
        _customer = refreshed ?? updatedCustomer;
      });

      _showMessage('Profile updated successfully.');
    } catch (e) {
      if (mounted) {
        _showMessage(
          'Unable to save your profile. Please try again.',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 19,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.manrope(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: isError ? heading : primary,
          behavior: SnackBarBehavior.floating,
          elevation: 0,
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'My Profile',
          style: GoogleFonts.manrope(
            fontSize: 21,
            fontWeight: FontWeight.w900,
            color: heading,
            letterSpacing: -0.4,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: primary,
                strokeWidth: 2.4,
              ),
            )
          : SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
                  children: [
                    _buildProfileHeader(),
                    const SizedBox(height: 14),
                    _buildVerificationSummary(),
                    const SizedBox(height: 20),
                    _buildSection(
                      title: 'Personal Information',
                      icon: Icons.person_outline_rounded,
                      children: [
                        _buildField(
                          controller: _nameController,
                          label: 'Full Name',
                          hint: 'Enter your full name',
                          icon: Icons.badge_outlined,
                          required: true,
                          validator: (value) {
                            if (value == null ||
                                value.trim().isEmpty) {
                              return 'Please enter your name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        _buildField(
                          controller: TextEditingController(
                            text: _customer?.phone ?? '',
                          ),
                          label: 'Mobile Number',
                          hint: 'Verified mobile number',
                          icon: Icons.phone_outlined,
                          readOnly: true,
                          suffix: const Icon(
                            Icons.verified_rounded,
                            color: primary,
                            size: 19,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildField(
                          controller: _emailController,
                          label: 'Email',
                          hint: 'Optional',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            final email = value?.trim() ?? '';
                            if (email.isEmpty) return null;

                            final valid = RegExp(
                              r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                            ).hasMatch(email);

                            return valid
                                ? null
                                : 'Enter a valid email';
                          },
                        ),
                        const SizedBox(height: 14),
                        _buildField(
                          controller: _dobController,
                          label: 'Date of Birth',
                          hint: 'Select your date of birth',
                          icon: Icons.calendar_today_outlined,
                          readOnly: true,
                          onTap: _pickDate,
                        ),
                        const SizedBox(height: 14),
                        _buildGenderSelector(),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      title: 'Address',
                      icon: Icons.location_on_outlined,
                      subtitle: 'Optional — can be completed later',
                      children: [
                        _buildField(
                          controller: _address1Controller,
                          label: 'Address Line 1',
                          hint: 'House / building / street',
                          icon: Icons.home_outlined,
                        ),
                        const SizedBox(height: 14),
                        _buildField(
                          controller: _address2Controller,
                          label: 'Address Line 2',
                          hint: 'Apartment / landmark',
                          icon: Icons.apartment_outlined,
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _buildField(
                                controller: _cityController,
                                label: 'City',
                                hint: 'Pune',
                                icon: Icons.location_city_outlined,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildField(
                                controller: _postalController,
                                label: 'PIN Code',
                                hint: '411057',
                                icon: Icons.pin_drop_outlined,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _buildField(
                          controller: _stateController,
                          label: 'State',
                          hint: 'Maharashtra',
                          icon: Icons.map_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      title: 'Emergency Contact',
                      icon: Icons.contact_phone_outlined,
                      subtitle: 'Optional — can be completed later',
                      children: [
                        _buildField(
                          controller: _emergencyNameController,
                          label: 'Contact Name',
                          hint: 'Enter contact name',
                          icon: Icons.person_outline_rounded,
                        ),
                        const SizedBox(height: 14),
                        _buildField(
                          controller: _emergencyPhoneController,
                          label: 'Contact Number',
                          hint: 'Enter phone number',
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 14),
                        _buildField(
                          controller:
                              _emergencyRelationshipController,
                          label: 'Relationship',
                          hint: 'e.g. Father, Mother, Spouse',
                          icon: Icons.people_outline_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      title: 'Documents & KYC',
                      icon: Icons.description_outlined,
                      subtitle:
                          'Documents can be completed before pickup',
                      children: [
                        _buildKycRow(),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          disabledBackgroundColor:
                              primary.withValues(alpha: 0.55),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(17),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 21,
                                height: 21,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.2,
                                ),
                              )
                            : Text(
                                'Save Profile',
                                style: GoogleFonts.manrope(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProfileHeader() {
    final completion = _calculateCompletion();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: heading.withValues(alpha: 0.045),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: softAccent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.person_outline_rounded,
              color: primary,
              size: 31,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _nameController.text.trim().isEmpty
                      ? 'Welcome'
                      : _nameController.text.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: heading,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _customer?.phone ?? '',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: body,
                  ),
                ),
                const SizedBox(height: 11),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: completion / 100,
                          minHeight: 6,
                          backgroundColor: border,
                          color: accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$completion%',
                      style: GoogleFonts.manrope(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationSummary() {
    final verified = _isKycVerified;
    final pending = _customer?.kycStatus == 'pending';
    final rejected = _customer?.kycStatus == 'rejected';

    final title = verified
        ? 'Ready for pickup verification'
        : pending
            ? 'Documents under review'
            : rejected
                ? 'Verification needs attention'
                : 'Complete verification before pickup';

    final subtitle = verified
        ? 'Your submitted KYC documents have been approved.'
        : pending
            ? 'We are reviewing your submitted documents.'
            : rejected
                ? 'Open Verification to review and resubmit your documents.'
                : 'You can browse and book without completing KYC now.';

    return InkWell(
      onTap: _openKyc,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: verified ? softAccent : card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: verified ? accent.withValues(alpha: 0.25) : border,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: softAccent,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                verified
                    ? Icons.verified_rounded
                    : Icons.verified_user_outlined,
                color: primary,
                size: 21,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.manrope(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: heading,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: GoogleFonts.manrope(
                      fontSize: 10.2,
                      fontWeight: FontWeight.w500,
                      color: body,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: muted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 17, 16, 18),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                child: Icon(
                  icon,
                  color: primary,
                  size: 19,
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
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: heading,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.manrope(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          ...children,
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool required = false,
    bool readOnly = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    Widget? suffix,
    VoidCallback? onTap,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      validator: validator,
      onTap: onTap,
      onChanged: (_) {
        setState(() {});
      },
      style: GoogleFonts.manrope(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: heading,
      ),
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        hintText: hint,
        prefixIcon: Icon(
          icon,
          size: 19,
          color: muted,
        ),
        suffixIcon: suffix,
        filled: true,
        fillColor: background,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        labelStyle: GoogleFonts.manrope(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: body,
        ),
        hintStyle: GoogleFonts.manrope(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: muted,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(
            color: primary,
            width: 1.3,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
    );
  }

  Widget _buildGenderSelector() {
    const genders = ['Male', 'Female', 'Other'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gender',
          style: GoogleFonts.manrope(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: body,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: genders.map((gender) {
            final value = gender.toLowerCase();
            final selected = _gender == value;

            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: gender == genders.last ? 0 : 8,
                ),
                child: GestureDetector(
                  onTap: () {
                    setState(() => _gender = value);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 46,
                    decoration: BoxDecoration(
                      color: selected ? softAccent : background,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: selected ? primary : border,
                        width: selected ? 1.2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        gender,
                        style: GoogleFonts.manrope(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: selected ? primary : body,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildKycRow() {
    final status = _customer?.kycStatus ?? 'not_started';

    Color statusColor;
    Color statusBackground;
    IconData icon;

    switch (status) {
      case 'verified':
        statusColor = primary;
        statusBackground = softAccent;
        icon = Icons.verified_rounded;
        break;
      case 'pending':
        statusColor = primary;
        statusBackground = softAccent;
        icon = Icons.hourglass_top_rounded;
        break;
      case 'rejected':
        statusColor = heading;
        statusBackground = const Color(0xFFF2F4F3);
        icon = Icons.error_outline_rounded;
        break;
      default:
        statusColor = muted;
        statusBackground = background;
        icon = Icons.upload_file_outlined;
    }

    return InkWell(
      onTap: _openKyc,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: statusBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                icon,
                color: statusColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _kycStatusTitle,
                    style: GoogleFonts.manrope(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: heading,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _kycStatusSubtitle,
                    style: GoogleFonts.manrope(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: body,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: muted,
            ),
          ],
        ),
      ),
    );
  }
  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _dobController.dispose();

    _address1Controller.dispose();
    _address2Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalController.dispose();

    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _emergencyRelationshipController.dispose();

    super.dispose();
  }
}
