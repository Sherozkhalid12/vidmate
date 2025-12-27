import 'dart:ui';
import 'package:flutter/material.dart';

/// Modern full-width glass bottom nav bar – no border, white circle on selected (dark mode)
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
      bottom: false, // Respect bottom safe area (home indicator)
      top: false,   // Don't add top padding
      child: Container(
        height: 78, // expanded height like modern designs
        margin: EdgeInsets.zero, // no side margins → full width
        padding: const EdgeInsets.symmetric(vertical: 0),
        child: ClipRRect(
          borderRadius: BorderRadius.zero, // no rounding on sides for full-width feel
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24), // strong glass blur
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withOpacity(0.22)   // semi-transparent dark glass
                    : Colors.white.withOpacity(0.28),  // light mode variant
                // NO border → exactly as in image
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, -4), // subtle lift from bottom
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: List.generate(5, (index) {
                  return _buildNavItem(context, index);
                }),
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

    // Icons – matched to page order: Home, Explore, Create, Reels, Profile
    final icons = [
      Icons.home_outlined,          // Index 0: Home Feed
      Icons.explore_outlined,       // Index 1: Explore / Discover
      Icons.add_circle_outline,     // Index 2: Create / Upload
      Icons.play_circle_outline,    // Index 3: Reels / Videos
      Icons.person_outline,         // Index 4: Profile
    ];

    final selectedIcons = [
      Icons.home_rounded,
      Icons.explore_rounded,
      Icons.add_circle_rounded,
      Icons.play_circle_rounded,
      Icons.person_rounded,
    ];

    final icon = isSelected ? selectedIcons[index] : icons[index];

    // White circle only on selected item
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
                color: isDark ? Colors.white : Colors.black, // white circle in dark mode, black in light mode
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
                ? (isDark ? Colors.black : Colors.white) // black icon in white circle (dark), white in black circle (light)
                : (isDark 
                    ? Colors.white.withOpacity(0.70) 
                    : Colors.black.withOpacity(0.60)), // inactive subtle color
            size: isSelected ? 28 : 26,
          ),
        ),
      ),
    );
  }
}