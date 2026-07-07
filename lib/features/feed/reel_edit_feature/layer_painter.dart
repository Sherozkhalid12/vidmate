part of '../reel_edit_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════
// LAYER PAINTER
// ═══════════════════════════════════════════════════════════════════════════

class _LayerPainter extends CustomPainter {
  final List<_Layer> layers;
  final List<Offset?> currentStroke;
  final Color currentColor;
  final double currentStrokeWidth;
  final _BrushType currentBrush;

  const _LayerPainter({
    required this.layers,
    required this.currentStroke,
    required this.currentColor,
    required this.currentStrokeWidth,
    required this.currentBrush,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    for (final layer in layers) {
      if (layer is _DrawLayer) {
        _paintStroke(
            canvas, layer.points, layer.color, layer.strokeWidth, layer.brush);
      }
    }

    if (currentStroke.isNotEmpty) {
      _paintStroke(canvas, currentStroke, currentColor, currentStrokeWidth,
          currentBrush);
    }

    canvas.restore();
  }

  void _paintStroke(Canvas canvas, List<Offset?> points, Color color,
      double width, _BrushType brush) {
    if (points.isEmpty) return;

    final path = _buildPath(points);

    switch (brush) {
      case _BrushType.pen:
        canvas.drawPath(
            path,
            Paint()
              ..color = color
              ..strokeWidth = width
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round
              ..style = PaintingStyle.stroke);

      case _BrushType.marker:
        canvas.drawPath(
            path,
            Paint()
              ..color = color.withOpacity(0.55)
              ..strokeWidth = width * 2.5
              ..strokeCap = StrokeCap.square
              ..style = PaintingStyle.stroke);

      case _BrushType.neon:
        canvas.drawPath(
            path,
            Paint()
              ..color = color.withOpacity(0.3)
              ..strokeWidth = width * 4
              ..strokeCap = StrokeCap.round
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
              ..style = PaintingStyle.stroke);
        canvas.drawPath(
            path,
            Paint()
              ..color = color.withOpacity(0.6)
              ..strokeWidth = width * 2
              ..strokeCap = StrokeCap.round
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
              ..style = PaintingStyle.stroke);
        canvas.drawPath(
            path,
            Paint()
              ..color = Colors.white
              ..strokeWidth = width * 0.5
              ..strokeCap = StrokeCap.round
              ..style = PaintingStyle.stroke);

      case _BrushType.eraser:
        canvas.drawPath(
            path,
            Paint()
              ..blendMode = BlendMode.clear
              ..strokeWidth = width * 3
              ..strokeCap = StrokeCap.round
              ..style = PaintingStyle.stroke);
    }
  }

  Path _buildPath(List<Offset?> points) {
    final path = Path();
    bool needsMove = true;

    for (final point in points) {
      if (point == null) {
        needsMove = true;
        continue;
      }
      if (needsMove) {
        path.moveTo(point.dx, point.dy);
        needsMove = false;
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }

    return path;
  }

  @override
  bool shouldRepaint(_LayerPainter oldDelegate) {
    return oldDelegate.currentStroke != currentStroke ||
        oldDelegate.layers.length != layers.length ||
        oldDelegate.currentColor != currentColor ||
        oldDelegate.currentStrokeWidth != currentStrokeWidth;
  }
}
