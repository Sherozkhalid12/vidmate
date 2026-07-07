import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/post_model.dart';
import '../providers/home_feed_playback_provider_riverpod.dart';
import '../video_engine/video_engine_provider.dart';
import '../../features/long_videos/long_video_embedded_session_host.dart';
import '../../features/reels/reels_screen.dart';
import '../../features/video/video_player_screen.dart';

/// Opens a reel viewer and ensures playback stops when returning.
Future<void> openReelViewer(
  BuildContext context,
  WidgetRef ref, {
  PostModel? prependedReel,
  String? initialPostId,
}) async {
  final engine = ref.read(globalVideoEngineProvider.notifier);
  ref.read(homeFeedActiveReelIdProvider.notifier).state = null;
  await engine.pauseActive();
  if (!context.mounted) return;

  final handoffId = prependedReel?.id ?? initialPostId;
  if (handoffId != null && handoffId.isNotEmpty) {
    ref.read(homeFeedReelHandoffIdProvider.notifier).state = handoffId;
  }

  await Navigator.push<void>(
    context,
    MaterialPageRoute<void>(
      builder: (_) => ReelsScreen(
        prependedReel: prependedReel,
        initialPostId: initialPostId,
      ),
    ),
  );

  ref.read(homeFeedReelHandoffIdProvider.notifier).state = null;
  ref.read(homeFeedActiveReelIdProvider.notifier).state = null;
  await engine.pauseActive();
}

/// Opens a long-form video player and ensures playback stops when returning.
Future<void> openLongVideoViewer(
  BuildContext context,
  WidgetRef ref,
  PostModel video,
) async {
  final videoUrl = video.videoUrl?.trim() ?? '';
  if (videoUrl.isEmpty) return;

  final engine = ref.read(globalVideoEngineProvider.notifier);
  ref.read(homeFeedActiveReelIdProvider.notifier).state = null;
  await engine.pauseActive();
  if (!context.mounted) return;

  await Navigator.push<void>(
    context,
    MaterialPageRoute<void>(
      builder: (_) => video.postType == 'longVideo'
          ? LongVideoEmbeddedSessionHost(post: video)
          : VideoPlayerScreen(
              videoUrl: videoUrl,
              title: video.caption,
              author: video.author,
              post: video,
            ),
    ),
  );

  ref.read(homeFeedActiveReelIdProvider.notifier).state = null;
  await engine.pauseActive();
}
