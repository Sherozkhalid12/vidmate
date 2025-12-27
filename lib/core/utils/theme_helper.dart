import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Helper class for theme-aware colors
class ThemeHelper {
  static Color getBackgroundColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? AppColors.primaryBackground : AppColors.lightBackground;
  }

  static Color getSecondaryBackgroundColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? AppColors.secondaryBackground : AppColors.lightSecondaryBackground;
  }

  static Color getTextPrimary(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
  }

  static Color getTextSecondary(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;
  }

  static Color getTextMuted(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? AppColors.textMuted : AppColors.lightTextMuted;
  }

  static Color getSurfaceColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? AppColors.glassSurface : AppColors.lightGlassSurfaceMedium;
  }

  static Color getBorderColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? AppColors.glassBorder : AppColors.lightGlassBorder;
  }

  static LinearGradient getBackgroundGradient(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? AppColors.backgroundGradient
        : AppColors.lightBackgroundGradient;
  }

  /// Get theme-aware icon color (uses Theme.iconTheme.color or falls back to textSecondary)
  static Color getIconColor(BuildContext context) {
    final iconTheme = Theme.of(context).iconTheme;
    if (iconTheme.color != null) {
      return iconTheme.color!;
    }
    return getTextSecondary(context);
  }

  /// Get high-contrast icon color for overlays (white in dark, black in light)
  static Color getHighContrastIconColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.white : Colors.black;
  }

  /// Get theme-aware accent color (primary color from colorScheme)
  /// Use for buttons, icons, highlights, and interactive elements
  static Color getAccentColor(BuildContext context) {
    return Theme.of(context).colorScheme.primary;
  }

  /// Get theme-aware accent gradient for buttons and decorative elements
  /// Returns a gradient from primary to slightly transparent primary
  static LinearGradient getAccentGradient(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return LinearGradient(
      colors: [
        primary,
        primary.withOpacity(0.8),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  /// Get theme-aware color for text/icons on accent backgrounds
  /// Returns onPrimary color from colorScheme
  static Color getOnAccentColor(BuildContext context) {
    return Theme.of(context).colorScheme.onPrimary;
  }
}


