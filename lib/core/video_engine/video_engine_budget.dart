/// Cross-feed cap on simultaneous [BetterPlayerController] instances.
///
/// Budget allocation:
/// - **Reels tab active:** 1 engine active + 2 reel warm neighbors = 3
/// - **Long videos tab active:** 1 reel standby + 1 LV engine active + 1 LV warm = 3
/// - **Embedded player:** all feed controllers released; player owns 1
class VideoEngineBudget {
  VideoEngineBudget._();

  static const int maxControllers = 3;

  /// Warm neighbors while the reels viewport is active (prev + next).
  static const int reelsWarmWhenActive = 2;

  /// Paused reel controller kept ready while the long-videos tab is open.
  static const int reelsStandbyWhenLongVideosTab = 1;

  /// Next-tile warm controller while the long-videos feed is active.
  /// Disabled: each warm ExoPlayer allocates an Android AudioTrack even when
  /// muted, which triggers AudioTrack init failures (-12 / -20) on device limits.
  /// Use [LongVideoHlsPrefetch] for next-tile buffering instead.
  static const int longVideosWarmWhenActive = 0;
}
