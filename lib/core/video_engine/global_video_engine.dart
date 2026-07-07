import 'dart:async';

import 'package:better_player/better_player.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../media/long_video_better_cache.dart';
import 'global_video_engine_state.dart';
import 'video_engine_logger.dart';

class GlobalVideoEngine extends StateNotifier<GlobalVideoEngineState> {
  GlobalVideoEngine() : super(const GlobalVideoEngineState());

  int _activeEpoch = 0;
  Timer? _prefetchTimer;
  bool _isActivePaused = false;
  bool _disposed = false;
  Future<void> _activateFeatureMutex = Future<void>.value();

  /// Snapshot of [VideoPlayerController.value.volume] before [pauseActive] zeroes
  /// volume (so [resumeActive] can restore feed mute vs audible).
  double _volumeSnapshotBeforePause = 1.0;

  void _resetActivePauseCoalescing() {
    _isActivePaused = false;
  }

  Future<void> activateFeature(VideoEngineFeature feature) async {
    if (state.activeFeature == feature) {
      VideoEngineLogger.engine(
        'ACTIVATE_FEATURE_SKIP — already active feature=${feature.name}',
      );
      return;
    }

    final run = _activateFeatureMutex.then((_) async {
      if (state.activeFeature == feature) {
        VideoEngineLogger.engine(
          'ACTIVATE_FEATURE_SKIP — became active while queued feature=${feature.name}',
        );
        return;
      }

      VideoEngineLogger.engine(
        'ACTIVATE_FEATURE from=${state.activeFeature.name} to=${feature.name}',
      );

      await _disposeAll();
      _resetActivePauseCoalescing();

      state = state.copyWith(
        activeFeature: feature,
        isTransitioning: false,
      );

      VideoEngineLogger.engine('ACTIVATE_FEATURE_DONE feature=${feature.name}');
    });

    _activateFeatureMutex = run.catchError((Object _, StackTrace __) {
      return;
    });
    await run;
  }

  Future<void> deactivateAll() async {
    VideoEngineLogger.engine('DEACTIVATE_ALL');
    await _disposeAll();
    _resetActivePauseCoalescing();
    state = const GlobalVideoEngineState(
      activeFeature: VideoEngineFeature.none,
    );
  }

  Future<BetterPlayerController?> play({
    required String id,
    required String url,
    required VideoEngineFeature feature,
    bool muteInitially = false,
    Duration startAt = Duration.zero,
  }) async {
    if (state.activeFeature != feature) {
      VideoEngineLogger.engine(
        'PLAY_BLOCKED feature=${feature.name} activeFeature=${state.activeFeature.name}',
      );
      return null;
    }

    final active = state.activeSlot;
    if (active != null && active.id == id && active.url == url) {
      VideoEngineLogger.engine('PLAY_SKIP_ACTIVE_MATCH id=$id');
      _resetActivePauseCoalescing();
      try {
        await active.controller.setVolume(muteInitially ? 0.0 : 1.0);
        await active.controller.play();
      } catch (_) {}
      return active.controller;
    }

    return _executePlay(
      id: id,
      url: url,
      feature: feature,
      muteInitially: muteInitially,
      startAt: startAt,
    );
  }

  /// Long-form playback: activates [VideoEngineFeature.longVideos], no reel
  /// coalesce path, [BoxFit.contain] via [_configurationForFeature].
  ///
  /// Returns the controller or null on failure / stale epoch.
  Future<BetterPlayerController?> playLongVideo({
    required String id,
    required String url,
    Duration startAt = Duration.zero,
  }) async {
    if (_disposed) return null;

    if (state.activeFeature != VideoEngineFeature.longVideos) {
      await activateFeature(VideoEngineFeature.longVideos);
      if (_disposed) return null;
    }

    final active = state.activeSlot;
    if (active != null && active.id == id && active.url == url) {
      VideoEngineLogger.engine('LV_PLAY_SKIP_ACTIVE_MATCH id=$id');
      _resetActivePauseCoalescing();
      try {
        await active.controller.setVolume(1.0);
        await active.controller.play();
      } catch (_) {}
      return active.controller;
    }

    return _executePlay(
      id: id,
      url: url,
      feature: VideoEngineFeature.longVideos,
      muteInitially: false,
      startAt: startAt,
    );
  }

  /// After an in-place resolution / master URL switch, keep [VideoSlot.id] and
  /// update the tracked URL so feed helpers stay consistent.
  void syncLongVideoActiveUrl(String newUrl) {
    final a = state.activeSlot;
    if (a == null || state.activeFeature != VideoEngineFeature.longVideos) {
      return;
    }
    final u = newUrl.trim();
    if (u.isEmpty) return;
    state = state.copyWith(
      activeSlot: VideoSlot(id: a.id, url: u, controller: a.controller),
    );
  }

  /// Drops the active long-form slot when both [id] and [url] match the active
  /// slot (avoids tearing down a newer session that reused the same post id).
  void abandonIfLongVideoSlotMatches({
    required String id,
    required String url,
  }) {
    final a = state.activeSlot;
    if (_disposed) return;
    if (a == null || state.activeFeature != VideoEngineFeature.longVideos) {
      return;
    }
    if (a.id != id || a.url.trim() != url.trim()) return;
    state = state.copyWith(
      clearActive: true,
      activeFeature: VideoEngineFeature.none,
    );
    _hardDispose(a.controller, label: 'abandon-long');
    _resetActivePauseCoalescing();
    VideoEngineLogger.engine('ABANDON_LONG id=$id');
  }

  Future<BetterPlayerController?> _executePlay({
    required String id,
    required String url,
    required VideoEngineFeature feature,
    required bool muteInitially,
    required Duration startAt,
  }) async {
    final epoch = ++_activeEpoch;
    VideoEngineLogger.engine(
      'PLAY_START id=$id epoch=$epoch url=$url',
    );

    state = state.copyWith(isTransitioning: true);

    return _createAndPlay(
      id: id,
      url: url,
      feature: feature,
      epoch: epoch,
      muteInitially: muteInitially,
      startAt: startAt,
    );
  }

  BetterPlayerConfiguration _configurationForFeature(
    VideoEngineFeature feature,
    Duration startAt,
  ) {
    if (feature == VideoEngineFeature.reels) {
      return BetterPlayerConfiguration(
        aspectRatio: 9 / 16,
        fit: BoxFit.cover,
        autoPlay: false,
        looping: true,
        handleLifecycle: false,
        autoDispose: false,
        expandToFill: true,
        startAt: startAt > Duration.zero ? startAt : null,
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
      );
    }
    return BetterPlayerConfiguration(
      autoPlay: false,
      looping: false,
      handleLifecycle: false,
      autoDispose: false,
      fit: BoxFit.contain,
      startAt: startAt > Duration.zero ? startAt : null,
      controlsConfiguration: const BetterPlayerControlsConfiguration(
        showControls: false,
      ),
    );
  }

  BetterPlayerDataSource _dataSourceForFeature({
    required VideoEngineFeature feature,
    required String url,
  }) {
    if (feature == VideoEngineFeature.reels) {
      return BetterPlayerDataSource.network(
        url,
        useAsmsTracks: true,
        cacheConfiguration: longVideoNetworkCache(url),
        bufferingConfiguration: const BetterPlayerBufferingConfiguration(
          minBufferMs: 1500,
          maxBufferMs: 2000,
          bufferForPlaybackMs: 300,
          bufferForPlaybackAfterRebufferMs: 800,
        ),
      );
    }
    return BetterPlayerDataSource.network(
      url,
      cacheConfiguration: longVideoNetworkCache(url),
      bufferingConfiguration: const BetterPlayerBufferingConfiguration(
        minBufferMs: 10000,
        maxBufferMs: 30000,
        bufferForPlaybackMs: 800,
        bufferForPlaybackAfterRebufferMs: 2000,
      ),
    );
  }

  bool _featureMatchesCurrentConfig(VideoEngineFeature feature, VideoSlot _) {
    return state.activeFeature == feature;
  }

  Future<BetterPlayerController?> _freshCreate({
    required String id,
    required String url,
    required VideoEngineFeature feature,
    required int epoch,
    required bool muteInitially,
    required Duration startAt,
  }) async {
    if (epoch != _activeEpoch) {
      VideoEngineLogger.engine(
        'FRESH_ABORT_EPOCH epoch=$epoch currentEpoch=$_activeEpoch',
      );
      state = state.copyWith(isTransitioning: false);
      return null;
    }

    BetterPlayerController? controller;
    try {
      controller = BetterPlayerController(
        _configurationForFeature(feature, startAt),
      );
      await controller.setupDataSource(
        _dataSourceForFeature(feature: feature, url: url),
      );
      VideoEngineLogger.engine('FRESH_SETUP_DONE id=$id');
    } catch (e) {
      VideoEngineLogger.error('FRESH_CREATE_FAILED id=$id error=$e');
      try {
        controller?.dispose(forceDispose: true);
      } catch (_) {}
      state = state.copyWith(isTransitioning: false);
      return null;
    }

    if (epoch != _activeEpoch) {
      VideoEngineLogger.engine(
        'FRESH_ABORT_STALE_AFTER_SETUP epoch=$epoch currentEpoch=$_activeEpoch',
      );
      try {
        controller.dispose(forceDispose: true);
      } catch (_) {}
      state = state.copyWith(isTransitioning: false);
      return null;
    }

    final BetterPlayerController c = controller;
    final slot = VideoSlot(id: id, url: url, controller: c);
    state = state.copyWith(
      activeSlot: slot,
      isTransitioning: false,
    );
    _resetActivePauseCoalescing();

    try {
      await c.setVolume(muteInitially ? 0.0 : 1.0);
      await c.play();
      VideoEngineLogger.engine(
        'FRESH_PLAY_SUCCESS id=$id muteInitially=$muteInitially',
      );
    } catch (e) {
      VideoEngineLogger.error('FRESH_PLAY_FAILED id=$id error=$e');
    }

    return c;
  }

  Future<BetterPlayerController?> _createAndPlay({
    required String id,
    required String url,
    required VideoEngineFeature feature,
    required int epoch,
    required bool muteInitially,
    required Duration startAt,
  }) async {
    VideoEngineLogger.engine('CREATE_CONTROLLER id=$id url=$url');

    if (epoch != _activeEpoch) {
      VideoEngineLogger.engine(
        'CREATE_ABORT_BEFORE_INIT epoch=$epoch currentEpoch=$_activeEpoch',
      );
      state = state.copyWith(isTransitioning: false);
      return null;
    }

    final currentActive = state.activeSlot;
    late final BetterPlayerController controller;

    if (currentActive != null &&
        _featureMatchesCurrentConfig(feature, currentActive)) {
      VideoEngineLogger.engine(
        'REUSE_CONTROLLER id=${currentActive.id} → $id url=$url',
      );
      controller = currentActive.controller;

      try {
        await controller.seekTo(Duration.zero);
      } catch (_) {}

      try {
        await controller.pause();
      } catch (_) {}

      await Future<void>.delayed(const Duration(milliseconds: 32));

      if (epoch != _activeEpoch) {
        VideoEngineLogger.engine(
          'REUSE_ABORT_AFTER_FLUSH epoch=$epoch currentEpoch=$_activeEpoch',
        );
        state = state.copyWith(isTransitioning: false);
        return null;
      }

      state = state.copyWith(
        activeSlot: VideoSlot(id: id, url: url, controller: controller),
      );

      try {
        await controller.setupDataSource(
          _dataSourceForFeature(feature: feature, url: url),
        );
        VideoEngineLogger.engine('REUSE_SETUP_DONE id=$id');
        if (feature == VideoEngineFeature.longVideos &&
            startAt > Duration.zero) {
          try {
            await controller.seekTo(startAt);
          } catch (_) {}
        }
      } catch (e) {
        VideoEngineLogger.error('REUSE_SETUP_FAILED id=$id error=$e');
        state = state.copyWith(clearActive: true);
        _hardDispose(controller, label: 'reuse-failed');
        return _freshCreate(
          id: id,
          url: url,
          feature: feature,
          epoch: epoch,
          muteInitially: muteInitially,
          startAt: startAt,
        );
      }
    } else {
      if (currentActive != null) {
        VideoEngineLogger.engine('DISPOSE_PREV id=${currentActive.id}');
        state = state.copyWith(clearActive: true);
        _hardDispose(currentActive.controller, label: 'feature-change');
        await Future<void>.delayed(const Duration(milliseconds: 280));
        if (epoch != _activeEpoch) {
          VideoEngineLogger.engine(
            'CREATE_ABORT_STALE epoch=$epoch currentEpoch=$_activeEpoch',
          );
          state = state.copyWith(isTransitioning: false);
          return null;
        }
      }

      return _freshCreate(
        id: id,
        url: url,
        feature: feature,
        epoch: epoch,
        muteInitially: muteInitially,
        startAt: startAt,
      );
    }

    if (epoch != _activeEpoch) {
      VideoEngineLogger.engine(
        'CREATE_ABORT_STALE_AFTER_REUSE epoch=$epoch currentEpoch=$_activeEpoch',
      );
      state = state.copyWith(isTransitioning: false);
      return null;
    }

    state = state.copyWith(isTransitioning: false);
    _resetActivePauseCoalescing();

    try {
      await controller.setVolume(muteInitially ? 0.0 : 1.0);
      await controller.play();
      VideoEngineLogger.engine(
        'PLAY_SUCCESS id=$id muteInitially=$muteInitially',
      );
    } catch (e) {
      VideoEngineLogger.error('PLAY_FAILED id=$id error=$e');
    }

    return controller;
  }

  Future<void> pauseActive() async {
    final active = state.activeSlot;
    if (active == null) return;
    if (_isActivePaused) {
      VideoEngineLogger.engine(
        'PAUSE_ACTIVE_SKIP — already paused id=${active.id}',
      );
      return;
    }
    try {
      final vpc = active.controller.videoPlayerController;
      _volumeSnapshotBeforePause =
          (vpc?.value.volume ?? 1.0).clamp(0.0, 1.0);
      await active.controller.setVolume(0.0);
      await active.controller.pause();
      _isActivePaused = true;
      VideoEngineLogger.engine('PAUSE_ACTIVE id=${active.id}');
    } catch (e) {
      VideoEngineLogger.error('PAUSE_ACTIVE_FAILED error=$e');
    }
  }

  /// Pauses playback unless the active slot matches [id] (e.g. dominant tile).
  Future<void> pauseActiveUnless(String id) async {
    final active = state.activeSlot;
    if (active == null) return;
    if (active.id == id) return;
    await pauseActive();
  }

  Future<void> resumeActive() async {
    final active = state.activeSlot;
    if (active == null) return;
    _isActivePaused = false;
    try {
      await active.controller
          .setVolume(_volumeSnapshotBeforePause.clamp(0.0, 1.0));
      await active.controller.play();
      VideoEngineLogger.engine('RESUME_ACTIVE id=${active.id}');
    } catch (e) {
      VideoEngineLogger.error('RESUME_ACTIVE_FAILED error=$e');
    }
  }

  Future<void> setActiveVolume(double volume) async {
    final active = state.activeSlot;
    if (active == null) return;
    try {
      await active.controller.setVolume(volume);
    } catch (_) {}
  }

  Future<void> seekActive(Duration position) async {
    final active = state.activeSlot;
    if (active == null) return;
    try {
      await active.controller.seekTo(position);
    } catch (_) {}
  }

  BetterPlayerController? detachActiveForEmbedded() {
    final active = state.activeSlot;
    if (active == null) {
      VideoEngineLogger.engine('DETACH_ACTIVE — no active slot');
      return null;
    }
    VideoEngineLogger.engine('DETACH_ACTIVE id=${active.id}');
    state = state.copyWith(clearActive: true);
    _resetActivePauseCoalescing();
    return active.controller;
  }

  void acceptReturnedController({
    required String id,
    required String url,
    required BetterPlayerController controller,
  }) {
    VideoEngineLogger.engine('ACCEPT_RETURNED id=$id');
    final existing = state.activeSlot;
    if (existing != null) {
      state = state.copyWith(clearActive: true);
      _hardDispose(existing.controller, label: 'clear-active-for-return');
    }
    final slot = VideoSlot(
      id: id,
      url: url,
      controller: controller,
    );
    state = state.copyWith(activeSlot: slot);
    _resetActivePauseCoalescing();
  }

  void schedulePrefetch(String url, {Duration delay = const Duration(seconds: 3)}) {
    _prefetchTimer?.cancel();
    _prefetchTimer = Timer(delay, () => _doPrefetch(url));
  }

  Future<void> _doPrefetch(String url) async {
    if (url.isEmpty) return;
    if (_disposed) return;
    if (state.prefetchedUrl == url) {
      VideoEngineLogger.engine('PREFETCH_SKIP — already done url=$url');
      return;
    }
    VideoEngineLogger.engine('PREFETCH_START url=$url');
    try {
      final dio = Dio();
      await dio.get<String>(
        url,
        options: Options(
          responseType: ResponseType.plain,
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
      if (!_disposed) {
        state = state.copyWith(prefetchedUrl: url);
        VideoEngineLogger.engine('PREFETCH_DONE url=$url');
      }
    } catch (e) {
      VideoEngineLogger.engine(
        'PREFETCH_FAIL url=$url error=${e.runtimeType}',
      );
    }
  }

  Future<void> onAppPaused() async {
    VideoEngineLogger.engine('APP_PAUSED');
    _isActivePaused = false;
    await pauseActive();
  }

  Future<void> onAppResumed() async {
    VideoEngineLogger.engine('APP_RESUMED');
    await resumeActive();
  }

  Future<void> _disposeAll() async {
    _prefetchTimer?.cancel();

    final active = state.activeSlot;

    if (active != null) {
      _hardDispose(active.controller, label: 'dispose-all-active');
    }

    state = state.copyWith(
      clearActive: true,
      clearPrefetch: true,
      isTransitioning: false,
    );

    VideoEngineLogger.engine(
      'DISPOSE_ALL_DONE liveCount=${state.liveControllerCount}',
    );
    _resetActivePauseCoalescing();
  }

  /// Pause immediately; dispose after two post-frame callbacks so the
  /// [BetterPlayer] subtree can detach its surface before [MediaCodec] release.
  void _hardDispose(BetterPlayerController c, {String label = ''}) {
    VideoEngineLogger.engine('HARD_DISPOSE label=$label');
    try {
      c.pause();
    } catch (_) {}
    try {
      c.setVolume(0.0);
    } catch (_) {}
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          c.dispose(forceDispose: true);
        } catch (_) {}
      });
    });
  }

  /// Pause now; defer [dispose] to next frame when the widget tree may still
  /// reference the surface (e.g. engine [dispose] during teardown).
  void _safeDispose(BetterPlayerController c, {String label = ''}) {
    VideoEngineLogger.engine('SAFE_DISPOSE label=$label');
    try {
      c.pause();
    } catch (_) {}

    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        c.dispose(forceDispose: true);
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _activeEpoch++;
    _prefetchTimer?.cancel();
    final a = state.activeSlot?.controller;
    if (a != null) _safeDispose(a, label: 'engine-dispose-active');
    super.dispose();
  }
}
