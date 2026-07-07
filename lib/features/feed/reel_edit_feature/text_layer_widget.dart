part of '../reel_edit_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════
// TEXT LAYER WIDGET
// ═══════════════════════════════════════════════════════════════════════════

class _TextLayerWidget extends StatelessWidget {
  final _TextLayer layer;

  const _TextLayerWidget({required this.layer});

  @override
  Widget build(BuildContext context) {
    return switch (layer.style) {
      _TextStyle.plain => Text(
        layer.text,
        style: TextStyle(
          color: layer.color,
          fontSize: layer.fontSize,
          fontWeight: FontWeight.bold,
          shadows: const [Shadow(blurRadius: 6, color: Colors.black54)],
        ),
      ),
      _TextStyle.filled => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: layer.bgColor ?? Colors.black,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          layer.text,
          style: TextStyle(
            color: layer.color,
            fontSize: layer.fontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      _TextStyle.outlined => Stack(
        children: [
          Text(
            layer.text,
            style: TextStyle(
              fontSize: layer.fontSize,
              fontWeight: FontWeight.bold,
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3
                ..color = Colors.black,
            ),
          ),
          Text(
            layer.text,
            style: TextStyle(
              color: layer.color,
              fontSize: layer.fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      _TextStyle.neon => Text(
        layer.text,
        style: TextStyle(
          color: layer.color,
          fontSize: layer.fontSize,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(blurRadius: 2, color: layer.color),
            Shadow(blurRadius: 10, color: layer.color),
            Shadow(blurRadius: 20, color: layer.color.withOpacity(0.6)),
          ],
        ),
      ),
    };
  }
}
