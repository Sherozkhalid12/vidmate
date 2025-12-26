import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_colors.dart';
import '../theme/theme_extensions.dart';
import '../models/post_model.dart';
import '../../features/feed/comments_screen.dart';

/// Instagram-style post card for feed
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

class _InstagramPostCardState extends State<InstagramPostCard> {
  bool _isLiked = false;
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.isLiked;
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${time.day}/${time.month}/${time.year}';
    }
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          bottom: BorderSide(
            color: context.borderColor,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header - Author info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: widget.post.author.avatarUrl,
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: 32,
                      height: 32,
                      color: context.surfaceColor,
                      child: const Center(
                        child: SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.neonPurple,
                          ),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 32,
                      height: 32,
                      color: context.surfaceColor,
                      child: Icon(
                        Icons.person,
                        color: context.textSecondary,
                        size: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.post.author.username,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (widget.post.author.displayName != widget.post.author.username)
                        Text(
                          widget.post.author.displayName,
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: context.textPrimary),
                  iconSize: 20,
                  onSelected: (value) {
                    if (value == 'delete' && widget.onDelete != null) {
                      widget.onDelete!();
                    } else if (value == 'report') {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Report submitted'),
                          backgroundColor: AppColors.cyanGlow,
                        ),
                      );
                    } else if (value == 'copy') {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Link copied'),
                          backgroundColor: AppColors.cyanGlow,
                        ),
                      );
                    }
                  },
                  itemBuilder: (context) => [
                    if (widget.onDelete != null)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: AppColors.warning),
                            SizedBox(width: 8),
                            Text('Delete'),
                          ],
                        ),
                      ),
                    if (widget.onDelete != null)
                      const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'report',
                      child: Row(
                        children: [
                          Icon(Icons.flag, color: context.textSecondary),
                          const SizedBox(width: 8),
                          const Text('Report'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'copy',
                      child: Row(
                        children: [
                          Icon(Icons.link, color: context.textSecondary),
                          const SizedBox(width: 8),
                          const Text('Copy Link'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Media
          GestureDetector(
            onDoubleTap: () {
              setState(() {
                _isLiked = true;
              });
              // Show heart animation
            },
            child: Stack(
              children: [
                if (widget.post.imageUrl != null)
                  CachedNetworkImage(
                    imageUrl: widget.post.imageUrl!,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 400,
                      color: context.surfaceColor,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.neonPurple,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 400,
                      color: context.surfaceColor,
                      child: Center(
                        child: Icon(
                          Icons.broken_image,
                          size: 48,
                          color: context.textMuted,
                        ),
                      ),
                    ),
                  )
                else if (widget.post.thumbnailUrl != null)
                  CachedNetworkImage(
                    imageUrl: widget.post.thumbnailUrl!,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 400,
                      color: context.surfaceColor,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.neonPurple,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 400,
                      color: context.surfaceColor,
                    ),
                  ),
                if (widget.post.isVideo)
                  Positioned.fill(
                      child: Container(
                        color: Colors.black.withOpacity(0.3),
                        child: Center(
                          child: Icon(
                            Icons.play_circle_filled,
                            size: 64,
                            color: context.textPrimary,
                          ),
                        ),
                      ),
                  ),
              ],
            ),
          ),
          // Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isLiked = !_isLiked;
                    });
                  },
                  child: Icon(
                    _isLiked ? Icons.favorite : Icons.favorite_border,
                    color: _isLiked ? AppColors.warning : context.textPrimary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CommentsScreen(
                          postId: widget.post.id,
                        ),
                      ),
                    );
                  },
                  child: Icon(
                    Icons.chat_bubble_outline,
                    color: context.textPrimary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Share feature coming soon'),
                        backgroundColor: AppColors.cyanGlow,
                      ),
                    );
                  },
                  child: Icon(
                    Icons.send_outlined,
                    color: context.textPrimary,
                    size: 28,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isSaved = !_isSaved;
                    });
                  },
                  child: Icon(
                    _isSaved ? Icons.bookmark : Icons.bookmark_border,
                    color: context.textPrimary,
                    size: 28,
                  ),
                ),
              ],
            ),
          ),
          // Likes count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '${_formatCount((_isLiked ? 1 : 0) + widget.post.likes)} likes',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Caption
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  color: context.textPrimary,
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
          // View all comments
          if (widget.post.comments > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CommentsScreen(
                        postId: widget.post.id,
                      ),
                    ),
                  );
                },
                child: Text(
                  'View all ${_formatCount(widget.post.comments)} comments',
                  style: TextStyle(
                    color: context.textMuted,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          // Time
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(
              _formatTime(widget.post.createdAt),
              style: TextStyle(
                color: context.textMuted,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

