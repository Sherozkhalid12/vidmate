import 'package:better_player/better_player.dart';

/// Buffering policy aligned with [long_video_widget_provider] inline feed player.
BetterPlayerBufferingConfiguration? longVideoStreamBuffering(String url) {
  final u = url.toLowerCase();
  if (u.contains('.m3u8') ||
      u.contains('.mpd') ||
      u.contains('/master') ||
      u.contains('playlist') ||
      u.contains('long-videos')) {
    return const BetterPlayerBufferingConfiguration(
      minBufferMs: 2000,
      maxBufferMs: 50000,
      bufferForPlaybackMs: 1000,
      bufferForPlaybackAfterRebufferMs: 2000,
    );
  }
  return null;
}

/// Disk cache for progressive MP4 in long-video inline player. HLS/DASH skips [SimpleCache]
/// to avoid global cache lock contention (same policy as reels).
BetterPlayerCacheConfiguration? longVideoNetworkCache(String url) {
  final u = url.toLowerCase();
  if (u.contains('.m3u8') ||
      u.contains('.mpd') ||
      u.contains('/master') ||
      u.contains('playlist')) {
    return null;
  }
  return BetterPlayerCacheConfiguration(
    useCache: true,
    maxCacheSize: 256 * 1024 * 1024,
    maxCacheFileSize: 80 * 1024 * 1024,
    preCacheSize: 8 * 1024 * 1024,
    key: url,
  );
}
