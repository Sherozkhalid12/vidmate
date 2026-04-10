import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:better_player/better_player.dart';
import 'package:shimmer/shimmer.dart';
import 'package:blurhash_dart/blurhash_dart.dart' as bh;
import 'package:image/image.dart' as img;
import '../../core/widgets/comments_bottom_sheet.dart';
import '../../core/widgets/share_bottom_sheet.dart';
import '../../core/widgets/safe_better_player.dart';
import '../../core/providers/auth_provider_riverpod.dart';
import '../../core/providers/follow_provider_riverpod.dart';
import '../../core/providers/posts_provider_riverpod.dart';
import '../../core/providers/main_tab_index_provider.dart';
import '../../core/media/app_media_cache.dart';
import '../../core/perf/reels_perf_metrics.dart';
import '../../services/posts/posts_service.dart';
import '../../core/models/post_model.dart';
import '../../core/providers/reels_provider_riverpod.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/api/dio_client.dart';
import '../../core/utils/create_content_visibility.dart';
import '../../core/utils/share_link_helper.dart';
import 'audio_detail_screen.dart';

/// Reels screen with full-screen vertical swipe videos.
///
/// Playback is driven by [_currentIndex], [_playSession] (invalidates stale async work), and a
/// small index→[BetterPlayerController] pool with eviction (see [_poolRadius]).
/// When [prependedReel] is set (from home feed), this reel is shown first, then the rest from API.
/// When [initialPostId] is set, finds that reel in the list and opens at it. Shows back button when opened as a route.
class ReelsScreen extends ConsumerStatefulWidget {
  const ReelsScreen({super.key, this.initialPostId, this.prependedReel});

  final String? initialPostId;
  /// When set, this reel is shown first (tapped video from home), then reels from API. Takes precedence over initialPostId.
  final PostModel? prependedReel;

  @override
  ConsumerState<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends ConsumerState<ReelsScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  final Map<int, BetterPlayerController> _betterControllers = {};
  final Map<String, Uint8List?> _localVideoThumbs = {};
  final Map<String, bool> _savedReels = {};
  bool _hasAppliedInitialPostId = false;
  bool _firstReelMetricLogged = false;
  /// Bumps on each page switch / init so stale async [setupDataSource] cannot attach a second player.
  int _playSession = 0;

  /// Coalesces rapid vertical swipes: only the last [onPageChanged] runs activation (timer reset).
  Timer? _pageSettleTimer;
  static const Duration _pageSettleDelay = Duration(milliseconds: 16);

  /// How many reels to keep on each side of the current page (±[_poolRadius]).
  /// 2 → five controllers max; fewer dispose/recreate cycles when scrolling back through reels.
  static const int _poolRadius = 2;

  /// True while a post-frame bootstrap callback is queued (not necessarily finished).
  bool _bootstrapPostFrameScheduled = false;

  /// Second [addPostFrameCallback] must await this so two [setupDataSource] runs never race.
  Future<void>? _bootstrapInFlightFuture;

  final Map<String, void Function(BetterPlayerEvent)> _reelEventListeners = {};

  static const BetterPlayerBufferingConfiguration _bufferingActive = BetterPlayerBufferingConfiguration(
    minBufferMs: 2000,
    maxBufferMs: 10000,
    bufferForPlaybackMs: 500,
    bufferForPlaybackAfterRebufferMs: 1000,
  );

  static const BetterPlayerBufferingConfiguration _bufferingPrewarm = BetterPlayerBufferingConfiguration(
    minBufferMs: 4000,
    maxBufferMs: 8000,
    bufferForPlaybackMs: 2000,
    bufferForPlaybackAfterRebufferMs: 1000,
  );

  /// HLS/DASH must **not** use ExoPlayer [SimpleCache] here: multiple loaders + one global
  /// cache lock caused 700ms+ contention and AAC/Video codec failures on MediaTek (see logcat).
  static BetterPlayerCacheConfiguration? _reelNetworkCache(String url) {
    final u = url.toLowerCase();
    if (u.contains('.m3u8') || u.contains('.mpd') || u.contains('/master') || u.contains('playlist')) {
      return null;
    }
    return BetterPlayerCacheConfiguration(
      useCache: true,
      maxCacheSize: 256 * 1024 * 1024,
      maxCacheFileSize: 80 * 1024 * 1024,
      preCacheSize: 8 * 1024 * 1024,
      key: url,
    );
  }

  static BetterPlayerConfiguration _reelBetterConfig() {
    return BetterPlayerConfiguration(
      // Placeholder until [BetterPlayerEventType.initialized]; then we set the real ratio from the video.
      aspectRatio: 9 / 16,
      fit: BoxFit.contain,
      looping: true,
      autoPlay: false,
      handleLifecycle: false,
      expandToFill: true,
      controlsConfiguration: BetterPlayerControlsConfiguration(
        showControls: false,
        enableProgressBar: false,
        enableProgressText: false,
        enableFullscreen: false,
        enableMute: false,
        enablePlayPause: false,
        enableSkips: false,
        enablePlaybackSpeed: false,
        enableSubtitles: false,
        enableOverflowMenu: false,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    createContentVisibleNotifier.addListener(_onCreateContentVisibilityChanged);
    ReelsPerfMetrics.instance.onScreenMount();
  }

  List<PostModel> _effectiveReelsList() {
    final reelsFromProvider = ref.read(reelsListProvider);
    final prependedReel = widget.prependedReel;
    if (prependedReel != null) {
      return [prependedReel, ...reelsFromProvider.where((r) => r.id != prependedReel.id)];
    }
    return reelsFromProvider;
  }

  void _onCreateContentVisibilityChanged() {
    if (createContentVisibleNotifier.value) {
      _cancelPendingPlayerAttach();
      unawaited(_releaseAllVideoResources());
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _pageSettleTimer?.cancel();
    _bootstrapPostFrameScheduled = false;
    createContentVisibleNotifier.removeListener(_onCreateContentVisibilityChanged);
    _pageController.dispose();
    unawaited(_releaseAllVideoResources());
    super.dispose();
  }

  void _cancelPendingPlayerAttach() {
    _pageSettleTimer?.cancel();
    _pageSettleTimer = null;
  }

  Future<void> _safeSetVolume(BetterPlayerController c, double value) async {
    try {
      await c.setVolume(value);
    } catch (_) {}
  }

  Future<void> _safePause(BetterPlayerController c) async {
    try {
      await c.pause();
    } catch (_) {}
  }

  Future<void> _safePlay(BetterPlayerController c) async {
    try {
      await c.play();
    } catch (_) {}
  }

  Future<void> _safeSeekZero(BetterPlayerController c) async {
    try {
      await c.seekTo(Duration.zero);
    } catch (_) {}
  }

  /// Fast path: cut audio before heavy teardown (rapid swipes).
  Future<void> _muteAndPauseAllPlayers() async {
    final snapshot = _betterControllers.values.toList(growable: false);
    for (final c in snapshot) {
      await _safeSetVolume(c, 0);
      await _safePause(c);
    }
  }

  /// Dispose full pool (tab away, route leave, widget dispose).
  Future<void> _releaseAllVideoResources() async {
    final entries = _betterControllers.entries.toList();
    _betterControllers.clear();
    final reels = _effectiveReelsList();
    for (final e in entries) {
      final c = e.value;
      final idx = e.key;
      String? url;
      if (idx >= 0 && idx < reels.length) {
        url = reels[idx].videoUrl;
      }
      if (url != null && url.isNotEmpty) {
        final l = _reelEventListeners.remove(url);
        if (l != null) {
          try {
            c.removeEventsListener(l);
          } catch (_) {}
        }
      }
      await _safeSetVolume(c, 0);
      await _safePause(c);
      try {
        c.dispose(forceDispose: true);
      } catch (_) {}
    }
    _reelEventListeners.clear();
  }

  void _evictDistantControllers(int center) {
    for (final idx in _betterControllers.keys.toList()) {
      if ((idx - center).abs() > _poolRadius) {
        unawaited(_disposeBetterAt(idx));
      }
    }
  }

  Future<void> _disposeBetterAt(int index) async {
    final c = _betterControllers.remove(index);
    if (c != null) {
      final reels = _effectiveReelsList();
      String? url;
      if (index >= 0 && index < reels.length) {
        url = reels[index].videoUrl;
      }
      if (url != null && url.isNotEmpty) {
        final l = _reelEventListeners.remove(url);
        if (l != null) {
          try {
            c.removeEventsListener(l);
          } catch (_) {}
        }
      }
      await _safeSetVolume(c, 0);
      await _safePause(c);
      try {
        c.dispose(forceDispose: true);
      } catch (_) {}
    }
  }

  void _bindReelPlayerEvents(
    BetterPlayerController controller,
    String url,
    int index,
    int session,
  ) {
    final existing = _reelEventListeners.remove(url);
    if (existing != null) {
      try {
        controller.removeEventsListener(existing);
      } catch (_) {}
    }
    void listener(BetterPlayerEvent ev) {
      if (session != _playSession) return;
      if (ev.betterPlayerEventType == BetterPlayerEventType.bufferingStart) {
        ReelsPerfMetrics.instance.recordRebuffer();
      }
      if (ev.betterPlayerEventType == BetterPlayerEventType.initialized) {
        _syncReelVideoAspectRatio(controller);
        // Playback is driven by [_ensureBetterPlayer] / [_resumeController] to avoid double [play]
        // racing [setupDataSource] completion (first-reel stutter).
        if (!_firstReelMetricLogged && index == _currentIndex && session == _playSession) {
          _firstReelMetricLogged = true;
          ReelsPerfMetrics.instance.onFirstReelVisible();
        }
        if (mounted && session == _playSession) setState(() {});
      }
      if (ev.betterPlayerEventType == BetterPlayerEventType.exception) {
        if (mounted && _currentIndex == index && session == _playSession) {
          _disposeBetterAt(index);
          setState(() {});
        }
      }
    }

    _reelEventListeners[url] = listener;
    controller.addEventsListener(listener);
  }

  bool _betterReady(BetterPlayerController? c) {
    if (c == null) return false;
    try {
      return c.isVideoInitialized() == true;
    } catch (_) {
      return false;
    }
  }

  void _syncReelVideoAspectRatio(BetterPlayerController controller) {
    try {
      final vpc = controller.videoPlayerController;
      if (vpc == null || !vpc.value.initialized) return;
      final s = vpc.value.size;
      if (s == null || s.width <= 0 || s.height <= 0) return;
      controller.setOverriddenAspectRatio(s.width / s.height);
      controller.setOverriddenFit(BoxFit.contain);
    } catch (_) {}
  }

  /// Serialize bootstraps so two post-frame callbacks cannot overlap [setupDataSource] (stutter).
  Future<void> _bootstrapPlayerImmediate(String debugTag) async {
    final existing = _bootstrapInFlightFuture;
    if (existing != null) {
      await existing;
      return;
    }
    final done = Completer<void>();
    _bootstrapInFlightFuture = done.future;
    try {
      await _bootstrapPlayerImmediateBody(debugTag);
    } finally {
      if (!done.isCompleted) done.complete();
      _bootstrapInFlightFuture = null;
    }
  }

  Future<void> _bootstrapPlayerImmediateBody(String debugTag) async {
    if (kDebugMode) {
      debugPrint('[Reels] bootstrap ($debugTag) index=$_currentIndex');
    }
    final reels = _effectiveReelsList();
    if (reels.isEmpty) return;
    if (_currentIndex < 0 || _currentIndex >= reels.length) return;

    _cancelPendingPlayerAttach();
    _playSession++;
    final session = _playSession;

    if (_betterControllers.isNotEmpty) {
      await _muteAndPauseAllPlayers();
      await _releaseAllVideoResources();
    }
    if (!mounted || session != _playSession) return;
    final listNow = _effectiveReelsList();
    if (_currentIndex < 0 || _currentIndex >= listNow.length) return;
    await _activateIndex(_currentIndex, listNow, session);
    if (!mounted || session != _playSession) return;
    _scheduleDeferredPrewarm(_currentIndex, listNow, session);
  }

  void _scheduleBootstrap() {
    if (_bootstrapPostFrameScheduled) return;
    _bootstrapPostFrameScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (!mounted) return;
        await _bootstrapPlayerImmediate('postFrame');
      } finally {
        _bootstrapPostFrameScheduled = false;
      }
    });
  }

  /// Long delay after cold bootstrap so the first [setupDataSource] + decode is not starved.
  static const Duration _deferredPrewarmDelayCold = Duration(milliseconds: 450);
  /// Short delay after a swipe — user may scroll again; pool already keeps nearby indices.
  static const Duration _deferredPrewarmDelaySwipe = Duration(milliseconds: 140);

  void _scheduleDeferredPrewarm(
    int center,
    List<PostModel> reels,
    int session, {
    Duration delay = _deferredPrewarmDelayCold,
  }) {
    Future<void>.delayed(delay, () {
      if (!mounted || session != _playSession || _currentIndex != center) return;
      final list = _effectiveReelsList();
      if (center < 0 || center >= list.length) return;
      unawaited(_prewarmNeighbors(center, list, session));
    });
  }

  void _initVideosForList(List<PostModel> reels) {
    if (reels.isEmpty) return;
    _scheduleBootstrap();
  }

  Map<String, String>? _reelThumbHeaders() {
    final auth = DioClient.instance.options.headers['Authorization'];
    if (auth == null) return null;
    final s = auth.toString();
    if (s.isEmpty) return null;
    return {'Authorization': s};
  }

  /// Parked controllers (muted + paused) need [seekTo] before [play] on Android so AAC restarts.
  Future<void> _resumeController(
    BetterPlayerController controller,
    int index,
    List<PostModel> reels,
    int session,
  ) async {
    if (session != _playSession || !mounted) return;
    final vpc = controller.videoPlayerController;
    if (vpc == null) {
      await _ensureBetterPlayer(index, reels, session, activateIfCurrent: true, forceRecreate: true);
      return;
    }
    try {
      Duration target = Duration.zero;
      final pos = vpc.value.position;
      final dur = vpc.value.duration;
      if (pos > Duration.zero && dur != null && dur > Duration.zero && pos < dur) {
        target = pos;
      }
      await controller.seekTo(target);
      if (session != _playSession || !mounted) return;
      await _safeSetVolume(controller, 1.0);
      if (session != _playSession || !mounted) return;
      await _safePlay(controller);
      if (mounted && session == _playSession) setState(() {});
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[Reels] resumeController failed $e');
        debugPrint('$st');
      }
      if (session != _playSession || !mounted) return;
      await _disposeBetterAt(index);
      if (session != _playSession || !mounted) return;
      await _ensureBetterPlayer(index, reels, session, activateIfCurrent: true, forceRecreate: true);
    }
  }

  Future<void> _ensureBetterPlayer(
    int index,
    List<PostModel> reels,
    int session, {
    bool activateIfCurrent = false,
    bool forceRecreate = false,
  }) async {
    if (index < 0 || index >= reels.length) return;
    if (session != _playSession) return;

    final reel = reels[index];
    final url = reel.videoUrl;
    if (url == null || url.isEmpty) return;

    if (forceRecreate && _betterControllers.containsKey(index)) {
      await _disposeBetterAt(index);
    }
    if (session != _playSession || !mounted) return;

    final existing = _betterControllers[index];
    if (existing != null && !forceRecreate) {
      final isActiveSlot = activateIfCurrent && index == _currentIndex;
      if (isActiveSlot) {
        await _resumeController(existing, index, reels, session);
      } else {
        await _safeSetVolume(existing, 0);
        await _safePause(existing);
      }
      if (mounted && session == _playSession) setState(() {});
      return;
    }

    final cfg = _reelBetterConfig();
    final controller = BetterPlayerController(cfg);
    _bindReelPlayerEvents(controller, url, index, session);

    try {
      final BetterPlayerDataSource ds = BetterPlayerDataSource.network(
        url,
        cacheConfiguration: _reelNetworkCache(url),
        bufferingConfiguration: activateIfCurrent && index == _currentIndex ? _bufferingActive : _bufferingPrewarm,
      );
      await controller.setupDataSource(ds);
      if (!mounted || session != _playSession) {
        final l = _reelEventListeners.remove(url);
        if (l != null) {
          try {
            controller.removeEventsListener(l);
          } catch (_) {}
        }
        controller.dispose(forceDispose: true);
        return;
      }
      _betterControllers[index] = controller;
      if (activateIfCurrent && index == _currentIndex && session == _playSession) {
        await _resumeController(controller, index, reels, session);
      } else {
        await _safeSetVolume(controller, 0);
        await _safePause(controller);
        await _safeSeekZero(controller);
      }
    } catch (_) {
      final l = _reelEventListeners.remove(url);
      if (l != null) {
        try {
          controller.removeEventsListener(l);
        } catch (_) {}
      }
      try {
        controller.dispose(forceDispose: true);
      } catch (_) {}
    }
    if (mounted && session == _playSession) setState(() {});
  }

  Future<void> _activateIndex(int index, List<PostModel> reels, int session) async {
    if (index < 0 || index >= reels.length) return;
    final pauseFutures = <Future<void>>[];
    for (final entry in _betterControllers.entries) {
      if (entry.key == index) continue;
      final c = entry.value;
      pauseFutures.add(() async {
        try {
          await c.setVolume(0);
          await c.pause();
        } catch (_) {}
      }());
    }
    await Future.wait(pauseFutures);
    if (session != _playSession || !mounted) return;

    final existing = _betterControllers[index];
    if (existing != null) {
      await _resumeController(existing, index, reels, session);
    } else {
      await _ensureBetterPlayer(index, reels, session, activateIfCurrent: true);
    }
    if (session != _playSession || !mounted) return;
    _evictDistantControllers(index);
  }

  Future<void> _prewarmNeighbors(int center, List<PostModel> reels, int session) async {
    final neighbors = <int>[
      center + 1,
      center - 1,
      center + 2,
      center - 2,
    ].where((i) => i >= 0 && i < reels.length).toList();

    for (final i in neighbors) {
      if (session != _playSession || !mounted) return;
      if (_betterControllers.containsKey(i)) continue;
      await _ensureBetterPlayer(i, reels, session);
      final c = _betterControllers[i];
      if (c != null && session == _playSession) {
        await _safeSeekZero(c);
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (session != _playSession) return;
    }
  }

  /// After a list refresh removes items, keep [PageController] and player in range.
  void _clampCurrentIndexIfNeeded() {
    if (!mounted) return;
    final reels = _effectiveReelsList();
    if (reels.isEmpty) return;
    if (_currentIndex < reels.length) return;
    final n = reels.length - 1;
    _cancelPendingPlayerAttach();
    setState(() => _currentIndex = n);
    if (_pageController.hasClients) {
      _pageController.jumpToPage(n);
    }
    unawaited(_bootstrapPlayerImmediate('clampOvershoot'));
  }

  /// Fired when the vertical [PageView] settles on a new page.
  ///
  /// Bumps [_playSession] first (invalidates in-flight work), mutes the outgoing reel, updates
  /// [_currentIndex], then after [_pageSettleDelay] runs [_activateIndex].
  void _onPageChanged(int index) {
    final reels = _effectiveReelsList();
    if (index < 0 || index >= reels.length) return;

    if (index == _currentIndex) {
      return;
    }

    final session = ++_playSession;

    _pageSettleTimer?.cancel();

    final outgoing = _currentIndex;
    try {
      _betterControllers[outgoing]?.setVolume(0);
    } catch (_) {}

    setState(() {
      _currentIndex = index;
    });

    _pageSettleTimer = Timer(_pageSettleDelay, () {
      _pageSettleTimer = null;
      if (!mounted) return;
      if (session != _playSession) return;
      if (_currentIndex != index) return;
      final list = _effectiveReelsList();
      if (index < 0 || index >= list.length) return;
      unawaited(() async {
        await _activateIndex(index, list, session);
        if (!mounted || session != _playSession || _currentIndex != index) return;
        _scheduleDeferredPrewarm(index, list, session, delay: _deferredPrewarmDelaySwipe);
      }());
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(mainTabIndexProvider, (prev, next) {
      if (next != 1) {
        _cancelPendingPlayerAttach();
        unawaited(_releaseAllVideoResources());
      } else if (prev != null && prev != 1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final reels = _effectiveReelsList();
          if (reels.isNotEmpty) {
            // Single path: [_initVideosForList] → [_bootstrapPlayerImmediate] bumps [_playSession]
            // once and activates — do not increment session again or activation is discarded.
            _initVideosForList(reels);
          }
        });
      }
    });

    final reelsFromProvider = ref.watch(reelsListProvider);
    final isLoading = ref.watch(reelsLoadingProvider);
    final error = ref.watch(reelsErrorProvider);
    final prependedReel = widget.prependedReel;
    final initialPostId = widget.initialPostId;

    // Combined list: prepended reel first (tapped from home), then reels from API
    final reels = prependedReel != null
        ? [prependedReel, ...reelsFromProvider.where((r) => r.id != prependedReel.id)]
        : reelsFromProvider;

    final isPushedRoute = prependedReel != null || initialPostId != null;

    // When opened with prependedReel: start at 0 (tapped video) once. Else when initialPostId: jump to that index once.
    if (reels.isNotEmpty && !_hasAppliedInitialPostId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _hasAppliedInitialPostId = true;
        if (prependedReel == null && initialPostId == null) {
          return;
        }
        int targetIndex = 0;
        if (prependedReel != null) {
          targetIndex = 0;
        } else if (initialPostId != null) {
          final idx = reels.indexWhere((r) => r.id == initialPostId);
          if (idx >= 0) targetIndex = idx;
        }
        if (_pageController.hasClients && targetIndex < reels.length) {
          setState(() {
            _currentIndex = targetIndex;
          });
          _pageController.jumpToPage(targetIndex);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (_betterControllers.isEmpty) {
              unawaited(_bootstrapPlayerImmediate('routeInitialJump'));
            }
          });
        }
      });
    }

    if (reels.isNotEmpty && _currentIndex >= reels.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _clampCurrentIndexIfNeeded());
    }

    if (error != null && reels.isEmpty && !isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                error,
                style: TextStyle(color: ThemeHelper.getTextSecondary(context), fontSize: 14, decoration: TextDecoration.none),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => ref.read(reelsProvider.notifier).refresh(),
                child: Text('Retry', style: TextStyle(color: ThemeHelper.getAccentColor(context), decoration: TextDecoration.none)),
              ),
            ],
          ),
        ),
      );
    }
    final tabIndex = ref.watch(mainTabIndexProvider);
    final reelsTabVisible = tabIndex == 1 || isPushedRoute;
    final needsRouteJump = isPushedRoute && (prependedReel != null || initialPostId != null);
    if (reels.isNotEmpty && _betterControllers.isEmpty && reelsTabVisible && !needsRouteJump) {
      _initVideosForList(_effectiveReelsList());
    }

    final pageStack = DefaultTextStyle(
      style: const TextStyle(decoration: TextDecoration.none),
      child: RefreshIndicator(
        onRefresh: () => ref.read(reelsProvider.notifier).refresh(),
        color: Colors.white,
        backgroundColor: Colors.black54,
        child: PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          onPageChanged: _onPageChanged,
          itemCount: reels.length,
          physics: const _ReelPageScrollPhysics(),
          itemBuilder: (context, index) {
            if (index < 0 || index >= reels.length) {
              return Container(color: Colors.black);
            }
            return KeyedSubtree(
              key: ValueKey<String>(reels[index].id),
              child: _buildReelItem(reels[index], index),
            );
          },
        ),
      ),
    );

    final bodyChild = (reels.isEmpty && isLoading)
        ? _reelFullBleedSkeleton(context)
        : (reels.isEmpty
            ? Center(
                child: Text(
                  'No reels yet',
                  style: TextStyle(color: ThemeHelper.getTextSecondary(context), fontSize: 16, decoration: TextDecoration.none),
                ),
              )
            : pageStack);

    final content = Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: KeyedSubtree(
          key: ValueKey(
            reels.isEmpty && isLoading
                ? 'reel_skeleton'
                : reels.isEmpty
                    ? 'reel_empty'
                    : 'reel_feed',
          ),
          child: bodyChild,
        ),
      ),
    );

    if (isPushedRoute) {
      return Stack(
        children: [
          content,
          Positioned(
            top: MediaQuery.of(context).padding.top,
            left: 0,
            child: SafeArea(
              bottom: false,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 24),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      );
    }
    return content;
  }

  Widget _reelFullBleedSkeleton(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final w = constraints.maxWidth;
        final ar = w / (h > 1 ? h : 1);
        final targetW = (ar > 9 / 16) ? h * 9 / 16 : w;
        return Center(
          child: Shimmer.fromColors(
            baseColor: Colors.grey.shade900,
            highlightColor: Colors.grey.shade700,
            child: Container(
              width: targetW,
              height: h,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }

  Widget _reelBlurUnderlay(PostModel reel) {
    final gradient = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey.shade900,
            Colors.grey.shade800,
            Colors.black,
          ],
        ),
      ),
    );
    final h = reel.blurHash;
    if (h == null || h.length < 6) return gradient;
    try {
      final decoded = bh.BlurHash.decode(h);
      final im = decoded.toImage(64, 64);
      final jpg = img.encodeJpg(im, quality: 72);
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(Uint8List.fromList(jpg), fit: BoxFit.cover),
          gradient,
        ],
      );
    } catch (_) {
      return gradient;
    }
  }

  /// API [thumbnailUrl] first (with auth headers), then network fallback, then first video frame.
  Widget _reelPosterStack(PostModel reel, Uint8List? localThumb, Map<String, String>? headers) {
    final apiThumb = reel.thumbnailUrl != null && reel.thumbnailUrl!.trim().isNotEmpty
        ? reel.thumbnailUrl!.trim()
        : null;
    final fallbackNet = reel.effectiveThumbnailUrl;
    final hasLocal = localThumb != null && localThumb.isNotEmpty;
    final showShimmer = apiThumb == null &&
        (fallbackNet == null || fallbackNet.isEmpty) &&
        !hasLocal;

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(child: _reelBlurUnderlay(reel)),
        if (apiThumb != null)
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl: apiThumb,
              fit: BoxFit.cover,
              httpHeaders: headers,
              cacheManager: AppMediaCache.reelsThumbnails,
              errorWidget: (context, url, error) {
                if (fallbackNet != null &&
                    fallbackNet.isNotEmpty &&
                    fallbackNet != apiThumb) {
                  return CachedNetworkImage(
                    imageUrl: fallbackNet,
                    fit: BoxFit.cover,
                    httpHeaders: headers,
                    cacheManager: AppMediaCache.reelsThumbnails,
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        if (apiThumb == null && fallbackNet != null && fallbackNet.isNotEmpty)
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl: fallbackNet,
              fit: BoxFit.cover,
              httpHeaders: headers,
              cacheManager: AppMediaCache.reelsThumbnails,
              errorWidget: (context, url, error) => const SizedBox.shrink(),
            ),
          ),
        if (hasLocal)
          Positioned.fill(
            child: Image.memory(localThumb, fit: BoxFit.cover, gaplessPlayback: true),
          ),
        if (showShimmer)
          Positioned.fill(
            child: Shimmer.fromColors(
              baseColor: Colors.black.withValues(alpha: 0.25),
              highlightColor: Colors.white.withValues(alpha: 0.05),
              child: Container(color: Colors.transparent),
            ),
          ),
      ],
    );
  }

  Widget _buildReelItem(PostModel reel, int index) {
    final controller = _betterControllers[index];
    final isCurrent = index == _currentIndex;
    final ready = _betterReady(controller);
    final isPlaying = controller?.isPlaying() == true;
    final vUrl = reel.videoUrl;
    final localThumb = (vUrl != null && vUrl.isNotEmpty) ? _localVideoThumbs[vUrl] : null;
    final thumbHeaders = _reelThumbHeaders();
    final showPlayer = isCurrent && controller != null && ready;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (showPlayer)
          RepaintBoundary(
            key: ValueKey<Object>('reel_bc_${reel.id}_${controller.hashCode}'),
            child: ColoredBox(
              color: Colors.black,
              child: Center(
                child: SafeBetterPlayerWrapper(
                  key: ObjectKey(controller),
                  controller: controller,
                ),
              ),
            ),
          )
        else
          ColoredBox(
            color: Colors.black,
            child: _reelPosterStack(reel, localThumb, thumbHeaders),
          ),
        // Overlay UI
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.8),
                  Colors.transparent,
                ],
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Left side - Author info and caption
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundImage: reel.author.avatarUrl.isNotEmpty
                                ? CachedNetworkImageProvider(
                                    reel.author.avatarUrl,
                                    cacheManager: AppMediaCache.reelsThumbnails,
                                  )
                                : null,
                            backgroundColor: Colors.grey[800],
                            onBackgroundImageError: reel.author.avatarUrl.isNotEmpty
                                ? (exception, stackTrace) {}
                                : null,
                            child: reel.author.avatarUrl.isEmpty
                                ? Icon(Icons.person, color: Colors.grey[600], size: 22)
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  reel.author.username,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Follow button - hide when author is current user
                          Consumer(
                            builder: (context, ref, child) {
                              final currentUser = ref.watch(currentUserProvider);
                              if (currentUser?.id == reel.author.id) {
                                return const SizedBox.shrink();
                              }
                              final followState = ref.watch(followProvider);
                              final followOverrides = ref.watch(followStateProvider);
                              final posts = ref.watch(postsListProvider);
                              PostModel? post;
                              try {
                                post = posts.firstWhere((p) => p.author.id == reel.author.id);
                              } catch (_) {}
                              final overrideStatus =
                                  followOverrides[reel.author.id];
                              final isFollowing =
                                  overrideStatus ==
                                          FollowRelationshipStatus.following ||
                                      (overrideStatus == null &&
                                          (followState.followingIds.isNotEmpty
                                              ? followState.followingIds
                                                  .contains(reel.author.id)
                                              : (post?.author.isFollowing ??
                                                  reel.author.isFollowing)));
                              final isPending = overrideStatus ==
                                      FollowRelationshipStatus.pending ||
                                  (overrideStatus == null &&
                                      followState.outgoingPendingRequests
                                          .containsKey(reel.author.id));
                              return GestureDetector(
                                onTap: () {
                                  ref.read(followProvider.notifier).toggleFollow(reel.author.id);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isFollowing ? Colors.transparent : Colors.white,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: isFollowing ? Colors.white.withOpacity(0.5) : Colors.white,
                                      width: isFollowing ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Text(
                                    isFollowing
                                        ? 'Following'
                                        : (isPending ? 'Requested' : 'Follow'),
                                    style: TextStyle(
                                      color: isFollowing ? Colors.white : Colors.black,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Audio row (Instagram-style) - tappable to see reels with same audio
                      if (reel.audioName != null || reel.isVideo)
                        GestureDetector(
                            onTap: () {
                            _cancelPendingPlayerAttach();
                            unawaited(_releaseAllVideoResources());
                            if (mounted) setState(() {});
                            final audioId = reel.audioId ?? 'original_${reel.author.id}';
                            final audioName = reel.audioName ?? 'Original sound - ${reel.author.username}';
                            final reelsList = ref.read(reelsListProvider);
                            final sameAudioReels = reelsList.where((r) => (r.audioId ?? 'original_${r.author.id}') == audioId).toList();
                            if (sameAudioReels.isEmpty) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AudioDetailScreen(
                                  audioId: audioId,
                                  audioName: audioName,
                                  reels: sameAudioReels,
                                ),
                              ),
                            ).then((_) {
                              // Re-initialize current video when returning from audio/create content screen
                              if (mounted) {
                                final reelsList = ref.read(reelsListProvider);
                                _initVideosForList(reelsList);
                              }
                            });
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.music_note_rounded, color: Colors.white, size: 18),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  reel.audioName ?? 'Original sound - ${reel.author.username}',
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        reel.caption,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.left,
                        style: TextStyle(
                          // Caption on dark overlay - use white for visibility in both modes
                          color: Colors.white,
                          fontSize: 14,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.6),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Right side - Action buttons
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (reel.author.allowLikes) ...[
                          _buildActionButton(
                          icon: Icons.favorite,
                          count: ref.watch(reelLikeCountProvider(reel.id)),
                          isActive: ref.watch(reelLikedProvider(reel.id)),
                          onTap: () {
                            ref.read(reelsProvider.notifier).toggleLikeWithApi(reel.id);
                          },
                        ),
                      const SizedBox(height: 14),
                    ],
                    if (reel.author.allowComments) ...[
                      _buildActionButton(
                        icon: Icons.comment,
                        count: reel.comments,
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => CommentsBottomSheet(postId: reel.id),
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (reel.author.allowShares) ...[
                      GestureDetector(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => ShareBottomSheet(
                              postId: reel.id,
                              videoUrl: reel.videoUrl,
                              imageUrl: reel.effectiveThumbnailUrl,
                            ),
                          );
                        },
                        child: Column(
                          children: [
                            Transform.rotate(
                              angle: -0.785398,
                              child: Icon(
                                Icons.send,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatCount(reel.shares),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    _buildActionButton(
                      icon: (_savedReels[reel.id] ?? false) ? Icons.star : Icons.star_border,
                      onTap: () {
                        setState(() {
                          _savedReels[reel.id] = !(_savedReels[reel.id] ?? false);
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildActionButton(
                      icon: isPlaying ? Icons.pause : Icons.play_arrow,
                      onTap: () {
                        if (controller != null && identical(_betterControllers[index], controller)) {
                          if (isPlaying) {
                            unawaited(_safePause(controller));
                          } else {
                            unawaited(() async {
                              await _safeSetVolume(controller, 1.0);
                              await _safePlay(controller);
                            }());
                          }
                          setState(() {});
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Three-dot menu (vertical) top right
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          right: 12,
          child: GestureDetector(
            onTap: () => _showReelMoreMenu(context, reel),
            child: Icon(
              Icons.more_vert,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ],
    );
  }

  void _showReelMoreMenu(BuildContext context, PostModel reel) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            child: const Text('Report'),
            onPressed: () async {
              final currentUserId = ref.read(authProvider).currentUser?.id ?? '';
              Navigator.pop(context);

              final result = await PostsService().reportPost(
                postId: reel.id,
                currentUserId: currentUserId,
                postAuthorId: reel.author.id,
              );

              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    result.success ? 'Reported' : (result.errorMessage ?? 'Report failed'),
                  ),
                  backgroundColor: result.success
                      ? ThemeHelper.getAccentColor(context)
                      : ThemeHelper.getSurfaceColor(context),
                ),
              );
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('Copy Link'),
            onPressed: () {
              final link = ShareLinkHelper.build(
                contentId: reel.id,
                thumbnailUrl: reel.effectiveThumbnailUrl,
              );
              Navigator.pop(context);
              Clipboard.setData(ClipboardData(text: link));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Link copied!',
                    style: TextStyle(color: ThemeHelper.getTextPrimary(context)),
                  ),
                  backgroundColor:
                      ThemeHelper.getSurfaceColor(context).withOpacity(0.95),
                ),
              );
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('Cancel'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    int? count,
    bool isActive = false,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Icon(
            icon,
            color: isActive ? Colors.red : Colors.white,
            size: 28,
          ),
        ),
        if (count != null) ...[
          const SizedBox(height: 4),
          Text(
            _formatCount(count),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
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

/// Instagram-like snap paging without bounce, tuned to avoid accidental skips.
class _ReelPageScrollPhysics extends PageScrollPhysics {
  const _ReelPageScrollPhysics({super.parent});

  @override
  _ReelPageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _ReelPageScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double get dragStartDistanceMotionThreshold => 2.0;

  @override
  double get minFlingVelocity => 16.0;
}
