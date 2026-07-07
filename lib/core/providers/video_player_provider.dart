import 'dart:async';

import 'package:better_player/better_player.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../long_video_logger.dart';
import '../media/adaptive_track_selection.dart';
import '../media/long_video_better_cache.dart';
import '../video_engine/video_engine_provider.dart';
import 'active_long_video_url_provider.dart';
import 'long_video_cold_start_intent_provider.dart';
import 'long_video_embedded_handoff_provider.dart';
import 'video_playback_wakelock_provider.dart';

enum VideoPlayerHostKind { longFormScreen, feedInline }

typedef VideoPlayerFamilyKey = ({
  String url,
  VideoPlayerHostKind host,
  String? scopeId,
});

/// scopeId is the canonical engine / feed id (e.g. post id). When null, the
/// trimmed url is used for GlobalVideoEngine slot identity.
VideoPlayerFamilyKey videoPlayerKeyLongForm(String url, {String? postId}) => (
      url: url,
      host: VideoPlayerHostKind.longFormScreen,
      scopeId: postId,
    );

VideoPlayerFamilyKey videoPlayerKeyFeedInline(String url, {String? scopeId}) =>
    (
      url: url,
      host: VideoPlayerHostKind.feedInline,
      scopeId: scopeId,
    );

/// Video player state (HLS/network via BetterPlayer).
class VideoPlayerState {
  /// Non-null only for [VideoPlayerHostKind.feedInline] (legacy local player).
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
  final bool isDisposed;
  final String? activeResolutionKey;

  const VideoPlayerState({
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
    this.activeResolutionKey,
  });

  bool get hasValidController =>
      !isDisposed &&
      (controller != null
          ? (isInitialized && controller != null)
          : isInitialized);

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
    String? activeResolutionKey,
    bool clearActiveResolutionKey = false,
    bool clearController = false,
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
      activeResolutionKey: clearActiveResolutionKey
          ? null
          : (activeResolutionKey ?? this.activeResolutionKey),
    );
  }
}

final videoPlayerProvider = StateNotifierProvider.autoDispose
    .family<VideoPlayerNotifier, VideoPlayerState, VideoPlayerFamilyKey>(
  (ref, key) => VideoPlayerNotifier(ref, key),
);

class VideoPlayerNotifier extends StateNotifier<VideoPlayerState> {
  VideoPlayerNotifier(this._ref, VideoPlayerFamilyKey key)
      : videoUrl = key.url.trim(),
        _host = key.host,
        _scopeId = key.scopeId,
        super(const VideoPlayerState()) {
    _initializePlayer(videoUrl);
  }

  final Ref _ref;
  final String videoUrl;
  final VideoPlayerHostKind _host;
  final String? _scopeId;

  Timer? _progressSaveTimer;
  Timer? _positionSyncTimer;
  void Function(BetterPlayerEvent)? _eventListener;
  void Function(BetterPlayerEvent)? _engineEventListener;
  /// Controller instance that currently has [_engineEventListener] attached.
  BetterPlayerController? _engineControllerForEvents;
  bool _disposed = false;
  bool _wakelockHeld = false;
  bool _inlineHandoffActive = false;
  bool _initializePlayerInFlight = false;
  String? _initializePlayerInFlightUrl;
  bool _playerInitInProgress = false;
  bool _transferredToFeed = false;

  bool get _useEnginePath => _host == VideoPlayerHostKind.longFormScreen;

  String get _enginePlayId {
    final s = _scopeId?.trim();
    if (s != null && s.isNotEmpty) return s;
    return videoUrl.trim();
  }

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

  BetterPlayerController? get _engineController {
    final slot = _ref.read(globalVideoEngineProvider).activeSlot;
    if (slot == null) return null;
    if (slot.id != _enginePlayId) return null;
    return slot.controller;
  }

  BetterPlayerController? get _activeController =>
      _useEnginePath ? _engineController : state.controller;

  bool get _safeToUseController {
    if (_disposed || state.isDisposed) return false;
    final c = _activeController;
    if (c == null) return false;
    if (!state.isInitialized) return false;
    try {
      final vc = c.videoPlayerController;
      if (vc == null || !vc.value.initialized) return false;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _waitForInitializedEvent(
    BetterPlayerController controller, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final vpc = controller.videoPlayerController;
    if (controller.isVideoInitialized() == true ||
        (vpc?.value.initialized ?? false)) {
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
      // Timeout: caller may still attempt play.
    } finally {
      try {
        controller.removeEventsListener(listener);
      } catch (_) {}
    }
  }

  void _initializePlayer(String url) {
    // Long-form: microtask runs before end of frame so [playLongVideo] can reuse
    // the engine slot while the previous autoDispose family notifier is still
    // alive (postFrame would run after dispose and [abandon] cleared the slot).
    if (_useEnginePath) {
      Future.microtask(() async {
        if (_disposed) return;
        await _doInitializePlayer(url);
      });
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_disposed) return;
      await _doInitializePlayer(url);
    });
  }

  String _handoffAcceptId(String normalized) {
    final target = _ref.read(longVideoFeedReturnTargetProvider);
    if (target != null && target.videoUrl.trim() == normalized) {
      return target.videoId;
    }
    return _enginePlayId;
  }

  Future<void> _doInitializePlayer(String url) async {
    if (_disposed) return;
    final normalizedUrl = url.trim();
    if (_initializePlayerInFlight &&
        _initializePlayerInFlightUrl == normalizedUrl) {
      LongVideoLogger.lifecycle(
        'player init skip duplicate in-flight url=$normalizedUrl',
      );
      return;
    }
    if (_playerInitInProgress) {
      debugPrint(
        '[VideoPlayerProvider] init already in progress, skipping url=$url',
      );
      return;
    }
    if (!_isValidRemoteUrl(normalizedUrl)) {
      LongVideoLogger.error('invalid remote url url=$normalizedUrl');
      if (!_disposed) {
        state = state.copyWith(
          isInitialized: false,
          isPlaying: false,
          isDisposed: true,
          clearController: true,
        );
      }
      return;
    }

    _playerInitInProgress = true;
    _initializePlayerInFlight = true;
    _initializePlayerInFlightUrl = normalizedUrl;
    try {
      debugPrint('[VideoPlayerProvider] init url=$normalizedUrl host=$_host');
      final coldIntent = _ref.read(longVideoColdStartIntentProvider);
      final forceColdZero = coldIntent != null &&
          coldIntent.videoUrl.trim() == normalizedUrl;
      if (forceColdZero) {
        _deferClearStateProvider(() {
          _ref.read(longVideoColdStartIntentProvider.notifier).state = null;
        });
      }
      Duration hintedResume = Duration.zero;
      var forceZeroFromFeedTap = false;
      if (!forceColdZero) {
        final syncHint = _ref.read(longVideoEmbedResumeHintProvider);
        if (syncHint != null && syncHint.videoUrl == url) {
          hintedResume = _sanitizeResumePosition(syncHint.position);
          forceZeroFromFeedTap = syncHint.forceStartFromZero;
          _deferClearStateProvider(() {
            _ref.read(longVideoEmbedResumeHintProvider.notifier).state = null;
          });
        }
      }

      final handoff = _ref.read(longVideoEmbeddedHandoffProvider);
      if (handoff != null && handoff.videoUrl.trim() == normalizedUrl) {
        if (_useEnginePath) {
          await _handleEngineHandoff(
            handoff: handoff,
            normalizedUrl: normalizedUrl,
            forceColdZero: forceColdZero,
          );
        } else {
          await _handleLegacyHandoff(
            handoff: handoff,
            normalizedUrl: normalizedUrl,
            forceColdZero: forceColdZero,
          );
        }
        return;
      }

      final rtStale = _ref.read(longVideoFeedReturnTargetProvider);
      if (rtStale != null && rtStale.videoUrl.trim() == normalizedUrl) {
        _deferClearStateProvider(() {
          _ref.read(longVideoFeedReturnTargetProvider.notifier).state = null;
        });
      }

      late Duration resumeFrom;
      if (forceColdZero || forceZeroFromFeedTap) {
        resumeFrom = Duration.zero;
      } else if (hintedResume > Duration.zero) {
        resumeFrom = hintedResume;
      } else {
        resumeFrom = _sanitizeResumePosition(await _loadSavedProgress(url));
      }

      if (normalizedUrl.isEmpty || normalizedUrl == 'file:///') {
        debugPrint('[VideoPlayerProvider] invalid empty/file url');
        state = state.copyWith(
          isInitialized: false,
          isPlaying: false,
          isDisposed: true,
          clearController: true,
        );
        return;
      }

      if (_useEnginePath) {
        final existingSlot = _ref.read(globalVideoEngineProvider).activeSlot;
        if (existingSlot != null &&
            existingSlot.id == _enginePlayId &&
            existingSlot.url.trim() == normalizedUrl) {
          LongVideoLogger.lifecycle(
            'engine slot already matches notifier; skip duplicate playLongVideo '
            'id=$_enginePlayId',
          );
          if (!_disposed && state.activeResolutionKey != null) {
            state = state.copyWith(clearActiveResolutionKey: true);
          }
          await _syncNotifierToEngineController(
            existingSlot.controller,
            normalizedUrl,
          );
        } else {
          await _coldStartEngine(
            normalizedUrl: normalizedUrl,
            resumeFrom: resumeFrom,
          );
        }
      } else {
        await _coldStartLegacy(
          normalizedUrl: normalizedUrl,
          resumeFrom: resumeFrom,
        );
      }
    } catch (e) {
      final activeUrl = _ref.read(activeLongVideoUrlProvider);
      if (activeUrl == videoUrl.trim()) {
        _ref.read(activeLongVideoUrlProvider.notifier).state = null;
      }
      if (!_disposed) {
        state = state.copyWith(isInitialized: false);
      }
    } finally {
      _playerInitInProgress = false;
      _initializePlayerInFlight = false;
      _initializePlayerInFlightUrl = null;
    }
  }

  Future<void> _handleEngineHandoff({
    required LongVideoInlineHandoff handoff,
    required String normalizedUrl,
    required bool forceColdZero,
  }) async {
    LongVideoLogger.handoff('using inline handoff (engine) url=$normalizedUrl');
    _deferClearStateProvider(() {
      _ref.read(longVideoEmbeddedHandoffProvider.notifier).state = null;
    });

    final controller = handoff.controller;
    _ref.read(globalVideoEngineProvider.notifier).acceptReturnedController(
          id: _handoffAcceptId(normalizedUrl),
          url: normalizedUrl,
          controller: controller,
        );

    _attachEngineEventListener(controller);
    final vpc = controller.videoPlayerController;
    final dur = vpc?.value.duration ?? Duration.zero;
    final alreadyInited = controller.isVideoInitialized() == true ||
        (vpc?.value.initialized ?? false);

    if (!_disposed) {
      state = state.copyWith(
        isInitialized: alreadyInited,
        duration: dur,
        isPlaying: false,
        position: _sanitizeResumePosition(handoff.position, knownDuration: dur),
      );
      _ref.read(activeLongVideoUrlProvider.notifier).state = normalizedUrl;
      _startProgressSaving();
      _startPositionSync(controller, engineMode: true);
    }

    await SchedulerBinding.instance.endOfFrame;
    if (_disposed) return;

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
        if (!_disposed) {
          state = state.copyWith(isPlaying: true);
          _setWakelockPlaying(true);
        }
      } catch (_) {}
    }
    _inlineHandoffActive = true;
  }

  Future<void> _handleLegacyHandoff({
    required LongVideoInlineHandoff handoff,
    required String normalizedUrl,
    required bool forceColdZero,
  }) async {
    LongVideoLogger.handoff('using inline handoff url=$normalizedUrl');
    debugPrint('[VideoPlayerProvider] using inline handoff');
    _deferClearStateProvider(() {
      _ref.read(longVideoEmbeddedHandoffProvider.notifier).state = null;
    });
    final controller = handoff.controller;
    if (_disposed) return;

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
    _ref.read(activeLongVideoUrlProvider.notifier).state = normalizedUrl;
    _startProgressSaving();
    _startPositionSync(controller, engineMode: false);

    await SchedulerBinding.instance.endOfFrame;
    if (_disposed) return;

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

  Future<void> _coldStartEngine({
    required String normalizedUrl,
    required Duration resumeFrom,
  }) async {
    LongVideoLogger.handoff(
      'no inline handoff found; cold start (engine) url=$normalizedUrl',
    );
    LongVideoLogger.lifecycle('cold start (engine) url=$normalizedUrl');

    if (!_disposed && state.activeResolutionKey != null) {
      state = state.copyWith(clearActiveResolutionKey: true);
    }

    final engine = _ref.read(globalVideoEngineProvider.notifier);
    final controller = await engine.playLongVideo(
      id: _enginePlayId,
      url: normalizedUrl,
      startAt: resumeFrom,
    );

    if (_disposed) return;

    if (controller == null) {
      LongVideoLogger.error(
        'engine returned null controller url=$normalizedUrl',
      );
      return;
    }

    await _syncNotifierToEngineController(controller, normalizedUrl);
  }

  /// Shared tail after [GlobalVideoEngine.playLongVideo] (or when the active
  /// slot already matches this notifier — avoids a second playLongVideo from
  /// overlapping microtasks during suggested in-place switches).
  Future<void> _syncNotifierToEngineController(
    BetterPlayerController controller,
    String normalizedUrl,
  ) async {
    if (_disposed) return;

    _ref.read(activeLongVideoUrlProvider.notifier).state = normalizedUrl;
    _attachEngineEventListener(controller);
    _startPositionSync(controller, engineMode: true);
    _startProgressSaving();

    await _waitForInitializedEvent(controller);
    if (_disposed || state.isDisposed) return;

    // Engine path: [BetterPlayerEventType.initialized] may have fired before our
    // listener was attached; mirror the legacy path and sync from the controller.
    if (!_disposed) {
      final vpc = controller.videoPlayerController;
      final inited = controller.isVideoInitialized() == true ||
          (vpc?.value.initialized ?? false);
      if (inited) {
        state = state.copyWith(
          isInitialized: true,
          duration: vpc?.value.duration ?? state.duration,
          isPlaying: vpc?.value.isPlaying ?? state.isPlaying,
          isBuffering: vpc?.value.isBuffering ?? state.isBuffering,
        );
        if (state.isPlaying) {
          _setWakelockPlaying(true);
        }
      }
    }
    if (_disposed || state.isDisposed) return;

    await applyAutoQualityIfAdaptive(
      settleDelay: const Duration(milliseconds: 80),
    );
    if (_disposed || state.isDisposed) return;
    _syncPlayingStateFromController(controller);
  }

  void _syncPlayingStateFromController(BetterPlayerController controller) {
    if (_disposed) return;
    try {
      final vpc = controller.videoPlayerController;
      if (vpc == null || !vpc.value.initialized) return;
      final playing = vpc.value.isPlaying;
      final buffering = vpc.value.isBuffering;
      if (playing == state.isPlaying && buffering == state.isBuffering) {
        return;
      }
      state = state.copyWith(isPlaying: playing, isBuffering: buffering);
      _setWakelockPlaying(playing);
    } catch (_) {}
  }

  Future<void> _coldStartLegacy({
    required String normalizedUrl,
    required Duration resumeFrom,
  }) async {
    LongVideoLogger.handoff(
      'no inline handoff found; cold start url=$normalizedUrl',
    );
    LongVideoLogger.lifecycle('cold start url=$normalizedUrl');

    if (!_disposed && state.activeResolutionKey != null) {
      state = state.copyWith(clearActiveResolutionKey: true);
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
      _ref.read(activeLongVideoUrlProvider.notifier).state = normalizedUrl;

      _startProgressSaving();
      _startPositionSync(controller, engineMode: false);
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
  }

  void _attachEngineEventListener(BetterPlayerController c) {
    if (_engineEventListener != null) {
      final prev = _engineControllerForEvents;
      if (prev != null) {
        try {
          prev.removeEventsListener(_engineEventListener!);
        } catch (_) {}
      }
    }
    _engineControllerForEvents = c;
    _engineEventListener = (BetterPlayerEvent event) {
      if (_disposed) return;
      final slot = _ref.read(globalVideoEngineProvider).activeSlot;
      if (slot == null || slot.controller != c) return;

      final t = event.betterPlayerEventType;
      if (t == BetterPlayerEventType.initialized) {
        final dur = c.videoPlayerController?.value.duration ?? Duration.zero;
        if (!_disposed) {
          state = state.copyWith(isInitialized: true, duration: dur);
        }
      } else if (t == BetterPlayerEventType.play) {
        if (!_disposed) {
          state = state.copyWith(isPlaying: true);
          _setWakelockPlaying(true);
        }
      } else if (t == BetterPlayerEventType.pause) {
        if (!_disposed) {
          state = state.copyWith(isPlaying: false);
          _setWakelockPlaying(false);
        }
      } else if (t == BetterPlayerEventType.bufferingStart) {
        if (!_disposed) {
          state = state.copyWith(isBuffering: true);
        }
      } else if (t == BetterPlayerEventType.bufferingEnd) {
        if (!_disposed) {
          state = state.copyWith(isBuffering: false);
        }
      } else if (t == BetterPlayerEventType.finished) {
        try {
          c.pause();
          c.seekTo(Duration.zero);
        } catch (_) {}
        if (!_disposed) {
          state = state.copyWith(isPlaying: false, position: Duration.zero);
          _setWakelockPlaying(false);
        }
      } else if (t == BetterPlayerEventType.exception) {
        LongVideoLogger.error('engine controller exception url=$videoUrl');
        if (!_disposed) {
          state = state.copyWith(
            isPlaying: false,
            isBuffering: false,
            isDisposed: true,
          );
        }
      }
    };
    c.addEventsListener(_engineEventListener!);
  }

  void _detachEngineEventListener() {
    if (_engineEventListener != null) {
      final attached = _engineControllerForEvents;
      if (attached != null) {
        try {
          attached.removeEventsListener(_engineEventListener!);
        } catch (_) {}
      }
    }
    _engineEventListener = null;
    _engineControllerForEvents = null;
  }

  void _attachBetterPlayerEvents(BetterPlayerController controller) {
    _eventListener = (BetterPlayerEvent event) {
      if (_disposed) return;
      try {
        if (event.betterPlayerEventType == BetterPlayerEventType.initialized) {
          final dur =
              controller.videoPlayerController?.value.duration ??
                  Duration.zero;
          if (!_disposed) {
            state = state.copyWith(isInitialized: true, duration: dur);
          }
        } else if (event.betterPlayerEventType ==
            BetterPlayerEventType.exception) {
          debugPrint('[VideoPlayerProvider] BetterPlayer exception event');
          final activeUrl = _ref.read(activeLongVideoUrlProvider);
          if (activeUrl == videoUrl) {
            _ref.read(activeLongVideoUrlProvider.notifier).state = null;
          }
          if (!_disposed) {
            state = state.copyWith(
              isPlaying: false,
              isBuffering: false,
              isDisposed: true,
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
            BetterPlayerEventType.bufferingStart) {
          if (!_disposed) {
            state = state.copyWith(isBuffering: true);
          }
        } else if (event.betterPlayerEventType ==
            BetterPlayerEventType.bufferingEnd) {
          if (!_disposed) {
            state = state.copyWith(isBuffering: false);
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
      } catch (_) {
        if (!_disposed) {
          state = state.copyWith(
            clearController: true,
            isDisposed: true,
          );
        }
      }
    };
  }

  void _startPositionSync(
    BetterPlayerController ctrl, {
    required bool engineMode,
  }) {
    _positionSyncTimer?.cancel();
    final interval = engineMode
        ? const Duration(milliseconds: 250)
        : const Duration(milliseconds: 500);
    _positionSyncTimer = Timer.periodic(interval, (_) {
      if (_disposed || state.isDisposed) return;
      if (engineMode) {
        final slot = _ref.read(globalVideoEngineProvider).activeSlot;
        if (slot == null || slot.controller != ctrl) {
          _positionSyncTimer?.cancel();
          return;
        }
      } else {
        if (ctrl != state.controller) return;
      }
      try {
        final vc = ctrl.videoPlayerController;
        if (vc == null || !vc.value.initialized || _disposed) return;
        final pos = vc.value.position;
        final dur = vc.value.duration ?? state.duration;
        if (engineMode) {
          final playing = vc.value.isPlaying;
          final buffering = vc.value.isBuffering;
          if ((pos - state.position).abs() >
                  const Duration(milliseconds: 100) ||
              playing != state.isPlaying ||
              buffering != state.isBuffering) {
            state = state.copyWith(
              position: pos,
              duration: dur,
              isPlaying: playing,
              isBuffering: buffering,
            );
          }
        } else {
          state = state.copyWith(
            position: pos,
            duration: dur,
            isPlaying: vc.value.isPlaying,
            isBuffering: vc.value.isBuffering,
          );
        }
      } catch (_) {
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
    if (!state.isInitialized) return;
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

  Future<void> togglePlayPause() async {
    if (!_safeToUseController) return;
    final c = _activeController!;
    try {
      if (state.isPlaying) {
        await c.pause();
        if (_disposed || state.isDisposed) return;
        state = state.copyWith(isPlaying: false);
      } else {
        await c.play();
        if (_disposed || state.isDisposed) return;
        state = state.copyWith(isPlaying: true);
      }
    } catch (_) {
      if (!_useEnginePath && !_disposed) {
        state = state.copyWith(isDisposed: true, clearController: true);
      } else if (_useEnginePath && !_disposed) {
        state = state.copyWith(isDisposed: true);
      }
    }
  }

  Future<void> play() async {
    if (!_safeToUseController) return;
    final c = _activeController!;
    try {
      if (!state.isPlaying) {
        await c.play();
        if (_disposed || state.isDisposed) return;
        state = state.copyWith(isPlaying: true);
      }
    } catch (_) {
      if (!_useEnginePath && !_disposed) {
        state = state.copyWith(isDisposed: true, clearController: true);
      } else if (_useEnginePath && !_disposed) {
        state = state.copyWith(isDisposed: true);
      }
    }
  }

  Future<void> pause() async {
    if (!_safeToUseController) return;
    final c = _activeController!;
    try {
      if (state.isPlaying) {
        await c.pause();
        if (_disposed || state.isDisposed) return;
        state = state.copyWith(isPlaying: false);
      }
    } catch (_) {
      if (!_useEnginePath && !_disposed) {
        state = state.copyWith(isDisposed: true, clearController: true);
      } else if (_useEnginePath && !_disposed) {
        state = state.copyWith(isDisposed: true);
      }
    }
  }

  Future<void> seekForward() async {
    if (!_safeToUseController) return;
    final c = _activeController!;
    try {
      final newPosition = state.position + const Duration(seconds: 10);
      final target = newPosition > state.duration
          ? state.duration
          : newPosition;
      await c.seekTo(target);
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
    } catch (_) {
      if (!_useEnginePath && !_disposed) {
        state = state.copyWith(isDisposed: true, clearController: true);
      }
    }
  }

  Future<void> seekBackward() async {
    if (!_safeToUseController) return;
    final c = _activeController!;
    try {
      final newPosition = state.position - const Duration(seconds: 10);
      final target =
          newPosition < Duration.zero ? Duration.zero : newPosition;
      final wasPlaying = state.isPlaying;
      await c.seekTo(target);
      if (wasPlaying) {
        await c.play();
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
    } catch (_) {
      if (!_useEnginePath && !_disposed) {
        state = state.copyWith(isDisposed: true, clearController: true);
      }
    }
  }

  void toggleControls() {
    state = state.copyWith(showControls: !state.showControls);
  }

  void ensureControlsVisible() {
    if (_disposed || state.showControls) return;
    state = state.copyWith(showControls: true);
  }

  void toggleFullscreen() {
    state = state.copyWith(isFullscreen: !state.isFullscreen);
  }

  Future<void> seekTo(Duration position) async {
    if (!_safeToUseController) return;
    final c = _activeController!;
    try {
      await c.seekTo(position);
      if (_disposed || state.isDisposed) return;
      state = state.copyWith(position: position);
    } catch (_) {
      if (!_useEnginePath && !_disposed) {
        state = state.copyWith(isDisposed: true, clearController: true);
      }
    }
  }

  Future<void> setPlaybackSpeed(double speed) async {
    if (!_safeToUseController) return;
    final c = _activeController!;
    try {
      await c.setSpeed(speed);
      if (_disposed || state.isDisposed) return;
      state = state.copyWith(
        playbackSpeed: speed,
        showPlaybackSpeedMenu: false,
      );
    } catch (_) {
      if (!_useEnginePath && !_disposed) {
        state = state.copyWith(isDisposed: true, clearController: true);
      }
    }
  }

  void togglePlaybackSpeedMenu() {
    state = state.copyWith(
      showPlaybackSpeedMenu: !state.showPlaybackSpeedMenu,
    );
  }

  static bool _urlLooksAdaptive(String url) {
    final u = url.toLowerCase();
    return u.contains('.m3u8') ||
        u.contains('.mpd') ||
        u.contains('/master') ||
        u.contains('playlist');
  }

  Future<void> applyAutoQualityIfAdaptive({
    Duration settleDelay = const Duration(milliseconds: 400),
  }) async {
    if (!_safeToUseController) return;
    if (!_urlLooksAdaptive(videoUrl)) return;
    final c = _activeController!;
    try {
      if (settleDelay > Duration.zero) {
        await Future<void>.delayed(settleDelay);
      }
      if (_disposed || state.isDisposed || _activeController != c) return;
      if (c.isVideoInitialized() != true) return;
      final tracks = c.betterPlayerAsmsTracks;
      if (tracks.length < 2) return;
      final wasPlaying = state.isPlaying ||
          (c.videoPlayerController?.value.isPlaying ?? false);
      final cx = await Connectivity().checkConnectivity();
      final pick = pickBetterPlayerTrackForConnectivity(tracks, cx);
      if (pick != null && !_disposed && _activeController == c) {
        c.setTrack(pick);
        if (wasPlaying) {
          await Future<void>.delayed(const Duration(milliseconds: 60));
          if (_disposed || state.isDisposed || _activeController != c) return;
          try {
            await c.play();
            if (!_disposed && _activeController == c) {
              state = state.copyWith(isPlaying: true);
              _setWakelockPlaying(true);
            }
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  Future<void> setVideoQualityTrack(BetterPlayerAsmsTrack track) async {
    if (!_safeToUseController) return;
    final c = _activeController!;
    try {
      final wasPlaying = state.isPlaying ||
          (c.videoPlayerController?.value.isPlaying ?? false);
      c.setTrack(track);
      if (wasPlaying) {
        await Future<void>.delayed(const Duration(milliseconds: 60));
        if (_disposed || state.isDisposed || _activeController != c) return;
        await c.play();
        if (!_disposed && _activeController == c) {
          state = state.copyWith(isPlaying: true);
          _setWakelockPlaying(true);
        }
      }
    } catch (_) {}
  }

  Future<void> switchToResolution({
    required String? resolutionKey,
    required Map<String, String> videoResolutions,
    required String masterUrl,
  }) async {
    if (!_safeToUseController) return;
    if (masterUrl.trim().isEmpty &&
        (resolutionKey == null ||
            !videoResolutions.containsKey(resolutionKey))) {
      debugPrint('[VideoPlayerProvider] switchToResolution: no valid URL');
      return;
    }

    final targetUrl = (resolutionKey != null &&
            videoResolutions.containsKey(resolutionKey))
        ? videoResolutions[resolutionKey]!
        : masterUrl;

    final c = _activeController!;
    final wasPlaying = state.isPlaying;
    final savedPosition = state.position;

    final newSource = BetterPlayerDataSource.network(
      targetUrl,
      cacheConfiguration: longVideoNetworkCache(targetUrl),
      bufferingConfiguration: const BetterPlayerBufferingConfiguration(
        minBufferMs: 2000,
        maxBufferMs: 50000,
        bufferForPlaybackMs: 1000,
        bufferForPlaybackAfterRebufferMs: 2000,
      ),
    );

    LongVideoLogger.resolution(
      'switch to resolutionKey=$resolutionKey url=$targetUrl',
    );

    try {
      state = state.copyWith(isBuffering: true);
      await c.setupDataSource(newSource);
      await _waitForInitializedEvent(c);
      if (_disposed) return;
      await c.seekTo(savedPosition);
      if (wasPlaying) {
        await c.play();
      }
      if (_useEnginePath) {
        _ref
            .read(globalVideoEngineProvider.notifier)
            .syncLongVideoActiveUrl(targetUrl);
      }
      state = state.copyWith(
        isBuffering: false,
        isPlaying: wasPlaying,
        activeResolutionKey: resolutionKey,
      );
      LongVideoLogger.resolution('switch done resolutionKey=$resolutionKey');
    } catch (e) {
      state = state.copyWith(isBuffering: false);
      LongVideoLogger.error('resolution switch failed: $e');
      debugPrint('[VideoPlayerProvider] resolution switch failed: $e');
    }
  }

  void resetResolution() {
    if (_disposed) return;
    state = state.copyWith(clearActiveResolutionKey: true);
  }

  Future<void> setVideoQualityByTargetHeight(int targetHeightPixels) async {
    if (!_safeToUseController) return;
    final c = _activeController!;
    final tracks = c.betterPlayerAsmsTracks;
    final pick =
        pickBetterPlayerTrackForTargetHeight(tracks, targetHeightPixels);
    if (pick == null) return;
    await setVideoQualityTrack(pick);
  }

  Future<void> clearSavedProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('video_progress_${videoUrl.hashCode}');
    } catch (_) {}
  }

  void transferToLongVideoFeedIfPossibleSync() {
    if (!_inlineHandoffActive) return;
    final target = _ref.read(longVideoFeedReturnTargetProvider);
    if (target == null || target.videoUrl != videoUrl) {
      _inlineHandoffActive = false;
      final activeUrl = _ref.read(activeLongVideoUrlProvider);
      if (activeUrl == videoUrl) {
        _ref.read(activeLongVideoUrlProvider.notifier).state = null;
      }
      return;
    }

    _ref.read(longVideoFeedReturnTargetProvider.notifier).state = null;
    _inlineHandoffActive = false;
    _transferredToFeed = true;

    unawaited(_saveProgress());

    _progressSaveTimer?.cancel();
    _positionSyncTimer?.cancel();

    if (_wakelockHeld) {
      _wakelockHeld = false;
      unawaited(_ref.read(videoPlaybackWakelockProvider.notifier).release());
    }

    if (_useEnginePath) {
      final slot = _ref.read(globalVideoEngineProvider).activeSlot;
      _detachEngineEventListener();

      if (slot == null) {
        if (!_disposed) {
          state = state.copyWith(
            isDisposed: true,
            isInitialized: false,
            isPlaying: false,
          );
        }
        return;
      }

      if (slot.id == target.videoId &&
          slot.url.trim() == target.videoUrl.trim()) {
        LongVideoLogger.handoff(
          'transfer back to feed url=$videoUrl (engine already)',
        );
        if (!_disposed) {
          state = state.copyWith(
            isDisposed: true,
            isInitialized: false,
            isPlaying: false,
          );
        }
        return;
      }

      try {
        _ref.read(globalVideoEngineProvider.notifier).acceptReturnedController(
              id: target.videoId,
              url: target.videoUrl,
              controller: slot.controller,
            );
      } catch (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            slot.controller.dispose(forceDispose: true);
          } catch (_) {}
        });
      }
      if (!_disposed) {
        state = state.copyWith(
          isDisposed: true,
          isInitialized: false,
          isPlaying: false,
        );
      }
      return;
    }

    final controller = state.controller;
    if (controller == null) {
      return;
    }

    final listener = _eventListener;
    try {
      if (listener != null) controller.removeEventsListener(listener);
    } catch (_) {}
    _eventListener = null;

    state = state.copyWith(
      clearController: true,
      isDisposed: true,
      isInitialized: false,
      isPlaying: false,
    );

    LongVideoLogger.handoff('transfer back to feed url=$videoUrl');
    try {
      _ref.read(globalVideoEngineProvider.notifier).acceptReturnedController(
            id: target.videoId,
            url: target.videoUrl,
            controller: controller,
          );
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
    LongVideoLogger.lifecycle('dispose url=$videoUrl host=$_host');
    _playerInitInProgress = false;
    transferToLongVideoFeedIfPossibleSync();
    _disposed = true;
    _progressSaveTimer?.cancel();
    _positionSyncTimer?.cancel();

    if (_wakelockHeld) {
      _wakelockHeld = false;
      unawaited(_ref.read(videoPlaybackWakelockProvider.notifier).release());
    }

    unawaited(_saveProgress());

    if (_useEnginePath) {
      _detachEngineEventListener();

      // Do not call [abandonIfLongVideoSlotMatches]: a new long-form notifier may
      // already own this slot (suggested in-place switch). Only pause when this
      // session still matches the active slot id+url.
      if (!_transferredToFeed) {
        final currentSlot = _ref.read(globalVideoEngineProvider).activeSlot;
        if (currentSlot != null &&
            currentSlot.id == _enginePlayId &&
            currentSlot.url.trim() == videoUrl.trim()) {
          try {
            currentSlot.controller.pause();
          } catch (_) {}
        }
      }

      state = state.copyWith(
        isDisposed: true,
        isInitialized: false,
        isPlaying: false,
      );
    } else {
      final controller = state.controller;
      state = state.copyWith(
        clearController: true,
        isDisposed: true,
        isInitialized: false,
        isPlaying: false,
      );

      if (controller != null) {
        final listener = _eventListener;
        _eventListener = null;
        try {
          if (listener != null) {
            controller.removeEventsListener(listener);
          }
        } catch (_) {}

        unawaited(() async {
          try {
            await controller.pause();
          } catch (_) {}
          await Future<void>.delayed(const Duration(milliseconds: 250));
          try {
            controller.dispose(forceDispose: true);
          } catch (_) {}
        }());
      }
    }

    final activeUrl = _ref.read(activeLongVideoUrlProvider);
    if (activeUrl == videoUrl) {
      _ref.read(activeLongVideoUrlProvider.notifier).state = null;
    }

    super.dispose();
  }
}
