import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State for tracking currently playing video in long videos screen
class LongVideoPlaybackState {
  final String? currentlyPlayingVideoId;
  final Map<String, bool> showControls; // Track controls visibility per video
  final bool isAutoplayEnabled; // Whether autoplay is active
  final String? centerVideoId; // Video currently in the center of screen
  final bool isManualPlay; // Whether current play was triggered manually

  LongVideoPlaybackState({
    this.currentlyPlayingVideoId,
    Map<String, bool>? showControls,
    this.isAutoplayEnabled = true,
    this.centerVideoId,
    this.isManualPlay = false,
  }) : showControls = showControls ?? {};

  LongVideoPlaybackState copyWith({
    String? currentlyPlayingVideoId,
    Map<String, bool>? showControls,
    bool? isAutoplayEnabled,
    String? centerVideoId,
    bool? isManualPlay,
    bool clearCurrentlyPlaying = false,
    bool clearCenterVideo = false,
  }) {
    return LongVideoPlaybackState(
      currentlyPlayingVideoId: clearCurrentlyPlaying
          ? null
          : (currentlyPlayingVideoId ?? this.currentlyPlayingVideoId),
      showControls: showControls ?? this.showControls,
      isAutoplayEnabled: isAutoplayEnabled ?? this.isAutoplayEnabled,
      centerVideoId: clearCenterVideo ? null : (centerVideoId ?? this.centerVideoId),
      isManualPlay: isManualPlay ?? this.isManualPlay,
    );
  }
}

/// Notifier for managing video playback state in long videos screen
class LongVideoPlaybackNotifier extends StateNotifier<LongVideoPlaybackState> {
  LongVideoPlaybackNotifier() : super(LongVideoPlaybackState());

  /// Set the currently playing video ID
  void setCurrentlyPlaying(String? videoId) {
    try {
      state = state.copyWith(currentlyPlayingVideoId: videoId);
    } catch (e) {
      // Ignore errors if provider is disposed or element is defunct
    }
  }

  /// Clear currently playing video
  void clearCurrentlyPlaying() {
    try {
      state = state.copyWith(clearCurrentlyPlaying: true);
    } catch (e) {
      // Ignore errors if provider is disposed or element is defunct
    }
  }

  /// Check if a video is currently playing
  bool isVideoPlaying(String videoId) {
    return state.currentlyPlayingVideoId == videoId;
  }

  /// Set controls visibility for a video
  void setControlsVisibility(String videoId, bool visible) {
    try {
      final newShowControls = Map<String, bool>.from(state.showControls);
      newShowControls[videoId] = visible;
      state = state.copyWith(showControls: newShowControls);
    } catch (e) {
      // Ignore errors if provider is disposed or element is defunct
    }
  }

  /// Get controls visibility for a video
  bool getControlsVisibility(String videoId) {
    return state.showControls[videoId] ?? true;
  }

  /// Enable autoplay
  void enableAutoplay() {
    state = state.copyWith(isAutoplayEnabled: true, isManualPlay: false);
  }

  /// Disable autoplay (when user manually plays a video)
  void disableAutoplay() {
    try {
      state = state.copyWith(isAutoplayEnabled: false, isManualPlay: true);
    } catch (e) {
      // Ignore errors if provider is disposed or element is defunct
    }
  }

  /// Set the center video ID (for autoplay)
  void setCenterVideo(String? videoId) {
    state = state.copyWith(centerVideoId: videoId);
  }

  /// Clear center video
  void clearCenterVideo() {
    state = state.copyWith(clearCenterVideo: true);
  }
}

/// Provider for long video playback state
final longVideoPlaybackProvider =
    StateNotifierProvider<LongVideoPlaybackNotifier, LongVideoPlaybackState>(
  (ref) => LongVideoPlaybackNotifier(),
);

/// Convenience provider to check if a video is playing
final isVideoPlayingProvider = Provider.family<bool, String>((ref, videoId) {
  return ref.watch(longVideoPlaybackProvider).currentlyPlayingVideoId == videoId;
});

