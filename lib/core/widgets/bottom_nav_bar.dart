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

    // Icons and labels – matched to image: Home, Reels, Story, Long Videos, Notifications
    final icons = [
      Icons.home_outlined,          // Index 0: Home
      Icons.movie_outlined,         // Index 1: Reels
      Icons.access_time_outlined,   // Index 2: Story
      Icons.play_circle_outline,    // Index 3: Long Videos
      Icons.notifications_outlined, // Index 4: Notifications
    ];

    final selectedIcons = [
      Icons.home_rounded,
      Icons.movie_rounded,
      Icons.access_time_rounded,
      Icons.play_circle_rounded,
      Icons.notifications_rounded,
    ];

    final labels = [
      'Home',
      'Reels',
      'Story',
      'Long Videos',
      'Notifications',
    ];

    final icon = isSelected ? selectedIcons[index] : icons[index];

    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            width: 40,
            height: 40,
            decoration: isSelected
                ? BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  )
                : null,
            child: Center(
              child: Icon(
                icon,
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimary
                    : (isDark 
                        ? Colors.white.withOpacity(0.70) 
                        : Colors.black.withOpacity(0.60)),
                size: 24,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            labels[index],
            style: TextStyle(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : (isDark 
                      ? Colors.white.withOpacity(0.70) 
                      : Colors.black.withOpacity(0.60)),
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}