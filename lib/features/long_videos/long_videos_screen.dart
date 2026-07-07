import 'package:better_player/better_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/long_video_logger.dart';
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
import '../../core/providers/post_views_provider.dart';
import '../../core/video_engine/global_video_engine_state.dart';
import '../../core/video_engine/video_engine_logger.dart';
import '../../core/video_engine/video_feed_warm_pool.dart';
import '../../core/video_engine/video_engine_provider.dart';
import '../feed/reel_edit_feature/audio/services/reel_audio_session_service.dart';
import '../profile/profile_screen.dart';
import 'long_video_embedded_session_host.dart';
import '../../core/providers/long_video_embedded_handoff_provider.dart';
import 'long_videos_search_screen.dart';
import 'providers/long_videos_provider.dart';
import 'providers/long_video_playback_provider.dart';
import 'providers/long_video_autoplay_manager.dart';
import 'providers/long_video_feed_search_query_provider.dart';
import 'dart:async';
import 'dart:ui';
import 'package:visibility_detector/visibility_detector.dart';

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
  Timer? _scrollThrottleTimer;
  bool _isRoutePushInProgress = false;
  int _autoplayRequestId = 0;
  bool _autoplayArmedByUserScroll = false;
  ProviderSubscription<int>? _mainTabSub;
  ProviderSubscription<String?>? _dominantSub;
  ProviderSubscription<LongVideoPlaybackState>? _playbackSub;
  ProviderSubscription<LongVideosState>? _videosSub;
  bool _ensuredInitialLoad = false;
  _LongVideoWarmSlot? _nextWarmSlot;
  @override
  void initState() {
    super.initState();
    ref.read(videoFeedWarmPoolProvider.notifier).register(
          'long_videos',
          () async {
            if (!mounted) return;
            await _disposeLongVideoWarmSlot();
          },
        );
    _mainTabSub = ref.listenManual<int>(mainTabIndexProvider, (prev, next) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (prev == kLongVideosTabIndex && next != kLongVideosTabIndex) {
          _autoplayArmedByUserScroll = false;
          ref.read(longVideoPlaybackProvider.notifier).clearCurrentlyPlaying();
          ref.read(longVideosProvider.notifier).cancelPendingNetworkLoad();
          ref.read(longVideoAutoplayManagerProvider.notifier).disable();
          unawaited(_disposeLongVideoWarmSlot());
        } else if (prev != null && prev != kLongVideosTabIndex && next == kLongVideosTabIndex) {
          _autoplayArmedByUserScroll = false;
          unawaited(ReelAudioSessionService.instance.restoreDefaultPlayback());
          ref.read(longVideoAutoplayManagerProvider.notifier).enable();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _armAutoplayIfLongVideosTabVisible();
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
    unawaited(
      ref
          .read(globalVideoEngineProvider.notifier)
          .pauseActiveUnless(exceptVideoId),
    );
  }

  @override
  void dispose() {
    _autoplayRequestId++;
    _isRoutePushInProgress = true;
    unawaited(_disposeLongVideoWarmSlot());
    _mainTabSub?.close();
    _dominantSub?.close();
    _playbackSub?.close();
    _videosSub?.close();
    _scrollController.dispose();
    _scrollThrottleTimer?.cancel();
    // Do not use ref in dispose() — Riverpod invalidates ref when the widget is torn down.
    // Playback state is cleared when providers are no longer watched (e.g. autoDispose).
    super.dispose();
  }

  /// Arms feed autoplay when the tab is visible (visibility detector picks tile).
  void _armAutoplayIfLongVideosTabVisible() {
    if (!mounted) return;
    if (ref.read(mainTabIndexProvider) != kLongVideosTabIndex) return;
    _autoplayArmedByUserScroll = true;
  }

  PostModel? _longVideoPostById(String id) {
    try {
      return ref.read(longVideosListProvider).firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  Duration _adaptiveAutoplayDwellDelay() {
    if (!_scrollController.hasClients) {
      return const Duration(milliseconds: 350);
    }
    final activelyScrolling =
        _scrollController.position.isScrollingNotifier.value;
    return activelyScrolling
        ? const Duration(milliseconds: 600)
        : const Duration(milliseconds: 350);
  }

  Future<void> _onAutoplayDominantChanged(String? prev, String? next) async {
    final requestId = ++_autoplayRequestId;
    if (!mounted) return;
    if (_isRoutePushInProgress) {
      LongVideoLogger.autoplay('dominant blocked; route in progress');
      return;
    }
    if (!_autoplayArmedByUserScroll) return;
    final mgr = ref.read(longVideoAutoplayManagerProvider);
    if (!mgr.isEnabled) return;
    final pb = ref.read(longVideoPlaybackProvider);
    if (!pb.isAutoplayEnabled) return;

    if (prev != next) {
      LongVideoLogger.autoplay('dominant changed prev=$prev next=$next');
    }

    if (prev != null && prev != next) {
      if (!mounted) return;
      if (ref.read(longVideoPlaybackProvider).currentlyPlayingVideoId == prev) {
        ref.read(longVideoPlaybackProvider.notifier).clearCurrentlyPlaying();
      }
    }

    if (next == null) return;
    final post = _longVideoPostById(next);
    final u = post?.videoUrl;
    if (u == null || u.isEmpty) return;

    await Future<void>.delayed(_adaptiveAutoplayDwellDelay());
    if (!mounted) return;
    if (requestId != _autoplayRequestId) return;
    if (_isRoutePushInProgress) return;
    if (ref.read(longVideoAutoplayManagerProvider).dominantVideoId != next) {
      return;
    }

    LongVideoLogger.autoplay('autoplay fire videoId=$next');
    if (!mounted) return;
    ref.read(longVideosProvider.notifier).prefetchNextAfter(next);
    ref.read(longVideoPlaybackProvider.notifier).setCurrentlyPlaying(next);
    ref
        .read(longVideoPlaybackProvider.notifier)
        .setControlsVisibility(next, false);

    final videos = ref.read(longVideosListProvider);
    final idx = videos.indexWhere((e) => e.id == next);
    if (idx >= 0) {
      unawaited(_kickEngineForLongVideoDominant(idx, videos));
    }
    unawaited(
      ref.read(postViewCountOverridesProvider.notifier).recordAndUpdate(
            next,
            fallback: (post?.displayViews ?? 0),
          ),
    );
  }

  void _onScroll() {
    if (!_autoplayArmedByUserScroll &&
        _scrollController.hasClients &&
        _scrollController.offset.abs() > 10) {
      _autoplayArmedByUserScroll = true;
    }
    _scrollThrottleTimer?.cancel();
    _scrollThrottleTimer =
        Timer(const Duration(milliseconds: 150), _handleScroll);
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8) {
      ref.read(longVideosProvider.notifier).loadMoreVideos();
    }
  }

  void _handleScroll() {
    if (!mounted) return;
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      ref.read(longVideosProvider.notifier).loadMoreVideos();
    }
  }

  String _longVideoFeedPlayUrl(PostModel video) {
    return video.videoResolutions['360p'] ??
        video.videoMasterUrl ??
        video.videoUrl ??
        '';
  }

  Future<void> _kickEngineForLongVideoDominant(
    int dominantIndex,
    List<PostModel> videos,
  ) async {
    if (dominantIndex < 0 || dominantIndex >= videos.length) return;
    final video = videos[dominantIndex];
    final url = _longVideoFeedPlayUrl(video);
    if (url.isEmpty) return;

    final notifier = ref.read(globalVideoEngineProvider.notifier);
    var st = ref.read(globalVideoEngineProvider);
    if (st.activeFeature != VideoEngineFeature.longVideos) {
      await notifier.activateFeature(VideoEngineFeature.longVideos);
      if (!mounted) return;
      st = ref.read(globalVideoEngineProvider);
    }

    if (_nextWarmSlot != null && _nextWarmSlot!.id == video.id) {
      final promoted = _nextWarmSlot!;
      _nextWarmSlot = null;
      final detached = notifier.detachActiveForEmbedded();
      if (detached != null) {
        _disposeLongVideoController(detached, label: 'lv-promote-replaced-active');
      }
      notifier.acceptReturnedController(
        id: promoted.id,
        url: promoted.url,
        controller: promoted.controller,
      );
      try {
        await promoted.controller.setVolume(0.0);
        await promoted.controller.play();
      } catch (_) {}
      VideoEngineLogger.engine('LONGVIDEOS_PROMOTE_WARM id=${video.id}');
      unawaited(_ensureLongVideoWarmNext(dominantIndex, videos));
      return;
    }

    if (st.activeSlot?.id == video.id) {
      try {
        final active = st.activeSlot!;
        final vpc = active.controller.videoPlayerController;
        if (vpc != null && !vpc.value.isPlaying) {
          await active.controller.play();
        }
        await notifier.setActiveVolume(0.0);
      } catch (_) {}
      VideoEngineLogger.engine('LONGVIDEOS_RESUME_ACTIVE id=${video.id}');
      unawaited(_ensureLongVideoWarmNext(dominantIndex, videos));
      return;
    }

    unawaited(
      notifier.play(
        id: video.id,
        url: url,
        feature: VideoEngineFeature.longVideos,
        muteInitially: true,
      ),
    );
    unawaited(_ensureLongVideoWarmNext(dominantIndex, videos));
  }

  void _disposeLongVideoController(
    BetterPlayerController controller, {
    String label = '',
  }) {
    VideoEngineLogger.engine('LONGVIDEOS_DISPOSE label=$label');
    try {
      controller.pause();
    } catch (_) {}
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        controller.dispose(forceDispose: true);
      } catch (_) {}
    });
  }

  Future<void> _disposeLongVideoWarmSlot() async {
    final warm = _nextWarmSlot;
    _nextWarmSlot = null;
    if (warm != null) {
      _disposeLongVideoController(warm.controller, label: 'lv-warm-next');
    }
  }

  Future<void> _ensureLongVideoWarmNext(
    int dominantIndex,
    List<PostModel> videos,
  ) async {
    if (!mounted) return;
    if (ref.read(mainTabIndexProvider) != kLongVideosTabIndex) return;

    // Drop any legacy warm ExoPlayer (budget is 0; HLS prefetch only).
    await _disposeLongVideoWarmSlot();

    if (dominantIndex < 0 || dominantIndex >= videos.length) return;
    ref
        .read(longVideosProvider.notifier)
        .prefetchNextAfter(videos[dominantIndex].id);
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
                              final viewOverrides = ref.watch(postViewCountOverridesProvider);
                              final baseViews = video.displayViews;
                              final viewCount = viewOverrides[video.id] ?? baseViews;
                              return LongVideoCard(
                                key: ValueKey('lv_card_${video.id}_$index'),
                                video: video,
                                formattedViews: _formatViews(viewCount),
                                timeAgo: _formatTimeAgo(video.createdAt),
                                onShowMoreMenu: () =>
                                    _showLongVideoMoreMenu(context, video),
                                onOpenEmbedded: (videoUrl) =>
                                    _openEmbeddedLongVideo(video, videoUrl),
                                onPlayerVisibilityChanged: (id, fraction) {
                                  if (!mounted) return;
                                  ref
                                      .read(longVideoAutoplayManagerProvider
                                          .notifier)
                                      .reportPlayerVisibility(id, fraction);
                                },
                                isValidRemoteUrl: _isValidRemoteUrl,
                                formatDuration: _formatDuration,
                              );
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
    final viewOverrides = ref.watch(postViewCountOverridesProvider);
    final views = viewOverrides[video.id] ?? video.displayViews;
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

  Future<void> _openEmbeddedLongVideo(PostModel video, String videoUrl) async {
    debugPrint('[LongVideos] tap videoId=${video.id} url=$videoUrl');
    unawaited(
      ref.read(postViewCountOverridesProvider.notifier).recordAndUpdate(
            video.id,
            fallback: video.displayViews,
          ),
    );
    _isRoutePushInProgress = true;
    _autoplayRequestId++;
    LongVideoLogger.handoff(
      'open embedded start videoId=${video.id} url=$videoUrl',
    );
    ref.read(longVideoAutoplayManagerProvider.notifier).disable();
    await ref.read(videoFeedWarmPoolProvider.notifier).releaseAllForEmbeddedPlayer();
    if (!mounted) return;
    try {
      final engineState = ref.read(globalVideoEngineProvider);
      final slot = engineState.activeSlot;

      var coldStartFallback = false;
      if (slot != null && slot.id == video.id) {
        final pos = slot.controller.videoPlayerController?.value.position ??
            Duration.zero;
        try {
          await slot.controller.pause();
        } catch (_) {}
        if (!mounted) return;
        ref.read(longVideoEmbedResumeHintProvider.notifier).state =
            LongVideoEmbedResumeHint(
          videoUrl: videoUrl,
          position: pos,
          forceStartFromZero: false,
        );
        final detached = ref
            .read(globalVideoEngineProvider.notifier)
            .detachActiveForEmbedded();

        LongVideoLogger.handoff(
          'inline engine handoff pos=${pos.inMilliseconds}',
        );
        debugPrint('[LongVideos] detachedController=${detached != null}');
        if (detached != null) {
          LongVideoLogger.handoff('handoff prepared videoId=${video.id}');
          ref.read(longVideoFeedReturnTargetProvider.notifier).state =
              LongVideoFeedReturnTarget(
            videoId: video.id,
            videoUrl: slot.url,
          );
          ref.read(longVideoEmbeddedHandoffProvider.notifier).state =
              LongVideoInlineHandoff(
            videoUrl: slot.url,
            controller: detached,
            position: pos,
            resumePlayback: true,
          );
        } else {
          coldStartFallback = true;
          LongVideoLogger.handoff(
            'handoff unavailable; falling back to cold start videoId=${video.id}',
          );
          ref.read(longVideoEmbedResumeHintProvider.notifier).state =
              LongVideoEmbedResumeHint(
            videoUrl: videoUrl,
            position: Duration.zero,
            forceStartFromZero: true,
          );
          ref.read(longVideoEmbeddedHandoffProvider.notifier).state = null;
          ref.read(longVideoFeedReturnTargetProvider.notifier).state = null;
        }
      } else {
        coldStartFallback = true;
        LongVideoLogger.handoff(
          'handoff unavailable; falling back to cold start videoId=${video.id}',
        );
        ref.read(longVideoEmbedResumeHintProvider.notifier).state =
            LongVideoEmbedResumeHint(
          videoUrl: videoUrl,
          position: Duration.zero,
          forceStartFromZero: true,
        );
        ref.read(longVideoEmbeddedHandoffProvider.notifier).state = null;
        ref.read(longVideoFeedReturnTargetProvider.notifier).state = null;
      }
      if (!mounted) return;
      if (coldStartFallback) {
        LongVideoLogger.handoff(
          'cold start fallback videoId=${video.id}',
        );
      }
      debugPrint('[LongVideos] push embedded start');
      await Navigator.push<void>(
        context,
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 320),
          reverseTransitionDuration: const Duration(milliseconds: 280),
          pageBuilder: (context, animation, secondaryAnimation) =>
              LongVideoEmbeddedSessionHost(post: video),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
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
        ref.read(longVideoAutoplayManagerProvider.notifier).enable();
        _autoplayArmedByUserScroll = true;
        final dom = ref.read(longVideoAutoplayManagerProvider).dominantVideoId;
        if (dom != null) {
          final vids = ref.read(longVideosListProvider);
          final i = vids.indexWhere((e) => e.id == dom);
          if (i >= 0) {
            unawaited(_kickEngineForLongVideoDominant(i, vids));
          }
          unawaited(_onAutoplayDominantChanged(null, dom));
        }
      }
    }
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

    final controller = ref.watch(
      globalVideoEngineProvider.select(
        (s) =>
            s.activeSlot?.id == video.id ? s.activeSlot?.controller : null,
      ),
    );
    final isDominant = ref.watch(
      longVideoAutoplayManagerProvider
          .select((s) => s.dominantVideoId == video.id),
    );

    final rawThumb = video.effectiveThumbnailUrl ??
        video.thumbnailUrl ??
        video.imageUrl ??
        '';
    final networkThumb = _isValidRemoteUrl(rawThumb) &&
            !isProtectedVideoCdnThumbnailUrl(rawThumb)
        ? rawThumb
        : '';

    final vpc = controller?.videoPlayerController;
    final hasPlayer = controller != null && vpc != null;

    return Stack(
      children: [
        GestureDetector(
          onTap: () {
            unawaited(_openEmbeddedLongVideo(video, videoUrl));
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
                  if (hasPlayer)
                    Positioned.fill(
                      child: ListenableBuilder(
                        listenable: vpc!,
                        builder: (context, _) {
                          final c = controller!;
                          final val = vpc.value;
                          final paint = c.isVideoInitialized() == true &&
                              _longVideoEngineFeedPaintVisible(val);
                          return RepaintBoundary(
                            child: ClipRect(
                              child: AnimatedOpacity(
                                opacity: paint ? 1.0 : 0.0,
                                duration: const Duration(milliseconds: 150),
                                child: IgnorePointer(
                                  ignoring: !paint,
                                  child: SafeBetterPlayerWrapper(
                                    controller: c,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        if (video.videoDuration != null && hasPlayer)
          Positioned(
            bottom: 8,
            right: 8,
            child: ListenableBuilder(
              listenable: vpc!,
              builder: (_, __) {
                if (vpc.value.isPlaying) return const SizedBox.shrink();
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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
                );
              },
            ),
          ),

        if (isDominant && hasPlayer && vpc != null)
          ListenableBuilder(
            listenable: vpc,
            builder: (context, _) {
              final val = vpc.value;
              if (!val.isPlaying || val.volume > 0.001) {
                return const SizedBox.shrink();
              }
              return Positioned(
                left: 10,
                bottom: 14,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      unawaited(
                        ref
                            .read(globalVideoEngineProvider.notifier)
                            .setActiveVolume(1.0),
                      );
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
              );
            },
          ),

        if (isDominant && hasPlayer)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ListenableBuilder(
              listenable: vpc!,
              builder: (context, _) {
                final val = vpc.value;
                final durMs = val.duration?.inMilliseconds ?? 0;
                final posMs = val.position.inMilliseconds;
                return SizedBox(
                  height: 2,
                  child: LinearProgressIndicator(
                    value: durMs > 0
                        ? (posMs / durMs).clamp(0.0, 1.0)
                        : 0.0,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

bool _longVideoEngineFeedPaintVisible(VideoPlayerValue v) {
  final nearStart = v.position.inMilliseconds < 300;
  if (v.isBuffering && nearStart) return false;
  if (v.isPlaying && !v.isBuffering) return true;
  if (v.isPlaying && v.isBuffering && !nearStart) return true;
  if (!v.isPlaying && v.position > Duration.zero) return true;
  return false;
}

class LongVideoCard extends ConsumerWidget {
  const LongVideoCard({
    super.key,
    required this.video,
    required this.formattedViews,
    required this.timeAgo,
    required this.onShowMoreMenu,
    required this.onOpenEmbedded,
    required this.onPlayerVisibilityChanged,
    required this.isValidRemoteUrl,
    required this.formatDuration,
  });

  final PostModel video;
  final String formattedViews;
  final String timeAgo;
  final VoidCallback onShowMoreMenu;
  final Future<void> Function(String videoUrl) onOpenEmbedded;
  final void Function(String videoId, double visibleFraction)
      onPlayerVisibilityChanged;
  final bool Function(String? value) isValidRemoteUrl;
  final String Function(Duration duration) formatDuration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final videoUrl = video.videoUrl?.trim();
    final hasVideo = videoUrl != null && videoUrl.isNotEmpty;
    final videos = ref.watch(longVideosListProvider);
    final videoIndex = videos.indexWhere((v) => v.id == video.id);
    final inList = videoIndex >= 0;
    final controller = ref.watch(
      globalVideoEngineProvider.select(
        (s) => (inList && s.activeSlot?.id == video.id)
            ? s.activeSlot?.controller
            : null,
      ),
    );
    final isDominant = ref.watch(
      longVideoAutoplayManagerProvider
          .select((s) => s.dominantVideoId == video.id),
    );

    final rawThumb =
        video.effectiveThumbnailUrl ?? video.thumbnailUrl ?? video.imageUrl ?? '';
    final networkThumb = isValidRemoteUrl(rawThumb) &&
            !isProtectedVideoCdnThumbnailUrl(rawThumb)
        ? rawThumb
        : '';

    return RepaintBoundary(
      child: Column(
        children: [
          isDark
              ? Container(
                  color: ThemeHelper.getBackgroundColor(context),
                  child: _buildCardContent(
                    context,
                    ref,
                    videoIndex,
                    controller,
                    isDominant,
                    networkThumb,
                    hasVideo,
                    videoUrl,
                  ),
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(0),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                      ),
                      child: _buildCardContent(
                        context,
                        ref,
                        videoIndex,
                        controller,
                        isDominant,
                        networkThumb,
                        hasVideo,
                        videoUrl,
                      ),
                    ),
                  ),
                ),
          Container(
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
                        color:
                            Theme.of(context).colorScheme.primary.withOpacity(0.1),
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
          ),
        ],
      ),
    );
  }

  Widget _buildCardContent(
    BuildContext context,
    WidgetRef ref,
    int videoIndex,
    BetterPlayerController? activeController,
    bool isDominant,
    String networkThumb,
    bool hasVideo,
    String? videoUrl,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
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
                  child: isValidRemoteUrl(video.author.avatarUrl)
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
                onTap: onShowMoreMenu,
                child: Icon(
                  CupertinoIcons.ellipsis,
                  color: ThemeHelper.getTextPrimary(context),
                  size: 20,
                ),
              ),
            ],
          ),
        ),
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
        _buildVideoPlayer(
          context,
          ref,
          videoIndex,
          activeController,
          isDominant,
          networkThumb,
          hasVideo,
          videoUrl,
        ),
      ],
    );
  }

  Widget _buildVideoPlayer(
    BuildContext context,
    WidgetRef ref,
    int videoIndex,
    BetterPlayerController? activeController,
    bool isDominant,
    String networkThumb,
    bool hasVideo,
    String? videoUrl,
  ) {
    if (!hasVideo || videoUrl == null) {
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
    final controller = activeController;
    final vpc = controller?.videoPlayerController;
    final showPlayer = controller != null &&
        videoIndex >= 0 &&
        controller.isVideoInitialized() == true &&
        vpc != null;

    return VisibilityDetector(
      key: ValueKey<String>('lv_player_vis_${video.id}'),
      onVisibilityChanged: (info) {
        onPlayerVisibilityChanged(video.id, info.visibleFraction);
      },
      child: Stack(
        children: [
          GestureDetector(
            onTap: () => onOpenEmbedded(videoUrl),
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
                  if (showPlayer)
                    Positioned.fill(
                      child: ListenableBuilder(
                        listenable: vpc!,
                        builder: (context, _) {
                          final c = controller!;
                          final val = vpc.value;
                          final paint = c.isVideoInitialized() == true &&
                              _longVideoEngineFeedPaintVisible(val);
                          return RepaintBoundary(
                            child: ClipRect(
                              child: AnimatedOpacity(
                                opacity: paint ? 1.0 : 0.0,
                                duration: const Duration(milliseconds: 150),
                                child: IgnorePointer(
                                  ignoring: !paint,
                                  child: SafeBetterPlayerWrapper(
                                    controller: c,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (video.videoDuration != null)
          Positioned(
            bottom: 8,
            right: 8,
            child: showPlayer
                ? ListenableBuilder(
                    listenable: vpc!,
                    builder: (_, __) {
                      if (vpc.value.isPlaying) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          formatDuration(video.videoDuration!),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  )
                : Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      formatDuration(video.videoDuration!),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
          ),
        if (isDominant && showPlayer && vpc != null)
          ListenableBuilder(
            listenable: vpc,
            builder: (context, _) {
              final val = vpc.value;
              if (!val.isPlaying || val.volume > 0.001) {
                return const SizedBox.shrink();
              }
              return Positioned(
                left: 10,
                bottom: 14,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      unawaited(
                        ref
                            .read(globalVideoEngineProvider.notifier)
                            .setActiveVolume(1.0),
                      );
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
              );
            },
          ),
        if (isDominant && showPlayer)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ListenableBuilder(
              listenable: vpc!,
              builder: (_, __) {
                final val = vpc.value;
                final durMs = val.duration?.inMilliseconds ?? 0;
                final posMs = val.position.inMilliseconds;
                return SizedBox(
                  height: 2,
                  child: LinearProgressIndicator(
                    value: durMs > 0
                        ? (posMs / durMs).clamp(0.0, 1.0)
                        : 0.0,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                );
              },
            ),
          ),
      ],
    ),
    );
  }
}

class _LongVideoWarmSlot {
  final String id;
  final String url;
  final BetterPlayerController controller;

  const _LongVideoWarmSlot({
    required this.id,
    required this.url,
    required this.controller,
  });
}
