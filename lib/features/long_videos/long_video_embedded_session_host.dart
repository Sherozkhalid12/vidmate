import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/long_video_logger.dart';
import '../../core/models/post_model.dart';
import '../../core/providers/long_video_cold_start_intent_provider.dart';
import '../../core/providers/long_video_embedded_handoff_provider.dart';
import '../../core/providers/video_player_provider.dart';
import '../video/video_player_screen.dart';
import 'providers/long_video_widget_provider.dart';

String _longVideoPlayableUrl(PostModel p) {
  final u = p.videoUrl?.trim();
  if (u != null && u.isNotEmpty) return u;
  return (p.videoResolutions['360p'] ?? p.videoMasterUrl ?? '').trim();
}

/// Holds one embedded long-video session so switching **Suggested** updates
/// [VideoPlayerScreen] in place (same route / stable surface lifecycle) instead of
/// [Navigator.pushReplacement], which repeatedly tore down ExoPlayer and flooded
/// GPU allocators on some Mali devices.
///
/// Opening from the long-video **feed** still uses the same [VideoPlayerScreen]
/// and handoff logic; only the suggestion list uses [onSuggestedLongVideoSelected].
class LongVideoEmbeddedSessionHost extends ConsumerStatefulWidget {
  const LongVideoEmbeddedSessionHost({super.key, required this.post});

  final PostModel post;

  @override
  ConsumerState<LongVideoEmbeddedSessionHost> createState() =>
      _LongVideoEmbeddedSessionHostState();
}

class _LongVideoEmbeddedSessionHostState
    extends ConsumerState<LongVideoEmbeddedSessionHost> {
  /// Must stay constant across suggestion taps so [VideoPlayerScreen] is updated
  /// in place ([didUpdateWidget]). A per-video [ValueKey] recreates the screen,
  /// disposes the whole BetterPlayer subtree, and hammers ExoPlayer/surface
  /// teardown on MTK (BufferQueue abandoned, UI jank).
  static const ValueKey<String> _kEmbeddedPlayer =
      ValueKey<String>('long_video_embedded_session_player');

  late PostModel _post;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
  }

  Future<void> _switchTo(PostModel next) async {
    if (_longVideoPlayableUrl(next) == _longVideoPlayableUrl(_post)) return;
    final url = _longVideoPlayableUrl(next);
    if (url.isEmpty) return;
    LongVideoLogger.handoff(
      'suggested switch to postId=${next.id} url=$url',
    );
    final prev = _post;
    final prevUrl = prev.videoUrl?.trim() ?? '';
    final prevPlayable = _longVideoPlayableUrl(prev);

    // Step 1: old feed tile exits embedded mode.
    if (prevUrl.isNotEmpty) {
      try {
        ref
            .read(longVideoWidgetProvider(VideoWidgetKey(prev.id, prevUrl)).notifier)
            .setEmbeddedOpen(false);
      } catch (_) {}
    }

    // Step 2: pause previous embedded session (autoDispose drops the old family
    // slot once [VideoPlayerScreen] stops watching it).
    if (prevPlayable.isNotEmpty) {
      try {
        final oldNotifier = ref.read(videoPlayerProvider(
                videoPlayerKeyLongForm(prevPlayable, postId: prev.id))
            .notifier);
        await oldNotifier.pause();
      } catch (_) {}
    }

    // Step 3: set cold-start intent for the incoming URL.
    ref.read(longVideoColdStartIntentProvider.notifier).state =
        LongVideoColdStartEmbeddedIntent(url);
    ref.read(longVideoEmbedResumeHintProvider.notifier).state =
        LongVideoEmbedResumeHint(
      videoUrl: url,
      position: Duration.zero,
      forceStartFromZero: true,
    );

    LongVideoLogger.handoff('suggested switch: cold start url=$url');
    ref.read(longVideoEmbeddedHandoffProvider.notifier).state = null;

    await Future<void>.delayed(const Duration(milliseconds: 30));
    if (!mounted) return;
    setState(() => _post = next);
  }

  @override
  Widget build(BuildContext context) {
    final url = _longVideoPlayableUrl(_post);
    return VideoPlayerScreen(
      key: _kEmbeddedPlayer,
      videoUrl: url,
      title: _post.caption,
      author: _post.author,
      post: _post,
      onSuggestedLongVideoSelected: (p) {
        unawaited(_switchTo(p));
      },
    );
  }
}
