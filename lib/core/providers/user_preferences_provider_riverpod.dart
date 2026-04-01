import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/auth/auth_service.dart';
import '../../services/storage/user_storage_service.dart';
import '../models/user_preferences_model.dart';
import 'auth_provider_riverpod.dart';

class UserPreferencesState {
  final UserPreferencesModel preferences;
  final bool isSyncing;
  final String? error;

  const UserPreferencesState({
    this.preferences = const UserPreferencesModel(),
    this.isSyncing = false,
    this.error,
  });

  UserPreferencesState copyWith({
    UserPreferencesModel? preferences,
    bool? isSyncing,
    String? error,
    bool clearError = false,
  }) {
    return UserPreferencesState(
      preferences: preferences ?? this.preferences,
      isSyncing: isSyncing ?? this.isSyncing,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class UserPreferencesNotifier extends StateNotifier<UserPreferencesState> {
  UserPreferencesNotifier(this._ref) : super(const UserPreferencesState());

  final Ref _ref;
  final AuthService _authService = AuthService();

  Future<void> loadFromStorage() async {
    final userId = _ref.read(currentUserProvider)?.id;
    if (userId == null || userId.isEmpty) return;
    final prefs = await UserStorageService.instance.getPreferences(userId: userId);
    state = state.copyWith(preferences: prefs, clearError: true);
  }

  Future<void> updatePreference({
    required UserPreferencesModel Function(UserPreferencesModel current) update,
  }) async {
    final userId = _ref.read(currentUserProvider)?.id;
    if (userId == null || userId.isEmpty) return;

    final next = update(state.preferences);
    state = state.copyWith(preferences: next, isSyncing: true, clearError: true);

    await UserStorageService.instance.savePreferences(next, userId: userId);

    final result = await _authService.updatePreferences(preferences: next.toJson());
    if (!result.success) {
      state = state.copyWith(
        isSyncing: false,
        error: result.errorMessage ?? 'Failed to sync preferences',
      );
      return;
    }

    state = state.copyWith(isSyncing: false, clearError: true);
  }
}

final userPreferencesProvider =
    StateNotifierProvider<UserPreferencesNotifier, UserPreferencesState>((ref) {
  return UserPreferencesNotifier(ref);
});
