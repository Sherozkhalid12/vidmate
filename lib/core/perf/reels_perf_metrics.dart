import 'package:flutter/foundation.dart';

/// Debug / trace hooks for reel performance (Feature 1.12).
class ReelsPerfMetrics {
  ReelsPerfMetrics._();
  static final ReelsPerfMetrics instance = ReelsPerfMetrics._();

  int rebufferCountSession = 0;
  DateTime? screenMountTime;

  void onScreenMount() {
    screenMountTime = DateTime.now();
  }

  void onFirstReelVisible() {
    if (screenMountTime == null) return;
    final ms = DateTime.now().difference(screenMountTime!).inMilliseconds;
    if (kDebugMode) {
      debugPrint('[ReelsPerf] first_reel_visible_ms=$ms');
    }
    screenMountTime = null;
  }

  void recordRebuffer() {
    rebufferCountSession++;
    if (kDebugMode) {
      debugPrint('[ReelsPerf] video_rebuffer_count=$rebufferCountSession');
    }
  }

  void resetSession() {
    rebufferCountSession = 0;
    screenMountTime = null;
  }
}
