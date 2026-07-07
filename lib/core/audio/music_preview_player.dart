import 'dart:async';

import 'package:just_audio/just_audio.dart';

/// Plays a remote preview URL (e.g. Deezer `previewUrl`) with a hard cap so
/// UX matches licensed 30s previews in create flow and music picker.
///
/// Uses [just_audio] + ExoPlayer on Android with a browser-like [User-Agent],
/// because plain `MediaPlayer` (used by `audioplayers`) often fails on
/// tokenized CDN URLs such as `cdnt-preview.dzcdn.net` (`MEDIA_ERROR_SYSTEM`).
class MusicPreviewPlayer {
  MusicPreviewPlayer({
    this.maxPreviewMs = 30000,
    this.onIsPlayingChanged,
    this.onProgressChanged,
  });

  /// Deezer / similar CDNs commonly reject generic mobile player agents.
  static const String _previewUserAgent =
      'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  /// Deezer preview hosts return **403** without site context headers.
  static Map<String, String>? _previewHeadersForUrl(String url) {
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

  final int maxPreviewMs;
  final void Function(bool isPlaying)? onIsPlayingChanged;
  final void Function(double progress)? onProgressChanged;

  void _notify() => onIsPlayingChanged?.call(_isPlaying);

  AudioPlayer? _player;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<ProcessingState>? _processingSub;
  String? _currentUrl;
  bool _isPlaying = false;
  int _loadGeneration = 0;
  bool _listenersAttached = false;
  int _lastProgressEmitMs = 0;

  bool get isPlaying => _isPlaying;
  String? get currentUrl => _currentUrl;

  /// Create the native player early so the first tap only loads audio.
  void warmUp() {
    _ensurePlayer();
  }

  Future<void> dispose() async {
    await stop();
  }

  Future<void> stop() async {
    _loadGeneration++;
    await _cancelSubs();
    _listenersAttached = false;
    try {
      await _player?.stop();
      await _player?.dispose();
    } catch (_) {}
    _player = null;
    _currentUrl = null;
    _isPlaying = false;
    onProgressChanged?.call(0);
    _notify();
  }

  Future<void> _cancelSubs() async {
    await _posSub?.cancel();
    _posSub = null;
    await _playingSub?.cancel();
    _playingSub = null;
    await _processingSub?.cancel();
    _processingSub = null;
  }

  void _ensurePlayer() {
    if (_player != null) return;
    final player = AudioPlayer(
      userAgent: _previewUserAgent,
      useProxyForRequestHeaders: false,
    );
    _player = player;
    _attachListenersOnce(player);
  }

  void _attachListenersOnce(AudioPlayer player) {
    if (_listenersAttached) return;
    _listenersAttached = true;
    final active = player;

    _posSub = player.positionStream.listen((pos) {
      if (_player != active) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      final progress =
          (pos.inMilliseconds / maxPreviewMs).clamp(0.0, 1.0);
      final shouldEmit = progress >= 1.0 ||
          now - _lastProgressEmitMs >= 120 ||
          _lastProgressEmitMs == 0;
      if (shouldEmit) {
        _lastProgressEmitMs = now;
        onProgressChanged?.call(progress);
      }
      if (pos.inMilliseconds >= maxPreviewMs) {
        unawaited(_enforceMaxPreview());
      }
    });

    _playingSub = player.playingStream.listen((playing) {
      if (_player != active) return;
      _isPlaying = playing;
      _notify();
    });

    _processingSub = player.processingStateStream.listen((state) {
      if (_player != active) return;
      if (state == ProcessingState.completed) {
        _isPlaying = false;
        onProgressChanged?.call(0);
        _notify();
      }
    });
  }

  Future<void> _enforceMaxPreview() async {
    if (_player == null) return;
    try {
      await _player!.pause();
      await _player!.seek(Duration.zero);
    } catch (_) {}
    _isPlaying = false;
    onProgressChanged?.call(0);
    _notify();
  }

  /// If [url] is already loaded and playing, pause. If paused, resume from
  /// current position. Otherwise load and play [url] from the start.
  Future<void> toggle(String url) async {
    if (url.isEmpty) return;
    _ensurePlayer();
    final player = _player!;

    if (_currentUrl == url) {
      try {
        if (player.playing) {
          await player.pause();
        } else {
          await player.play();
        }
      } catch (_) {
        _isPlaying = false;
        _notify();
      }
      return;
    }

    final op = ++_loadGeneration;
    _currentUrl = url;
    _isPlaying = false;
    _lastProgressEmitMs = 0;
    onProgressChanged?.call(0);
    _notify();

    try {
      if (player.playing) {
        unawaited(player.pause());
      }
      await player.setUrl(
        url,
        headers: _previewHeadersForUrl(url),
        preload: true,
      );
      if (op != _loadGeneration) return;
      await player.seek(Duration.zero);
      if (op != _loadGeneration) return;
      await player.play();
      if (op != _loadGeneration) return;
      _isPlaying = player.playing;
      _notify();
    } catch (_) {
      if (op != _loadGeneration) return;
      _currentUrl = null;
      _isPlaying = false;
      _notify();
    }
  }

  /// Stops any current sound, then plays [url] from the beginning (feed/story
  /// sticker: one continuous run, capped at [maxPreviewMs]).
  Future<void> playPreview(String url) async {
    if (url.isEmpty) return;
    await stop();
    _ensurePlayer();
    await _loadAndPlay(url);
  }

  Future<void> _loadAndPlay(String url) async {
    final op = ++_loadGeneration;
    _currentUrl = url;
    final player = _player!;
    try {
      await player.setUrl(url, headers: _previewHeadersForUrl(url), preload: true);
      if (op != _loadGeneration) return;
      _attachListenersOnce(player);
      await player.play();
      if (op != _loadGeneration) return;
      _isPlaying = player.playing;
      _notify();
    } catch (_) {
      if (op != _loadGeneration) return;
      await stop();
    }
  }
}
