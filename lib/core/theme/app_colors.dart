import 'package:flutter/material.dart';

/// App color palette with glassmorphism and premium gradients
/// Features sophisticated navy-to-brown-black gradient for immersive experience
/// All screens use this background with transparent glass widgets on top
class AppColors {
  // ═══════════════════════════════════════════════════════════════════════════
  // DARK THEME BACKGROUND COLORS
  // Navy → Brown-Bronze → Near-Black with subtle warm undertones
  // ═══════════════════════════════════════════════════════════════════════════

  // Top area colors
  static const Color backgroundTop1 = Color(0xFF1A1F2E);          // Dark navy-blue
  static const Color backgroundTop2 = Color(0xFF1C2130);          // Slightly lighter navy

  // Upper-middle colors
  static const Color backgroundUpperMid1 = Color(0xFF1A1C26);     // Navy transitioning
  static const Color backgroundUpperMid2 = Color(0xFF1E1A1F);     // Brown warmth beginning

  // Middle section colors (KEY - brown-bronze warmth)
  static const Color backgroundMid1 = Color(0xFF1F1C1A);          // Dark brown-bronze tint
  static const Color backgroundMid2 = Color(0xFF221E1C);          // Subtle warm undertones

  // Lower-middle colors
  static const Color backgroundLowerMid1 = Color(0xFF1A1816);     // Brown-black transition
  static const Color backgroundLowerMid2 = Color(0xFF151312);     // Darker brown-black

  // Bottom colors
  static const Color backgroundBottom1 = Color(0xFF0F0E0D);       // Near-black
  static const Color backgroundBottom2 = Color(0xFF0A0909);       // Almost pure black

  // ═══════════════════════════════════════════════════════════════════════════
  // LIGHT THEME BACKGROUND COLORS – UPDATED to be visibly warm & premium
  // Warm Cream → Peach-Gold → Blush-Rose → Soft Lavender → Clean White
  // ═══════════════════════════════════════════════════════════════════════════

  // Top area colors (warm cream with visible warmth)
  static const Color lightBackgroundTop1 = Color(0xFFFFF8F0);     // Rich warm cream
  static const Color lightBackgroundTop2 = Color(0xFFFFFBF5);     // Soft warm off-white

  // Upper-middle colors (clear peach-gold transition)
  static const Color lightBackgroundUpperMid1 = Color(0xFFFFEEDD); // Soft peach
  static const Color lightBackgroundUpperMid2 = Color(0xFFFFE5D0); // Warm peach-gold

  // Middle section colors (KEY - visible blush-rose & lavender warmth)
  static const Color lightBackgroundMid1 = Color(0xFFFFF0F5);     // Gentle blush rose
  static const Color lightBackgroundMid2 = Color(0xFFF8F0FF);     // Soft lavender-rose

  // Lower-middle colors (pale lavender to clean light)
  static const Color lightBackgroundLowerMid1 = Color(0xFFFAF5FF); // Pale lavender
  static const Color lightBackgroundLowerMid2 = Color(0xFFFCF9FF); // Very pale lavender-white

  // Bottom colors (lightest – clean fade to white)
  static const Color lightBackgroundBottom1 = Color(0xFFFEFCFF);  // Near-white with hint
  static const Color lightBackgroundBottom2 = Color(0xFFFFFFFF);  // Pure white

  // ═══════════════════════════════════════════════════════════════════════════
  // DARK THEME BACKGROUND GRADIENT - Used across ALL dark mode screens
  // ═══════════════════════════════════════════════════════════════════════════

  /// The main dark background gradient used on ALL screens
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF1A1F2E),      // Top: Dark navy-blue
      Color(0xFF1C2130),      // Top transition
      Color(0xFF1A1C26),      // Upper-middle: Navy transitioning
      Color(0xFF1E1A1F),      // Upper-middle: Brown warmth
      Color(0xFF1F1C1A),      // Middle: Dark brown-bronze ✨
      Color(0xFF221E1C),      // Middle: Warm undertones ✨
      Color(0xFF1A1816),      // Lower-middle: Brown-black
      Color(0xFF151312),      // Lower-middle: Darker
      Color(0xFF0F0E0D),      // Bottom: Near-black
      Color(0xFF0A0909),      // Bottom: Almost black
    ],
    stops: [0.0, 0.15, 0.25, 0.35, 0.45, 0.55, 0.65, 0.75, 0.90, 1.0],
  );

  // Alternative: Simpler dark version with key stops only
  static const LinearGradient backgroundGradientSimple = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF1A1F2E),      // Top: Navy-blue
      Color(0xFF1E1A1F),      // Upper-middle: Navy with brown
      Color(0xFF1F1C1A),      // Middle: Brown-bronze warmth ✨
      Color(0xFF1A1816),      // Lower-middle: Brown-black
      Color(0xFF0F0E0D),      // Bottom: Near-black
    ],
    stops: [0.0, 0.3, 0.5, 0.7, 1.0],
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // LIGHT THEME BACKGROUND GRADIENT - Updated with visible warmth
  // ═══════════════════════════════════════════════════════════════════════════

  /// The main light background gradient used on ALL screens
  static const LinearGradient lightBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFF0F8FF),      // Top: Soft light bluish cream (icy sky tint) — mirrors dark mode navy top
      Color(0xFFF5FAFF),      // Top transition: Very pale blue-cream
      Color(0xFFFFF0E8),      // Upper-middle: Warm peach-gold (visible warmth)
      Color(0xFFFFE8D5),      // Upper-middle: Deeper peach-gold
      Color(0xFFFFE9F0),      // Middle: Gentle blush rose (key warm point) ✨
      Color(0xFFF2EDFF),      // Middle: Soft lavender-rose blend ✨
      Color(0xFFF8F4FF),      // Lower-middle: Pale lavender
      Color(0xFFFBF9FF),      // Lower-middle: Very pale lavender-white
      Color(0xFFF5FBFF),      // Bottom: Near-white with subtle cool blue hint
      Color(0xFFFAFDFF),      // Bottom: Clean light bluish-white (mirrors dark mode near-black fade)
    ],
    stops: [0.0, 0.15, 0.25, 0.35, 0.45, 0.55, 0.65, 0.75, 0.90, 1.0],
  );

  // Alternative: Simpler light version with key stops only
  static const LinearGradient lightBackgroundGradientSimple = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFFFF8F0),      // Top: Rich warm cream
      Color(0xFFFFE5D0),      // Upper-middle: Warm peach-gold
      Color(0xFFFFF0F5),      // Middle: Gentle blush rose ✨
      Color(0xFFFAF5FF),      // Lower-middle: Pale lavender
      Color(0xFFFFFFFF),      // Bottom: Pure white
    ],
    stops: [0.0, 0.3, 0.5, 0.7, 1.0],
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // THEME-AWARE HELPER - Get background based on theme
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get the appropriate background gradient based on theme brightness
  static LinearGradient getBackgroundGradient(bool isDark) {
    return isDark ? backgroundGradient : lightBackgroundGradient;
  }

  /// Get the simplified background gradient based on theme brightness
  static LinearGradient getBackgroundGradientSimple(bool isDark) {
    return isDark ? backgroundGradientSimple : lightBackgroundGradientSimple;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GLASS SURFACES - Transparent with blur for BOTH themes
  // ═══════════════════════════════════════════════════════════════════════════

  // Dark theme glass surfaces
  static const Color glassSurface = Color.fromRGBO(255, 255, 255, 0.08);        // 8% white (very subtle)
  static const Color glassSurfaceMedium = Color.fromRGBO(255, 255, 255, 0.12);  // 12% white (standard)
  static const Color glassSurfaceElevated = Color.fromRGBO(255, 255, 255, 0.15); // 15% white (elevated)
  static const Color glassSurfaceHeavy = Color.fromRGBO(255, 255, 255, 0.20);    // 20% white (prominent)

  // Light theme glass surfaces
  static const Color lightGlassSurface = Color.fromRGBO(255, 255, 255, 0.70);       // 70% white (subtle)
  static const Color lightGlassSurfaceMedium = Color.fromRGBO(255, 255, 255, 0.85); // 85% white (standard)
  static const Color lightGlassSurfaceElevated = Color.fromRGBO(255, 255, 255, 0.90); // 90% white (elevated)
  static const Color lightGlassSurfaceHeavy = Color.fromRGBO(255, 255, 255, 0.95);   // 95% white (prominent)

  // Dark theme glass borders
  static const Color glassBorder = Color.fromRGBO(255, 255, 255, 0.15);          // 15% white subtle
  static const Color glassBorderAccent = Color.fromRGBO(139, 92, 246, 0.25);     // 25% purple glow
  static const Color glassBorderBright = Color.fromRGBO(255, 255, 255, 0.25);    // 25% white bright

  // Light theme glass borders
  static const Color lightGlassBorder = Color.fromRGBO(255, 255, 255, 0.50);         // 50% white subtle
  static const Color lightGlassBorderAccent = Color.fromRGBO(180, 165, 243, 0.40);   // 40% lavender glow
  static const Color lightGlassBorderBright = Color.fromRGBO(255, 255, 255, 0.70);   // 70% white bright

  // Dark theme glass shadows
  static const Color glassShadow = Color.fromRGBO(0, 0, 0, 0.30);                // 30% black
  static const Color glassShadowHeavy = Color.fromRGBO(0, 0, 0, 0.50);           // 50% black (deep)

  // Light theme glass shadows
  static const Color lightGlassShadow = Color.fromRGBO(0, 0, 0, 0.08);           // 8% black (subtle)
  static const Color lightGlassShadowHeavy = Color.fromRGBO(0, 0, 0, 0.15);      // 15% black (visible)

  // ═══════════════════════════════════════════════════════════════════════════
  // ACCENT COLORS - Premium, soothing palette
  // ═══════════════════════════════════════════════════════════════════════════

  // Primary accents (vibrant but not neon)
  static const Color royalPurple = Color(0xFF8B5CF6);     // Royal purple
  static const Color indigo = Color(0xFF6366F1);          // Vibrant indigo
  static const Color electricBlue = Color(0xFF60A5FA);    // Electric blue
  static const Color cyan = Color(0xFF3B82F6);            // Royal blue

  // Secondary accents (soft variations)
  static const Color lavender = Color(0xFFB4A5F3);        // Soft lavender
  static const Color rose = Color(0xFFE89FB5);            // Soft rose
  static const Color coral = Color(0xFFFFB08A);           // Soft coral
  static const Color teal = Color(0xFF6EC1E4);            // Gentle teal

  // Semantic colors
  static const Color success = Color(0xFF10B981);         // Emerald green
  static const Color successLight = Color(0xFF86EFAC);    // Soft mint
  static const Color warning = Color(0xFFF59E0B);         // Deep amber
  static const Color warningLight = Color(0xFFFBBF24);    // Warm amber
  static const Color error = Color(0xFFEF4444);           // Vibrant red
  static const Color errorLight = Color(0xFFE57373);      // Soft red
  static const Color info = Color(0xFF3B82F6);            // Royal blue
  static const Color infoLight = Color(0xFF93C5FD);       // Sky blue

  // ═══════════════════════════════════════════════════════════════════════════
  // TEXT COLORS - Optimized for dark background
  // ═══════════════════════════════════════════════════════════════════════════

  static const Color textPrimary = Color(0xFFFFFFFF);              // Pure white
  static const Color textSecondary = Color(0xFFE8E8F0);            // Off white
  static const Color textTertiary = Color(0xFFB8B8C7);             // Light gray
  static const Color textMuted = Color(0xFF7A7D99);                // Medium gray
  static const Color textDisabled = Color(0xFF5E6280);             // Dark gray

  // ═══════════════════════════════════════════════════════════════════════════
  // LIGHT THEME TEXT COLORS - Optimized for light background
  // ═══════════════════════════════════════════════════════════════════════════

  static const Color lightTextPrimary = Color(0xFF1A1A1A);          // Near black
  static const Color lightTextSecondary = Color(0xFF4A4A4A);        // Dark gray
  static const Color lightTextTertiary = Color(0xFF6A6A6A);         // Medium gray
  static const Color lightTextMuted = Color(0xFF8A8A8A);            // Light gray
  static const Color lightTextDisabled = Color(0xFFB0B0B0);        // Very light gray

  // ═══════════════════════════════════════════════════════════════════════════
  // PREMIUM GRADIENTS - For buttons, cards, and accents
  // ═══════════════════════════════════════════════════════════════════════════

  /// Primary gradient - Royal purple to electric blue
  static const LinearGradient purpleGradient = LinearGradient(
    colors: [
      Color(0xFF8B5CF6),      // Royal purple
      Color(0xFF6366F1),      // Vibrant indigo
      Color(0xFF60A5FA),      // Electric blue
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.0, 0.5, 1.0],
  );

  /// Secondary gradient - Deep purple to indigo
  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [
      Color(0xFF7C3AED),      // Deep purple
      Color(0xFF6366F1),      // Vibrant indigo
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Accent gradient - Blue to cyan
  static const LinearGradient cyanGradient = LinearGradient(
    colors: [
      Color(0xFF3B82F6),      // Royal blue
      Color(0xFF60A5FA),      // Sky blue
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Story ring gradient - Full spectrum
  static const LinearGradient storyRingGradient = LinearGradient(
    colors: [
      Color(0xFF8B5CF6),      // Royal purple
      Color(0xFF6366F1),      // Vibrant indigo
      Color(0xFF60A5FA),      // Electric blue
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Radial glow for interactive elements
  static const RadialGradient radialGlow = RadialGradient(
    center: Alignment.center,
    radius: 1.5,
    colors: [
      Color(0x668B5CF6),      // Purple center (40%)
      Color(0x4D6366F1),      // Indigo mid (30%)
      Color(0x0060A5FA),      // Blue edge (transparent)
    ],
    stops: [0.0, 0.5, 1.0],
  );

  /// Soft glow for cards and containers
  static const RadialGradient softGlow = RadialGradient(
    center: Alignment.center,
    radius: 2.0,
    colors: [
      Color(0x33FFFFFF),      // White center (20%)
      Color(0x1AFFFFFF),      // White mid (10%)
      Color(0x00FFFFFF),      // Transparent edge
    ],
    stops: [0.0, 0.5, 1.0],
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // CARD GRADIENTS - Feed diversity with glass effect
  // ═══════════════════════════════════════════════════════════════════════════

  static const List<LinearGradient> cardGradients = [
    // Royal Purple to Indigo
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0x668B5CF6),    // 40% purple
        Color(0x4D7C3AED),    // 30% deep purple
        Color(0x336366F1),    // 20% indigo
      ],
    ),
    // Indigo to Blue
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0x666366F1),    // 40% indigo
        Color(0x4D5B5FE8),    // 30% medium indigo
        Color(0x3360A5FA),    // 20% electric blue
      ],
    ),
    // Blue to Cyan
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0x6660A5FA),    // 40% electric blue
        Color(0x4D3B82F6),    // 30% royal blue
        Color(0x3314B8A6),    // 20% teal
      ],
    ),
    // Purple to Violet
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0x668B5CF6),    // 40% purple
        Color(0x4DA78BFA),    // 30% light purple
        Color(0x33C4B5FD),    // 20% violet
      ],
    ),
  ];

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPER METHODS - Theme-aware getters
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get glass surface based on theme
  static Color getGlassSurface(bool isDark) {
    return isDark ? glassSurfaceMedium : lightGlassSurfaceMedium;
  }

  /// Get glass border based on theme
  static Color getGlassBorder(bool isDark) {
    return isDark ? glassBorder : lightGlassBorder;
  }

  /// Get glass shadow based on theme
  static Color getGlassShadow(bool isDark) {
    return isDark ? glassShadow : lightGlassShadow;
  }

  /// Get card gradient by index
  static LinearGradient getCardGradient(int index) {
    return cardGradients[index % cardGradients.length];
  }

  /// Get glass surface with custom opacity (dark theme)
  static Color getGlassSurfaceWithOpacity(double opacity) {
    return Color.fromRGBO(255, 255, 255, opacity.clamp(0.0, 1.0));
  }

  /// Get glass border with custom opacity (dark theme)
  static Color getGlassBorderWithOpacity(double opacity) {
    return Color.fromRGBO(255, 255, 255, opacity.clamp(0.0, 1.0));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BLUR CONSTANTS - For glassmorphism effects
  // ═══════════════════════════════════════════════════════════════════════════

  static const double blurLight = 10.0;       // Subtle blur for light glass
  static const double blurMedium = 15.0;      // Standard blur for most glass
  static const double blurHeavy = 20.0;       // Heavy blur for prominent glass
  static const double blurIntense = 30.0;     // Intense blur for special effects

  // ═══════════════════════════════════════════════════════════════════════════
  // LEGACY COLOR CONSTANTS - For backward compatibility
  // ═══════════════════════════════════════════════════════════════════════════

  // Legacy accent colors - mapped to white/black based on theme
  // Use context.buttonColor instead
  @Deprecated('Use context.buttonColor or Theme.of(context).colorScheme.primary instead')
  static const Color neonPurple = Colors.white;  // Maps to button color (white in dark theme)

  @Deprecated('Use context.buttonColor or Theme.of(context).colorScheme.primary instead')
  static const Color cyanGlow = Colors.white;   // Maps to button color

  @Deprecated('Use context.buttonColor or Theme.of(context).colorScheme.primary instead')
  static const Color softBlue = Colors.white;   // Maps to button color

  // Legacy background colors - use context.backgroundColor instead
  @Deprecated('Use context.backgroundColor instead')
  static const Color primaryBackground = backgroundTop1;

  @Deprecated('Use context.secondaryBackgroundColor instead')
  static const Color secondaryBackground = backgroundMid1;

  @Deprecated('Use context.backgroundColor instead')
  static const Color lightBackground = lightBackgroundTop1;

  @Deprecated('Use context.secondaryBackgroundColor instead')
  static const Color lightSecondaryBackground = lightBackgroundMid1;
}