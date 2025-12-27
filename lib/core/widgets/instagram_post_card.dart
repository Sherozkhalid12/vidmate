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
                // Header — no glass around avatar/username or ellipsis
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Row(
                    children: [
                      Row(
                        children: [
                          ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: widget.post.author.avatarUrl,
                              width: 38,
                              height: 38,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                width: 38,
                                height: 38,
                                color: ThemeHelper.getSurfaceColor(context),
                              ),
                              errorWidget: (context, url, error) => Icon(
                                CupertinoIcons.person_crop_circle,
                                size: 38,
                                color: ThemeHelper.getTextSecondary(context),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.post.author.username,
                                style: TextStyle(
                                  color: ThemeHelper.getTextPrimary(context), // Theme-aware text color
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (widget.post.author.displayName != widget.post.author.username)
                                Text(
                                  widget.post.author.displayName,
                                  style: TextStyle(
                                    color: ThemeHelper.getTextSecondary(context), // Theme-aware text color
                                    fontSize: 13,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => _showMoreMenu(context),
                        child: Icon(
                          CupertinoIcons.ellipsis_vertical,
                          color: ThemeHelper.getTextPrimary(context), // Theme-aware icon color
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ),

                // Media + bottom overlay stack (actions + caption — no glass)
                Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 1 / 1.1,
                      child: _buildMediaBackground(),
                    ),

                    // Bottom overlay content — plain, no container/glass
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Action buttons row — plain icons + text
                            Row(
                              children: [
                                _buildPlainAction(
                                  icon: _isLiked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                                  label: _formatCount((_isLiked ? 1 : 0) + widget.post.likes),
                                  color: _isLiked 
                                      ? const Color(0xFFFF2D55) // Keep red for liked state
                                      : Colors.white, // Theme-aware for overlay on image
                                  onTap: () {
                                    setState(() => _isLiked = !_isLiked);
                                    if (_isLiked) _likeAnimationController.forward(from: 0);
                                  },
                                ),
                                const SizedBox(width: 24),
                                _buildPlainAction(
                                  icon: CupertinoIcons.bubble_left_bubble_right,
                                  label: _formatCount(widget.post.comments),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => CommentsScreen(postId: widget.post.id)),
                                    );
                                  },
                                ),
                                const SizedBox(width: 24),
                                _buildPlainAction(
                                  icon: CupertinoIcons.paperplane,
                                  label: _formatCount(widget.post.shares ?? 0),
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Share coming soon')),
                                    );
                                  },
                                ),
                                const Spacer(),
                                GestureDetector(
                                  onTap: () => setState(() => _isSaved = !_isSaved),
                                  child: Icon(
                                    _isSaved ? CupertinoIcons.bookmark_fill : CupertinoIcons.bookmark,
                                    color: _isSaved 
                                        ? Colors.amber // Keep amber for saved state
                                        : Colors.white, // Theme-aware for overlay on image
                                    size: 26,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // Caption — plain rich text, no background/glass
                            // Text on image overlay - use high contrast for readability
                            RichText(
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              text: TextSpan(
                                style: TextStyle(
                                  color: Colors.white, // High contrast for overlay
                                  fontSize: 14,
                                  height: 1.4,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 5,
                                      color: Colors.black.withOpacity(0.7), // Shadow for contrast
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                children: [
                                  TextSpan(
                                    text: '@${widget.post.author.username} ',
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  TextSpan(text: widget.post.caption),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (widget.post.isVideo)
                      Center(
                        child: Icon(
                          CupertinoIcons.play_circle_fill,
                          size: 70,
                          color: ThemeHelper.getHighContrastIconColor(context).withOpacity(0.8), // High contrast for overlay
                        ),
                      ),
                  ],
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

  Widget _buildPlainAction({
    required IconData icon,
    required String? label,
    Color? color,
    required VoidCallback onTap,
  }) {
    // Default to high contrast for overlay on image, or use provided color
    final defaultColor = color ?? ThemeHelper.getHighContrastIconColor(context);
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 26),
          if (label != null) ...[
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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