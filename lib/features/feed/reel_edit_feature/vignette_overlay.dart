part of '../reel_edit_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════
// VIGNETTE OVERLAY
// ═══════════════════════════════════════════════════════════════════════════

class _VignetteOverlay extends StatelessWidget {
  final double intensity;
  const _VignetteOverlay({required this.intensity});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(intensity * 0.85)
          ],
          stops: const [0.5, 1.0],
        ),
      ),
    );
  }
}
