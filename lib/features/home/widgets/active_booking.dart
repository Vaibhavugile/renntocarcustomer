import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ActiveBooking extends StatelessWidget {
  const ActiveBooking({super.key});

  static const bool hasActiveBooking = false;

  @override
  Widget build(BuildContext context) {
    if (!hasActiveBooking) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        8,
        20,
        20,
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFE6FFFB),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: const Color(0xFFB9EEE7),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 35,
                  height: 35,
                  decoration: const BoxDecoration(
                    color: Color(0xFF0F766E),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.directions_car_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'YOUR ACTIVE BOOKING',
                        style: GoogleFonts.manrope(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                          color: const Color(0xFF0F766E),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Hyundai Creta',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF17201F),
                        ),
                      ),
                    ],
                  ),
                ),

                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF0F766E),
                ),
              ],
            ),

            const SizedBox(height: 15),

            Row(
              children: [
                Expanded(
                  child: _Info(
                    icon: Icons.calendar_today_outlined,
                    title: 'Today',
                    value: '10:00 AM',
                  ),
                ),
                Expanded(
                  child: _Info(
                    icon: Icons.location_on_outlined,
                    title: 'Pickup',
                    value: 'Wakad',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _Info({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 15,
          color: const Color(0xFF0F766E),
        ),
        const SizedBox(width: 7),
        Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.manrope(
                fontSize: 8.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF94A09D),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: GoogleFonts.manrope(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF17201F),
              ),
            ),
          ],
        ),
      ],
    );
  }
}