import 'package:flutter/material.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/widgets/bottom_nav_bar.dart';
import '../home/home_feed_page.dart';
import '../reels/reels_page.dart';
import '../stories/story_page.dart';
import '../long_videos/long_videos_page.dart';
import '../notifications/notifications_page.dart';
/// Root screen with persistent glassmorphic bottom navigation
/// Uses Stack architecture: PageView for content, BottomNavBar as overlay
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
  
  // Static reference to access MainScreen state from anywhere
  static _MainScreenState? _instance;
  
  static _MainScreenState? get instance => _instance;
}

class _MainScreenState extends State<MainScreen> {
  late PageController _pageController;
  int _currentIndex = 0;
  
  @override
  void initState() {
    super.initState();
    // Set the static instance reference
    MainScreen._instance = this;
    _pageController = PageController(initialPage: 0);
  }
  
  @override
  void dispose() {
    // Clear the static instance when disposed
    if (MainScreen._instance == this) {
      MainScreen._instance = null;
    }
    _pageController.dispose();
    super.dispose();
  }


  void _onNavItemTapped(int index) {
    if (_currentIndex != index) {
      // Update index immediately to prevent blinking
      setState(() {
        _currentIndex = index;
      });
      // Use jumpToPage for instant switching without animating through intermediate pages
      if (_pageController.hasClients) {
        _pageController.jumpToPage(index);
      }
    }
  }

  void _onPageChanged(int index) {
    // Only update if different to prevent unnecessary rebuilds
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  // Method to navigate to a specific index (can be called from anywhere)
  void navigateToIndex(int index) {
    if (_currentIndex != index) {
      // Update index immediately
      setState(() {
        _currentIndex = index;
      });
      // Use jumpToPage for instant switching
      if (_pageController.hasClients) {
        _pageController.jumpToPage(index);
      }
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
              child: PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(), // Disable swipe, only tap nav
                onPageChanged: _onPageChanged,
                itemCount: 5,
                itemBuilder: (context, index) {
                  return _buildPage(index, totalBottomPadding);
                },
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
      case 4: // Notifications
        return NotificationsPage(bottomPadding: bottomPadding);
      default:
        return const SizedBox.shrink();
    }
  }
}


