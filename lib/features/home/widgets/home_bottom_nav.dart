import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  /// Optional badge count for the Bookings tab.
  /// Pass null or 0 when no badge is needed.
  final int? bookingCount;

  const HomeBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
    this.bookingCount,
  });

  // ============================================================
  // FIXED PREMIUM PALETTE
  // ============================================================

  static const Color card = Color(0xFFFFFFFF);
  static const Color primary = Color(0xFF0F766E);
  static const Color softAccent = Color(0xFFE6FFFB);
  static const Color heading = Color(0xFF17201F);
  static const Color muted = Color(0xFF94A09D);
  static const Color border = Color(0xFFE5EBE9);

  static const List<_NavItemData> _items = [
    _NavItemData(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
    ),
    _NavItemData(
      icon: Icons.directions_car_outlined,
      activeIcon: Icons.directions_car_rounded,
      label: 'Explore',
    ),
    _NavItemData(
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long_rounded,
      label: 'Bookings',
    ),
    _NavItemData(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final safeIndex =
        selectedIndex >= 0 && selectedIndex < _items.length
            ? selectedIndex
            : 0;

    final hasBookingBadge =
        bookingCount != null && bookingCount! > 0;

    return Container(
      decoration: BoxDecoration(
        color: card,
        border: const Border(
          top: BorderSide(
            color: border,
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: heading.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
          child: Row(
            children: List.generate(
              _items.length,
              (index) {
                final item = _items[index];

                return Expanded(
                  child: _buildItem(
                    context: context,
                    index: index,
                    item: item,
                    selected: safeIndex == index,
                    showBadge:
                        index == 2 && hasBookingBadge,
                    badgeCount:
                        index == 2 ? bookingCount : null,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItem({
    required BuildContext context,
    required int index,
    required _NavItemData item,
    required bool selected,
    required bool showBadge,
    required int? badgeCount,
  }) {
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: Tooltip(
        message: item.label,
        child: InkWell(
          onTap: () {
            if (!selected) {
              onChanged(index);
            }
          },
          borderRadius: BorderRadius.circular(18),
          splashColor: softAccent,
          highlightColor: softAccent.withValues(alpha: 0.35),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 3,
              vertical: 2,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(vertical: 5),
              decoration: BoxDecoration(
                color: selected
                    ? softAccent.withValues(alpha: 0.72)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 34,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          width: selected ? 44 : 40,
                          height: 32,
                          decoration: BoxDecoration(
                            color: selected
                                ? softAccent
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 160),
                            switchInCurve: Curves.easeOutBack,
                            switchOutCurve: Curves.easeIn,
                            child: Icon(
                              selected ? item.activeIcon : item.icon,
                              key: ValueKey(
                                '${item.label}-$selected',
                              ),
                              size: selected ? 21 : 20,
                              color: selected ? primary : muted,
                            ),
                          ),
                        ),
                        if (showBadge)
                          Positioned(
                            right: 7,
                            top: -2,
                            child: _buildBadge(badgeCount!),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    style: GoogleFonts.manrope(
                      fontSize: selected ? 10.2 : 10,
                      fontWeight: selected
                          ? FontWeight.w800
                          : FontWeight.w600,
                      color: selected ? heading : muted,
                      height: 1.1,
                    ),
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(int count) {
    final text = count > 99 ? '99+' : '$count';

    return Container(
      constraints: const BoxConstraints(
        minWidth: 16,
        minHeight: 16,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 4.5,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: primary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: card,
          width: 1.5,
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.manrope(
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          height: 1,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItemData({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
