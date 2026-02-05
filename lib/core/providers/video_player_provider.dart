import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Video player state
class VideoPlayerState {
  final VideoPlayerController? controller;
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
  });

  VideoPlayerState copyWith({
    VideoPlayerController? controller,
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
  }) {
    return VideoPlayerState(
      controller: controller ?? this.controller,
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
    );
  }
}

/// Video player provider - auto-disposes when not watched
final videoPlayerProvider = StateNotifierProvider.autoDispose
    .family<VideoPlayerNotifier, VideoPlayerState, String>((ref, videoUrl) {
      final notifier = VideoPlayerNotifier(videoUrl);

      // Ensure proper disposal when provider is no longer watched
      ref.onDispose(() {
        // The notifier's dispose will be called automatically, but we can add cleanup here if needed
      });

      return notifier;
    });

/// Video player notifier
class VideoPlayerNotifier extends StateNotifier<VideoPlayerState> {
  final String videoUrl;
  Timer? _progressSaveTimer;

  VideoPlayerNotifier(this.videoUrl) : super(VideoPlayerState()) {
    _initializePlayer(videoUrl);
  }

  Future<void> _initializePlayer(String videoUrl) async {
    try {
      // Try to load saved progress
      final savedPosition = await _loadSavedProgress(videoUrl);

      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));

      await controller.initialize();

      // Restore saved position if available
      if (savedPosition > Duration.zero &&
          savedPosition < controller.value.duration) {
        await controller.seekTo(savedPosition);
      }

      // Set initial playback speed
      await controller.setPlaybackSpeed(state.playbackSpeed);

      if (mounted) {
        state = state.copyWith(
          controller: controller,
          isInitialized: true,
          duration: controller.value.duration,
          isPlaying: false, // Don't auto-play - let UI control it
        );
        controller.addListener(_videoListener);
        // Don't auto-play - the screen will control when to play
        // This prevents videos from running in background

        // Start periodic progress saving
        _startProgressSaving();
      } else {
        // If not mounted, dispose immediately to prevent background playback
        try {
          controller.pause();
          controller.dispose();
        } catch (e) {
          // Ignore errors
        }
      }
    } catch (e) {
      // Handle initialization error
      if (mounted) {
        state = state.copyWith(isInitialized: false);
      }
    }
  }

  void _videoListener() {
    // Only update if mounted and controller exists
    if (!mounted || state.controller == null) return;

    try {
      final value = state.controller!.value;
      if (mounted) {
        state = state.copyWith(
          position: value.position,
          isPlaying: value.isPlaying,
          isBuffering: value.isBuffering,
          duration: value.duration,
        );
      }
    } catch (e) {
      // Ignore errors if widget is disposed
    }
  }

  void _startProgressSaving() {
    _progressSaveTimer?.cancel();
    _progressSaveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _saveProgress();
    });
  }

  Future<void> _saveProgress() async {
    if (state.controller == null || !state.isInitialized) return;
    if (state.position < const Duration(seconds: 5))
      return; // Don't save if less than 5 seconds

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'video_progress_${videoUrl.hashCode}';
      await prefs.setInt(key, state.position.inSeconds);
    } catch (e) {
      // Silently handle save errors
    }
  }

  Future<Duration> _loadSavedProgress(String videoUrl) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'video_progress_${videoUrl.hashCode}';
      final seconds = prefs.getInt(key);
      if (seconds != null && seconds > 0) {
        return Duration(seconds: seconds);
      }
    } catch (e) {
      // Silently handle load errors
    }
    return Duration.zero;
  }

  void togglePlayPause() {
    if (state.controller == null || !state.isInitialized || !mounted) return;
    if (state.isPlaying) {
      state.controller!.pause();
      state = state.copyWith(isPlaying: false);
    } else {
      state.controller!.play();
      state = state.copyWith(isPlaying: true);
    }
  }

  void play() {
    if (state.controller == null || !state.isInitialized || !mounted) return;
    if (!state.isPlaying) {
      state.controller!.play();
      state = state.copyWith(isPlaying: true);
    }
  }

  void pause() {
    if (state.controller == null || !state.isInitialized || !mounted) return;
    if (state.isPlaying) {
      state.controller!.pause();
      state = state.copyWith(isPlaying: false);
    }
  }

  void seekForward() {
    if (state.controller == null || !state.isInitialized) return;
    final newPosition = state.position + const Duration(seconds: 10);
    final targetPosition = newPosition > state.duration
        ? state.duration
        : newPosition;
    state.controller!.seekTo(targetPosition);
    _showSeekFeedback('forward', targetPosition);
  }

  void seekBackward() {
    if (state.controller == null || !state.isInitialized) return;
    final newPosition = state.position - const Duration(seconds: 10);
    final targetPosition = newPosition < Duration.zero
        ? Duration.zero
        : newPosition;
    // Seek without pausing - maintain play state
    final wasPlaying = state.isPlaying;
    state.controller!.seekTo(targetPosition);
    // Ensure video continues playing if it was playing before
    if (wasPlaying && !state.controller!.value.isPlaying) {
      state.controller!.play();
    }
    _showSeekFeedback('backward', targetPosition);
  }

  void _showSeekFeedback(String direction, Duration target) {
    state = state.copyWith(
      showSeekIndicator: true,
      seekDirection: direction,
      seekTarget: target,
    );
    Future.delayed(const Duration(milliseconds: 800), () {
      state = state.copyWith(showSeekIndicator: false);
    });
  }

  void toggleControls() {
    state = state.copyWith(showControls: !state.showControls);
  }

  void toggleFullscreen() {
    state = state.copyWith(isFullscreen: !state.isFullscreen);
  }

  void seekTo(Duration position) {
    if (state.controller == null || !state.isInitialized) return;
    state.controller!.seekTo(position);
    state = state.copyWith(position: position);
  }

  void setPlaybackSpeed(double speed) async {
    if (state.controller == null || !state.isInitialized) return;
    try {
      await state.controller!.setPlaybackSpeed(speed);
      state = state.copyWith(
        playbackSpeed: speed,
        showPlaybackSpeedMenu: false,
      );
    } catch (e) {
      // Handle error
    }
  }

  void togglePlaybackSpeedMenu() {
    state = state.copyWith(showPlaybackSpeedMenu: !state.showPlaybackSpeedMenu);
  }

  void clearSavedProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'video_progress_${videoUrl.hashCode}';
      await prefs.remove(key);
    } catch (e) {
      // Silently handle errors
    }
  }

  @override
  void dispose() {
    _progressSaveTimer?.cancel();
    _saveProgress(); // Save one last time before disposing

    // Properly dispose the video controller
    final controller = state.controller;
    if (controller != null) {
      try {
        // Remove listener first to prevent callbacks during disposal
        controller.removeListener(_videoListener);

        // Force pause if playing (critical to stop background playback)
        if (controller.value.isInitialized) {
          try {
            if (controller.value.isPlaying) {
              controller.pause();
            }
          } catch (e) {
            // Ignore pause errors
          }
        }

        // Dispose the controller
        controller.dispose();
      } catch (e) {
        // Ignore errors during disposal
      }

      // Clear controller from state
      state = state.copyWith(controller: null);
    }

    super.dispose();
  }
}
