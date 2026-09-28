
import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../admin/availability/services/admin_availability_service.dart';
import '../../cars/models/car.dart';
import '../../cars/screens/car_details_screen.dart';
import '../../cars/services/car_service.dart';
import 'car_card.dart';

class FeaturedCars extends StatefulWidget {
  /// Customer's selected pickup date/time from Home.
  final DateTime? pickupDateTime;

  /// Customer's selected return date/time from Home.
  final DateTime? returnDateTime;

  /// Current rental mode.
  ///
  /// Keep this aligned with Explore / booking:
  /// 'daily' or 'hourly'.
  final String rentalType;

  const FeaturedCars({
    super.key,
    this.pickupDateTime,
    this.returnDateTime,
    this.rentalType = 'daily',
  });

  @override
  State<FeaturedCars> createState() => _FeaturedCarsState();
}

class _FeaturedCarsState extends State<FeaturedCars> {
  // ============================================================
  // SERVICES
  // ============================================================

  final CarService _carService = CarService.instance;

  final AdminAvailabilityService _availabilityService =
      AdminAvailabilityService.instance;

  // ============================================================
  // PALETTE
  // ============================================================

  static const Color background = Color(0xFFF8FAF9);
  static const Color card = Colors.white;
  static const Color primary = Color(0xFF0F766E);
  static const Color accent = Color(0xFF14B8A6);
  static const Color softAccent = Color(0xFFE6FFFB);
  static const Color heading = Color(0xFF17201F);
  static const Color body = Color(0xFF66706E);
  static const Color muted = Color(0xFF94A09D);
  static const Color border = Color(0xFFE5EBE9);

  // ============================================================
  // STATE
  // ============================================================

  List<Car> _featuredCars = <Car>[];

  bool _isLoading = true;

  bool _isCheckingAvailability = false;

  String? _errorMessage;

  int _loadGeneration = 0;

  String get _tenantId =>
      AppConfig.tenant.tenantId.trim();

  // ============================================================
  // LIFECYCLE
  // ============================================================

  @override
  void initState() {
    super.initState();

    _loadCars();
  }

  @override
  void didUpdateWidget(
    covariant FeaturedCars oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    final datesChanged =
        oldWidget.pickupDateTime != widget.pickupDateTime ||
            oldWidget.returnDateTime != widget.returnDateTime;

    final rentalTypeChanged =
        oldWidget.rentalType != widget.rentalType;

    if (datesChanged || rentalTypeChanged) {
      _loadCars();
    }
  }

  // ============================================================
  // LOAD
  // ============================================================

  Future<void> _loadCars() async {
    final int generation = ++_loadGeneration;

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _isCheckingAvailability = false;
      _errorMessage = null;
    });

    try {
      if (_tenantId.isEmpty) {
        throw Exception(
          'Tenant configuration is missing.',
        );
      }

      // --------------------------------------------------------
      // IMPORTANT
      //
      // We intentionally start from featured cars because this
      // section is still the Home "featured" section.
      //
      // Availability is then applied ON TOP of the featured
      // fleet.
      // --------------------------------------------------------

      final cars = await _carService.getFeaturedCars(
        tenantId: _tenantId,
      );

      if (!mounted || generation != _loadGeneration) {
        return;
      }

      // --------------------------------------------------------
      // No dates selected yet
      //
      // Show active featured cars normally.
      // Once Home passes dates, availability is checked.
      // --------------------------------------------------------

      if (!_hasValidTripDates) {
        setState(() {
          _featuredCars = cars
              .where(
                (car) => car.isActive,
              )
              .toList();

          _isLoading = false;
          _isCheckingAvailability = false;
        });

        return;
      }

      // --------------------------------------------------------
      // CHECK AVAILABILITY
      // --------------------------------------------------------

      setState(() {
        _isCheckingAvailability = true;
      });

      final pickup = widget.pickupDateTime!;

      final returnDateTime =
          widget.returnDateTime!;

      if (!returnDateTime.isAfter(pickup)) {
        setState(() {
          _featuredCars = <Car>[];
          _isLoading = false;
          _isCheckingAvailability = false;
          _errorMessage =
              'Return date and time must be after pickup.';
        });

        return;
      }

      // --------------------------------------------------------
      // USE THE SAME RANGE NORMALIZATION AS EXPLORE
      // --------------------------------------------------------

      final range =
          _availabilityService.normalizeRentalRange(
        pickupDateTime: pickup,
        returnDateTime: returnDateTime,
        rentalType: widget.rentalType,
      );

      // --------------------------------------------------------
      // GET ONE AVAILABILITY SNAPSHOT
      //
      // This is intentionally done once for the entire section.
      // We DO NOT call Firestore separately for every car.
      // --------------------------------------------------------

      final snapshot =
          await _availabilityService.getAvailabilityForRange(
        rangeStart: range.start,
        rangeEnd: range.end,
        tenantId: _tenantId,
      );

      // --------------------------------------------------------
      // CREATE FAST LOOKUP SET
      //
      // Only featured cars that are actually available for the
      // selected range remain visible.
      // --------------------------------------------------------

      final availableCarIds = snapshot.cars
          .where(
            (car) => _availabilityService
                .isCarAvailableForRange(
              car: car,
              start: range.start,
              end: range.end,
              bookings: snapshot.bookings,
              blocks: snapshot.blocks,
            ),
          )
          .map(
            (car) => car.id,
          )
          .toSet();

      // --------------------------------------------------------
      // FILTER ORIGINAL FEATURED LIST
      //
      // This keeps Home's featured ordering.
      // --------------------------------------------------------

      final availableFeaturedCars =
          cars.where(
        (car) =>
            car.isActive &&
            availableCarIds.contains(
              car.id,
            ),
      ).toList();

      if (!mounted || generation != _loadGeneration) {
        return;
      }

      setState(() {
        _featuredCars = availableFeaturedCars;
        _isLoading = false;
        _isCheckingAvailability = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _featuredCars = <Car>[];
        _isLoading = false;
        _isCheckingAvailability = false;
        _errorMessage = _cleanError(e);
      });
    }
  }

  // ============================================================
  // VALID TRIP
  // ============================================================

  bool get _hasValidTripDates {
    final pickup = widget.pickupDateTime;

    final returnDateTime = widget.returnDateTime;

    if (pickup == null ||
        returnDateTime == null) {
      return false;
    }

    return returnDateTime.isAfter(
      pickup,
    );
  }

  // ============================================================
  // OPEN DETAILS
  // ============================================================

  void _openCarDetails(Car car) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CarDetailsScreen(
          car: car,
          pickupDateTime: widget.pickupDateTime,
          returnDateTime: widget.returnDateTime,
          rentalType: widget.rentalType,
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    // ----------------------------------------------------------
    // LOADING
    // ----------------------------------------------------------

    if (_isLoading) {
      return _buildLoadingState();
    }

    // ----------------------------------------------------------
    // ERROR
    // ----------------------------------------------------------

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    // ----------------------------------------------------------
    // EMPTY
    // ----------------------------------------------------------

    if (_featuredCars.isEmpty) {
      if (_hasValidTripDates) {
        return _buildNoAvailableCarsState();
      }

      return const SizedBox.shrink();
    }

    // ----------------------------------------------------------
    // SECTION
    // ----------------------------------------------------------

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        10,
        0,
        0,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(),

          const SizedBox(height: 13),

          _buildCarsList(),

          const SizedBox(height: 17),
        ],
      ),
    );
  }

  // ============================================================
  // SECTION HEADER
  // ============================================================

  Widget _buildSectionHeader() {
    final availableMode =
        _hasValidTripDates;

    return Padding(
      padding: const EdgeInsets.only(
        right: 16,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      availableMode
                          ? 'Available for your trip'
                          : 'Featured cars',
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: heading,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      availableMode
                          ? '${_featuredCars.length} car${_featuredCars.length == 1 ? '' : 's'} available for your selected dates'
                          : 'Handpicked cars ready for your next drive',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: body,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // ------------------------------------------------
              // STATUS PILL
              // ------------------------------------------------

              if (_isCheckingAvailability)
                _buildCheckingPill()
              else if (availableMode)
                _buildAvailablePill(),
            ],
          ),

          // ----------------------------------------------------
          // TRIP CONTEXT
          // ----------------------------------------------------

          if (availableMode) ...[
            const SizedBox(height: 11),
            _buildTripContext(),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // CHECKING PILL
  // ============================================================

  Widget _buildCheckingPill() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: softAccent,
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.8,
              color: primary,
            ),
          ),
          SizedBox(width: 6),
          Text(
            'Checking',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: primary,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // AVAILABLE PILL
  // ============================================================

  Widget _buildAvailablePill() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFEAFBF4),
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFD4F2E4),
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF159A68),
            size: 13,
          ),
          SizedBox(width: 5),
          Text(
            'Available',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF147A54),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TRIP CONTEXT
  // ============================================================

  Widget _buildTripContext() {
    final pickup =
        widget.pickupDateTime!;

    final returnDateTime =
        widget.returnDateTime!;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF9),
        borderRadius:
            BorderRadius.circular(15),
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
                  BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.route_rounded,
              color: primary,
              size: 16,
            ),
          ),

          const SizedBox(width: 9),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'YOUR TRIP',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: muted,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_formatDate(pickup)}  •  ${_formatTime(pickup)}'
                  '   →   '
                  '${_formatDate(returnDateTime)}  •  ${_formatTime(returnDateTime)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: heading,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Icon(
                      widget.rentalType.toLowerCase() == 'hourly'
                          ? Icons.schedule_rounded
                          : Icons.calendar_month_rounded,
                      size: 11,
                      color: primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.rentalType.toLowerCase() == 'hourly'
                          ? 'Hourly rental'
                          : 'Daily rental',
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
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

  // ============================================================
  // CAR LIST
  // ============================================================

  Widget _buildCarsList() {
    return SizedBox(
      height: 335,
      child: ListView.separated(
        scrollDirection:
            Axis.horizontal,
        physics:
            const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(
          right: 16,
          bottom: 4,
        ),
        itemCount:
            _featuredCars.length,
        separatorBuilder: (
          _,
          __,
        ) {
          return const SizedBox(
            width: 14,
          );
        },
        itemBuilder: (
          context,
          index,
        ) {
          final car =
              _featuredCars[index];

          return SizedBox(
            width: 286,
            child: _buildPremiumCarItem(
              car,
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // PREMIUM CAR ITEM
  // ============================================================

  Widget _buildPremiumCarItem(
    Car car,
  ) {
    return Stack(
      children: [
        // ------------------------------------------------------
        // EXISTING CARD
        // ------------------------------------------------------

        CarCard(
          car: car,
          pickupDateTime: widget.pickupDateTime,
          returnDateTime: widget.returnDateTime,
          rentalType: widget.rentalType,
          onTap: () {
            _openCarDetails(car);
          },
        ),
      ],
    );
  }

  // ============================================================
  // LOADING
  // ============================================================

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        18,
        16,
        8,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 145,
                height: 20,
                decoration:
                    BoxDecoration(
                  color: const Color(
                    0xFFE9EFED,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    8,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                width: 55,
                height: 14,
                decoration:
                    BoxDecoration(
                  color: const Color(
                    0xFFE9EFED,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    8,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 13),

          SizedBox(
            height: 292,
            child: ListView.separated(
              scrollDirection:
                  Axis.horizontal,
              physics:
                  const NeverScrollableScrollPhysics(),
              itemCount: 2,
              separatorBuilder: (
                _,
                __,
              ) {
                return const SizedBox(
                  width: 14,
                );
              },
              itemBuilder: (
                context,
                index,
              ) {
                return Container(
                  width: 286,
                  decoration:
                      BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(
                      24,
                    ),
                    border: Border.all(
                      color: border,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        height: 175,
                        decoration:
                            const BoxDecoration(
                          color: Color(
                            0xFFEDF2F0,
                          ),
                          borderRadius:
                              BorderRadius.vertical(
                            top: Radius.circular(
                              24,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding:
                            const EdgeInsets.all(
                          15,
                        ),
                        child: Column(
                          children: [
                            Align(
                              alignment:
                                  Alignment
                                      .centerLeft,
                              child:
                                  Container(
                                width: 150,
                                height: 14,
                                decoration:
                                    BoxDecoration(
                                  color:
                                      const Color(
                                    0xFFE9EFED,
                                  ),
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    7,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(
                              height: 10,
                            ),
                            Align(
                              alignment:
                                  Alignment
                                      .centerLeft,
                              child:
                                  Container(
                                width: 100,
                                height: 11,
                                decoration:
                                    BoxDecoration(
                                  color:
                                      const Color(
                                    0xFFE9EFED,
                                  ),
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    6,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // NO AVAILABLE CARS
  // ============================================================

  Widget _buildNoAvailableCarsState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        18,
        16,
        12,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 22,
          vertical: 25,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(24),
          border: Border.all(
            color: border,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: 0.035,
              ),
              blurRadius: 20,
              offset: const Offset(
                0,
                8,
              ),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: softAccent,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.directions_car_filled_outlined,
                color: primary,
                size: 27,
              ),
            ),

            const SizedBox(height: 14),

            const Text(
              'No featured cars available',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: heading,
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              'There are no featured vehicles available for your selected dates. Try different dates or explore the full fleet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: body,
                height: 1.45,
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              height: 42,
              child: OutlinedButton.icon(
                onPressed: _loadCars,
                style:
                    OutlinedButton.styleFrom(
                  foregroundColor: primary,
                  side: const BorderSide(
                    color: Color(
                      0xFFBCE8E2,
                    ),
                  ),
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                      14,
                    ),
                  ),
                ),
                icon: const Icon(
                  Icons.refresh_rounded,
                  size: 17,
                ),
                label: const Text(
                  'Refresh',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w900,
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
  // ERROR
  // ============================================================

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        15,
        16,
        12,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(
          16,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(22),
          border: Border.all(
            color: border,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(
                  0xFFFFF3F1,
                ),
                borderRadius:
                    BorderRadius.circular(
                  13,
                ),
              ),
              child: const Icon(
                Icons
                    .directions_car_outlined,
                color: Color(
                  0xFFD05B4F,
                ),
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
                    'Cars unavailable right now',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 12.5,
                      fontWeight:
                          FontWeight.w900,
                      color: heading,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _errorMessage ??
                        'Please try again.',
                    maxLines: 2,
                    overflow:
                        TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 9.5,
                      fontWeight:
                          FontWeight.w600,
                      color: body,
                    ),
                  ),
                ],
              ),
            ),

            TextButton(
              onPressed: _loadCars,
              child: const Text(
                'Retry',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  color: primary,
                  fontSize: 10.5,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // FORMAT DATE
  // ============================================================

  String _formatDate(
    DateTime value,
  ) {
    const months = <String>[
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

    return '${value.day} ${months[value.month - 1]}';
  }

  // ============================================================
  // FORMAT TIME
  // ============================================================

  String _formatTime(
    DateTime value,
  ) {
    final hour =
        value.hour % 12 == 0
            ? 12
            : value.hour % 12;

    final minute =
        value.minute.toString().padLeft(
              2,
              '0',
            );

    final period =
        value.hour >= 12
            ? 'PM'
            : 'AM';

    return '$hour:$minute $period';
  }

  // ============================================================
  // CLEAN ERROR
  // ============================================================

  String _cleanError(
    Object error,
  ) {
    final text = error.toString();

    if (text.startsWith(
      'Exception: ',
    )) {
      return text.substring(
        'Exception: '.length,
      );
    }

    return text;
  }
}

