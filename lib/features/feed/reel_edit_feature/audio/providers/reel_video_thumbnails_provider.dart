import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

@immutable
class ReelVideoThumbnailsRequest {
  const ReelVideoThumbnailsRequest({
    required this.videoPath,
    required this.durationSec,
  });

  final String videoPath;
  final double durationSec;

  @override
  bool operator ==(Object other) =>
      other is ReelVideoThumbnailsRequest &&
      other.videoPath == videoPath &&
      other.durationSec == durationSec;

  @override
  int get hashCode => Object.hash(videoPath, durationSec);
}

@immutable
class ReelVideoThumbnailFrame {
  const ReelVideoThumbnailFrame({required this.timeMs, required this.bytes});

  final int timeMs;
  final Uint8List bytes;
}

final reelVideoThumbnailsProvider = FutureProvider.autoDispose
    .family<List<ReelVideoThumbnailFrame>, ReelVideoThumbnailsRequest>(
  (ref, request) async {
    if (request.videoPath.isEmpty || request.durationSec <= 0) {
      return const [];
    }

    final count = (request.durationSec / 1.5).ceil().clamp(4, 24);
    final frames = <ReelVideoThumbnailFrame>[];

    for (var i = 0; i < count; i++) {
      final timeMs =
          (i * request.durationSec * 1000 / count).round().clamp(0, 999999);
      try {
        final bytes = await VideoThumbnail.thumbnailData(
          video: request.videoPath,
          imageFormat: ImageFormat.JPEG,
          timeMs: timeMs,
          quality: 55,
          maxWidth: 160,
        );
        if (bytes != null && bytes.isNotEmpty) {
          frames.add(ReelVideoThumbnailFrame(timeMs: timeMs, bytes: bytes));
        }
      } catch (e) {
        debugPrint('Reel thumbnail error @${timeMs}ms: $e');
      }
    }
    return frames;
  },
);
