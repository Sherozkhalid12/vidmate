import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/media/app_media_cache.dart';
import '../../core/models/post_model.dart';
import '../../core/perf/explore_perf_metrics.dart';
import '../../core/providers/network_status_provider.dart';
import '../../core/providers/reels_provider_riverpod.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/utils/video_thumbnail_helper.dart';
import '../../core/widgets/feed_cached_post_image.dart';
import '../../core/widgets/feed_image_precache.dart';
import '../long_videos/long_video_embedded_session_host.dart';
import '../long_videos/providers/long_videos_provider.dart';
import '../reels/reels_screen.dart';
import '../video/video_player_screen.dart';
import 'search_screen.dart';

/// Explore screen: staggered grid of reels from [reelsProvider] (Hive-backed SWR, Feature 4.2).
class ExploreScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBackToHome;
  final double? bottomPadding;

  const ExploreScreen({super.key, this.onBackToHome, this.bottomPadding});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  static Color _alpha(Color c, double opacity) =>
      c.withAlpha((opacity.clamp(0.0, 1.0) * 255).round());

  final Stopwatch _gridPaintSw = Stopwatch();
  bool _gridPaintLogged = false;
  String? _precachedForReelSignature;

  @override
  void initState() {
    super.initState();
    _gridPaintSw.start();
  }

  String _reelListSignature(List<PostModel> reels) {
    if (reels.isEmpty) return '';
    final b = StringBuffer();
    final n = reels.length > 16 ? 16 : reels.length;
    for (var i = 0; i < n; i++) {
      b.write(reels[i].id);
      b.write(',');
    }
    return b.toString();
  }

  void _maybeLogGridPaint(List<PostModel> reels) {
    if (_gridPaintLogged || reels.isEmpty) return;
    _gridPaintLogged = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !context.mounted) return;
      _gridPaintSw.stop();
      ExplorePerfMetrics.logExploreGridPaintMs(
          _gridPaintSw.elapsedMilliseconds);
    });
  }

  void _precacheVisibleThumbs(List<PostModel> reels) {
    final sig = _reelListSignature(reels);
    if (sig.isEmpty || sig == _precachedForReelSignature) return;
    _precachedForReelSignature = sig;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !context.mounted) return;
      final mq = MediaQuery.sizeOf(context);
      final dpr = MediaQuery.devicePixelRatioOf(context);
      final cellW = ((mq.width - 4) / 3).clamp(40.0, 500.0);
      final memW = (cellW * dpr).round().clamp(48, 420);
      final memH = ((memW * 16) / 9).round().clamp(64, 720);

      var n = 0;
      for (final r in reels) {
        if (n >= 12) break;
        final u = _thumbUrlForExplore(r);
        if (u.isEmpty) continue;
        precacheFeedImageSafe(
          ResizeImage(
            CachedNetworkImageProvider(
              u,
              cacheManager: AppMediaCache.feedMedia,
            ),
            width: memW,
            height: memH,
          ),
          context,
        );
        n++;
      }
    });
  }

  String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  (Color, Color) _shimmerColors() {
    final base = Theme.of(context).brightness == Brightness.dark
        ? Colors.white10
        : Colors.black12;
    return (base, base.withValues(alpha: 0.35));
  }

  Widget _buildExploreShimmerGrid() {
    final (base, hi) = _shimmerColors();
    return ListView.builder(
      key: const PageStorageKey<String>('explore_grid_shimmer'),
      padding: EdgeInsets.only(bottom: widget.bottomPadding ?? 0),
      itemCount: 8,
      itemBuilder: (context, index) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: List.generate(3, (_) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 2),
                      child: Shimmer.fromColors(
                        baseColor: base,
                        highlightColor: hi,
                        child: const AspectRatio(
                          aspectRatio: 9 / 16,
                          child: DecoratedBox(
                            decoration: BoxDecoration(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            Shimmer.fromColors(
              baseColor: base,
              highlightColor: hi,
              child: const AspectRatio(
                aspectRatio: 3.2,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 2),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final reels = ref.watch(reelsListProvider);
    final longVideos = ref.watch(longVideosListProvider);
    final loading = ref.watch(reelsLoadingProvider);
    final error = ref.watch(reelsErrorProvider);
    final offline = ref.watch(isOfflineProvider);

    _maybeLogGridPaint(reels);
    _precacheVisibleThumbs(reels);

    final showSkeleton = reels.isEmpty && loading;
    final showOfflineBanner = offline && reels.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: ThemeHelper.getBackgroundGradient(context),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  border: Border(
                    bottom: BorderSide(
                      color: _alpha(ThemeHelper.getBorderColor(context), 0.3),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        if (widget.onBackToHome != null) {
                          widget.onBackToHome!();
                        } else if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        }
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.back,
                            color: ThemeHelper.getAccentColor(context),
                            size: 28,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SearchScreen(
                                bottomPadding: widget.bottomPadding,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: ThemeHelper.getSurfaceColor(context),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: ThemeHelper.getBorderColor(context),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                CupertinoIcons.search,
                                color: ThemeHelper.getTextSecondary(context),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Search',
                                style: TextStyle(
                                  color: ThemeHelper.getTextSecondary(context),
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (showOfflineBanner)
                Material(
                  color: ThemeHelper.getSurfaceColor(context).withValues(
                    alpha: 0.92,
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(
                      children: [
                        Icon(
                          Icons.wifi_off_rounded,
                          size: 18,
                          color: ThemeHelper.getTextSecondary(context),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Showing saved reels — connect to refresh',
                            style: TextStyle(
                              fontSize: 12,
                              color: ThemeHelper.getTextSecondary(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: showSkeleton
                    ? _buildExploreShimmerGrid()
                    : error != null && reels.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.video_library_outlined,
                                    size: 48,
                                    color: ThemeHelper.getTextMuted(context),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    offline
                                        ? 'Reels unavailable offline. Connect to explore.'
                                        : error,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: ThemeHelper.getTextMuted(context),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : reels.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    'No reels to explore yet.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: ThemeHelper.getTextMuted(context),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              )
                            : RefreshIndicator(
                                color: ThemeHelper.getAccentColor(context),
                                onRefresh: () =>
                                    ref.read(reelsProvider.notifier).refresh(),
                                child: _buildExploreGrid(reels, longVideos),
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExploreGrid(List<PostModel> reels, List<PostModel> longVideos) {
    final rowCount = (reels.length / 3).ceil();
    final hasLongRows = longVideos.isNotEmpty;
    final itemCount = hasLongRows ? rowCount * 2 : rowCount;
    final cellHeight = ((MediaQuery.sizeOf(context).width - 4) / 3) * (16 / 9);

    return Padding(
      padding: EdgeInsets.only(
        bottom: (widget.bottomPadding ?? 0),
      ),
      child: ListView.builder(
        key: const PageStorageKey<String>('explore_reels_mixed_list'),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (hasLongRows && index.isOdd) {
            final rowIndex = index ~/ 2;
            final longVideo = longVideos[rowIndex % longVideos.length];
            return _buildExploreLongVideoStrip(longVideo, cellHeight);
          }
          final rowIndex = hasLongRows ? index ~/ 2 : index;
          final start = rowIndex * 3;
          final rowReels = reels.skip(start).take(3).toList();
          return _buildExploreReelRow(rowReels);
        },
      ),
    );
  }

  Widget _buildExploreReelRow(List<PostModel> rowReels) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: List.generate(3, (index) {
          if (index >= rowReels.length) {
            return const Expanded(child: SizedBox.shrink());
          }
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: index == 2 ? 0 : 2),
              child: _buildExploreItem(rowReels[index]),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildExploreLongVideoStrip(PostModel video, double height) {
    final thumb = _thumbUrlForExplore(video);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: GestureDetector(
        onTap: () {
          if (video.videoUrl == null || video.videoUrl!.isEmpty) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => video.postType == 'longVideo'
                  ? LongVideoEmbeddedSessionHost(post: video)
                  : VideoPlayerScreen(
                      videoUrl: video.videoUrl!,
                      title: video.caption,
                      author: video.author,
                      post: video,
                    ),
            ),
          );
        },
        child: SizedBox(
          width: double.infinity,
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              thumb.isEmpty
                  ? ColoredBox(
                      color: ThemeHelper.getSurfaceColor(context),
                      child: Icon(
                        Icons.video_library,
                        color: ThemeHelper.getTextSecondary(context),
                      ),
                    )
                  : FeedCachedPostImage(
                      imageUrl: thumb,
                      postId: video.id,
                      blurHash: video.blurHash,
                      fit: BoxFit.cover,
                      useShimmerWhileLoading: true,
                    ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        _alpha(Colors.black, 0.05),
                        _alpha(Colors.black, 0.55),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Text(
                  video.caption.isEmpty
                      ? video.author.displayName
                      : video.caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _alpha(Colors.white, 0.95),
                    fontWeight: FontWeight.w700,
                    shadows: [
                      Shadow(
                        color: _alpha(Colors.black, 0.7),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExploreItem(PostModel reel) {
    final likes = reel.likes;
    const views = 0;

    return RepaintBoundary(
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReelsScreen(initialPostId: reel.id),
            ),
          );
        },
        child: AspectRatio(
          aspectRatio: 9 / 16,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: FeedCachedPostImage(
                  imageUrl: _thumbUrlForExplore(reel),
                  postId: reel.id,
                  blurHash: reel.blurHash,
                  fit: BoxFit.cover,
                  useShimmerWhileLoading: true,
                ),
              ),
              Positioned.fill(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          _alpha(Colors.black, 0.0),
                          _alpha(Colors.black, 0.0),
                          _alpha(Colors.black, 0.35),
                          _alpha(Colors.black, 0.75),
                        ],
                        stops: const [0.0, 0.45, 0.70, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Row(
                  children: [
                    _metricInline(
                      icon: Icons.favorite_rounded,
                      value: _formatCount(likes),
                    ),
                    const SizedBox(width: 12),
                    _metricInline(
                      icon: Icons.remove_red_eye_rounded,
                      value: _formatCount(views),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _thumbUrlForExplore(PostModel reel) {
    final u = reel.effectiveThumbnailUrl ?? reel.thumbnailUrl ?? '';
    if (u.isEmpty) return '';
    if (!isProtectedVideoCdnThumbnailUrl(u)) return u;
    // MP4 reels often only have a /posts/videos/.../thumbnail.jpg URL (403 without cookies).
    // Stripping it leaves an empty URL → shimmer forever. Prefer HLS-derived thumb when possible.
    final v = reel.videoUrl ?? '';
    final gen = VideoThumbnailHelper.thumbnailFromVideoUrl(v);
    if (gen != null &&
        gen.isNotEmpty &&
        !isProtectedVideoCdnThumbnailUrl(gen)) {
      return gen;
    }
    return u;
  }

  Widget _metricInline({required IconData icon, required String value}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: _alpha(Colors.white, 0.92)),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            color: _alpha(Colors.white, 0.92),
            fontSize: 12,
            fontWeight: FontWeight.w800,
            shadows: [
              Shadow(
                color: _alpha(Colors.black, 0.55),
                blurRadius: 10,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
