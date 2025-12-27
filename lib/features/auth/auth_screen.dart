import 'package:flutter/material.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/glass_button.dart';
import '../main/main_screen.dart';

/// Auth screen with glassmorphism design
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const MainScreen(),
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
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  // Logo with glow animation
                  AnimatedBuilder(
                    animation: _glowAnimation,
                    builder: (context, child) {
                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: ThemeHelper.getAccentColor(context) // Theme-aware accent color
                                  .withOpacity(_glowAnimation.value * 0.5),
                              blurRadius: 40,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: ThemeHelper.getAccentGradient(context), // Theme-aware accent gradient
                          ),
                          child: Icon(
                            Icons.play_circle_filled,
                            size: 64,
                            color: context.textPrimary,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 40),
                  // App name
                  Text(
                    'VidConnect',
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your Social Video Platform',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 16,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 60),
                  // Glass card with login options
                  GlassCard(
                    padding: const EdgeInsets.all(32),
                    borderRadius: BorderRadius.circular(24),
                    child: Column(
                      children: [
                        GlassButton(
                          text: 'Continue with Google',
                          icon: Icons.g_mobiledata,
                          onPressed: _handleLogin,
                          width: double.infinity,
                        ),
                        const SizedBox(height: 16),
                        GlassButton(
                          text: 'Continue with Apple',
                          icon: Icons.apple,
                          backgroundColor: context.textPrimary,
                          textColor: context.backgroundColor,
                          onPressed: _handleLogin,
                          width: double.infinity,
                        ),
                        const SizedBox(height: 16),
                        GlassButton(
                          text: 'Continue with Facebook',
                          icon: Icons.facebook,
                          backgroundColor: ThemeHelper.getAccentColor(context), // Theme-aware accent color
                          onPressed: _handleLogin,
                          width: double.infinity,
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 1,
                                color: context.borderColor,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'OR',
                                style: TextStyle(
                                  color: context.textMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                height: 1,
                                color: context.borderColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        GlassButton(
                          text: 'Continue as Guest',
                          backgroundColor: context.surfaceColor,
                          textColor: context.textPrimary,
                          onPressed: _handleLogin,
                          width: double.infinity,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Terms and privacy
                  Text(
                    'By continuing, you agree to our Terms of Service\nand Privacy Policy',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.textMuted,
                      fontSize: 12,
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
}

