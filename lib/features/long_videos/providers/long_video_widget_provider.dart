import 'dart:async';

import 'package:better_player/better_player.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/media/long_video_better_cache.dart';
import '../../../core/perf/long_video_perf_metrics.dart';
import '../../../core/providers/video_playback_wakelock_provider.dart';
import 'long_video_saved_position_provider.dart';

/// Per-widget Better Player state for long videos (Feature 3.4 / 3.8).
class LongVideoWidgetState {
  final BetterPlayerController? controller;
  final bool isPlaying;
  final bool isInitialized;
  final bool isBuffering;
  final Duration duration;
  final Duration position;
  final bool showControls;
  final bool isSeeking;
  final bool isMuted;
  final String widgetId;
  final String videoUrl;

  LongVideoWidgetState({
    this.controller,
    this.isPlaying = false,
    this.isInitialized = false,
    this.isBuffering = false,
    this.duration = Duration.zero,
    this.position = Duration.zero,
    this.showControls = true,
    this.isSeeking = false,
    this.isMuted = false,
    required this.widgetId,
    required this.videoUrl,
  });

  LongVideoWidgetState copyWith({
    BetterPlayerController? controller,
    bool? isPlaying,
    bool? isInitialized,
    bool? isBuffering,
    Duration? duration,
    Duration? position,
    bool? showControls,
    bool? isSeeking,
    bool? isMuted,
  }) {
    return LongVideoWidgetState(
      controller: controller ?? this.controller,
      isPlaying: isPlaying ?? this.isPlaying,
      isInitialized: isInitialized ?? this.isInitialized,
      isBuffering: isBuffering ?? this.isBuffering,
      duration: duration ?? this.duration,
      position: position ?? this.position,
      showControls: showControls ?? this.showControls,
      isSeeking: isSeeking ?? this.isSeeking,
      isMuted: isMuted ?? this.isMuted,
      widgetId: widgetId,
      videoUrl: videoUrl,
    );
  }
}

class VideoWidgetKey {
  final String widgetId;
  final String videoUrl;

  const VideoWidgetKey(this.widgetId, this.videoUrl);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is VideoWidgetKey &&
              runtimeType == other.runtimeType &&
              widgetId == other.widgetId &&
              videoUrl == other.videoUrl;

  @override
  int get hashCode => widgetId.hashCode ^ videoUrl.hashCode;
}

final longVideoWidgetProvider = StateNotifierProvider.autoDispose
    .family<LongVideoWidgetNotifier, LongVideoWidgetState, VideoWidgetKey>(
      (ref, key) {
    return LongVideoWidgetNotifier(ref, key.widgetId, key.videoUrl);
  },
);

class LongVideoWidgetNotifier extends StateNotifier<LongVideoWidgetState> {
  LongVideoWidgetNotifier(this._ref, this.widgetId, this.videoUrl)
      : super(LongVideoWidgetState(widgetId: widgetId, videoUrl: videoUrl));

  final Ref _ref;
  final String widgetId;
  final String videoUrl;
  bool _isInitializing = false;
  bool _isReleasing = false;
  bool _embeddedOpen = false;
  Stopwatch? _firstFrameWatch;
  bool _loggedFirstFrame = false;
  DateTime? _lastPositionEmitWhilePlaying;

  void _onBetterEvent(BetterPlayerEvent event) {
    if (!mounted) return;
    switch (event.betterPlayerEventType) {
      case BetterPlayerEventType.bufferingStart:
        LongVideoPerfMetrics.logLongVideoRebuffer();
        state = state.copyWith(isBuffering: true);
        break;
      case BetterPlayerEventType.bufferingEnd:
        state = state.copyWith(isBuffering: false);
        break;
      case BetterPlayerEventType.play:
        if (!_loggedFirstFrame && _firstFrameWatch != null) {
          _loggedFirstFrame = true;
          LongVideoPerfMetrics.logLongVideoFirstFrameMs(
            _firstFrameWatch!.elapsedMilliseconds,
          );
          _firstFrameWatch = null;
        }
        break;
      default:
        break;
    }
  }

  Future<void> _initializePlayer() async {
    if (_isInitializing || state.isInitialized) return;
    _isInitializing = true;

    try {
      final better = BetterPlayerController(
        BetterPlayerConfiguration(
          aspectRatio: 16 / 9,
          fit: BoxFit.cover,
          autoPlay: false,
          autoDispose: false,
          looping: false,
          handleLifecycle: false,
          expandToFill: true,
          controlsConfiguration: const BetterPlayerControlsConfiguration(
            showControls: false,
            enableProgressBar: false,
            enableProgressText: false,
            enableFullscreen: false,
            enableMute: false,
            enablePlayPause: false,
            enableSkips: false,
            enablePlaybackSpeed: false,
            enableSubtitles: false,
            enableOverflowMenu: false,
          ),
        ),
      );
      better.addEventsListener(_onBetterEvent);

      await better.setupDataSource(
        BetterPlayerDataSource.network(
          videoUrl,
          cacheConfiguration: longVideoNetworkCache(videoUrl),
          bufferingConfiguration: const BetterPlayerBufferingConfiguration(
            minBufferMs: 2000,
            maxBufferMs: 50000,
            bufferForPlaybackMs: 1000,
            bufferForPlaybackAfterRebufferMs: 2000,
          ),
        ),
      );

      if (!mounted) {
        better.dispose(forceDispose: true);
        return;
      }

      final vpc = better.videoPlayerController;
      vpc?.addListener(_videoListener);

      state = state.copyWith(
        controller: better,
        isInitialized: true,
        duration: vpc?.value.duration ?? Duration.zero,
        isBuffering: vpc?.value.isBuffering ?? false,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[LongVideoWidget] init failed: $e');
      }
      if (mounted) {
        state = state.copyWith(isInitialized: false);
      }
    } finally {
      _isInitializing = false;
    }
  }

  void _videoListener() {
    if (!mounted || state.controller == null) return;
    final vpc = state.controller!.videoPlayerController;
    if (vpc == null) return;
    try {
      final value = vpc.value;
      final wasPlaying = state.isPlaying;
      final nowPlaying = value.isPlaying;
      if (wasPlaying != nowPlaying) {
        if (nowPlaying) {
          unawaited(_ref.read(videoPlaybackWakelockProvider.notifier).acquire());
        } else {
          unawaited(_ref.read(videoPlaybackWakelockProvider.notifier).release());
        }
      }
      var pos = value.position;
      if (value.isPlaying) {
        final now = DateTime.now();
        final last = _lastPositionEmitWhilePlaying;
        if (last != null &&
            now.difference(last) < const Duration(milliseconds: 500)) {
          pos = state.position;
        } else {
          _lastPositionEmitWhilePlaying = now;
        }
      } else {
        _lastPositionEmitWhilePlaying = null;
      }
      state = state.copyWith(
        position: pos,
        isPlaying: nowPlaying,
        duration: value.duration,
        isBuffering: value.isBuffering,
      );
    } catch (_) {}
  }

  Future<void> play() async {
    if (!mounted) return;
    if (!state.isInitialized) {
      await _initializePlayer();
      if (!mounted || !state.isInitialized || state.controller == null) return;
    }

    final c = state.controller;
    if (c == null) return;

    _firstFrameWatch = Stopwatch()..start();
    _loggedFirstFrame = false;

    try {
      await c.setVolume(1.0);
      if (mounted) {
        state = state.copyWith(isMuted: false);
      }
      await c.play();
      if (mounted) {
        state = state.copyWith(isPlaying: true);
      }
    } catch (_) {}
  }

  /// Prepare decoder surface without starting playback (Section 3 / 5).
  /// If already initialized, does nothing (scroll pool must not reset playback).
  Future<void> warmUp() async {
    if (_embeddedOpen) return;
    if (!mounted) return;
    if (state.isInitialized) return;
    await _initializePlayer();
    if (!mounted || state.controller == null) return;
    final c = state.controller!;
    try {
      await c.pause();
      await c.seekTo(Duration.zero);
      if (mounted) {
        state = state.copyWith(isPlaying: false, position: Duration.zero);
      }
    } catch (_) {}
  }

  /// Transfers ownership of the inline [BetterPlayerController] to [VideoPlayerScreen]
  /// without disposing. Returns null if there is no ready controller.
  BetterPlayerController? detachControllerForRouteHandoff() {
    if (_isReleasing || _isInitializing) return null;
    final c = state.controller;
    if (c == null || !state.isInitialized) return null;
    try {
      c.removeEventsListener(_onBetterEvent);
      c.videoPlayerController?.removeListener(_videoListener);
    } catch (_) {}
    state = LongVideoWidgetState(widgetId: widgetId, videoUrl: videoUrl);
    return c;
  }

  /// Saves position, disposes BetterPlayer (Section 5.2). Caller must skip dominant tile.
  Future<void> release() async {
    if (_isReleasing || _isInitializing) return;
    final c = state.controller;
    if (c == null || !state.isInitialized) return;
    _isReleasing = true;
    try {
      final pos = state.position;
      _ref.read(longVideoSavedPositionProvider.notifier).record(widgetId, pos);
      c.removeEventsListener(_onBetterEvent);
      c.videoPlayerController?.removeListener(_videoListener);
      await c.pause();
      c.dispose(forceDispose: true);
      if (mounted) {
        state = LongVideoWidgetState(widgetId: widgetId, videoUrl: videoUrl);
      }
    } catch (_) {
      if (mounted) {
        state = LongVideoWidgetState(widgetId: widgetId, videoUrl: videoUrl);
      }
    } finally {
      _isReleasing = false;
      _isInitializing = false;
    }
  }

  /// Muted autoplay for feed dominant tile.
  Future<void> autoplay() async {
    if (_embeddedOpen) return;
    if (!mounted) return;
    if (!state.isInitialized) {
      await warmUp();
      if (!mounted || state.controller == null) return;
    }
    final c = state.controller!;
    try {
      await c.seekTo(Duration.zero);
      if (mounted) {
        state = state.copyWith(position: Duration.zero);
      }
    } catch (_) {}
    _firstFrameWatch = Stopwatch()..start();
    _loggedFirstFrame = false;
    try {
      await c.setVolume(0.0);
      if (mounted) {
        state = state.copyWith(isMuted: true);
      }
      await c.play();
      if (mounted) {
        state = state.copyWith(isPlaying: true);
      }
    } catch (_) {}
  }

  /// Pause only (used when tile loses dominance).
  Future<void> autoPause() async {
    if (_embeddedOpen) return;
    await pause();
  }

  /// Prevents inline warm-up/autoplay/pause churn while embedded player owns focus.
  void setEmbeddedOpen(bool value) {
    _embeddedOpen = value;
  }

  Future<void> toggleMute() async {
    if (state.controller == null || !state.isInitialized || !mounted) return;
    final c = state.controller!;
    final nextMuted = !state.isMuted;
    try {
      await c.setVolume(nextMuted ? 0.0 : 1.0);
      if (mounted) {
        state = state.copyWith(isMuted: nextMuted);
      }
    } catch (_) {}
  }

  Future<void> pause() async {
    if (state.controller == null || !state.isInitialized || !mounted) return;
    try {
      await state.controller!.pause();
      if (mounted) {
        state = state.copyWith(isPlaying: false);
      }
    } catch (_) {}
  }

  Future<void> togglePlayPause() async {
    if (state.isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> seekForward() async {
    if (state.controller == null || !state.isInitialized || !mounted) return;
    if (mounted) {
      state = state.copyWith(isSeeking: true);
    }
    try {
      final newPosition = state.position + const Duration(seconds: 10);
      final target =
      newPosition > state.duration ? state.duration : newPosition;
      await state.controller!.seekTo(target);
      if (mounted) {
        state = state.copyWith(isSeeking: false);
      }
    } catch (_) {
      if (mounted) {
        state = state.copyWith(isSeeking: false);
      }
    }
  }

  Future<void> seekBackward() async {
    if (state.controller == null || !state.isInitialized || !mounted) return;
    if (mounted) {
      state = state.copyWith(isSeeking: true);
    }
    try {
      final newPosition = state.position - const Duration(seconds: 10);
      final target =
      newPosition < Duration.zero ? Duration.zero : newPosition;
      await state.controller!.seekTo(target);
      if (mounted) {
        state = state.copyWith(isSeeking: false);
      }
    } catch (_) {
      if (mounted) {
        state = state.copyWith(isSeeking: false);
      }
    }
  }

  void setControlsVisibility(bool visible) {
    if (mounted) {
      state = state.copyWith(showControls: visible);
    }
  }

  /// Re-attach the same [BetterPlayerController] after [VideoPlayerScreen] pops
  /// (feed handoff round-trip).
  void acceptReturnedControllerSync(
    BetterPlayerController c, {
    bool wasPlaying = false,
  }) {
    if (!mounted) return;
    if (_isReleasing) return;
    _isInitializing = false;
    try {
      c.removeEventsListener(_onBetterEvent);
      c.videoPlayerController?.removeListener(_videoListener);
    } catch (_) {}
    c.addEventsListener(_onBetterEvent);
    c.videoPlayerController?.addListener(_videoListener);

    final vpc = c.videoPlayerController;
    final dur = vpc?.value.duration ?? Duration.zero;
    final pos = vpc?.value.position ?? Duration.zero;
    final buffering = vpc?.value.isBuffering ?? false;

    state = state.copyWith(
      controller: c,
      isInitialized: true,
      duration: dur,
      position: pos,
      isBuffering: buffering,
      isPlaying: vpc?.value.isPlaying ?? false,
      isMuted: true,
    );

    unawaited(_afterInlineReturnFromFullPlayer(c));
  }

  Future<void> _afterInlineReturnFromFullPlayer(BetterPlayerController c) async {
    try {
      await c.setVolume(0.0);
    } catch (_) {}
    if (!mounted) return;
    try {
      // Feed: never resume inline playback immediately after embedded closes.
      // Stay paused at 0:00; [LongVideosScreen] autoplay will start after dwell.
      await c.pause();
      await c.seekTo(Duration.zero);
      if (mounted) {
        state = state.copyWith(isPlaying: false, position: Duration.zero);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    final c = state.controller;
    if (c != null) {
      try {
        if (state.isInitialized) {
          _ref
              .read(longVideoSavedPositionProvider.notifier)
              .record(widgetId, state.position);
        }
        if (state.isPlaying) {
          unawaited(
            _ref.read(videoPlaybackWakelockProvider.notifier).release(),
          );
        }
        c.removeEventsListener(_onBetterEvent);
        c.videoPlayerController?.removeListener(_videoListener);
        c.dispose(forceDispose: true);
      } catch (_) {}
    }
    super.dispose();
  }
}
