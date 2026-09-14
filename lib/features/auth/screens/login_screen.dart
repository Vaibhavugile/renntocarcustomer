import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/app_config.dart';
import '../services/auth_service.dart';
import 'otp_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
  });

  @override
  State<LoginScreen> createState() =>
      _LoginScreenState();
}

class _LoginScreenState
    extends State<LoginScreen> {

  final TextEditingController
      _phoneController =
      TextEditingController();

  final AuthService _authService =
      AuthService();

  bool _loading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  // ============================================================
  // SEND OTP
  // ============================================================

  Future<void> _continue() async {
    final phone =
        _phoneController.text.trim();

    if (phone.length != 10) {
      _showError(
        'Please enter a valid 10-digit mobile number.',
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
    });

    await _authService.sendOtp(
      phoneNumber:
          '+91$phone',

      onCodeSent:
          (verificationId) {

        if (!mounted) return;

        setState(() {
          _loading = false;
        });

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                OtpScreen(
              verificationId:
                  verificationId,

              phoneNumber:
                  '+91$phone',
            ),
          ),
        );
      },

      onError:
          (message) {

        if (!mounted) return;

        setState(() {
          _loading = false;
        });

        _showError(message);
      },
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  void _showError(
    String message,
  ) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content:
            Text(message),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {

    final config =
        AppConfig.tenant;

    final primary =
        Theme.of(context)
            .colorScheme
            .primary;

    final secondary =
        Theme.of(context)
            .colorScheme
            .secondary;

    return Scaffold(
      backgroundColor:
          const Color(
        0xFFF8FAF9,
      ),

      body: SafeArea(
        child: Stack(
          children: [

            // ==================================================
            // TOP SOFT GLOW
            // ==================================================

            Positioned(
              top: -150,
              right: -110,

              child:
                  Container(
                width: 330,
                height: 330,

                decoration:
                    BoxDecoration(
                  shape:
                      BoxShape.circle,

                  color:
                      secondary.withValues(
                    alpha: 0.07,
                  ),
                ),
              ),
            ),

            // ==================================================
            // SMALL DECORATIVE SHAPE
            // ==================================================

            Positioned(
              top: 300,
              left: -190,

              child:
                  Container(
                width: 300,
                height: 300,

                decoration:
                    BoxDecoration(
                  shape:
                      BoxShape.circle,

                  color:
                      primary.withValues(
                    alpha: 0.035,
                  ),
                ),
              ),
            ),

            // ==================================================
            // CONTENT
            // ==================================================

            SingleChildScrollView(
              physics:
                  const BouncingScrollPhysics(),

              padding:
                  const EdgeInsets.fromLTRB(
                24,
                30,
                24,
                24,
              ),

              child:
                  Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [

                  // =================================================
                  // BRAND
                  // =================================================

                  Row(
                    children: [

                      Container(
                        width: 48,
                        height: 48,

                        decoration:
                            BoxDecoration(
                          color:
                              primary,

                          borderRadius:
                              BorderRadius
                                  .circular(
                            15,
                          ),

                          boxShadow: [
                            BoxShadow(
                              color:
                                  primary.withValues(
                                alpha: 0.20,
                              ),

                              blurRadius:
                                  20,

                              offset:
                                  const Offset(
                                0,
                                8,
                              ),
                            ),
                          ],
                        ),

                        child:
                            const Icon(
                          Icons
                              .directions_car_filled_rounded,

                          color:
                              Colors.white,

                          size: 24,
                        ),
                      ),

                      const SizedBox(
                        width: 12,
                      ),

                      Text(
                        config
                            .branding
                            .appName
                            .toUpperCase(),

                        style:
                            GoogleFonts.manrope(
                          fontSize: 16,

                          fontWeight:
                              FontWeight.w900,

                          letterSpacing:
                              1.2,

                          color:
                              const Color(
                            0xFF17201F,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 58,
                  ),

                  // =================================================
                  // HEADLINE
                  // =================================================

                  Text(
                    'Find your\nperfect drive.',
                    style:
                        GoogleFonts.manrope(
                      fontSize: 42,

                      height: 1.03,

                      fontWeight:
                          FontWeight.w900,

                      letterSpacing:
                          -1.5,

                      color:
                          const Color(
                        0xFF17201F,
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 18,
                  ),

                  Text(
                    'Premium cars. Simple booking.\n'
                    'A better way to move.',
                    style:
                        GoogleFonts.manrope(
                      fontSize: 15.5,

                      height: 1.55,

                      fontWeight:
                          FontWeight.w500,

                      color:
                          const Color(
                        0xFF66706E,
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 42,
                  ),

                  // =================================================
                  // LOGIN CARD
                  // =================================================

                  Container(
                    width:
                        double.infinity,

                    padding:
                        const EdgeInsets.all(
                      20,
                    ),

                    decoration:
                        BoxDecoration(
                      color:
                          Colors.white,

                      borderRadius:
                          BorderRadius.circular(
                        26,
                      ),

                      border:
                          Border.all(
                        color:
                            const Color(
                          0xFFE5EBE9,
                        ),
                      ),

                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(
                            0xFF17201F,
                          ).withValues(
                            alpha: 0.045,
                          ),

                          blurRadius:
                              32,

                          offset:
                              const Offset(
                            0,
                            14,
                          ),
                        ),
                      ],
                    ),

                    child:
                        Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,

                      children: [

                        Text(
                          'WELCOME',
                          style:
                              GoogleFonts.manrope(
                            fontSize: 11,

                            fontWeight:
                                FontWeight.w900,

                            letterSpacing:
                                1.7,

                            color:
                                const Color(
                              0xFF66706E,
                            ),
                          ),
                        ),

                        const SizedBox(
                          height: 9,
                        ),

                        Text(
                          'Enter your mobile number',
                          style:
                              GoogleFonts.manrope(
                            fontSize: 18,

                            fontWeight:
                                FontWeight.w800,

                            color:
                                const Color(
                              0xFF17201F,
                            ),
                          ),
                        ),

                        const SizedBox(
                          height: 5,
                        ),

                        Text(
                          'We will send a secure verification code.',
                          style:
                              GoogleFonts.manrope(
                            fontSize: 12.5,

                            fontWeight:
                                FontWeight.w500,

                            color:
                                const Color(
                              0xFF94A09D,
                            ),
                          ),
                        ),

                        const SizedBox(
                          height: 20,
                        ),

                        // =============================================
                        // PHONE INPUT
                        // =============================================

                        Container(
                          height: 62,

                          decoration:
                              BoxDecoration(
                            color:
                                const Color(
                              0xFFF8FAF9,
                            ),

                            borderRadius:
                                BorderRadius.circular(
                              17,
                            ),

                            border:
                                Border.all(
                              color:
                                  const Color(
                                0xFFE5EBE9,
                              ),
                            ),
                          ),

                          child:
                              Row(
                            children: [

                              const SizedBox(
                                width: 15,
                              ),

                              Container(
                                padding:
                                    const EdgeInsets
                                        .symmetric(
                                  horizontal:
                                      11,

                                  vertical:
                                      8,
                                ),

                                decoration:
                                    BoxDecoration(
                                  color:
                                      const Color(
                                    0xFFE6FFFB,
                                  ),

                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    10,
                                  ),
                                ),

                                child:
                                    Text(
                                  '+91',
                                  style:
                                      GoogleFonts.manrope(
                                    fontSize:
                                        14,

                                    fontWeight:
                                        FontWeight.w800,

                                    color:
                                        primary,
                                  ),
                                ),
                              ),

                              const SizedBox(
                                width: 10,
                              ),

                              Container(
                                width: 1,
                                height: 26,

                                color:
                                    const Color(
                                  0xFFE5EBE9,
                                ),
                              ),

                              const SizedBox(
                                width: 10,
                              ),

                              Expanded(
                                child:
                                    TextField(
                                  controller:
                                      _phoneController,

                                  keyboardType:
                                      TextInputType.phone,

                                  maxLength:
                                      10,

                                  style:
                                      GoogleFonts.manrope(
                                    fontSize:
                                        16,

                                    fontWeight:
                                        FontWeight.w700,

                                    color:
                                        const Color(
                                      0xFF17201F,
                                    ),
                                  ),

                                  decoration:
                                      InputDecoration(
                                    hintText:
                                        'Mobile number',

                                    hintStyle:
                                        GoogleFonts.manrope(
                                      color:
                                          const Color(
                                        0xFF9AA5A2,
                                      ),

                                      fontWeight:
                                          FontWeight.w500,
                                    ),

                                    border:
                                        InputBorder
                                            .none,

                                    counterText:
                                        '',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(
                          height: 16,
                        ),

                        // =============================================
                        // CONTINUE
                        // =============================================

                        SizedBox(
                          width:
                              double.infinity,

                          height: 58,

                          child:
                              ElevatedButton(
                            onPressed:
                                _loading
                                    ? null
                                    : _continue,

                            style:
                                ElevatedButton
                                    .styleFrom(
                              backgroundColor:
                                  primary,

                              disabledBackgroundColor:
                                  primary.withValues(
                                alpha: 0.55,
                              ),

                              elevation:
                                  0,

                              shape:
                                  RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(
                                  17,
                                ),
                              ),
                            ),

                            child:
                                _loading
                                    ? const SizedBox(
                                        width:
                                            22,
                                        height:
                                            22,

                                        child:
                                            CircularProgressIndicator(
                                          color:
                                              Colors.white,

                                          strokeWidth:
                                              2.2,
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment
                                                .center,

                                        children: [

                                          Text(
                                            'Continue',
                                            style:
                                                GoogleFonts.manrope(
                                              color:
                                                  Colors.white,

                                              fontSize:
                                                  15.5,

                                              fontWeight:
                                                  FontWeight.w800,
                                            ),
                                          ),

                                          const SizedBox(
                                            width:
                                                9,
                                          ),

                                          const Icon(
                                            Icons
                                                .arrow_forward_rounded,

                                            color:
                                                Colors.white,

                                            size:
                                                21,
                                          ),
                                        ],
                                      ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(
                    height: 28,
                  ),

                  // =================================================
                  // SECURITY
                  // =================================================

                  Center(
                    child:
                        Row(
                      mainAxisSize:
                          MainAxisSize.min,

                      children: [

                        Container(
                          width: 28,
                          height: 28,

                          decoration:
                              BoxDecoration(
                            color:
                                const Color(
                              0xFFE6FFFB,
                            ),

                            borderRadius:
                                BorderRadius
                                    .circular(
                              9,
                            ),
                          ),

                          child:
                              Icon(
                            Icons
                                .verified_user_outlined,

                            size:
                                15,

                            color:
                                primary,
                          ),
                        ),

                        const SizedBox(
                          width: 9,
                        ),

                        Text(
                          'Secure OTP authentication',
                          style:
                              GoogleFonts.manrope(
                            fontSize: 12,

                            fontWeight:
                                FontWeight.w600,

                            color:
                                const Color(
                              0xFF66706E,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  Text(
                    'By continuing, you agree to our '
                    'Terms of Service and Privacy Policy.',
                    textAlign:
                        TextAlign.center,

                    style:
                        GoogleFonts.manrope(
                      fontSize: 10.5,

                      height: 1.45,

                      color:
                          const Color(
                        0xFF9AA5A2,
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