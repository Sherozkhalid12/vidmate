import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

/// Per-widget video player state for long videos
/// Uses both videoUrl and widgetId to create unique instances
class LongVideoWidgetState {
  final VideoPlayerController? controller;
  final bool isPlaying;
  final bool isInitialized;
  final Duration duration;
  final Duration position;
  final bool showControls;
  final bool isSeeking; // Track seeking state to prevent thumbnail flashing
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
    VideoPlayerController? controller,
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

/// Unique key for per-widget video players
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

/// Per-widget video player provider - each widget gets its own instance
final longVideoWidgetProvider = StateNotifierProvider.autoDispose
    .family<LongVideoWidgetNotifier, LongVideoWidgetState, VideoWidgetKey>(
  (ref, key) {
    final notifier = LongVideoWidgetNotifier(key.widgetId, key.videoUrl);
    
    // Cleanup on dispose
    ref.onDispose(() {
      // Notifier's dispose will be called automatically
    });
    
    return notifier;
  },
);

/// Notifier for per-widget video player
class LongVideoWidgetNotifier extends StateNotifier<LongVideoWidgetState> {
  final String widgetId;
  final String videoUrl;
  Timer? _positionUpdateTimer;
  bool _isInitializing = false;

  LongVideoWidgetNotifier(this.widgetId, this.videoUrl)
      : super(LongVideoWidgetState(widgetId: widgetId, videoUrl: videoUrl)) {
    // DO NOT auto-initialize - only initialize when user wants to play
    // This prevents black screens and unnecessary resource usage
  }

  /// Lazy initialization - only called when user wants to play
  Future<void> _initializePlayer() async {
    // Prevent multiple simultaneous initializations
    if (_isInitializing || state.isInitialized) return;
    
    _isInitializing = true;
    
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      await controller.initialize();

      if (mounted) {
        state = state.copyWith(
          controller: controller,
          isInitialized: true,
          duration: controller.value.duration,
          isPlaying: false, // Don't auto-play
        );
        
        // Add listener for position updates
        controller.addListener(_videoListener);
      } else {
        // If not mounted, dispose immediately
        controller.dispose();
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isInitialized: false);
      }
    } finally {
      _isInitializing = false;
    }
  }

  void _videoListener() {
    if (!mounted || state.controller == null) return;

    try {
      final value = state.controller!.value;
      if (mounted) {
        state = state.copyWith(
          position: value.position,
          isPlaying: value.isPlaying,
          duration: value.duration,
        );
      }
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> play() async {
    if (!mounted) return;
    
    // Lazy initialization: Initialize player if not already initialized
    if (!state.isInitialized) {
      await _initializePlayer();
      // After initialization, check again if mounted and initialized
      if (!mounted || !state.isInitialized || state.controller == null) return;
    }
    
    if (state.controller == null || !state.isInitialized) return;
    
    try {
      await state.controller!.play();
      if (mounted) {
        state = state.copyWith(isPlaying: true);
      }
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> pause() async {
    if (state.controller == null || !state.isInitialized || !mounted) return;
    
    try {
      await state.controller!.pause();
      // Double-check mounted after async operation
      if (mounted) {
        state = state.copyWith(isPlaying: false);
      }
    } catch (e) {
      // Ignore errors - widget might be disposed
    }
  }

  Future<void> togglePlayPause() async {
    if (state.isPlaying) {
      pause();
    } else {
      await play();
    }
  }

  Future<void> seekForward() async {
    if (state.controller == null || !state.isInitialized || !mounted) return;
    
    // Set seeking state to prevent thumbnail flashing
    if (mounted) {
      state = state.copyWith(isSeeking: true);
    }
    
    try {
      final newPosition = state.position + const Duration(seconds: 10);
      final targetPosition = newPosition > state.duration ? state.duration : newPosition;
      await state.controller!.seekTo(targetPosition);
      
      // Clear seeking state after seek completes
      if (mounted) {
        state = state.copyWith(isSeeking: false);
      }
    } catch (e) {
      // Clear seeking state on error
      if (mounted) {
        state = state.copyWith(isSeeking: false);
      }
    }
  }

  Future<void> seekBackward() async {
    if (state.controller == null || !state.isInitialized || !mounted) return;
    
    // Set seeking state to prevent thumbnail flashing
    if (mounted) {
      state = state.copyWith(isSeeking: true);
    }
    
    try {
      final newPosition = state.position - const Duration(seconds: 10);
      final targetPosition = newPosition < Duration.zero ? Duration.zero : newPosition;
      await state.controller!.seekTo(targetPosition);
      
      // Clear seeking state after seek completes
      if (mounted) {
        state = state.copyWith(isSeeking: false);
      }
    } catch (e) {
      // Clear seeking state on error
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
    _positionUpdateTimer?.cancel();
    
    final controller = state.controller;
    if (controller != null) {
      try {
        controller.removeListener(_videoListener);
        
        if (controller.value.isInitialized && controller.value.isPlaying) {
          controller.pause();
        }
        
        controller.dispose();
      } catch (e) {
        // Ignore errors
      }
    }
    
    super.dispose();
  }
}

