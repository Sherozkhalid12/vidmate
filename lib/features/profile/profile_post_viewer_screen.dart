import 'dart:ui';

import 'package:flutter/material.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/models/post_model.dart';
import '../../core/widgets/instagram_post_card.dart';
import '../../core/widgets/video_tile.dart';
import '../reels/reels_screen.dart';
import '../long_videos/long_videos_page.dart';

class ProfilePostViewerScreen extends StatelessWidget {
  final List<PostModel> posts;
  final int initialIndex;

  const ProfilePostViewerScreen({
    super.key,
    required this.posts,
    required this.initialIndex,
  });

  Widget _buildPostWidget(BuildContext context, PostModel post) {
    // Use the same widgets as home feed: InstagramPostCard for photo posts,
    // VideoTile for reels/short videos, and also for long videos (with long-video tap).
    final isVideo = post.isVideo || post.postType == 'reel' || post.postType == 'longVideo';
    if (!isVideo) {
      // Exact widget as feed for simple posts
      return InstagramPostCard(post: post);
    }

    return VideoTile(
      thumbnailUrl: post.effectiveThumbnailUrl ?? '',
      title: post.caption,
      channelName: post.author.displayName.isNotEmpty ? post.author.displayName : post.author.username,
      channelAvatar: post.author.avatarUrl,
      authorId: post.author.id,
      onAuthorTap: () {
        Navigator.pop(context); // return to profile before navigating again
      },
      views: post.likes * 10,
      likes: post.likes,
      comments: post.comments,
      shares: post.shares,
      duration: post.videoDuration,
      videoUrl: post.videoUrl,
      postId: post.id,
      onTap: () {
        if (post.postType == 'reel') {
          Navigator.push(context, MaterialPageRoute(builder: (_) => ReelsScreen(prependedReel: post)));
        } else if (post.postType == 'longVideo') {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const LongVideosPage(bottomPadding: 0)));
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: BoxDecoration(gradient: context.backgroundGradient),
          child: SafeArea(
            child: Center(
              child: Text(
                'No posts to show',
                style: TextStyle(
                  color: ThemeHelper.getTextPrimary(context),
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      );
    }

    final startIndex = initialIndex.clamp(0, posts.length - 1);
    final visiblePosts = posts.sublist(startIndex);
    final initialPost = visiblePosts.first;
    final authorName = initialPost.author.username.isNotEmpty
        ? initialPost.author.username
        : (initialPost.author.displayName.isNotEmpty
            ? initialPost.author.displayName
            : 'Post');

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          _BackgroundGlow(),
          SafeArea(
            bottom: false,
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  floating: true,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  leading: IconButton(
                    icon: Icon(
                      Icons.arrow_back,
                      color: ThemeHelper.getTextPrimary(context),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  title: Text(
                    'Post Viewer',
                    style: TextStyle(
                      color: ThemeHelper.getTextPrimary(context),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                  actions: [
                    Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: context.surfaceColor.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: context.borderColor,
                        ),
                      ),
                      child: Text(
                        '${startIndex + 1} / ${posts.length}',
                        style: TextStyle(
                          color: ThemeHelper.getTextPrimary(context),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  flexibleSpace: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: ThemeHelper.getBackgroundColor(context).withOpacity(0.4),
                          border: Border(
                            bottom: BorderSide(
                              color: context.borderColor.withOpacity(0.6),
                              width: 0.8,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                    tween: Tween(begin: 0, end: 1),
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 16 * (1 - value)),
                          child: child,
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: LinearGradient(
                            colors: [
                              context.surfaceColor.withOpacity(0.5),
                              context.surfaceColor.withOpacity(0.2),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: context.borderColor,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: ThemeHelper.getTextPrimary(context).withOpacity(0.12),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: ThemeHelper.getSurfaceColor(context),
                              backgroundImage: initialPost.author.avatarUrl.isNotEmpty
                                  ? NetworkImage(initialPost.author.avatarUrl)
                                  : null,
                              child: initialPost.author.avatarUrl.isNotEmpty
                                  ? null
                                  : Icon(
                                      Icons.person,
                                      size: 22,
                                      color: ThemeHelper.getTextSecondary(context),
                                    ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    authorName,
                                    style: TextStyle(
                                      color: ThemeHelper.getTextPrimary(context),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Showing ${posts.length - startIndex} posts from this point',
                                    style: TextStyle(
                                      color: ThemeHelper.getTextSecondary(context),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: ThemeHelper.getAccentColor(context).withOpacity(0.16),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'Profile',
                                style: TextStyle(
                                  color: ThemeHelper.getTextPrimary(context),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.only(bottom: 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final post = visiblePosts[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: _buildPostWidget(context, post),
                        );
                      },
                      childCount: visiblePosts.length,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BackgroundGlow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return IgnorePointer(
      child: Stack(
        children: [
          Container(decoration: BoxDecoration(gradient: context.backgroundGradient)),
          Positioned(
            top: -size.width * 0.25,
            right: -size.width * 0.2,
            child: _GlowOrb(
              size: size.width * 0.7,
              color: ThemeHelper.getAccentColor(context).withOpacity(0.35),
            ),
          ),
          Positioned(
            bottom: -size.width * 0.35,
            left: -size.width * 0.15,
            child: _GlowOrb(
              size: size.width * 0.8,
              color: ThemeHelper.getAccentColor(context).withOpacity(0.2),
            ),
          ),
          Positioned(
            top: size.height * 0.35,
            left: size.width * 0.55,
            child: _GlowOrb(
              size: size.width * 0.4,
              color: ThemeHelper.getAccentColor(context).withOpacity(0.15),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color,
            color.withOpacity(0.0),
          ],
        ),
      ),
    );
  }
}
