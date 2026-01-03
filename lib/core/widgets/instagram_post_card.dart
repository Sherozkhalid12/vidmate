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
import '../../features/feed/comments_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _likeAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      color: ThemeHelper.getBackgroundColor(context),
      child: Column(
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
                    child: CachedNetworkImage(
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
                // Follow button (keep in same position)
                if (!widget.post.author.isFollowing)
                  GestureDetector(
                    onTap: () {
                      // Handle follow action
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: ThemeHelper.getAccentColor(context),
                        borderRadius: BorderRadius.circular(6),
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
                  )
                else
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

          // Media - Full width square image
          GestureDetector(
            onDoubleTap: () {
              final isLiked = ref.read(postLikedProvider(widget.post.id));
              ref.read(postsProvider.notifier).toggleLike(widget.post.id);
              if (!isLiked) {
                _likeAnimationController.forward(from: 0);
              }
            },
            child: AspectRatio(
              aspectRatio: 1.0,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: widget.post.imageUrl ?? widget.post.thumbnailUrl ?? '',
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
                  Consumer(
                    builder: (context, ref, child) {
                      final isLiked = ref.watch(postLikedProvider(widget.post.id));
                      if (isLiked) {
                        return Center(
                          child: ScaleTransition(
                            scale: Tween<double>(begin: 0.8, end: 1.2).animate(
                              CurvedAnimation(
                                parent: _likeAnimationController,
                                curve: Curves.elasticOut,
                              ),
                            ),
                            child: Icon(
                              CupertinoIcons.heart_fill,
                              color: Colors.red,
                              size: 80,
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
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
                        _isSaved ? Icons.bookmark : Icons.bookmark_border,
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
                    // Handle share action
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.share_outlined,
                        size: 28,
                        color: ThemeHelper.getTextPrimary(context),
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
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CommentsScreen(postId: widget.post.id),
                      ),
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
      ),
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
