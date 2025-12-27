import 'package:flutter/material.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/glass_button.dart';
import '../main/main_screen.dart';
import 'signup_screen.dart';

/// Login screen with glassmorphism design
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
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
    _emailController.dispose();
    _passwordController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      // Simulate login
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
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
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: context.backgroundGradient,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  // Logo with glow
                  AnimatedBuilder(
                    animation: _glowAnimation,
                    builder: (context, child) {
                      return Center(
                        child: Container(
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
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 40),
                  // Welcome text
                  Text(
                    'Welcome Back',
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to continue',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 16,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  // Email field
                  GlassCard(
                    padding: EdgeInsets.zero,
                    borderRadius: BorderRadius.circular(16),
                    child: TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(color: context.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Email',
                        labelStyle: TextStyle(color: context.textSecondary),
                        prefixIcon: Icon(Icons.email_outlined,
                            color: context.textSecondary),
                        border: InputBorder.none,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!value.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Password field
                  GlassCard(
                    padding: EdgeInsets.zero,
                    borderRadius: BorderRadius.circular(16),
                    child: TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: TextStyle(color: context.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        labelStyle:
                            TextStyle(color: context.textSecondary),
                        prefixIcon: Icon(Icons.lock_outlined,
                            color: context.textSecondary),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: context.textSecondary,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        border: InputBorder.none,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Forgot password
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Password reset feature coming soon'),
                            backgroundColor: ThemeHelper.getAccentColor(context), // Theme-aware accent color
                          ),
                        );
                      },
                      child: Text(
                        'Forgot Password?',
                        style: TextStyle(
                          color: ThemeHelper.getAccentColor(context), // Theme-aware accent color
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Login button
                  GlassButton(
                    text: 'Sign In',
                    onPressed: _handleLogin,
                    isLoading: _isLoading,
                    width: double.infinity,
                  ),
                  const SizedBox(height: 24),
                  // Divider
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
                  // Social login buttons
                  GlassButton(
                    text: 'Continue with Google',
                    icon: Icons.g_mobiledata,
                    backgroundColor: context.surfaceColor,
                    textColor: context.textPrimary,
                    onPressed: _handleLogin,
                    width: double.infinity,
                  ),
                  const SizedBox(height: 12),
                  GlassButton(
                    text: 'Continue with Apple',
                    icon: Icons.apple,
                    backgroundColor: context.textPrimary,
                    textColor: context.backgroundColor,
                    onPressed: _handleLogin,
                    width: double.infinity,
                  ),
                  const SizedBox(height: 40),
                  // Sign up link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SignUpScreen(),
                            ),
                          );
                        },
                        child: Text(
                          'Sign Up',
                          style: TextStyle(
                            color: ThemeHelper.getAccentColor(context), // Theme-aware accent color
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
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

