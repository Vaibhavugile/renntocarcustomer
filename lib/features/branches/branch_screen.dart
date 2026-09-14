import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/config/app_config.dart';
import '../../core/services/branch_service.dart';
import '../../models/branch.dart';

class BranchScreen extends StatefulWidget {
  const BranchScreen({super.key});

  @override
  State<BranchScreen> createState() => _BranchScreenState();
}

class _BranchScreenState extends State<BranchScreen> {
  // ============================================================
  // SERVICES
  // ============================================================

  final BranchService _branchService = BranchService();

  // ============================================================
  // DATA
  // ============================================================

  List<Branch> branches = [];

  bool isLoading = true;

  String? errorMessage;

  // ============================================================
  // FIXED PREMIUM COLORS
  //
  // IMPORTANT:
  // These colors do NOT come from Firebase.
  // ============================================================

  static const Color backgroundColor =
      Color(0xFFF8FAF9);

  static const Color cardColor =
      Color(0xFFFFFFFF);

  static const Color primaryColor =
      Color(0xFF0F766E);

  static const Color accentColor =
      Color(0xFF14B8A6);

  static const Color softAccentColor =
      Color(0xFFE6FFFB);

  static const Color headingColor =
      Color(0xFF17201F);

  static const Color bodyColor =
      Color(0xFF66706E);

  static const Color borderColor =
      Color(0xFFE5EBE9);

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    loadBranches();
  }

  // ============================================================
  // LOAD BRANCHES
  // ============================================================

  Future<void> loadBranches() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
    }

    try {
      final tenantId =
          AppConfig.tenant.tenantId;

      final result =
          await _branchService.getBranches(
        tenantId,
      );

      if (!mounted) return;

      setState(() {
        branches = result;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        branches = [];
        isLoading = false;
        errorMessage =
            'Unable to load rental locations.';
      });
    }
  }

  // ============================================================
  // SELECT BRANCH
  // ============================================================

  void _selectBranch(Branch branch) {
    // Branch selection will be connected to the
    // booking flow in the next step.

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withValues(
                  alpha: 0.18,
                ),
                borderRadius:
                    BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.location_on_rounded,
                color: Colors.white,
                size: 19,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${branch.name} selected',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight:
                      FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor:
            const Color(0xFF25302E),
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
              BorderRadius.circular(16),
        ),
      ),
    );
  }

  // ============================================================
  // LOCATION ICON
  // ============================================================

  Widget _buildLocationIcon() {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: softAccentColor,
        borderRadius:
            BorderRadius.circular(17),
      ),
      child: const Icon(
        Icons.location_on_rounded,
        color: primaryColor,
        size: 26,
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
      margin:
          const EdgeInsets.only(bottom: 16),

      decoration: BoxDecoration(
        color: cardColor,

        borderRadius:
            BorderRadius.circular(22),

        border: Border.all(
          color: borderColor,
          width: 1,
        ),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.035,
            ),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),

      child: Padding(
        padding:
            const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [
            // --------------------------------------------------
            // TOP ROW
            // --------------------------------------------------

            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                _buildLocationIcon(),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,

                    children: [
                      Text(
                        branch.name,
                        maxLines: 2,
                        overflow:
                            TextOverflow.ellipsis,
                        style:
                            GoogleFonts.manrope(
                          fontSize: 17,
                          height: 1.25,
                          fontWeight:
                              FontWeight.w800,
                          color:
                              headingColor,
                        ),
                      ),

                      const SizedBox(
                        height: 6,
                      ),

                      Row(
                        children: [
                          const Icon(
                            Icons
                                .check_circle_rounded,
                            size: 14,
                            color:
                                primaryColor,
                          ),

                          const SizedBox(
                              width: 5),

                          Text(
                            'Available for pickup',
                            style:
                                GoogleFonts.manrope(
                              fontSize: 10.5,
                              fontWeight:
                                  FontWeight.w700,
                              color:
                                  primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 18,
            ),

            // --------------------------------------------------
            // DIVIDER
            // --------------------------------------------------

            Container(
              height: 1,
              color: borderColor,
            ),

            const SizedBox(
              height: 17,
            ),

            // --------------------------------------------------
            // ADDRESS
            // --------------------------------------------------

            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                const Icon(
                  Icons
                      .place_outlined,
                  size: 19,
                  color: bodyColor,
                ),

                const SizedBox(
                  width: 10,
                ),

                Expanded(
                  child: Text(
                    branch.address,
                    style:
                        GoogleFonts.manrope(
                      fontSize: 13,
                      height: 1.45,
                      fontWeight:
                          FontWeight.w500,
                      color:
                          bodyColor,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 10,
            ),

            // --------------------------------------------------
            // CITY
            // --------------------------------------------------

            Row(
              children: [
                const Icon(
                  Icons
                      .location_city_outlined,
                  size: 18,
                  color: bodyColor,
                ),

                const SizedBox(
                  width: 10,
                ),

                Text(
                  branch.city,
                  style:
                      GoogleFonts.manrope(
                    fontSize: 12.5,
                    fontWeight:
                        FontWeight.w700,
                    color:
                        headingColor,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 18,
            ),

            // --------------------------------------------------
            // PHONE
            // --------------------------------------------------

            if (branch.phone.isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.only(
                  bottom: 18,
                ),

                child: Row(
                  children: [
                    const Icon(
                      Icons
                          .phone_outlined,
                      size: 18,
                      color: bodyColor,
                    ),

                    const SizedBox(
                      width: 10,
                    ),

                    Text(
                      branch.phone,
                      style:
                          GoogleFonts.manrope(
                        fontSize: 12.5,
                        fontWeight:
                            FontWeight.w600,
                        color:
                            bodyColor,
                      ),
                    ),
                  ],
                ),
              ),

            // --------------------------------------------------
            // SELECT BUTTON
            // --------------------------------------------------

            SizedBox(
              width: double.infinity,
              height: 52,

              child:
                  ElevatedButton(
                onPressed: () {
                  _selectBranch(
                    branch,
                  );
                },

                style:
                    ElevatedButton.styleFrom(
                  backgroundColor:
                      primaryColor,

                  foregroundColor:
                      Colors.white,

                  elevation: 0,

                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius
                            .circular(
                      16,
                    ),
                  ),
                ),

                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .center,

                  children: [
                    Text(
                      'Select Location',
                      style:
                          GoogleFonts.manrope(
                        fontSize: 13.5,
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
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // LOADING
  // ============================================================

  Widget _buildLoading() {
    return ListView(
      padding:
          const EdgeInsets.fromLTRB(
        20,
        20,
        20,
        30,
      ),

      children: [
        _buildLoadingCard(),
        _buildLoadingCard(),
        _buildLoadingCard(),
      ],
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      height: 225,

      margin:
          const EdgeInsets.only(
        bottom: 16,
      ),

      decoration: BoxDecoration(
        color: cardColor,

        borderRadius:
            BorderRadius.circular(22),

        border: Border.all(
          color: borderColor,
        ),
      ),

      child: Padding(
        padding:
            const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [
            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration:
                      BoxDecoration(
                    color:
                        const Color(
                      0xFFEFF3F2,
                    ),
                    borderRadius:
                        BorderRadius
                            .circular(
                      17,
                    ),
                  ),
                ),

                const SizedBox(
                    width: 14),

                Expanded(
                  child:
                      Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Container(
                        width: 160,
                        height: 15,
                        decoration:
                            BoxDecoration(
                          color:
                              const Color(
                            0xFFEFF3F2,
                          ),
                          borderRadius:
                              BorderRadius
                                  .circular(
                            8,
                          ),
                        ),
                      ),

                      const SizedBox(
                          height: 9),

                      Container(
                        width: 115,
                        height: 10,
                        decoration:
                            BoxDecoration(
                          color:
                              const Color(
                            0xFFEFF3F2,
                          ),
                          borderRadius:
                              BorderRadius
                                  .circular(
                            8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(
                height: 22),

            Container(
              width: double.infinity,
              height: 12,
              decoration:
                  BoxDecoration(
                color:
                    const Color(
                  0xFFEFF3F2,
                ),
                borderRadius:
                    BorderRadius
                        .circular(
                  8,
                ),
              ),
            ),

            const SizedBox(
                height: 10),

            Container(
              width: 180,
              height: 12,
              decoration:
                  BoxDecoration(
                color:
                    const Color(
                  0xFFEFF3F2,
                ),
                borderRadius:
                    BorderRadius
                        .circular(
                  8,
                ),
              ),
            ),

            const Spacer(),

            Container(
              width: double.infinity,
              height: 48,
              decoration:
                  BoxDecoration(
                color:
                    const Color(
                  0xFFEFF3F2,
                ),
                borderRadius:
                    BorderRadius
                        .circular(
                  16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(30),

        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,

          children: [
            Container(
              width: 76,
              height: 76,

              decoration:
                  BoxDecoration(
                color:
                    softAccentColor,
                borderRadius:
                    BorderRadius.circular(
                  24,
                ),
              ),

              child: const Icon(
                Icons
                    .location_off_outlined,
                size: 34,
                color:
                    primaryColor,
              ),
            ),

            const SizedBox(
              height: 22,
            ),

            Text(
              'No locations available',
              textAlign:
                  TextAlign.center,
              style:
                  GoogleFonts.manrope(
                fontSize: 20,
                fontWeight:
                    FontWeight.w800,
                color:
                    headingColor,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            Text(
              'There are currently no rental locations available for this service.',
              textAlign:
                  TextAlign.center,
              style:
                  GoogleFonts.manrope(
                fontSize: 13,
                height: 1.5,
                fontWeight:
                    FontWeight.w500,
                color:
                    bodyColor,
              ),
            ),

            const SizedBox(
              height: 22,
            ),

            OutlinedButton.icon(
              onPressed:
                  loadBranches,

              icon: const Icon(
                Icons.refresh_rounded,
                size: 18,
              ),

              label: Text(
                'Try Again',
                style:
                    GoogleFonts.manrope(
                  fontWeight:
                      FontWeight.w800,
                ),
              ),

              style:
                  OutlinedButton.styleFrom(
                foregroundColor:
                    primaryColor,

                side: const BorderSide(
                  color:
                      borderColor,
                ),

                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ERROR STATE
  // ============================================================

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(30),

        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,

          children: [
            Container(
              width: 76,
              height: 76,

              decoration:
                  BoxDecoration(
                color:
                    const Color(
                  0xFFFFF3F1,
                ),

                borderRadius:
                    BorderRadius.circular(
                  24,
                ),
              ),

              child: const Icon(
                Icons
                    .cloud_off_rounded,
                size: 34,
                color:
                    Color(0xFFB84A3A),
              ),
            ),

            const SizedBox(
                height: 22),

            Text(
              'Something went wrong',
              textAlign:
                  TextAlign.center,
              style:
                  GoogleFonts.manrope(
                fontSize: 20,
                fontWeight:
                    FontWeight.w800,
                color:
                    headingColor,
              ),
            ),

            const SizedBox(
                height: 8),

            Text(
              errorMessage ??
                  'Unable to load locations.',
              textAlign:
                  TextAlign.center,
              style:
                  GoogleFonts.manrope(
                fontSize: 13,
                height: 1.5,
                fontWeight:
                    FontWeight.w500,
                color:
                    bodyColor,
              ),
            ),

            const SizedBox(
                height: 22),

            ElevatedButton.icon(
              onPressed:
                  loadBranches,

              icon: const Icon(
                Icons.refresh_rounded,
                size: 18,
              ),

              label: Text(
                'Try Again',
                style:
                    GoogleFonts.manrope(
                  fontWeight:
                      FontWeight.w800,
                ),
              ),

              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    primaryColor,
                foregroundColor:
                    Colors.white,
                elevation: 0,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
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
  Widget build(
    BuildContext context,
  ) {
    final config =
        AppConfig.tenant;

    final appName =
        config.branding.appName
                .isNotEmpty
            ? config.branding.appName
            : 'Rental';

    return Scaffold(
      backgroundColor:
          backgroundColor,

      body: SafeArea(
        child: Column(
          children: [
            // ==================================================
            // HEADER
            // ==================================================

            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                22,
                16,
                22,
                8,
              ),

              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,

                    decoration:
                        BoxDecoration(
                      color:
                          cardColor,

                      borderRadius:
                          BorderRadius.circular(
                        14,
                      ),

                      border:
                          Border.all(
                        color:
                            borderColor,
                      ),
                    ),

                    child:
                        IconButton(
                      onPressed: () {
                        Navigator.pop(
                          context,
                        );
                      },

                      icon:
                          const Icon(
                        Icons
                            .arrow_back_ios_new_rounded,
                        size: 17,
                        color:
                            headingColor,
                      ),
                    ),
                  ),

                  const Spacer(),

                  Container(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),

                    decoration:
                        BoxDecoration(
                      color:
                          softAccentColor,

                      borderRadius:
                          BorderRadius.circular(
                        10,
                      ),
                    ),

                    child: Row(
                      mainAxisSize:
                          MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons
                              .verified_rounded,
                          size: 14,
                          color:
                              primaryColor,
                        ),

                        const SizedBox(
                            width: 5),

                        Text(
                          appName,
                          style:
                              GoogleFonts.manrope(
                            fontSize: 10,
                            fontWeight:
                                FontWeight.w800,
                            color:
                                primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ==================================================
            // PAGE CONTENT
            // ==================================================

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [
                  Padding(
                    padding:
                        const EdgeInsets
                            .fromLTRB(
                      24,
                      24,
                      24,
                      18,
                    ),

                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,

                      children: [
                        Text(
                          'Choose your',
                          style:
                              GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight:
                                FontWeight.w600,
                            color:
                                bodyColor,
                          ),
                        ),

                        const SizedBox(
                            height: 2),

                        Text(
                          'pickup location.',
                          style:
                              GoogleFonts.manrope(
                            fontSize: 32,
                            height: 1.1,
                            fontWeight:
                                FontWeight.w800,
                            letterSpacing:
                                -0.8,
                            color:
                                headingColor,
                          ),
                        ),

                        const SizedBox(
                            height: 9),

                        Text(
                          'Select a rental location that works best for you.',
                          style:
                              GoogleFonts.manrope(
                            fontSize: 13,
                            height: 1.5,
                            fontWeight:
                                FontWeight.w500,
                            color:
                                bodyColor,
                          ),
                        ),

                        const SizedBox(
                            height: 16),

                        // Location count
                        if (!isLoading &&
                            branches.isNotEmpty)
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration:
                                    const BoxDecoration(
                                  color:
                                      accentColor,
                                  shape:
                                      BoxShape.circle,
                                ),
                              ),

                              const SizedBox(
                                  width: 7),

                              Text(
                                '${branches.length} locations available',
                                style:
                                    GoogleFonts.manrope(
                                  fontSize:
                                      11,
                                  fontWeight:
                                      FontWeight
                                          .w700,
                                  color:
                                      primaryColor,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),

                  // ==================================================
                  // BRANCH LIST / STATES
                  // ==================================================

                  Expanded(
                    child: isLoading
                        ? _buildLoading()
                        : errorMessage !=
                                null
                            ? _buildErrorState()
                            : branches
                                    .isEmpty
                                ? _buildEmptyState()
                                : RefreshIndicator(
                                    color:
                                        primaryColor,

                                    onRefresh:
                                        loadBranches,

                                    child:
                                        ListView.builder(
                                      physics:
                                          const AlwaysScrollableScrollPhysics(),

                                      padding:
                                          const EdgeInsets.fromLTRB(
                                        20,
                                        0,
                                        20,
                                        30,
                                      ),

                                      itemCount:
                                          branches.length,

                                      itemBuilder:
                                          (
                                        context,
                                        index,
                                      ) {
                                        return _buildBranchCard(
                                          branches[
                                              index],
                                        );
                                      },
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