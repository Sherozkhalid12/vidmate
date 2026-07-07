import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message_bubble.dart';
import '../models/post_model.dart';
import '../providers/posts_provider_riverpod.dart';
import '../providers/reels_provider_riverpod.dart';
import '../utils/theme_helper.dart';
import '../video_engine/video_engine_provider.dart';
import '../../features/long_videos/long_videos_page.dart';
import '../../features/profile/profile_post_viewer_screen.dart';
import '../../features/reels/reels_screen.dart';
import '../../services/chat/chat_service.dart';

/// Opens the correct viewer for a shared post/reel/long video from chat.
Future<void> openSharedPostFromChat(
  BuildContext context,
  WidgetRef ref, {
  required String postId,
  PostPreview? preview,
}) async {
  if (postId.isEmpty && preview == null) return;

  var post = _findPostInProviders(ref, postId);
  if (post == null && preview != null) {
    post = PostModel.fromPostPreview(preview);
  }
  if (post == null && postId.isNotEmpty) {
    final resolved = await ChatService().resolvePostPreview(postId: postId);
    if (resolved.success && resolved.data != null) {
      post = PostModel.fromPostPreview(
        PostPreview.fromJson(resolved.data!),
      );
    }
  }

  if (!context.mounted) return;
  if (post == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Post not available right now'),
        backgroundColor: ThemeHelper.getAccentColor(context),
      ),
    );
    return;
  }

  final type = (preview?.type ?? post.postType).toLowerCase();
  final engine = ref.read(globalVideoEngineProvider.notifier);
  await engine.pauseActive();

  if (!context.mounted) return;

  if (type == 'reel' || post.postType == 'reel') {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReelsScreen(prependedReel: post),
      ),
    );
    await engine.pauseActive();
    return;
  }
  if (type == 'longvideo' || post.postType == 'longVideo') {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LongVideosPage(bottomPadding: 0),
      ),
    );
    await engine.pauseActive();
    return;
  }

  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ProfilePostViewerScreen(
        posts: [post!],
        initialIndex: 0,
      ),
    ),
  );
  await engine.pauseActive();
}

PostModel? _findPostInProviders(WidgetRef ref, String postId) {
  if (postId.isEmpty) return null;
  for (final p in ref.read(postsProvider).posts) {
    if (p.id == postId) return p;
  }
  for (final r in ref.read(reelsListProvider)) {
    if (r.id == postId) return r;
  }
  return null;
}
