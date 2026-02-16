import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import '../api/dio_client.dart';
import '../../services/auth/auth_service.dart';

/// Authentication state
class AuthState {
  final UserModel? currentUser;
  final bool isLoading;
  final String? error;

  AuthState({
    this.currentUser,
    this.isLoading = false,
    this.error,
  });

  bool get isAuthenticated => currentUser != null;

  AuthState copyWith({
    UserModel? currentUser,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return AuthState(
      currentUser: currentUser ?? this.currentUser,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Authentication notifier using AuthService. Riverpod only, no setState.
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState());

  final AuthService _authService = AuthService();

  /// Restore session from SharedPreferences (token + user). Call from splash so
  /// user can enter app directly when logged in, including when offline.
  Future<void> loadFromStorage() async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) return;
    final userJson = await _authService.getStoredUser();
    if (userJson == null) return;
    try {
      final user = UserModel.fromJson(userJson);
      state = state.copyWith(currentUser: user);
    } catch (_) {
      // Invalid stored user; clear auth so user can log in again
      await _authService.clearAuth();
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _authService.login(email: email, password: password);
    if (result.success && result.data != null) {
      state = state.copyWith(
        currentUser: result.data!.user,
        isLoading: false,
      );
      return true;
    }
    state = state.copyWith(
      isLoading: false,
      error: result.errorMessage ?? 'Login failed',
    );
    return false;
  }

  Future<bool> sendEmailOTP(String email) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _authService.sendEmailOTP(email: email);
    if (result.success) {
      state = state.copyWith(isLoading: false);
      return true;
    }
    state = state.copyWith(
      isLoading: false,
      error: result.errorMessage ?? 'Failed to send OTP',
    );
    return false;
  }

  Future<bool> verifyEmailOtp({required String email, required String otp}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _authService.verifyEmailOtp(email: email, otp: otp);
    if (result.success) {
      state = state.copyWith(isLoading: false);
      return true;
    }
    state = state.copyWith(
      isLoading: false,
      error: result.errorMessage ?? 'Invalid OTP',
    );
    return false;
  }

  Future<bool> signUp({
    required String username,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _authService.signup(
      username: username,
      email: email,
      password: password,
    );
    if (result.success && result.data != null) {
      state = state.copyWith(
        currentUser: result.data!.user,
        isLoading: false,
      );
      return true;
    }
    state = state.copyWith(
      isLoading: false,
      error: result.errorMessage ?? 'Sign up failed',
    );
    return false;
  }

  Future<void> logout() async {
    DioClient.clearAuthToken();
    await _authService.clearAuth();
    state = state.copyWith(currentUser: null);
  }

  Future<bool> updateUser({
    required String userId,
    String? name,
    String? username,
    String? bio,
    File? profilePicture,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _authService.updateUser(
      userId: userId,
      name: name,
      username: username,
      bio: bio,
      profilePicture: profilePicture,
    );
    if (result.success && result.data != null) {
      state = state.copyWith(
        currentUser: result.data!.user,
        isLoading: false,
      );
      return true;
    }
    state = state.copyWith(
      isLoading: false,
      error: result.errorMessage ?? 'Update failed',
    );
    return false;
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

/// Auth provider
final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier());

/// Convenience providers
final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(authProvider).currentUser;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isAuthenticated;
});

final authLoadingProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isLoading;
});

final authErrorProvider = Provider<String?>((ref) {
  return ref.watch(authProvider).error;
});
