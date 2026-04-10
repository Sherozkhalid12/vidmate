import 'package:flutter/foundation.dart';

/// Debug traces for stories tray and viewer (Feature 5.8).
class StoriesPerfMetrics {
  StoriesPerfMetrics._();

  static int preloadHitCount = 0;
  static int preloadMissCount = 0;

  static void logTrayPaintMs(int ms) {
    if (kDebugMode) {
      debugPrint('[perf] stories_tray_paint_ms=$ms');
    }
  }

  static void logStoryFirstFrameMs(int ms) {
    if (kDebugMode) {
      debugPrint('[perf] story_first_frame_ms=$ms');
    }
  }

  static void recordPreloadHit() {
    preloadHitCount++;
    if (kDebugMode) {
      debugPrint('[perf] story_preload_hit total=$preloadHitCount miss=$preloadMissCount');
    }
  }

  static void recordPreloadMiss() {
    preloadMissCount++;
    if (kDebugMode) {
      debugPrint('[perf] story_preload_miss total=$preloadMissCount hit=$preloadHitCount');
    }
  }
}
