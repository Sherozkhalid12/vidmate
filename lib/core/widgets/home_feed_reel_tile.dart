import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../media/app_media_cache.dart';
import '../models/post_model.dart';
import '../providers/home_feed_playback_provider_riverpod.dart';
import '../providers/posts_provider_riverpod.dart';
import '../providers/reels_provider_riverpod.dart';
import '../providers/saved_posts_provider_riverpod.dart';
import '../utils/theme_helper.dart';
import '../video_engine/video_engine_provider.dart';
import 'comments_bottom_sheet.dart';
import 'feed_cached_post_image.dart';
import 'home_feed_reel_player_cover.dart';
import 'share_bottom_sheet.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/reels/reels_screen.dart';

/// Reel card for the home feed (4:5, same as post cards) with [GlobalVideoEngine] auto-play.
class HomeFeedReelTile extends ConsumerWidget {
  final PostModel reel;

  const HomeFeedReelTile({super.key, required this.reel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(homeFeedReelEngineBinderProvider);

    final activeSlotId = ref.watch(
      globalVideoEngineProvider.select((s) => s.activeSlot?.id),
    );
    final activeController = ref.watch(
      globalVideoEngineProvider.select((s) => s.activeSlot?.controller),
    );
    final handoffId = ref.watch(homeFeedReelHandoffIdProvider);
    final isActive = activeSlotId == reel.id && activeController != null;
    final isHandedOff = handoffId == reel.id;
    final showPlayer = isActive && !isHandedOff;
    final thumb = reel.effectiveThumbnailUrl ?? '';

    final canShare = reel.author.allowShares;
    final canComment = reel.author.allowComments;
    final canLike = reel.author.allowLikes;

    return Container(
      key: ValueKey('home_reel_${reel.id}'),
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _openAuthor(context),
                  child: ClipOval(
                    child: reel.author.avatarUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: reel.author.avatarUrl,
                            width: 32,
                            height: 32,
                            fit: BoxFit.cover,
                            cacheManager: AppMediaCache.feedMedia,
                          )
                        : Container(
                            width: 32,
                            height: 32,
                            color: ThemeHelper.getSurfaceColor(context),
                            child: Icon(
                              CupertinoIcons.person_crop_circle,
                              size: 20,
                              color: ThemeHelper.getTextSecondary(context),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _openAuthor(context),
                    child: Text(
                      reel.author.username.isNotEmpty
                          ? reel.author.username
                          : reel.author.displayName,
                      style: TextStyle(
                        color: ThemeHelper.getTextPrimary(context),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (reel.audioName != null && reel.audioName!.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      Icons.music_note_rounded,
                      size: 18,
                      color: ThemeHelper.getAccentColor(context),
                    ),
                  ),
              ],
            ),
          ),
          VisibilityDetector(
            key: Key('home_reel_vis_${reel.id}'),
            onVisibilityChanged: (info) {
              final id = reel.id;
              final handoff = ref.read(homeFeedReelHandoffIdProvider);
              if (handoff == id) return;

              final notifier = ref.read(homeFeedActiveReelIdProvider.notifier);
              if (info.visibleFraction >= 0.55) {
                if (notifier.state != id) notifier.state = id;
              } else if (notifier.state == id && info.visibleFraction < 0.2) {
                notifier.state = null;
              }
            },
            child: GestureDetector(
              onTap: () {
                ref.read(homeFeedReelHandoffIdProvider.notifier).state =
                    reel.id;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReelsScreen(prependedReel: reel),
                  ),
                ).whenComplete(() {
                  ref.read(homeFeedReelHandoffIdProvider.notifier).state =
                      null;
                });
              },
              child: AspectRatio(
                aspectRatio: 4 / 5,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const ColoredBox(color: Colors.black),
                    if (thumb.isNotEmpty && !showPlayer)
                      FeedCachedPostImage(
                        imageUrl: thumb,
                        postId: reel.id,
                        blurHash: reel.blurHash,
                        fit: BoxFit.cover,
                      ),
                    if (showPlayer)
                      HomeFeedReelPlayerCover(
                        controller: activeController,
                      ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Consumer(
                  builder: (context, ref, _) {
                    final isSaved = ref.watch(isPostSavedProvider(reel.id));
                    return GestureDetector(
                      onTap: () {
                        ref
                            .read(savedPostsProvider.notifier)
                            .toggleSave(reel.id);
                      },
                      child: Icon(
                        isSaved ? Icons.star : Icons.star_border,
                        size: 28,
                        color: isSaved
                            ? ThemeHelper.getAccentColor(context)
                            : ThemeHelper.getTextPrimary(context),
                      ),
                    );
                  },
                ),
                const Spacer(),
                if (canShare) ...[
                  GestureDetector(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => ShareBottomSheet(
                          postId: reel.id,
                          videoUrl: reel.videoUrl,
                          imageUrl: reel.effectiveThumbnailUrl,
                        ),
                      );
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Transform.rotate(
                          angle: -0.785398,
                          child: Icon(
                            Icons.send,
                            size: 28,
                            color: ThemeHelper.getTextPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatCount(reel.shares),
                          style: TextStyle(
                            color: ThemeHelper.getTextSecondary(context),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                if (canComment) ...[
                  GestureDetector(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) =>
                            CommentsBottomSheet(postId: reel.id),
                      );
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.mode_comment_outlined,
                          size: 28,
                          color: ThemeHelper.getTextPrimary(context),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatCount(
                            ref.watch(postCommentCountProvider(reel.id)),
                          ),
                          style: TextStyle(
                            color: ThemeHelper.getTextSecondary(context),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                if (canLike)
                  Consumer(
                    builder: (context, ref, _) {
                      final isLiked = ref.watch(reelLikedProvider(reel.id));
                      final likeCount =
                          ref.watch(reelLikeCountProvider(reel.id));
                      return GestureDetector(
                        onTap: () {
                          ref
                              .read(reelsProvider.notifier)
                              .toggleLikeWithApi(reel.id);
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isLiked ? Icons.favorite : Icons.favorite_border,
                              size: 28,
                              color: isLiked
                                  ? Colors.red
                                  : ThemeHelper.getTextPrimary(context),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatCount(likeCount),
                              style: TextStyle(
                                color: ThemeHelper.getTextSecondary(context),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          if (reel.caption.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
              child: Text(
                reel.caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: ThemeHelper.getTextPrimary(context),
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openAuthor(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileScreen(user: reel.author)),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    }
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}
