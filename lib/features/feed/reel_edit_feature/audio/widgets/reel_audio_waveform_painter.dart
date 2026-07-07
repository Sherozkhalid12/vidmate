import 'package:flutter/material.dart';

/// Paints a waveform stretched edge-to-edge across the available width.
class ReelAudioWaveformPainter extends CustomPainter {
  ReelAudioWaveformPainter({
    required this.samples,
    required this.color,
  });

  final List<double> samples;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final paint = Paint()..color = color;
    final barCount = (size.width / 3).floor().clamp(8, 120);
    final barWidth = size.width / barCount * 0.55;
    final gap = size.width / barCount * 0.45;

    for (var i = 0; i < barCount; i++) {
      final t = barCount <= 1 ? 0.0 : i / (barCount - 1);
      final sample = _sampleAt(t).clamp(0.08, 1.0);
      final h = (size.height * sample).clamp(2.0, size.height);
      final x = i * (barWidth + gap);
      final y = (size.height - h) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, h),
          const Radius.circular(1),
        ),
        paint,
      );
    }
  }

  double _sampleAt(double t) {
    if (samples.isEmpty) return 0.3 + 0.4 * (0.5 - (t - 0.5).abs());
    if (samples.length == 1) return samples.first;
    final pos = t * (samples.length - 1);
    final i = pos.floor().clamp(0, samples.length - 1);
    final j = (i + 1).clamp(0, samples.length - 1);
    final frac = pos - i;
    return samples[i] * (1 - frac) + samples[j] * frac;
  }

  @override
  bool shouldRepaint(covariant ReelAudioWaveformPainter oldDelegate) {
    return oldDelegate.samples != samples || oldDelegate.color != color;
  }
}
