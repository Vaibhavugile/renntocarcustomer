import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeSearch extends StatelessWidget {
  const HomeSearch({super.key});

  static const Color primary = Color(0xFF0F766E);
  static const Color card = Color(0xFFFFFFFF);
  static const Color softAccent = Color(0xFFE6FFFB);
  static const Color heading = Color(0xFF17201F);
  static const Color body = Color(0xFF66706E);
  static const Color muted = Color(0xFF94A09D);
  static const Color border = Color(0xFFE5EBE9);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        14,
        20,
        22,
      ),
      child: Material(
        color: card,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () {
            // Explore screen will be connected here later.
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: border,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.025),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                _buildSearchIcon(),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Find your next car',
                        style: GoogleFonts.manrope(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: heading,
                        ),
                      ),

                      const SizedBox(height: 3),

                      Text(
                        'Search by car, type or preference',
                        style: GoogleFonts.manrope(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ),

                _buildArrow(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchIcon() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: softAccent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(
        Icons.search_rounded,
        color: primary,
        size: 21,
      ),
    );
  }

  Widget _buildArrow() {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: softAccent,
        borderRadius: BorderRadius.circular(11),
      ),
      child: const Icon(
        Icons.arrow_forward_rounded,
        color: primary,
        size: 16,
      ),
    );
  }
}