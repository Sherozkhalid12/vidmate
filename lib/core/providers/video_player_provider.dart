import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:better_player/better_player.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  return VideoPlayerNotifier(videoUrl);
});

/// Video player notifier (BetterPlayer for HLS support).
class VideoPlayerNotifier extends StateNotifier<VideoPlayerState> {
  final String videoUrl;
  Timer? _progressSaveTimer;
  void Function(BetterPlayerEvent)? _eventListener;
  bool _disposed = false;

  VideoPlayerNotifier(this.videoUrl) : super(VideoPlayerState()) {
    _initializePlayer(videoUrl);
  }

  Future<void> _initializePlayer(String url) async {
    try {
      final savedPosition = await _loadSavedProgress(url);

      final dataSource = BetterPlayerDataSource.network(url);

      final config = BetterPlayerConfiguration(
        autoPlay: false,
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

      if (savedPosition > Duration.zero) {
        await controller.seekTo(savedPosition);
      }

      if (!_disposed) {
        _eventListener = (BetterPlayerEvent event) {
          if (_disposed) return;
          try {
            if (event.betterPlayerEventType == BetterPlayerEventType.initialized) {
              final dur = controller.videoPlayerController?.value.duration ?? Duration.zero;
              if (savedPosition > Duration.zero && savedPosition < dur) {
                controller.seekTo(savedPosition);
              }
              if (!_disposed) {
                state = state.copyWith(isInitialized: true, duration: dur);
              }
            } else if (event.betterPlayerEventType == BetterPlayerEventType.play) {
              if (!_disposed) {
                state = state.copyWith(isPlaying: true);
              }
            } else if (event.betterPlayerEventType == BetterPlayerEventType.pause) {
              if (!_disposed) {
                state = state.copyWith(isPlaying: false);
              }
            } else if (event.betterPlayerEventType == BetterPlayerEventType.finished) {
              // Video completed - pause and reset to beginning
              if (!_disposed) {
                try {
                  controller.pause();
                  controller.seekTo(Duration.zero);
                  state = state.copyWith(isPlaying: false, position: Duration.zero);
                } catch (_) {
                  // Controller might be disposed
                }
              }
            }
          } catch (e) {
            // Event listener error - controller might be disposed
            if (!_disposed) {
              state = state.copyWith(controller: null, isDisposed: true, clearController: true);
            }
          }
        };
        controller.addEventsListener(_eventListener!);

        state = state.copyWith(
          controller: controller,
          isInitialized: controller.isVideoInitialized() ?? false,
          duration: controller.videoPlayerController?.value.duration ?? Duration.zero,
          isPlaying: false,
        );

        _startProgressSaving();
        _startPositionSync(controller);
      } else {
        controller.dispose();
      }
    } catch (e) {
      if (!_disposed) {
        state = state.copyWith(isInitialized: false);
      }
    }
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

  void togglePlayPause() {
    if (!state.hasValidController || !state.isInitialized || _disposed) return;
    try {
      if (state.isPlaying) {
        state.controller!.pause();
        state = state.copyWith(isPlaying: false);
      } else {
        state.controller!.play();
        state = state.copyWith(isPlaying: true);
      }
    } catch (e) {
      // Controller was disposed, clear it from state
      state = state.copyWith(controller: null, isDisposed: true, clearController: true);
    }
  }

  void play() {
    if (!state.hasValidController || !state.isInitialized || _disposed) return;
    try {
      if (!state.isPlaying) {
        state.controller!.play();
        state = state.copyWith(isPlaying: true);
      }
    } catch (e) {
      // Controller was disposed, clear it from state
      state = state.copyWith(controller: null, isDisposed: true, clearController: true);
    }
  }

  void pause() {
    if (!state.hasValidController || !state.isInitialized || _disposed) return;
    try {
      if (state.isPlaying) {
        state.controller!.pause();
        state = state.copyWith(isPlaying: false);
      }
    } catch (e) {
      // Controller was disposed, clear it from state
      state = state.copyWith(controller: null, isDisposed: true, clearController: true);
    }
  }

  void seekForward() {
    if (!state.hasValidController || !state.isInitialized || _disposed) return;
    try {
      final newPosition = state.position + const Duration(seconds: 10);
      final target = newPosition > state.duration ? state.duration : newPosition;
      state.controller!.seekTo(target);
      state = state.copyWith(
        showSeekIndicator: true,
        seekDirection: 'forward',
        seekTarget: target,
      );
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!_disposed) {
          state = state.copyWith(showSeekIndicator: false);
        }
      });
    } catch (e) {
      // Controller was disposed
      state = state.copyWith(controller: null, isDisposed: true, clearController: true);
    }
  }

  void seekBackward() {
    if (!state.hasValidController || !state.isInitialized || _disposed) return;
    try {
      final newPosition = state.position - const Duration(seconds: 10);
      final target = newPosition < Duration.zero ? Duration.zero : newPosition;
      final wasPlaying = state.isPlaying;
      state.controller!.seekTo(target);
      if (wasPlaying) state.controller!.play();
      state = state.copyWith(
        showSeekIndicator: true,
        seekDirection: 'backward',
        seekTarget: target,
      );
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!_disposed) {
          state = state.copyWith(showSeekIndicator: false);
        }
      });
    } catch (e) {
      // Controller was disposed
      state = state.copyWith(controller: null, isDisposed: true, clearController: true);
    }
  }

  void toggleControls() {
    state = state.copyWith(showControls: !state.showControls);
  }

  void toggleFullscreen() {
    state = state.copyWith(isFullscreen: !state.isFullscreen);
  }

  void seekTo(Duration position) {
    if (!state.hasValidController || !state.isInitialized || _disposed) return;
    try {
      state.controller!.seekTo(position);
      state = state.copyWith(position: position);
    } catch (e) {
      // Controller was disposed
      state = state.copyWith(controller: null, isDisposed: true, clearController: true);
    }
  }

  Future<void> setPlaybackSpeed(double speed) async {
    if (!state.hasValidController || !state.isInitialized || _disposed) return;
    try {
      await state.controller!.setSpeed(speed);
      state = state.copyWith(playbackSpeed: speed, showPlaybackSpeedMenu: false);
    } catch (e) {
      // Controller was disposed
      state = state.copyWith(controller: null, isDisposed: true, clearController: true);
    }
  }

  void togglePlaybackSpeedMenu() {
    state = state.copyWith(showPlaybackSpeedMenu: !state.showPlaybackSpeedMenu);
  }

  Future<void> clearSavedProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('video_progress_${videoUrl.hashCode}');
    } catch (_) {}
  }

  @override
  void dispose() {
    _disposed = true;
    _progressSaveTimer?.cancel();
    _positionSyncTimer?.cancel();
    
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
      try {
        // Remove event listener first
        if (_eventListener != null) {
          try {
            controller.removeEventsListener(_eventListener!);
          } catch (_) {
            // Listener might already be removed
          }
        }
        // Pause if playing
        try {
          if (controller.isPlaying() == true) {
            controller.pause();
          }
        } catch (_) {
          // Controller might already be disposed
        }
        // Dispose controller
        controller.dispose();
      } catch (_) {
        // Controller might already be disposed, ignore
      }
    }
    super.dispose();
  }
}
