import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WhyChooseUs extends StatelessWidget {
  const WhyChooseUs({super.key});

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
        30,
        20,
        0,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            'A better way to move',
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: heading,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            'Everything you need for a smoother rental.',
            style: GoogleFonts.manrope(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: muted,
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _Feature(
                  icon: Icons.verified_outlined,
                  title: 'Verified cars',
                  subtitle: 'Quality checked',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Feature(
                  icon: Icons.bolt_rounded,
                  title: 'Easy booking',
                  subtitle: 'Simple & fast',
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _Feature(
                  icon: Icons.payments_outlined,
                  title: 'Clear pricing',
                  subtitle: 'No surprises',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Feature(
                  icon: Icons.support_agent_rounded,
                  title: 'Always here',
                  subtitle: 'Dedicated support',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _Feature({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE5EBE9),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFE6FFFB),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              size: 18,
              color: const Color(0xFF0F766E),
            ),
          ),

          const SizedBox(width: 9),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF17201F),
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF94A09D),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}