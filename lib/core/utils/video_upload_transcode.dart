import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// FFmpeg-based transcode for gallery picks that use codecs many Android
/// devices cannot decode in hardware (HEVC 10-bit, AV1, VP9, etc.).
class VideoUploadTranscode {
  VideoUploadTranscode._();

  /// Primary video stream codec name from FFprobe, lowercased (e.g. `hevc`, `h264`).
  static Future<String?> probeVideoCodecName(File file) async {
    try {
      final session = await FFprobeKit.getMediaInformation(file.path);
      final info = session.getMediaInformation();
      if (info == null) return null;

      try {
        final props = (info as dynamic).getAllProperties();
        if (props is Map) {
          final streams = props['streams'];
          if (streams is List) {
            for (final s in streams) {
              if (s is! Map) continue;
              final type = (s['codec_type'] ?? s['codecType'] ?? '').toString();
              if (type != 'video') continue;
              final name = (s['codec_name'] ?? s['codecName'] ?? '').toString();
              if (name.isNotEmpty) return name.toLowerCase();
            }
          }
        }
      } catch (_) {}

      try {
        final streams = (info as dynamic).getStreams();
        if (streams is List) {
          for (final s in streams) {
            try {
              final type =
                  (s as dynamic).getType?.call() ?? (s as dynamic).getCodecType?.call();
              if (type?.toString() != 'video') continue;
              final name = (s as dynamic).getCodec?.call();
              if (name != null && '$name'.isNotEmpty) return '$name'.toLowerCase();
            } catch (_) {}
          }
        }
      } catch (_) {}
    } catch (e, st) {
      debugPrint('[VideoUploadTranscode] probe failed: $e\n$st');
    }
    return null;
  }

  /// Codecs that commonly break [VideoPlayerController] on mid-range Android.
  static bool shouldSoftwareTranscode(String? codec) {
    if (codec == null || codec.isEmpty) return false;
    const fragile = <String>{
      'hevc',
      'h265',
      'av1',
      'vp9',
      'ffv1',
      'mpeg2video',
      'mpeg2',
      'prores',
      'dnxhr',
      'dnxhd',
      'theora',
      'vc1',
    };
    return fragile.contains(codec.toLowerCase());
  }

  /// Re-encode to H.264 8-bit + AAC in MP4 for preview and upload.
  ///
  /// [maxVideoHeight]: if > 0, applies `scale=-2:H` (limits height, keeps aspect).
  static Future<File> transcodeToH264AacMp4({
    required File input,
    int maxVideoHeight = 1080,
  }) async {
    final tmp = await getTemporaryDirectory();
    final outPath =
        '${tmp.path}${Platform.pathSeparator}upload_h264_${DateTime.now().millisecondsSinceEpoch}.mp4';

    final args = <String>[
      '-y',
      '-i',
      input.path,
    ];
    if (maxVideoHeight > 0) {
      args.addAll(['-vf', 'scale=-2:$maxVideoHeight:flags=lanczos']);
    }
    args.addAll([
      '-map_metadata',
      '-1',
      '-map',
      '0:v:0',
      '-map',
      '0:a?',
      '-c:v',
      'libx264',
      '-profile:v',
      'baseline',
      '-level',
      '4.0',
      '-preset',
      'fast',
      '-crf',
      '23',
      '-pix_fmt',
      'yuv420p',
      '-c:a',
      'aac',
      '-b:a',
      '128k',
      '-ac',
      '2',
      '-movflags',
      '+faststart',
      outPath,
    ]);

    final session = await FFmpegKit.executeWithArguments(args);
    final returnCode = await session.getReturnCode();
    if (!ReturnCode.isSuccess(returnCode)) {
      final logs = await session.getAllLogsAsString();
      debugPrint('[VideoUploadTranscode] FFmpeg failed: $logs');
      throw Exception('Video conversion failed');
    }
    final out = File(outPath);
    if (!await out.exists() || await out.length() < 32) {
      throw Exception('Video conversion produced no output');
    }
    return out;
  }
}
