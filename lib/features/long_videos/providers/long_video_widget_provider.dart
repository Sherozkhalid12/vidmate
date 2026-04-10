import 'dart:async';

import 'package:better_player/better_player.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/media/long_video_better_cache.dart';
import '../../../core/perf/long_video_perf_metrics.dart';

/// Per-widget Better Player state for long videos (Feature 3.4 / 3.8).
class LongVideoWidgetState {
  final BetterPlayerController? controller;
  final bool isPlaying;
  final bool isInitialized;
  final Duration duration;
  final Duration position;
  final bool showControls;
  final bool isSeeking;
  final String widgetId;
  final String videoUrl;

  LongVideoWidgetState({
    this.controller,
    this.isPlaying = false,
    this.isInitialized = false,
    this.duration = Duration.zero,
    this.position = Duration.zero,
    this.showControls = true,
    this.isSeeking = false,
    required this.widgetId,
    required this.videoUrl,
  });

  LongVideoWidgetState copyWith({
    BetterPlayerController? controller,
    bool? isPlaying,
    bool? isInitialized,
    Duration? duration,
    Duration? position,
    bool? showControls,
    bool? isSeeking,
  }) {
    return LongVideoWidgetState(
      controller: controller ?? this.controller,
      isPlaying: isPlaying ?? this.isPlaying,
      isInitialized: isInitialized ?? this.isInitialized,
      duration: duration ?? this.duration,
      position: position ?? this.position,
      showControls: showControls ?? this.showControls,
      isSeeking: isSeeking ?? this.isSeeking,
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
    return LongVideoWidgetNotifier(key.widgetId, key.videoUrl);
  },
);

class LongVideoWidgetNotifier extends StateNotifier<LongVideoWidgetState> {
  LongVideoWidgetNotifier(this.widgetId, this.videoUrl)
      : super(LongVideoWidgetState(widgetId: widgetId, videoUrl: videoUrl));

  final String widgetId;
  final String videoUrl;
  bool _isInitializing = false;
  Stopwatch? _firstFrameWatch;
  bool _loggedFirstFrame = false;

  void _onBetterEvent(BetterPlayerEvent event) {
    if (!mounted) return;
    switch (event.betterPlayerEventType) {
      case BetterPlayerEventType.bufferingStart:
        LongVideoPerfMetrics.logLongVideoRebuffer();
        break;
      case BetterPlayerEventType.bufferingEnd:
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
      state = state.copyWith(
        position: value.position,
        isPlaying: value.isPlaying,
        duration: value.duration,
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
      await c.play();
      if (mounted) {
        state = state.copyWith(isPlaying: true);
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

  @override
  void dispose() {
    final c = state.controller;
    if (c != null) {
      try {
        c.removeEventsListener(_onBetterEvent);
        c.videoPlayerController?.removeListener(_videoListener);
        c.dispose(forceDispose: true);
      } catch (_) {}
    }
    super.dispose();
  }
}
