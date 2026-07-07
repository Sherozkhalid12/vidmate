part of '../reel_edit_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════
// CROP OVERLAY
// ═══════════════════════════════════════════════════════════════════════════

class _CropOverlay extends StatelessWidget {
  final Rect rect;
  final ValueChanged<Rect> onRectChanged;

  const _CropOverlay({required this.rect, required this.onRectChanged});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        final left = rect.left * width;
        final top = rect.top * height;
        final right = rect.right * width;
        final bottom = rect.bottom * height;

        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter:
                _CropDimPainter(Rect.fromLTRB(left, top, right, bottom)),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              width: right - left,
              height: bottom - top,
              child: CustomPaint(painter: _GridPainter()),
            ),
            Positioned(
              left: left,
              top: top,
              width: right - left,
              height: bottom - top,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                      color: _ReelEditTheme.of(context).accent, width: 2),
                ),
              ),
            ),
            _buildCornerHandle(
                context, left - 12, top - 12, 1, 1, width, height),
            _buildCornerHandle(
                context, right - 12, top - 12, -1, 1, width, height),
            _buildCornerHandle(
                context, left - 12, bottom - 12, 1, -1, width, height),
            _buildCornerHandle(
                context, right - 12, bottom - 12, -1, -1, width, height),
            Positioned(
              left: left + 24,
              top: top + 24,
              width: right - left - 48,
              height: bottom - top - 48,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanUpdate: (d) {
                  final newRect = Rect.fromLTRB(
                    ((left + d.delta.dx) / width).clamp(0, 1 - rect.width),
                    ((top + d.delta.dy) / height).clamp(0, 1 - rect.height),
                    ((right + d.delta.dx) / width).clamp(rect.width, 1),
                    ((bottom + d.delta.dy) / height).clamp(rect.height, 1),
                  );
                  onRectChanged(newRect);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCornerHandle(BuildContext context, double x, double y,
      double sx, double sy, double containerWidth, double containerHeight) {
    return Positioned(
      left: x,
      top: y,
      width: 24,
      height: 24,
      child: GestureDetector(
        onPanUpdate: (d) {
          final newRect = Rect.fromLTRB(
            sx > 0
                ? ((rect.left * containerWidth + d.delta.dx) / containerWidth)
                .clamp(0, rect.right - 0.1)
                : rect.left,
            sy > 0
                ? ((rect.top * containerHeight + d.delta.dy) / containerHeight)
                .clamp(0, rect.bottom - 0.1)
                : rect.top,
            sx < 0
                ? ((rect.right * containerWidth + d.delta.dx) / containerWidth)
                .clamp(rect.left + 0.1, 1)
                : rect.right,
            sy < 0
                ? ((rect.bottom * containerHeight + d.delta.dy) /
                containerHeight)
                .clamp(rect.top + 0.1, 1)
                : rect.bottom,
          );
          onRectChanged(newRect);
        },
        child: Container(
          decoration: BoxDecoration(
            color: _ReelEditTheme.of(context).accent,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

class _CropDimPainter extends CustomPainter {
  final Rect cropRect;
  _CropDimPainter(this.cropRect);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(cropRect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, Paint()..color = Colors.black.withOpacity(0.6));
  }

  @override
  bool shouldRepaint(_CropDimPainter oldDelegate) =>
      cropRect != oldDelegate.cropRect;
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..strokeWidth = 0.5;

    for (int i = 1; i < 3; i++) {
      final x = size.width * i / 3;
      final y = size.height * i / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
