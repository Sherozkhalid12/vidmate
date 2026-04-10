import 'package:flutter/foundation.dart';

/// Debug traces for home feed (Feature 2.11).
class FeedPerfMetrics {
  FeedPerfMetrics._();

  static int loadPostsSkipCount = 0;

  static void logFeedHydrateMs(int ms) {
    if (kDebugMode) {
      debugPrint('[perf] feed_hydrate_ms=$ms');
    }
  }

  static void logFirstSkeletonMs(int ms) {
    if (kDebugMode) {
      debugPrint('[perf] feed_first_skeleton_ms=$ms');
    }
  }

  static void logLoadPostsSkipped() {
    loadPostsSkipCount++;
    if (kDebugMode) {
      debugPrint('[perf] loadPosts skipped (tab switch / cache hit) total=$loadPostsSkipCount');
    }
  }
}
