import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Extension to get theme-aware colors
extension ThemeColors on BuildContext {
  // Background gradient - theme-aware
  LinearGradient get backgroundGradient {
    final isDark = Theme.of(this).brightness == Brightness.dark;
    return AppColors.getBackgroundGradient(isDark);
  }

  // Text colors
  Color get textPrimary {
    final isDark = Theme.of(this).brightness == Brightness.dark;
    return isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
  }

  Color get textSecondary {
    final isDark = Theme.of(this).brightness == Brightness.dark;
    return isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;
  }

  Color get textMuted {
    final isDark = Theme.of(this).brightness == Brightness.dark;
    return isDark ? AppColors.textMuted : AppColors.lightTextMuted;
  }

  // Glass surface colors
  Color get surfaceColor {
    final isDark = Theme.of(this).brightness == Brightness.dark;
    return isDark ? AppColors.glassSurfaceMedium : AppColors.lightGlassSurfaceMedium;
  }

  Color get borderColor {
    final isDark = Theme.of(this).brightness == Brightness.dark;
    return isDark ? AppColors.glassBorder : AppColors.lightGlassBorder;
  }
  
  // Button colors - white in dark, black in light
  Color get buttonColor {
    final isDark = Theme.of(this).brightness == Brightness.dark;
    return isDark ? Colors.white : Colors.black;
  }
  
  Color get buttonTextColor {
    final isDark = Theme.of(this).brightness == Brightness.dark;
    return isDark ? Colors.black : Colors.white;
  }
  
  // Background colors (for compatibility - returns first gradient color)
  Color get backgroundColor {
    final isDark = Theme.of(this).brightness == Brightness.dark;
    return isDark ? AppColors.backgroundTop1 : Colors.transparent;
  }
  
  // Secondary background (for compatibility - returns middle gradient color)
  Color get secondaryBackgroundColor {
    final isDark = Theme.of(this).brightness == Brightness.dark;
    return isDark ? AppColors.backgroundMid1 : AppColors.lightBackgroundMid1;
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // THEME-AWARE ACCENT COLORS - Use these instead of AppColors.neonPurple etc.
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Primary accent color (white in dark theme, black in light theme)
  Color get accentColor => buttonColor;
  
  // Legacy color support (mapped to theme-aware colors)
  Color get primaryColor => buttonColor;
  Color get secondaryColor => buttonColor;
  
  /// Secondary accent color (same as primary for glassmorphic design)
  Color get accentSecondary => buttonColor;
  
  /// Tertiary accent color (same as primary for glassmorphic design)
  Color get accentTertiary => buttonColor;
  
  /// Success/positive action color
  Color get successColor => AppColors.success;
  
  /// Warning color
  Color get warningColor => AppColors.warning;
  
  /// Error color
  Color get errorColor => AppColors.error;
  
  /// Info color
  Color get infoColor => AppColors.info;
}


