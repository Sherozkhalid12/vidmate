import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/utils/theme_helper.dart';
import '../onboarding/onboarding_screen.dart';

/// Splash screen with animated logo and glow effect
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
      ),
    );

    _controller.forward();

    // Navigate to onboarding after animation
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const OnboardingScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradient = isDark 
        ? AppColors.backgroundGradient
        : const LinearGradient(
            colors: [Color(0xFFF8F9FA), Color(0xFFFFFFFF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          );
    final textColor = isDark ? context.textSecondary : AppColors.lightTextSecondary;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: gradient,
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App name
                  Column(
                    children: [
                      Opacity(
                        opacity: _opacityAnimation.value,
                        child: ShaderMask(
                          shaderCallback: (bounds) {
                            final primary = Theme.of(context).colorScheme.primary;
                            final secondary = Theme.of(context).colorScheme.secondary;
                            return LinearGradient(
                              colors: [
                                primary,
                                secondary,
                                primary.withOpacity(0.7),
                              ],
                            ).createShader(bounds);
                          },
                          child: Text(
                            'VidConnect',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 3,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Opacity(
                        opacity: _opacityAnimation.value,
                        child: Text(
                          'Your Social Video Platform',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 16,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

