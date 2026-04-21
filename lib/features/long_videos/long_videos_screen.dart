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
import '../profile/profile_screen.dart';
import 'long_video_embedded_session_host.dart';
import '../../core/providers/long_video_embedded_handoff_provider.dart';
import 'long_videos_search_screen.dart';
import 'providers/long_videos_provider.dart';
import 'providers/long_video_playback_provider.dart';
import 'providers/long_video_autoplay_manager.dart';
import 'providers/long_video_feed_search_query_provider.dart';
import 'providers/long_video_widget_provider.dart';
import 'widgets/long_video_tile_visibility.dart';
import 'dart:async';
import 'dart:ui';

/// Long Videos Page - YouTube-style video feed with Riverpod state management
class LongVideosScreen extends ConsumerStatefulWidget {
  /// Clears the bottom nav / safe area overlap (same idea as [HomeFeedPage.bottomPadding]).
  final double bottomPadding;

  const LongVideosScreen({super.key, this.bottomPadding = 0});

  @override
  ConsumerState<LongVideosScreen> createState() => _LongVideosScreenState();
}

class _LongVideosScreenState extends ConsumerState<LongVideosScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final ScrollController _scrollController = ScrollController();
  Timer? _scrollThrottleTimer; // Throttle scroll events
  Timer? _warmPoolDebounceTimer; // Section 5.1 — debounced warm / eviction
  final Set<String> _warmPoolVideoIds = {};
  final Map<String, Timer> _pendingReleaseTimers = {};
  static const double _approxLongVideoTileHeight = 440;
  static const Duration _autoplayDwellDelay = Duration(milliseconds: 900);
  bool _isRoutePushInProgress = false;
  int _autoplayRequestId = 0;
  bool _autoplayArmedByUserScroll = false;
  ProviderSubscription<int>? _mainTabSub;
  ProviderSubscription<String?>? _dominantSub;
  ProviderSubscription<LongVideoPlaybackState>? _playbackSub;
  ProviderSubscription<LongVideosState>? _videosSub;
  bool _ensuredInitialLoad = false;
  @override
  void initState() {
    super.initState();
    _mainTabSub = ref.listenManual<int>(mainTabIndexProvider, (prev, next) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (prev == 3 && next != 3) {
          _autoplayArmedByUserScroll = false;
          _warmPoolDebounceTimer?.cancel();
          _pauseAllInlinePlayers();
          ref.read(longVideosProvider.notifier).cancelPendingNetworkLoad();
          ref.read(longVideoAutoplayManagerProvider.notifier).disable();
        } else if (prev != null && prev != 3 && next == 3) {
          _autoplayArmedByUserScroll = false;
          ref.read(longVideoAutoplayManagerProvider.notifier).enable();
          _scheduleWarmPoolAfterTabReturn();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            Future<void>.delayed(const Duration(milliseconds: 120), () {
              if (!mounted) return;
              _armAutoplayIfLongVideosTabVisible();
            });
          });
        }
      });
    });
    _dominantSub = ref.listenManual<String?>(
      longVideoAutoplayManagerProvider.select((s) => s.dominantVideoId),
      (prev, next) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          unawaited(_onAutoplayDominantChanged(prev, next));
        });
      },
    );
    _playbackSub = ref.listenManual<LongVideoPlaybackState>(
      longVideoPlaybackProvider,
      (previous, next) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (previous?.currentlyPlayingVideoId != next.currentlyPlayingVideoId) {
            if (next.currentlyPlayingVideoId != null) {
              _pauseAllVideosExcept(next.currentlyPlayingVideoId!);
            }
          }
        });
      },
    );
    _videosSub = ref.listenManual<LongVideosState>(
      longVideosProvider,
      (prev, next) {
        if (next.videos.isEmpty) return;
        final hadVideos = prev?.videos.isNotEmpty == true;
        final firstBatch = !hadVideos && next.videos.isNotEmpty;
        final refreshDone =
            (prev?.isRefreshing == true) && !next.isRefreshing && next.videos.isNotEmpty;
        if (!firstBatch && !refreshDone) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Future<void>.delayed(const Duration(milliseconds: 120), () {
            if (!mounted) return;
            _armAutoplayIfLongVideosTabVisible();
          });
        });
      },
    );
    // Setup scroll listener for pagination
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = ref.read(longVideosProvider);
      if (s.videos.isNotEmpty) {
        _ensuredInitialLoad = true;
        Future<void>.delayed(const Duration(milliseconds: 120), () {
          if (!mounted) return;
          _armAutoplayIfLongVideosTabVisible();
        });
        return;
      }
      if (_ensuredInitialLoad) return;
      if (!s.isLoading && s.error == null && !s.initialFetchCompleted) {
        _ensuredInitialLoad = true;
        ref.read(longVideosProvider.notifier).loadVideos();
      }
    });
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
    _autoplayRequestId++;
    _isRoutePushInProgress = true;
    _mainTabSub?.close();
    _dominantSub?.close();
    _playbackSub?.close();
    _videosSub?.close();
    _scrollController.dispose();
    _scrollThrottleTimer?.cancel();
    _warmPoolDebounceTimer?.cancel();
    for (final t in _pendingReleaseTimers.values) {
      t.cancel();
    }
    _pendingReleaseTimers.clear();
    // Do not use ref in dispose() — Riverpod invalidates ref when the widget is torn down.
    // Playback state is cleared when providers are no longer watched (e.g. autoDispose).
    super.dispose();
  }

  /// Arms feed autoplay without requiring a scroll gesture (first paint / tab / refresh).
  void _armAutoplayIfLongVideosTabVisible() {
    if (!mounted) return;
    if (ref.read(mainTabIndexProvider) != 3) return;
    _autoplayArmedByUserScroll = true;

    void seedHeadAndKick() {
      if (!mounted) return;
      if (ref.read(mainTabIndexProvider) != 3) return;
      var dom = ref.read(longVideoAutoplayManagerProvider).dominantVideoId;
      if (dom == null) {
        final videos = ref.read(longVideosListProvider);
        if (videos.isNotEmpty) {
          final u = videos.first.videoUrl;
          if (u != null && u.isNotEmpty) {
            ref.read(longVideoAutoplayManagerProvider.notifier).adoptHeadIfUnset(videos.first.id);
            dom = ref.read(longVideoAutoplayManagerProvider).dominantVideoId;
          }
        }
      }
      if (dom != null) {
        unawaited(_onAutoplayDominantChanged(null, dom));
      }
    }

    seedHeadAndKick();
    // Visibility can report after first frame; seed + autoplay only if still no dominant.
    Future<void>.delayed(const Duration(milliseconds: 360), () {
      if (!mounted) return;
      if (ref.read(mainTabIndexProvider) != 3) return;
      if (ref.read(longVideoAutoplayManagerProvider).dominantVideoId != null) return;
      seedHeadAndKick();
    });
  }

  void _pauseAllInlinePlayers() {
    final videos = ref.read(longVideosListProvider);
    for (final video in videos) {
      final u = video.videoUrl;
      if (u == null || u.isEmpty) continue;
      try {
        ref
            .read(longVideoWidgetProvider(VideoWidgetKey(video.id, u)).notifier)
            .pause();
      } catch (_) {}
    }
    ref.read(longVideoPlaybackProvider.notifier).clearCurrentlyPlaying();
  }

  PostModel? _longVideoPostById(String id) {
    try {
      return ref.read(longVideosListProvider).firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> _autoPauseLongVideoTile(String videoId) async {
    final post = _longVideoPostById(videoId);
    final u = post?.videoUrl;
    if (u == null || u.isEmpty) return;
    await ref
        .read(longVideoWidgetProvider(VideoWidgetKey(videoId, u)).notifier)
        .autoPause();
  }

  Future<void> _onAutoplayDominantChanged(String? prev, String? next) async {
    final requestId = ++_autoplayRequestId;
    if (!mounted) return;
    if (_isRoutePushInProgress) return;
    if (!_autoplayArmedByUserScroll) return;
    final mgr = ref.read(longVideoAutoplayManagerProvider);
    if (!mgr.isEnabled) return;
    final pb = ref.read(longVideoPlaybackProvider);
    if (!pb.isAutoplayEnabled) return;

    if (prev != null && prev != next) {
      await _autoPauseLongVideoTile(prev);
      if (!mounted) return;
      if (ref.read(longVideoPlaybackProvider).currentlyPlayingVideoId == prev) {
        ref.read(longVideoPlaybackProvider.notifier).clearCurrentlyPlaying();
      }
    }

    if (next == null) return;
    final post = _longVideoPostById(next);
    final u = post?.videoUrl;
    if (u == null || u.isEmpty) return;

    await Future<void>.delayed(_autoplayDwellDelay);
    if (!mounted) return;
    if (requestId != _autoplayRequestId) return;
    if (_isRoutePushInProgress) return;
    if (ref.read(longVideoAutoplayManagerProvider).dominantVideoId != next) {
      return;
    }

    await ref
        .read(longVideoWidgetProvider(VideoWidgetKey(next, u)).notifier)
        .autoplay();
    if (!mounted) return;
    ref.read(longVideosProvider.notifier).prefetchNextAfter(next);
    ref.read(longVideoPlaybackProvider.notifier).setCurrentlyPlaying(next);
    ref
        .read(longVideoPlaybackProvider.notifier)
        .setControlsVisibility(next, false);
  }

  void _onScroll() {
    if (!_autoplayArmedByUserScroll &&
        _scrollController.hasClients &&
        _scrollController.offset.abs() > 10) {
      _autoplayArmedByUserScroll = true;
      final dom = ref.read(longVideoAutoplayManagerProvider).dominantVideoId;
      if (dom != null) {
        unawaited(_onAutoplayDominantChanged(null, dom));
      }
    }
    // Throttle scroll events to improve performance
    _scrollThrottleTimer?.cancel();
    _scrollThrottleTimer = Timer(const Duration(milliseconds: 150), () {
      _handleScroll();
    });
    _warmPoolDebounceTimer?.cancel();
    _warmPoolDebounceTimer = Timer(const Duration(milliseconds: 280), () {
      if (mounted) {
        unawaited(_applyScrollWarmPool());
      }
    });
  }

  int _estimateCenterVideoIndex(int listLength) {
    if (listLength <= 0) return 0;
    if (!_scrollController.hasClients) return 0;
    final offset = _scrollController.offset;
    final extent = _scrollController.position.viewportDimension;
    final centerPixel = offset + extent * 0.5;
    final idx =
        (centerPixel / _approxLongVideoTileHeight).floor().clamp(0, listLength - 1);
    return idx;
  }

  /// Warm ±2 around viewport center; release tiles that left the pool (Section 5).
  Future<void> _applyScrollWarmPool() async {
    if (!mounted) return;
    final videos = ref.read(longVideosListProvider);
    if (videos.isEmpty) return;

    final center = _estimateCenterVideoIndex(videos.length);
    final dominant = ref.read(longVideoAutoplayManagerProvider).dominantVideoId;
    final nextPool = <String>{};
    for (var i = center - 2; i <= center + 2; i++) {
      if (i < 0 || i >= videos.length) continue;
      final u = videos[i].videoUrl;
      if (u == null || u.isEmpty) continue;
      nextPool.add(videos[i].id);
    }
    for (final id in nextPool) {
      _pendingReleaseTimers.remove(id)?.cancel();
    }

    for (final id in _warmPoolVideoIds.difference(nextPool)) {
      if (id == dominant) continue;
      PostModel? post;
      try {
        post = videos.firstWhere((v) => v.id == id);
      } catch (_) {
        continue;
      }
      final u = post.videoUrl;
      if (u == null || u.isEmpty) continue;
      try {
        await ref
            .read(longVideoWidgetProvider(VideoWidgetKey(id, u)).notifier)
            .autoPause();
      } catch (_) {}
      _pendingReleaseTimers.remove(id)?.cancel();
      _pendingReleaseTimers[id] = Timer(const Duration(milliseconds: 900), () async {
        if (!mounted) return;
        if (_warmPoolVideoIds.contains(id)) {
          _pendingReleaseTimers.remove(id);
          return;
        }
        final currentDominant =
            ref.read(longVideoAutoplayManagerProvider).dominantVideoId;
        if (currentDominant == id) {
          _pendingReleaseTimers.remove(id);
          return;
        }
        final currentVideos = ref.read(longVideosListProvider);
        PostModel? currentPost;
        try {
          currentPost = currentVideos.firstWhere((v) => v.id == id);
        } catch (_) {
          _pendingReleaseTimers.remove(id);
          return;
        }
        final currentUrl = currentPost.videoUrl;
        if (currentUrl == null || currentUrl.isEmpty) {
          _pendingReleaseTimers.remove(id);
          return;
        }
        try {
          await ref
              .read(longVideoWidgetProvider(VideoWidgetKey(id, currentUrl)).notifier)
              .release();
        } catch (_) {}
        _pendingReleaseTimers.remove(id);
      });
    }
    _warmPoolVideoIds
      ..clear()
      ..addAll(nextPool);

    var staggerMs = 0;
    for (var i = center - 2; i <= center + 2; i++) {
      if (i < 0 || i >= videos.length) continue;
      final post = videos[i];
      final u = post.videoUrl;
      if (u == null || u.isEmpty) continue;
      final vk = VideoWidgetKey(post.id, u);
      final delay = Duration(milliseconds: staggerMs);
      staggerMs += 48;
      Future<void>.delayed(delay, () {
        if (!mounted) return;
        try {
          unawaited(
            ref.read(longVideoWidgetProvider(vk).notifier).warmUp(),
          );
        } catch (_) {}
      });
    }
  }

  void _scheduleWarmPoolAfterTabReturn() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_applyScrollWarmPool());
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

  bool _isValidRemoteUrl(String? value) {
    if (value == null || value.trim().isEmpty) return false;
    final uri = Uri.tryParse(value.trim());
    if (uri == null) return false;
    if (!(uri.scheme == 'http' || uri.scheme == 'https')) return false;
    return uri.host.isNotEmpty;
  }

  /// Inline feed tile: when to paint the [BetterPlayer] layer (thumbnail always underneath).
  /// Hides surface while buffering near 0:00 to avoid black/green flash. Player stays mounted.
  bool _longVideoTileVideoPaintVisible(LongVideoWidgetState s) {
    if (!s.isInitialized || s.controller == null) return false;
    final nearStart = s.position.inMilliseconds < 300;
    if (s.isBuffering && nearStart) return false;
    if (s.isSeeking) return true;
    if (s.isPlaying && !s.isBuffering) return true;
    if (s.isPlaying && s.isBuffering && !nearStart) return true;
    if (!s.isPlaying && s.position > Duration.zero) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final videos = ref.watch(longVideosListProvider);
    final isLoading = ref.watch(longVideosLoadingProvider);
    final isRefreshing = ref.watch(longVideosRefreshingProvider);
    final error = ref.watch(longVideosErrorProvider);
    final offlineBanner = ref.watch(longVideosOfflineBannerProvider);

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
                color: ThemeHelper.getSurfaceColor(context)
                    .withValues(alpha: 0.95),
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
                            padding:
                                EdgeInsets.only(bottom: widget.bottomPadding),
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
                              return _buildVideoCard(video,
                                  itemKey: ValueKey('lv_card_${video.id}_$index'));
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
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + widget.bottomPadding),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
        Expanded(
          child: Text(
            'VidConnect',
            style: TextStyle(
              color: ThemeHelper.getTextPrimary(context),
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Search long videos',
          icon: Icon(
            Icons.search,
            color: ThemeHelper.getTextPrimary(context),
            size: 26,
          ),
          onPressed: () {
            Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => LongVideosSearchScreen(
                  bottomPadding: widget.bottomPadding,
                ),
              ),
            ).then((_) {
              if (!context.mounted) return;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!context.mounted) return;
                ref.read(longVideoFeedSearchQueryProvider.notifier).state = '';
              });
            });
          },
        ),
      ],
    );
  }

  Widget _buildVideoCard(PostModel video, {Key? itemKey}) {
    final views = video.likes * 10; // Convert likes to views for display
    final formattedViews = _formatViews(views);
    final timeAgo = _formatTimeAgo(video.createdAt);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      key: itemKey ?? ValueKey(video.id),
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
                    child:
                        _buildVideoCardContent(video, formattedViews, timeAgo),
                  ),
                ),
              ),
        _buildPostDivider(),
      ],
    );
  }

  Widget _buildVideoCardContent(
      PostModel video, String formattedViews, String timeAgo) {
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
                  child: _isValidRemoteUrl(video.author.avatarUrl)
                      ? CachedNetworkImage(
                          imageUrl: video.author.avatarUrl,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          cacheManager: AppMediaCache.feedMedia,
                          memCacheWidth:
                              (40 * MediaQuery.devicePixelRatioOf(context))
                                  .round()
                                  .clamp(1, 256),
                          memCacheHeight:
                              (40 * MediaQuery.devicePixelRatioOf(context))
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
                    post =
                        posts.firstWhere((p) => p.author.id == video.author.id);
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
                      ref
                          .read(followProvider.notifier)
                          .toggleFollow(video.author.id);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: isFollowing
                            ? Colors.transparent
                            : ThemeHelper.getAccentColor(context),
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
                  ref
                      .read(longVideosProvider.notifier)
                      .removeVideoById(video.id);
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
                    style: TextStyle(
                        color: ThemeHelper.getTextPrimary(parentContext)),
                  ),
                  backgroundColor: ThemeHelper.getSurfaceColor(parentContext)
                      .withOpacity(0.95),
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
    final videoUrl = video.videoUrl?.trim();

    if (videoUrl == null || videoUrl.isEmpty) {
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
    final isDominant = ref.watch(
      longVideoAutoplayManagerProvider
          .select((s) => s.dominantVideoId == video.id),
    );

    final isVideoInitialized = widgetState.isInitialized;

    final rawThumb = video.effectiveThumbnailUrl ??
        video.thumbnailUrl ??
        video.imageUrl ??
        '';
    final networkThumb = _isValidRemoteUrl(rawThumb) &&
            !isProtectedVideoCdnThumbnailUrl(rawThumb)
        ? rawThumb
        : '';
    final videoPaintVisible = _longVideoTileVideoPaintVisible(widgetState);

    return LongVideoTileVisibility(
      videoId: video.id,
      child: Stack(
        children: [
          // Thumbnail always under a single BetterPlayer layer (opacity per §2).
          GestureDetector(
            onTap: () async {
              debugPrint('[LongVideos] tap videoId=${video.id} url=$videoUrl');
              _isRoutePushInProgress = true;
              _autoplayRequestId++;
              ref.read(longVideoAutoplayManagerProvider.notifier).disable();
              try {
                final vk = VideoWidgetKey(video.id, videoUrl);
                ref.read(longVideoWidgetProvider(vk).notifier).setEmbeddedOpen(true);
                final inline = ref.read(longVideoWidgetProvider(vk));
                debugPrint(
                  '[LongVideos] inline initialized=${inline.isInitialized} hasController=${inline.controller != null} pos=${inline.position.inMilliseconds}',
                );
                if (inline.isInitialized && inline.controller != null) {
                  final pos = inline.position;
                  await ref.read(longVideoWidgetProvider(vk).notifier).pause();
                  if (!mounted) return;
                  ref.read(longVideoEmbedResumeHintProvider.notifier).state =
                      LongVideoEmbedResumeHint(
                    videoUrl: videoUrl,
                    position: pos,
                  );
                  final detached = ref
                      .read(longVideoWidgetProvider(vk).notifier)
                      .detachControllerForRouteHandoff();
                  debugPrint('[LongVideos] detachedController=${detached != null}');
                  if (detached != null) {
                    ref.read(longVideoFeedReturnTargetProvider.notifier).state =
                        LongVideoFeedReturnTarget(
                      videoId: video.id,
                      videoUrl: videoUrl,
                    );
                    ref.read(longVideoEmbeddedHandoffProvider.notifier).state =
                        LongVideoInlineHandoff(
                      videoUrl: videoUrl,
                      controller: detached,
                      position: pos,
                      resumePlayback: true,
                    );
                  }
                } else {
                  ref.read(longVideoEmbedResumeHintProvider.notifier).state =
                      null;
                  ref.read(longVideoEmbeddedHandoffProvider.notifier).state =
                      null;
                  ref.read(longVideoFeedReturnTargetProvider.notifier).state =
                      null;
                }
                if (!mounted) return;
                debugPrint('[LongVideos] push embedded start');
                await Navigator.push<void>(
                  context,
                  PageRouteBuilder<void>(
                    transitionDuration: const Duration(milliseconds: 320),
                    reverseTransitionDuration: const Duration(milliseconds: 280),
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        LongVideoEmbeddedSessionHost(post: video),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                      final curved = CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      );
                      final offset = Tween<Offset>(
                        begin: const Offset(0, 1),
                        end: Offset.zero,
                      ).animate(curved);
                      return SlideTransition(position: offset, child: child);
                    },
                  ),
                );
                debugPrint('[LongVideos] push embedded returned');
              } finally {
                await Future<void>.delayed(const Duration(milliseconds: 350));
                _isRoutePushInProgress = false;
                if (mounted) {
                  final vk = VideoWidgetKey(video.id, videoUrl);
                  ref.read(longVideoWidgetProvider(vk).notifier).setEmbeddedOpen(false);
                  unawaited(ref.read(longVideoWidgetProvider(vk).notifier).warmUp());
                  ref.read(longVideoAutoplayManagerProvider.notifier).enable();
                  _autoplayArmedByUserScroll = true;
                  final dom =
                      ref.read(longVideoAutoplayManagerProvider).dominantVideoId;
                  if (dom != null) {
                    unawaited(_onAutoplayDominantChanged(null, dom));
                  }
                }
              }
            },
            behavior: HitTestBehavior.opaque,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                height: 220,
                decoration: BoxDecoration(
                  color: Colors.black,
                  border: Border.all(
                    color: ThemeHelper.getBorderColor(context)
                        .withValues(alpha: 0.35),
                  ),
                ),
                child: Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.hardEdge,
                children: [
                  RepaintBoundary(
                    child: FeedCachedPostImage(
                      imageUrl: networkThumb,
                      postId: video.id,
                      blurHash: video.blurHash,
                      fit: BoxFit.cover,
                      useShimmerWhileLoading: true,
                    ),
                  ),
                  if (isVideoInitialized && widgetState.controller != null)
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: ClipRect(
                          child: AnimatedOpacity(
                            opacity: videoPaintVisible ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 150),
                            child: IgnorePointer(
                              ignoring: !videoPaintVisible,
                              child: SafeBetterPlayerWrapper(
                                controller: widgetState.controller!,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              ),
            ),
          ),

          // Duration badge (hidden while playing — same idea as YouTube inline)
          if (video.videoDuration != null &&
              !(isVideoInitialized && widgetState.isPlaying))
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

          if (isDominant &&
              isVideoInitialized &&
              widgetState.isPlaying &&
              widgetState.isMuted)
            Positioned(
              left: 10,
              bottom: 14,
              child: Material(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    ref
                        .read(longVideoWidgetProvider(key).notifier)
                        .toggleMute();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.volume_off_rounded,
                          color: Colors.white.withValues(alpha: 0.95),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Tap to unmute',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.95),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          if (isDominant && isVideoInitialized)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SizedBox(
                height: 2,
                child: LinearProgressIndicator(
                  value: widgetState.duration.inMilliseconds > 0
                      ? (widgetState.position.inMilliseconds /
                              widgetState.duration.inMilliseconds)
                          .clamp(0.0, 1.0)
                      : 0.0,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
