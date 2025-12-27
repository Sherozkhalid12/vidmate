import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      // Transparent scaffold - background gradient applied in screens
      scaffoldBackgroundColor: Colors.transparent,
      
      // Color scheme - neutral colors for glassmorphic design
      colorScheme: const ColorScheme.dark(
        primary: Colors.white,  // White for buttons in dark theme
        secondary: Colors.white,
        tertiary: Colors.white,
        error: AppColors.error,
        surface: AppColors.glassSurfaceMedium,
        onPrimary: Colors.black,  // Black text on white buttons
        onSecondary: Colors.black,
        onSurface: AppColors.textPrimary,
        onBackground: AppColors.textPrimary,
      ),
      
      // App bar theme - fully transparent with glass effect
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
      
      // Text theme
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 32,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
        displayMedium: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 28,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
        displaySmall: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        headlineMedium: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.15,
        ),
        titleLarge: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.15,
        ),
        titleMedium: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.15,
        ),
        bodyLarge: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.normal,
          letterSpacing: 0.5,
        ),
        bodyMedium: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.normal,
          letterSpacing: 0.25,
        ),
        bodySmall: TextStyle(
          color: AppColors.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.normal,
          letterSpacing: 0.4,
        ),
        labelLarge: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
        ),
      ),
      
      // Card theme
      cardTheme: CardThemeData(
        color: AppColors.glassSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(
            color: AppColors.glassBorder,
            width: 1,
          ),
        ),
      ),
      
      // Icon theme
      iconTheme: const IconThemeData(
        color: AppColors.textSecondary,
        size: 24,
      ),
      
      // Input decoration theme - glass style
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.glassSurfaceMedium,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: AppColors.glassBorder,
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: AppColors.glassBorder,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: AppColors.glassBorderBright,
            width: 1.5,
          ),
        ),
        hintStyle: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 14,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
      ),
      
      // Button themes - white buttons in dark theme (no purple)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      
      // Text button theme - white text
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      
      // Outlined button theme - white border
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      
      // Switch theme - white for selected
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return Colors.white;
          }
          return AppColors.textMuted;
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return Colors.white.withOpacity(0.5);
          }
          return AppColors.glassSurface;
        }),
      ),
    );
  }
  
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      // Transparent scaffold - background gradient applied in screens
      scaffoldBackgroundColor: Colors.transparent,
      
      // Color scheme - neutral colors for glassmorphic design
      colorScheme: const ColorScheme.light(
        primary: Colors.black,  // Black for buttons in light theme
        secondary: Colors.black,
        tertiary: Colors.black,
        error: AppColors.error,
        surface: AppColors.lightGlassSurfaceMedium,
        onPrimary: Colors.white,  // White text on black buttons
        onSecondary: Colors.white,
        onSurface: AppColors.lightTextPrimary,
        onBackground: AppColors.lightTextPrimary,
      ),
      
      // App bar theme - fully transparent with glass effect
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        iconTheme: IconThemeData(color: AppColors.lightTextPrimary),
        titleTextStyle: TextStyle(
          color: AppColors.lightTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
      
      // Text theme
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: AppColors.lightTextPrimary,
          fontSize: 32,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
        displayMedium: TextStyle(
          color: AppColors.lightTextPrimary,
          fontSize: 28,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
        displaySmall: TextStyle(
          color: AppColors.lightTextPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        headlineMedium: TextStyle(
          color: AppColors.lightTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.15,
        ),
        titleLarge: TextStyle(
          color: AppColors.lightTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.15,
        ),
        titleMedium: TextStyle(
          color: AppColors.lightTextPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.15,
        ),
        bodyLarge: TextStyle(
          color: AppColors.lightTextPrimary,
          fontSize: 16,
          fontWeight: FontWeight.normal,
          letterSpacing: 0.5,
        ),
        bodyMedium: TextStyle(
          color: AppColors.lightTextSecondary,
          fontSize: 14,
          fontWeight: FontWeight.normal,
          letterSpacing: 0.25,
        ),
        bodySmall: TextStyle(
          color: AppColors.lightTextSecondary,
          fontSize: 12,
          fontWeight: FontWeight.normal,
          letterSpacing: 0.4,
        ),
        labelLarge: TextStyle(
          color: AppColors.lightTextPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
        ),
      ),
      
      // Card theme - glass style
      cardTheme: CardThemeData(
        color: AppColors.lightGlassSurfaceMedium,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(
            color: AppColors.lightGlassBorder,
            width: 1,
          ),
        ),
      ),
      
      // Icon theme
      iconTheme: const IconThemeData(
        color: AppColors.lightTextSecondary,
        size: 24,
      ),
      
      // Input decoration theme - glass style
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightGlassSurfaceMedium,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: AppColors.lightGlassBorder,
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: AppColors.lightGlassBorder,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: AppColors.lightGlassBorderBright,
            width: 1.5,
          ),
        ),
        hintStyle: const TextStyle(
          color: AppColors.lightTextMuted,
          fontSize: 14,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
      ),
      
      // Button themes - black buttons in light theme (no purple)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      
      // Text button theme - black text
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: Colors.black,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      
      // Outlined button theme - black border
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black,
          side: const BorderSide(color: Colors.black, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      
      // Switch theme - black for selected
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return Colors.black;
          }
          return AppColors.lightTextMuted;
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return Colors.black.withOpacity(0.5);
          }
          return AppColors.lightGlassSurface;
        }),
      ),
    );
  }
}

