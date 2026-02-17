import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/features/profile/profile_screen.dart';
import 'dart:ui';
import '../models/post_model.dart';
import '../theme/app_colors.dart';
import '../utils/theme_helper.dart';
import '../providers/posts_provider_riverpod.dart';
import 'comments_bottom_sheet.dart';
import 'share_bottom_sheet.dart';

class InstagramPostCard extends ConsumerStatefulWidget {
  final PostModel post;
  final VoidCallback? onDelete;

  const InstagramPostCard({
    super.key,
    required this.post,
    this.onDelete,
  });

  @override
  ConsumerState<InstagramPostCard> createState() => _InstagramPostCardState();
}

class _InstagramPostCardState extends ConsumerState<InstagramPostCard> with SingleTickerProviderStateMixin {
  bool _isSaved = false;
  late AnimationController _likeAnimationController;
  bool _isAnimating = false;
  final PageController _imageCarouselController = PageController();
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
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
                // Follow button (keep in same position) - always show, fully rounded
                widget.post.author.isFollowing
                    ? GestureDetector(
                        onTap: () {
                          // Handle unfollow action - toggle follow state
                          ref.read(postsProvider.notifier).toggleFollow(widget.post.author.id);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                          // Handle follow action - toggle follow state
                          ref.read(postsProvider.notifier).toggleFollow(widget.post.author.id);
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
                            'Follow',
                            style: TextStyle(
                              color: ThemeHelper.getOnAccentColor(context),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
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

          // Media - Full width square image with carousel for multiple images
          GestureDetector(
            onDoubleTap: () {
              final isLiked = ref.read(postLikedProvider(widget.post.id));
              ref.read(postsProvider.notifier).toggleLike(widget.post.id);
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
                  // Carousel for multiple images, or single image/video
                  widget.post.imageUrls.length > 1
                      ? PageView.builder(
                          controller: _imageCarouselController,
                          onPageChanged: (index) {
                            setState(() {
                              _currentImageIndex = index;
                            });
                          },
                          itemCount: widget.post.imageUrls.length,
                          itemBuilder: (context, index) {
                            final imageUrl = widget.post.imageUrls[index];
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
                            return CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              placeholder: (context, url) => Container(
                                color: ThemeHelper.getSurfaceColor(context),
                                child: Center(
                                  child: CupertinoActivityIndicator(
                                    color: ThemeHelper.getTextSecondary(context),
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: ThemeHelper.getSurfaceColor(context),
                                child: Center(
                                  child: Icon(
                                    CupertinoIcons.exclamationmark_triangle_fill,
                                    color: ThemeHelper.getTextSecondary(context),
                                    size: 48,
                                  ),
                                ),
                              ),
                            );
                          },
                        )
                      : (() {
                          final mediaUrl =
                              widget.post.imageUrl ?? widget.post.thumbnailUrl ?? '';
                          if (mediaUrl.isEmpty) {
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
                          return CachedNetworkImage(
                            imageUrl: mediaUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            placeholder: (context, url) => Container(
                              color: ThemeHelper.getSurfaceColor(context),
                              child: Center(
                                child: CupertinoActivityIndicator(
                                  color: ThemeHelper.getTextSecondary(context),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: ThemeHelper.getSurfaceColor(context),
                              child: Center(
                                child: Icon(
                                  CupertinoIcons.exclamationmark_triangle_fill,
                                  color: ThemeHelper.getTextSecondary(context),
                                  size: 48,
                                ),
                              ),
                            ),
                          );
                        })(),
                  // Carousel indicators for multiple images
                  if (widget.post.imageUrls.length > 1)
                    Positioned(
                      top: 8,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          widget.post.imageUrls.length,
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
                  // Video play icon overlay
                  if (widget.post.isVideo)
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
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isSaved = !_isSaved;
                    });
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isSaved ? Icons.star : Icons.star_border,
                        size: 28,
                        color: _isSaved ? ThemeHelper.getAccentColor(context) : ThemeHelper.getTextPrimary(context),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Right side actions - Share, Comment, Like
                GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => ShareBottomSheet(
                        postId: widget.post.id,
                        videoUrl: widget.post.videoUrl,
                        imageUrl: widget.post.imageUrl,
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
                        _formatCount(widget.post.comments),
                        style: TextStyle(
                          color: ThemeHelper.getTextSecondary(context),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Consumer(
                  builder: (context, ref, child) {
                    final isLiked = ref.watch(postLikedProvider(widget.post.id));
                    final likeCount = ref.watch(postLikeCountProvider(widget.post.id));
                    return GestureDetector(
                      onTap: () {
                        ref.read(postsProvider.notifier).toggleLike(widget.post.id);
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

          const SizedBox(height: 8),
        ],
    );
  }

  void _showMoreMenu(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          if (widget.onDelete != null)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(context);
                widget.onDelete!();
              },
              child: const Text('Delete'),
            ),
          CupertinoActionSheetAction(
            child: const Text('Report'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoActionSheetAction(
            child: const Text('Copy Link'),
            onPressed: () => Navigator.pop(context),
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
