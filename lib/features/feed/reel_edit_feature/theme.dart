part of '../reel_edit_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════
// REEL EDIT THEME – app theme on black background, bluish accent, nothing hides
// ═══════════════════════════════════════════════════════════════════════════

class _ReelEditThemeData {
  final Color bg;
  final Color surface;
  final Color surface2;
  final Color border;
  final Color accent;
  final Color accentAlt;
  final Color textPrim;
  final Color textSec;
  final Color textDim;

  const _ReelEditThemeData({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.border,
    required this.accent,
    required this.accentAlt,
    required this.textPrim,
    required this.textSec,
    required this.textDim,
  });
}

class _ReelEditTheme extends InheritedWidget {
  const _ReelEditTheme({required this.data, required super.child});
  final _ReelEditThemeData data;

  static _ReelEditThemeData _fallback() => const _ReelEditThemeData(
    bg: Colors.black,
    surface: Color(0xFF1E293B),
    surface2: Color(0xFF334155),
    border: Color(0xFF475569),
    accent: Color(0xFF60A5FA),
    accentAlt: Color(0xFFF87171),
    textPrim: Colors.white,
    textSec: Color(0xFFB0BEC5),
    textDim: Color(0xFF78909C),
  );

  static _ReelEditThemeData of(BuildContext context) {
    final t = context.dependOnInheritedWidgetOfExactType<_ReelEditTheme>();
    return t?.data ?? _fallback();
  }

  @override
  bool updateShouldNotify(_ReelEditTheme old) => data != old.data;
}

class _DS {
  _DS._();

  static TextStyle label(
      BuildContext context, {
        double size = 10,
        Color? color,
        FontWeight? weight,
      }) {
    final d = _ReelEditTheme.of(context);
    return TextStyle(
      fontSize: size,
      color: color ?? d.textSec,
      fontWeight: weight ?? FontWeight.w500,
      letterSpacing: 1.2,
      fontFamily: 'monospace',
    );
  }

  static TextStyle heading(BuildContext context,
      {double size = 13, Color? color}) {
    final d = _ReelEditTheme.of(context);
    return TextStyle(
      fontSize: size,
      color: color ?? d.textPrim,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.5,
    );
  }

  static BoxDecoration pill(BuildContext context,
      {Color? bg, Color? borderColor}) {
    final d = _ReelEditTheme.of(context);
    return BoxDecoration(
      color: bg ?? d.surface2,
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: borderColor ?? d.border, width: 1),
    );
  }

  static BoxDecoration activePill(BuildContext context) {
    final d = _ReelEditTheme.of(context);
    return BoxDecoration(
      color: d.accent.withOpacity(0.18),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: d.accent, width: 1),
    );
  }

  static Future<void> hapticLight() async {
    await HapticFeedback.lightImpact();
  }

  static Future<void> hapticMedium() async {
    await HapticFeedback.mediumImpact();
  }
}
