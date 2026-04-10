import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/widgets/bottom_nav_bar.dart';
import '../../core/providers/auth_provider_riverpod.dart';
import '../../core/providers/posts_provider_riverpod.dart';
import '../../core/providers/reels_provider_riverpod.dart';
import '../../core/providers/notifications_provider_riverpod.dart';
import '../../core/providers/stories_provider_riverpod.dart';
import '../../core/providers/main_tab_index_provider.dart';
import '../long_videos/providers/long_videos_provider.dart';
import '../home/home_feed_page.dart';
import '../reels/reels_page.dart';
import '../stories/story_page.dart';
import '../long_videos/long_videos_page.dart';
import '../music/music_page.dart';
/// Root screen with persistent glassmorphic bottom navigation
/// Uses Stack architecture: IndexedStack keeps tab state, BottomNavBar as overlay
class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();

  // Static reference to access MainScreen state from anywhere
  static _MainScreenState? _instance;
  static _MainScreenState? get instance => _instance;
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _currentIndex = 0;
  
  @override
  void initState() {
    super.initState();
    // Set the static instance reference
    MainScreen._instance = this;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!ref.read(isAuthenticatedProvider)) return;
      unawaited(ref.read(postsProvider.notifier).loadPosts(forceRefresh: false));
      Future.microtask(() {
        if (!mounted) return;
        if (!ref.read(isAuthenticatedProvider)) return;
        unawaited(ref.read(reelsProvider.notifier).loadReels());
        unawaited(ref.read(storiesProvider.notifier).loadStories());
      });
    });

    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      if (!ref.read(isAuthenticatedProvider)) return;
      unawaited(ref.read(notificationsProvider.notifier).loadNotifications());
      unawaited(ref.read(longVideosProvider.notifier).loadVideos());
    });
  }
  
  @override
  void dispose() {
    // Clear the static instance when disposed
    if (MainScreen._instance == this) {
      MainScreen._instance = null;
    }
    super.dispose();
  }


  void _onNavItemTapped(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
      _onTabSelected(index);
    }
  }

  void _onTabSelected(int index) {
    ref.read(mainTabIndexProvider.notifier).state = index;
    // Stories tab: SWR background refresh (Hive tray stays visible).
    if (index == 2) {
      unawaited(ref.read(storiesProvider.notifier).loadStories());
    }
  }

  // Method to navigate to a specific index (can be called from anywhere)
  void navigateToIndex(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
      _onTabSelected(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate bottom nav bar height for content padding
    final bottomNavHeight = 78.0;
    final safeAreaBottom = MediaQuery.of(context).padding.bottom;
    final totalBottomPadding = bottomNavHeight + safeAreaBottom;

    // Get theme-aware gradient background
    final gradient = ThemeHelper.getBackgroundGradient(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: Container(
        // Apply gradient background at root level - fills entire screen
        decoration: BoxDecoration(
          gradient: gradient,
        ),
        child: Stack(
          children: [
            // Main content layer - scrollable pages
            Padding(
              padding: const EdgeInsets.only(bottom: 72.0),
              child: IndexedStack(
                index: _currentIndex,
                sizing: StackFit.expand,
                children: List.generate(
                  5,
                  (i) => _buildPage(i, totalBottomPadding),
                ),
              ),
            ),

            // Persistent bottom navigation bar overlay
            // Positioned at bottom so glass blur reveals scrolling gradient/content
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: BottomNavBar(
                currentIndex: _currentIndex,
                onTap: _onNavItemTapped,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(int index, double bottomPadding) {
    switch (index) {
      case 0: // Home
        return HomeFeedPage(bottomPadding: bottomPadding);
      case 1: // Reels
        return ReelsPage(bottomPadding: bottomPadding);
      case 2: // Story
        return StoryPage(bottomPadding: bottomPadding);
      case 3: // Long Videos
        return LongVideosPage(bottomPadding: bottomPadding);
      case 4: // Music
        return MusicPage(bottomPadding: bottomPadding);
      default:
        return const SizedBox.shrink();
    }
  }
}


