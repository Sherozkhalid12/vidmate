import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui';
import '../models/post_model.dart';
import '../theme/app_colors.dart';
import '../utils/theme_helper.dart';
import '../../features/feed/comments_screen.dart';


class InstagramPostCard extends StatefulWidget {
  final PostModel post;
  final VoidCallback? onDelete;

  const InstagramPostCard({
    super.key,
    required this.post,
    this.onDelete,
  });

  @override
  State<InstagramPostCard> createState() => _InstagramPostCardState();
}

class _InstagramPostCardState extends State<InstagramPostCard> with SingleTickerProviderStateMixin {
  bool _isLiked = false;
  bool _isSaved = false;
  late AnimationController _likeAnimationController;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.isLiked;
    _likeAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _likeAnimationController.dispose();
    super.dispose();
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
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            // This is the only glass background now — the whole card
            decoration: BoxDecoration(
              // Use original dark mode transparency (8% white) for beautiful glassy effect
              // Keep beautiful light mode transparency (85% white) for light mode
              color: isDark 
                  ? AppColors.glassSurface  // Original dark mode: 8% white (transparent, shows background)
                  : AppColors.lightGlassSurfaceMedium, // Light mode: 85% white (beautiful)
              borderRadius: BorderRadius.circular(24),
              // No border in both modes - removes white edges
            ),
            child: Column(
              children: [
                // Header — Profile info with Follow button
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Row(
                    children: [
                      Row(
                        children: [
                          ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: widget.post.author.avatarUrl,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                width: 40,
                                height: 40,
                                color: ThemeHelper.getSurfaceColor(context),
                              ),
                              errorWidget: (context, url, error) => Icon(
                                CupertinoIcons.person_crop_circle,
                                size: 40,
                                color: ThemeHelper.getTextSecondary(context),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    widget.post.author.username,
                                    style: TextStyle(
                                      color: ThemeHelper.getTextPrimary(context),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Text('🇮🇳', style: TextStyle(fontSize: 14)), // Flag emoji
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatTimeAgo(widget.post.createdAt),
                                    style: TextStyle(
                                      color: ThemeHelper.getTextSecondary(context),
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.verified,
                                    size: 14,
                                    color: ThemeHelper.getAccentColor(context),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Follow button
                      if (!widget.post.author.isFollowing)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: ThemeHelper.getAccentColor(context),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Follow',
                            style: TextStyle(
                              color: ThemeHelper.getOnAccentColor(context),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      else
                        GestureDetector(
                          onTap: () => _showMoreMenu(context),
                          child: Icon(
                            CupertinoIcons.ellipsis_vertical,
                            color: ThemeHelper.getTextPrimary(context),
                            size: 22,
                          ),
                        ),
                    ],
                  ),
                ),

                // Media image
                AspectRatio(
                  aspectRatio: 1.0,
                  child: Stack(
                    children: [
                      _buildMediaBackground(),
                      if (widget.post.isVideo)
                        Center(
                          child: Icon(
                            CupertinoIcons.play_circle_fill,
                            size: 70,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                    ],
                  ),
                ),

                // Engagement and caption below image
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Engagement row - likes with share icon on left, comment and save on right
                      Row(
                        children: [
                          // Left side - likes and share
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _isLiked = !_isLiked;
                                if (_isLiked) _likeAnimationController.forward(from: 0);
                              });
                            },
                            child: Row(
                              children: [
                                Text(
                                  _formatCount((_isLiked ? 1 : 0) + widget.post.likes),
                                  style: TextStyle(
                                    color: ThemeHelper.getTextPrimary(context),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.share_outlined,
                                  size: 16,
                                  color: ThemeHelper.getTextSecondary(context),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          // Right side - comment and save
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CommentsScreen(postId: widget.post.id),
                                    ),
                                  );
                                },
                                child: Row(
                                  children: [
                                    Icon(
                                      CupertinoIcons.bubble_left_bubble_right,
                                      size: 20,
                                      color: ThemeHelper.getTextSecondary(context),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _formatCount(widget.post.comments),
                                      style: TextStyle(
                                        color: ThemeHelper.getTextSecondary(context),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              GestureDetector(
                                onTap: () => setState(() => _isSaved = !_isSaved),
                                child: Row(
                                  children: [
                                    Icon(
                                      _isSaved ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                                      size: 20,
                                      color: _isSaved 
                                          ? Colors.amber
                                          : ThemeHelper.getTextSecondary(context),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _formatCount(_isSaved ? 145 : 1),
                                      style: TextStyle(
                                        color: ThemeHelper.getTextSecondary(context),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Caption below engagement
                      RichText(
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          style: TextStyle(
                            color: ThemeHelper.getTextPrimary(context),
                            fontSize: 14,
                            height: 1.4,
                          ),
                          children: [
                            TextSpan(
                              text: widget.post.caption,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMediaBackground() {
    return CachedNetworkImage(
      imageUrl: widget.post.imageUrl ?? widget.post.thumbnailUrl ?? '',
      fit: BoxFit.cover,
      placeholder: (context, url) => Center(
        child: CupertinoActivityIndicator(
          color: ThemeHelper.getTextSecondary(context), // Theme-aware loading indicator
        ),
      ),
      errorWidget: (context, url, error) => Center(
        child: Icon(
          CupertinoIcons.exclamationmark_triangle_fill,
          color: Colors.white, // Theme-aware error icon
          size: 60,
        ),
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
          CupertinoActionSheetAction(child: const Text('Report'), onPressed: () => Navigator.pop(context)),
          CupertinoActionSheetAction(child: const Text('Copy Link'), onPressed: () => Navigator.pop(context)),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('Cancel'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }
}