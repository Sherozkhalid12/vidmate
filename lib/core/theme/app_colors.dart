import 'package:flutter/material.dart';

/// App color palette with glassmorphism and neon accents
class AppColors {
  // Background colors
  static const Color primaryBackground = Color(0xFF0B0F1A);
  static const Color secondaryBackground = Color(0xFF0E1325);
  
  // Glass surfaces
  static const Color glassSurface = Color.fromRGBO(255, 255, 255, 0.06);
  static const Color glassBorder = Color.fromRGBO(255, 255, 255, 0.12);
  
  // Accent colors
  static const Color neonPurple = Color(0xFF7C6CFF);
  static const Color cyanGlow = Color(0xFF2DE2E6);
  static const Color softBlue = Color(0xFF4DA3FF);
  static const Color warning = Color(0xFFFF6B6B);
  
  // Text colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA0A6C3);
  static const Color textMuted = Color(0xFF6E7391);
  
  // Light mode colors
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightSecondaryBackground = Color(0xFFF8F9FA);
  static const Color lightSurface = Color(0xFFF5F5F5);
  static const Color lightTextPrimary = Color(0xFF1A1A1A);
  static const Color lightTextSecondary = Color(0xFF666666);
  static const Color lightTextMuted = Color(0xFF999999);
  static const Color lightGlassBorder = Color(0xFFE0E0E0);
  
  // Gradients
  static const LinearGradient purpleGradient = LinearGradient(
    colors: [neonPurple, Color(0xFF9D8AFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient cyanGradient = LinearGradient(
    colors: [cyanGlow, softBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [primaryBackground, secondaryBackground],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  
  // Story ring gradient
  static const LinearGradient storyRingGradient = LinearGradient(
    colors: [neonPurple, cyanGlow, softBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

