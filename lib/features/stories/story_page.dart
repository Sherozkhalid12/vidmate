import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'stories_viewer_screen.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/media/app_media_cache.dart';
import '../../core/widgets/feed_image_precache.dart';
import '../../core/widgets/natural_aspect_image.dart';
import '../../core/perf/stories_perf_metrics.dart';
import '../../core/providers/stories_provider_riverpod.dart';
import '../../core/providers/auth_provider_riverpod.dart';
import '../../core/providers/network_status_provider.dart';
import '../../services/reels/reel_video_prefetch.dart';
import '../../services/stories/story_audio_preloader.dart';
import '../../core/providers/active_livestreams_provider_riverpod.dart';
import '../../core/providers/livestream_controller_riverpod.dart';
import '../../core/models/story_model.dart';
import '../../core/models/user_model.dart';
import '../../core/models/livestream_model.dart';
import '../feed/create_content_screen.dart';
import '../live/live_join_overlay_screen.dart';
import '../live/live_stream_studio_screen.dart';
import '../live/live_stream_watch_screen.dart';
import 'current_user_story_live_viewer_screen.dart';

/// Story Page - Grid layout like WhatsApp Status (data from API via Riverpod)
class StoryPage extends ConsumerStatefulWidget {
  final double bottomPadding;

  const StoryPage({super.key, required this.bottomPadding});

  @override
  ConsumerState<StoryPage> createState() => _StoryPageState();
}

class _StoryPageState extends ConsumerState<StoryPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final Stopwatch _trayStopwatch = Stopwatch()..start();
  bool _trayPaintLogged = false;
  String _lastTrayWarmSig = '';

  (Color, Color) _shimmerBaseHi(BuildContext context) {
    final base = Theme.of(context).brightness == Brightness.dark
        ? Colors.white10
        : Colors.black12;
    return (base, base.withValues(alpha: 0.35));
  }

  void _maybeLogTrayPaint() {
    if (_trayPaintLogged) return;
    _trayPaintLogged = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      StoriesPerfMetrics.logTrayPaintMs(_trayStopwatch.elapsedMilliseconds);
    });
  }

  void _maybePrecacheStoriesTray(StoriesState s) {
    if (s.users.isEmpty) return;
    final sig = s.users
        .map((u) {
          final st = s.userStoriesMap[u.id] ?? [];
          final ids = st.map((e) => e.id).join(',');
          return '${u.id}:$ids';
        })
        .join('|');
    if (sig == _lastTrayWarmSig) return;
    _lastTrayWarmSig = sig;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final u in s.users) {
        if (u.avatarUrl.isNotEmpty) {
          precacheFeedImageSafe(
            CachedNetworkImageProvider(
              u.avatarUrl,
              cacheManager: AppMediaCache.feedMedia,
            ),
            context,
          );
        }
        final stories = s.userStoriesMap[u.id] ?? [];
        for (final story in stories) {
          if (story.mediaUrl.isEmpty) continue;
          if (story.isVideo) {
            final thumb = story.thumbnailUrl?.trim() ?? '';
            if (thumb.isNotEmpty) {
              precacheFeedImageSafe(
                CachedNetworkImageProvider(
                  thumb,
                  cacheManager: AppMediaCache.feedMedia,
                ),
                context,
              );
            } else {
              unawaited(
                ReelVideoPrefetchService.instance
                    .prefetchIfAllowed(story.mediaUrl),
              );
            }
          } else {
            precacheFeedImageSafe(
              CachedNetworkImageProvider(
                story.mediaUrl,
                cacheManager: AppMediaCache.feedMedia,
              ),
              context,
            );
          }
        }
      }
      unawaited(StoryAudioPreloader.instance.prewarmTray(s.userStoriesMap));
    });
  }

  Widget _avatarImagePlaceholder(BuildContext context, {double iconSize = 28}) {
    final accent = ThemeHelper.getAccentColor(context);
    final surface = ThemeHelper.getSurfaceColor(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.45),
            surface,
          ],
        ),
      ),
      child: Center(child: _personIcon(context, size: iconSize)),
    );
  }

  /// Matches loaded Stories tab: hero bubble, optional “Live now” + card, two-column tray.
  Widget _buildStoriesLayoutShimmer() {
    final (base, hi) = _shimmerBaseHi(context);
    final surface = ThemeHelper.getSurfaceColor(context);
    final border = ThemeHelper.getBorderColor(context);

    Widget ringBubble(double outer, double labelW) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: outer,
            height: outer,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: surface,
              border: Border.all(color: border.withValues(alpha: 0.22)),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: labelW,
            height: 12,
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ],
      );
    }

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: hi,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          SizedBox(
            height: 132,
            child: Center(child: ringBubble(92, 108)),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (ctx, c) {
              final w = (c.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 14,
                children: List<Widget>.generate(
                  6,
                  (_) => SizedBox(
                    width: w,
                    child: Center(child: ringBubble(90, 80)),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  static const String _kStoriesEmptyTitle = 'No stories from your network';
  static const String _kLiveEmptySubtitle =
      'Live broadcasts from people you follow appear here as soon as they start streaming.';

  Widget _buildStoriesEmptyTextOnly() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Text(
        _kStoriesEmptyTitle,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: ThemeHelper.getTextSecondary(context),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Theme-aware empty / soft-error card (Stories tab + Live section).
  Widget _buildStoriesEmptyStateCard({
    required IconData icon,
    required String title,
    required String subtitle,
    bool isError = false,
  }) {
    final surface = ThemeHelper.getSurfaceColor(context);
    final bg = ThemeHelper.getBackgroundColor(context);
    final border = ThemeHelper.getBorderColor(context);
    final primary = ThemeHelper.getTextPrimary(context);
    final secondary = ThemeHelper.getTextSecondary(context);
    final accent = ThemeHelper.getAccentColor(context);
    final secondaryBg = ThemeHelper.getSecondaryBackgroundColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor =
        isError ? ThemeHelper.getTextMuted(context) : accent.withValues(alpha: 0.9);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: surface.withValues(alpha: isDark ? 0.5 : 0.78),
          border: Border.all(
            color: border.withValues(alpha: isError ? 0.42 : 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: bg.withValues(alpha: 0.4),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: secondaryBg.withValues(alpha: 0.95),
                  border: Border.all(
                    color: border.withValues(alpha: 0.28),
                  ),
                ),
                child: Icon(icon, size: 30, color: iconColor),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: primary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 3,
                decoration: BoxDecoration(
                  gradient: ThemeHelper.getAccentGradient(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: secondary,
                  fontSize: 14,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _hasFollowingStoryOrLiveTiles(
    UserModel? currentUser,
    List<UserModel> users,
    Map<String, List<StoryModel>> userStoriesMap,
    List<LivestreamModel> streams,
  ) {
    final myId = currentUser?.id ?? '';
    bool hasStories(UserModel u) =>
        userStoriesMap[u.id]?.isNotEmpty ?? false;
    bool isLive(UserModel u) =>
        streams.any((s) => _livestreamHostId(s) == u.id);
    if (myId.isNotEmpty) {
      return users.any(
        (u) => u.id != myId && (hasStories(u) || isLive(u)),
      );
    }
    return users.any((u) => hasStories(u) || isLive(u));
  }

  void _openStoryViewer(
    int userIndex,
    int storyIndex,
    List<UserModel> users,
    Map<String, List<StoryModel>> userStoriesMap,
  ) {
    final offline = ref.read(isOfflineProvider);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StoriesViewerScreen(
          initialUserIndex: userIndex,
          initialStoryIndex: storyIndex,
          users: users,
          userStoriesMap: userStoriesMap,
          offline: offline,
        ),
      ),
    );
  }

  void _openCurrentUserStoryViewer(
    UserModel currentUser,
    Map<String, List<StoryModel>> userStoriesMap,
  ) {
    final myStories = userStoriesMap[currentUser.id] ?? const <StoryModel>[];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CurrentUserStoriesViewerScreen(
          currentUser: currentUser,
          stories: myStories,
        ),
      ),
    );
  }

  String _yourStoryPreviewUrl(
    UserModel? currentUser,
    Map<String, List<StoryModel>> userStoriesMap,
  ) {
    if (currentUser == null) return '';
    final list = userStoriesMap[currentUser.id];
    return _storyTrayImageUrl(currentUser.avatarUrl, list ?? const []);
  }

  String _storyTrayImageUrl(String avatarUrl, List<StoryModel> stories) {
    if (stories.isNotEmpty) {
      final first = stories.first;
      if (first.isVideo) {
        final thumb = first.thumbnailUrl?.trim() ?? '';
        if (thumb.isNotEmpty) return thumb;
      }
      if (first.mediaUrl.isNotEmpty) return first.mediaUrl;
    }
    return avatarUrl;
  }

  Widget _personIcon(BuildContext context, {double size = 28}) {
    return Icon(
      Icons.person,
      size: size,
      color: ThemeHelper.getTextSecondary(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final storiesState = ref.watch(storiesProvider);
    ref.listen<StoriesState>(storiesProvider, (_, next) {
      _maybePrecacheStoriesTray(next);
    });
    _maybePrecacheStoriesTray(storiesState);
    _maybeLogTrayPaint();

    final users = storiesState.users;
    final userStoriesMap = storiesState.userStoriesMap;
    final isLoading = storiesState.isLoading;
    final error = storiesState.error;
    final offline = ref.watch(isOfflineProvider);
    final showTrayOfflineBanner =
        storiesState.trayOfflineBanner || (offline && users.isNotEmpty);
    final currentUser = ref.watch(authProvider).currentUser;
    final liveAsync = ref.watch(activeLivestreamsProvider);

    return SafeArea(
      bottom: false,
      child: Container(
        decoration: BoxDecoration(
          gradient: ThemeHelper.getBackgroundGradient(context),
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Text(
                    'Stories',
                    style: TextStyle(
                      color: ThemeHelper.getTextPrimary(context),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            if (showTrayOfflineBanner)
              Material(
                color: ThemeHelper.getSurfaceColor(context).withValues(alpha: 0.92),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                          storiesState.trayOfflineBanner
                              ? 'Couldn\'t refresh — showing saved stories'
                              : 'Showing saved stories — connect to refresh',
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
            // Stories layout: "Your story" at top center, then 2 columns below
            Expanded(
              child: isLoading && users.isEmpty
                  ? RefreshIndicator(
                      onRefresh: () async {
                        await ref.read(storiesProvider.notifier).refresh();
                        await ref
                            .read(activeLivestreamsProvider.notifier)
                            .refreshFromNetwork();
                      },
                      color: ThemeHelper.getAccentColor(context),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildStoriesLayoutShimmer(),
                            if (error != null)
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  error,
                                  style: TextStyle(
                                    color: ThemeHelper.getTextSecondary(context),
                                    fontSize: 13,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                          ],
                        ),
                      ),
                    )
                  : error != null && users.isEmpty
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
                                error,
                                style: TextStyle(
                                  color: ThemeHelper.getTextPrimary(context),
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () =>
                                    ref.read(storiesProvider.notifier).refresh(),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                  : RefreshIndicator(
                          onRefresh: () async {
                            await ref.read(storiesProvider.notifier).refresh();
                            await ref
                                .read(activeLivestreamsProvider.notifier)
                                .refreshFromNetwork();
                          },
                          color: ThemeHelper.getAccentColor(context),
                          child: SingleChildScrollView(
                            key: const PageStorageKey<String>('story_tab_scroll'),
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Builder(
                              builder: (ctx) {
                                return Column(
                                  children: [
                                    _buildStoriesHeroPairRow(
                                      currentUser,
                                      users,
                                      userStoriesMap,
                                      liveAsync,
                                    ),
                                    const SizedBox(height: 14),
                                    LayoutBuilder(
                                      builder: (ctx2, c) {
                                        return _buildStoriesTwoColumnGrid(
                                          currentUser,
                                          users,
                                          userStoriesMap,
                                          liveAsync,
                                          c.maxWidth,
                                        );
                                      },
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopRow(
    UserModel? currentUser,
    List<UserModel> users,
    Map<String, List<StoryModel>> userStoriesMap,
    AsyncValue<List<LivestreamModel>> liveAsync,
    {required LivestreamControllerState liveCtrlState}
  ) {
    return liveAsync.when(
      loading: () => _buildTopRowData(
        currentUser,
        users,
        userStoriesMap,
        const [],
        liveCtrlState: liveCtrlState,
      ),
      error: (_, __) => _buildTopRowData(
        currentUser,
        users,
        userStoriesMap,
        const [],
        liveCtrlState: liveCtrlState,
      ),
      data: (streams) => _buildTopRowData(
        currentUser,
        users,
        userStoriesMap,
        streams,
        liveCtrlState: liveCtrlState,
      ),
    );
  }

  Widget _buildTopRowData(
    UserModel? currentUser,
    List<UserModel> users,
    Map<String, List<StoryModel>> userStoriesMap,
    List<LivestreamModel> streams,
    {required LivestreamControllerState liveCtrlState}
  ) {
    final effectiveCurrentUser = currentUser ?? (users.isNotEmpty ? users.first : null);
    final myId = effectiveCurrentUser?.id ?? '';
    final myStories =
        myId.isNotEmpty ? (userStoriesMap[myId] ?? []) : const <StoryModel>[];
    if (effectiveCurrentUser == null) return const SizedBox.shrink();
    return SizedBox(
      height: 150,
      child: Align(
        alignment: Alignment.centerLeft,
        child: _buildCurrentUserStoriesLivesTile(
          currentUser: effectiveCurrentUser,
          stories: myStories,
          lives: const [],
        ),
      ),
    );
  }

  Widget _buildCurrentUserStoriesLivesTile({
    required UserModel currentUser,
    required List<StoryModel> stories,
    required List<LivestreamModel> lives,
  }) {
    final hasStories = stories.isNotEmpty;
    final hasLives = lives.isNotEmpty;
    final showPlus = true;

    final accent = ThemeHelper.getAccentColor(context);
    final bg = ThemeHelper.getBackgroundColor(context);

    final ringGradient = hasLives
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [const Color(0xFFEF4444), const Color(0xFFF97316), accent],
          )
        : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent,
              accent.withAlpha((0.6 * 255).round()),
            ],
          );

    final innerImage = hasStories && stories.first.mediaUrl.isNotEmpty
        ? CachedNetworkImageProvider(stories.first.mediaUrl)
        : (currentUser.avatarUrl.isNotEmpty ? CachedNetworkImageProvider(currentUser.avatarUrl) : null);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CurrentUserStoriesViewerScreen(
              currentUser: currentUser,
              stories: stories,
            ),
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: ringGradient,
              boxShadow: [
                BoxShadow(
                  color: accent.withAlpha((0.26 * 255).round()),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.all(3),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: bg,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipOval(
                    child: innerImage != null
                        ? Image(
                            image: innerImage,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: ThemeHelper.getSurfaceColor(context),
                              child: Icon(Icons.person, color: ThemeHelper.getTextSecondary(context)),
                            ),
                          )
                        : Container(
                            color: ThemeHelper.getSurfaceColor(context),
                            child: Icon(Icons.person, color: ThemeHelper.getTextSecondary(context)),
                          ),
                  ),
                  if (showPlus)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: InkWell(
                        borderRadius: const BorderRadius.all(Radius.circular(999)),
                        onTap: () async {
                          await _showCurrentUserAddSheet();
                        },
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: ThemeHelper.getAccentColor(context),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: ThemeHelper.getBackgroundColor(context),
                              width: 3,
                            ),
                          ),
                          child: Icon(
                            Icons.add,
                            color: ThemeHelper.getOnAccentColor(context),
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 120,
            child: Text(
              'Your story',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ThemeHelper.getTextPrimary(context),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // New horizontal stories row (Instagram-style)
  Widget _buildStoriesRow(
    UserModel? currentUser,
    List<UserModel> users,
    Map<String, List<StoryModel>> userStoriesMap,
    AsyncValue<List<LivestreamModel>> liveAsync,
  ) {
    final accent = ThemeHelper.getAccentColor(context);
    final ring = LinearGradient(
      colors: [accent, accent.withOpacity(0.6)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final streams = liveAsync.value ?? const <LivestreamModel>[];
    final trayUsers = currentUser == null
        ? users
        : users.where((u) => u.id != currentUser.id).toList();

    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 8, right: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            final cu = currentUser;
            if (cu == null) {
              return _storyBubble(
                name: 'Your story',
                imageUrl: '',
                showPlus: true,
                ring: ring,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        CreateContentScreen(initialType: ContentType.story),
                  ),
                ),
              );
            }
            return _storyBubble(
              name: 'Your story',
              imageUrl: _yourStoryPreviewUrl(cu, userStoriesMap),
              showPlus: true,
              ring: ring,
              onAvatarTap: () => _openCurrentUserStoryViewer(cu, userStoriesMap),
              onPlusTap: () async => _showCurrentUserAddSheet(),
            );
          }
          final user = trayUsers[index - 1];
          final stories = userStoriesMap[user.id] ?? const <StoryModel>[];
          if (stories.isEmpty) return const SizedBox.shrink();
          final isLive = streams.any((s) => s.hostId == user.id);
          final fullIndex = users.indexWhere((u) => u.id == user.id);
          return _storyBubble(
            name: user.username,
            imageUrl: _storyTrayImageUrl(user.avatarUrl, stories),
            ring: isLive
                ? const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFF97316)])
                : ring,
            showLiveBadge: isLive,
            onTap: () {
              if (fullIndex >= 0) {
                _openStoryViewer(fullIndex, 0, users, userStoriesMap);
              }
            },
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemCount: trayUsers.length + 1,
      ),
    );
  }

  Widget _storyBubble({
    required String name,
    required String imageUrl,
    required Gradient ring,
    VoidCallback? onTap,
    VoidCallback? onAvatarTap,
    VoidCallback? onPlusTap,
    bool showPlus = false,
    String? badge,
    double innerAvatarSize = 72,
    double labelMaxWidth = 80,
    bool useStoryLiveSplit = false,
    bool showLiveBadge = false,
  }) {
    final bg = ThemeHelper.getBackgroundColor(context);
    final VoidCallback? avatarTap =
        (showPlus && onAvatarTap != null) ? onAvatarTap : onTap;
    final iconSize = (innerAvatarSize * 0.5).clamp(24.0, 44.0);
    final state = ref.watch(storiesProvider);
    var localPath = state.storyLocalThumbnailPaths[imageUrl];
    if (localPath == null || localPath.isEmpty) {
      final mediaPath = state.storyLocalMediaPaths[imageUrl];
      if (mediaPath != null && mediaPath.isNotEmpty) {
        final lower = mediaPath.toLowerCase();
        final isVideoFile = lower.endsWith('.mp4') ||
            lower.endsWith('.mov') ||
            lower.endsWith('.mkv') ||
            lower.endsWith('.webm');
        if (!isVideoFile) localPath = mediaPath;
      }
    }
    final avatarCore = Container(
      width: innerAvatarSize,
      height: innerAvatarSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bg,
      ),
      clipBehavior: Clip.antiAlias,
      child: _buildTrayAvatarContent(
        context,
        imageUrl: imageUrl,
        localPath: localPath,
        iconSize: iconSize,
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              onTap: avatarTap,
              behavior: HitTestBehavior.opaque,
              child: useStoryLiveSplit
                  ? SizedBox(
                      width: innerAvatarSize + 6,
                      height: innerAvatarSize + 6,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: Size(innerAvatarSize + 6, innerAvatarSize + 6),
                            painter: _StoryLiveSplitRingPainter(
                              storyGradient: _storyStatusRing(),
                              liveGradient: _liveStatusRing(),
                              ringWidth: 3,
                            ),
                          ),
                          avatarCore,
                        ],
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: ring,
                      ),
                      child: avatarCore,
                    ),
            ),
              if (showLiveBadge)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.wifi_tethering,
                      color: Colors.white,
                      size: 13,
                    ),
                  ),
                )
              else if (badge != null && !useStoryLiveSplit)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              if (showPlus && onPlusTap != null)
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onPlusTap,
                      customBorder: const CircleBorder(),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: bg,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: ThemeHelper.getAccentColor(context),
                          ),
                          child: Icon(
                            Icons.add,
                            size: 16,
                            color: ThemeHelper.getOnAccentColor(context),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (showPlus && onPlusTap == null)
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: bg,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: ThemeHelper.getAccentColor(context),
                      ),
                      child: Icon(
                        Icons.add,
                        size: 16,
                        color: ThemeHelper.getOnAccentColor(context),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 6),
        SizedBox(
          width: labelMaxWidth,
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ThemeHelper.getTextPrimary(context),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  String _livestreamHostId(LivestreamModel s) {
    if (s.hostId.isNotEmpty) return s.hostId;
    final h = s.host;
    if (h != null && h.id.isNotEmpty) return h.id;
    return '';
  }

  Gradient _storyStatusRing() {
    final accent = ThemeHelper.getAccentColor(context);
    final surface = ThemeHelper.getSurfaceColor(context);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        accent,
        Color.lerp(accent, surface, 0.32)!,
        accent.withValues(alpha: 0.82),
      ],
      stops: const [0.0, 0.5, 1.0],
    );
  }

  Gradient _liveStatusRing() {
    final accent = ThemeHelper.getAccentColor(context);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        const Color(0xFFFF5F8A),
        const Color(0xFFFFB86C),
        accent.withValues(alpha: 0.92),
      ],
    );
  }

  LivestreamModel? _liveStreamForUser(
    UserModel user,
    List<LivestreamModel> streams,
  ) {
    for (final s in streams) {
      if (_livestreamHostId(s) == user.id) return s;
    }
    return null;
  }

  Widget _buildStoriesHeroPairRow(
    UserModel? currentUser,
    List<UserModel> users,
    Map<String, List<StoryModel>> userStoriesMap,
    AsyncValue<List<LivestreamModel>> liveAsync,
  ) {
    final effective = currentUser ?? (users.isNotEmpty ? users.first : null);
    if (effective == null) return const SizedBox.shrink();

    return liveAsync.when(
      loading: () {
        final (base, hi) = _shimmerBaseHi(context);
        final surface = ThemeHelper.getSurfaceColor(context);
        final border = ThemeHelper.getBorderColor(context);
        return SizedBox(
          height: 132,
          child: Shimmer.fromColors(
            baseColor: base,
            highlightColor: hi,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: surface,
                      border: Border.all(
                        color: border.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: 108,
                    height: 11,
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      error: (_, __) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: _heroPairRowBody(
          effective,
          userStoriesMap,
          const <LivestreamModel>[],
        ),
      ),
      data: (streams) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: _heroPairRowBody(effective, userStoriesMap, streams),
      ),
    );
  }

  Widget _heroPairRowBody(
    UserModel cu,
    Map<String, List<StoryModel>> userStoriesMap,
    List<LivestreamModel> streams,
  ) {
    final myLive = _liveStreamForUser(cu, streams);
    final myStories = userStoriesMap[cu.id] ?? const <StoryModel>[];
    final hasStories = myStories.isNotEmpty;
    final hasLive = myLive != null;
    final splitStoryAndLive = hasStories && hasLive;
    final ring = splitStoryAndLive
        ? _storyStatusRing()
        : (hasLive ? _liveStatusRing() : _storyStatusRing());

    return Center(
      child: _storyBubble(
        name: 'Your story',
        imageUrl: _yourStoryPreviewUrl(cu, userStoriesMap),
        showPlus: true,
        ring: ring,
        showLiveBadge: hasLive,
        innerAvatarSize: 84,
        labelMaxWidth: 112,
        useStoryLiveSplit: splitStoryAndLive,
        onAvatarTap: () {
          if (hasLive && !hasStories) {
            unawaited(_joinMyLiveAsViewer(myLive));
            return;
          }
          _openCurrentUserStoryViewer(cu, userStoriesMap);
        },
        onPlusTap: () async => _showCurrentUserAddSheet(),
      ),
    );
  }

  Future<void> _joinMyLiveAsViewer(LivestreamModel myLive) async {
    final ok = await ref
        .read(livestreamControllerProvider.notifier)
        .joinAsViewer(streamId: myLive.streamId);
    if (!mounted) return;
    if (ok) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => LiveStreamWatchScreen(streamId: myLive.streamId),
        ),
      );
    }
  }

  Future<void> _joinLiveAsViewer(LivestreamModel stream) async {
    final ok = await ref
        .read(livestreamControllerProvider.notifier)
        .joinAsViewer(streamId: stream.streamId);
    if (!mounted) return;
    if (ok) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => LiveStreamWatchScreen(streamId: stream.streamId),
        ),
      );
    }
  }

  Future<void> _showStoryOrLiveChoiceSheet({
    required String username,
    required VoidCallback onOpenStory,
    required VoidCallback onViewLive,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final bgColor = ThemeHelper.getBackgroundColor(ctx);
        final borderColor = ThemeHelper.getBorderColor(ctx);
        final textPrimary = ThemeHelper.getTextPrimary(ctx);
        final textSecondary = ThemeHelper.getTextSecondary(ctx);
        final accent = ThemeHelper.getAccentColor(ctx);

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: borderColor.withAlpha(isDark ? 120 : 80),
                width: 1,
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          username.isNotEmpty ? username : 'Choose',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: textSecondary),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  ListTile(
                    leading: Icon(Icons.auto_stories_outlined, color: accent),
                    title: Text(
                      'Open Story',
                      style: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      onOpenStory();
                    },
                  ),
                  Divider(color: ThemeHelper.getBorderColor(ctx)),
                  ListTile(
                    leading: const Icon(
                      Icons.wifi_tethering,
                      color: Color(0xFFEF4444),
                    ),
                    title: Text(
                      'View Live',
                      style: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      onViewLive();
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStoriesTwoColumnGrid(
    UserModel? currentUser,
    List<UserModel> users,
    Map<String, List<StoryModel>> userStoriesMap,
    AsyncValue<List<LivestreamModel>> liveAsync,
    double maxWidth,
  ) {
    final streams = liveAsync.value ?? const <LivestreamModel>[];
    final myId = currentUser?.id ?? '';

    final streamByHost = <String, LivestreamModel>{};
    for (final s in streams) {
      final hostId = _livestreamHostId(s);
      if (hostId.isEmpty) continue;
      streamByHost.putIfAbsent(hostId, () => s);
    }

    final entries = <_StoryGridEntry>[];
    final seenUserIds = <String>{};

    for (var i = 0; i < users.length; i++) {
      final u = users[i];
      if (myId.isNotEmpty && u.id == myId) continue;
      final hasStory = userStoriesMap[u.id]?.isNotEmpty ?? false;
      final live = streamByHost[u.id];
      if (!hasStory && live == null) continue;
      entries.add(
        _StoryGridEntry(
          userId: u.id,
          username: u.username,
          avatarUrl: u.avatarUrl,
          hasStory: hasStory,
          liveStream: live,
          fullUserIndex: i,
        ),
      );
      seenUserIds.add(u.id);
    }

    // Include live-only hosts that are not present in stories users list.
    for (final e in streamByHost.entries) {
      final hostId = e.key;
      if (seenUserIds.contains(hostId)) continue;
      if (myId.isNotEmpty && hostId == myId) continue;
      final s = e.value;
      final host = s.host;
      entries.add(
        _StoryGridEntry(
          userId: hostId,
          username: (host?.username.isNotEmpty ?? false)
              ? host!.username
              : (s.channelName.isNotEmpty ? s.channelName : 'Live'),
          avatarUrl: host?.profilePicture ?? '',
          hasStory: false,
          liveStream: s,
          fullUserIndex: -1,
        ),
      );
    }

    if (entries.isEmpty) {
      if (liveAsync.isLoading) {
        return const SizedBox(height: 10);
      }
      if (liveAsync.hasError) {
        return _buildStoriesEmptyStateCard(
          icon: Icons.cloud_off_outlined,
          title: 'Couldn\'t refresh',
          subtitle:
              'We couldn\'t load stories or live streams. Pull down to try again.',
          isError: true,
        );
      }
      if (liveAsync.hasValue && streams.isEmpty) {
        return _buildStoriesEmptyTextOnly();
      }
      if (liveAsync.hasValue && streams.isNotEmpty) {
        return const SizedBox.shrink();
      }
      return const SizedBox(height: 8);
    }

    final tileW = (maxWidth - 12) / 2;

    return Wrap(
      spacing: 12,
      runSpacing: 14,
      alignment: WrapAlignment.end,
      children: [
        for (final entry in entries)
          SizedBox(
            width: tileW,
            child: Center(
              child: Builder(
                builder: (context) {
                  final hasStories = entry.hasStory;
                  final liveStream = entry.liveStream;
                  final hasLive = liveStream != null;
                  final ring = hasStories
                      ? _storyStatusRing()
                      : (hasLive ? _liveStatusRing() : _storyStatusRing());
                  final stories =
                      userStoriesMap[entry.userId] ?? const <StoryModel>[];
                  final avatarUrl = _storyTrayImageUrl(
                    entry.avatarUrl.isNotEmpty
                        ? entry.avatarUrl
                        : (liveStream?.host?.profilePicture ?? ''),
                    stories,
                  );
                  return _storyBubble(
                    name: entry.username,
                    imageUrl: avatarUrl,
                    ring: ring,
                    useStoryLiveSplit: hasStories && hasLive,
                    showLiveBadge: hasLive,
                    onTap: () async {
                      final fullIndex = entry.fullUserIndex;
                      final openStory = () {
                        if (fullIndex < 0) return;
                        _openStoryViewer(fullIndex, 0, users, userStoriesMap);
                      };
                      final openLive = () {
                        if (liveStream == null) return;
                        unawaited(_joinLiveAsViewer(liveStream));
                      };

                      if (hasStories && hasLive && fullIndex >= 0 && liveStream != null) {
                        await _showStoryOrLiveChoiceSheet(
                          username: entry.username,
                          onOpenStory: openStory,
                          onViewLive: openLive,
                        );
                        return;
                      }

                      if (hasStories && fullIndex >= 0) {
                        openStory();
                        return;
                      }

                      if (hasLive && liveStream != null) {
                        openLive();
                      }
                    },
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLivesList(
    AsyncValue<List<LivestreamModel>> liveAsync, {
    bool suppressEmptyWhenUnified = false,
  }) {
    return liveAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) {
        if (suppressEmptyWhenUnified) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Text(
                'Live now',
                style: TextStyle(
                  color: ThemeHelper.getTextPrimary(context),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            _buildStoriesEmptyStateCard(
              icon: Icons.cloud_off_outlined,
              title: 'Couldn\'t refresh',
              subtitle:
                  'We couldn\'t load stories or live streams. Pull down to try again.',
              isError: true,
            ),
          ],
        );
      },
      data: (streams) {
        if (streams.isNotEmpty) {
          return _buildLiveStreamsColumn(streams);
        }
        if (suppressEmptyWhenUnified) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Text(
                'Live now',
                style: TextStyle(
                  color: ThemeHelper.getTextPrimary(context),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            _buildStoriesEmptyStateCard(
              icon: Icons.live_tv_rounded,
              title: 'No live streams right now',
              subtitle: _kLiveEmptySubtitle,
            ),
          ],
        );
      },
    );
  }

  Widget _buildLiveStreamsColumn(List<LivestreamModel> streams) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Live now',
                style: TextStyle(
                  color: ThemeHelper.getTextPrimary(context),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '${streams.length}',
                style: TextStyle(
                  color: ThemeHelper.getTextSecondary(context),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        ...streams.map(_liveCard),
      ],
    );
  }

  Widget _liveCard(LivestreamModel stream) {
    final host = stream.host;
    final thumb = stream.thumbnail ?? '';
    final image =
        thumb.isNotEmpty ? thumb : (host?.profilePicture ?? '');
    final rawTitle = stream.title ?? '';
    final title =
        rawTitle.isNotEmpty ? rawTitle : stream.channelName;
    final rawDesc = stream.description ?? '';
    final subtitle = rawDesc.isNotEmpty
        ? rawDesc
        : 'Hosted by ${host?.username ?? 'creator'}';
    return GestureDetector(
      onTap: () async {
        final ok = await ref.read(livestreamControllerProvider.notifier).joinAsViewer(
              streamId: stream.streamId,
            );
        if (!mounted) return;
        if (ok) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LiveStreamWatchScreen(streamId: stream.streamId),
            ),
          );
        } else {
          final err = ref.read(livestreamControllerProvider).errorMessage ??
              'Livestream is no longer active.';
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Stream unavailable'),
              content: Text(err),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        height: 210,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: ThemeHelper.getSurfaceColor(context),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (image.isNotEmpty)
              CachedNetworkImage(
                imageUrl: image,
                fit: BoxFit.cover,
              )
            else
              Container(
                color: Colors.black12,
                alignment: Alignment.center,
                child: Icon(Icons.person, size: 56, color: ThemeHelper.getTextSecondary(context)),
              ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.45),
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_tethering, size: 16, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      '${stream.viewerCount} watching',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 14,
              left: 14,
              right: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCurrentUserAddSheet() async {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final bgColor = ThemeHelper.getBackgroundColor(ctx);
        final borderColor = ThemeHelper.getBorderColor(ctx);
        final textPrimary = ThemeHelper.getTextPrimary(ctx);
        final textSecondary = ThemeHelper.getTextSecondary(ctx);
        final accent = ThemeHelper.getAccentColor(ctx);

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor.withAlpha(isDark ? 120 : 80), width: 1),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Add',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: textSecondary),
                          onPressed: () => Navigator.pop(ctx),
                        )
                      ],
                    ),
                  ),
                  ListTile(
                    leading: Icon(Icons.auto_stories_outlined, color: accent),
                    title: Text('Add Story', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700)),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CreateContentScreen(initialType: ContentType.story),
                        ),
                      );
                    },
                  ),
                  Divider(color: ThemeHelper.getBorderColor(ctx)),
                  ListTile(
                    leading: Icon(Icons.live_tv_rounded, color: accent),
                    title: Text('Go Live', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700)),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LiveStreamStudioScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStoryBubble(
    UserModel user,
    List<StoryModel> stories,
    List<UserModel> users,
    Map<String, List<StoryModel>> userStoriesMap,
  ) {
    final firstStory = stories.first;
    return GestureDetector(
      onTap: () {
        final userIndex = users.indexWhere((u) => u.id == user.id);
        if (userIndex >= 0) _openStoryViewer(userIndex, 0, users, userStoriesMap);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  ThemeHelper.getAccentColor(context),
                  ThemeHelper.getAccentColor(context).withAlpha((0.6 * 255).round()),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: ThemeHelper.getAccentColor(context).withAlpha((0.24 * 255).round()),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(3),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ThemeHelper.getBackgroundColor(context),
              ),
              child: _buildStoryCircleFill(
                mediaUrl: firstStory.mediaUrl,
                avatarUrl: user.avatarUrl,
                isVideo: firstStory.isVideo,
                thumbnailUrl: firstStory.thumbnailUrl,
                iconSize: 36,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 120,
            child: Text(
              user.displayName,
              style: TextStyle(
                color: ThemeHelper.getTextPrimary(context),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrayAvatarContent(
    BuildContext context, {
    required String imageUrl,
    required String? localPath,
    required double iconSize,
  }) {
    if (localPath != null && localPath.isNotEmpty) {
      return Image.file(
        File(localPath),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Center(
          child: _personIcon(context, size: iconSize),
        ),
      );
    }
    if (imageUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        cacheManager: AppMediaCache.feedMedia,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        placeholder: (_, __) =>
            _avatarImagePlaceholder(context, iconSize: iconSize),
        errorWidget: (_, __, ___) => Center(
          child: _personIcon(context, size: iconSize),
        ),
      );
    }
    return Center(child: _personIcon(context, size: iconSize));
  }

  Widget _buildStoryCircleFill({
    required String mediaUrl,
    required String avatarUrl,
    required bool isVideo,
    String? thumbnailUrl,
    double iconSize = 30,
  }) {
    final remoteThumb = thumbnailUrl?.trim() ?? '';
    final imageUrl = isVideo
        ? (remoteThumb.isNotEmpty
            ? remoteThumb
            : (mediaUrl.isNotEmpty ? mediaUrl : avatarUrl))
        : (mediaUrl.isNotEmpty ? mediaUrl : avatarUrl);
    final localPath = isVideo
        ? ref.watch(storiesProvider).storyLocalThumbnailPaths[mediaUrl]
        : (mediaUrl.isNotEmpty
            ? ref.watch(storiesProvider).storyLocalMediaPaths[mediaUrl]
            : null);
    if (isVideo && localPath == null && remoteThumb.isEmpty) {
      return CircleAvatar(
        backgroundColor: Colors.black,
        child: Icon(
          Icons.play_circle_filled,
          size: iconSize,
          color: Colors.white,
        ),
      );
    }
    if (localPath != null && localPath.isNotEmpty) {
      return CircleAvatar(
        backgroundColor: ThemeHelper.getSurfaceColor(context),
        backgroundImage: FileImage(File(localPath)),
        onBackgroundImageError: (_, __) {},
        child: null,
      );
    }
    return CircleAvatar(
      backgroundColor: ThemeHelper.getSurfaceColor(context),
      backgroundImage: imageUrl.isNotEmpty
          ? CachedNetworkImageProvider(
              imageUrl,
              cacheManager: AppMediaCache.feedMedia,
            )
          : null,
      onBackgroundImageError: (_, __) {},
      child: imageUrl.isEmpty ? _personIcon(context, size: iconSize) : null,
    );
  }

  Widget _buildYourStoryCard(
    UserModel? currentUser,
    List<UserModel> users,
    Map<String, List<StoryModel>> userStoriesMap,
  ) {
    final user = currentUser ??
        (users.isNotEmpty ? users.first : null);
    if (user == null) {
      return const SizedBox.shrink();
    }
    final currentUserStories = userStoriesMap[user.id] ?? [];
    final hasStories = currentUserStories.isNotEmpty;

    return GestureDetector(
      onTap: () {
        if (hasStories) {
          _showYourStoryOptions(user, users, userStoriesMap);
        } else {
          // No story - navigate to create content screen with stories tab
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreateContentScreen(
                initialType: ContentType.story,
              ),
            ),
          );
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Smaller circular story widget
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  ThemeHelper.getAccentColor(context),
                  ThemeHelper.getAccentColor(context).withOpacity(0.6),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: ThemeHelper.getAccentColor(context).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(3),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ThemeHelper.getBackgroundColor(context),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildStoryCircleFill(
                    mediaUrl: hasStories ? currentUserStories.first.mediaUrl : '',
                    avatarUrl: user.avatarUrl,
                    isVideo: hasStories && currentUserStories.first.isVideo,
                    thumbnailUrl:
                        hasStories ? currentUserStories.first.thumbnailUrl : null,
                    iconSize: 36,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: ThemeHelper.getAccentColor(context),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: ThemeHelper.getBackgroundColor(context),
                          width: 3,
                        ),
                      ),
                      child: Icon(
                        Icons.add,
                        color: ThemeHelper.getOnAccentColor(context),
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your story',
            style: TextStyle(
              color: ThemeHelper.getTextPrimary(context),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOtherStoriesAndLivesWrap(
    UserModel? currentUser,
    List<UserModel> users,
    Map<String, List<StoryModel>> userStoriesMap,
    AsyncValue<List<LivestreamModel>> liveAsync,
    {required LivestreamControllerState liveCtrlState}
  ) {
    return liveAsync.when(
      loading: () => _buildOtherStoriesAndLivesWrapData(
        currentUser,
        users,
        userStoriesMap,
        const [],
        liveCtrlState: liveCtrlState,
      ),
      error: (_, __) => _buildOtherStoriesAndLivesWrapData(
        currentUser,
        users,
        userStoriesMap,
        const [],
        liveCtrlState: liveCtrlState,
      ),
      data: (streams) => _buildOtherStoriesAndLivesWrapData(
        currentUser,
        users,
        userStoriesMap,
        streams,
        liveCtrlState: liveCtrlState,
      ),
    );
  }

  Widget _buildOtherStoriesAndLivesWrapData(
    UserModel? currentUser,
    List<UserModel> users,
    Map<String, List<StoryModel>> userStoriesMap,
    List<LivestreamModel> streams,
    {required LivestreamControllerState liveCtrlState}
  ) {
    final effectiveCurrentUser = currentUser ?? (users.isNotEmpty ? users.first : null);
    final myId = effectiveCurrentUser?.id ?? '';

    String streamHostId(LivestreamModel s) {
      if (s.hostId.isNotEmpty) return s.hostId;
      final h = s.host;
      if (h != null && h.id.isNotEmpty) return h.id;
      return '';
    }

    var mergedStreams = streams;
    if (myId.isNotEmpty &&
        liveCtrlState.state == LiveStreamState.live &&
        liveCtrlState.stream?.hostId == myId &&
        liveCtrlState.stream != null) {
      final ctrlStream = liveCtrlState.stream!;
      if (!mergedStreams.any((e) => e.streamId == ctrlStream.streamId)) {
        mergedStreams = [...mergedStreams, ctrlStream];
      }
    }

    final otherLives = myId.isNotEmpty
        ? mergedStreams.where((s) => streamHostId(s) != myId).toList()
        : mergedStreams;
    final otherStoryUsers = myId.isNotEmpty
        ? users
            .where((u) => u.id != myId && (userStoriesMap[u.id]?.isNotEmpty ?? false))
            .toList()
        : users.where((u) => (userStoriesMap[u.id]?.isNotEmpty ?? false)).toList();

    if (otherLives.isEmpty && otherStoryUsers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final s in otherLives)
          _LiveTile(
            stream: s,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => LiveJoinOverlayScreen(stream: s)),
              );
            },
          ),
        for (final user in otherStoryUsers)
          _buildStoryBubble(
            user,
            userStoriesMap[user.id] ?? const <StoryModel>[],
            otherStoryUsers,
            userStoriesMap,
          ),
      ],
    );
  }

  Widget _buildStoryCard(
    UserModel user,
    List<StoryModel> stories,
    int userIndex,
    List<UserModel> users,
    Map<String, List<StoryModel>> userStoriesMap,
  ) {
    final firstStory = stories.first;

    return GestureDetector(
      onTap: () => _openStoryViewer(userIndex, 0, users, userStoriesMap),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Smaller circular story widget
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  ThemeHelper.getAccentColor(context),
                  ThemeHelper.getAccentColor(context).withOpacity(0.6),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: ThemeHelper.getAccentColor(context).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(3),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ThemeHelper.getBackgroundColor(context),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildStoryCircleFill(
                    mediaUrl: firstStory.mediaUrl,
                    avatarUrl: user.avatarUrl,
                    isVideo: firstStory.isVideo,
                    thumbnailUrl: firstStory.thumbnailUrl,
                    iconSize: 30,
                  ),
                  // Story count badge (if multiple stories)
                  if (stories.length > 1)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              ThemeHelper.getAccentColor(context),
                              ThemeHelper.getAccentColor(context).withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: ThemeHelper.getAccentColor(context).withOpacity(0.4),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          '${stories.length}',
                          style: TextStyle(
                            color: ThemeHelper.getOnAccentColor(context),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // User name below circle
          Text(
            user.displayName,
            style: TextStyle(
              color: ThemeHelper.getTextPrimary(context),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showYourStoryOptions(
    UserModel currentUser,
    List<UserModel> users,
    Map<String, List<StoryModel>> userStoriesMap,
  ) {
    final userIndex = users.indexWhere((u) => u.id == currentUser.id);

    showModalBottomSheet(
      context: context,
      backgroundColor: ThemeHelper.getBackgroundColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                Icons.visibility,
                color: ThemeHelper.getAccentColor(context),
              ),
              title: Text(
                'View Story',
                style: TextStyle(
                  color: ThemeHelper.getTextPrimary(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                if (userIndex >= 0) {
                  _openStoryViewer(userIndex, 0, users, userStoriesMap);
                }
              },
            ),
            Divider(color: ThemeHelper.getBorderColor(context)),
            ListTile(
              leading: Icon(
                Icons.add_circle_outline,
                color: ThemeHelper.getAccentColor(context),
              ),
              title: Text(
                'Add Story',
                style: TextStyle(
                  color: ThemeHelper.getTextPrimary(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreateContentScreen(
                      initialType: ContentType.story,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Story + live: two semicircle halves (left = story, right = live) with ~1px gaps at top and bottom.
class _StoryLiveSplitRingPainter extends CustomPainter {
  _StoryLiveSplitRingPainter({
    required this.storyGradient,
    required this.liveGradient,
    required this.ringWidth,
  });

  final Gradient storyGradient;
  final Gradient liveGradient;
  final double ringWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final midR = size.width / 2 - ringWidth / 2;
    final bounds = Rect.fromCircle(center: c, radius: midR);
    final outerR = midR + ringWidth / 2;
    final gapRad = (1.0 / outerR).clamp(0.004, 0.15);

    final westStory = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth
      ..strokeCap = StrokeCap.butt
      ..shader = storyGradient.createShader(bounds);

    canvas.drawArc(
      bounds,
      math.pi / 2 + gapRad,
      math.pi - 2 * gapRad,
      false,
      westStory,
    );

    final eastLive = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth
      ..strokeCap = StrokeCap.butt
      ..shader = liveGradient.createShader(bounds);

    canvas.drawArc(
      bounds,
      -math.pi / 2 + gapRad,
      math.pi - 2 * gapRad,
      false,
      eastLive,
    );
  }

  @override
  bool shouldRepaint(covariant _StoryLiveSplitRingPainter oldDelegate) =>
      oldDelegate.ringWidth != ringWidth ||
      oldDelegate.storyGradient != storyGradient ||
      oldDelegate.liveGradient != liveGradient;
}

class _StoryGridEntry {
  const _StoryGridEntry({
    required this.userId,
    required this.username,
    required this.avatarUrl,
    required this.hasStory,
    required this.liveStream,
    required this.fullUserIndex,
  });

  final String userId;
  final String username;
  final String avatarUrl;
  final bool hasStory;
  final LivestreamModel? liveStream;
  final int fullUserIndex;
}

class _LiveTile extends StatelessWidget {
  final LivestreamModel stream;
  final VoidCallback onTap;
  const _LiveTile({required this.stream, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = ThemeHelper.getAccentColor(context);
    final bg = ThemeHelper.getBackgroundColor(context);
    final border = ThemeHelper.getBorderColor(context);
    final text = ThemeHelper.getTextPrimary(context);
    final muted = ThemeHelper.getTextSecondary(context);

    // Distinct ring for live streams (different feel from story ring).
    final ring = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        const Color(0xFFEF4444),
        const Color(0xFFF97316),
        accent,
      ],
    );

    final avatar = stream.host?.profilePicture ?? '';
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: ring,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEF4444).withAlpha((0.22 * 255).round()),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.all(3),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: bg,
              ),
              padding: const EdgeInsets.all(2),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipOval(
                    child: avatar.isNotEmpty
                        ? Image.network(
                            avatar,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: ThemeHelper.getSurfaceColor(context),
                              alignment: Alignment.center,
                              child: Icon(Icons.person, color: muted),
                            ),
                          )
                        : Container(
                            color: ThemeHelper.getSurfaceColor(context),
                            alignment: Alignment.center,
                            child: Icon(Icons.person, color: muted),
                          ),
                  ),
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha((0.55 * 255).round()),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withAlpha((0.14 * 255).round()),
                        ),
                      ),
                      child: const Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: ThemeHelper.getSurfaceColor(context).withAlpha((0.92 * 255).round()),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: border.withAlpha((0.7 * 255).round())),
                      ),
                      child: Text(
                        '👁 ${stream.viewerCount}',
                        style: TextStyle(
                          color: text,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 120,
            child: Text(
              stream.host?.username ?? 'Live',
              style: TextStyle(
                color: text,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
