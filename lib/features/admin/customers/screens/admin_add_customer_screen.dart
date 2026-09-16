import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../../customer/models/customer.dart';
import '../../../customer/services/customer_service.dart';

class AdminAddCustomerScreen extends StatefulWidget {
  const AdminAddCustomerScreen({super.key});

  @override
  State<AdminAddCustomerScreen> createState() =>
      _AdminAddCustomerScreenState();
}

class _AdminAddCustomerScreenState
    extends State<AdminAddCustomerScreen> {
  static const bg = Color(0xFFF8FAF9);
  static const card = Color(0xFFFFFFFF);
  static const primary = Color(0xFF0F766E);
  static const accent = Color(0xFF14B8A6);
  static const softAccent = Color(0xFFE6FFFB);
  static const heading = Color(0xFF17201F);
  static const body = Color(0xFF66706E);
  static const muted = Color(0xFF94A09D);
  static const border = Color(0xFFE5EBE9);

  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _dob = TextEditingController();

  final _address1 = TextEditingController();
  final _address2 = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _postal = TextEditingController();

  final _emergencyName = TextEditingController();
  final _emergencyPhone = TextEditingController();
  final _relationship = TextEditingController();

  String _gender = '';
  bool _saving = false;

  String get _tenantId => AppConfig.tenant.tenantId;

  CustomerService get _customerService =>
      CustomerService.instance;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _dob.dispose();

    _address1.dispose();
    _address2.dispose();
    _city.dispose();
    _state.dispose();
    _postal.dispose();

    _emergencyName.dispose();
    _emergencyPhone.dispose();
    _relationship.dispose();

    super.dispose();
  }

  // ============================================================
  // PHONE NORMALIZATION
  // ============================================================

  String _normalizePhone(String value) {
    var phone = value.trim();

    phone = phone.replaceAll(
      RegExp(r'[\s\-\(\)]'),
      '',
    );

    // Indian local number:
    // 8446442206
    // -> +918446442206
    if (phone.length == 10 &&
        RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
      phone = '+91$phone';
    }

    // 918446442206
    // -> +918446442206
    if (phone.length == 12 &&
        phone.startsWith('91')) {
      phone = '+$phone';
    }

    return phone;
  }

  bool _isValidPhone(String phone) {
    return RegExp(
      r'^\+[1-9]\d{7,14}$',
    ).hasMatch(phone);
  }

  // ============================================================
  // CREATE CUSTOMER
  // ============================================================

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    if (_saving) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final phone = _normalizePhone(
      _phone.text,
    );

    if (!_isValidPhone(phone)) {
      _showError(
        'Enter a valid phone number.',
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      // --------------------------------------------------------
      // STEP 1
      // Check existing customer in this tenant.
      // --------------------------------------------------------

      final existing =
          await _customerService.getCustomerByPhone(
        tenantId: _tenantId,
        phone: phone,
      );

      if (existing != null) {
        if (mounted) {
          setState(() {
            _saving = false;
          });

          _showError(
            'A customer with this phone number already exists.',
          );
        }

        return;
      }

      // --------------------------------------------------------
      // STEP 2
      // Ask Firebase Cloud Function to:
      //
      // Firebase Auth createUser()
      //        ↓
      // Firebase UID
      //        ↓
      // customers/{UID}
      // --------------------------------------------------------

      final customerId =
          await _customerService.createCustomerByAdmin(
        tenantId: _tenantId,
        fullName: _name.text.trim(),
        phone: phone,
        email: _email.text.trim(),
      );

      // --------------------------------------------------------
      // STEP 3
      // Build complete customer profile.
      // --------------------------------------------------------

      final addressStarted = [
        _address1.text,
        _address2.text,
        _city.text,
        _state.text,
        _postal.text,
      ].any(
        (value) => value.trim().isNotEmpty,
      );

      final emergencyStarted = [
        _emergencyName.text,
        _emergencyPhone.text,
        _relationship.text,
      ].any(
        (value) => value.trim().isNotEmpty,
      );

      final customer = Customer(
        customerId: customerId,
        tenantId: _tenantId,
        fullName: _name.text.trim(),
        phone: phone,
        email: _email.text.trim(),
        profileImageUrl: '',
        dateOfBirth: _dob.text.trim(),
        gender: _gender,
        address: addressStarted
            ? CustomerAddress(
                addressLine1:
                    _address1.text.trim(),
                addressLine2:
                    _address2.text.trim(),
                city: _city.text.trim(),
                state: _state.text.trim(),
                postalCode:
                    _postal.text.trim(),
                country: 'India',
              )
            : null,
        emergencyContact: emergencyStarted
            ? EmergencyContact(
                name:
                    _emergencyName.text.trim(),
                phone:
                    _emergencyPhone.text.trim(),
                relationship:
                    _relationship.text.trim(),
              )
            : null,
        kycStatus: 'not_started',
        profileCompleted:
            _name.text.trim().isNotEmpty,
        isActive: true,
        totalBookings: 0,
        completedBookings: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // --------------------------------------------------------
      // STEP 4
      // Update the Auth-created customer document with
      // the remaining profile fields.
      // --------------------------------------------------------

      await _customerService.updateCustomerForAdmin(
        tenantId: _tenantId,
        customer: customer,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
      });

      // --------------------------------------------------------
      // STEP 5
      // Success
      // --------------------------------------------------------

      _showSuccess(
        'Customer created successfully.',
      );

      await Future.delayed(
        const Duration(milliseconds: 500),
      );

      if (!mounted) {
        return;
      }

      Navigator.pop(
        context,
        customer,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
      });

      _showError(
        e.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
    }
  }

  // ============================================================
  // DATE PICKER
  // ============================================================

  Future<void> _selectDateOfBirth() async {
    FocusScope.of(context).unfocus();

    final now = DateTime.now();

    final initialDate = DateTime(
      now.year - 25,
      now.month,
      now.day,
    );

    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(
        1940,
        1,
        1,
      ),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: primary,
              surface: card,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selected == null) {
      return;
    }

    final day =
        selected.day.toString().padLeft(2, '0');

    final month =
        selected.month.toString().padLeft(2, '0');

    final year =
        selected.year.toString();

    setState(() {
      _dob.text = '$day/$month/$year';
    });
  }

  // ============================================================
  // UI HELPERS
  // ============================================================

  InputDecoration _dec(
    String label, {
    String? hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: card,
      labelStyle: const TextStyle(
        color: body,
      ),
      hintStyle: const TextStyle(
        color: muted,
      ),
      contentPadding:
          const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
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
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Colors.redAccent,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Colors.redAccent,
          width: 1.5,
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    TextInputType? keyboard,
    int maxLines = 1,
    Widget? prefixIcon,
    Widget? suffixIcon,
    String? hint,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      maxLines: maxLines,
      textInputAction:
          maxLines > 1
              ? TextInputAction.newline
              : TextInputAction.next,
      decoration: _dec(
        label,
        hint: hint,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
      ),
      validator: validator ??
          (required
              ? (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return '$label is required';
                  }

                  return null;
                }
              : null),
    );
  }

  Widget _sectionTitle(
    String title,
    String subtitle,
  ) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 14,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: heading,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: body,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(
        bottom: 18,
      ),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: border,
        ),
        boxShadow: const [
          BoxShadow(
            blurRadius: 18,
            offset: Offset(0, 6),
            color: Color(0x0A17201F),
          ),
        ],
      ),
      child: child,
    );
  }

  // ============================================================
  // SNACKBARS
  // ============================================================

  void _showError(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          backgroundColor: const Color(0xFFB42318),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  void _showSuccess(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          backgroundColor: primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_outline_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
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
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        surfaceTintColor: bg,
        elevation: 0,
        titleSpacing: 20,
        title: const Text(
          'Add Customer',
          style: TextStyle(
            color: heading,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            20,
            8,
            20,
            40,
          ),
          keyboardDismissBehavior:
              ScrollViewKeyboardDismissBehavior
                  .onDrag,
          children: [
            // ----------------------------------------------------
            // HEADER
            // ----------------------------------------------------

            Container(
              padding: const EdgeInsets.all(18),
              margin: const EdgeInsets.only(
                bottom: 18,
              ),
              decoration: BoxDecoration(
                color: softAccent,
                borderRadius:
                    BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFC8F4ED),
                ),
              ),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: primary,
                      borderRadius:
                          BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.person_add_alt_1_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create customer account',
                          style: TextStyle(
                            color: heading,
                            fontSize: 16,
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'A Firebase account and customer profile will be created for this tenant.',
                          style: TextStyle(
                            color: body,
                            fontSize: 12.5,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ----------------------------------------------------
            // CUSTOMER INFORMATION
            // ----------------------------------------------------

            _sectionCard(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  _sectionTitle(
                    'Customer information',
                    'Basic information used for the rental account.',
                  ),

                  _field(
                    _name,
                    'Full name',
                    required: true,
                    prefixIcon: const Icon(
                      Icons.person_outline_rounded,
                      color: primary,
                    ),
                  ),

                  const SizedBox(height: 12),

                  _field(
                    _phone,
                    'Phone number',
                    required: true,
                    keyboard:
                        TextInputType.phone,
                    hint: '9876543210',
                    prefixIcon: const Icon(
                      Icons.phone_outlined,
                      color: primary,
                    ),
                    validator: (value) {
                      if (value == null ||
                          value.trim().isEmpty) {
                        return 'Phone number is required';
                      }

                      final normalized =
                          _normalizePhone(
                        value,
                      );

                      if (!_isValidPhone(
                        normalized,
                      )) {
                        return 'Enter a valid phone number';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 12),

                  _field(
                    _email,
                    'Email',
                    keyboard:
                        TextInputType.emailAddress,
                    prefixIcon: const Icon(
                      Icons.email_outlined,
                      color: primary,
                    ),
                    validator: (value) {
                      if (value == null ||
                          value.trim().isEmpty) {
                        return null;
                      }

                      final valid =
                          RegExp(
                        r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                      ).hasMatch(
                        value.trim(),
                      );

                      return valid
                          ? null
                          : 'Enter a valid email';
                    },
                  ),

                  const SizedBox(height: 12),

                  _field(
                    _dob,
                    'Date of birth',
                    suffixIcon: IconButton(
                      onPressed:
                          _selectDateOfBirth,
                      icon: const Icon(
                        Icons.calendar_month_outlined,
                        color: primary,
                      ),
                    ),
                    prefixIcon: const Icon(
                      Icons.cake_outlined,
                      color: primary,
                    ),
                  ),

                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    value: _gender.isEmpty
                        ? null
                        : _gender,
                    decoration: _dec(
                      'Gender',
                      prefixIcon: const Icon(
                        Icons.wc_outlined,
                        color: primary,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'male',
                        child: Text('Male'),
                      ),
                      DropdownMenuItem(
                        value: 'female',
                        child: Text('Female'),
                      ),
                      DropdownMenuItem(
                        value: 'other',
                        child: Text('Other'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _gender = value ?? '';
                      });
                    },
                  ),
                ],
              ),
            ),

            // ----------------------------------------------------
            // ADDRESS
            // ----------------------------------------------------

            _sectionCard(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  _sectionTitle(
                    'Address',
                    'Optional customer address information.',
                  ),

                  _field(
                    _address1,
                    'Address line 1',
                    prefixIcon: const Icon(
                      Icons.location_on_outlined,
                      color: primary,
                    ),
                  ),

                  const SizedBox(height: 12),

                  _field(
                    _address2,
                    'Address line 2',
                  ),

                  const SizedBox(height: 12),

                  Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _field(
                          _city,
                          'City',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _field(
                          _state,
                          'State',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  _field(
                    _postal,
                    'Postal code',
                    keyboard:
                        TextInputType.number,
                  ),
                ],
              ),
            ),

            // ----------------------------------------------------
            // EMERGENCY CONTACT
            // ----------------------------------------------------

            _sectionCard(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  _sectionTitle(
                    'Emergency contact',
                    'Optional emergency contact for the customer.',
                  ),

                  _field(
                    _emergencyName,
                    'Name',
                    prefixIcon: const Icon(
                      Icons.contact_emergency_outlined,
                      color: primary,
                    ),
                  ),

                  const SizedBox(height: 12),

                  _field(
                    _emergencyPhone,
                    'Phone',
                    keyboard:
                        TextInputType.phone,
                    prefixIcon: const Icon(
                      Icons.phone_outlined,
                      color: primary,
                    ),
                  ),

                  const SizedBox(height: 12),

                  _field(
                    _relationship,
                    'Relationship',
                  ),
                ],
              ),
            ),

            // ----------------------------------------------------
            // CREATE BUTTON
            // ----------------------------------------------------

            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed:
                    _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      primary.withValues(
                    alpha: 0.55,
                  ),
                  elevation: 0,
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(16),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons
                                .person_add_alt_1_rounded,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Create Customer',
                            style: TextStyle(
                              fontWeight:
                                  FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 14),

            // ----------------------------------------------------
            // INFO
            // ----------------------------------------------------

            Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(14),
                border: Border.all(
                  color: border,
                ),
              ),
              child: const Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: primary,
                  ),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'The customer will receive an OTP when they first sign in. Their Firebase UID is used as the customer document ID.',
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        color: body,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}