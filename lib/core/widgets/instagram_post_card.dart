import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/features/profile/profile_screen.dart';
import 'dart:ui';
import '../models/post_model.dart';
import '../utils/theme_helper.dart';
import '../utils/video_thumbnail_helper.dart';
import '../utils/share_link_helper.dart';
import '../media/app_media_cache.dart';
import '../media/feed_image_decode_limits.dart';
import '../providers/auth_provider_riverpod.dart';
import '../providers/follow_provider_riverpod.dart';
import '../providers/posts_provider_riverpod.dart';
import '../providers/saved_posts_provider_riverpod.dart';
import 'comments_bottom_sheet.dart';
import 'share_bottom_sheet.dart';
import '../../services/posts/posts_service.dart';
import 'feed_cached_post_image.dart';
import 'feed_image_precache.dart';
import 'music_sticker_row.dart';

class InstagramPostCard extends ConsumerStatefulWidget {
  final PostModel post;
  final VoidCallback? onDelete;
  /// When true (home feed), comment count comes from [postCommentCountProvider] only.
  final bool useFeedCommentCounts;

  const InstagramPostCard({
    super.key,
    required this.post,
    this.onDelete,
    this.useFeedCommentCounts = false,
  });

  @override
  ConsumerState<InstagramPostCard> createState() => _InstagramPostCardState();
}

/// Single slot in the post media carousel (image or video).
class _MediaSlot {
  final String url;
  final bool isVideo;
  _MediaSlot(this.url, this.isVideo);
}

/// Keeps off-screen carousel pages alive so [CachedNetworkImage] state is not torn down on swipe.
class _CarouselKeepAlivePage extends StatefulWidget {
  const _CarouselKeepAlivePage({required this.child});

  final Widget child;

  @override
  State<_CarouselKeepAlivePage> createState() => _CarouselKeepAlivePageState();
}

class _CarouselKeepAlivePageState extends State<_CarouselKeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _InstagramPostCardState extends ConsumerState<InstagramPostCard> with SingleTickerProviderStateMixin {
  late AnimationController _likeAnimationController;
  bool _isAnimating = false;
  final PageController _imageCarouselController = PageController();
  int _currentImageIndex = 0;

  /// Unified list of media items for carousel: images first, then video if any (Instagram-style).
  List<_MediaSlot> get _mediaSlots {
    final list = <_MediaSlot>[];
    for (final u in widget.post.imageUrls) {
      if (u.isNotEmpty) list.add(_MediaSlot(u, false));
    }
    final v = widget.post.videoUrl;
    if (v != null && v.isNotEmpty) list.add(_MediaSlot(v, true));
    if (list.isEmpty) {
      final u = widget.post.imageUrl ?? widget.post.thumbnailUrl ?? widget.post.effectiveThumbnailUrl ?? '';
      if (u.isNotEmpty) list.add(_MediaSlot(u, widget.post.isVideo));
    }
    return list;
  }

  void _schedulePrecacheAllCarouselUrls() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final urls = feedCarouselImageUrls(widget.post);
      final mq = MediaQuery.sizeOf(context);
      final dpr = MediaQuery.devicePixelRatioOf(context);
      final dims = feedMemCacheDimensions(mq, dpr);
      for (final url in urls) {
        if (url.isEmpty) continue;
        final provider = ResizeImage(
          CachedNetworkImageProvider(
            url,
            cacheManager: AppMediaCache.feedMedia,
          ),
          width: dims.w,
          height: dims.h,
        );
        precacheFeedImageSafe(provider, context);
      }
    });
  }

  @override
  void didUpdateWidget(covariant InstagramPostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id) {
      _currentImageIndex = 0;
      if (_imageCarouselController.hasClients) {
        _imageCarouselController.jumpToPage(0);
      }
      _schedulePrecacheAllCarouselUrls();
    } else {
      final oldSig = feedCarouselImageUrls(oldWidget.post).join('|');
      final newSig = feedCarouselImageUrls(widget.post).join('|');
      if (oldSig != newSig) {
        _schedulePrecacheAllCarouselUrls();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _schedulePrecacheAllCarouselUrls();
    _likeAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _likeAnimationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isAnimating = false;
        });
        _likeAnimationController.reset();
      }
    });
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  /// Comment count: from feed provider when [useFeedCommentCounts], else from post model.
  int _effectiveCommentCount(WidgetRef ref) {
    if (widget.useFeedCommentCounts) {
      return ref.watch(postCommentCountProvider(widget.post.id));
    }
    return widget.post.comments;
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${difference.inDays ~/ 7}w';
    }
  }

  Widget _buildMediaSlot(_MediaSlot slot) {
    final imageUrl = slot.isVideo
        ? (VideoThumbnailHelper.thumbnailFromVideoUrl(slot.url) ?? slot.url)
        : slot.url;
    if (imageUrl.isEmpty) {
      return Container(
        color: ThemeHelper.getSurfaceColor(context),
        child: Center(
          child: Icon(
            CupertinoIcons.exclamationmark_triangle_fill,
            color: ThemeHelper.getTextSecondary(context),
            size: 48,
          ),
        ),
      );
    }
    return KeyedSubtree(
      key: ValueKey<String>('post_media_${widget.post.id}_$imageUrl'),
      child: FeedCachedPostImage(
        imageUrl: imageUrl,
        postId: widget.post.id,
        blurHash: widget.post.blurHash,
      ),
    );
  }

  @override
  void dispose() {
    _likeAnimationController.dispose();
    _imageCarouselController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: isDark
          ? Container(
              color: ThemeHelper.getBackgroundColor(context),
              child: _buildCardContent(),
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                  ),
                  child: _buildCardContent(),
                ),
              ),
            ),
    );
  }

  Widget _buildCardContent() {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final avatarPx = (32 * dpr).round().clamp(1, 512);
    final currentUserId = ref.watch(currentUserProvider)?.id;
    final isOwner = currentUserId != null && currentUserId == widget.post.author.id;
    final canLike = widget.post.author.allowLikes || isOwner;
    final canComment = widget.post.author.allowComments || isOwner;
    final canShare = widget.post.author.allowShares || isOwner;
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header - Instagram style
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // Profile picture
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfileScreen(user: widget.post.author),
                      ),
                    );
                  },
                  child: ClipOval(
                    child: widget.post.author.avatarUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: widget.post.author.avatarUrl,
                            width: 32,
                            height: 32,
                            fit: BoxFit.cover,
                            memCacheWidth: avatarPx,
                            memCacheHeight: avatarPx,
                            cacheManager: AppMediaCache.feedMedia,
                            placeholder: (context, url) => Container(
                              width: 32,
                              height: 32,
                              color: ThemeHelper.getSurfaceColor(context),
                            ),
                            errorWidget: (context, url, error) => Container(
                              width: 32,
                              height: 32,
                              color: ThemeHelper.getSurfaceColor(context),
                              child: Icon(
                                CupertinoIcons.person_crop_circle,
                                size: 32,
                                color: ThemeHelper.getTextSecondary(context),
                              ),
                            ),
                          )
                        : Container(
                            width: 32,
                            height: 32,
                            color: ThemeHelper.getSurfaceColor(context),
                            child: Icon(
                              CupertinoIcons.person_crop_circle,
                              size: 32,
                              color: ThemeHelper.getTextSecondary(context),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                // Username and time
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProfileScreen(user: widget.post.author),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        Text(
                          widget.post.author.username,
                          style: TextStyle(
                            color: ThemeHelper.getTextPrimary(context),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.verified,
                          size: 12,
                          color: ThemeHelper.getAccentColor(context),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '• ${_formatTimeAgo(widget.post.createdAt)}',
                          style: TextStyle(
                            color: ThemeHelper.getTextSecondary(context),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Follow button - hide when author is current user
                ...(ref.watch(currentUserProvider)?.id != widget.post.author.id
                    ? [
                        ((ref.watch(followStateProvider)[widget.post.author.id] ==
                                    FollowRelationshipStatus.following) ||
                                (ref.watch(followStateProvider)[widget.post.author.id] == null &&
                                    (ref.watch(followProvider).followingIds.isNotEmpty
                                        ? ref.watch(followProvider)
                                            .followingIds
                                            .contains(widget.post.author.id)
                                        : widget.post.author.isFollowing)))
                            ? GestureDetector(
                                onTap: () {
                                  ref.read(followProvider.notifier).toggleFollow(widget.post.author.id);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: ThemeHelper.getTextPrimary(context),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Text(
                                    'Following',
                                    style: TextStyle(
                                      color: ThemeHelper.getTextPrimary(context),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              )
                            : GestureDetector(
                                onTap: () {
                                  ref.read(followProvider.notifier).toggleFollow(widget.post.author.id);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: ThemeHelper.getAccentColor(context),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: ThemeHelper.getAccentColor(context),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    (ref.watch(followStateProvider)[widget.post.author.id] ==
                                                FollowRelationshipStatus.pending)
                                            ? 'Requested'
                                            : 'Follow',
                                    style: TextStyle(
                                      color: ThemeHelper.getOnAccentColor(context),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                      ]
                    : []),
                const SizedBox(width: 8),
                // More menu icon (always visible)
                GestureDetector(
                  onTap: () => _showMoreMenu(context),
                  child: Icon(
                    CupertinoIcons.ellipsis,
                    color: ThemeHelper.getTextPrimary(context),
                    size: 20,
                  ),
                ),
              ],
            ),
          ),

          // Media - Instagram-style slider for multiple images or images + video
          GestureDetector(
            onDoubleTap: () {
              final isLiked = ref.read(postLikedProvider(widget.post.id));
              ref.read(postsProvider.notifier).toggleLikeWithApi(widget.post.id);
              if (!isLiked) {
                setState(() {
                  _isAnimating = true;
                });
                _likeAnimationController.forward(from: 0);
              }
            },
            child: AspectRatio(
              aspectRatio: 1.0,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Carousel when multiple media (images and/or video)
                  _mediaSlots.length > 1
                      ? PageView.builder(
                          key: PageStorageKey<String>('post_carousel_${widget.post.id}'),
                          controller: _imageCarouselController,
                          scrollDirection: Axis.horizontal,
                          physics: const PageScrollPhysics(),
                          allowImplicitScrolling: false,
                          onPageChanged: (index) {
                            setState(() {
                              _currentImageIndex = index;
                            });
                          },
                          itemCount: _mediaSlots.length,
                          itemBuilder: (context, index) {
                            return _CarouselKeepAlivePage(
                              child: _buildMediaSlot(_mediaSlots[index]),
                            );
                          },
                        )
                      : _mediaSlots.isEmpty
                          ? Container(
                              color: ThemeHelper.getSurfaceColor(context),
                              child: Center(
                                child: Icon(
                                  CupertinoIcons.exclamationmark_triangle_fill,
                                  color: ThemeHelper.getTextSecondary(context),
                                  size: 48,
                                ),
                              ),
                            )
                          : _buildMediaSlot(_mediaSlots.first),
                  // Carousel indicators (dots)
                  if (_mediaSlots.length > 1)
                    Positioned(
                      top: 8,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _mediaSlots.length,
                          (index) => Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _currentImageIndex == index
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Video play icon overlay when current slide is video
                  if (_mediaSlots.isNotEmpty &&
                      _mediaSlots[_currentImageIndex.clamp(0, _mediaSlots.length - 1)].isVideo)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          CupertinoIcons.play_fill,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                  // Like animation overlay
                  if (_isAnimating)
                    Center(
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.0, end: 1.2).animate(
                          CurvedAnimation(
                            parent: _likeAnimationController,
                            curve: Curves.elasticOut,
                          ),
                        ),
                        child: FadeTransition(
                          opacity: Tween<double>(begin: 1.0, end: 0.0).animate(
                            CurvedAnimation(
                              parent: _likeAnimationController,
                              curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
                            ),
                          ),
                          child: Icon(
                            CupertinoIcons.heart_fill,
                            color: Colors.red,
                            size: 80,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Actions row - Bookmark on LEFT, Share/Comment/Like on RIGHT
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // Left side - Bookmark
                Consumer(
                  builder: (context, ref, _) {
                    final isSaved = ref.watch(isPostSavedProvider(widget.post.id));
                    return GestureDetector(
                      onTap: () {
                        ref.read(savedPostsProvider.notifier).toggleSave(widget.post.id);
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isSaved ? Icons.star : Icons.star_border,
                            size: 28,
                            color: isSaved ? ThemeHelper.getAccentColor(context) : ThemeHelper.getTextPrimary(context),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const Spacer(),
                // Right side actions - Share, Comment, Like
                if (canShare) ...[
                  GestureDetector(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => ShareBottomSheet(
                          postId: widget.post.id,
                          videoUrl: widget.post.videoUrl,
                          imageUrl: widget.post.effectiveThumbnailUrl,
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
                          _formatCount(widget.post.shares),
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
                        builder: (context) => CommentsBottomSheet(postId: widget.post.id),
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
                          _formatCount(_effectiveCommentCount(ref)),
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
                    builder: (context, ref, child) {
                      final isLiked = ref.watch(postLikedProvider(widget.post.id));
                      final likeCount = ref.watch(postLikeCountProvider(widget.post.id));
                      return GestureDetector(
                        onTap: () {
                          ref.read(postsProvider.notifier).toggleLikeWithApi(widget.post.id);
                          if (!isLiked) {
                            setState(() {
                              _isAnimating = true;
                            });
                            _likeAnimationController.forward(from: 0);
                          }
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isLiked ? Icons.favorite : Icons.favorite_border,
                              size: 28,
                              color: isLiked ? Colors.red : ThemeHelper.getTextPrimary(context),
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

          const SizedBox(height: 4),

          // Caption
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  color: ThemeHelper.getTextPrimary(context),
                  fontSize: 14,
                ),
                children: [
                  TextSpan(
                    text: '${widget.post.author.username} ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: widget.post.caption),
                ],
              ),
            ),
          ),
          MusicStickerRow(
            previewUrl: widget.post.musicPreviewUrl,
            musicName: widget.post.musicName,
            musicTitle: widget.post.musicTitle,
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
          ),

          const SizedBox(height: 8),
        ],
    );
  }

  void _showMoreMenu(BuildContext context) {
    final currentUserId = ref.read(authProvider).currentUser?.id ?? '';
    final isOwner =
        currentUserId.isNotEmpty && currentUserId == widget.post.author.id;

    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          if (isOwner)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () async {
                Navigator.pop(context);

                final result = await PostsService().deletePost(
                  postId: widget.post.id,
                  currentUserId: currentUserId,
                  postAuthorId: widget.post.author.id,
                );

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      result.success
                          ? 'Post deleted'
                          : (result.errorMessage ?? 'Delete failed'),
                    ),
                    backgroundColor: result.success
                        ? ThemeHelper.getAccentColor(context)
                        : ThemeHelper.getSurfaceColor(context),
                  ),
                );

                if (result.success) {
                  await ref.read(postsProvider.notifier).loadPosts();
                }
              },
              child: const Text('Delete'),
            ),
          if (!isOwner)
            CupertinoActionSheetAction(
              child: const Text('Report'),
              onPressed: () async {
                Navigator.pop(context);

                final result = await PostsService().reportPost(
                  postId: widget.post.id,
                  currentUserId: currentUserId,
                  postAuthorId: widget.post.author.id,
                );

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      result.success
                          ? 'Reported'
                          : (result.errorMessage ?? 'Report failed'),
                    ),
                    backgroundColor: result.success
                        ? ThemeHelper.getAccentColor(context)
                        : ThemeHelper.getSurfaceColor(context),
                  ),
                );
              },
            ),
          CupertinoActionSheetAction(
            child: const Text('Copy Link'),
            onPressed: () {
              final thumb = widget.post.effectiveThumbnailUrl;
              final link = ShareLinkHelper.build(
                contentId: widget.post.id,
                thumbnailUrl: thumb,
              );
              Navigator.pop(context);
              Clipboard.setData(ClipboardData(text: link));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Link copied!',
                    style: TextStyle(color: ThemeHelper.getTextPrimary(context)),
                  ),
                  backgroundColor:
                      ThemeHelper.getSurfaceColor(context).withOpacity(0.95),
                ),
              );
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('Cancel'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }
}
