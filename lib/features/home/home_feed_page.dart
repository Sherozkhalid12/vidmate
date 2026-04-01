import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/widgets/video_tile.dart';
import '../../core/widgets/instagram_post_card.dart';
import '../../core/widgets/ad_banner.dart';
import '../../core/models/post_model.dart';
import '../../core/providers/posts_provider_riverpod.dart';
import '../../core/providers/auth_provider_riverpod.dart';
import '../reels/reels_screen.dart';
import '../search/explore_screen.dart';
import '../profile/profile_screen.dart';
import '../chat/chat_list_screen.dart';
import '../notifications/notifications_screen.dart';

class HomeFeedPage extends ConsumerStatefulWidget {
  final double bottomPadding;

  const HomeFeedPage({super.key, required this.bottomPadding});

  @override
  ConsumerState<HomeFeedPage> createState() => _HomeFeedPageState();
}

class _HomeFeedPageState extends ConsumerState<HomeFeedPage> {
  final ScrollController _scrollController = ScrollController();
  bool _hasTriggeredLoad = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  /// Ensure we load posts when this page is shown with empty list (e.g. after re-login).
  void _ensurePostsLoadedIfEmpty(WidgetRef ref) {
    if (_hasTriggeredLoad) return;
    final state = ref.read(postsProvider);
    if (state.posts.isEmpty && !state.isLoading) {
      _hasTriggeredLoad = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(postsProvider.notifier).loadPosts();
      });
    }
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
    final allPosts = ref.watch(postsListProvider);
    // Home feed: only show posts with type 'post' (exclude reels, longVideo, story)
    final posts = allPosts.where((p) => p.postType == 'post').toList();
    final isLoading = postsState.isLoading;
    final error = postsState.error;

    _ensurePostsLoadedIfEmpty(ref);

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _buildAppBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                _hasTriggeredLoad = true;
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
                  else if (posts.isEmpty)
                    SliverFillRemaining(
                      child: _buildEmptyState(context, error, ref),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.only(bottom: widget.bottomPadding),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (index > 0 && index % 5 == 0 && index < posts.length) {
                              return AdBanner(
                                height: 60.h,
                                adType: 'banner',
                              );
                            }
                            final postIndex = index - (index ~/ 5);
                            if (postIndex < posts.length) {
                              return AnimationConfiguration.staggeredList(
                                position: postIndex,
                                duration: const Duration(milliseconds: 375),
                                child: SlideAnimation(
                                  verticalOffset: 50.h,
                                  child: FadeInAnimation(
                                    child: _buildPostCard(posts[postIndex]),
                                  ),
                                ),
                              );
                            }
                            if (isLoading) {
                              return Padding(
                                padding: EdgeInsets.all(16.w),
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

  Widget _buildEmptyState(BuildContext context, String? error, WidgetRef ref) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.feed_outlined,
              size: 64.r,
              color: Theme.of(context).colorScheme.outline,
            ),
            SizedBox(height: 16.h),
            Text(
              error ?? 'No posts yet',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 16.sp,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24.h),
            FilledButton.icon(
              onPressed: () {
                _hasTriggeredLoad = true;
                ref.read(postsProvider.notifier).loadPosts();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        children: [
          Text(
            'VidConnect',
            style: TextStyle(
              color: ThemeHelper.getAccentColor(context),
              fontSize: 22.sp,
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
              margin: EdgeInsets.only(left: 10.w, right: 8.w),
              padding: EdgeInsets.all(6.w),
              child: Transform.rotate(
                angle: -0.785398,
                child: Icon(
                  Icons.send,
                  color: ThemeHelper.getTextPrimary(context),
                  size: 24.r,
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
                margin: EdgeInsets.symmetric(horizontal: 10.w),
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: ThemeHelper.getSurfaceColor(context),
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(
                    color: ThemeHelper.getBorderColor(context),
                    width: 1.w,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.search,
                      size: 18.r,
                      color: ThemeHelper.getTextMuted(context),
                    ),
                    SizedBox(width: 8.w),
                    Flexible(
                      child: Text(
                        'Search',
                        style: TextStyle(
                          color: ThemeHelper.getTextMuted(context),
                          fontSize: 14.sp,
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
              padding: EdgeInsets.all(6.w),
              child: Icon(
                Icons.notifications_outlined,
                color: ThemeHelper.getTextPrimary(context),
                size: 24.r,
              ),
            ),
          ),
          SizedBox(width: 8.w),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileScreen(),
                ),
              );
            },
            child: Consumer(
              builder: (context, ref, _) {
                final currentUser = ref.watch(currentUserProvider);
                final avatarUrl = currentUser?.avatarUrl ?? '';
                return ClipOval(
                  child: avatarUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: avatarUrl,
                          width: 32.w,
                          height: 32.w,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            width: 32.w,
                            height: 32.w,
                            color: ThemeHelper.getSurfaceColor(context),
                            child: Icon(Icons.person, size: 18.r, color: ThemeHelper.getTextSecondary(context)),
                          ),
                          errorWidget: (context, url, error) => Container(
                            width: 32.w,
                            height: 32.w,
                            color: ThemeHelper.getSurfaceColor(context),
                            child: Icon(Icons.person, size: 18.r, color: ThemeHelper.getTextSecondary(context)),
                          ),
                        )
                      : Container(
                          width: 32.w,
                          height: 32.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: ThemeHelper.getSurfaceColor(context),
                          ),
                          child: Icon(
                            Icons.person,
                            size: 18.r,
                            color: ThemeHelper.getTextSecondary(context),
                          ),
                        ),
                );
              },
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
      margin: EdgeInsets.only(bottom: 16.h),
      child: VideoTile(
        thumbnailUrl: post.effectiveThumbnailUrl ?? post.thumbnailUrl ?? post.imageUrl ?? '',
        title: post.caption,
        channelName: post.author.displayName.isNotEmpty ? post.author.displayName : post.author.username,
        channelAvatar: post.author.avatarUrl,
        authorId: post.author.id,
        onAuthorTap: () {
          final currentUser = ref.read(currentUserProvider);
          if (currentUser?.id == post.author.id) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
          } else {
            Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileScreen(user: post.author)));
          }
        },
        views: post.likes * 10,
        likes: post.likes,
        comments: post.comments,
        shares: post.shares,
        duration: post.videoDuration,
        videoUrl: post.videoUrl,
        postId: post.id,
        onTap: () {
          if (post.isVideo && post.videoUrl != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ReelsScreen(prependedReel: post),
              ),
            );
          }
        },
      ),
    );
  }
}
