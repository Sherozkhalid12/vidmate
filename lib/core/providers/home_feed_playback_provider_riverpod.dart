import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/post_model.dart';
import '../video_engine/global_video_engine_state.dart';
import '../video_engine/video_engine_provider.dart';
import 'reels_provider_riverpod.dart';

/// Post id of the home-feed reel tile that is most visible (for auto-play).
final homeFeedActiveReelIdProvider = StateProvider<String?>((ref) => null);

/// Set while navigating from home feed to [ReelsScreen] so playback is not paused.
final homeFeedReelHandoffIdProvider = StateProvider<String?>((ref) => null);

/// Preview URL of the feed post whose attached music should auto-play.
final feedActiveMusicPreviewUrlProvider = StateProvider<String?>((ref) => null);

/// Drives [GlobalVideoEngine] for the visible home-feed reel (tab 0).
final homeFeedReelEngineBinderProvider = Provider<void>((ref) {
  ref.listen<String?>(homeFeedActiveReelIdProvider, (previous, next) async {
    final engine = ref.read(globalVideoEngineProvider.notifier);
    if (next == null || next.isEmpty) {
      final handoff = ref.read(homeFeedReelHandoffIdProvider);
      if (handoff != null && handoff.isNotEmpty) {
        return;
      }
      await engine.pauseActive();
      return;
    }

    PostModel? reel;
    for (final r in ref.read(reelsListProvider)) {
      if (r.id == next) {
        reel = r;
        break;
      }
    }
    if (reel == null) {
      for (final p in ref.read(reelsProvider).reels) {
        if (p.id == next) {
          reel = p;
          break;
        }
      }
    }

    final url = (reel?.videoMasterUrl ?? reel?.videoUrl ?? '').trim();
    if (reel == null || url.isEmpty) return;

    if (ref.read(globalVideoEngineProvider).activeFeature !=
        VideoEngineFeature.reels) {
      await engine.activateFeature(VideoEngineFeature.reels);
    }
    await engine.play(
      id: reel.id,
      url: url,
      feature: VideoEngineFeature.reels,
      muteInitially: false,
    );
  });
});

/// After returning from fullscreen reels, pause and clear stale active id so
/// off-screen tiles cannot keep playing when visibility events were skipped.
final homeFeedReelHandoffReturnSyncProvider = Provider<void>((ref) {
  ref.listen<String?>(homeFeedReelHandoffIdProvider, (previous, next) async {
    if (previous == null || previous.isEmpty) return;
    if (next != null && next.isNotEmpty) return;

    await ref.read(globalVideoEngineProvider.notifier).pauseActive();
    if (ref.read(homeFeedActiveReelIdProvider) != null) {
      ref.read(homeFeedActiveReelIdProvider.notifier).state = null;
    }
  });
});
