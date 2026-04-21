import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Last known inline playback position per long-video post id (Section 5.2).
class LongVideoSavedPositionNotifier extends StateNotifier<Map<String, int>> {
  LongVideoSavedPositionNotifier() : super(const {});

  void record(String videoId, Duration position) {
    if (videoId.isEmpty) return;
    state = {...state, videoId: position.inMilliseconds};
  }

  Duration? getFor(String videoId) {
    final ms = state[videoId];
    if (ms == null) return null;
    return Duration(milliseconds: ms);
  }

  void remove(String videoId) {
    if (!state.containsKey(videoId)) return;
    final next = Map<String, int>.from(state)..remove(videoId);
    state = next;
  }
}

final longVideoSavedPositionProvider =
    StateNotifierProvider<LongVideoSavedPositionNotifier, Map<String, int>>(
  (ref) => LongVideoSavedPositionNotifier(),
);
