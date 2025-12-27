import 'package:flutter/material.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_button.dart';
import '../../core/models/post_model.dart';
import 'comments_screen.dart';

/// Post detail screen with full interactions
class PostDetailScreen extends StatelessWidget {
  final PostModel post;

  const PostDetailScreen({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        title: Text('Post'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: context.secondaryBackgroundColor,
                builder: (context) => Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: Icon(
                          Icons.share,
                          color: ThemeHelper.getAccentColor(context), // Theme-aware accent color
                        ),
                        title: Text('Share', style: TextStyle(color: context.textPrimary)),
                        onTap: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Share feature coming soon'),
                              backgroundColor: ThemeHelper.getAccentColor(context), // Theme-aware accent color
                            ),
                          );
                        },
                      ),
                      ListTile(
                        leading: Icon(Icons.report, color: AppColors.warning),
                        title: Text('Report', style: TextStyle(color: context.textPrimary)),
                        onTap: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Report feature coming soon'),
                              backgroundColor: ThemeHelper.getAccentColor(context), // Theme-aware accent color
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Post media
            if (post.imageUrl != null)
              Image.network(
                post.imageUrl!,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 400,
                    color: context.surfaceColor,
                    child: Center(
                      child: Icon(
                        Icons.broken_image,
                        size: 64,
                        color: context.textMuted,
                      ),
                    ),
                  );
                },
              ),
            // Author and caption
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Author info
                  Row(
                    children: [
                      ClipOval(
                        child: Image.network(
                          post.author.avatarUrl,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 40,
                              height: 40,
                              color: context.surfaceColor,
                              child: Icon(
                                Icons.person,
                                color: context.textSecondary,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post.author.displayName,
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '@${post.author.username}',
                              style: TextStyle(
                                color: context.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GlassButton(
                        text: post.author.isFollowing ? 'Following' : 'Follow',
                        backgroundColor: post.author.isFollowing
                            ? context.surfaceColor
                            : null,
                        textColor: post.author.isFollowing
                            ? context.textPrimary
                            : null,
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Follow feature coming soon'),
                              backgroundColor: ThemeHelper.getAccentColor(context), // Theme-aware accent color
                            ),
                          );
                        },
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Caption
                  Text(
                    post.caption,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildAction(
                        context,
                        icon: post.isLiked ? Icons.favorite : Icons.favorite_border,
                        label: _formatCount(post.likes),
                        color: post.isLiked ? AppColors.warning : null,
                        onTap: () {},
                      ),
                      _buildAction(
                        context,
                        icon: Icons.comment_outlined,
                        label: _formatCount(post.comments),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CommentsScreen(
                                postId: post.id,
                              ),
                            ),
                          );
                        },
                      ),
                      _buildAction(
                        context,
                        icon: Icons.share_outlined,
                        label: _formatCount(post.shares),
                        onTap: () {},
                      ),
                      _buildAction(
                        context,
                        icon: Icons.bookmark_border,
                        label: 'Save',
                        onTap: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    Color? color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(
            icon,
            color: color ?? context.textSecondary,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: context.textMuted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}

