import 'dart:io';
import 'dart:ui';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:path_provider/path_provider.dart';

class VideoFrameExtractor {
  VideoFrameExtractor._();

  /// Returns video dimensions (width/height) using FFprobe.
  static Future<Size?> getVideoSize(File videoFile) async {
    final session = await FFprobeKit.getMediaInformation(videoFile.path);
    final info = session.getMediaInformation();
    if (info == null) return null;
    try {
      final props = (info as dynamic).getAllProperties();
      if (props is Map) {
        final streams = props['streams'];
        if (streams is List) {
          for (final s in streams) {
            if (s is Map) {
              final type = (s['codec_type'] ?? s['codecType'] ?? '').toString();
              if (type != 'video') continue;
              final w = int.tryParse((s['width'] ?? '').toString()) ?? 0;
              final h = int.tryParse((s['height'] ?? '').toString()) ?? 0;
              if (w > 0 && h > 0) return Size(w.toDouble(), h.toDouble());
            }
          }
        }
      }
    } catch (_) {}
    try {
      final streams = (info as dynamic).getStreams();
      if (streams is List) {
        for (final s in streams) {
          try {
            final type = (s as dynamic).getType?.call() ?? (s as dynamic).getCodecType?.call();
            if (type != 'video') continue;
            final w = int.tryParse(((s as dynamic).getWidth?.call() ?? '').toString()) ?? 0;
            final h = int.tryParse(((s as dynamic).getHeight?.call() ?? '').toString()) ?? 0;
            if (w > 0 && h > 0) return Size(w.toDouble(), h.toDouble());
          } catch (_) {}
        }
      }
    } catch (_) {}
    return null;
  }

  /// Returns duration in milliseconds using FFprobe (no video decoder init).
  static Future<int> getDurationMs(File videoFile) async {
    final session = await FFprobeKit.getMediaInformation(videoFile.path);
    final info = session.getMediaInformation();
    final durationStr = info?.getDuration();
    final seconds = double.tryParse(durationStr ?? '');
    if (seconds == null || seconds.isNaN || seconds.isInfinite || seconds <= 0) {
      return 0;
    }
    return (seconds * 1000).round();
  }

  /// Extracts a single frame at [positionMs] into a JPEG file.
  /// Returns the output file on success.
  static Future<File> extractJpegFrame({
    required File videoFile,
    required int positionMs,
    int? maxWidth,
  }) async {
    final tmp = await getTemporaryDirectory();
    final out = File(
      '${tmp.path}${Platform.pathSeparator}cover_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );

    // -ss before -i for faster seek, but may be less accurate; good enough for cover.
    final seconds = (positionMs / 1000.0).toStringAsFixed(3);
    final vf = (maxWidth != null && maxWidth > 0)
        ? ' -vf "scale=$maxWidth:-2"'
        : '';
    final cmd =
        '-ss $seconds -i "${videoFile.path}" -frames:v 1$vf -q:v 2 "${out.path}"';

    final session = await FFmpegKit.execute(cmd);
    final code = await session.getReturnCode();
    if (code == null || !code.isValueSuccess()) {
      throw Exception('Failed to extract cover frame');
    }
    if (!await out.exists()) {
      throw Exception('Cover image not created');
    }
    return out;
  }
}

