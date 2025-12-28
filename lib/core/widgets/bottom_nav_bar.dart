import 'dart:ui';
import 'package:flutter/material.dart';

/// Modern full-width glass bottom nav bar – white circle on selected (dark mode)
/// Icons updated to: Home → Reels → Story → Long Videos → Notifications
class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      bottom: false,
      top: false,
      child: Container(
        height: 78,
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.symmetric(vertical: 0),
        child: ClipRRect(
          borderRadius: BorderRadius.zero,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: List.generate(5, (index) => _buildNavItem(context, index)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = currentIndex == index;

    // Updated icons to match your desired "new" design
    final icons = [
      Icons.home_outlined,          // 0: Home
      Icons.movie_outlined,         // 1: Reels
      Icons.access_time_outlined,   // 2: Story
      Icons.play_circle_outline,    // 3: Long Videos
      Icons.notifications_outlined, // 4: Notifications
    ];

    final selectedIcons = [
      Icons.home_rounded,
      Icons.movie_rounded,
      Icons.access_time_rounded,
      Icons.play_circle_rounded,
      Icons.notifications_rounded,
    ];

    final icon = isSelected ? selectedIcons[index] : icons[index];

    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        width: 56,
        height: 56,
        decoration: isSelected
            ? BoxDecoration(
          color: isDark ? Colors.white : Colors.black,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: (isDark ? Colors.black : Colors.white).withOpacity(0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        )
            : null,
        child: Center(
          child: Icon(
            icon,
            color: isSelected
                ? (isDark ? Colors.black : Colors.white)
                : (isDark
                ? Colors.white.withOpacity(0.70)
                : Colors.black.withOpacity(0.60)),
            size: isSelected ? 28 : 26,
          ),
        ),
      ),
    );
  }
}