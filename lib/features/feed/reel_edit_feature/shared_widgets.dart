part of '../reel_edit_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════
// SHARED UI COMPONENTS
// ═══════════════════════════════════════════════════════════════════════════

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  const _IconBtn(this.icon, {required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon,
            color: color ?? _ReelEditTheme.of(context).textPrim, size: 22),
      ),
    );
  }
}

class _SlimSlider extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final bool centered;
  final ValueChanged<double> onChanged;

  const _SlimSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.centered = false,
  });

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: _ReelEditTheme.of(context).accent,
        inactiveTrackColor: _ReelEditTheme.of(context).border,
        thumbColor: _ReelEditTheme.of(context).accent,
        overlayColor: _ReelEditTheme.of(context).accent.withOpacity(0.15),
        trackHeight: 2,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
      ),
      child: Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        onChanged: onChanged,
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _TabButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: isActive
            ? _DS.activePill(context)
            : BoxDecoration(borderRadius: BorderRadius.circular(4)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 22,
                color: isActive
                    ? _ReelEditTheme.of(context).accent
                    : _ReelEditTheme.of(context).textSec),
            const SizedBox(height: 4),
            Text(
              label,
              style: _DS.label(
                context,
                size: 9,
                color: isActive
                    ? _ReelEditTheme.of(context).accent
                    : _ReelEditTheme.of(context).textDim,
                weight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorCircle extends StatelessWidget {
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;
  final double size;

  const _ColorCircle({
    required this.color,
    required this.isSelected,
    required this.onTap,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: isSelected ? size + 6 : size,
        height: isSelected ? size + 6 : size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected
                ? _ReelEditTheme.of(context).accent
                : _ReelEditTheme.of(context).border,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 10)]
              : null,
        ),
      ),
    );
  }
}
