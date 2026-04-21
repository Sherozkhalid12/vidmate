import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Reference-counted screen wake lock while any video is playing (global).
class VideoPlaybackWakelockNotifier extends StateNotifier<int> {
  VideoPlaybackWakelockNotifier() : super(0);

  Future<void> acquire() async {
    final next = state + 1;
    state = next;
    if (next == 1) {
      try {
        await WakelockPlus.enable();
      } catch (_) {}
    }
  }

  Future<void> release() async {
    final next = state > 0 ? state - 1 : 0;
    state = next;
    if (next == 0) {
      try {
        await WakelockPlus.disable();
      } catch (_) {}
    }
  }
}

final videoPlaybackWakelockProvider =
    StateNotifierProvider<VideoPlaybackWakelockNotifier, int>(
  (ref) => VideoPlaybackWakelockNotifier(),
);
