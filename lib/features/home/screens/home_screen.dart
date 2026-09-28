
import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../ai_chat/screens/ai_chat_screen.dart';
import '../../booking/screens/my_bookings_screen.dart';
import '../../customer/screens/profile_screen.dart';
import '../../payment/screens/customer_transactions_screen.dart';
import 'explore_screen.dart';

import '../widgets/active_booking.dart';
import '../widgets/featured_cars.dart';
import '../widgets/home_bottom_nav.dart';
import '../widgets/home_categories.dart';
import '../widgets/home_header.dart';
import '../widgets/home_hero.dart';
import '../widgets/why_choose_us.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  // ============================================================
  // PREMIUM LIGHT THEME
  // ============================================================

  static const Color background = Color(0xFFF7FAF9);
  static const Color surface = Colors.white;

  static const Color primary = Color(0xFF0F766E);
  static const Color primaryDark = Color(0xFF115E59);
  static const Color primaryLight = Color(0xFF19A89B);

  static const Color softAccent = Color(0xFFE7F8F5);

  static const Color heading = Color(0xFF17201F);
  static const Color body = Color(0xFF66706E);
  static const Color muted = Color(0xFF98A3A0);
  static const Color border = Color(0xFFE5ECE9);

  // ============================================================
  // TENANT
  // ============================================================

  String get _tenantId {
    try {
      return AppConfig.tenant.tenantId.trim();
    } catch (_) {
      return '';
    }
  }

  // ============================================================
  // NAVIGATION
  // ============================================================

  int _selectedNav = 0;

  int _bookingCount = 0;

  // ============================================================
  // HOME ANIMATION
  // ============================================================

  late final AnimationController _homeAnimationController;

  late final Animation<double> _homeFadeAnimation;

  late final Animation<Offset> _homeSlideAnimation;

  // ============================================================
  // AI ANIMATION
  // ============================================================

  late final AnimationController _aiAnimationController;

  late final Animation<double> _aiScaleAnimation;

  late final Animation<double> _aiGlowAnimation;

  // ============================================================
  // TRIP STATE
  // ============================================================

  DateTime? _pickupDateTime;

  DateTime? _returnDateTime;

  /// Keep this aligned with your existing booking flow.
  ///
  /// Supported by the availability engine:
  /// - daily
  /// - hourly
  String _rentalType = 'daily';

  bool _hasSelectedTrip = false;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    // ----------------------------------------------------------
    // HOME ENTRANCE
    // ----------------------------------------------------------

    _homeAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 650,
      ),
    );

    _homeFadeAnimation = CurvedAnimation(
      parent: _homeAnimationController,
      curve: Curves.easeOutCubic,
    );

    _homeSlideAnimation = Tween<Offset>(
      begin: const Offset(
        0,
        0.025,
      ),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _homeAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    // ----------------------------------------------------------
    // AI BUTTON
    // ----------------------------------------------------------

    _aiAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 2200,
      ),
    );

    _aiScaleAnimation = Tween<double>(
      begin: 0.96,
      end: 1.04,
    ).animate(
      CurvedAnimation(
        parent: _aiAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _aiGlowAnimation = Tween<double>(
      begin: 0.14,
      end: 0.30,
    ).animate(
      CurvedAnimation(
        parent: _aiAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _aiAnimationController.repeat(
      reverse: true,
    );

    _homeAnimationController.forward();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _homeAnimationController.dispose();
    _aiAnimationController.dispose();

    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor: background,

      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _selectedNav,
          children: [
            _buildHome(),

            ExploreScreen(
              tenantId: _tenantId,
            ),

            MyBookingsScreen(
              tenantId: _tenantId,
            ),

            CustomerTransactionsScreen(
              tenantId: _tenantId,
            ),

            const ProfileScreen(),
          ],
        ),
      ),

      bottomNavigationBar: HomeBottomNav(
        selectedIndex: _selectedNav,
        bookingCount: _bookingCount,
        onChanged: _onNavigationChanged,
      ),

      floatingActionButton: _buildAIButton(),

      floatingActionButtonLocation:
          FloatingActionButtonLocation.endFloat,
    );
  }

  // ============================================================
  // HOME
  // ============================================================

  Widget _buildHome() {
    return FadeTransition(
      opacity: _homeFadeAnimation,
      child: SlideTransition(
        position: _homeSlideAnimation,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ==================================================
            // HEADER
            // ==================================================

            const SliverToBoxAdapter(
              child: HomeHeader(),
            ),

            // ==================================================
            // HERO
            // ==================================================

            const SliverToBoxAdapter(
              child: HomeHero(),
            ),

            // ==================================================
            // TRIP PLANNER
            // ==================================================

            SliverToBoxAdapter(
              child: _buildTripPlanner(),
            ),

            // ==================================================
            // CATEGORIES
            // ==================================================

            const SliverToBoxAdapter(
              child: HomeCategories(),
            ),

            // ==================================================
            // ACTIVE BOOKING
            // ==================================================

            const SliverToBoxAdapter(
              child: ActiveBooking(),
            ),

            // ==================================================
            // FEATURED / AVAILABLE CARS
            //
            // IMPORTANT:
            // Pickup + return are passed directly to FeaturedCars.
            // ==================================================

            SliverToBoxAdapter(
              child: FeaturedCars(
                pickupDateTime: _pickupDateTime,
                returnDateTime: _returnDateTime,
                rentalType: _rentalType,
              ),
            ),

            // ==================================================
            // WHY CHOOSE US
            // ==================================================

            const SliverToBoxAdapter(
              child: WhyChooseUs(),
            ),

            // ==================================================
            // BOTTOM SPACE
            // ==================================================

            const SliverToBoxAdapter(
              child: SizedBox(
                height: 115,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PREMIUM TRIP PLANNER
  // ============================================================

  Widget _buildTripPlanner() {
    final hasTrip = _pickupDateTime != null &&
        _returnDateTime != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        12,
        16,
        18,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(
            28,
          ),
          border: Border.all(
            color: border,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: 0.045,
              ),
              blurRadius: 30,
              offset: const Offset(
                0,
                14,
              ),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            18,
            19,
            18,
            18,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              // ------------------------------------------------
              // HEADER
              // ------------------------------------------------

              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: softAccent,
                      borderRadius:
                          BorderRadius.circular(
                        14,
                      ),
                    ),
                    child: const Icon(
                      Icons.route_rounded,
                      color: primary,
                      size: 21,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Plan your trip',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 17,
                            fontWeight:
                                FontWeight.w900,
                            color: heading,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hasTrip
                              ? 'Your car search is ready'
                              : 'Choose when you need your car',
                          style: const TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 11,
                            fontWeight:
                                FontWeight.w600,
                            color: body,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ------------------------------------------------
                  // CLEAR
                  // ------------------------------------------------

                  if (hasTrip)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius:
                            BorderRadius.circular(
                          12,
                        ),
                        onTap: _clearTrip,
                        child: const Padding(
                          padding: EdgeInsets.all(
                            7,
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            color: muted,
                            size: 19,
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 18),

              // ------------------------------------------------
              // PICKUP / RETURN
              // ------------------------------------------------

              Row(
                children: [
                  Expanded(
                    child: _buildTripField(
                      label: 'PICKUP',
                      icon: Icons.login_rounded,
                      value: _pickupDateTime == null
                          ? 'Select date'
                          : _formatDateTime(
                              _pickupDateTime!,
                            ),
                      onTap: () {
                        _selectTripDateTime(
                          isPickup: true,
                        );
                      },
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: _buildTripField(
                      label: 'RETURN',
                      icon: Icons.logout_rounded,
                      value: _returnDateTime == null
                          ? 'Select date'
                          : _formatDateTime(
                              _returnDateTime!,
                            ),
                      onTap: () {
                        _selectTripDateTime(
                          isPickup: false,
                        );
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ------------------------------------------------
              // RENTAL TYPE
              // ------------------------------------------------

              _buildRentalTypeSelector(),

              const SizedBox(height: 14),

              // ------------------------------------------------
              // SEARCH BUTTON
              // ------------------------------------------------

              _buildFindCarsButton(),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TRIP FIELD
  // ============================================================

  Widget _buildTripField({
    required String label,
    required IconData icon,
    required String value,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(
          19,
        ),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            12,
            12,
            10,
            12,
          ),
          decoration: BoxDecoration(
            color: const Color(
              0xFFFAFCFB,
            ),
            borderRadius:
                BorderRadius.circular(
              19,
            ),
            border: Border.all(
              color: border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: softAccent,
                  borderRadius:
                      BorderRadius.circular(
                    11,
                  ),
                ),
                child: Icon(
                  icon,
                  color: primary,
                  size: 17,
                ),
              ),

              const SizedBox(width: 9),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 8.5,
                        fontWeight:
                            FontWeight.w900,
                        letterSpacing: 0.7,
                        color: muted,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      value,
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 11.5,
                        fontWeight:
                            FontWeight.w900,
                        color:
                            value ==
                                    'Select date'
                                ? body
                                : heading,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons
                    .keyboard_arrow_down_rounded,
                color: muted,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // RENTAL TYPE
  // ============================================================

  Widget _buildRentalTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(
        4,
      ),
      decoration: BoxDecoration(
        color: const Color(
          0xFFF4F7F6,
        ),
        borderRadius:
            BorderRadius.circular(
          15,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildRentalTypeItem(
              value: 'daily',
              title: 'Daily',
              subtitle: 'Best for longer trips',
              icon: Icons.calendar_month_rounded,
            ),
          ),

          Expanded(
            child: _buildRentalTypeItem(
              value: 'hourly',
              title: 'Hourly',
              subtitle: 'Quick city trips',
              icon: Icons.schedule_rounded,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // RENTAL TYPE ITEM
  // ============================================================

  Widget _buildRentalTypeItem({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final selected =
        _rentalType == value;

    return AnimatedContainer(
      duration: const Duration(
        milliseconds: 220,
      ),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: selected
            ? Colors.white
            : Colors.transparent,
        borderRadius:
            BorderRadius.circular(
          12,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: Colors.black
                      .withValues(
                    alpha: 0.045,
                  ),
                  blurRadius: 12,
                  offset: const Offset(
                    0,
                    4,
                  ),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius:
              BorderRadius.circular(
            12,
          ),
          onTap: () {
            if (_rentalType == value) {
              return;
            }

            setState(() {
              _rentalType = value;
            });

            _refreshCarsIfTripSelected();
          },
          child: Padding(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 11,
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: selected
                        ? softAccent
                        : Colors.white,
                    borderRadius:
                        BorderRadius.circular(
                      10,
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: 17,
                    color: selected
                        ? primary
                        : muted,
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily:
                              'Manrope',
                          fontSize: 11.5,
                          fontWeight:
                              FontWeight.w900,
                          color: selected
                              ? heading
                              : body,
                        ),
                      ),
                      const SizedBox(
                        height: 2,
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style:
                            const TextStyle(
                          fontFamily:
                              'Manrope',
                          fontSize: 7.8,
                          fontWeight:
                              FontWeight.w600,
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // FIND CARS BUTTON
  // ============================================================

  Widget _buildFindCarsButton() {
    final ready =
        _pickupDateTime != null &&
            _returnDateTime != null;

    return AnimatedContainer(
      duration: const Duration(
        milliseconds: 250,
      ),
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(
          17,
        ),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryLight,
            primary,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(
              alpha: ready
                  ? 0.22
                  : 0.12,
            ),
            blurRadius: 18,
            offset: const Offset(
              0,
              8,
            ),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius:
              BorderRadius.circular(
            17,
          ),
          onTap: _onFindCars,
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Icon(
                ready
                    ? Icons.search_rounded
                    : Icons.event_available_rounded,
                color: Colors.white,
                size: 20,
              ),

              const SizedBox(width: 9),

              Text(
                ready
                    ? 'Find available cars'
                    : 'Choose your trip dates',
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 13.5,
                  fontWeight:
                      FontWeight.w900,
                  color: Colors.white,
                ),
              ),

              const SizedBox(width: 7),

              const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SELECT DATE + TIME
  // ============================================================

Future<void> _selectTripDateTime({
  required bool isPickup,
}) async {
  final now = DateTime.now();

  DateTime initialDate;

  if (isPickup) {
    initialDate = _pickupDateTime ?? now;
  } else {
    initialDate =
        _returnDateTime ??
        _pickupDateTime?.add(const Duration(days: 1)) ??
        now.add(const Duration(days: 1));
  }

  TimeOfDay initialTime;

  if (isPickup && _pickupDateTime != null) {
    initialTime = TimeOfDay.fromDateTime(_pickupDateTime!);
  } else if (!isPickup && _returnDateTime != null) {
    initialTime = TimeOfDay.fromDateTime(_returnDateTime!);
  } else {
    final nextHour = now.add(const Duration(hours: 1));

    initialTime = TimeOfDay(
      hour: nextHour.hour,
      minute: 0,
    );
  }

  final result = await _showTripDateTimeSheet(
    isPickup: isPickup,
    initialDate: DateTime(
      initialDate.year,
      initialDate.month,
      initialDate.day,
    ),
    initialTime: initialTime,
  );

  if (!mounted || result == null) {
    return;
  }

  final DateTime selectedDate =
      result['date'] as DateTime;

  final TimeOfDay selectedTime =
      result['time'] as TimeOfDay;

  final DateTime selectedDateTime = DateTime(
    selectedDate.year,
    selectedDate.month,
    selectedDate.day,
    selectedTime.hour,
    selectedTime.minute,
  );

  // ------------------------------------------------------------
  // PICKUP
  // ------------------------------------------------------------

  if (isPickup) {
    setState(() {
      _pickupDateTime = selectedDateTime;

      // Existing return becomes invalid.
      // Automatically move it one day after pickup.
      if (_returnDateTime != null &&
          !_returnDateTime!.isAfter(selectedDateTime)) {
        _returnDateTime =
            selectedDateTime.add(
          const Duration(days: 1),
        );
      }

      _hasSelectedTrip =
          _pickupDateTime != null &&
          _returnDateTime != null;
    });

    return;
  }

  // ------------------------------------------------------------
  // RETURN
  // ------------------------------------------------------------

  if (_pickupDateTime != null &&
      !selectedDateTime.isAfter(_pickupDateTime!)) {
    _showPremiumMessage(
      'Return time must be after pickup time.',
      error: true,
    );

    return;
  }

  setState(() {
    _returnDateTime = selectedDateTime;

    _hasSelectedTrip =
        _pickupDateTime != null &&
        _returnDateTime != null;
  });
}
String _formatDate(DateTime date) {
  const List<String> months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  return '${date.day} ${months[date.month - 1]} ${date.year}';
}
Future<Map<String, dynamic>?> _showTripDateTimeSheet({
  required bool isPickup,
  required DateTime initialDate,
  required TimeOfDay initialTime,
}) async {
  DateTime selectedDate = initialDate;
  TimeOfDay selectedTime = initialTime;

  final DateTime now = DateTime.now();

  final DateTime firstDate = DateTime(
    now.year,
    now.month,
    now.day,
  );

  final DateTime lastDate = DateTime(
    now.year + 2,
    now.month,
    now.day,
  );

  List<TimeOfDay> generateTimeSlots(
    DateTime date,
  ) {
    final bool isHourly =
        _rentalType.toLowerCase() == 'hourly';

    // EXACTLY like the DateTimeScreen concept:
    //
    // Hourly -> every 30 minutes
    // Daily  -> every 60 minutes
    //
    final int intervalMinutes =
        isHourly ? 30 : 60;

    final List<TimeOfDay> slots = [];

    for (
      int totalMinutes = 0;
      totalMinutes < 24 * 60;
      totalMinutes += intervalMinutes
    ) {
      final DateTime candidate = DateTime(
        date.year,
        date.month,
        date.day,
        totalMinutes ~/ 60,
        totalMinutes % 60,
      );

      // --------------------------------------------------------
      // PICKUP
      // --------------------------------------------------------

      if (isPickup) {
        if (candidate.isBefore(now)) {
          continue;
        }
      }

      // --------------------------------------------------------
      // RETURN
      // --------------------------------------------------------

      if (!isPickup &&
          _pickupDateTime != null) {
        if (!candidate.isAfter(_pickupDateTime!)) {
          continue;
        }
      }

      slots.add(
        TimeOfDay(
          hour: candidate.hour,
          minute: candidate.minute,
        ),
      );
    }

    return slots;
  }

  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (
          context,
          setSheetState,
        ) {
          final List<TimeOfDay> slots =
              generateTimeSlots(
            selectedDate,
          );

          // ------------------------------------------------------
          // MAKE SURE SELECTED TIME EXISTS
          // ------------------------------------------------------

          final bool selectedTimeExists =
              slots.any(
            (slot) =>
                slot.hour ==
                    selectedTime.hour &&
                slot.minute ==
                    selectedTime.minute,
          );

          if (slots.isNotEmpty &&
              !selectedTimeExists) {
            selectedTime = slots.first;
          }

          final DateTime selectedDateTime =
              DateTime(
            selectedDate.year,
            selectedDate.month,
            selectedDate.day,
            selectedTime.hour,
            selectedTime.minute,
          );

          bool validSelection;

          if (isPickup) {
            validSelection =
                !selectedDateTime.isBefore(now);
          } else {
            validSelection =
                _pickupDateTime != null &&
                selectedDateTime.isAfter(
                  _pickupDateTime!,
                );
          }

          return SafeArea(
            top: false,
            child: Container(
              constraints: BoxConstraints(
                maxHeight:
                    MediaQuery.of(context)
                            .size
                            .height *
                        0.88,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  10,
                  20,
                  20 +
                      MediaQuery.of(context)
                          .viewInsets
                          .bottom,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    // ==================================================
                    // DRAG HANDLE
                    // ==================================================

                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFDDE4E1,
                          ),
                          borderRadius:
                              BorderRadius.circular(
                            20,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ==================================================
                    // HEADER
                    // ==================================================

                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration:
                              BoxDecoration(
                            color: const Color(
                              0xFFE8F7F4,
                            ),
                            borderRadius:
                                BorderRadius.circular(
                              15,
                            ),
                          ),
                          child: Icon(
                            isPickup
                                ? Icons
                                    .login_rounded
                                : Icons
                                    .logout_rounded,
                            color:
                                const Color(
                              0xFF0F766E,
                            ),
                            size: 22,
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              Text(
                                isPickup
                                    ? 'Pickup'
                                    : 'Return',
                                style:
                                    const TextStyle(
                                  fontFamily:
                                      'Manrope',
                                  fontSize: 19,
                                  fontWeight:
                                      FontWeight.w900,
                                  color:
                                      Color(
                                    0xFF17201F,
                                  ),
                                ),
                              ),
                              const SizedBox(
                                height: 3,
                              ),
                              Text(
                                isPickup
                                    ? 'When would you like to pick up the car?'
                                    : 'When would you like to return the car?',
                                style:
                                    const TextStyle(
                                  fontFamily:
                                      'Manrope',
                                  fontSize: 10.5,
                                  fontWeight:
                                      FontWeight.w600,
                                  color:
                                      Color(
                                    0xFF687370,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // ==================================================
                    // RENTAL TYPE
                    // ==================================================

                    Container(
                      width: double.infinity,
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 11,
                      ),
                      decoration:
                          BoxDecoration(
                        color: const Color(
                          0xFFF7FAF9,
                        ),
                        borderRadius:
                            BorderRadius.circular(
                          15,
                        ),
                        border: Border.all(
                          color: const Color(
                            0xFFE4EBE8,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons
                                .calendar_month_rounded,
                            size: 17,
                            color:
                                Color(
                              0xFF0F766E,
                            ),
                          ),
                          const SizedBox(
                            width: 8,
                          ),
                          const Expanded(
                            child: Text(
                              'Rental type',
                              style:
                                  TextStyle(
                                fontFamily:
                                    'Manrope',
                                fontSize: 10,
                                fontWeight:
                                    FontWeight.w700,
                                color:
                                    Color(
                                  0xFF687370,
                                ),
                              ),
                            ),
                          ),
                          Container(
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration:
                                BoxDecoration(
                              color:
                                  const Color(
                                0xFFE8F7F4,
                              ),
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                10,
                              ),
                            ),
                            child: Text(
                              _rentalType
                                          .toLowerCase() ==
                                      'hourly'
                                  ? 'HOURLY'
                                  : 'DAILY',
                              style:
                                  const TextStyle(
                                fontFamily:
                                    'Manrope',
                                fontSize: 8,
                                fontWeight:
                                    FontWeight.w900,
                                color:
                                    Color(
                                  0xFF0F766E,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 15),

                    // ==================================================
                    // DATE
                    // ==================================================

                    const Text(
                      'Select date',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 14,
                        fontWeight:
                            FontWeight.w900,
                        color:
                            Color(0xFF17201F),
                      ),
                    ),

                    const SizedBox(height: 9),

                    Container(
                      decoration:
                          BoxDecoration(
                        color:
                            const Color(
                          0xFFF8FAF9,
                        ),
                        borderRadius:
                            BorderRadius.circular(
                          18,
                        ),
                        border: Border.all(
                          color:
                              const Color(
                            0xFFE4EBE8,
                          ),
                        ),
                      ),
                      child:
                          CalendarDatePicker(
                        initialDate:
                            selectedDate
                                .isBefore(
                          firstDate,
                        )
                                ? firstDate
                                : selectedDate,
                        firstDate:
                            firstDate,
                        lastDate:
                            lastDate,
                        onDateChanged:
                            (DateTime date) {
                          setSheetState(() {
                            selectedDate =
                                DateTime(
                              date.year,
                              date.month,
                              date.day,
                            );

                            final List<
                                    TimeOfDay>
                                newSlots =
                                generateTimeSlots(
                              selectedDate,
                            );

                            final bool
                                stillAvailable =
                                newSlots.any(
                              (slot) =>
                                  slot.hour ==
                                      selectedTime
                                          .hour &&
                                  slot.minute ==
                                      selectedTime
                                          .minute,
                            );

                            if (newSlots
                                    .isNotEmpty &&
                                !stillAvailable) {
                              selectedTime =
                                  newSlots.first;
                            }
                          });
                        },
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ==================================================
                    // TIME HEADER
                    // ==================================================

                    Row(
                      children: [
                        const Icon(
                          Icons
                              .schedule_rounded,
                          size: 19,
                          color:
                              Color(0xFF0F766E),
                        ),
                        const SizedBox(
                          width: 8,
                        ),
                        const Expanded(
                          child: Text(
                            'Select time',
                            style:
                                TextStyle(
                              fontFamily:
                                  'Manrope',
                              fontSize: 14,
                              fontWeight:
                                  FontWeight.w900,
                              color:
                                  Color(
                                0xFF17201F,
                              ),
                            ),
                          ),
                        ),
                        Text(
                          _rentalType
                                      .toLowerCase() ==
                                  'hourly'
                              ? '30 min slots'
                              : '1 hour slots',
                          style:
                              const TextStyle(
                            fontFamily:
                                'Manrope',
                            fontSize: 9,
                            fontWeight:
                                FontWeight.w800,
                            color:
                                Color(
                              0xFF98A3A0,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // ==================================================
                    // TIME SLOTS
                    // ==================================================

                    if (slots.isEmpty)
                      Container(
                        width:
                            double.infinity,
                        padding:
                            const EdgeInsets
                                .all(14),
                        decoration:
                            BoxDecoration(
                          color:
                              const Color(
                            0xFFFFF7ED,
                          ),
                          borderRadius:
                              BorderRadius
                                  .circular(
                            14,
                          ),
                          border:
                              Border.all(
                            color:
                                const Color(
                              0xFFF4D2AA,
                            ),
                          ),
                        ),
                        child:
                            const Text(
                          'No available time slots for this date. Please select another date.',
                          style:
                              TextStyle(
                            fontFamily:
                                'Manrope',
                            fontSize: 10,
                            fontWeight:
                                FontWeight.w700,
                            color:
                                Color(
                              0xFF9A5B18,
                            ),
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        height: 55,
                        child:
                            ListView.separated(
                          scrollDirection:
                              Axis.horizontal,
                          itemCount:
                              slots.length,
                          separatorBuilder:
                              (
                            context,
                            index,
                          ) {
                            return const SizedBox(
                              width: 8,
                            );
                          },
                          itemBuilder:
                              (
                            context,
                            index,
                          ) {
                            final TimeOfDay
                                slot =
                                slots[index];

                            final bool
                                isSelected =
                                slot.hour ==
                                        selectedTime
                                            .hour &&
                                    slot.minute ==
                                        selectedTime
                                            .minute;

                            return GestureDetector(
                              onTap: () {
                                setSheetState(() {
                                  selectedTime =
                                      slot;
                                });
                              },
                              child:
                                  AnimatedContainer(
                                duration:
                                    const Duration(
                                  milliseconds:
                                      180,
                                ),
                                width: 92,
                                decoration:
                                    BoxDecoration(
                                  color:
                                      isSelected
                                          ? const Color(
                                              0xFF0F766E,
                                            )
                                          : const Color(
                                              0xFFF8FAF9,
                                            ),
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    14,
                                  ),
                                  border:
                                      Border.all(
                                    color:
                                        isSelected
                                            ? const Color(
                                                0xFF0F766E,
                                              )
                                            : const Color(
                                                0xFFE4EBE8,
                                              ),
                                  ),
                                  boxShadow:
                                      isSelected
                                          ? [
                                              BoxShadow(
                                                color:
                                                    const Color(
                                                  0xFF0F766E,
                                                ).withValues(
                                                  alpha:
                                                      0.18,
                                                ),
                                                blurRadius:
                                                    12,
                                                offset:
                                                    const Offset(
                                                  0,
                                                  5,
                                                ),
                                              ),
                                            ]
                                          : null,
                                ),
                                child:
                                    Center(
                                  child: Text(
                                    slot.format(
                                      context,
                                    ),
                                    style:
                                        TextStyle(
                                      fontFamily:
                                          'Manrope',
                                      fontSize:
                                          11,
                                      fontWeight:
                                          FontWeight
                                              .w900,
                                      color:
                                          isSelected
                                              ? Colors
                                                  .white
                                              : const Color(
                                                  0xFF17201F,
                                                ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                    const SizedBox(height: 15),

                    // ==================================================
                    // SELECTED SUMMARY
                    // ==================================================

                    Container(
                      width:
                          double.infinity,
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                      decoration:
                          BoxDecoration(
                        color:
                            const Color(
                          0xFFE8F7F4,
                        ),
                        borderRadius:
                            BorderRadius.circular(
                          15,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons
                                .event_available_rounded,
                            size: 19,
                            color:
                                Color(
                              0xFF0F766E,
                            ),
                          ),
                          const SizedBox(
                            width: 9,
                          ),
                          Expanded(
                            child: Text(
                              '${_formatDate(selectedDate)} • ${selectedTime.format(context)}',
                              style:
                                  const TextStyle(
                                fontFamily:
                                    'Manrope',
                                fontSize: 11,
                                fontWeight:
                                    FontWeight.w900,
                                color:
                                    Color(
                                  0xFF14534E,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 17),

                    // ==================================================
                    // CONFIRM BUTTON
                    // ==================================================

                    SizedBox(
                      width:
                          double.infinity,
                      height: 54,
                      child: DecoratedBox(
                        decoration:
                            BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(
                            17,
                          ),
                          gradient:
                              const LinearGradient(
                            begin:
                                Alignment
                                    .centerLeft,
                            end:
                                Alignment
                                    .centerRight,
                            colors: [
                              Color(
                                0xFF14B8A6,
                              ),
                              Color(
                                0xFF0F766E,
                              ),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  const Color(
                                0xFF0F766E,
                              ).withValues(
                                alpha: 0.18,
                              ),
                              blurRadius: 14,
                              offset:
                                  const Offset(
                                0,
                                6,
                              ),
                            ),
                          ],
                        ),
                        child: Material(
                          color:
                              Colors.transparent,
                          child: InkWell(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              17,
                            ),
                            onTap:
                                !validSelection
                                    ? null
                                    : () {
                                        Navigator.pop(
                                          sheetContext,
                                          <
                                              String,
                                              dynamic>{
                                            'date':
                                                selectedDate,
                                            'time':
                                                selectedTime,
                                          },
                                        );
                                      },
                            child: Center(
                              child: Text(
                                isPickup
                                    ? 'Confirm pickup'
                                    : 'Confirm return',
                                style:
                                    TextStyle(
                                  fontFamily:
                                      'Manrope',
                                  fontSize:
                                      14,
                                  fontWeight:
                                      FontWeight
                                          .w900,
                                  color:
                                      validSelection
                                          ? Colors
                                              .white
                                          : Colors
                                              .white54,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

  // ============================================================
  // FIND CARS
  // ============================================================

  void _onFindCars() {
    final pickup =
        _pickupDateTime;

    final returnDateTime =
        _returnDateTime;

    if (pickup == null ||
        returnDateTime == null) {
      _showPremiumMessage(
        'Please select pickup and return first.',
        error: true,
      );

      return;
    }

    if (!returnDateTime
        .isAfter(
      pickup,
    )) {
      _showPremiumMessage(
        'Return must be after pickup.',
        error: true,
      );

      return;
    }

    // ----------------------------------------------------------
    // FeaturedCars automatically receives these values because
    // they are stored in Home state.
    //
    // setState triggers the availability-aware FeaturedCars
    // widget to refresh.
    // ----------------------------------------------------------

    setState(() {
      _hasSelectedTrip = true;
    });

    _showPremiumMessage(
      'Checking cars available for your trip.',
    );
  }

  // ============================================================
  // REFRESH AFTER RENTAL TYPE CHANGE
  // ============================================================

  void _refreshCarsIfTripSelected() {
    if (_pickupDateTime == null ||
        _returnDateTime == null) {
      return;
    }

    setState(() {
      _hasSelectedTrip = true;
    });
  }

  // ============================================================
  // CLEAR TRIP
  // ============================================================

  void _clearTrip() {
    setState(() {
      _pickupDateTime = null;
      _returnDateTime = null;
      _hasSelectedTrip = false;
    });

    _showPremiumMessage(
      'Trip dates cleared.',
    );
  }

  // ============================================================
  // DATE/TIME FORMAT
  // ============================================================

  String _formatDateTime(
    DateTime value,
  ) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final hour =
        value.hour % 12 == 0
            ? 12
            : value.hour % 12;

    final minute =
        value.minute
            .toString()
            .padLeft(
              2,
              '0',
            );

    final period =
        value.hour >= 12
            ? 'PM'
            : 'AM';

    return '${value.day} ${months[value.month - 1]}'
        '\n'
        '$hour:$minute $period';
  }

  // ============================================================
  // AI BUTTON
  // ============================================================

  Widget _buildAIButton() {
    return AnimatedBuilder(
      animation:
          _aiAnimationController,
      builder: (
        context,
        child,
      ) {
        return Transform.scale(
          scale:
              _aiScaleAnimation.value,
          child: Container(
            width: 58,
            height: 58,
            decoration:
                BoxDecoration(
              shape:
                  BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color:
                      primary.withValues(
                    alpha:
                        _aiGlowAnimation
                            .value,
                  ),
                  blurRadius: 18,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: Material(
              color:
                  Colors.transparent,
              shape:
                  const CircleBorder(),
              child: InkWell(
                onTap:
                    _openAIChat,
                customBorder:
                    const CircleBorder(),
                child: Container(
                  width: 58,
                  height: 58,
                  decoration:
                      const BoxDecoration(
                    shape:
                        BoxShape.circle,
                    gradient:
                        LinearGradient(
                      begin:
                          Alignment
                              .topLeft,
                      end:
                          Alignment
                              .bottomRight,
                      colors: [
                        primaryLight,
                        primary,
                      ],
                    ),
                  ),
                  child: Stack(
                    alignment:
                        Alignment
                            .center,
                    children: [
                      Positioned(
                        top: 7,
                        left: 10,
                        child:
                            Container(
                          width: 14,
                          height: 8,
                          decoration:
                              BoxDecoration(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              20,
                            ),
                            color: Colors
                                .white
                                .withValues(
                              alpha:
                                  0.20,
                            ),
                          ),
                        ),
                      ),

                      const Icon(
                        Icons
                            .auto_awesome_rounded,
                        color:
                            Colors.white,
                        size: 25,
                      ),

                      Positioned(
                        right: 4,
                        bottom: 4,
                        child:
                            Container(
                          width: 13,
                          height: 13,
                          decoration:
                              BoxDecoration(
                            shape:
                                BoxShape
                                    .circle,
                            color:
                                const Color(
                              0xFF34D399,
                            ),
                            border:
                                Border.all(
                              color:
                                  Colors
                                      .white,
                              width:
                                  2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // AI CHAT
  // ============================================================

  void _openAIChat() {
    final tenantId =
        _tenantId;

    if (tenantId.isEmpty) {
      _showPremiumMessage(
        'We could not identify your rental account.',
        error: true,
      );

      return;
    }

    Navigator.of(
      context,
    ).push(
      MaterialPageRoute(
        builder: (_) =>
            AIChatScreen(
          tenantId:
              tenantId,
        ),
      ),
    );
  }

  // ============================================================
  // NAVIGATION
  // ============================================================

  void _onNavigationChanged(
    int index,
  ) {
    if (index < 0 ||
        index > 4) {
      return;
    }

    if (_selectedNav ==
        index) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedNav =
          index;
    });
  }

  // ============================================================
  // PREMIUM MESSAGE
  // ============================================================

  void _showPremiumMessage(
    String message, {
    bool error = false,
  }) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    )
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior:
              SnackBarBehavior
                  .floating,
          margin:
              const EdgeInsets.fromLTRB(
            16,
            0,
            16,
            92,
          ),
          elevation: 0,
          backgroundColor:
              error
                  ? const Color(
                      0xFF241B1B,
                    )
                  : heading,
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius
                    .circular(
              18,
            ),
          ),
          content:
              Row(
            children: [
              Container(
                width: 35,
                height: 35,
                decoration:
                    BoxDecoration(
                  color: error
                      ? const Color(
                          0xFFFFE4E4,
                        )
                      : primary.withValues(
                          alpha:
                              0.18,
                        ),
                  shape:
                      BoxShape
                          .circle,
                ),
                child:
                    Icon(
                  error
                      ? Icons
                          .error_outline_rounded
                      : Icons
                          .auto_awesome_rounded,
                  color: error
                      ? const Color(
                          0xFFEF8B8B,
                        )
                      : const Color(
                          0xFF5EEAD4,
                        ),
                  size: 18,
                ),
              ),

              const SizedBox(
                width: 12,
              ),

              Expanded(
                child:
                    Text(
                  message,
                  style:
                      const TextStyle(
                    fontFamily:
                        'Manrope',
                    fontSize:
                        12,
                    fontWeight:
                        FontWeight.w700,
                    color:
                        Colors.white,
                    height:
                        1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }
}

