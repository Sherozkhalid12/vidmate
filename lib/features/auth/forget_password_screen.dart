import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/glass_button.dart';
import '../../core/providers/forget_password_provider_riverpod.dart';
import 'login_screen.dart';

/// Forget password flow: enter email → send OTP → verify OTP → reset password.
/// Matches app design language (theme, GlassCard, GlassButton).
class ForgetPasswordScreen extends ConsumerStatefulWidget {
  const ForgetPasswordScreen({super.key});

  @override
  ConsumerState<ForgetPasswordScreen> createState() =>
      _ForgetPasswordScreenState();
}

class _ForgetPasswordScreenState extends ConsumerState<ForgetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref
        .read(forgetPasswordProvider.notifier)
        .sendOtp(_emailController.text.trim());
    if (!mounted) return;
    if (ok) {
      _showSuccess('OTP sent to your email');
    } else {
      _showError(
          ref.read(forgetPasswordProvider).error ?? 'Failed to send OTP');
    }
  }

  Future<void> _verifyOtp() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(forgetPasswordProvider.notifier).verifyOtp(
          _otpController.text.trim(),
        );
    if (!mounted) return;
    if (ok) {
      _showSuccess('OTP verified');
    } else {
      _showError(
          ref.read(forgetPasswordProvider).error ?? 'Invalid OTP');
    }
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordController.text != _confirmPasswordController.text) {
      _showError('Passwords do not match');
      return;
    }
    final ok = await ref.read(forgetPasswordProvider.notifier).resetPassword(
          _passwordController.text,
        );
    if (!mounted) return;
    if (ok) {
      _showSuccess('Password reset successfully');
      ref.read(forgetPasswordProvider.notifier).reset();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } else {
      _showError(ref.read(forgetPasswordProvider).error ??
          'Failed to reset password');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(forgetPasswordProvider);
    final step = state.step;
    final isLoading = state.isLoading;

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
                  Align(
                    alignment: Alignment.topLeft,
                    child: IconButton(
                      icon: Icon(Icons.arrow_back, color: context.textPrimary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Forgot Password',
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    step == ForgetPasswordStep.enterEmail
                        ? 'Enter your email to receive OTP'
                        : step == ForgetPasswordStep.verifyOtp
                            ? 'Enter the OTP sent to your email'
                            : 'Enter your new password',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  if (step == ForgetPasswordStep.enterEmail) ...[
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
                          contentPadding:
                              const EdgeInsets.fromLTRB(16, 20, 16, 16),
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
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Enter your email';
                          if (!v.contains('@')) return 'Enter a valid email';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    GlassButton(
                      text: 'Send OTP',
                      onPressed: isLoading ? null : _sendOtp,
                      isLoading: isLoading,
                      width: double.infinity,
                    ),
                  ] else if (step == ForgetPasswordStep.verifyOtp) ...[
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
                          contentPadding:
                              const EdgeInsets.fromLTRB(16, 20, 16, 16),
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
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Enter OTP';
                          if (v.length < 4) return 'Enter a valid OTP';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    GlassButton(
                      text: 'Verify OTP',
                      onPressed: isLoading ? null : _verifyOtp,
                      isLoading: isLoading,
                      width: double.infinity,
                    ),
                  ] else ...[
                    GlassCard(
                      padding: const EdgeInsets.only(top: 8),
                      borderRadius: BorderRadius.circular(16),
                      child: TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: TextStyle(color: context.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'New Password',
                          labelStyle: TextStyle(color: context.textSecondary),
                          contentPadding:
                              const EdgeInsets.fromLTRB(16, 20, 16, 16),
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
                              setState(
                                  () => _obscurePassword = !_obscurePassword);
                            },
                          ),
                          border: InputBorder.none,
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Enter password';
                          if (v.length < 6) return 'At least 6 characters';
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
                        obscureText: _obscureConfirm,
                        style: TextStyle(color: context.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          labelStyle: TextStyle(color: context.textSecondary),
                          contentPadding:
                              const EdgeInsets.fromLTRB(16, 20, 16, 16),
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
                              _obscureConfirm
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: ThemeHelper.getAccentColor(context),
                            ),
                            onPressed: () {
                              setState(
                                  () => _obscureConfirm = !_obscureConfirm);
                            },
                          ),
                          border: InputBorder.none,
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Confirm password';
                          if (v != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    GlassButton(
                      text: 'Reset Password',
                      onPressed: isLoading ? null : _resetPassword,
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
