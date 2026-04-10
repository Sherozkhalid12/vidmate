import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/providers/auth_provider_riverpod.dart';
import '../../core/providers/socket_provider_riverpod.dart';
import '../../core/providers/stories_provider_riverpod.dart';
import '../onboarding/onboarding_screen.dart';
import '../main/main_screen.dart';

/// Elegant splash screen with existing theme colors.
/// Loads stored auth from SharedPreferences; if user is logged in, goes to MainScreen.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late DateTime _started;

  @override
  void initState() {
    super.initState();
    _started = DateTime.now();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _controller.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_runSplashFlow()));
  }

  Future<void> _runSplashFlow() async {
    try {
      await ref
          .read(authProvider.notifier)
          .loadFromStorage()
          .timeout(const Duration(seconds: 3));
    } catch (_) {}

    if (!mounted) return;
    final loggedIn = ref.read(isAuthenticatedProvider);
    if (loggedIn) {
      ref.read(socketConnectionProvider.notifier).ensureConnection();
      unawaited(ref.read(storiesProvider.notifier).loadStories());
    }

    final elapsed = DateTime.now().difference(_started);
    const minSplash = Duration(milliseconds: 2500);
    if (elapsed < minSplash) {
      await Future.delayed(minSplash - elapsed);
    }
    if (!mounted) return;

    final isLoggedIn = ref.read(isAuthenticatedProvider);
    if (isLoggedIn) {
      ref.read(socketConnectionProvider.notifier).ensureConnection();
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            isLoggedIn ? const MainScreen() : const OnboardingScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = ThemeHelper.getAccentColor(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: ThemeHelper.getBackgroundGradient(context),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: Center(
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Text(
                      'VidConnect',
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 36,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
