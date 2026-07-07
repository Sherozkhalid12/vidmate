import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/notifications_provider_riverpod.dart';
import '../providers/main_tab_index_provider.dart';

/// Glass bottom nav: Reels → Long Videos → Story → Notifications → Music
class BottomNavBar extends ConsumerWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                children: List.generate(5, (index) => _buildNavItem(context, ref, index)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, WidgetRef ref, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = currentIndex == index;
    final unreadCount = ref.watch(
      notificationsProvider.select((s) => s.unreadCount),
    );

    final icons = [
      Icons.home_outlined,          // 0: Reels (home)
      Icons.play_circle_outline,    // 1: Long Videos
      Icons.access_time_outlined,   // 2: Story
      Icons.notifications_outlined, // 3: Notifications
      Icons.music_note_outlined,    // 4: Music
    ];

    final selectedIcons = [
      Icons.home_rounded,
      Icons.play_circle_rounded,
      Icons.access_time_rounded,
      Icons.notifications_rounded,
      Icons.music_note,
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
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                icon,
                color: isSelected
                    ? (isDark ? Colors.black : Colors.white)
                    : (isDark
                        ? Colors.white.withOpacity(0.70)
                        : Colors.black.withOpacity(0.60)),
                size: isSelected ? 28 : 26,
              ),
              if (index == kNotificationsTabIndex &&
                  currentIndex != kNotificationsTabIndex &&
                  unreadCount > 0)
                Positioned(
                  top: -5,
                  right: -8,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? Colors.black : Colors.white,
                        width: 1.2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
