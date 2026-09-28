
import 'package:flutter/material.dart';

import '../../cars/models/car.dart';
import '../../cars/screens/car_details_screen.dart';

class CarCard extends StatefulWidget {
  final Car car;
  final VoidCallback? onTap;

  /// Selected customer pickup date/time.
  final DateTime? pickupDateTime;

  /// Selected customer return date/time.
  final DateTime? returnDateTime;

  /// daily / hourly
  final String rentalType;

  const CarCard({
    super.key,
    required this.car,
    this.onTap,
    this.pickupDateTime,
    this.returnDateTime,
    this.rentalType = 'daily',
  });

  @override
  State<CarCard> createState() => _CarCardState();
}

class _CarCardState extends State<CarCard> {
  // ============================================================
  // PREMIUM PALETTE
  // ============================================================

  static const Color background = Color(0xFFF7FAF9);
  static const Color surface = Colors.white;

  static const Color primary = Color(0xFF0F766E);
  static const Color primaryLight = Color(0xFF14B8A6);

  static const Color heading = Color(0xFF17201F);
  static const Color body = Color(0xFF687370);
  static const Color muted = Color(0xFF98A3A0);
  static const Color border = Color(0xFFE4EBE8);

  // ============================================================
  // STATE
  // ============================================================

  bool _isFavorite = false;
  bool _pressed = false;

  // ============================================================
  // GETTERS
  // ============================================================

  Car get car => widget.car;

  bool get _hasTripDates =>
      widget.pickupDateTime != null &&
      widget.returnDateTime != null;

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.985 : 1,
      duration: const Duration(
        milliseconds: 130,
      ),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(
            25,
          ),
          onTap: _handleTap,
          onHighlightChanged: (value) {
            if (mounted) {
              setState(() {
                _pressed = value;
              });
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(
                25,
              ),
              border: Border.all(
                color: border,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: 0.055,
                  ),
                  blurRadius: 25,
                  offset: const Offset(
                    0,
                    11,
                  ),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                _buildImageSection(),

                _buildInformationSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // IMAGE
  // ============================================================

  Widget _buildImageSection() {
    return SizedBox(
      height: 158,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildCarImage(),

          // ------------------------------------------------------
          // IMAGE GRADIENT
          // ------------------------------------------------------

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 64,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(
                        alpha: 0.42,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ------------------------------------------------------
          // TOP BADGES
          // ------------------------------------------------------

          Positioned(
            top: 10,
            left: 10,
            child: _buildTypeBadge(),
          ),

          Positioned(
            top: 10,
            right: 10,
            child: _buildFavoriteButton(),
          ),

          // ------------------------------------------------------
          // BOTTOM AVAILABILITY
          // ------------------------------------------------------

          Positioned(
            left: 11,
            bottom: 10,
            child: _buildAvailabilityBadge(),
          ),

        ],
      ),
    );
  }

  // ============================================================
  // IMAGE
  // ============================================================

  Widget _buildCarImage() {
    final imageUrl = car.image.trim();

    if (imageUrl.trim().isEmpty) {
      return Container(
        color: const Color(
          0xFFF0F4F2,
        ),
        child: const Center(
          child: Icon(
            Icons.directions_car_rounded,
            color: Color(
              0xFFB4BFBC,
            ),
            size: 48,
          ),
        ),
      );
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      errorBuilder: (
        context,
        error,
        stackTrace,
      ) {
        return Container(
          color: const Color(
            0xFFF0F4F2,
          ),
          child: const Center(
            child: Icon(
              Icons.directions_car_rounded,
              color: Color(
                0xFFB4BFBC,
              ),
              size: 48,
            ),
          ),
        );
      },
      loadingBuilder: (
        context,
        child,
        loadingProgress,
      ) {
        if (loadingProgress == null) {
          return child;
        }

        return Container(
          color: const Color(
            0xFFF0F4F2,
          ),
          child: const Center(
            child: SizedBox(
              width: 23,
              height: 23,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: primary,
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // TYPE BADGE
  // ============================================================

  Widget _buildTypeBadge() {
    final type = car.type.trim();

    if (type.isEmpty) {
      return const SizedBox.shrink();
    }

    return _glassBadge(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.directions_car_rounded,
            color: heading,
            size: 12,
          ),
          const SizedBox(width: 5),
          Text(
            type,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: heading,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FAVORITE
  // ============================================================

  Widget _buildFavoriteButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          setState(() {
            _isFavorite = !_isFavorite;
          });
        },
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withValues(
              alpha: 0.94,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: 0.09,
                ),
                blurRadius: 12,
                offset: const Offset(
                  0,
                  4,
                ),
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(
              milliseconds: 170,
            ),
            child: Icon(
              _isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              key: ValueKey(
                _isFavorite,
              ),
              size: 18,
              color: _isFavorite
                  ? const Color(
                      0xFFE25555,
                    )
                  : heading,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // AVAILABILITY
  // ============================================================

  Widget _buildAvailabilityBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(
          alpha: 0.95,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF27B978),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _hasTripDates
                ? 'Available for your dates'
                : 'Available now',
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 8.5,
              fontWeight: FontWeight.w900,
              color: heading,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INFORMATION
  // ============================================================

  Widget _buildInformationSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        14,
        11,
        14,
        11,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          // ------------------------------------------------------
          // NAME + PRICE
          // ------------------------------------------------------

          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildCarName(),
              ),

              const SizedBox(width: 10),

              _buildPrice(),
            ],
          ),

          const SizedBox(height: 8),

          // ------------------------------------------------------
          // SPECS
          // ------------------------------------------------------

          _buildSpecs(),

          const SizedBox(height: 8),

          // ------------------------------------------------------
          // CTA
          // ------------------------------------------------------

          _buildDetailsButton(),
        ],
      ),
    );
  }

  // ============================================================
  // NAME
  // ============================================================

  Widget _buildCarName() {
    final name = car.name.trim();

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          name.isEmpty
              ? 'Premium Car'
              : name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: heading,
            height: 1.1,
          ),
        ),

        if (car.registrationNumber
            .trim()
            .isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            car.registrationNumber,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              color: muted,
              letterSpacing: 0.25,
            ),
          ),
        ],
      ],
    );
  }

  // ============================================================
  // PRICE
  // ============================================================

  Widget _buildPrice() {
    final price = car.pricePerDay;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.end,
      children: [
        Text(
          '₹${_formatPrice(price)}',
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: primary,
            height: 1,
          ),
        ),

        const SizedBox(height: 4),

        Text(
          widget.rentalType == 'hourly'
              ? '/ hour'
              : '/ day',
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 8,
            fontWeight: FontWeight.w700,
            color: muted,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SPECS
  // ============================================================

  Widget _buildSpecs() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(
          14,
        ),
        border: Border.all(
          color: border,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSpec(
              icon: Icons.settings_rounded,
              value: car.transmission,
              label: 'Transmission',
            ),
          ),

          _buildSpecDivider(),

          Expanded(
            child: _buildSpec(
              icon: Icons.local_gas_station_rounded,
              value: car.fuel,
              label: 'Fuel',
            ),
          ),

          _buildSpecDivider(),

          Expanded(
            child: _buildSpec(
              icon: Icons.event_seat_rounded,
              value: '${car.seats}',
              label: 'Seats',
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SPEC
  // ============================================================

  Widget _buildSpec({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: primary,
          size: 13,
        ),

        const SizedBox(height: 2),

        Text(
          value.isEmpty ? '-' : value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 8.5,
            fontWeight: FontWeight.w900,
            color: heading,
            height: 1,
          ),
        ),

        const SizedBox(height: 1),

        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 6.5,
            fontWeight: FontWeight.w600,
            color: muted,
            height: 1,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // DIVIDER
  // ============================================================

  Widget _buildSpecDivider() {
    return Container(
      width: 1,
      height: 29,
      color: border,
    );
  }

  // ============================================================
  // DETAILS BUTTON
  // ============================================================

  Widget _buildDetailsButton() {
    return SizedBox(
      width: double.infinity,
      height: 38,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(
            13,
          ),
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              primaryLight,
              primary,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: primary.withValues(
                alpha: 0.16,
              ),
              blurRadius: 12,
              offset: const Offset(
                0,
                5,
              ),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius:
                BorderRadius.circular(
              13,
            ),
            onTap: _handleTap,
            child: const Row(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                Text(
                  'View car details',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 7),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 15,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // GLASS BADGE
  // ============================================================

  Widget _glassBadge({
    required Widget child,
  }) {
    return Container(
      constraints: const BoxConstraints(
        maxWidth: 145,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(
          alpha: 0.94,
        ),
        borderRadius: BorderRadius.circular(
          18,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.08,
            ),
            blurRadius: 10,
            offset: const Offset(
              0,
              4,
            ),
          ),
        ],
      ),
      child: child,
    );
  }

  // ============================================================
  // TAP
  // ============================================================

  void _handleTap() {
    if (widget.onTap != null) {
      widget.onTap!();
      return;
    }

    Navigator.of(
      context,
    ).push(
      MaterialPageRoute(
        builder: (_) {
          return CarDetailsScreen(
            car: car,
            pickupDateTime: widget.pickupDateTime,
            returnDateTime: widget.returnDateTime,
            rentalType: widget.rentalType,
          );
        },
      ),
    );
  }

  // ============================================================
  // PRICE FORMAT
  // ============================================================

  String _formatPrice(
    num value,
  ) {
    final number = value.toDouble();

    if (number == number.roundToDouble()) {
      return number.toInt().toString();
    }

    return number.toStringAsFixed(0);
  }
}

