import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:better_player/better_player.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../media/adaptive_track_selection.dart';
import '../media/long_video_better_cache.dart';
import 'long_video_cold_start_intent_provider.dart';
import 'long_video_embedded_handoff_provider.dart';
import 'video_playback_wakelock_provider.dart';
import '../../features/long_videos/providers/long_video_widget_provider.dart';

/// Video player state (HLS/network via BetterPlayer).
class VideoPlayerState {
  final BetterPlayerController? controller;
  final bool isPlaying;
  final bool isInitialized;
  final Duration duration;
  final Duration position;
  final bool showControls;
  final bool isFullscreen;
  final bool showSeekIndicator;
  final Duration seekTarget;
  final String seekDirection;
  final double playbackSpeed;
  final bool isBuffering;
  final bool showPlaybackSpeedMenu;
  final bool isDisposed; // Track disposal state

  VideoPlayerState({
    this.controller,
    this.isPlaying = false,
    this.isInitialized = false,
    this.duration = Duration.zero,
    this.position = Duration.zero,
    this.showControls = true,
    this.isFullscreen = false,
    this.showSeekIndicator = false,
    this.seekTarget = Duration.zero,
    this.seekDirection = '',
    this.playbackSpeed = 1.0,
    this.isBuffering = false,
    this.showPlaybackSpeedMenu = false,
    this.isDisposed = false,
  });

  /// Check if controller is valid and can be used
  bool get hasValidController => controller != null && !isDisposed;

  VideoPlayerState copyWith({
    BetterPlayerController? controller,
    bool? isPlaying,
    bool? isInitialized,
    Duration? duration,
    Duration? position,
    bool? showControls,
    bool? isFullscreen,
    bool? showSeekIndicator,
    Duration? seekTarget,
    String? seekDirection,
    double? playbackSpeed,
    bool? isBuffering,
    bool? showPlaybackSpeedMenu,
    bool? isDisposed,
    bool clearController = false, // Special flag to clear controller
  }) {
    return VideoPlayerState(
      controller: clearController ? null : (controller ?? this.controller),
      isPlaying: isPlaying ?? this.isPlaying,
      isInitialized: isInitialized ?? this.isInitialized,
      duration: duration ?? this.duration,
      position: position ?? this.position,
      showControls: showControls ?? this.showControls,
      isFullscreen: isFullscreen ?? this.isFullscreen,
      showSeekIndicator: showSeekIndicator ?? this.showSeekIndicator,
      seekTarget: seekTarget ?? this.seekTarget,
      seekDirection: seekDirection ?? this.seekDirection,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      isBuffering: isBuffering ?? this.isBuffering,
      showPlaybackSpeedMenu:
      showPlaybackSpeedMenu ?? this.showPlaybackSpeedMenu,
      isDisposed: isDisposed ?? this.isDisposed,
    );
  }
}

/// Video player provider - uses BetterPlayer for HLS/network (backend videos).
final videoPlayerProvider = StateNotifierProvider.autoDispose
    .family<VideoPlayerNotifier, VideoPlayerState, String>((ref, videoUrl) {
  return VideoPlayerNotifier(ref, videoUrl);
});

/// Video player notifier (BetterPlayer for HLS support).
class VideoPlayerNotifier extends StateNotifier<VideoPlayerState> {
  VideoPlayerNotifier(this._ref, this.videoUrl) : super(VideoPlayerState()) {
    _initializePlayer(videoUrl);
  }

  final Ref _ref;
  final String videoUrl;
  Timer? _progressSaveTimer;
  void Function(BetterPlayerEvent)? _eventListener;
  bool _disposed = false;
  bool _wakelockHeld = false;
  bool _inlineHandoffActive = false;

  void _deferClearStateProvider(void Function() clearAction) {
    Future<void>(() {
      if (_disposed) return;
      try {
        clearAction();
      } catch (_) {}
    });
  }

  void _setWakelockPlaying(bool playing) {
    if (playing == _wakelockHeld) return;
    _wakelockHeld = playing;
    if (playing) {
      unawaited(_ref.read(videoPlaybackWakelockProvider.notifier).acquire());
    } else {
      unawaited(_ref.read(videoPlaybackWakelockProvider.notifier).release());
    }
  }

  Duration _sanitizeResumePosition(Duration value, {Duration? knownDuration}) {
    if (value <= Duration.zero) return Duration.zero;
    if (knownDuration != null &&
        knownDuration > Duration.zero &&
        value.inMilliseconds >= (knownDuration.inMilliseconds * 92 ~/ 100)) {
      return Duration.zero;
    }
    return value;
  }

  bool _isValidRemoteUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null) return false;
    if (!(uri.scheme == 'http' || uri.scheme == 'https')) return false;
    return uri.host.isNotEmpty;
  }

  Future<void> _waitForInitializedEvent(
    BetterPlayerController controller, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final vpc = controller.videoPlayerController;
    if (controller.isVideoInitialized() == true || (vpc?.value.initialized ?? false)) {
      return;
    }
    final completer = Completer<void>();
    late void Function(BetterPlayerEvent) listener;
    listener = (event) {
      if (event.betterPlayerEventType == BetterPlayerEventType.initialized ||
          event.betterPlayerEventType == BetterPlayerEventType.exception) {
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    };
    controller.addEventsListener(listener);
    try {
      await completer.future.timeout(timeout);
    } catch (_) {
      // Timeout fallback: caller may still attempt play.
    } finally {
      try {
        controller.removeEventsListener(listener);
      } catch (_) {}
    }
  }

  Future<void> _initializePlayer(String url) async {
    try {
      final normalizedUrl = url.trim();
      debugPrint('[VideoPlayerProvider] init url=$normalizedUrl');
      final coldIntent = _ref.read(longVideoColdStartIntentProvider);
      final forceColdZero = coldIntent != null &&
          coldIntent.videoUrl.trim() == normalizedUrl;
      if (forceColdZero) {
        _deferClearStateProvider(() {
          _ref.read(longVideoColdStartIntentProvider.notifier).state = null;
        });
      }
      Duration hintedResume = Duration.zero;
      if (!forceColdZero) {
        final syncHint = _ref.read(longVideoEmbedResumeHintProvider);
        if (syncHint != null && syncHint.videoUrl == url) {
          hintedResume = _sanitizeResumePosition(syncHint.position);
          _deferClearStateProvider(() {
            _ref.read(longVideoEmbedResumeHintProvider.notifier).state = null;
          });
        }
      }
      final handoff = _ref.read(longVideoEmbeddedHandoffProvider);
      if (handoff != null && handoff.videoUrl.trim() == normalizedUrl) {
        debugPrint('[VideoPlayerProvider] using inline handoff');
        _deferClearStateProvider(() {
          _ref.read(longVideoEmbeddedHandoffProvider.notifier).state = null;
        });
        final controller = handoff.controller;
        if (!_disposed) {
          _attachBetterPlayerEvents(controller);
          controller.addEventsListener(_eventListener!);
          final vpc = controller.videoPlayerController;
          final dur =
              controller.videoPlayerController?.value.duration ?? Duration.zero;
          final alreadyInited = controller.isVideoInitialized() == true ||
              (vpc?.value.initialized ?? false);
          state = state.copyWith(
            controller: controller,
            isInitialized: alreadyInited,
            duration: dur,
            isPlaying: false,
            position: _sanitizeResumePosition(handoff.position, knownDuration: dur),
          );
          _startProgressSaving();
          _startPositionSync(controller);
          // [ref.watch] creates this notifier during [VideoPlayerScreen.build];
          // setVolume notifies listeners → BetterPlayerSubtitlesDrawer setState.
          await SchedulerBinding.instance.endOfFrame;
          if (_disposed) return;
          // Inline feed keeps the tile muted; embedded must hear audio unless the
          // user explicitly muted inside the full player.
          try {
            await controller.setVolume(1.0);
          } catch (_) {}
          if (forceColdZero) {
            try {
              await controller.seekTo(Duration.zero);
              if (!_disposed) {
                state = state.copyWith(position: Duration.zero);
              }
            } catch (_) {}
          }
          if (handoff.resumePlayback) {
            await _waitForInitializedEvent(controller);
            if (_disposed) return;
            try {
              await controller.play();
              debugPrint('[VideoPlayerProvider] handoff play() called');
              if (!_disposed) {
                state = state.copyWith(isPlaying: true);
                _setWakelockPlaying(true);
              }
            } catch (_) {}
          }
          _inlineHandoffActive = true;
        }
        return;
      }

      final rtStale = _ref.read(longVideoFeedReturnTargetProvider);
      if (rtStale != null && rtStale.videoUrl.trim() == normalizedUrl) {
        _deferClearStateProvider(() {
          _ref.read(longVideoFeedReturnTargetProvider.notifier).state = null;
        });
      }

      Duration resumeFrom = hintedResume;
      if (forceColdZero) {
        resumeFrom = Duration.zero;
      } else if (resumeFrom == Duration.zero) {
        resumeFrom = _sanitizeResumePosition(await _loadSavedProgress(url));
      }

      if (normalizedUrl.isEmpty || normalizedUrl == 'file:///') {
        debugPrint('[VideoPlayerProvider] invalid empty/file url');
        state = state.copyWith(
          isInitialized: false,
          isPlaying: false,
          isDisposed: true,
          controller: null,
          clearController: true,
        );
        return;
      }

      final dataSource = BetterPlayerDataSource.network(
        normalizedUrl,
        cacheConfiguration: longVideoNetworkCache(normalizedUrl),
        bufferingConfiguration: longVideoStreamBuffering(normalizedUrl) ??
            const BetterPlayerBufferingConfiguration(),
      );

      final config = BetterPlayerConfiguration(
        autoPlay: false,
        autoDispose: false,
        startAt: resumeFrom,
        controlsConfiguration: const BetterPlayerControlsConfiguration(
          showControls: false,
        ),
        aspectRatio: 1.0,
        fit: BoxFit.cover,
        handleLifecycle: false,
      );

      final controller = BetterPlayerController(
        config,
        betterPlayerDataSource: dataSource,
      );

      await controller.setupDataSource(dataSource);
      debugPrint('[VideoPlayerProvider] setupDataSource completed');

      if (!_disposed) {
        _attachBetterPlayerEvents(controller);
        controller.addEventsListener(_eventListener!);

        state = state.copyWith(
          controller: controller,
          isInitialized: controller.isVideoInitialized() ?? false,
          duration:
              controller.videoPlayerController?.value.duration ?? Duration.zero,
          isPlaying: false,
        );

        _startProgressSaving();
        _startPositionSync(controller);
        await _waitForInitializedEvent(controller);
        if (_disposed || state.isDisposed) return;
        await applyAutoQualityIfAdaptive(
          settleDelay: const Duration(milliseconds: 80),
        );
        if (_disposed || state.isDisposed) return;
        try {
          await controller.setVolume(1.0);
          await controller.play();
          debugPrint('[VideoPlayerProvider] cold-start play() called');
          if (!_disposed) {
            state = state.copyWith(isPlaying: true);
            _setWakelockPlaying(true);
          }
        } catch (_) {}
      } else {
        controller.dispose();
      }
    } catch (e) {
      if (!_disposed) {
        state = state.copyWith(isInitialized: false);
      }
    }
  }

  void _attachBetterPlayerEvents(BetterPlayerController controller) {
    _eventListener = (BetterPlayerEvent event) {
      if (_disposed) return;
      try {
        if (event.betterPlayerEventType == BetterPlayerEventType.initialized) {
          final dur =
              controller.videoPlayerController?.value.duration ?? Duration.zero;
          if (!_disposed) {
            state = state.copyWith(isInitialized: true, duration: dur);
          }
          // Do not call applyAutoQualityIfAdaptive here: setTrack() shortly after
          // play() would pause HLS until the user taps play again (suggested videos).
        } else if (event.betterPlayerEventType == BetterPlayerEventType.exception) {
          debugPrint('[VideoPlayerProvider] BetterPlayer exception event');
          if (!_disposed) {
            state = state.copyWith(
              isPlaying: false,
              isBuffering: false,
              isDisposed: true,
              controller: null,
              clearController: true,
            );
          }
          try {
            controller.dispose(forceDispose: true);
          } catch (_) {}
        } else if (event.betterPlayerEventType == BetterPlayerEventType.play) {
          if (!_disposed) {
            state = state.copyWith(isPlaying: true);
            _setWakelockPlaying(true);
          }
        } else if (event.betterPlayerEventType == BetterPlayerEventType.pause) {
          if (!_disposed) {
            state = state.copyWith(isPlaying: false);
            _setWakelockPlaying(false);
          }
        } else if (event.betterPlayerEventType ==
            BetterPlayerEventType.finished) {
          if (!_disposed) {
            try {
              controller.pause();
              controller.seekTo(Duration.zero);
              state = state.copyWith(
                isPlaying: false,
                position: Duration.zero,
              );
              _setWakelockPlaying(false);
            } catch (_) {}
          }
        }
      } catch (e) {
        if (!_disposed) {
          state = state.copyWith(
            controller: null,
            isDisposed: true,
            clearController: true,
          );
        }
      }
    };
  }

  Timer? _positionSyncTimer;
  void _startPositionSync(BetterPlayerController ctrl) {
    _positionSyncTimer?.cancel();
    _positionSyncTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (_disposed || state.controller == null || state.isDisposed) return;
      try {
        // Verify controller is still valid before accessing
        if (ctrl != state.controller) return;
        final vc = ctrl.videoPlayerController;
        if (vc != null && vc.value.initialized && !_disposed) {
          state = state.copyWith(
            position: vc.value.position,
            duration: vc.value.duration,
            isPlaying: vc.value.isPlaying,
            isBuffering: vc.value.isBuffering,
          );
        }
      } catch (_) {
        // Controller might be disposed, stop syncing
        _positionSyncTimer?.cancel();
      }
    });
  }

  void _startProgressSaving() {
    _progressSaveTimer?.cancel();
    _progressSaveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _saveProgress();
    });
  }

  Future<void> _saveProgress() async {
    if (state.controller == null || !state.isInitialized) return;
    if (state.position < const Duration(seconds: 5)) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'video_progress_${videoUrl.hashCode}';
      await prefs.setInt(key, state.position.inSeconds);
    } catch (_) {}
  }

  Future<Duration> _loadSavedProgress(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'video_progress_${url.hashCode}';
      final seconds = prefs.getInt(key);
      if (seconds != null && seconds > 0) return Duration(seconds: seconds);
    } catch (_) {}
    return Duration.zero;
  }

  bool _canUseController() {
    if (_disposed || state.isDisposed || state.controller == null) return false;
    if (!state.isInitialized) return false;
    try {
      final vc = state.controller!.videoPlayerController;
      if (vc == null || !vc.value.initialized) return false;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> togglePlayPause() async {
    if (!_canUseController()) return;
    try {
      if (state.isPlaying) {
        await state.controller!.pause();
        if (_disposed || state.isDisposed) return;
        state = state.copyWith(isPlaying: false);
      } else {
        await state.controller!.play();
        if (_disposed || state.isDisposed) return;
        state = state.copyWith(isPlaying: true);
      }
    } catch (e) {
      // Controller was disposed, clear it from state
      state = state.copyWith(
        controller: null,
        isDisposed: true,
        clearController: true,
      );
    }
  }

  Future<void> play() async {
    if (!_canUseController()) return;
    try {
      if (!state.isPlaying) {
        await state.controller!.play();
        if (_disposed || state.isDisposed) return;
        state = state.copyWith(isPlaying: true);
      }
    } catch (e) {
      // Controller was disposed, clear it from state
      state = state.copyWith(
        controller: null,
        isDisposed: true,
        clearController: true,
      );
    }
  }

  Future<void> pause() async {
    if (!_canUseController()) return;
    try {
      if (state.isPlaying) {
        await state.controller!.pause();
        if (_disposed || state.isDisposed) return;
        state = state.copyWith(isPlaying: false);
      }
    } catch (e) {
      // Controller was disposed, clear it from state
      state = state.copyWith(
        controller: null,
        isDisposed: true,
        clearController: true,
      );
    }
  }

  Future<void> seekForward() async {
    if (!_canUseController()) return;
    try {
      final newPosition = state.position + const Duration(seconds: 10);
      final target = newPosition > state.duration
          ? state.duration
          : newPosition;
      await state.controller!.seekTo(target);
      if (_disposed || state.isDisposed) return;
      state = state.copyWith(
        showSeekIndicator: true,
        seekDirection: 'forward',
        seekTarget: target,
      );
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!_disposed && !state.isDisposed) {
          state = state.copyWith(showSeekIndicator: false);
        }
      });
    } catch (e) {
      // Controller was disposed
      state = state.copyWith(
        controller: null,
        isDisposed: true,
        clearController: true,
      );
    }
  }

  Future<void> seekBackward() async {
    if (!_canUseController()) return;
    try {
      final newPosition = state.position - const Duration(seconds: 10);
      final target = newPosition < Duration.zero ? Duration.zero : newPosition;
      final wasPlaying = state.isPlaying;
      await state.controller!.seekTo(target);
      if (wasPlaying) {
        await state.controller!.play();
      }
      if (_disposed || state.isDisposed) return;
      state = state.copyWith(
        showSeekIndicator: true,
        seekDirection: 'backward',
        seekTarget: target,
      );
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!_disposed && !state.isDisposed) {
          state = state.copyWith(showSeekIndicator: false);
        }
      });
    } catch (e) {
      // Controller was disposed
      state = state.copyWith(
        controller: null,
        isDisposed: true,
        clearController: true,
      );
    }
  }

  void toggleControls() {
    state = state.copyWith(showControls: !state.showControls);
  }

  void toggleFullscreen() {
    state = state.copyWith(isFullscreen: !state.isFullscreen);
  }

  Future<void> seekTo(Duration position) async {
    if (!_canUseController()) return;
    try {
      await state.controller!.seekTo(position);
      if (_disposed || state.isDisposed) return;
      state = state.copyWith(position: position);
    } catch (e) {
      // Controller was disposed
      state = state.copyWith(
        controller: null,
        isDisposed: true,
        clearController: true,
      );
    }
  }

  Future<void> setPlaybackSpeed(double speed) async {
    if (!_canUseController()) return;
    try {
      await state.controller!.setSpeed(speed);
      if (_disposed || state.isDisposed) return;
      state = state.copyWith(
        playbackSpeed: speed,
        showPlaybackSpeedMenu: false,
      );
    } catch (e) {
      // Controller was disposed
      state = state.copyWith(
        controller: null,
        isDisposed: true,
        clearController: true,
      );
    }
  }

  void togglePlaybackSpeedMenu() {
    state = state.copyWith(showPlaybackSpeedMenu: !state.showPlaybackSpeedMenu);
  }

  static bool _urlLooksAdaptive(String url) {
    final u = url.toLowerCase();
    return u.contains('.m3u8') ||
        u.contains('.mpd') ||
        u.contains('/master') ||
        u.contains('playlist');
  }

  /// HLS/DASH: pick a rung from [pickBetterPlayerTrackForConnectivity] (Wi‑Fi vs cellular).
  Future<void> applyAutoQualityIfAdaptive({
    Duration settleDelay = const Duration(milliseconds: 400),
  }) async {
    if (!_canUseController()) return;
    if (!_urlLooksAdaptive(videoUrl)) return;
    final c = state.controller!;
    try {
      if (settleDelay > Duration.zero) {
        await Future<void>.delayed(settleDelay);
      }
      if (_disposed || state.isDisposed || state.controller != c) return;
      if (c.isVideoInitialized() != true) return;
      final tracks = c.betterPlayerAsmsTracks;
      if (tracks.length < 2) return;
      final wasPlaying = state.isPlaying ||
          (c.videoPlayerController?.value.isPlaying ?? false);
      final cx = await Connectivity().checkConnectivity();
      final pick = pickBetterPlayerTrackForConnectivity(tracks, cx);
      if (pick != null && !_disposed && state.controller == c) {
        c.setTrack(pick);
        if (wasPlaying) {
          await Future<void>.delayed(const Duration(milliseconds: 60));
          if (_disposed || state.isDisposed || state.controller != c) return;
          try {
            await c.play();
            if (!_disposed && state.controller == c) {
              state = state.copyWith(isPlaying: true);
              _setWakelockPlaying(true);
            }
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  Future<void> setVideoQualityTrack(BetterPlayerAsmsTrack track) async {
    if (!_canUseController()) return;
    try {
      final c = state.controller!;
      final wasPlaying = state.isPlaying ||
          (c.videoPlayerController?.value.isPlaying ?? false);
      c.setTrack(track);
      if (wasPlaying) {
        await Future<void>.delayed(const Duration(milliseconds: 60));
        if (_disposed || state.isDisposed || state.controller != c) return;
        await c.play();
        if (!_disposed && state.controller == c) {
          state = state.copyWith(isPlaying: true);
          _setWakelockPlaying(true);
        }
      }
    } catch (_) {}
  }

  Future<void> clearSavedProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('video_progress_${videoUrl.hashCode}');
    } catch (_) {}
  }

  /// Returns the inline feed [BetterPlayerController] without disposing it
  /// when the route was opened from a long-video tile handoff.
  void transferToLongVideoFeedIfPossibleSync() {
    if (!_inlineHandoffActive) return;
    final target = _ref.read(longVideoFeedReturnTargetProvider);
    if (target == null || target.videoUrl != videoUrl) {
      _inlineHandoffActive = false;
      return;
    }
    final controller = state.controller;
    if (controller == null) {
      _inlineHandoffActive = false;
      _ref.read(longVideoFeedReturnTargetProvider.notifier).state = null;
      return;
    }

    final wasPlaying = state.isPlaying;
    _ref.read(longVideoFeedReturnTargetProvider.notifier).state = null;
    _inlineHandoffActive = false;

    unawaited(_saveProgress());

    _progressSaveTimer?.cancel();
    _positionSyncTimer?.cancel();

    final listener = _eventListener;
    try {
      if (listener != null) controller.removeEventsListener(listener);
    } catch (_) {}
    _eventListener = null;

    if (_wakelockHeld) {
      _wakelockHeld = false;
      unawaited(_ref.read(videoPlaybackWakelockProvider.notifier).release());
    }

    state = state.copyWith(
      controller: null,
      isDisposed: true,
      isInitialized: false,
      isPlaying: false,
      clearController: true,
    );

    try {
      _ref
          .read(longVideoWidgetProvider(
                  VideoWidgetKey(target.videoId, target.videoUrl))
              .notifier)
          .acceptReturnedControllerSync(controller, wasPlaying: wasPlaying);
    } catch (_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          controller.dispose(forceDispose: true);
        } catch (_) {}
      });
    }
  }

  @override
  void dispose() {
    transferToLongVideoFeedIfPossibleSync();
    _disposed = true;
    _progressSaveTimer?.cancel();
    _positionSyncTimer?.cancel();

    if (_wakelockHeld) {
      _wakelockHeld = false;
      unawaited(_ref.read(videoPlaybackWakelockProvider.notifier).release());
    }

    // Save progress before disposing
    _saveProgress();

    final controller = state.controller;
    // Immediately clear controller from state to prevent widgets from using it
    // This must happen BEFORE disposing the controller to prevent race conditions
    state = state.copyWith(
      controller: null,
      isDisposed: true,
      isInitialized: false,
      isPlaying: false,
      clearController: true,
    );

    if (controller != null) {
      final listener = _eventListener;
      _eventListener = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          if (listener != null) {
            controller.removeEventsListener(listener);
          }
        } catch (_) {
          // Listener might already be removed
        }
        try {
          controller.dispose(forceDispose: true);
        } catch (_) {
          // Controller might already be disposed
        }
      });
    }
    super.dispose();
  }
}
