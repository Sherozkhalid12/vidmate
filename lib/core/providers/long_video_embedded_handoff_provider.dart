// NOTE: LongVideoInlineHandoff and longVideoEmbeddedHandoffProvider are
// optional BetterPlayer handoff hooks for opening VideoPlayerScreen with resume
// hints. Wire only when using inline BetterPlayer + separate embedded player.

import 'package:better_player/better_player.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One-shot resume time when opening [VideoPlayerScreen] from the long-videos
/// inline tile (new route seeks here).
class LongVideoEmbedResumeHint {
  final String videoUrl;
  final Duration position;

  const LongVideoEmbedResumeHint({
    required this.videoUrl,
    required this.position,
  });
}

/// Set immediately before pushing embedded route; cleared after consume or in
/// [LongVideosScreen] when the route is popped.
final longVideoEmbedResumeHintProvider =
    StateProvider<LongVideoEmbedResumeHint?>((ref) => null);

/// One-shot transfer of the inline long-video [BetterPlayerController] into
/// [VideoPlayerScreen] so the embedded player reuses the same decoder/buffer.
class LongVideoInlineHandoff {
  final String videoUrl;
  final BetterPlayerController controller;
  final Duration position;
  final bool resumePlayback;

  const LongVideoInlineHandoff({
    required this.videoUrl,
    required this.controller,
    required this.position,
    required this.resumePlayback,
  });
}

/// Cleared when consumed by [VideoPlayerNotifier] or on failed navigation.
final longVideoEmbeddedHandoffProvider =
    StateProvider<LongVideoInlineHandoff?>((ref) => null);

/// When non-null, [VideoPlayerNotifier] may return the handed-off
/// [BetterPlayerController] to this feed tile on route pop instead of disposing it.
class LongVideoFeedReturnTarget {
  final String videoId;
  final String videoUrl;

  const LongVideoFeedReturnTarget({
    required this.videoId,
    required this.videoUrl,
  });
}

final longVideoFeedReturnTargetProvider =
    StateProvider<LongVideoFeedReturnTarget?>((ref) => null);
