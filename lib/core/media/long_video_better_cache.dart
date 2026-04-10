import 'package:better_player/better_player.dart';

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
