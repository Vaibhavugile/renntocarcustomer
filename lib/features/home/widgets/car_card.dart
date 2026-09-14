import 'package:flutter/material.dart';

import '../../cars/models/car.dart';

class CarCard extends StatefulWidget {
  final Car car;
  final VoidCallback? onTap;

  const CarCard({
    super.key,
    required this.car,
    this.onTap,
  });

  @override
  State<CarCard> createState() => _CarCardState();
}

class _CarCardState extends State<CarCard> {
  bool _isFavorite = false;

  static const Color primary = Color(0xFF0F766E);
  static const Color accent = Color(0xFF14B8A6);
  static const Color heading = Color(0xFF17201F);
  static const Color body = Color(0xFF66706E);
  static const Color border = Color(0xFFE5EBE9);

  @override
  Widget build(BuildContext context) {
    final car = widget.car;

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: border,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A17201F),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImage(car),

            Padding(
              padding: const EdgeInsets.fromLTRB(
                16,
                13,
                16,
                15,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          car.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: heading,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildTypeBadge(car.type),
                    ],
                  ),

                  const SizedBox(height: 10),

                  Row(
                    children: [
                      _spec(
                        Icons.settings_outlined,
                        car.transmission,
                      ),
                      const SizedBox(width: 12),
                      _spec(
                        Icons.event_seat_outlined,
                        '${car.seats} Seats',
                      ),
                      const SizedBox(width: 12),
                      _spec(
                        Icons.local_gas_station_outlined,
                        car.fuel,
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  Row(
                    children: [
                      RichText(
                        text: TextSpan(
                          children: [
                            const TextSpan(
                              text: '₹',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: primary,
                              ),
                            ),
                            TextSpan(
                              text: '${car.pricePerDay}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: heading,
                              ),
                            ),
                            const TextSpan(
                              text: ' / day',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: body,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Spacer(),

                      AnimatedContainer(
                        duration:
                            const Duration(milliseconds: 180),
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: primary,
                          borderRadius:
                              BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(Car car) {
    return SizedBox(
      height: 148,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
            child: Image.network(
              car.image,
              width: double.infinity,
              height: 148,
              fit: BoxFit.cover,
              errorBuilder: (
                context,
                error,
                stackTrace,
              ) {
                return Container(
                  color: const Color(0xFFF1F5F4),
                  child: const Center(
                    child: Icon(
                      Icons.directions_car_outlined,
                      size: 48,
                      color: Color(0xFF94A09D),
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
                  color: const Color(0xFFF1F5F4),
                  child: const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: primary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Availability
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(
                  alpha: 0.92,
                ),
                borderRadius:
                    BorderRadius.circular(10),
              ),
              child: Text(
                car.isAvailable
                    ? 'AVAILABLE'
                    : 'UNAVAILABLE',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: car.isAvailable
                      ? primary
                      : Colors.redAccent,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),

          // Favourite
          Positioned(
            top: 10,
            right: 10,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isFavorite = !_isFavorite;
                });
              },
              child: AnimatedContainer(
                duration:
                    const Duration(milliseconds: 180),
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(
                    alpha: 0.94,
                  ),
                  shape: BoxShape.circle,
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(
                    milliseconds: 180,
                  ),
                  child: Icon(
                    _isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    key: ValueKey(_isFavorite),
                    size: 19,
                    color: _isFavorite
                        ? Colors.redAccent
                        : heading,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeBadge(String type) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFE6FFFB),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        type.toUpperCase(),
        style: const TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w900,
          color: primary,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _spec(
    IconData icon,
    String text,
  ) {
    return Flexible(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: accent,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: body,
              ),
            ),
          ),
        ],
      ),
    );
  }
}