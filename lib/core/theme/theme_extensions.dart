import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Extension to get theme-aware colors
extension ThemeColors on BuildContext {
  Color get backgroundColor {
    final isDark = Theme.of(this).brightness == Brightness.dark;
    return isDark ? AppColors.primaryBackground : AppColors.lightBackground;
  }

  Color get secondaryBackgroundColor {
    final isDark = Theme.of(this).brightness == Brightness.dark;
    return isDark ? AppColors.secondaryBackground : AppColors.lightSecondaryBackground;
  }

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

  Color get surfaceColor {
    final isDark = Theme.of(this).brightness == Brightness.dark;
    return isDark ? AppColors.glassSurface : AppColors.lightSurface;
  }

  Color get borderColor {
    final isDark = Theme.of(this).brightness == Brightness.dark;
    return isDark ? AppColors.glassBorder : AppColors.lightGlassBorder;
  }

  LinearGradient get backgroundGradient {
    final isDark = Theme.of(this).brightness == Brightness.dark;
    return isDark 
        ? AppColors.backgroundGradient
        : const LinearGradient(
            colors: [Color(0xFFF8F9FA), Color(0xFFFFFFFF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          );
  }
}


