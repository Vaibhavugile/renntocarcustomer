import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeHero extends StatefulWidget {
  const HomeHero({super.key});

  @override
  State<HomeHero> createState() => _HomeHeroState();
}

class _HomeHeroState extends State<HomeHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const Color primary = Color(0xFF0F766E);
  static const Color heading = Color(0xFF17201F);

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 1200,
      ),
    );

    Future.delayed(
      const Duration(milliseconds: 150),
      () {
        if (mounted) {
          _controller.forward();
        }
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        8,
        20,
        8,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: SizedBox(
          height: 235,
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.network(
                  'https://images.unsplash.com/photo-1503376780353-7e6692767b70?auto=format&fit=crop&w=1400&q=90',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) {
                    return Container(
                      color: heading,
                    );
                  },
                ),
              ),

              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.black.withOpacity(0.78),
                        Colors.black.withOpacity(0.34),
                        Colors.transparent,
                      ],
                      stops: const [
                        0,
                        0.58,
                        1,
                      ],
                    ),
                  ),
                ),
              ),

              Positioned(
                top: 20,
                left: 20,
                child: _buildBadge(),
              ),

              Positioned(
                left: 20,
                right: 20,
                bottom: 20,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final value =
                        Curves.easeOutCubic.transform(
                      _controller.value,
                    );

                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(
                          -25 * (1 - value),
                          0,
                        ),
                        child: child,
                      ),
                    );
                  },
                  child: _buildHeroContent(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.13),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white.withOpacity(0.16),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF14B8A6),
              shape: BoxShape.circle,
            ),
          ),

          const SizedBox(width: 7),

          Text(
            'PREMIUM MOBILITY',
            style: GoogleFonts.manrope(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroContent() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          'Find your\nperfect drive.',
          style: GoogleFonts.manrope(
            fontSize: 29,
            height: 1.05,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.2,
            color: Colors.white,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          'Premium cars. Simple booking.',
          style: GoogleFonts.manrope(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: Colors.white.withOpacity(0.78),
          ),
        ),

        const SizedBox(height: 15),

        _buildExploreButton(),
      ],
    );
  }

  Widget _buildExploreButton() {
    return Material(
      color: primary,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 11,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Explore cars',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),

              const SizedBox(width: 8),

              const Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}