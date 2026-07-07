import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../models/reel_audio_clip.dart';
import '../models/reel_audio_timeline_state.dart';
import '../services/reel_audio_cache_service.dart';
import '../services/reel_audio_session_service.dart';
import 'reel_audio_timeline_provider.dart';
import 'reel_edit_playback_provider.dart';

/// Keeps [just_audio] players in sync with the video playhead during preview.
class ReelAudioPreviewNotifier extends StateNotifier<void> {
  ReelAudioPreviewNotifier(this.ref) : super(null) {
    unawaited(ReelAudioSessionService.instance.ensureMixablePlayback());

    ref.listen<bool>(
      reelEditPlaybackProvider.select((s) => s.isPlaying),
      _onPlayingChanged,
    );

    ref.listen<int>(
      reelEditPlaybackProvider.select((s) => s.positionMs),
      _onPositionChanged,
    );

    ref.listen<bool>(
      reelAudioTimelineProvider.select((s) => s.musicMuted),
      _onMusicMutedChanged,
    );

    ref.listen<bool>(
      reelAudioTimelineProvider.select((s) => s.isClipDragging),
      _onClipDraggingChanged,
    );

    ref.listen<ReelAudioTimelineState>(reelAudioTimelineProvider, _onTimeline);
  }

  final Ref ref;
  final Map<String, AudioPlayer> _players = {};
  final Map<String, String> _loadSignatures = {};

  Timer? _positionTimer;
  bool _syncInFlight = false;

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

  static String _clipLoadSignature(ReelAudioClip clip, String path) {
    return '$path|${clip.sourceTrimStartSec}|${clip.effectiveTrimEndSec}';
  }

  void _onPlayingChanged(bool? prev, bool next) {
    _positionTimer?.cancel();
    if (next) {
      unawaited(_startPlaybackLoop());
    } else {
      unawaited(_pauseAll());
    }
  }

  void _onPositionChanged(int? prev, int next) {
    if (prev == null) return;
    if (ref.read(reelAudioTimelineProvider).isClipDragging) return;

    final jumped = (next - prev).abs() > 250;
    final rewound = next < prev - 200;
    if (!jumped && !rewound) return;

    if (!ref.read(reelEditPlaybackProvider).isPlaying) return;
    unawaited(_resyncAllClips(forceSeek: true));
  }

  void _onClipDraggingChanged(bool? prev, bool next) {
    if (next) {
      unawaited(_pauseAll());
      return;
    }
    if (prev == true) {
      unawaited(_onClipDragEnded());
    }
  }

  Future<void> _onClipDragEnded() async {
    final timeline = ref.read(reelAudioTimelineProvider);
    for (final clip in timeline.clips) {
      await _ensurePlayerLoaded(clip);
    }
    if (ref.read(reelEditPlaybackProvider).isPlaying && !timeline.musicMuted) {
      await _resyncAllClips(forceSeek: true);
    }
  }

  Future<void> _startPlaybackLoop() async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!ref.read(reelEditPlaybackProvider).isPlaying) return;
    if (ref.read(reelAudioTimelineProvider).isClipDragging) return;
    await _resyncAllClips(forceSeek: true);
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => unawaited(_tickSync()),
    );
  }

  void _onMusicMutedChanged(bool? prev, bool next) {
    if (next) {
      unawaited(_pauseAll());
    } else if (ref.read(reelEditPlaybackProvider).isPlaying) {
      unawaited(_resyncAllClips(forceSeek: true));
    }
  }

  void _onTimeline(ReelAudioTimelineState? prev, ReelAudioTimelineState next) {
    if (next.isClipDragging) return;

    final prevIds = prev?.clips.map((c) => c.id).toSet() ?? {};
    final nextIds = next.clips.map((c) => c.id).toSet();

    for (final removed in prevIds.difference(nextIds)) {
      unawaited(_disposePlayer(removed));
    }

    var needsResync = false;
    for (final clip in next.clips) {
      if (!prevIds.contains(clip.id)) {
        unawaited(_ensurePlayerLoaded(clip));
        needsResync = true;
        continue;
      }
      final old = prev?.clips.where((c) => c.id == clip.id).firstOrNull;
      if (old == null) continue;

      if (old.volume != clip.volume) {
        unawaited(_applyVolume(clip));
      }
      if (old.sourceTrimStartSec != clip.sourceTrimStartSec ||
          old.sourceTrimEndSec != clip.sourceTrimEndSec) {
        unawaited(_ensurePlayerLoaded(clip, forceReload: true));
        needsResync = true;
      }
    }

    if (needsResync &&
        ref.read(reelEditPlaybackProvider).isPlaying &&
        !next.musicMuted) {
      unawaited(_resyncAllClips(forceSeek: true));
    }
  }

  Future<void> _tickSync() async {
    if (_syncInFlight) return;
    if (ref.read(reelAudioTimelineProvider).isClipDragging) return;
    _syncInFlight = true;
    try {
      final playback = ref.read(reelEditPlaybackProvider);
      if (!playback.isPlaying) return;

      final timeline = ref.read(reelAudioTimelineProvider);
      if (timeline.musicMuted) {
        await _pauseAll();
        return;
      }

      final relSec = playback.relativePositionSec;
      for (final clip in timeline.clips) {
        await _syncClip(clip, relSec);
      }
    } finally {
      _syncInFlight = false;
    }
  }

  Future<void> _resyncAllClips({bool forceSeek = false}) async {
    await ReelAudioSessionService.instance.ensureMixablePlayback();
    final timeline = ref.read(reelAudioTimelineProvider);
    if (timeline.musicMuted || timeline.clips.isEmpty) return;

    final relSec = ref.read(reelEditPlaybackProvider).relativePositionSec;
    for (final clip in timeline.clips) {
      await _ensurePlayerLoaded(clip);
      await _syncClip(clip, relSec, forceSeek: forceSeek);
    }
  }

  Future<void> _syncClip(
    ReelAudioClip clip,
    double relSec, {
    bool forceSeek = false,
  }) async {
    final inRange =
        relSec >= clip.timelineOffsetSec && relSec < clip.timelineEndSec;

    if (!inRange) {
      final player = _players[clip.id];
      if (player != null && player.playing) await player.pause();
      return;
    }

    final player = await _ensurePlayerLoaded(clip);
    if (player == null) return;

    final offsetInClip = relSec - clip.timelineOffsetSec;
    if (offsetInClip >= clip.clipDurationSec - 0.02) {
      if (player.playing) await player.pause();
      return;
    }

    final target = Duration(milliseconds: (offsetInClip * 1000).round());
    final driftMs = (player.position - target).inMilliseconds.abs();
    if (forceSeek || driftMs > 200) {
      await player.seek(target);
    }

    if (!player.playing) {
      await player.play();
    }
    await player.setVolume(clip.volume.clamp(0, 1));
  }

  Future<void> _applyVolume(ReelAudioClip clip) async {
    final player = _players[clip.id];
    if (player == null) return;
    await player.setVolume(clip.volume.clamp(0, 1));
  }

  Future<AudioPlayer?> _ensurePlayerLoaded(
    ReelAudioClip clip, {
    bool forceReload = false,
  }) async {
    final path = clip.localFilePath ??
        await ReelAudioCacheService.instance.ensureLocalFile(
          url: clip.sourceUrl,
          clipId: clip.id,
        );
    if (path == null) return null;

    final signature = _clipLoadSignature(clip, path);
    if (!forceReload &&
        _loadSignatures[clip.id] == signature &&
        _players[clip.id] != null) {
      return _players[clip.id];
    }

    await _disposePlayer(clip.id);
    final player = AudioPlayer();
    try {
      final child = path.startsWith('http')
          ? AudioSource.uri(
              Uri.parse(path),
              headers: _previewHeadersForUrl(path),
            )
          : AudioSource.file(path);

      final trimStartMs = (clip.sourceTrimStartSec * 1000).round();
      final trimEndMs = (clip.effectiveTrimEndSec * 1000).round();
      await player.setAudioSource(
        ClippingAudioSource(
          start: Duration(milliseconds: trimStartMs),
          end: Duration(milliseconds: trimEndMs),
          child: child,
        ),
      );
      _players[clip.id] = player;
      _loadSignatures[clip.id] = signature;
      return player;
    } catch (e) {
      debugPrint('Reel audio preview load error: $e');
      await player.dispose();
      return null;
    }
  }

  Future<void> _pauseAll() async {
    for (final player in _players.values) {
      if (player.playing) await player.pause();
    }
  }

  Future<void> _disposePlayer(String clipId) async {
    final player = _players.remove(clipId);
    _loadSignatures.remove(clipId);
    if (player != null) {
      await player.dispose();
    }
  }

  @override
  void dispose() {
    _positionTimer?.cancel();
    for (final id in _players.keys.toList()) {
      unawaited(_disposePlayer(id));
    }
    super.dispose();
  }
}

final reelAudioPreviewProvider =
    StateNotifierProvider.autoDispose<ReelAudioPreviewNotifier, void>(
  ReelAudioPreviewNotifier.new,
);
