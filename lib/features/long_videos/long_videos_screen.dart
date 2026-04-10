import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/models/post_model.dart';
import '../../core/widgets/safe_better_player.dart';
import '../../core/widgets/feed_cached_post_image.dart';
import '../../core/widgets/feed_image_precache.dart';
import '../../core/media/app_media_cache.dart';
import '../../core/utils/share_link_helper.dart';
import '../../services/posts/posts_service.dart';
import '../../core/providers/auth_provider_riverpod.dart';
import '../../core/providers/follow_provider_riverpod.dart';
import '../../core/providers/posts_provider_riverpod.dart';
import '../../core/providers/main_tab_index_provider.dart';
import '../video/video_player_screen.dart';
import '../profile/profile_screen.dart';
import 'providers/long_videos_provider.dart';
import 'providers/long_video_playback_provider.dart';
import 'providers/long_video_widget_provider.dart';
import 'dart:async';
import 'dart:ui';

/// Long Videos Page - YouTube-style video feed with Riverpod state management
class LongVideosScreen extends ConsumerStatefulWidget {
  const LongVideosScreen({super.key});

  @override
  ConsumerState<LongVideosScreen> createState() => _LongVideosScreenState();
}

class _LongVideosScreenState extends ConsumerState<LongVideosScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final ScrollController _scrollController = ScrollController();
  final Map<String, Timer> _controlsTimers = {};
  final Map<String, GlobalKey> _videoKeys = {}; // Track widget keys for position detection
  DateTime? _lastPlayActionTime; // Prevent rapid play/pause toggles
  Timer? _scrollThrottleTimer; // Throttle scroll events
  bool _ensuredInitialLoad = false;
  @override
  void initState() {
    super.initState();
    // Setup scroll listener for pagination
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = ref.read(longVideosProvider);
      if (s.videos.isNotEmpty) {
        _ensuredInitialLoad = true;
        return;
      }
      if (_ensuredInitialLoad) return;
      if (!s.isLoading && s.error == null && !s.initialFetchCompleted) {
        _ensuredInitialLoad = true;
        ref.read(longVideosProvider.notifier).loadVideos();
      }
    });
  }

  void _pauseVideoById(String videoId) {
    final videos = ref.read(longVideosListProvider);
    try {
      final video = videos.firstWhere((v) => v.id == videoId);
      if (video.videoUrl != null) {
        try {
          final key = VideoWidgetKey(video.id, video.videoUrl!);
          if (ref.read(longVideoWidgetProvider(key)).isPlaying) {
            ref.read(longVideoWidgetProvider(key).notifier).pause();
          }
        } catch (e) {
          // Ignore errors
        }
      }
    } catch (e) {
      // Video not found, ignore
    }
  }

  /// Pause all videos except the one with the given ID
  void _pauseAllVideosExcept(String exceptVideoId) {
    final videos = ref.read(longVideosListProvider);
    
    for (var video in videos) {
      // Skip the video that should be playing
      if (video.id == exceptVideoId) continue;
      
      // Skip if no video URL
      if (video.videoUrl == null) continue;
      
      try {
        final key = VideoWidgetKey(video.id, video.videoUrl!);
        if (ref.read(longVideoWidgetProvider(key)).isPlaying) {
          ref.read(longVideoWidgetProvider(key).notifier).pause();
        }
      } catch (e) {
        // Provider might not exist, ignore
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _scrollThrottleTimer?.cancel();
    for (var timer in _controlsTimers.values) {
      timer.cancel();
    }
    _controlsTimers.clear();
    _videoKeys.clear();
    // Do not use ref in dispose() — Riverpod invalidates ref when the widget is torn down.
    // Playback state is cleared when providers are no longer watched (e.g. autoDispose).
    super.dispose();
  }

  void _startControlsTimer(String videoId) {
    _controlsTimers[videoId]?.cancel();
    _controlsTimers[videoId] = Timer(const Duration(seconds: 3), () {
      // Only update if widget is still mounted and video is still playing
      if (mounted) {
        try {
          final playbackState = ref.read(longVideoPlaybackProvider);
          // Only hide controls if this video is still the currently playing one
          if (playbackState.currentlyPlayingVideoId == videoId) {
            ref.read(longVideoPlaybackProvider.notifier).setControlsVisibility(videoId, false);
          }
        } catch (e) {
          // Provider might be disposed, ignore
        }
      }
    });
  }

  void _showControlsTemporarily(String videoId) {
    if (mounted) {
      ref.read(longVideoPlaybackProvider.notifier).setControlsVisibility(videoId, true);
      _startControlsTimer(videoId);
    }
  }

  void _pauseAllInlinePlayers() {
    final videos = ref.read(longVideosListProvider);
    for (final video in videos) {
      final u = video.videoUrl;
      if (u == null || u.isEmpty) continue;
      try {
        ref.read(longVideoWidgetProvider(VideoWidgetKey(video.id, u)).notifier).pause();
      } catch (_) {}
    }
    ref.read(longVideoPlaybackProvider.notifier).clearCurrentlyPlaying();
  }

  void _pauseAllOtherVideos(String currentVideoId, String? currentVideoUrl) {
    if (currentVideoUrl == null) return;
    
    final videos = ref.read(longVideosListProvider);
    
    // CRITICAL: Pause ALL videos except the current one
    // Each widget has its own provider instance, so this is safe
    for (var video in videos) {
      // Skip the current video
      if (video.id == currentVideoId) continue;
      
      // Skip if no video URL
      if (video.videoUrl == null) continue;
      
      try {
        final key = VideoWidgetKey(video.id, video.videoUrl!);
        if (ref.read(longVideoWidgetProvider(key)).isPlaying) {
          ref.read(longVideoWidgetProvider(key).notifier).pause();
        }
      } catch (e) {
        // Provider might not exist, ignore
      }
    }
  }

  void _onScroll() {
    // Throttle scroll events to improve performance
    _scrollThrottleTimer?.cancel();
    _scrollThrottleTimer = Timer(const Duration(milliseconds: 150), () {
      _handleScroll();
    });
  }

  void _handleScroll() {
    if (!mounted) return;

    // Check pagination
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      // Load more when 80% scrolled
      final notifier = ref.read(longVideosProvider.notifier);
      notifier.loadMoreVideos();
    }
    
    // Check if manually played video is still visible
    _checkManualPlayVideoVisibility();
  }

  /// Check if manually played video is still visible, if not, stop it
  /// If a video was manually played and user scrolls away, STOP it immediately
  void _checkManualPlayVideoVisibility() {
    if (!mounted) return;

    final playbackState = ref.read(longVideoPlaybackProvider);
    if (!playbackState.isManualPlay || playbackState.currentlyPlayingVideoId == null) {
      return;
    }

    final videoId = playbackState.currentlyPlayingVideoId!;
    final key = _videoKeys[videoId];
    if (key?.currentContext == null) {
      // Video widget is not in tree, stop it
      _pauseVideoById(videoId);
      ref.read(longVideoPlaybackProvider.notifier).clearCurrentlyPlaying();
      return;
    }

    try {
      final renderBox = key!.currentContext!.findRenderObject() as RenderBox?;
      if (renderBox == null || !renderBox.attached) {
        // Video is not visible, stop it
        _pauseVideoById(videoId);
        ref.read(longVideoPlaybackProvider.notifier).clearCurrentlyPlaying();
        return;
      }

      final screenHeight = MediaQuery.of(context).size.height;
      final position = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;

      // Check if video is still sufficiently visible (at least 40% on screen)
      // Use 40% threshold to stop video before it completely scrolls away
      final visibleTop = position.dy.clamp(0.0, screenHeight);
      final visibleBottom = (position.dy + size.height).clamp(0.0, screenHeight);
      final visibleHeight = visibleBottom - visibleTop;
      final visibleRatio = visibleHeight / size.height;

      if (visibleRatio < 0.4) {
        // Video scrolled out of view, STOP it immediately
        _pauseVideoById(videoId);
        ref.read(longVideoPlaybackProvider.notifier).clearCurrentlyPlaying();
        // Show controls so play icon appears when video is paused
        ref.read(longVideoPlaybackProvider.notifier).setControlsVisibility(videoId, true);
      }
    } catch (e) {
      // On error, assume video is not visible, stop it
      _pauseVideoById(videoId);
      ref.read(longVideoPlaybackProvider.notifier).clearCurrentlyPlaying();
    }
  }


  String _formatViews(int views) {
    if (views >= 1000000) {
      return '${(views / 1000000).toStringAsFixed(1)}M views';
    } else if (views >= 1000) {
      return '${(views / 1000).toStringAsFixed(1)}K views';
    }
    return '$views views';
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    }
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final videos = ref.watch(longVideosListProvider);
    final isLoading = ref.watch(longVideosLoadingProvider);
    final isRefreshing = ref.watch(longVideosRefreshingProvider);
    final error = ref.watch(longVideosErrorProvider);
    final offlineBanner = ref.watch(longVideosOfflineBannerProvider);

    ref.listen<int>(mainTabIndexProvider, (prev, next) {
      if (prev == 3 && next != 3) {
        _pauseAllInlinePlayers();
        ref.read(longVideosProvider.notifier).cancelPendingNetworkLoad();
      }
    });

    // Listen to playback state changes to pause other videos
    // This is called in build, which is safe for ref.listen
    // Only listen once per build cycle to prevent multiple subscriptions
    ref.listen<LongVideoPlaybackState>(
      longVideoPlaybackProvider,
      (previous, next) {
        if (previous?.currentlyPlayingVideoId != next.currentlyPlayingVideoId && mounted) {
          // A new video started playing, pause ALL other videos immediately
          if (next.currentlyPlayingVideoId != null) {
            // Pause all videos except the new one
            _pauseAllVideosExcept(next.currentlyPlayingVideoId!);
          }
        }
      },
    );

    final showSkeleton = videos.isEmpty && isLoading;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            if (offlineBanner && videos.isNotEmpty)
              Material(
                color: ThemeHelper.getSurfaceColor(context).withValues(alpha: 0.95),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    children: [
                      Icon(
                        Icons.cloud_off_outlined,
                        size: 18,
                        color: ThemeHelper.getTextSecondary(context),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Showing saved long videos',
                          style: TextStyle(
                            color: ThemeHelper.getTextSecondary(context),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: error != null && videos.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: ThemeHelper.getTextSecondary(context),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading videos',
                            style: TextStyle(
                              color: ThemeHelper.getTextPrimary(context),
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () {
                              ref
                                  .read(longVideosProvider.notifier)
                                  .loadVideos(refresh: true);
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : showSkeleton
                      ? _buildLongVideoSkeletonList()
                      : RefreshIndicator(
                          onRefresh: () async {
                            await ref
                                .read(longVideosProvider.notifier)
                                .loadVideos(refresh: true);
                          },
                          color: ThemeHelper.getAccentColor(context),
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: EdgeInsets.zero,
                            itemCount: videos.length +
                                ((isLoading || isRefreshing) &&
                                        videos.isNotEmpty
                                    ? 1
                                    : 0),
                            itemBuilder: (context, index) {
                              if (index == videos.length) {
                                return _buildLoadMoreSkeleton();
                              }
                              final video = videos[index];
                              if (!_videoKeys.containsKey(video.id)) {
                                _videoKeys[video.id] = GlobalKey();
                              }
                              return _buildVideoCard(video,
                                  key: _videoKeys[video.id]);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadMoreSkeleton() {
    final base = Theme.of(context).brightness == Brightness.dark
        ? Colors.white10
        : Colors.black12;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Shimmer.fromColors(
        baseColor: base,
        highlightColor: base.withValues(alpha: 0.35),
        child: Row(
          children: [
            Container(
              width: 120,
              height: 68,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 14,
                    width: double.infinity,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 12,
                    width: 120,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLongVideoSkeletonList() {
    final base = Theme.of(context).brightness == Brightness.dark
        ? Colors.white10
        : Colors.black12;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Shimmer.fromColors(
            baseColor: base,
            highlightColor: base.withValues(alpha: 0.35),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 120,
                  height: 68,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 10,
                        width: 80,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        height: 14,
                        width: double.infinity,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 12,
                        width: 160,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderDecoration = BoxDecoration(
      border: Border(
        bottom: BorderSide(
          color: ThemeHelper.getBorderColor(context),
          width: 0.5,
        ),
      ),
    );
    return isDark
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: borderDecoration.copyWith(
              color: ThemeHelper.getBackgroundColor(context),
            ),
            child: _buildHeaderContent(),
          )
        : ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: borderDecoration.copyWith(
                  color: Colors.white.withOpacity(0.08),
                ),
                child: _buildHeaderContent(),
              ),
            ),
          );
  }

  Widget _buildHeaderContent() {
    return Row(
        children: [
          // App Logo/Name
          Text(
            'VidConnect',
            style: TextStyle(
              color: ThemeHelper.getTextPrimary(context),
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
        ],
      );
  }

  Widget _buildVideoCard(PostModel video, {GlobalKey? key}) {
    final views = video.likes * 10; // Convert likes to views for display
    final formattedViews = _formatViews(views);
    final timeAgo = _formatTimeAgo(video.createdAt);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      key: key ?? ValueKey(video.id),
      children: [
        isDark
            ? Container(
                color: ThemeHelper.getBackgroundColor(context),
                child: _buildVideoCardContent(video, formattedViews, timeAgo),
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(0),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                    ),
                    child: _buildVideoCardContent(video, formattedViews, timeAgo),
                  ),
                ),
              ),
        _buildPostDivider(),
      ],
    );
  }

  Widget _buildVideoCardContent(PostModel video, String formattedViews, String timeAgo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          // User Info Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Profile Picture - Clickable
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfileScreen(user: video.author),
                      ),
                    );
                  },
                  child: ClipOval(
                    child: video.author.avatarUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: video.author.avatarUrl,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            cacheManager: AppMediaCache.feedMedia,
                            memCacheWidth: (40 *
                                    MediaQuery.devicePixelRatioOf(context))
                                .round()
                                .clamp(1, 256),
                            memCacheHeight: (40 *
                                    MediaQuery.devicePixelRatioOf(context))
                                .round()
                                .clamp(1, 256),
                            placeholder: (context, url) => Container(
                              width: 40,
                              height: 40,
                              color: ThemeHelper.getSurfaceColor(context),
                            ),
                            errorWidget: (context, url, error) => Container(
                              width: 40,
                              height: 40,
                              color: ThemeHelper.getSurfaceColor(context),
                              child: Icon(
                                Icons.person,
                                color: ThemeHelper.getTextSecondary(context),
                                size: 20,
                              ),
                            ),
                          )
                        : Container(
                            width: 40,
                            height: 40,
                            color: ThemeHelper.getSurfaceColor(context),
                            child: Icon(
                              Icons.person,
                              color: ThemeHelper.getTextSecondary(context),
                              size: 20,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                // User Name and Views - Clickable
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProfileScreen(user: video.author),
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          video.author.displayName,
                          style: TextStyle(
                            color: ThemeHelper.getTextPrimary(context),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$formattedViews • $timeAgo',
                          style: TextStyle(
                            color: ThemeHelper.getTextSecondary(context),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Follow Button - hide when author is current user; state via Riverpod
                Consumer(
                  builder: (context, ref, child) {
                    final currentUser = ref.watch(currentUserProvider);
                    if (currentUser?.id == video.author.id) {
                      return const SizedBox.shrink();
                    }
                    final followOverrides = ref.watch(followStateProvider);
                    final followState = ref.watch(followProvider);
                    final posts = ref.watch(postsListProvider);
                    PostModel? post;
                    try {
                      post = posts.firstWhere((p) => p.author.id == video.author.id);
                    } catch (_) {
                      post = null;
                    }
                    final overrideStatus = followOverrides[video.author.id];
                    final isFollowing =
                        overrideStatus == FollowRelationshipStatus.following ||
                            (overrideStatus == null &&
                                (followState.followingIds.isNotEmpty
                                    ? followState.followingIds
                                        .contains(video.author.id)
                                    : (post?.author.isFollowing ??
                                        video.author.isFollowing)));
                    return GestureDetector(
                      onTap: () {
                        ref.read(followProvider.notifier).toggleFollow(video.author.id);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: isFollowing ? Colors.transparent : ThemeHelper.getAccentColor(context),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: isFollowing
                                ? ThemeHelper.getTextPrimary(context)
                                : ThemeHelper.getAccentColor(context),
                            width: isFollowing ? 1.5 : 1,
                          ),
                        ),
                        child: Text(
                          isFollowing ? 'Following' : 'Follow',
                          style: TextStyle(
                            color: isFollowing
                                ? ThemeHelper.getTextPrimary(context)
                                : ThemeHelper.getOnAccentColor(context),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _showLongVideoMoreMenu(context, video),
                  child: Icon(
                    CupertinoIcons.ellipsis,
                    color: ThemeHelper.getTextPrimary(context),
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        // Caption - below the icon/author row, above video
        if (video.caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              video.caption,
              style: TextStyle(
                color: ThemeHelper.getTextPrimary(context),
                fontSize: 14,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        // Video Player/Thumbnail
        _buildVideoPlayer(video),
      ],
    );
  }

  void _showLongVideoMoreMenu(BuildContext context, PostModel video) {
    final parentContext = context;
    final currentUserId = ref.read(authProvider).currentUser?.id ?? '';
    final isOwner =
        currentUserId.isNotEmpty && currentUserId == video.author.id;

    showCupertinoModalPopup(
      context: parentContext,
      builder: (sheetContext) => CupertinoActionSheet(
        actions: [
          if (isOwner)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () async {
                Navigator.pop(sheetContext);

                final result = await PostsService().deletePost(
                  postId: video.id,
                  currentUserId: currentUserId,
                  postAuthorId: video.author.id,
                );

                if (!parentContext.mounted) return;
                ScaffoldMessenger.of(parentContext).showSnackBar(
                  SnackBar(
                    content: Text(
                      result.success
                          ? 'Post deleted'
                          : (result.errorMessage ?? 'Delete failed'),
                    ),
                    backgroundColor: result.success
                        ? ThemeHelper.getAccentColor(parentContext)
                        : ThemeHelper.getSurfaceColor(parentContext),
                  ),
                );

                if (result.success) {
                  ref.read(longVideosProvider.notifier).removeVideoById(video.id);
                  await ref.read(postsProvider.notifier).loadPosts();
                }
              },
              child: const Text('Delete'),
            ),
          if (!isOwner)
            CupertinoActionSheetAction(
              child: const Text('Report'),
              onPressed: () async {
                Navigator.pop(sheetContext);

                final result = await PostsService().reportPost(
                  postId: video.id,
                  currentUserId: currentUserId,
                  postAuthorId: video.author.id,
                );

                if (!parentContext.mounted) return;
                ScaffoldMessenger.of(parentContext).showSnackBar(
                  SnackBar(
                    content: Text(
                      result.success
                          ? 'Reported'
                          : (result.errorMessage ?? 'Report failed'),
                    ),
                    backgroundColor: result.success
                        ? ThemeHelper.getAccentColor(parentContext)
                        : ThemeHelper.getSurfaceColor(parentContext),
                  ),
                );
              },
            ),
          CupertinoActionSheetAction(
            child: const Text('Copy Link'),
            onPressed: () {
              final thumb = video.effectiveThumbnailUrl;
              final link = ShareLinkHelper.build(
                contentId: video.id,
                thumbnailUrl: thumb,
              );
              Navigator.pop(sheetContext);
              Clipboard.setData(ClipboardData(text: link));
              if (!parentContext.mounted) return;
              ScaffoldMessenger.of(parentContext).showSnackBar(
                SnackBar(
                  content: Text(
                    'Link copied!',
                    style:
                        TextStyle(color: ThemeHelper.getTextPrimary(parentContext)),
                  ),
                  backgroundColor:
                      ThemeHelper.getSurfaceColor(parentContext).withOpacity(0.95),
                ),
              );
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('Cancel'),
          onPressed: () => Navigator.pop(sheetContext),
        ),
      ),
    );
  }

  Widget _buildPostDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    ThemeHelper.getBorderColor(context).withOpacity(0.2),
                    ThemeHelper.getBorderColor(context).withOpacity(0.5),
                  ],
                ),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ThemeHelper.getBorderColor(context).withOpacity(0.4),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    ThemeHelper.getBorderColor(context).withOpacity(0.5),
                    ThemeHelper.getBorderColor(context).withOpacity(0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  Widget _buildVideoPlayer(PostModel video) {
    final videoUrl = video.videoUrl;
    
    if (videoUrl == null) {
      return Container(
        width: double.infinity,
        height: 220,
        color: ThemeHelper.getSurfaceColor(context),
        child: Icon(
          Icons.video_library,
          color: ThemeHelper.getTextSecondary(context),
          size: 48,
        ),
      );
    }

    // CRITICAL: Use per-widget provider with unique key (widgetId + videoUrl)
    // This ensures each widget has its own independent video player instance
    final key = VideoWidgetKey(video.id, videoUrl);
    final widgetState = ref.watch(longVideoWidgetProvider(key));
    final playbackState = ref.watch(longVideoPlaybackProvider);
    
    final isVideoInitialized = widgetState.isInitialized;
    final isPlaying = widgetState.isPlaying;
    final isThisVideoPlaying = playbackState.currentlyPlayingVideoId == video.id && isPlaying;
    final showControls = playbackState.showControls[video.id] ?? true;

    return Stack(
      children: [
          // Video player or thumbnail with tap handler
          GestureDetector(
            onTap: () {
              // Only navigate if video is not initialized or if tapping outside play button
              // Play button will handle its own tap and stop propagation
              if (!isVideoInitialized || !isThisVideoPlaying) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VideoPlayerScreen(
                      videoUrl: videoUrl,
                      title: video.caption,
                      author: video.author,
                      post: video,
                    ),
                  ),
                );
              }
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: double.infinity,
              height: 220,
              color: Colors.black,
              child: (isVideoInitialized &&
                      widgetState.controller != null &&
                      (isThisVideoPlaying || widgetState.isSeeking))
                  ? RepaintBoundary(
                      child: ClipRect(
                        child: SizedBox(
                          width: double.infinity,
                          height: 220,
                          child: SafeBetterPlayerWrapper(
                            controller: widgetState.controller!,
                          ),
                        ),
                      ),
                    )
                  : (() {
                      final rawThumb =
                          video.effectiveThumbnailUrl ??
                              video.thumbnailUrl ??
                              video.imageUrl ??
                              '';
                      final networkThumb = rawThumb.isNotEmpty &&
                              !isProtectedVideoCdnThumbnailUrl(rawThumb)
                          ? rawThumb
                          : '';
                      return FeedCachedPostImage(
                        imageUrl: networkThumb,
                        postId: video.id,
                        blurHash: video.blurHash,
                        fit: BoxFit.cover,
                        useShimmerWhileLoading: true,
                      );
                    })(),
            ),
          ),
          
          // Play/Pause button - same as video_tile.dart
          if (isVideoInitialized && widgetState.controller != null)
            Positioned.fill(
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    // Prevent rapid toggles (debounce)
                    final now = DateTime.now();
                    if (_lastPlayActionTime != null &&
                        now.difference(_lastPlayActionTime!) < const Duration(milliseconds: 300)) {
                      return; // Ignore rapid taps
                    }
                    _lastPlayActionTime = now;
                    
                    // CRITICAL: Pause ALL other videos FIRST, before toggling this one
                    // This prevents multiple videos from playing simultaneously
                    _pauseAllOtherVideos(video.id, videoUrl);
                    
                    // DISABLE AUTOPLAY when user manually plays a video
                    ref.read(longVideoPlaybackProvider.notifier).disableAutoplay();
                    
                    // Then toggle play/pause for this video (with lazy initialization)
                    final widgetKey = VideoWidgetKey(video.id, videoUrl);
                    final notifier = ref.read(longVideoWidgetProvider(widgetKey).notifier);
                    
                    notifier.togglePlayPause().then((_) {
                      // Update currently playing video after async operation
                      if (mounted) {
                        final playing =
                            ref.read(longVideoWidgetProvider(widgetKey)).isPlaying;
                        if (playing) {
                          ref
                              .read(longVideosProvider.notifier)
                              .prefetchNextAfter(video.id);
                          // Set this video as currently playing
                          ref.read(longVideoPlaybackProvider.notifier).setCurrentlyPlaying(video.id);
                          _showControlsTemporarily(video.id);
                        } else {
                          // If paused, clear currently playing
                          ref.read(longVideoPlaybackProvider.notifier).clearCurrentlyPlaying();
                          ref.read(longVideoPlaybackProvider.notifier).setControlsVisibility(video.id, false);
                        }
                      }
                    });
                  },
                  behavior: HitTestBehavior.opaque, // Stops event propagation to parent
                  child: AnimatedOpacity(
                    // Show play/pause button when:
                    // 1. Video is playing AND controls are visible (show pause icon)
                    // 2. Video is initialized but NOT playing (always show play icon when paused)
                    // 3. Video is not initialized (show play icon)
                    opacity: (isThisVideoPlaying && showControls) || 
                             (isVideoInitialized && !isThisVideoPlaying) || 
                             (!isVideoInitialized)
                        ? 1.0 
                        : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.6),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        isPlaying && isThisVideoPlaying
                            ? CupertinoIcons.pause_circle_fill
                            : CupertinoIcons.play_circle_fill,
                        size: 70,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
            // Play button overlay when video not initialized (same as video_tile.dart)
            Positioned.fill(
              child: Stack(
                children: [
                  // Background tap area - navigates to fullscreen
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => VideoPlayerScreen(
                            videoUrl: videoUrl,
                            title: video.caption,
                            author: video.author,
                            post: video,
                          ),
                        ),
                      );
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      color: Colors.transparent,
                    ),
                  ),
                  // Play button - plays video inline, stops propagation
                  Center(
                    child: GestureDetector(
                      onTap: () {
                        // Prevent rapid toggles (debounce)
                        final now = DateTime.now();
                        if (_lastPlayActionTime != null &&
                            now.difference(_lastPlayActionTime!) < const Duration(milliseconds: 300)) {
                          return; // Ignore rapid taps
                        }
                        _lastPlayActionTime = now;
                        
                        // CRITICAL: Pause ALL other videos FIRST, before playing this one
                        // This prevents multiple videos from playing simultaneously
                        _pauseAllOtherVideos(video.id, videoUrl);
                        
                        // DISABLE AUTOPLAY when user manually plays a video
                        ref.read(longVideoPlaybackProvider.notifier).disableAutoplay();
                        
                        // Then initialize and play this video (lazy initialization)
                        final widgetKey = VideoWidgetKey(video.id, videoUrl);
                        final notifier = ref.read(longVideoWidgetProvider(widgetKey).notifier);
                        
                        // Play will trigger lazy initialization if needed
                        notifier.play().then((_) {
                          // Set this video as currently playing after initialization
                          if (mounted) {
                            ref
                                .read(longVideosProvider.notifier)
                                .prefetchNextAfter(video.id);
                            ref.read(longVideoPlaybackProvider.notifier).setCurrentlyPlaying(video.id);
                            _showControlsTemporarily(video.id);
                          }
                        });
                      },
                      behavior: HitTestBehavior.opaque, // Stops event propagation
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          CupertinoIcons.play_fill,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // Forward/Backward buttons - appear outside thumbnail on bottom left when playing
          if (isThisVideoPlaying && isVideoInitialized)
            Positioned(
              left: 12,
              bottom: 12,
              child: Row(
                children: [
                  // Backward 10s button
                  GestureDetector(
                    onTap: () async {
                      // Stop propagation to prevent navigation
                      final key = VideoWidgetKey(video.id, videoUrl);
                      final notifier = ref.read(longVideoWidgetProvider(key).notifier);
                      await notifier.seekBackward();
                      if (mounted) {
                        _showControlsTemporarily(video.id);
                      }
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.replay_10,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Forward 10s button
                  GestureDetector(
                    onTap: () async {
                      // Stop propagation to prevent navigation
                      final key = VideoWidgetKey(video.id, videoUrl);
                      final notifier = ref.read(longVideoWidgetProvider(key).notifier);
                      await notifier.seekForward();
                      if (mounted) {
                        _showControlsTemporarily(video.id);
                      }
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.forward_10,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // Duration badge
          if (video.videoDuration != null)
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _formatDuration(video.videoDuration!),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
      ],
    );
  }

}
