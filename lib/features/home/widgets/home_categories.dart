import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeCategories extends StatefulWidget {
  const HomeCategories({super.key});

  @override
  State<HomeCategories> createState() =>
      _HomeCategoriesState();
}

class _HomeCategoriesState
    extends State<HomeCategories> {
  static const Color primary = Color(0xFF0F766E);
  static const Color card = Color(0xFFFFFFFF);
  static const Color softAccent = Color(0xFFE6FFFB);
  static const Color heading = Color(0xFF17201F);
  static const Color muted = Color(0xFF94A09D);
  static const Color border = Color(0xFFE5EBE9);

  final List<_Category> _categories = const [
    _Category(
      title: 'All',
      subtitle: 'Every ride',
      icon: Icons.apps_rounded,
    ),
    _Category(
      title: 'SUV',
      subtitle: 'Spacious',
      icon: Icons.directions_car_filled_rounded,
    ),
    _Category(
      title: 'Sedan',
      subtitle: 'Comfort',
      icon: Icons.directions_car_rounded,
    ),
    _Category(
      title: 'Hatchback',
      subtitle: 'Compact',
      icon: Icons.car_rental_rounded,
    ),
    _Category(
      title: 'Luxury',
      subtitle: 'Premium',
      icon: Icons.auto_awesome_rounded,
    ),
  ];

  String _selectedCategory = 'All';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        _buildCategoryList(),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        4,
        20,
        13,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Browse by type',
                  style: GoogleFonts.manrope(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: heading,
                    letterSpacing: -0.5,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  'Choose the ride that fits your journey.',
                  style: GoogleFonts.manrope(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: muted,
                  ),
                ),
              ],
            ),
          ),

          GestureDetector(
            onTap: () {
              // Explore screen will be connected later.
            },
            child: Row(
              children: [
                Text(
                  'View all',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: primary,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 17,
                  color: primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryList() {
    return SizedBox(
      height: 119,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
        ),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _categories.length,
        separatorBuilder: (_, __) =>
            const SizedBox(width: 11),
        itemBuilder: (context, index) {
          return _buildCategoryCard(
            _categories[index],
            index,
          );
        },
      ),
    );
  }

  Widget _buildCategoryCard(
    _Category category,
    int index,
  ) {
    final bool selected =
        _selectedCategory == category.title;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = category.title;
        });
      },
      child: AnimatedScale(
        scale: selected ? 1.0 : 0.96,
        duration: const Duration(
          milliseconds: 220,
        ),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(
            milliseconds: 260,
          ),
          curve: Curves.easeOutCubic,
          width: 92,
          padding: const EdgeInsets.fromLTRB(
            8,
            9,
            8,
            9,
          ),
          decoration: BoxDecoration(
            color: selected ? primary : card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? primary
                  : border,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: primary.withOpacity(0.17),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.018),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(
                  milliseconds: 260,
                ),
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withOpacity(0.14)
                      : softAccent,
                  shape: BoxShape.circle,
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(
                    milliseconds: 180,
                  ),
                  transitionBuilder:
                      (child, animation) {
                    return ScaleTransition(
                      scale: animation,
                      child: child,
                    );
                  },
                  child: Icon(
                    category.icon,
                    key: ValueKey(
                      '${category.title}_$selected',
                    ),
                    size: 20,
                    color: selected
                        ? Colors.white
                        : primary,
                  ),
                ),
              ),

              const SizedBox(height: 7),

              Text(
                category.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: selected
                      ? Colors.white
                      : heading,
                ),
              ),

              const SizedBox(height: 1),

              Text(
                category.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 7.8,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? Colors.white.withOpacity(0.68)
                      : muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Category {
  final String title;
  final String subtitle;
  final IconData icon;

  const _Category({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}