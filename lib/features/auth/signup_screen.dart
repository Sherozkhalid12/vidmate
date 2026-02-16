import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/glass_button.dart';
import '../../core/providers/auth_provider_riverpod.dart';
import '../main/main_screen.dart';
import 'login_screen.dart';

/// Sign up screen with glassmorphism design
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

enum _SignupStep { enterDetails, verifyEmail }

class _SignUpScreenState extends ConsumerState<SignUpScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  _SignupStep _step = _SignupStep.enterDetails;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
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
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Step 1: Validate form + terms, send OTP, go to verify email step.
  Future<void> _handleVerifyEmail() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreeToTerms) {
      _showError('Please agree to the terms and conditions');
      return;
    }
    final ok = await ref
        .read(authProvider.notifier)
        .sendEmailOTP(_emailController.text.trim());
    if (!mounted) return;
    if (ok) {
      _showSuccess('OTP sent to your email');
      setState(() => _step = _SignupStep.verifyEmail);
    } else {
      _showError(ref.read(authErrorProvider) ?? 'Failed to send OTP');
    }
  }

  /// Step 2: Verify OTP then create account and enter app.
  Future<void> _handleVerifyAndCreateAccount() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(authProvider.notifier).verifyEmailOtp(
          email: _emailController.text.trim(),
          otp: _otpController.text.trim(),
        );
    if (!mounted) return;
    if (!ok) {
      _showError(ref.read(authErrorProvider) ?? 'Invalid OTP');
      return;
    }
    _showSuccess('Email verified');
    final success = await ref.read(authProvider.notifier).signUp(
          username: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
    if (!mounted) return;
    if (success) {
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
    } else {
      _showError(ref.read(authErrorProvider) ?? 'Sign up failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authLoadingProvider);
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
                      icon: Icon(Icons.arrow_back, color: context.textPrimary),
                      onPressed: () {
                        if (_step == _SignupStep.enterDetails) {
                          Navigator.pop(context);
                        } else {
                          setState(() => _step = _SignupStep.enterDetails);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  AnimatedBuilder(
                    animation: _glowAnimation,
                    builder: (context, child) {
                      final isDark = Theme.of(context).brightness == Brightness.dark;
                      return Center(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: isDark ? [
                              BoxShadow(
                                color: ThemeHelper.getAccentColor(context)
                                    .withOpacity(_glowAnimation.value * 0.5),
                                blurRadius: 40,
                                spreadRadius: 10,
                              ),
                            ] : null,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: ThemeHelper.getAccentGradient(context),
                            ),
                            child: Icon(
                              _step == _SignupStep.enterDetails
                                  ? Icons.person_add
                                  : Icons.mark_email_read_outlined,
                              size: 64,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 40),
                  Text(
                    _step == _SignupStep.enterDetails
                        ? 'Create Account'
                        : 'Verify your email',
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
                    _step == _SignupStep.enterDetails
                        ? 'Join the community today'
                        : 'Enter the code sent to your email',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 16,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  // Step 1: Full signup form (name, email, password, terms) → Verify Email
                  if (_step == _SignupStep.enterDetails) ...[
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
                    Row(
                      children: [
                        Checkbox(
                          value: _agreeToTerms,
                          onChanged: (value) {
                            setState(() {
                              _agreeToTerms = value ?? false;
                            });
                          },
                          activeColor: ThemeHelper.getAccentColor(context),
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
                    GlassButton(
                      text: 'Verify Email',
                      onPressed: isLoading ? null : _handleVerifyEmail,
                      isLoading: isLoading,
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
                      text: 'Continue with Google',
                      icon: Icons.g_mobiledata,
                      backgroundColor: context.surfaceColor,
                      textColor: context.textPrimary,
                      onPressed: _handleVerifyEmail,
                      width: double.infinity,
                    ),
                    const SizedBox(height: 12),
                    GlassButton(
                      text: 'Continue with Apple',
                      icon: Icons.apple,
                      backgroundColor: context.textPrimary,
                      textColor: context.backgroundColor,
                      onPressed: _handleVerifyEmail,
                      width: double.infinity,
                    ),
                    const SizedBox(height: 40),
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
                              color: ThemeHelper.getAccentColor(context),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  // Step 2: Verify email OTP then create account
                  if (_step == _SignupStep.verifyEmail) ...[
                    GlassCard(
                      padding: const EdgeInsets.only(top: 8),
                      borderRadius: BorderRadius.circular(16),
                      child: TextFormField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: context.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'OTP',
                          labelStyle: TextStyle(color: context.textSecondary),
                          contentPadding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                          isDense: false,
                          floatingLabelBehavior: FloatingLabelBehavior.auto,
                          prefixIcon: Icon(Icons.pin_outlined,
                              color: ThemeHelper.getAccentColor(context)),
                          prefixIconConstraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          border: InputBorder.none,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter the OTP';
                          }
                          if (value.length < 4) return 'Enter a valid OTP';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    GlassButton(
                      text: 'Verify & Create Account',
                      onPressed: isLoading ? null : _handleVerifyAndCreateAccount,
                      isLoading: isLoading,
                      width: double.infinity,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

