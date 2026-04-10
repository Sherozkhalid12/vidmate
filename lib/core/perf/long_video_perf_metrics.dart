import 'package:flutter/foundation.dart';

/// Traces for long videos tab (Feature 3.9).
class LongVideoPerfMetrics {
  LongVideoPerfMetrics._();

  static int loadVideosSkipCount = 0;

  static void logLongVideoHydrateMs(int ms) {
    if (kDebugMode) {
      debugPrint('[perf] longvideo_hydrate_ms=$ms');
    }
  }

  static void logLoadVideosSkipped() {
    loadVideosSkipCount++;
    if (kDebugMode) {
      debugPrint('[perf] loadVideos skipped (cache hit / in flight) total=$loadVideosSkipCount');
    }
  }

  /// Player init → first decoded frame (inline Better Player).
  static void logLongVideoFirstFrameMs(int ms) {
    if (kDebugMode) {
      debugPrint('[perf] longvideo_first_frame_ms=$ms');
    }
  }

  static void logLongVideoRebuffer() {
    if (kDebugMode) {
      debugPrint('[perf] longvideo_rebuffer_count++');
    }
  }
}
