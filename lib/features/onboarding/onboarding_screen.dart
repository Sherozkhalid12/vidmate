import 'package:flutter/material.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/utils/theme_helper.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../core/widgets/glass_button.dart';
import '../auth/login_screen.dart';

/// Futuristic onboarding screen with modern design
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late AnimationController _iconController;

  @override
  void initState() {
    super.initState();
    _iconController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _iconController.dispose();
    super.dispose();
  }

  List<OnboardingPage> _getPages(BuildContext context) {
    final accentColor = ThemeHelper.getAccentColor(context);
    
    return [
      OnboardingPage(
        icon: Icons.play_circle_filled,
        title: 'Watch Unlimited',
        description: 'Stream long-form videos, binge-watch reels, and discover content from creators around the globe.',
        gradient: LinearGradient(
          colors: [
            accentColor,
            accentColor.withOpacity(0.7),
            accentColor.withOpacity(0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        iconColor: Colors.white,
      ),
      OnboardingPage(
        icon: Icons.video_camera_front_rounded,
        title: 'Create & Share',
        description: 'Record videos, upload photos, share stories, and express yourself with creative content.',
        gradient: LinearGradient(
          colors: [
            accentColor.withOpacity(0.9),
            accentColor.withOpacity(0.6),
            accentColor.withOpacity(0.4),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        iconColor: Colors.white,
      ),
      OnboardingPage(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'Connect Instantly',
        description: 'Message friends, join conversations, and stay connected with real-time chat and notifications.',
        gradient: LinearGradient(
          colors: [
            accentColor,
            accentColor.withOpacity(0.8),
            accentColor.withOpacity(0.6),
          ],
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
        ),
        iconColor: Colors.white,
      ),
    ];
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = ThemeHelper.getAccentColor(context);
    
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 60),
                    TextButton(
                      onPressed: _skip,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          color: isDark 
                              ? context.textSecondary 
                              : ThemeHelper.getTextSecondary(context),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
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
                              child: _buildPage(pages[index], context),
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
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        pages.length,
                        (index) => _buildIndicator(context, index == _currentPage),
                      ),
                    ),
                  );
                },
              ),
              
              // Next button
              Builder(
                builder: (context) {
                  final pages = _getPages(context);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingPage page, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = ThemeHelper.getAccentColor(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Futuristic icon with animations
          AnimatedBuilder(
            animation: _iconController,
            builder: (context, child) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: page.gradient,
                  boxShadow: isDark ? [
                    BoxShadow(
                      color: accentColor.withOpacity(0.4),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                    BoxShadow(
                      color: accentColor.withOpacity(0.2),
                      blurRadius: 60,
                      spreadRadius: 20,
                    ),
                  ] : null, // No shadow in light mode
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Rotating ring
                    Transform.rotate(
                      angle: _iconController.value * 2 * 3.14159,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    // Icon
                    Icon(
                      page.icon,
                      size: 70,
                      color: page.iconColor,
                    ),
                  ],
                ),
              );
            },
          ),
          
          const SizedBox(height: 60),
          
          // Title
          Text(
            page.title,
            style: TextStyle(
              color: isDark 
                  ? context.textPrimary 
                  : ThemeHelper.getTextPrimary(context),
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 24),
          
          // Description
          Text(
            page.description,
            style: TextStyle(
              color: isDark 
                  ? context.textSecondary 
                  : ThemeHelper.getTextSecondary(context),
              fontSize: 16,
              height: 1.6,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildIndicator(BuildContext context, bool isActive) {
    final accentColor = ThemeHelper.getAccentColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 32 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive 
            ? accentColor 
            : (isDark ? context.textMuted : ThemeHelper.getTextMuted(context)),
        borderRadius: BorderRadius.circular(4),
        boxShadow: isActive && isDark
            ? [
                BoxShadow(
                  color: accentColor.withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ]
            : null, // No shadow in light mode
      ),
    );
  }
}

class OnboardingPage {
  final IconData icon;
  final String title;
  final String description;
  final Gradient gradient;
  final Color iconColor;

  OnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
    required this.gradient,
    required this.iconColor,
  });
}
