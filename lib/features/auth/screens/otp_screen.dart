import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/app_config.dart';
import '../services/auth_service.dart';
import '../../home/screens/home_screen.dart';
import '../../customer/services/customer_service.dart';
import '../../admin/dashboard/screens/admin_dashboard_screen.dart';

class OtpScreen extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;

  const OtpScreen({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController _otpController =
      TextEditingController();

  final FocusNode _otpFocusNode =
      FocusNode();

  // ============================================================
  // SERVICES
  // ============================================================

  final AuthService _authService =
      AuthService();

  final CustomerService _customerService =
      CustomerService();

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  // ============================================================
  // VERIFICATION ID
  // ============================================================
  //
  // This must remain mutable because Firebase gives us a new
  // verification ID when OTP is resent.
  //
  // ============================================================

  late String _verificationId;

  // ============================================================
  // STATE
  // ============================================================

  bool _loading = false;

  bool _resending = false;

  int _seconds = 30;

  Timer? _timer;

  // Prevent automatic verification from being triggered
  // multiple times while typing the 6th digit.
  bool _verificationStarted = false;

  // ============================================================
  // FIXED PREMIUM PALETTE
  // ============================================================

  static const Color background =
      Color(0xFFF8FAF9);

  static const Color primary =
      Color(0xFF0F766E);

  static const Color accent =
      Color(0xFF14B8A6);

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
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _verificationId =
        widget.verificationId;

    _startTimer();

    Future.delayed(
      const Duration(
        milliseconds: 400,
      ),
      () {
        if (mounted) {
          _otpFocusNode.requestFocus();
        }
      },
    );
  }

  // ============================================================
  // TENANT
  // ============================================================

  String get _tenantId {
    try {
      final tenantId =
          AppConfig.tenant.tenantId.trim();

      if (tenantId.isEmpty) {
        throw Exception(
          'Tenant ID is empty.',
        );
      }

      return tenantId;
    } catch (_) {
      throw Exception(
        'Tenant configuration is not available.',
      );
    }
  }

  // ============================================================
  // TIMER
  // ============================================================

  void _startTimer() {
    _timer?.cancel();

    _seconds = 30;

    if (mounted) {
      setState(() {});
    }

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (_seconds <= 1) {
          timer.cancel();

          setState(() {
            _seconds = 0;
          });
        } else {
          setState(() {
            _seconds--;
          });
        }
      },
    );
  }

  // ============================================================
  // VERIFY
  // ============================================================

  Future<void> _verify() async {
    if (_loading ||
        _resending ||
        _verificationStarted) {
      return;
    }

    final otp =
        _otpController.text.trim();

    if (otp.length != 6) {
      _showError(
        'Please enter the 6-digit OTP.',
      );

      _otpFocusNode.requestFocus();

      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
      _verificationStarted = true;
    });

    try {
      final success =
          await _authService.verifyOtp(
        verificationId:
            _verificationId,
        otp: otp,
      );

      if (!mounted) return;

      if (!success) {
        setState(() {
          _loading = false;
          _verificationStarted = false;
        });

        _showError(
          'Invalid OTP. Please check the code.',
        );

        return;
      }

      // ========================================================
      // OTP SUCCESS
      // ========================================================
      //
      // IMPORTANT:
      //
      // We DO NOT create a customer here immediately.
      //
      // First we check whether this authenticated Firebase UID
      // belongs to an admin for the current tenant.
      //
      // ========================================================

      await _routeAfterLogin();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _verificationStarted = false;
      });

      _showError(
        'Unable to verify OTP. Please try again.',
      );
    }
  }

  // ============================================================
  // ROUTE AFTER LOGIN
  // ============================================================

  Future<void> _routeAfterLogin() async {
    try {
      final user =
          _authService.currentUser;

      if (user == null) {
        throw Exception(
          'Authenticated user was not found.',
        );
      }

      final tenantId = _tenantId;

      final uid = user.uid;

      // ========================================================
      // CHECK ADMIN
      // ========================================================

      final adminDoc = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('admins')
          .doc(uid)
          .get();

      if (!mounted) return;

      // ========================================================
      // ADMIN EXISTS
      // ========================================================

      if (adminDoc.exists) {
        final adminData =
            adminDoc.data() ?? {};

        final storedTenantId =
            adminData['tenantId']
                    ?.toString()
                    .trim() ??
                '';

        // ------------------------------------------------------
        // TENANT SECURITY CHECK
        // ------------------------------------------------------

        if (storedTenantId != tenantId) {
          setState(() {
            _loading = false;
            _verificationStarted = false;
          });

          _showError(
            'Your admin account is not assigned to this business.',
          );

          await _authService.logout();

          return;
        }

        // ------------------------------------------------------
        // ACTIVE CHECK
        // ------------------------------------------------------

        final isActive =
            adminData['isActive'] == true;

        if (!isActive) {
          setState(() {
            _loading = false;
            _verificationStarted = false;
          });

          _showError(
            'Your admin account has been disabled. Please contact the business owner.',
          );

          await _authService.logout();

          return;
        }

        // ------------------------------------------------------
        // ROLE
        // ------------------------------------------------------

        final roleId =
            adminData['roleId']
                    ?.toString()
                    .trim() ??
                'admin';

        debugPrint(
          '========================================',
        );
        debugPrint(
          'ADMIN LOGIN SUCCESS',
        );
        debugPrint(
          'UID: $uid',
        );
        debugPrint(
          'Tenant: $tenantId',
        );
        debugPrint(
          'Role: $roleId',
        );
        debugPrint(
          '========================================',
        );

        // ======================================================
        // ADMIN DASHBOARD
        // ======================================================

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) =>
                const AdminDashboardScreen(),
          ),
          (route) => false,
        );

        return;
      }

      // ========================================================
      // NOT ADMIN
      // ========================================================
      //
      // This user is treated as a customer.
      //
      // Only NOW do we create the customer record.
      //
      // ========================================================

      await _createCustomerRecord();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _verificationStarted = false;
      });

      debugPrint(
        'Route after login error: $e',
      );

      _showError(
        'Unable to determine your account. Please try again.',
      );
    }
  }

  // ============================================================
  // CREATE CUSTOMER RECORD
  // ============================================================

  Future<void> _createCustomerRecord() async {
    try {
      final tenantId = _tenantId;

      // ========================================================
      // Customer registration is intentionally NOT mandatory.
      //
      // We create only the minimum customer identity after OTP:
      //
      // Firebase UID
      // tenantId
      // verified phone
      //
      // ========================================================

      await _customerService
          .createCustomerIfNotExists(
        tenantId: tenantId,
      );

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) =>
              const HomeScreen(),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _verificationStarted = false;
      });

      debugPrint(
        'Customer creation error: $e',
      );

      // Authentication succeeded, but customer persistence
      // failed. Do not silently continue because future
      // booking/profile data depends on tenant-scoped identity.

      _showError(
        'Your number is verified, but we could not save your customer profile. Please try again.',
      );
    }
  }

  // ============================================================
  // RESEND TIMER
  // ============================================================

  void _startResendTimer() {
    _timer?.cancel();

    if (!mounted) return;

    setState(() {
      _seconds = 30;
    });

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (_seconds > 0) {
          setState(() {
            _seconds--;
          });
        } else {
          timer.cancel();
        }
      },
    );
  }

  // ============================================================
  // RESEND OTP
  // ============================================================

  Future<void> _resendOtp() async {
    if (_seconds > 0 ||
        _loading ||
        _resending) {
      return;
    }

    setState(() {
      _resending = true;
    });

    try {
      await _authService.sendOtp(
        phoneNumber:
            widget.phoneNumber,
        onCodeSent: (
          String verificationId,
        ) {
          if (!mounted) return;

          _verificationId =
              verificationId;

          _otpController.clear();

          _verificationStarted = false;

          _startResendTimer();

          setState(() {
            _resending = false;
          });

          _showSuccess(
            'A new OTP has been sent.',
          );

          Future.delayed(
            const Duration(
              milliseconds: 250,
            ),
            () {
              if (mounted) {
                _otpFocusNode
                    .requestFocus();
              }
            },
          );
        },
        onError: (
          String message,
        ) {
          if (!mounted) return;

          setState(() {
            _resending = false;
          });

          _showError(
            message.isEmpty
                ? 'Unable to resend OTP. Please try again.'
                : message,
          );
        },
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _resending = false;
      });

      _showError(
        'Unable to resend OTP. Please try again.',
      );
    }
  }

  // ============================================================
  // SUCCESS MESSAGE
  // ============================================================

  void _showSuccess(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 19,
            ),

            const SizedBox(width: 10),

            Expanded(
              child: Text(
                message,
                style:
                    GoogleFonts.manrope(
                  fontSize: 12.5,
                  fontWeight:
                      FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: primary,
        behavior:
            SnackBarBehavior.floating,
        elevation: 0,
        margin:
            const EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20,
        ),
        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(15),
        ),
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  void _showError(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.white,
              size: 19,
            ),

            const SizedBox(width: 10),

            Expanded(
              child: Text(
                message,
                style:
                    GoogleFonts.manrope(
                  fontSize: 12.5,
                  fontWeight:
                      FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: heading,
        behavior:
            SnackBarBehavior.floating,
        elevation: 0,
        margin:
            const EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20,
        ),
        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(15),
        ),
      ),
    );
  }

  // ============================================================
  // OTP INPUT
  // ============================================================

  Widget _buildOtpInput() {
    return TextField(
      controller:
          _otpController,

      focusNode:
          _otpFocusNode,

      autofocus: false,

      keyboardType:
          TextInputType.number,

      textInputAction:
          TextInputAction.done,

      maxLength: 6,

      textAlign:
          TextAlign.center,

      cursorColor:
          primary,

      enabled:
          !_loading &&
          !_resending,

      style:
          GoogleFonts.manrope(
        fontSize: 27,
        fontWeight:
            FontWeight.w800,
        letterSpacing: 12,
        color: heading,
      ),

      decoration:
          InputDecoration(
        counterText: '',

        hintText:
            '• • • • • •',

        hintStyle:
            GoogleFonts.manrope(
          fontSize: 24,
          fontWeight:
              FontWeight.w600,
          letterSpacing: 7,
          color:
              const Color(
            0xFFC7D0CE,
          ),
        ),

        filled: true,

        fillColor:
            Colors.white,

        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 18,
        ),

        border:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(18),

          borderSide:
              const BorderSide(
            color: border,
          ),
        ),

        enabledBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(18),

          borderSide:
              const BorderSide(
            color: border,
          ),
        ),

        focusedBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(18),

          borderSide:
              const BorderSide(
            color: primary,
            width: 1.4,
          ),
        ),

        disabledBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(18),
          borderSide:
              const BorderSide(
            color: border,
          ),
        ),
      ),

      onChanged: (value) {
        if (value.length == 6 &&
            !_loading &&
            !_resending &&
            !_verificationStarted) {
          _verify();
        }

        setState(() {});
      },

      onSubmitted: (_) {
        if (!_loading &&
            !_resending) {
          _verify();
        }
      },
    );
  }

  // ============================================================
  // RESEND
  // ============================================================

  Widget _buildResend() {
    if (_resending) {
      return Row(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child:
                CircularProgressIndicator(
              strokeWidth: 2,
              color: primary,
            ),
          ),

          const SizedBox(width: 8),

          Text(
            'Sending new OTP...',
            style:
                GoogleFonts.manrope(
              fontSize: 12,
              fontWeight:
                  FontWeight.w700,
              color: primary,
            ),
          ),
        ],
      );
    }

    if (_seconds > 0) {
      return Row(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Text(
            "Didn't receive it?",
            style:
                GoogleFonts.manrope(
              fontSize: 12,
              fontWeight:
                  FontWeight.w500,
              color: body,
            ),
          ),

          const SizedBox(width: 5),

          Text(
            'Resend in 00:${_seconds.toString().padLeft(2, '0')}',
            style:
                GoogleFonts.manrope(
              fontSize: 12,
              fontWeight:
                  FontWeight.w800,
              color: primary,
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment:
          MainAxisAlignment.center,
      children: [
        Text(
          "Didn't receive it?",
          style:
              GoogleFonts.manrope(
            fontSize: 12,
            fontWeight:
                FontWeight.w500,
            color: body,
          ),
        ),

        const SizedBox(width: 5),

        GestureDetector(
          onTap:
              _resendOtp,
          behavior:
              HitTestBehavior.opaque,
          child: Text(
            'Resend OTP',
            style:
                GoogleFonts.manrope(
              fontSize: 12,
              fontWeight:
                  FontWeight.w800,
              color: primary,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // VERIFY BUTTON
  // ============================================================

  Widget _buildButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child:
          ElevatedButton(
        onPressed:
            _loading ||
                    _resending
                ? null
                : _verify,

        style:
            ElevatedButton.styleFrom(
          backgroundColor:
              primary,

          disabledBackgroundColor:
              primary.withValues(
            alpha: 0.55,
          ),

          foregroundColor:
              Colors.white,

          elevation: 0,

          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(17),
          ),
        ),

        child: _loading
            ? const SizedBox(
                width: 21,
                height: 21,
                child:
                    CircularProgressIndicator(
                  color:
                      Colors.white,
                  strokeWidth: 2.2,
                ),
              )
            : Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Text(
                    'Verify & Continue',
                    style:
                        GoogleFonts.manrope(
                      fontSize: 14.5,
                      fontWeight:
                          FontWeight.w800,
                      color:
                          Colors.white,
                    ),
                  ),

                  const SizedBox(
                    width: 9,
                  ),

                  const Icon(
                    Icons
                        .arrow_forward_rounded,
                    size: 19,
                    color:
                        Colors.white,
                  ),
                ],
              ),
      ),
    );
  }

  // ============================================================
  // SECURITY FOOTER
  // ============================================================

  Widget _buildSecurityFooter() {
    return Row(
      mainAxisAlignment:
          MainAxisAlignment.center,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration:
              BoxDecoration(
            color:
                softAccent,
            borderRadius:
                BorderRadius.circular(9),
          ),
          child:
              const Icon(
            Icons
                .verified_user_outlined,
            color: primary,
            size: 15,
          ),
        ),

        const SizedBox(
          width: 8,
        ),

        Text(
          'Secure OTP authentication',
          style:
              GoogleFonts.manrope(
            fontSize: 11.5,
            fontWeight:
                FontWeight.w600,
            color: body,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          background,

      body: SafeArea(
        child: Column(
          children: [
            // ==================================================
            // TOP BAR
            // ==================================================

            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                20,
                12,
                20,
                0,
              ),

              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration:
                        BoxDecoration(
                      color:
                          Colors.white,

                      borderRadius:
                          BorderRadius.circular(
                        13,
                      ),

                      border:
                          Border.all(
                        color:
                            border,
                      ),
                    ),

                    child:
                        IconButton(
                      padding:
                          EdgeInsets.zero,

                      onPressed: _loading
                          ? null
                          : () {
                              Navigator.pop(
                                context,
                              );
                            },

                      icon:
                          const Icon(
                        Icons
                            .arrow_back_ios_new_rounded,
                        size: 16,
                        color:
                            heading,
                      ),
                    ),
                  ),

                  const Spacer(),

                  Text(
                    'OTP VERIFICATION',
                    style:
                        GoogleFonts.manrope(
                      fontSize: 9.5,
                      fontWeight:
                          FontWeight.w800,
                      letterSpacing:
                          1.4,
                      color:
                          muted,
                    ),
                  ),
                ],
              ),
            ),

            // ==================================================
            // CONTENT
            // ==================================================

            Expanded(
              child:
                  SingleChildScrollView(
                physics:
                    const BouncingScrollPhysics(),

                padding:
                    const EdgeInsets.fromLTRB(
                  24,
                  50,
                  24,
                  24,
                ),

                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.center,

                  children: [
                    // ------------------------------------------
                    // SMALL ICON
                    // ------------------------------------------

                    Container(
                      width: 58,
                      height: 58,
                      decoration:
                          BoxDecoration(
                        color:
                            softAccent,
                        borderRadius:
                            BorderRadius.circular(
                          18,
                        ),
                      ),

                      child:
                          const Icon(
                        Icons
                            .lock_outline_rounded,
                        color:
                            primary,
                        size: 27,
                      ),
                    ),

                    const SizedBox(
                      height: 25,
                    ),

                    // ------------------------------------------
                    // TITLE
                    // ------------------------------------------

                    Text(
                      'Verify your number',
                      textAlign:
                          TextAlign.center,

                      style:
                          GoogleFonts.manrope(
                        fontSize: 32,
                        height: 1.1,
                        fontWeight:
                            FontWeight.w900,
                        letterSpacing:
                            -0.9,
                        color:
                            heading,
                      ),
                    ),

                    const SizedBox(
                      height: 11,
                    ),

                    // ------------------------------------------
                    // DESCRIPTION
                    // ------------------------------------------

                    Text(
                      'Enter the 6-digit code we sent to',
                      textAlign:
                          TextAlign.center,

                      style:
                          GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight:
                            FontWeight.w500,
                        color:
                            body,
                      ),
                    ),

                    const SizedBox(
                      height: 7,
                    ),

                    // ------------------------------------------
                    // PHONE
                    // ------------------------------------------

                    Text(
                      widget.phoneNumber,
                      textAlign:
                          TextAlign.center,

                      style:
                          GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight:
                            FontWeight.w800,
                        color:
                            heading,
                      ),
                    ),

                    const SizedBox(
                      height: 32,
                    ),

                    // ------------------------------------------
                    // OTP
                    // ------------------------------------------

                    _buildOtpInput(),

                    const SizedBox(
                      height: 16,
                    ),

                    // ------------------------------------------
                    // RESEND
                    // ------------------------------------------

                    _buildResend(),

                    const SizedBox(
                      height: 34,
                    ),

                    // ------------------------------------------
                    // BUTTON
                    // ------------------------------------------

                    _buildButton(),

                    const SizedBox(
                      height: 24,
                    ),

                    // ------------------------------------------
                    // SECURITY
                    // ------------------------------------------

                    _buildSecurityFooter(),

                    const SizedBox(
                      height: 12,
                    ),

                    Text(
                      'Your phone number is securely verified.',
                      textAlign:
                          TextAlign.center,
                      style:
                          GoogleFonts.manrope(
                        fontSize: 10.5,
                        fontWeight:
                            FontWeight.w500,
                        color:
                            muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _timer?.cancel();

    _otpController.dispose();

    _otpFocusNode.dispose();

    super.dispose();
  }
}