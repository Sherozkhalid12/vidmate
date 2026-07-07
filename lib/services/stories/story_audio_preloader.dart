import 'dart:async';

import 'package:just_audio/just_audio.dart';

import '../../core/models/story_model.dart';

class _CachedPlayer {
  _CachedPlayer({
    required this.player,
    required this.url,
  }) : lastUsed = DateTime.now();

  final AudioPlayer player;
  final String url;
  DateTime lastUsed;
  bool isReady = false;
}

class StoryAudioPreloader {
  StoryAudioPreloader._();
  static final instance = StoryAudioPreloader._();

  static const String _previewUserAgent =
      'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  static Map<String, String>? _headersForUrl(String url) {
    final lower = url.toLowerCase();
    if (!lower.contains('dzcdn.net') && !lower.contains('deezer.com')) {
      return null;
    }
    return const {
      'Referer': 'https://www.deezer.com/',
      'Origin': 'https://www.deezer.com',
      'Accept': 'audio/mpeg, audio/*;q=0.9, */*;q=0.8',
    };
  }

  final Map<String, _CachedPlayer> _cache = {};
  final Set<String> _warming = {};
  static const int _maxCacheSize = 20;
  bool _disposingAll = false;

  Future<void> prewarmAll(Map<String, List<StoryModel>> userStoriesMap) async {
    final urls = <String>{};
    for (final stories in userStoriesMap.values) {
      for (final story in stories) {
        final url = story.storyMusicPlaybackUrl.trim();
        if (url.isNotEmpty) urls.add(url);
      }
    }
    await Future.wait(urls.map(_ensureWarmed));
  }

  Future<void> prewarmTray(Map<String, List<StoryModel>> userStoriesMap) async {
    await prewarmAll(userStoriesMap);
  }

  Future<void> prewarmSingle(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    await _ensureWarmed(trimmed);
  }

  Future<AudioPlayer?> getPlayer(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;
    await _ensureWarmed(trimmed);
    final cached = _cache[trimmed];
    if (cached == null || !cached.isReady) return null;
    cached.lastUsed = DateTime.now();
    try {
      await cached.player.seek(Duration.zero);
    } catch (_) {}
    return cached.player;
  }

  Future<void> stopAndRewind(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    final cached = _cache[trimmed];
    if (cached == null) return;
    try {
      await cached.player.stop();
      await cached.player.seek(Duration.zero);
      cached.lastUsed = DateTime.now();
    } catch (_) {}
  }

  Future<void> pauseAll() async {
    for (final cached in _cache.values) {
      try {
        if (cached.player.playing) await cached.player.pause();
      } catch (_) {}
    }
  }

  Future<void> resumePlayer(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    final cached = _cache[trimmed];
    if (cached == null || !cached.isReady) return;
    try {
      await cached.player.play();
      cached.lastUsed = DateTime.now();
    } catch (_) {}
  }

  Future<void> _ensureWarmed(String url) async {
    final cached = _cache[url];
    if (cached != null) return;
    if (_warming.contains(url)) return;

    _warming.add(url);
    try {
      _evictIfNeeded();

      final player = AudioPlayer(
        userAgent: _previewUserAgent,
        useProxyForRequestHeaders: false,
      );
      final entry = _CachedPlayer(player: player, url: url);
      _cache[url] = entry;

      await player.setUrl(url, headers: _headersForUrl(url));
      await player.setVolume(0);
      await player.setLoopMode(LoopMode.one);
      await player.seek(Duration.zero);

      if (_disposingAll) {
        await player.dispose();
        _cache.remove(url);
        return;
      }

      entry.isReady = true;
      entry.lastUsed = DateTime.now();
    } catch (_) {
      final failed = _cache.remove(url);
      if (failed != null) {
        try {
          await failed.player.dispose();
        } catch (_) {}
      }
    } finally {
      _warming.remove(url);
    }
  }

  void _evictIfNeeded() {
    if (_cache.length < _maxCacheSize) return;

    String? oldestUrl;
    _CachedPlayer? oldest;
    for (final entry in _cache.entries) {
      final cached = entry.value;
      if (cached.player.playing) continue;
      if (oldest == null || cached.lastUsed.isBefore(oldest.lastUsed)) {
        oldest = cached;
        oldestUrl = entry.key;
      }
    }

    if (oldestUrl != null && oldest != null) {
      _cache.remove(oldestUrl);
      unawaited(oldest.player.dispose());
    }
  }

  Future<void> disposeAll() async {
    _disposingAll = true;
    try {
      for (final cached in _cache.values) {
        try {
          await cached.player.stop();
        } catch (_) {}
        try {
          await cached.player.dispose();
        } catch (_) {}
      }
      _cache.clear();
      _warming.clear();
    } finally {
      _disposingAll = false;
    }
  }
}
