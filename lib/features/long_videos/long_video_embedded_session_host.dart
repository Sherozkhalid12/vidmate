import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/post_model.dart';
import '../../core/providers/long_video_cold_start_intent_provider.dart';
import '../video/video_player_screen.dart';
import 'providers/long_video_widget_provider.dart';

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
    final url = next.videoUrl?.trim() ?? '';
    if (url.isEmpty) return;
    final prev = _post;
    final prevUrl = prev.videoUrl?.trim() ?? '';
    if (prevUrl.isNotEmpty) {
      ref.read(longVideoWidgetProvider(VideoWidgetKey(prev.id, prevUrl)).notifier).setEmbeddedOpen(false);
    }

    ref.read(longVideoColdStartIntentProvider.notifier).state =
        LongVideoColdStartEmbeddedIntent(url);

    // Do not call [warmUp] on the feed tile here: it spins up a second BetterPlayer
    // while [VideoPlayerScreen] creates another for the same URL → MTK pipeline
    // overload, buffering, and UI jank.

    if (!mounted) return;
    setState(() => _post = next);
  }

  @override
  Widget build(BuildContext context) {
    final url = _post.videoUrl?.trim() ?? '';
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
