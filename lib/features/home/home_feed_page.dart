import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/widgets/video_tile.dart';
import '../../core/widgets/instagram_post_card.dart';
import '../../core/widgets/ad_banner.dart';
import '../../core/models/post_model.dart';
import '../../core/providers/posts_provider_riverpod.dart';
import '../search/explore_screen.dart';
import '../profile/profile_screen.dart';
import '../chat/chat_list_screen.dart';
import '../notifications/notifications_screen.dart';
import 'home_reels_viewer_screen.dart';

class HomeFeedPage extends ConsumerStatefulWidget {
  final double bottomPadding;

  const HomeFeedPage({super.key, required this.bottomPadding});

  @override
  ConsumerState<HomeFeedPage> createState() => _HomeFeedPageState();
}

class _HomeFeedPageState extends ConsumerState<HomeFeedPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      // Load more posts if needed (for future pagination)
      // Currently all posts are loaded at once
    }
  }

  @override
  Widget build(BuildContext context) {
    final postsState = ref.watch(postsProvider);
    final posts = ref.watch(postsListProvider);
    final isLoading = postsState.isLoading;

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _buildAppBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await ref.read(postsProvider.notifier).loadPosts();
              },
              color: context.buttonColor,
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  if (isLoading && posts.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: CircularProgressIndicator(
                          color: context.buttonColor,
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.only(bottom: widget.bottomPadding),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (index > 0 && index % 5 == 0 && index < posts.length) {
                              return const AdBanner(
                                height: 60,
                                adType: 'banner',
                              );
                            }
                            
                            final postIndex = index - (index ~/ 5);
                            
                            if (postIndex < posts.length) {
                              return AnimationConfiguration.staggeredList(
                                position: postIndex,
                                duration: const Duration(milliseconds: 375),
                                child: SlideAnimation(
                                  verticalOffset: 50.0,
                                  child: FadeInAnimation(
                                    child: _buildPostCard(posts[postIndex]),
                                  ),
                                ),
                              );
                            } else if (isLoading) {
                              return Padding(
                                padding: const EdgeInsets.all(16),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: context.buttonColor,
                                  ),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                          childCount: posts.length + (posts.length ~/ 5) + (isLoading ? 1 : 0),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(
            'VidConnect',
            style: TextStyle(
              color: ThemeHelper.getAccentColor(context),
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          // Messages icon on left of search bar
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ChatListScreen(),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(left: 10, right: 8),
              padding: const EdgeInsets.all(6),
              child: Transform.rotate(
                angle: -0.785398,
                child: Icon(
                  Icons.send,
                  color: ThemeHelper.getTextPrimary(context),
                  size: 24,
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ExploreScreen(),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: ThemeHelper.getSurfaceColor(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: ThemeHelper.getBorderColor(context),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.search,
                      size: 18,
                      color: ThemeHelper.getTextMuted(context),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Search',
                        style: TextStyle(
                          color: ThemeHelper.getTextMuted(context),
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Notification icon where messages was
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsScreen(),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              child: Icon(
                Icons.notifications_outlined,
                color: ThemeHelper.getTextPrimary(context),
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileScreen(),
                ),
              );
            },
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    ThemeHelper.getAccentColor(context),
                    ThemeHelper.getAccentColor(context).withValues(alpha: 0.7),
                  ],
                ),
              ),
              child: Icon(
                Icons.person,
                size: 18,
                color: ThemeHelper.getOnAccentColor(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(PostModel post) {
    if (!post.isVideo || post.imageUrl != null) {
      return InstagramPostCard(post: post);
    }

    final posts = ref.watch(postsListProvider);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: VideoTile(
        thumbnailUrl: post.thumbnailUrl ?? post.imageUrl ?? '',
        title: post.caption,
        channelName: post.author.displayName,
        channelAvatar: post.author.avatarUrl,
        views: post.likes * 10,
        likes: post.likes,
        comments: post.comments,
        shares: post.shares,
        duration: post.videoDuration,
        videoUrl: post.videoUrl,
        postId: post.id,
        onTap: () {
          if (post.isVideo && post.videoUrl != null) {
            final videoPosts = posts.where((p) => p.isVideo && p.videoUrl != null).toList();
            final currentIndex = videoPosts.indexWhere((p) => p.id == post.id);
            
            if (currentIndex >= 0) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => HomeReelsViewerScreen(
                    videos: videoPosts,
                    initialIndex: currentIndex,
                  ),
                ),
              );
            }
          }
        },
      ),
    );
  }
}
