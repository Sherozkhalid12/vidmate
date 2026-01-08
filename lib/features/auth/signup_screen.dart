import 'package:flutter/material.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/glass_button.dart';
import '../main/main_screen.dart';
import 'login_screen.dart';

/// Sign up screen with glassmorphism design
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _agreeToTerms = false;
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
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  void _handleSignUp() {
    if (_formKey.currentState!.validate() && _agreeToTerms) {
      setState(() {
        _isLoading = true;
      });

      // Simulate sign up
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
    } else if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please agree to the terms and conditions'),
          backgroundColor: AppColors.warning,
        ),
      );
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
                  // Back button
                  Align(
                    alignment: Alignment.topLeft,
                    child: IconButton(
                      icon: Icon(Icons.arrow_back),
                      color: context.textPrimary,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
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
                              Icons.person_add,
                              size: 64,
                              color: Colors.white, // White for high contrast on gradient background
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 40),
                  // Welcome text
                  Text(
                    'Create Account',
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
                    'Join the community today',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 16,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  // Name field
                  GlassCard(
                    padding: const EdgeInsets.only(top: 8),
                    borderRadius: BorderRadius.circular(16),
                    child: TextFormField(
                      controller: _nameController,
                      style: TextStyle(color: context.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        labelStyle: TextStyle(color: context.textSecondary),
                        contentPadding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                        isDense: false,
                        floatingLabelBehavior: FloatingLabelBehavior.auto,
                        prefixIcon: Icon(Icons.person_outline,
                            color: ThemeHelper.getAccentColor(context)),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        border: InputBorder.none,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Email field
                  GlassCard(
                    padding: const EdgeInsets.only(top: 8),
                    borderRadius: BorderRadius.circular(16),
                    child: TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(color: context.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Email',
                        labelStyle: TextStyle(color: context.textSecondary),
                        contentPadding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                        isDense: false,
                        floatingLabelBehavior: FloatingLabelBehavior.auto,
                        prefixIcon: Icon(Icons.email_outlined,
                            color: ThemeHelper.getAccentColor(context)),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
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
                    padding: const EdgeInsets.only(top: 8),
                    borderRadius: BorderRadius.circular(16),
                    child: TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: TextStyle(color: context.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        labelStyle:
                            TextStyle(color: context.textSecondary),
                        contentPadding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                        isDense: false,
                        floatingLabelBehavior: FloatingLabelBehavior.auto,
                        prefixIcon: Icon(Icons.lock_outlined,
                            color: ThemeHelper.getAccentColor(context)),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: ThemeHelper.getAccentColor(context),
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
                  const SizedBox(height: 16),
                  // Confirm password field
                  GlassCard(
                    padding: const EdgeInsets.only(top: 8),
                    borderRadius: BorderRadius.circular(16),
                    child: TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      style: TextStyle(color: context.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        labelStyle:
                            TextStyle(color: context.textSecondary),
                        contentPadding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                        isDense: false,
                        floatingLabelBehavior: FloatingLabelBehavior.auto,
                        prefixIcon: Icon(Icons.lock_outlined,
                            color: ThemeHelper.getAccentColor(context)),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: ThemeHelper.getAccentColor(context),
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword = !_obscureConfirmPassword;
                            });
                          },
                        ),
                        border: InputBorder.none,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please confirm your password';
                        }
                        if (value != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Terms and conditions
                  Row(
                    children: [
                      Checkbox(
                        value: _agreeToTerms,
                        onChanged: (value) {
                          setState(() {
                            _agreeToTerms = value ?? false;
                          });
                        },
                        activeColor: ThemeHelper.getAccentColor(context), // Theme-aware accent color
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _agreeToTerms = !_agreeToTerms;
                            });
                          },
                          child: Text(
                            'I agree to the Terms of Service and Privacy Policy',
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Sign up button
                  GlassButton(
                    text: 'Sign Up',
                    onPressed: _handleSignUp,
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
                  // Social sign up buttons
                  GlassButton(
                    text: 'Continue with Google',
                    icon: Icons.g_mobiledata,
                    backgroundColor: context.surfaceColor,
                    textColor: context.textPrimary,
                    onPressed: _handleSignUp,
                    width: double.infinity,
                  ),
                  const SizedBox(height: 12),
                  GlassButton(
                    text: 'Continue with Apple',
                    icon: Icons.apple,
                    backgroundColor: context.textPrimary,
                    textColor: context.backgroundColor,
                    onPressed: _handleSignUp,
                    width: double.infinity,
                  ),
                  const SizedBox(height: 40),
                  // Login link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
                          );
                        },
                        child: Text(
                          'Sign In',
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

