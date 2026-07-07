import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Releases feed-owned warm/standby controllers (not the engine active slot).
typedef FeedWarmRelease = Future<void> Function();

/// Coordinates warm controllers owned by reels and long-videos feeds so the
/// embedded player can drop all feed players before taking ownership.
class VideoFeedWarmPool extends StateNotifier<int> {
  VideoFeedWarmPool() : super(0);

  final Map<String, FeedWarmRelease> _handlers = {};

  void register(String key, FeedWarmRelease release) {
    _handlers[key] = release;
  }

  void unregister(String key) {
    _handlers.remove(key);
  }

  /// Drops every registered feed warm/standby controller.
  Future<void> releaseAllForEmbeddedPlayer() async {
    final handlers = _handlers.values.toList();
    for (final release in handlers) {
      await release();
    }
    state = state + 1;
  }
}

final videoFeedWarmPoolProvider =
    StateNotifierProvider<VideoFeedWarmPool, int>((ref) {
  ref.keepAlive();
  return VideoFeedWarmPool();
});
