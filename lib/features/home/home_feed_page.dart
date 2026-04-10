import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/widgets/video_tile.dart';
import '../../core/widgets/instagram_post_card.dart';
import '../../core/widgets/ad_banner.dart';
import '../../core/models/post_model.dart';
import '../../core/providers/posts_provider_riverpod.dart';
import '../../core/providers/auth_provider_riverpod.dart';
import '../../core/perf/feed_perf_metrics.dart';
import '../../core/media/app_media_cache.dart';
import '../../core/widgets/feed_image_precache.dart';
import '../../core/providers/network_status_provider.dart';
import '../reels/reels_screen.dart';
import '../search/explore_screen.dart';
import '../profile/profile_screen.dart';
import '../chat/chat_list_screen.dart';
import '../notifications/notifications_screen.dart';

/// Bouncing three-dot indicator for feed pagination (used when footer loader is enabled).
/*
class _FeedThreeDotsLoader extends StatefulWidget {
  final Color color;

  const _FeedThreeDotsLoader({required this.color});

  @override
  State<_FeedThreeDotsLoader> createState() => _FeedThreeDotsLoaderState();
}

class _FeedThreeDotsLoaderState extends State<_FeedThreeDotsLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final t = (_c.value + i * 0.2) % 1.0;
            final scale = 0.5 + 0.5 * (1 - (t - 0.5).abs() * 2).clamp(0.0, 1.0);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
*/

class HomeFeedPage extends ConsumerStatefulWidget {
  final double bottomPadding;

  const HomeFeedPage({super.key, required this.bottomPadding});

  @override
  ConsumerState<HomeFeedPage> createState() => _HomeFeedPageState();
}

class _HomeFeedPageState extends ConsumerState<HomeFeedPage>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  bool _hasTriggeredLoad = false;
  bool _loggedSkeletonMetric = false;
  String? _lastFeedCarouselPrecacheSig;
  late final Stopwatch _skeletonStopwatch;
  /// ~row height for scroll-based prefetch (posts + spacing).
  static const double _kApproxListRowExtent = 520;
  bool _prefetchScheduled = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _skeletonStopwatch = Stopwatch()..start();
    _scrollController.addListener(_onScroll);
  }

  void _ensurePostsLoadedIfEmpty(WidgetRef ref) {
    if (_hasTriggeredLoad) return;
    final state = ref.read(postsProvider);
    if (state.posts.isEmpty && !state.isLoading && !state.isRefreshing) {
      _hasTriggeredLoad = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(postsProvider.notifier).loadPosts(forceRefresh: false);
      });
    }
  }

  void _maybeLogSkeletonMetric(bool showSkeleton) {
    if (showSkeleton && !_loggedSkeletonMetric) {
      _loggedSkeletonMetric = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        FeedPerfMetrics.logFirstSkeletonMs(_skeletonStopwatch.elapsedMilliseconds);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// List index in SliverList for feed post index [postIndex] (includes ad rows).
  static int _listIndexForPostIndex(int postIndex) {
    if (postIndex < 0) return 0;
    return postIndex + (postIndex ~/ 5);
  }

  void _onScroll() {
    if (!mounted) return;
    final pos = _scrollController.position;
    if (!pos.hasViewportDimension || !pos.hasPixels) return;

    final postsState = ref.read(postsProvider);
    final feedPosts =
        postsState.posts.where((p) => p.postType == 'post').toList();
    if (!postsState.hasMoreFeed ||
        postsState.isLoadingMoreFeed ||
        postsState.isLoading ||
        _prefetchScheduled) {
      return;
    }

    final nearBottom =
        pos.maxScrollExtent > 0 && pos.pixels >= pos.maxScrollExtent - 32;
    bool thresholdHit = false;
    // Align prefetch with paginated page size: when ≥10 posts, load next as user approaches the 5th-from-end row.
    if (feedPosts.length >= kFeedPageSize) {
      final triggerPostIndex = feedPosts.length - 6;
      final listIdx = _listIndexForPostIndex(triggerPostIndex);
      final threshold =
          listIdx * _kApproxListRowExtent - pos.viewportDimension * 0.85;
      thresholdHit = pos.pixels >= threshold;
    }

    if (thresholdHit || nearBottom) {
      _prefetchScheduled = true;
      ref.read(postsProvider.notifier).loadMoreFeedPosts().whenComplete(() {
        if (mounted) _prefetchScheduled = false;
      });
    }
  }

  Future<void> _pullToRefreshFeed() async {
    _hasTriggeredLoad = true;
    await ref.read(postsProvider.notifier).loadPosts(forceRefresh: true);
  }

  Widget _buildShimmerPostCard(BuildContext context) {
    final base = Theme.of(context).brightness == Brightness.dark
        ? Colors.white10
        : Colors.black12;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Shimmer.fromColors(
        baseColor: base,
        highlightColor: base.withOpacity(0.35),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40.r,
                  height: 40.r,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 12.h,
                        width: 120.w,
                        color: Colors.white,
                      ),
                      SizedBox(height: 8.h),
                      Container(
                        height: 10.h,
                        width: 80.w,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
            ),
            SizedBox(height: 12.h),
            Container(height: 12.h, width: double.infinity, color: Colors.white),
            SizedBox(height: 8.h),
            Container(height: 12.h, width: 200.w, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonSliver(BuildContext context) {
    return SliverPadding(
      padding: EdgeInsets.only(top: 8.h, bottom: widget.bottomPadding),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildShimmerPostCard(context),
          childCount: 5,
        ),
      ),
    );
  }

  // Bottom pagination loader (re-enable when needed).
  // Widget _buildPaginationFooterSliver(
  //   BuildContext context, {
  //   required bool hasMoreFeed,
  //   required bool isLoadingMore,
  //   required bool nearEnd,
  // }) {
  //   final surface = ThemeHelper.getSurfaceColor(context);
  //   final border = ThemeHelper.getBorderColor(context);
  //   final accent = ThemeHelper.getAccentColor(context);
  //   final expanded = hasMoreFeed && (isLoadingMore || nearEnd);
  //   return SliverToBoxAdapter(
  //     child: Padding(
  //       padding: EdgeInsets.only(
  //         left: 16.w,
  //         right: 16.w,
  //         top: 8.h,
  //         bottom: widget.bottomPadding + 12.h,
  //       ),
  //       child: ClipRRect(
  //         borderRadius: BorderRadius.vertical(top: Radius.circular(18.r)),
  //         child: AnimatedSize(
  //           duration: const Duration(milliseconds: 280),
  //           curve: Curves.easeOutCubic,
  //           alignment: Alignment.topCenter,
  //           child: expanded
  //               ? Material(
  //                   color: surface,
  //                   child: Container(
  //                     width: double.infinity,
  //                     decoration: BoxDecoration(
  //                       border: Border.all(color: border.withValues(alpha: 0.5)),
  //                       borderRadius: BorderRadius.vertical(top: Radius.circular(18.r)),
  //                       boxShadow: [
  //                         BoxShadow(
  //                           color: Colors.black.withValues(alpha: 0.12),
  //                           blurRadius: 12,
  //                           offset: const Offset(0, -4),
  //                         ),
  //                       ],
  //                     ),
  //                     padding: EdgeInsets.symmetric(vertical: 20.h),
  //                     child: isLoadingMore
  //                         ? Center(
  //                             child: _FeedThreeDotsLoader(color: accent),
  //                           )
  //                         : Center(
  //                             child: Text(
  //                               'Pull for more',
  //                               style: TextStyle(
  //                                 color: ThemeHelper.getTextMuted(context),
  //                                 fontSize: 13.sp,
  //                               ),
  //                             ),
  //                           ),
  //                   ),
  //                 )
  //               : const SizedBox(width: double.infinity),
  //         ),
  //       ),
  //     ),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final allPosts = ref.watch(postsProvider.select((s) => s.posts));
    final isLoading = ref.watch(postsProvider.select((s) => s.isLoading));
    final isRefreshing = ref.watch(postsProvider.select((s) => s.isRefreshing));
    final initialFetchCompleted =
        ref.watch(postsProvider.select((s) => s.initialFetchCompleted));
    final error = ref.watch(postsProvider.select((s) => s.error));
    final offlineBanner = ref.watch(postsProvider.select((s) => s.feedOfflineBanner));
    final posts = allPosts.where((p) => p.postType == 'post').toList();

    final showSkeleton = !initialFetchCompleted || (posts.isEmpty && isLoading);
    _maybeLogSkeletonMetric(showSkeleton);

    _ensurePostsLoadedIfEmpty(ref);

    final precacheSig = posts
        .take(12)
        .map((p) => '${p.id}:${p.imageUrls.join("|")}:${p.videoUrl ?? ""}')
        .join('|');
    if (posts.isNotEmpty && precacheSig != _lastFeedCarouselPrecacheSig) {
      _lastFeedCarouselPrecacheSig = precacheSig;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        precacheFeedCarouselImages(posts, context: context, maxPosts: 12);
      });
    }

    final slivers = <Widget>[
      CupertinoSliverRefreshControl(onRefresh: _pullToRefreshFeed),
      if (offlineBanner)
        SliverToBoxAdapter(
          child: Material(
            color: ThemeHelper.getSurfaceColor(context).withOpacity(0.95),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              child: Row(
                children: [
                  Icon(Icons.cloud_off, size: 18.r, color: ThemeHelper.getTextSecondary(context)),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'Showing saved posts',
                      style: TextStyle(fontSize: 13.sp, color: ThemeHelper.getTextSecondary(context)),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () {
                      ref.read(postsProvider.notifier).dismissOfflineBanner();
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          ),
        ),
      if (showSkeleton)
        _buildSkeletonSliver(context)
      else if (posts.isEmpty)
        SliverFillRemaining(
          hasScrollBody: false,
          child: _buildEmptyState(
            context,
            error,
            ref,
            offlineBanner,
            posts.isEmpty,
          ),
        )
      else ...[
        SliverPadding(
          padding: EdgeInsets.only(bottom: 8.h),
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
                  final post = posts[postIndex];
                  return _buildPostCard(post);
                }
                if (isRefreshing) {
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    child: Shimmer.fromColors(
                      baseColor: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white10
                          : Colors.black12,
                      highlightColor: Colors.white24,
                      child: Container(
                        height: 48.h,
                        margin: EdgeInsets.symmetric(horizontal: 16.w),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
              childCount: posts.length + (posts.length ~/ 5) + (isRefreshing ? 1 : 0),
              addAutomaticKeepAlives: true,
              addRepaintBoundaries: true,
            ),
          ),
        ),
        // Bottom pagination footer + three-dot loader (re-enable with _buildPaginationFooterSliver / _FeedThreeDotsLoader).
        // if (hasMoreFeed)
        //   _buildPaginationFooterSliver(
        //     context,
        //     hasMoreFeed: hasMoreFeed,
        //     isLoadingMore: isLoadingMoreFeed,
        //     nearEnd: nearEnd,
        //   ),
      ],
    ];

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _buildAppBar(),
          Expanded(
            child: CustomScrollView(
              key: const PageStorageKey<String>('home_feed_scroll'),
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              cacheExtent: MediaQuery.sizeOf(context).height * 0.65,
              slivers: slivers,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    String? error,
    WidgetRef ref,
    bool feedOfflineBanner,
    bool feedPostsEmpty,
  ) {
    final offline = ref.watch(apiOfflineSignalProvider);
    if (feedPostsEmpty && (offline || feedOfflineBanner)) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off, size: 56.r, color: Theme.of(context).colorScheme.outline),
              SizedBox(height: 16.h),
              Text(
                'Connect to see new posts',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 16.sp,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
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
                ref.read(postsProvider.notifier).loadPosts(forceRefresh: true);
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
                final dpr = MediaQuery.devicePixelRatioOf(context);
                final avatarPx = (32.w * dpr).round().clamp(1, 512);
                return ClipOval(
                  child: avatarUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: avatarUrl,
                          width: 32.w,
                          height: 32.w,
                          fit: BoxFit.cover,
                          memCacheWidth: avatarPx,
                          memCacheHeight: avatarPx,
                          cacheManager: AppMediaCache.feedMedia,
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
      return InstagramPostCard(
        key: ValueKey('feed_post_${post.id}'),
        post: post,
        useFeedCommentCounts: true,
      );
    }

    return Container(
      key: ValueKey('feed_video_${post.id}'),
      margin: EdgeInsets.only(bottom: 16.h),
      child: VideoTile(
        thumbnailUrl: post.effectiveThumbnailUrl ?? post.thumbnailUrl ?? post.imageUrl ?? '',
        title: post.caption,
        channelName: post.author.displayName.isNotEmpty ? post.author.displayName : post.author.username,
        channelAvatar: post.author.avatarUrl,
        authorId: post.author.id,
        blurHash: post.blurHash,
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
