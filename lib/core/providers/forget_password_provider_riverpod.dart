import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/forget_password/forget_password_service.dart';

/// Steps in the forget-password flow
enum ForgetPasswordStep {
  enterEmail,
  verifyOtp,
  resetPassword,
}

/// Forget password state
class ForgetPasswordState {
  final String? email;
  final ForgetPasswordStep step;
  final bool isLoading;
  final String? error;

  ForgetPasswordState({
    this.email,
    this.step = ForgetPasswordStep.enterEmail,
    this.isLoading = false,
    this.error,
  });

  ForgetPasswordState copyWith({
    String? email,
    ForgetPasswordStep? step,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return ForgetPasswordState(
      email: email ?? this.email,
      step: step ?? this.step,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Forget password notifier. Riverpod only.
class ForgetPasswordNotifier extends StateNotifier<ForgetPasswordState> {
  ForgetPasswordNotifier() : super(ForgetPasswordState());

  final ForgetPasswordService _service = ForgetPasswordService();

  Future<bool> sendOtp(String email) async {
    state = state.copyWith(isLoading: true, clearError: true, email: email);
    final result = await _service.sendForgetPasswordOTP(email: email);
    if (result.success) {
      state = state.copyWith(
        isLoading: false,
        step: ForgetPasswordStep.verifyOtp,
      );
      return true;
    }
    state = state.copyWith(
      isLoading: false,
      error: result.errorMessage ?? 'Failed to send OTP',
    );
    return false;
  }

  Future<bool> verifyOtp(String otp) async {
    final email = state.email;
    if (email == null || email.isEmpty) {
      state = state.copyWith(error: 'Email is required');
      return false;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _service.verifyForgetPasswordOTP(email: email, otp: otp);
    if (result.success) {
      state = state.copyWith(
        isLoading: false,
        step: ForgetPasswordStep.resetPassword,
      );
      return true;
    }
    state = state.copyWith(
      isLoading: false,
      error: result.errorMessage ?? 'Invalid OTP',
    );
    return false;
  }

  Future<bool> resetPassword(String newPassword) async {
    final email = state.email;
    if (email == null || email.isEmpty) {
      state = state.copyWith(error: 'Email is required');
      return false;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _service.resetPassword(
      email: email,
      newPassword: newPassword,
    );
    if (result.success) {
      state = state.copyWith(isLoading: false);
      return true;
    }
    state = state.copyWith(
      isLoading: false,
      error: result.errorMessage ?? 'Failed to reset password',
    );
    return false;
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  void reset() {
    state = ForgetPasswordState();
  }
}

final forgetPasswordProvider =
    StateNotifierProvider<ForgetPasswordNotifier, ForgetPasswordState>((ref) {
  return ForgetPasswordNotifier();
});
