import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

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
    );
  }
}

/// Video player provider
final videoPlayerProvider = StateNotifierProvider.family<VideoPlayerNotifier, VideoPlayerState, String>(
  (ref, videoUrl) => VideoPlayerNotifier(videoUrl),
);

/// Video player notifier
class VideoPlayerNotifier extends StateNotifier<VideoPlayerState> {
  VideoPlayerNotifier(String videoUrl) : super(VideoPlayerState()) {
    _initializePlayer(videoUrl);
  }

  void _initializePlayer(String videoUrl) {
    final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
    controller.initialize().then((_) {
      state = state.copyWith(
        controller: controller,
        isInitialized: true,
        duration: controller.value.duration,
        isPlaying: controller.value.isPlaying,
      );
      controller.addListener(_videoListener);
      controller.play();
    });
  }

  void _videoListener() {
    if (state.controller != null && mounted) {
      state = state.copyWith(
        position: state.controller!.value.position,
        isPlaying: state.controller!.value.isPlaying,
      );
    }
  }

  void togglePlayPause() {
    if (state.controller == null || !state.isInitialized) return;
    if (state.isPlaying) {
      state.controller!.pause();
    } else {
      state.controller!.play();
    }
    state = state.copyWith(isPlaying: !state.isPlaying);
  }

  void seekForward() {
    if (state.controller == null || !state.isInitialized) return;
    final newPosition = state.position + const Duration(seconds: 10);
    final targetPosition = newPosition > state.duration ? state.duration : newPosition;
    state.controller!.seekTo(targetPosition);
    _showSeekFeedback('forward', targetPosition);
  }

  void seekBackward() {
    if (state.controller == null || !state.isInitialized) return;
    final newPosition = state.position - const Duration(seconds: 10);
    final targetPosition = newPosition < Duration.zero ? Duration.zero : newPosition;
    state.controller!.seekTo(targetPosition);
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

  @override
  void dispose() {
    state.controller?.dispose();
    super.dispose();
  }
}

