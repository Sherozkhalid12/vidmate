import 'package:better_player/better_player.dart';

enum VideoEngineFeature { none, reels, longVideos }

class VideoSlot {
  final String id; // unique slot id (e.g. videoId or reelId)
  final String url; // the datasource URL being played
  final BetterPlayerController controller;

  const VideoSlot({
    required this.id,
    required this.url,
    required this.controller,
  });
}

class GlobalVideoEngineState {
  final VideoSlot? activeSlot;
  final VideoEngineFeature activeFeature;
  final bool isTransitioning;
  final String? prefetchedUrl; // URL that has been network-prefetched

  const GlobalVideoEngineState({
    this.activeSlot,
    this.activeFeature = VideoEngineFeature.none,
    this.isTransitioning = false,
    this.prefetchedUrl,
  });

  /// Engine active + feed warm/standby slots (owned outside the engine).
  /// Global budget is [VideoEngineBudget.maxControllers] across all feeds.
  int get liveControllerCount => activeSlot != null ? 1 : 0;

  bool get hasActive => activeSlot != null;

  GlobalVideoEngineState copyWith({
    VideoSlot? activeSlot,
    VideoEngineFeature? activeFeature,
    bool? isTransitioning,
    String? prefetchedUrl,
    bool clearActive = false,
    bool clearPrefetch = false,
  }) {
    return GlobalVideoEngineState(
      activeSlot: clearActive ? null : (activeSlot ?? this.activeSlot),
      activeFeature: activeFeature ?? this.activeFeature,
      isTransitioning: isTransitioning ?? this.isTransitioning,
      prefetchedUrl:
          clearPrefetch ? null : (prefetchedUrl ?? this.prefetchedUrl),
    );
  }
}
