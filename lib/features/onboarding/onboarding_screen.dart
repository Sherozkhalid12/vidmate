import 'package:flutter/material.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/utils/theme_helper.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_button.dart';
import '../auth/login_screen.dart';

/// Onboarding screen with multiple pages
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  List<OnboardingPage> _getPages(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final secondary = Theme.of(context).colorScheme.secondary;
    return [
      OnboardingPage(
        icon: Icons.play_circle_filled,
        title: 'Watch Unlimited',
        description: 'Stream long-form videos, binge-watch reels, and discover content from creators around the globe.',
        gradient: ThemeHelper.getAccentGradient(context), // Theme-aware accent gradient
      ),
      OnboardingPage(
        icon: Icons.camera_alt,
        title: 'Create & Share',
        description: 'Record videos, upload photos, share stories, and express yourself with creative content.',
        gradient: LinearGradient(
          colors: [primary, secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ), // Theme-aware gradient using primary and secondary
      ),
      OnboardingPage(
        icon: Icons.chat_bubble,
        title: 'Connect Instantly',
        description: 'Message friends, join conversations, and stay connected with real-time chat and notifications.',
        gradient: LinearGradient(
          colors: [primary, primary.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ), // Theme-aware gradient using primary
      ),
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage(BuildContext context) {
    final pages = _getPages(context);
    if (_currentPage < pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _navigateToLogin();
    }
  }

  void _skip() {
    _navigateToLogin();
  }

  void _navigateToLogin() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.1),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              )),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: context.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Skip button
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 60),
                    TextButton(
                      onPressed: _skip,
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Page view
              Builder(
                builder: (context) {
                  final pages = _getPages(context);
                  return Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (index) {
                        setState(() {
                          _currentPage = index;
                        });
                      },
                      itemCount: pages.length,
                      itemBuilder: (context, index) {
                        return AnimationConfiguration.staggeredList(
                          position: index,
                          duration: const Duration(milliseconds: 375),
                          child: SlideAnimation(
                            verticalOffset: 50.0,
                            child: FadeInAnimation(
                              child: _buildPage(pages[index]),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
              // Page indicators
              Builder(
                builder: (context) {
                  final pages = _getPages(context);
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      pages.length,
                      (index) => _buildIndicator(context, index == _currentPage),
                    ),
                  );
                },
              ),
              const SizedBox(height: 40),
              // Next button
              Builder(
                builder: (context) {
                  final pages = _getPages(context);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: GlassButton(
                      text: _currentPage == pages.length - 1
                          ? 'Get Started'
                          : 'Next',
                      onPressed: () => _nextPage(context),
                      width: double.infinity,
                    ),
                  );
                },
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon with gradient background
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              gradient: page.gradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: ThemeHelper.getAccentColor(context).withOpacity(0.3), // Theme-aware accent color with opacity
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Icon(
              page.icon,
              size: 80,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 60),
          // Title
          Text(
            page.title,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          // Description
          Text(
            page.description,
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 16,
              height: 1.6,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildIndicator(BuildContext context, bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? ThemeHelper.getAccentColor(context) : context.textMuted, // Theme-aware accent color
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class OnboardingPage {
  final IconData icon;
  final String title;
  final String description;
  final Gradient gradient;

  OnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
    required this.gradient,
  });
}

