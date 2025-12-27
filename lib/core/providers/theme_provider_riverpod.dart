import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

/// Theme state
class ThemeState {
  final bool isDarkMode;

  ThemeState({required this.isDarkMode});

  ThemeState copyWith({bool? isDarkMode}) {
    return ThemeState(isDarkMode: isDarkMode ?? this.isDarkMode);
  }
}

/// Theme provider using Riverpod StateNotifier for super fast performance
class ThemeNotifier extends StateNotifier<ThemeState> {
  static const String _themeKey = 'isDarkMode';

  ThemeNotifier() : super(ThemeState(isDarkMode: true)) {
    _loadTheme();
  }

  /// Load theme preference from SharedPreferences
  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDark = prefs.getBool(_themeKey) ?? true; // Default to dark mode
      state = state.copyWith(isDarkMode: isDark);
    } catch (e) {
      // If loading fails, use default (dark mode)
      state = state.copyWith(isDarkMode: true);
    }
  }

  /// Toggle theme and save preference
  Future<void> toggleTheme() async {
    final newIsDark = !state.isDarkMode;
    state = state.copyWith(isDarkMode: newIsDark);
    await _saveTheme();
  }

  /// Set theme and save preference
  Future<void> setTheme(bool isDark) async {
    state = state.copyWith(isDarkMode: isDark);
    await _saveTheme();
  }

  /// Save theme preference to SharedPreferences
  Future<void> _saveTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_themeKey, state.isDarkMode);
    } catch (e) {
      // If saving fails, just continue - theme will still work for this session
      debugPrint('Error saving theme preference: $e');
    }
  }
}

/// Theme provider
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>((ref) {
  return ThemeNotifier();
});

/// Convenience providers
final isDarkModeProvider = Provider<bool>((ref) {
  return ref.watch(themeProvider).isDarkMode;
});

final currentThemeProvider = Provider<ThemeData>((ref) {
  final isDark = ref.watch(isDarkModeProvider);
  return isDark ? AppTheme.darkTheme : AppTheme.lightTheme;
});

