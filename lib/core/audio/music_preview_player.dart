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

  void _notify() => onIsPlayingChanged?.call(_isPlaying);

  AudioPlayer? _player;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<ProcessingState>? _processingSub;
  String? _currentUrl;
  bool _isPlaying = false;

  bool get isPlaying => _isPlaying;
  String? get currentUrl => _currentUrl;

  Future<void> dispose() async {
    await stop();
  }

  Future<void> stop() async {
    await _cancelSubs();
    await _player?.stop();
    await _player?.dispose();
    _player = null;
    _currentUrl = null;
    _isPlaying = false;
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

  Future<void> _enforceMaxPreview() async {
    if (_player == null) return;
    try {
      await _player!.pause();
      await _player!.seek(Duration.zero);
    } catch (_) {}
    _isPlaying = false;
    _notify();
  }

  Future<void> _attachListeners(AudioPlayer player) async {
    await _cancelSubs();
    final active = player;
    _posSub = player.positionStream.listen((pos) {
      if (_player != active) return;
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
        _notify();
      }
    });
  }

  /// If [url] is already loaded and playing, pause. If paused, resume from
  /// current position. Otherwise load and play [url] from the start.
  Future<void> toggle(String url) async {
    if (url.isEmpty) return;
    if (_currentUrl == url && _player != null) {
      final p = _player!;
      try {
        if (p.playing) {
          await p.pause();
        } else {
          await p.play();
        }
      } catch (_) {
        _isPlaying = false;
        _notify();
      }
      return;
    }
    await stop();
    await _loadAndPlay(url);
  }

  /// Stops any current sound, then plays [url] from the beginning (feed/story
  /// sticker: one continuous run, capped at [maxPreviewMs]).
  Future<void> playPreview(String url) async {
    if (url.isEmpty) return;
    await stop();
    await _loadAndPlay(url);
  }

  Future<void> _loadAndPlay(String url) async {
    _currentUrl = url;
    final player = AudioPlayer(
      userAgent: _previewUserAgent,
      useProxyForRequestHeaders: false,
    );
    _player = player;
    try {
      await player.setUrl(url, headers: _previewHeadersForUrl(url));
      await _attachListeners(player);
      await player.play();
      _isPlaying = player.playing;
      _notify();
    } catch (_) {
      await stop();
    }
  }
}
