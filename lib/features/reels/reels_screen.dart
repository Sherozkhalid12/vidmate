import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:better_player/better_player.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
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
import '../../core/media/long_video_better_cache.dart';
import '../../core/perf/reels_perf_metrics.dart';
import '../../services/posts/posts_service.dart';
import '../../core/models/post_model.dart';
import '../../core/providers/reels_provider_riverpod.dart';
import '../../core/providers/blocked_users_provider.dart';
import '../../core/providers/post_views_provider.dart';
import '../../core/providers/saved_posts_provider_riverpod.dart';
import '../../core/providers/home_feed_playback_provider_riverpod.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/media/adaptive_track_selection.dart';
import '../../core/api/dio_client.dart';
import '../../core/utils/reels_logger.dart';
import '../../core/utils/create_content_visibility.dart';
import '../../core/utils/share_link_helper.dart';
import '../profile/profile_screen.dart';
import '../../core/video_engine/global_video_engine_state.dart';
import '../../core/video_engine/video_engine_budget.dart';
import '../../core/video_engine/video_engine_logger.dart';
import '../../core/video_engine/video_feed_warm_pool.dart';
import '../../core/video_engine/video_engine_provider.dart'
    show globalVideoEngineProvider;
import 'audio_detail_screen.dart';

const int _kReelsTabIndex = kReelsTabIndex;

/// Reels screen with full-screen vertical swipe videos.
///
/// Playback is owned exclusively by [GlobalVideoEngine]. This screen only
/// coordinates index, debounced activation, and lightweight UI notifiers.
/// When [prependedReel] is set (from home feed), this reel is shown first, then the rest from API.
/// When [initialPostId] is set, finds that reel in the list and opens at it. Shows back button when opened as a route.
class ReelsScreen extends ConsumerStatefulWidget {
  const ReelsScreen({
    super.key,
    this.initialPostId,
    this.prependedReel,
    this.bottomPadding = 0,
  });

  final String? initialPostId;

  /// When set, this reel is shown first (tapped video from home), then reels from API. Takes precedence over initialPostId.
  final PostModel? prependedReel;

  /// Tab bar + safe-area inset from [MainScreen] so overlays stay above the nav.
  final double bottomPadding;

  @override
  ConsumerState<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends ConsumerState<ReelsScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  final ValueNotifier<int> _activeIndexNotifier = ValueNotifier(0);
  final ValueNotifier<int> _controllerMapVersion = ValueNotifier<int>(0);
  final Map<int, ValueNotifier<bool>> _readyNotifiers = {};
  final Map<int, ValueNotifier<bool>> _playingNotifiers = {};
  final Map<int, ValueNotifier<bool>> _bufferingNotifiers = {};
  final ValueNotifier<bool> _activeThumbnailVisibleNotifier =
      ValueNotifier<bool>(false);
  final Map<String, Uint8List> _blurHashCache = {};
  final Set<String> _blurHashDecodeInFlight = <String>{};
  final Map<int, Completer<void>> _readyCompleters = {};
  final Map<int, Future<void>> _readyFutures = {};
  final Map<String, Uint8List?> _localVideoThumbs = {};
  bool _hasAppliedInitialPostId = false;
  bool _firstReelMetricLogged = false;

  /// Invalidates stale async work after a newer reel activation was requested.
  int _activationTicket = 0;

  /// Coalesces rapid vertical swipes: only the last [onPageChanged] runs activation after quiet period.
  Timer? _reelSettleTimer;
  int _pendingPageIndex = 0;

  /// Serial guard so only the latest settle timer runs after fast swipes.
  int _settleEpoch = 0;

  bool _isViewportActive = true;
  bool _wasViewportActive = false;
  Timer? _progressTimer;
  Timer? _thumbnailRevealTimer;
  late final AnimationController _progressAnimation;
  bool _mutePauseRequestedWhileInactive = false;

  final Map<BetterPlayerController, void Function(BetterPlayerEvent)>
      _reelEventListeners = {};
  _ReelWarmSlot? _prevWarmSlot;
  _ReelWarmSlot? _nextWarmSlot;
  /// Paused controller parked while the long-videos tab owns the engine.
  _ReelWarmSlot? _standbySlot;
  bool _warmSlotsDisposedWhileInactive = false;
  ProviderSubscription<int>? _tabIndexSub;
  ProviderSubscription<List<PostModel>>? _reelsListSub;
  Offset _lastDoubleTapLocal = Offset.zero;
  OverlayEntry? _heartOverlay;

  @override
  void initState() {
    super.initState();
    _progressAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      lowerBound: 0.0,
      upperBound: 1.0,
      value: 0.0,
    );
    createContentVisibleNotifier.addListener(_onCreateContentVisibilityChanged);
    ReelsPerfMetrics.instance.onScreenMount();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final saved = ref.read(savedPostsProvider);
      if (saved.savedPostIds.isEmpty && !saved.isLoading) {
        unawaited(ref.read(savedPostsProvider.notifier).loadSavedPosts());
      }
    });
    ref.read(videoFeedWarmPoolProvider.notifier).register(
          'reels',
          () async {
            if (!mounted) return;
            await _disposeWarmControllers();
          },
        );

    _tabIndexSub = ref.listenManual<int>(mainTabIndexProvider, (prev, next) {
      if (prev == null) return;

      if (next != _kReelsTabIndex) {
        _cancelPendingPlayerAttach();
        if (next == kLongVideosTabIndex) {
          unawaited(_parkOneReelStandby());
        }
      } else if (prev != _kReelsTabIndex) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          unawaited(_activateInitialReelIfNeeded());
        });
      }
    });
    _reelsListSub = ref.listenManual<List<PostModel>>(reelsListProvider, (prev, next) {
      if (prev != null && prev.isNotEmpty) return;
      if (next.isEmpty) return;
      final tabIndex = ref.read(mainTabIndexProvider);
      final isPushedRoute = widget.prependedReel != null || widget.initialPostId != null;
      final reelsTabVisible = tabIndex == _kReelsTabIndex || isPushedRoute;
      final needsRouteJump = isPushedRoute && !_hasAppliedInitialPostId;
      if (!reelsTabVisible) return;
      if (needsRouteJump) return;
      ReelsLogger.lifecycle('LIST_SUB: empty->content, init videos');
      unawaited(_activateInitialReelIfNeeded());
    });
  }

  List<PostModel> _effectiveReelsList() {
    final reelsFromProvider = ref.read(reelsListProvider);
    final prependedReel = widget.prependedReel;
    final blocked = ref.read(blockedUserIdsProvider);
    List<PostModel> list;
    if (prependedReel != null) {
      list = [
        prependedReel,
        ...reelsFromProvider.where((r) => r.id != prependedReel.id),
      ];
    } else {
      list = reelsFromProvider;
    }
    if (blocked.isEmpty) return list;
    return list.where((r) => !blocked.contains(r.author.id)).toList();
  }

  void _onCreateContentVisibilityChanged() {
    if (createContentVisibleNotifier.value) {
      _cancelPendingPlayerAttach();
      unawaited(_releaseAllVideoResources());
      // No setState needed — _releaseAllVideoResources updates _controllerMapVersion
    }
  }

  @override
  void dispose() {
    _tabIndexSub?.close();
    _tabIndexSub = null;
    _reelsListSub?.close();
    _reelsListSub = null;
    _activationTicket++;
    _reelSettleTimer?.cancel();
    createContentVisibleNotifier.removeListener(_onCreateContentVisibilityChanged);
    _pageController.dispose();
    _activeIndexNotifier.dispose();
    _controllerMapVersion.dispose();
    _activeThumbnailVisibleNotifier.dispose();
    for (final n in _readyNotifiers.values) {
      n.dispose();
    }
    for (final n in _playingNotifiers.values) {
      n.dispose();
    }
    for (final n in _bufferingNotifiers.values) {
      n.dispose();
    }
    _readyNotifiers.clear();
    _playingNotifiers.clear();
    _bufferingNotifiers.clear();
    for (final c in _readyCompleters.values) {
      if (!c.isCompleted) c.complete();
    }
    _readyCompleters.clear();
    _readyFutures.clear();
    _progressTimer?.cancel();
    _thumbnailRevealTimer?.cancel();
    _progressAnimation.dispose();
    _heartOverlay?.remove();
    _heartOverlay = null;
    _unbindAllReelEventListeners();
    unawaited(_releaseAllVideoResources());
    super.dispose();
  }

  ValueNotifier<bool> _readyNotifierFor(int index) =>
      _readyNotifiers.putIfAbsent(index, () => ValueNotifier<bool>(false));

  ValueNotifier<bool> _playingNotifierFor(int index) =>
      _playingNotifiers.putIfAbsent(index, () => ValueNotifier<bool>(false));

  ValueNotifier<bool> _bufferingNotifierFor(int index) =>
      _bufferingNotifiers.putIfAbsent(index, () => ValueNotifier<bool>(false));

  void _setReady(int index, bool ready) {
    final n = _readyNotifierFor(index);
    if (n.value != ready) n.value = ready;
  }

  void _setPlaying(int index, bool playing) {
    final n = _playingNotifierFor(index);
    if (n.value != playing) n.value = playing;
  }

  void _setBuffering(int index, bool buffering) {
    final n = _bufferingNotifierFor(index);
    if (n.value != buffering) n.value = buffering;
  }

  void _completeReadyFuture(int index) {
    final c = _readyCompleters[index];
    if (c != null && !c.isCompleted) {
      c.complete();
    }
  }

  void _clearReadyFuture(int index) {
    _readyCompleters.remove(index);
    _readyFutures.remove(index);
  }

  void _resetActiveThumbnailOverlay() {
    _thumbnailRevealTimer?.cancel();
    _thumbnailRevealTimer = null;
    if (_activeThumbnailVisibleNotifier.value) {
      _activeThumbnailVisibleNotifier.value = false;
    }
  }

  void _onActiveBufferingStart() {
    _thumbnailRevealTimer?.cancel();
    _thumbnailRevealTimer = Timer(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      final c = _engineControllerForCurrentReel();
      if (c != null && _isControllerUsable(c) && c.isPlaying() != true) {
        _activeThumbnailVisibleNotifier.value = true;
      }
    });
  }

  void _onActiveBufferingEndOrPlay() {
    _thumbnailRevealTimer?.cancel();
    _thumbnailRevealTimer = null;
    if (_activeThumbnailVisibleNotifier.value) {
      _activeThumbnailVisibleNotifier.value = false;
    }
  }

  bool _isControllerUsable(BetterPlayerController? c) {
    if (c == null) return false;
    try {
      final vpc = c.videoPlayerController;
      if (vpc == null) return false;
      if (vpc.value.initialized != true) return false;
      // Extra safety: check the controller has not been internally disposed
      final _ = vpc.value.position;
      return true;
    } catch (_) {
      return false;
    }
  }

  BetterPlayerController? _engineControllerForCurrentReel() {
    final reels = _effectiveReelsList();
    final viewIndex = _activeIndexNotifier.value;
    if (viewIndex < 0 || viewIndex >= reels.length) return null;
    final slot = ref.read(globalVideoEngineProvider).activeSlot;
    if (slot == null || slot.id != reels[viewIndex].id) return null;
    return slot.controller;
  }

  BetterPlayerController? _engineControllerForReelIndex(int index) {
    final reels = _effectiveReelsList();
    if (index < 0 || index >= reels.length) return null;
    final slot = ref.read(globalVideoEngineProvider).activeSlot;
    if (slot == null || slot.id != reels[index].id) return null;
    return slot.controller;
  }

  void _syncPlayingNotifierFromController(int index) {
    final c = _engineControllerForReelIndex(index);
    _setPlaying(index, c?.isPlaying() == true);
  }

  void _startProgressTracking(BetterPlayerController controller) {
    _progressTimer?.cancel();
    _progressAnimation.value = 0.0;
    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final vpc = controller.videoPlayerController;
      if (vpc == null || !vpc.value.initialized) return;
      final pos = vpc.value.position.inMilliseconds;
      final dur = vpc.value.duration?.inMilliseconds ?? 0;
      if (dur <= 0) return;
      _progressAnimation.value = (pos / dur).clamp(0.0, 1.0);
    });
  }

  void _stopProgressTracking() {
    _progressTimer?.cancel();
    _progressTimer = null;
    _progressAnimation.value = 0.0;
  }

  void _cancelPendingPlayerAttach() {
    _reelSettleTimer?.cancel();
    _reelSettleTimer = null;
  }

  Future<void> _safeSetVolume(BetterPlayerController c, double value) async {
    if (!_isControllerUsable(c)) return;
    try {
      await c.setVolume(value);
    } catch (_) {}
  }

  Future<void> _safePause(BetterPlayerController c) async {
    if (!_isControllerUsable(c)) return;
    try {
      await c.pause();
    } catch (_) {}
  }

  Future<void> _safePlay(BetterPlayerController c) async {
    if (!_isControllerUsable(c)) return;
    if (!_isViewportActive) {
      try {
        await c.setVolume(0);
      } catch (_) {}
      try {
        await c.pause();
      } catch (_) {}
      return;
    }
    try {
      await c.play();
    } catch (_) {}
  }

  Future<void> _muteAndPauseAllPlayers() async {
    try {
      await ref.read(globalVideoEngineProvider.notifier).pauseActive();
    } catch (_) {}
    _stopProgressTracking();
  }

  BetterPlayerConfiguration _reelPoolConfiguration() {
    return BetterPlayerConfiguration(
      aspectRatio: 9 / 16,
      fit: BoxFit.cover,
      autoPlay: false,
      looping: true,
      handleLifecycle: false,
      autoDispose: false,
      expandToFill: true,
      controlsConfiguration: const BetterPlayerControlsConfiguration(
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

  BetterPlayerDataSource _reelPoolDataSource(String url) {
    return BetterPlayerDataSource.network(
      url,
      useAsmsTracks: true,
      cacheConfiguration: longVideoNetworkCache(url),
      bufferingConfiguration: const BetterPlayerBufferingConfiguration(
        minBufferMs: 1500,
        maxBufferMs: 2000,
        bufferForPlaybackMs: 300,
        bufferForPlaybackAfterRebufferMs: 800,
      ),
    );
  }

  bool _warmSlotMatches(_ReelWarmSlot? slot, String id, String url) {
    return slot != null && slot.id == id && slot.url == url;
  }

  void _unbindAllReelEventListeners() {
    for (final entry in _reelEventListeners.entries.toList()) {
      try {
        entry.key.removeEventsListener(entry.value);
      } catch (_) {}
    }
    _reelEventListeners.clear();
  }

  void _disposeDetachedController(
    BetterPlayerController controller, {
    String label = '',
  }) {
    VideoEngineLogger.engine('REELS_DISPOSE_DETACHED label=$label');
    try {
      controller.pause();
    } catch (_) {}
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        controller.dispose(forceDispose: true);
      } catch (_) {}
    });
  }

  void _clearWarmSlot(_ReelWarmNeighbor neighbor) {
    if (neighbor == _ReelWarmNeighbor.next) {
      _nextWarmSlot = null;
    } else {
      _prevWarmSlot = null;
    }
  }

  Future<void> _disposeWarmControllers({bool markInactive = false}) async {
    final prev = _prevWarmSlot;
    final next = _nextWarmSlot;
    final standby = _standbySlot;

    _prevWarmSlot = null;
    _nextWarmSlot = null;
    _standbySlot = null;

    if (prev != null) {
      VideoEngineLogger.engine('REELS_WARM_DISPOSE prev id=${prev.id}');
      _disposeDetachedController(
        prev.controller,
        label: 'reels-prev-warm',
      );
    }

    if (next != null && !identical(next.controller, prev?.controller)) {
      VideoEngineLogger.engine('REELS_WARM_DISPOSE next id=${next.id}');
      _disposeDetachedController(
        next.controller,
        label: 'reels-next-warm',
      );
    }

    if (standby != null &&
        !identical(standby.controller, prev?.controller) &&
        !identical(standby.controller, next?.controller)) {
      VideoEngineLogger.engine('REELS_STANDBY_DISPOSE id=${standby.id}');
      _disposeDetachedController(
        standby.controller,
        label: 'reels-standby',
      );
    }

    if (markInactive) {
      _warmSlotsDisposedWhileInactive = true;
    }
  }

  /// Parks one paused reel controller while the long-videos tab is active.
  Future<void> _parkOneReelStandby() async {
    if (!mounted) return;

    final prev = _prevWarmSlot;
    _prevWarmSlot = null;
    if (prev != null) {
      _disposeDetachedController(prev.controller, label: 'reels-park-dispose-prev');
    }

    final reels = _effectiveReelsList();
    final idx = _activeIndexNotifier.value.clamp(
      0,
      reels.isEmpty ? 0 : reels.length - 1,
    );
    if (reels.isEmpty) {
      if (_nextWarmSlot != null) {
        _disposeDetachedController(
          _nextWarmSlot!.controller,
          label: 'reels-park-dispose-next-empty',
        );
        _nextWarmSlot = null;
      }
      if (_standbySlot != null) {
        _disposeDetachedController(
          _standbySlot!.controller,
          label: 'reels-park-dispose-standby-empty',
        );
        _standbySlot = null;
      }
      _warmSlotsDisposedWhileInactive = true;
      return;
    }

    final reel = reels[idx];
    final url = _reelPlayUrl(reel).trim();
    BetterPlayerController? parkedController;
    String? parkedId;
    String? parkedUrl;

    final engine = ref.read(globalVideoEngineProvider);
    if (engine.activeFeature == VideoEngineFeature.reels &&
        engine.activeSlot != null &&
        engine.activeSlot!.id == reel.id &&
        url.isNotEmpty) {
      final detached =
          ref.read(globalVideoEngineProvider.notifier).detachActiveForEmbedded();
      if (detached != null) {
        parkedController = detached;
        parkedId = reel.id;
        parkedUrl = url;
      }
    }

    if (parkedController == null && _nextWarmSlot != null) {
      final warm = _nextWarmSlot!;
      parkedController = warm.controller;
      parkedId = warm.id;
      parkedUrl = warm.url;
      _nextWarmSlot = null;
    } else if (_nextWarmSlot != null) {
      _disposeDetachedController(
        _nextWarmSlot!.controller,
        label: 'reels-park-dispose-next',
      );
      _nextWarmSlot = null;
    }

    if (parkedController != null && parkedId != null && parkedUrl != null) {
      if (_standbySlot != null &&
          !identical(_standbySlot!.controller, parkedController)) {
        _disposeDetachedController(
          _standbySlot!.controller,
          label: 'reels-park-replace-standby',
        );
      }
      try {
        await parkedController.pause();
      } catch (_) {}
      try {
        await parkedController.setVolume(0.0);
      } catch (_) {}
      _standbySlot = _ReelWarmSlot(
        id: parkedId,
        url: parkedUrl,
        controller: parkedController,
      );
      _warmSlotsDisposedWhileInactive = false;
      VideoEngineLogger.engine('REELS_STANDBY_PARKED id=$parkedId');
      return;
    }

    if (_standbySlot != null) {
      _warmSlotsDisposedWhileInactive = false;
      return;
    }

    _warmSlotsDisposedWhileInactive = true;
  }

  Future<BetterPlayerController?> _ensureWarmSlot({
    required _ReelWarmNeighbor neighbor,
    required int activeIndex,
    required int ticket,
    BetterPlayerController? recyclableController,
  }) async {
    final reels = _effectiveReelsList();
    final targetIndex = neighbor == _ReelWarmNeighbor.next
        ? activeIndex + 1
        : activeIndex - 1;

    final currentSlot =
        neighbor == _ReelWarmNeighbor.next ? _nextWarmSlot : _prevWarmSlot;

    if (targetIndex < 0 || targetIndex >= reels.length) {
      if (currentSlot != null) {
        _clearWarmSlot(neighbor);
        _disposeDetachedController(
          currentSlot.controller,
          label: 'reels-${neighbor.name}-out-of-range',
        );
      }
      return recyclableController;
    }

    final targetReel = reels[targetIndex];
    final targetUrl = _reelPlayUrl(targetReel).trim();

    if (targetUrl.isEmpty) {
      if (currentSlot != null) {
        _clearWarmSlot(neighbor);
        _disposeDetachedController(
          currentSlot.controller,
          label: 'reels-${neighbor.name}-empty-url',
        );
      }
      return recyclableController;
    }

    if (_warmSlotMatches(currentSlot, targetReel.id, targetUrl)) {
      return recyclableController;
    }

    final usingRecyclable =
        currentSlot == null && recyclableController != null;

    final controller = currentSlot?.controller ??
        recyclableController ??
        BetterPlayerController(_reelPoolConfiguration());

    if (usingRecyclable) {
      recyclableController = null;
    }

    try {
      await controller.pause();
    } catch (_) {}

    try {
      await controller.setVolume(0.0);
    } catch (_) {}

    try {
      await controller.setupDataSource(_reelPoolDataSource(targetUrl));
      try {
        await controller.seekTo(Duration.zero);
      } catch (_) {}
      try {
        await controller.pause();
      } catch (_) {}
    } catch (e) {
      VideoEngineLogger.error(
        'REELS_WARM_SETUP_FAILED side=${neighbor.name} id=${targetReel.id} error=$e',
      );
      if (currentSlot != null && identical(currentSlot.controller, controller)) {
        _clearWarmSlot(neighbor);
      }
      _disposeDetachedController(
        controller,
        label: 'reels-${neighbor.name}-setup-failed',
      );
      return recyclableController;
    }

    if (!mounted ||
        ticket != _activationTicket ||
        _activeIndexNotifier.value != activeIndex ||
        !_isViewportActive) {
      if (currentSlot != null && identical(currentSlot.controller, controller)) {
        _clearWarmSlot(neighbor);
      }
      _disposeDetachedController(
        controller,
        label: 'reels-${neighbor.name}-stale',
      );
      return recyclableController;
    }

    final slot = _ReelWarmSlot(
      id: targetReel.id,
      url: targetUrl,
      controller: controller,
    );

    if (neighbor == _ReelWarmNeighbor.next) {
      _nextWarmSlot = slot;
    } else {
      _prevWarmSlot = slot;
    }

    VideoEngineLogger.engine(
      'REELS_WARM_READY side=${neighbor.name} index=$targetIndex id=${targetReel.id}',
    );

    return recyclableController;
  }

  Future<void> _refreshWarmControllersFor({
    required int activeIndex,
    required int ticket,
    BetterPlayerController? reusableController,
  }) async {
    if (!mounted || !_isViewportActive) {
      if (reusableController != null) {
        _disposeDetachedController(
          reusableController,
          label: 'reels-warm-not-visible',
        );
      }
      return;
    }

    var recyclable = reusableController;

    recyclable = await _ensureWarmSlot(
      neighbor: _ReelWarmNeighbor.next,
      activeIndex: activeIndex,
      ticket: ticket,
      recyclableController: recyclable,
    );

    recyclable = await _ensureWarmSlot(
      neighbor: _ReelWarmNeighbor.previous,
      activeIndex: activeIndex,
      ticket: ticket,
      recyclableController: recyclable,
    );

    if (recyclable != null) {
      _disposeDetachedController(
        recyclable,
        label: 'reels-unused-recyclable',
      );
    }
  }

  Future<_ReelPromotionResult?> _tryPromoteWarmController({
    required PostModel reel,
    required String url,
  }) async {
    final engine = ref.read(globalVideoEngineProvider.notifier);
    final before = ref.read(globalVideoEngineProvider).activeSlot;

    if (_warmSlotMatches(_nextWarmSlot, reel.id, url)) {
      final promoted = _nextWarmSlot!;
      final recyclable = _prevWarmSlot;

      _nextWarmSlot = null;
      _prevWarmSlot = null;

      _unbindAllReelEventListeners();

      final detached = engine.detachActiveForEmbedded();
      if (detached != null && before != null) {
        try {
          await detached.pause();
        } catch (_) {}
        try {
          await detached.setVolume(0.0);
        } catch (_) {}
        _prevWarmSlot = _ReelWarmSlot(
          id: before.id,
          url: before.url,
          controller: detached,
        );
      } else if (detached != null) {
        _disposeDetachedController(detached, label: 'reels-promote-next-orphan');
      }

      engine.acceptReturnedController(
        id: reel.id,
        url: url,
        controller: promoted.controller,
      );

      VideoEngineLogger.engine('REELS_PROMOTE_NEXT id=${reel.id}');

      return _ReelPromotionResult(
        controller: promoted.controller,
        reusableController: recyclable?.controller,
      );
    }

    if (_warmSlotMatches(_prevWarmSlot, reel.id, url)) {
      final promoted = _prevWarmSlot!;
      final recyclable = _nextWarmSlot;

      _prevWarmSlot = null;
      _nextWarmSlot = null;

      _unbindAllReelEventListeners();

      final detached = engine.detachActiveForEmbedded();
      if (detached != null && before != null) {
        try {
          await detached.pause();
        } catch (_) {}
        try {
          await detached.setVolume(0.0);
        } catch (_) {}
        _nextWarmSlot = _ReelWarmSlot(
          id: before.id,
          url: before.url,
          controller: detached,
        );
      } else if (detached != null) {
        _disposeDetachedController(detached, label: 'reels-promote-prev-orphan');
      }

      engine.acceptReturnedController(
        id: reel.id,
        url: url,
        controller: promoted.controller,
      );

      VideoEngineLogger.engine('REELS_PROMOTE_PREV id=${reel.id}');

      return _ReelPromotionResult(
        controller: promoted.controller,
        reusableController: recyclable?.controller,
      );
    }

    return null;
  }

  Future<BetterPlayerController?> _activateReelWithPool({
    required int index,
    required PostModel reel,
    required String url,
    required int ticket,
  }) async {
    BetterPlayerController? controller;
    BetterPlayerController? reusableController;

    final promoted = await _tryPromoteWarmController(
      reel: reel,
      url: url,
    );

    if (promoted != null) {
      controller = promoted.controller;
      reusableController = promoted.reusableController;
      // A promoted warm controller is pre-initialized but paused/muted. Start it
      // immediately so ready/play listeners can flip the UI off the thumbnail.
      try {
        await controller.setVolume(1.0);
      } catch (_) {}
      try {
        await controller.play();
      } catch (_) {}
    } else {
      controller = await ref.read(globalVideoEngineProvider.notifier).play(
            id: reel.id,
            url: url,
            feature: VideoEngineFeature.reels,
            muteInitially: false,
          );
    }

    if (controller != null &&
        mounted &&
        ticket == _activationTicket &&
        _activeIndexNotifier.value == index) {
      unawaited(
        _refreshWarmControllersFor(
          activeIndex: index,
          ticket: ticket,
          reusableController: reusableController,
        ),
      );
    } else if (reusableController != null) {
      _disposeDetachedController(
        reusableController,
        label: 'reels-promotion-unused',
      );
    }

    return controller;
  }

  Future<void> _releaseAllVideoResources() async {
    ReelsLogger.life('RELEASE_ALL (pause global engine)');
    _unbindAllReelEventListeners();
    await _disposeWarmControllers();
    try {
      await ref.read(globalVideoEngineProvider.notifier).pauseActive();
    } catch (_) {}
    _stopProgressTracking();
    for (final idx in _readyNotifiers.keys.toList()) {
      _setPlaying(idx, false);
      _setReady(idx, false);
      _setBuffering(idx, false);
      _completeReadyFuture(idx);
      _clearReadyFuture(idx);
    }
    _controllerMapVersion.value++;
    ReelsLogger.lifecycle('RELEASE_ALL done');
  }

  bool _reelUrlLooksAdaptive(String url) {
    final u = url.toLowerCase();
    return u.contains('.m3u8') ||
        u.contains('.mpd') ||
        u.contains('/master') ||
        u.contains('playlist');
  }

  Future<void> _applyReelAdaptiveResolution(
    BetterPlayerController controller,
    String url,
  ) async {
    if (!_reelUrlLooksAdaptive(url)) return;
    if (!mounted || !context.mounted) return;
    try {
      if (controller.isVideoInitialized() != true) return;
      final tracks = controller.betterPlayerAsmsTracks;
      if (tracks.length < 2) return;
      final cx = await Connectivity().checkConnectivity();
      final pick = pickBetterPlayerTrackForConnectivity(tracks, cx);
      if (pick == null || !mounted || !context.mounted) return;
      controller.setTrack(pick);
    } catch (_) {}
  }

  void _bindReelPlayerEvents(
    BetterPlayerController controller,
    String url,
    int index,
    int boundTicket,
  ) {
    _unbindAllReelEventListeners();

    _setReady(index, false);

    var initializedFired = false;
    var playFired = false;
    void maybeSetReady() {
      if (initializedFired && playFired) {
        _setReady(index, true);
      }
    }

    void listener(BetterPlayerEvent ev) {
      if (boundTicket != _activationTicket) return;
      if (ev.betterPlayerEventType == BetterPlayerEventType.bufferingStart) {
        ReelsPerfMetrics.instance.recordRebuffer();
        if (index == _activeIndexNotifier.value) {
          _setBuffering(index, true);
          _onActiveBufferingStart();
        }
      }
      if (ev.betterPlayerEventType == BetterPlayerEventType.initialized) {
        _completeReadyFuture(index);
        _syncReelVideoAspectRatio(controller);
        unawaited(_applyReelAdaptiveResolution(controller, url));
        initializedFired = true;
        maybeSetReady();
        _setBuffering(index, false);
        if (index == _activeIndexNotifier.value) _onActiveBufferingEndOrPlay();
        _syncPlayingNotifierFromController(index);
        if (!_firstReelMetricLogged &&
            index == _activeIndexNotifier.value &&
            boundTicket == _activationTicket) {
          _firstReelMetricLogged = true;
          ReelsPerfMetrics.instance.onFirstReelVisible();
        }
      }
      if (ev.betterPlayerEventType == BetterPlayerEventType.exception) {
        _completeReadyFuture(index);
        ReelsLogger.error('CONTROLLER_EXCEPTION index=$index ticket=$boundTicket');
        // Do not dispose — log only
      }
      if (ev.betterPlayerEventType == BetterPlayerEventType.play) {
        playFired = true;
        maybeSetReady();
        _setPlaying(index, true);
        if (index == _activeIndexNotifier.value) _onActiveBufferingEndOrPlay();
      } else if (ev.betterPlayerEventType == BetterPlayerEventType.pause ||
          ev.betterPlayerEventType == BetterPlayerEventType.finished) {
        _setPlaying(index, false);
      } else if (ev.betterPlayerEventType == BetterPlayerEventType.bufferingEnd) {
        _setBuffering(index, false);
        if (index == _activeIndexNotifier.value) _onActiveBufferingEndOrPlay();
      }
    }

    _reelEventListeners[controller] = listener;
    controller.addEventsListener(listener);

    if (controller.isVideoInitialized() == true && controller.isPlaying() == true) {
      initializedFired = true;
      playFired = true;
      maybeSetReady();
    }
  }

  void _syncReelVideoAspectRatio(BetterPlayerController controller) {
    // Reels: always [BoxFit.cover] in the slot [_ReelPlayerCover] gives us; no
    // letterboxing band — many vertical clips are stored as landscape pixels.
    try {
      final vpc = controller.videoPlayerController;
      if (vpc == null || !vpc.value.initialized) return;
      final s = vpc.value.size;
      if (s == null || s.width <= 0 || s.height <= 0) return;
      controller.setOverriddenAspectRatio(s.width / s.height);
      controller.setOverriddenFit(BoxFit.cover);
    } catch (_) {}
  }

  Map<String, String>? _reelThumbHeaders() {
    final auth = DioClient.instance.options.headers['Authorization'];
    if (auth == null) return null;
    final s = auth.toString();
    if (s.isEmpty) return null;
    return {'Authorization': s};
  }

  String _reelPlayUrl(PostModel reel) =>
      reel.videoMasterUrl ?? reel.videoUrl ?? '';

  Future<void> _activateInitialReelIfNeeded() async {
    if (!mounted) return;
    // Invalidate any pending settle timer so tab-return / init does not race stale swipes.
    _settleEpoch++;
    final tabIndex = ref.read(mainTabIndexProvider);
    final isPushedRoute = widget.prependedReel != null || widget.initialPostId != null;
    if (tabIndex != _kReelsTabIndex && !isPushedRoute) return;

    final engine = ref.read(globalVideoEngineProvider.notifier);
    var st = ref.read(globalVideoEngineProvider);
    if (st.activeFeature != VideoEngineFeature.reels) {
      await engine.activateFeature(VideoEngineFeature.reels);
      if (!mounted) return;
      st = ref.read(globalVideoEngineProvider);
    }

    final reels = _effectiveReelsList();
    if (reels.isEmpty) return;
    final index = _activeIndexNotifier.value.clamp(0, reels.length - 1);
    final reel = reels[index];
    final url = _reelPlayUrl(reel);
    if (url.isEmpty) {
      _setReady(index, false);
      _setPlaying(index, false);
      _controllerMapVersion.value++;
      return;
    }

    final ticket = ++_activationTicket;
    VideoEngineLogger.engine('REELS_INITIAL_ACTIVATE index=$index ticket=$ticket');

    final activeSlot = st.activeSlot;
    if (activeSlot != null &&
        activeSlot.id == reel.id &&
        activeSlot.url == url &&
        st.activeFeature == VideoEngineFeature.reels) {
      try {
        await ref.read(globalVideoEngineProvider.notifier).resumeActive();
      } catch (_) {}
      if (!mounted || !context.mounted || ticket != _activationTicket) return;
      if (_pendingPageIndex != index || _activeIndexNotifier.value != index) {
        return;
      }
      await _applyReelEnginePlayResult(
        index: index,
        reel: reel,
        url: url,
        ticket: ticket,
        controller: activeSlot.controller,
      );
      return;
    }

    final parked = _standbySlot;
    if (parked != null && parked.id == reel.id && parked.url == url) {
      _standbySlot = null;
      ref.read(globalVideoEngineProvider.notifier).acceptReturnedController(
            id: parked.id,
            url: parked.url,
            controller: parked.controller,
          );
      try {
        await parked.controller.setVolume(1.0);
        await parked.controller.play();
      } catch (_) {}
      if (!mounted || !context.mounted || ticket != _activationTicket) return;
      if (_pendingPageIndex != index || _activeIndexNotifier.value != index) {
        return;
      }
      await _applyReelEnginePlayResult(
        index: index,
        reel: reel,
        url: url,
        ticket: ticket,
        controller: parked.controller,
      );
      return;
    }

    final prepended = widget.prependedReel;
    if (prepended != null && prepended.id == reel.id) {
      final handoff = ref.read(homeFeedReelHandoffIdProvider);
      final active = st.activeSlot;
      if (handoff == reel.id &&
          active != null &&
          active.id == reel.id) {
        final controller = active.controller;
        try {
          await controller.setVolume(1.0);
          await controller.play();
        } catch (_) {}
        if (!mounted || !context.mounted || ticket != _activationTicket) return;
        if (_pendingPageIndex != index || _activeIndexNotifier.value != index) {
          return;
        }
        await _applyReelEnginePlayResult(
          index: index,
          reel: reel,
          url: url,
          ticket: ticket,
          controller: controller,
        );
        return;
      }
    }

    _resetActiveThumbnailOverlay();
    final controller = await _activateReelWithPool(
      index: index,
      reel: reel,
      url: url,
      ticket: ticket,
    );
    if (!mounted || !context.mounted || ticket != _activationTicket) return;
    if (_pendingPageIndex != index || _activeIndexNotifier.value != index) {
      return;
    }

    await _applyReelEnginePlayResult(
      index: index,
      reel: reel,
      url: url,
      ticket: ticket,
      controller: controller,
    );
  }

  Future<void> _applyReelEnginePlayResult({
    required int index,
    required PostModel reel,
    required String url,
    required int ticket,
    required BetterPlayerController? controller,
  }) async {
    if (!mounted || !context.mounted) return;
    if (ticket != _activationTicket) return;
    if (_pendingPageIndex != index || _activeIndexNotifier.value != index) {
      return;
    }

    if (controller == null) {
      _setReady(index, false);
      _setPlaying(index, false);
      _controllerMapVersion.value++;
      return;
    }

    _bindReelPlayerEvents(controller, url, index, ticket);
    _setPlaying(index, controller.isPlaying() == true);
    if (_isViewportActive) {
      try {
        await controller.setVolume(1.0);
        await controller.play();
        _setPlaying(index, true);
      } catch (_) {}
    }
    if (index == _activeIndexNotifier.value) {
      unawaited(_applyReelAdaptiveResolution(controller, url));
      _startProgressTracking(controller);
    }
    unawaited(
      ref.read(postViewCountOverridesProvider.notifier).recordAndUpdate(
            reel.id,
            fallback: reel.displayViews,
          ),
    );
    _controllerMapVersion.value++;
  }

  Future<void> _runSettledReelActivation() async {
    if (!mounted || !context.mounted) return;
    final reels = _effectiveReelsList();
    final idx = _currentIndex;
    if (idx < 0 || idx >= reels.length) return;

    final engine = ref.read(globalVideoEngineProvider.notifier);
    if (ref.read(globalVideoEngineProvider).activeFeature != VideoEngineFeature.reels) {
      await engine.activateFeature(VideoEngineFeature.reels);
      if (!mounted) return;
    }

    if (_currentIndex != idx) return;

    final reel = reels[idx];
    final url = _reelPlayUrl(reel);
    if (url.isEmpty) return;

    final ticket = ++_activationTicket;
    _resetActiveThumbnailOverlay();

    VideoEngineLogger.engine(
      'REELS_SETTLED_ACTIVATE index=$idx ticket=$ticket id=${reel.id}',
    );
    final controller = await _activateReelWithPool(
      index: idx,
      reel: reel,
      url: url,
      ticket: ticket,
    );

    if (!mounted || ticket != _activationTicket) return;
    if (_currentIndex != idx) return;

    await _applyReelEnginePlayResult(
      index: idx,
      reel: reel,
      url: url,
      ticket: ticket,
      controller: controller,
    );
  }

  void _precacheAdjacentThumbnails(int index, List<PostModel> reels) {
    if (!mounted || !context.mounted) return;
    final headers = _reelThumbHeaders();
    for (var i = index - 1; i <= index + 2; i++) {
      if (i < 0 || i >= reels.length) continue;
      final thumb = reels[i].effectiveThumbnailUrl ?? reels[i].thumbnailUrl;
      if (thumb == null || thumb.trim().isEmpty) continue;
      unawaited(
        precacheImage(
          CachedNetworkImageProvider(
            thumb.trim(),
            cacheManager: AppMediaCache.reelsThumbnails,
            headers: headers,
          ),
          context,
        ).catchError((Object _, StackTrace __) {}),
      );
    }
  }

  void _onReelPageChanged(int index) {
    final reels = _effectiveReelsList();
    if (index < 0 || index >= reels.length) return;
    if (index == _pendingPageIndex) return;

    _stopProgressTracking();
    _reelSettleTimer?.cancel();
    _pendingPageIndex = index;
    if (_activeIndexNotifier.value != index) {
      _activeIndexNotifier.value = index;
    }

    _precacheAdjacentThumbnails(index, reels);

    unawaited(ref.read(globalVideoEngineProvider.notifier).pauseActive());

    _resetActiveThumbnailOverlay();

    final epochAtSchedule = ++_settleEpoch;

    _reelSettleTimer = Timer(const Duration(milliseconds: 150), () {
      _reelSettleTimer = null;
      if (!mounted) return;
      if (_settleEpoch != epochAtSchedule) return;
      _currentIndex = _pendingPageIndex;
      unawaited(_runSettledReelActivation());
    });
  }

  void _clampCurrentIndexIfNeeded() {
    if (!mounted || !context.mounted) return;
    final reels = _effectiveReelsList();
    if (reels.isEmpty) return;
    if (_currentIndex < reels.length) return;
    final n = reels.length - 1;
    _cancelPendingPlayerAttach();
    setState(() {
      _currentIndex = n;
      _pendingPageIndex = n;
    });
    if (_pageController.hasClients) {
      _pageController.jumpToPage(n);
    }
    unawaited(_activateInitialReelIfNeeded());
  }

  @override
  Widget build(BuildContext context) {
    final reelsFromProvider = ref.watch(reelsListProvider);
    final isLoading = ref.watch(reelsLoadingProvider);
    final error = ref.watch(reelsErrorProvider);
    final prependedReel = widget.prependedReel;
    final initialPostId = widget.initialPostId;

    final reels = prependedReel != null
        ? [prependedReel, ...reelsFromProvider.where((r) => r.id != prependedReel.id)]
        : reelsFromProvider;
    final blocked = ref.watch(blockedUserIdsProvider);
    final visibleReels = blocked.isEmpty
        ? reels
        : reels.where((r) => !blocked.contains(r.author.id)).toList();

    final isPushedRoute = prependedReel != null || initialPostId != null;

    if (reels.isNotEmpty && !_hasAppliedInitialPostId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !context.mounted) return;
        _hasAppliedInitialPostId = true;
        if (prependedReel == null && initialPostId == null) return;
        int targetIndex = 0;
        if (prependedReel != null) {
          targetIndex = 0;
        } else if (initialPostId != null) {
          final idx = visibleReels.indexWhere((r) => r.id == initialPostId);
          if (idx >= 0) targetIndex = idx;
        }
        if (_pageController.hasClients && targetIndex < visibleReels.length) {
          setState(() {
            _currentIndex = targetIndex;
            _pendingPageIndex = targetIndex;
          });
          if (_activeIndexNotifier.value != targetIndex) {
            _activeIndexNotifier.value = targetIndex;
          }
          _pageController.jumpToPage(targetIndex);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !context.mounted) return;
            unawaited(_activateInitialReelIfNeeded());
          });
        }
      });
    }

    if (visibleReels.isNotEmpty && _currentIndex >= visibleReels.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !context.mounted) return;
        _clampCurrentIndexIfNeeded();
      });
    }

    if (error != null && visibleReels.isEmpty && !isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        extendBody: true,
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
    final reelsTabVisible = tabIndex == _kReelsTabIndex || isPushedRoute;
    final routeIsCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    final viewportActive = reelsTabVisible && routeIsCurrent;
    _isViewportActive = viewportActive;
    final shouldMutePause = !viewportActive &&
        ref.read(globalVideoEngineProvider).activeSlot != null;
    if (viewportActive) {
      // Reset so we can schedule again the next time we become inactive.
      _mutePauseRequestedWhileInactive = false;
      if (!_wasViewportActive) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_isViewportActive) return;
          unawaited(_activateInitialReelIfNeeded());
        });
      }
    }
    _wasViewportActive = viewportActive;
    if (viewportActive && _warmSlotsDisposedWhileInactive) {
      _warmSlotsDisposedWhileInactive = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_isViewportActive) return;
        final reels = _effectiveReelsList();
        final idx = _activeIndexNotifier.value;
        if (idx < 0 || idx >= reels.length) return;

        final active = ref.read(globalVideoEngineProvider).activeSlot;
        final reel = reels[idx];
        final url = _reelPlayUrl(reel);
        if (active == null || active.id != reel.id || url.isEmpty) return;

        unawaited(
          _refreshWarmControllersFor(
            activeIndex: idx,
            ticket: _activationTicket,
          ),
        );
      });
    }
    if (shouldMutePause && !_mutePauseRequestedWhileInactive) {
      _mutePauseRequestedWhileInactive = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_isViewportActive) return;
        unawaited(_muteAndPauseAllPlayers());
        final tab = ref.read(mainTabIndexProvider);
        if (tab == kLongVideosTabIndex) {
          unawaited(_parkOneReelStandby());
        } else {
          unawaited(_disposeWarmControllers(markInactive: true));
        }
      });
    }

    final pageStack = DefaultTextStyle(
      style: const TextStyle(decoration: TextDecoration.none),
      child: RefreshIndicator(
        onRefresh: () => ref.read(reelsProvider.notifier).refresh(),
        color: Colors.white,
        backgroundColor: Colors.black54,
        // RefreshIndicator + PageView: give an explicit viewport size so each
        // page fills the tab area (avoids a short viewport and a black band
        // above the bottom nav even though MainScreen already reserved it).
        child: Consumer(
          builder: (context, ref, _) {
            final activeEngineSlotId = ref.watch(
              globalVideoEngineProvider.select((s) => s.activeSlot?.id),
            );
            final activeEngineController = ref.watch(
              globalVideoEngineProvider
                  .select((s) => s.activeSlot?.controller),
            );
            return LayoutBuilder(
              builder: (context, constraints) {
                return SizedBox(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (_) => false,
                    child: PageView.builder(
                      controller: _pageController,
                      scrollDirection: Axis.vertical,
                      onPageChanged: _onReelPageChanged,
                      itemCount: visibleReels.length,
                      physics: const _ReelPageScrollPhysics(),
                      itemBuilder: (context, index) {
                        if (index < 0 || index >= visibleReels.length) {
                          return Container(color: Colors.black);
                        }
                        return KeyedSubtree(
                          key: ValueKey<int>(index),
                          child: _buildReelItem(
                            visibleReels[index],
                            index,
                            activeEngineSlotId: activeEngineSlotId,
                            activeEngineController: activeEngineController,
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );

    final bodyChild = (visibleReels.isEmpty && isLoading)
        ? _reelFullBleedSkeleton(context)
        : (visibleReels.isEmpty
            ? Center(
                child: Text(
                  'No reels yet',
                  style: TextStyle(color: ThemeHelper.getTextSecondary(context), fontSize: 16, decoration: TextDecoration.none),
                ),
              )
            : pageStack);

    final content = Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: SizedBox.expand(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: KeyedSubtree(
            key: ValueKey(
              visibleReels.isEmpty && isLoading
                  ? 'reel_skeleton'
                  : reels.isEmpty
                      ? 'reel_empty'
                      : 'reel_feed',
            ),
            child: bodyChild,
          ),
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
    final cached = _blurHashCache[h];
    if (cached != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(cached, fit: BoxFit.cover),
          gradient,
        ],
      );
    }
    _decodeBlurHashAsync(h);
    return gradient;
  }

  void _decodeBlurHashAsync(String hash) {
    if (_blurHashCache.containsKey(hash)) return;
    if (_blurHashDecodeInFlight.contains(hash)) return;
    _blurHashDecodeInFlight.add(hash);
    unawaited(compute(_decodeBlurHashIsolate, hash).then((bytes) {
      _blurHashDecodeInFlight.remove(hash);
      if (!mounted || bytes == null || bytes.isEmpty) return;
      if (_blurHashCache.containsKey(hash)) return;
      _blurHashCache[hash] = bytes;
      // Trigger poster rebuild via controllerMapVersion instead of setState
      if (mounted) _controllerMapVersion.value++;
    }).catchError((_) {
      _blurHashDecodeInFlight.remove(hash);
    }));
  }

  static Uint8List? _decodeBlurHashIsolate(String hash) {
    try {
      final decoded = bh.BlurHash.decode(hash);
      final im = decoded.toImage(32, 32);
      return Uint8List.fromList(img.encodeJpg(im, quality: 60));
    } catch (_) {
      return null;
    }
  }

  Widget _reelPosterStack(PostModel reel, Uint8List? localThumb) {
    final apiThumb = reel.thumbnailUrl?.trim();
    final fallbackThumb = reel.effectiveThumbnailUrl?.trim();
    final effectiveThumb =
        (apiThumb != null && apiThumb.isNotEmpty) ? apiThumb : fallbackThumb;
    final hasLocal = localThumb != null && localThumb.isNotEmpty;
    final headers = _reelThumbHeaders();
    final showShimmer = !hasLocal && (effectiveThumb == null || effectiveThumb.isEmpty);

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(child: Container(color: Colors.black)),
        Positioned.fill(child: _reelBlurUnderlay(reel)),
        if (effectiveThumb != null && effectiveThumb.isNotEmpty)
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl: effectiveThumb,
              cacheManager: AppMediaCache.reelsThumbnails,
              fit: BoxFit.cover,
              httpHeaders: headers,
              fadeInDuration: Duration.zero,
              fadeOutDuration: Duration.zero,
              placeholderFadeInDuration: Duration.zero,
              placeholder: (context, url) => const ColoredBox(color: Colors.black),
              errorWidget: (_, __, ___) => const ColoredBox(color: Colors.black),
            ),
          ),
        if (hasLocal)
          Positioned.fill(
            child: Image.memory(localThumb, fit: BoxFit.cover, gaplessPlayback: true),
          ),
        if (showShimmer)
          const Positioned.fill(
            child: ColoredBox(color: Colors.black),
          ),
      ],
    );
  }


  Widget _buildReelItem(
    PostModel reel,
    int index, {
    required String? activeEngineSlotId,
    required BetterPlayerController? activeEngineController,
  }) {
    final vUrl = reel.videoUrl;
    final localThumb = (vUrl != null && vUrl.isNotEmpty) ? _localVideoThumbs[vUrl] : null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _handleSingleTap(index),
      onDoubleTapDown: (details) => _lastDoubleTapLocal = details.localPosition,
      onDoubleTap: () => _handleDoubleTap(reel, index, _lastDoubleTapLocal),
      child: Stack(
        fit: StackFit.expand,
        children: [
        // ─── Video layer (or poster while video is loading) ───────────────────
        // FIX: Both branches must be Positioned.fill so they each occupy the
        // full screen. The RepaintBoundary was missing Positioned.fill, which
        // caused BetterPlayer to size itself from its own intrinsic dimensions
        // (i.e. the overridden aspect-ratio box) instead of filling the screen.
        Positioned.fill(
          child: ValueListenableBuilder<int>(
            valueListenable: _activeIndexNotifier,
            builder: (_, activeIndex, __) {
              final isCurrent = index == activeIndex;
              if (isCurrent) {
                final controller = reel.id == activeEngineSlotId
                    ? activeEngineController
                    : null;
                return ValueListenableBuilder<int>(
                  valueListenable: _controllerMapVersion,
                  builder: (_, ___, ____) {
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        Positioned.fill(
                            child: _reelPosterStack(reel, localThumb)),
                        if (controller != null)
                          ValueListenableBuilder<bool>(
                            valueListenable: _readyNotifierFor(index),
                            builder: (_, ready, __) {
                              return AnimatedOpacity(
                                duration: const Duration(milliseconds: 300),
                                opacity: ready ? 1.0 : 0.0,
                                child: RepaintBoundary(
                                  key: ValueKey<String>('reel_slot_$index'),
                                  child:
                                      _ReelPlayerCover(controller: controller),
                                ),
                              );
                            },
                          ),
                      ],
                    );
                  },
                );
              }
              return _reelPosterStack(reel, localThumb);
            },
          ),
        ),

        Positioned(
          
          top: 78,
          right: 8,
          child:   GestureDetector(
                      onTap: () => _showReelMoreMenu(context, reel),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                       
                        child: const Icon(
                          Icons.more_vert,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    )
        ),

        // ─── Overlay UI ───────────────────────────────────────────────────────
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
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              5,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Left side — author info and caption
                
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      ProfileScreen(user: reel.author),
                                ),
                              );
                            },
                            child: CircleAvatar(
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
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        ProfileScreen(user: reel.author),
                                  ),
                                );
                              },
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
                          ),
                          // Follow button — hidden when viewing own reel
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
                              final overrideStatus = followOverrides[reel.author.id];
                              final isFollowing =
                                  overrideStatus == FollowRelationshipStatus.following ||
                                      (overrideStatus == null &&
                                          (followState.followingIds.isNotEmpty
                                              ? followState.followingIds.contains(reel.author.id)
                                              : (post?.author.isFollowing ?? reel.author.isFollowing)));
                              final isPending =
                                  overrideStatus == FollowRelationshipStatus.pending ||
                                      (overrideStatus == null &&
                                          followState.outgoingPendingRequests.containsKey(reel.author.id));
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
                                    isFollowing ? 'Following' : (isPending ? 'Requested' : 'Follow'),
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
                      // Audio row — tappable to browse reels with same audio
                      if (reel.audioName != null || reel.isVideo)
                        GestureDetector(
                          onTap: () {
                            _cancelPendingPlayerAttach();
                            unawaited(_releaseAllVideoResources());
                            if (mounted) setState(() {});
                            final audioId = reel.audioId ?? 'original_${reel.author.id}';
                            final audioName = reel.audioName ?? 'Original sound - ${reel.author.username}';
                            final reelsList = ref.read(reelsListProvider);
                            final sameAudioReels = reelsList
                                .where((r) => (r.audioId ?? 'original_${r.author.id}') == audioId)
                                .toList();
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
                              if (mounted) {
                                unawaited(_activateInitialReelIfNeeded());
                              }
                            });
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.music_note_rounded, color: Colors.white, size: 18),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  reel.audioName ?? 'Original sound - ${reel.author.username}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
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
                // Right side — action buttons
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
                              child: const Icon(
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
                    Consumer(
                      builder: (context, ref, _) {
                        final isSaved =
                            ref.watch(isPostSavedProvider(reel.id));
                        return _buildActionButton(
                          icon: isSaved ? Icons.star : Icons.star_border,
                          onTap: () {
                            ref
                                .read(savedPostsProvider.notifier)
                                .toggleSave(reel.id);
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    ValueListenableBuilder<bool>(
                      valueListenable: _playingNotifierFor(index),
                      builder: (_, isPlaying, __) {
                        return _buildActionButton(
                          icon: isPlaying ? Icons.pause : Icons.play_arrow,
                          onTap: () {
                            final controller =
                                _engineControllerForReelIndex(index);
                            if (controller != null) {
                              if (isPlaying) {
                                unawaited(_safePause(controller));
                                _setPlaying(index, false);
                              } else {
                                unawaited(() async {
                                  await _safeSetVolume(controller, 1.0);
                                  await _safePlay(controller);
                                  _setPlaying(index, true);
                                }());
                              }
                            }
                          },
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: ValueListenableBuilder<int>(
              valueListenable: _activeIndexNotifier,
              builder: (_, active, __) {
                if (active != index) return const SizedBox.shrink();
                return AnimatedBuilder(
                  animation: _progressAnimation,
                  builder: (_, __) => LinearProgressIndicator(
                    value: _progressAnimation.value,
                    minHeight: 2,
                    backgroundColor: Colors.white24,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                );
              },
            ),
          ),
        ),
        ],
      ),
    );
  }

  void _handleSingleTap(int index) {
    final c = _engineControllerForReelIndex(index);
    if (c == null) return;
    final isPlaying = c.isPlaying() == true;
    if (isPlaying) {
      unawaited(_safePause(c));
      _setPlaying(index, false);
    } else {
      unawaited(() async {
        await _safeSetVolume(c, 1.0);
        await _safePlay(c);
        _setPlaying(index, true);
      }());
    }
  }

  void _handleDoubleTap(PostModel reel, int index, Offset localPosition) {
    final isLiked = ref.read(reelLikedProvider(reel.id));
    if (!isLiked) {
      ref.read(reelsProvider.notifier).toggleLikeWithApi(reel.id);
    }
    _showHeartBurst(localPosition);
    final c = _engineControllerForReelIndex(index);
    if (c != null && c.isPlaying() != true) {
      unawaited(() async {
        await _safeSetVolume(c, 1.0);
        await _safePlay(c);
      }());
    }
  }

  void _showHeartBurst(Offset localPosition) {
    _heartOverlay?.remove();
    _heartOverlay = null;
    final overlay = Overlay.of(context, rootOverlay: true);
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final global = renderBox.localToGlobal(localPosition);
    _heartOverlay = OverlayEntry(
      builder: (_) => _HeartBurstWidget(
        position: global,
        onDone: () {
          _heartOverlay?.remove();
          _heartOverlay = null;
        },
      ),
    );
    overlay.insert(_heartOverlay!);
  }

  Future<void> _handleBlockedUser(PostModel reel) async {
    final blockedAuthorId = reel.author.id;
    final beforeList = List<PostModel>.from(_effectiveReelsList());
    final currentIdx = beforeList.isEmpty
        ? 0
        : _currentIndex.clamp(0, beforeList.length - 1);
    final currentReelId =
        beforeList.isNotEmpty && currentIdx < beforeList.length
            ? beforeList[currentIdx].id
            : null;

    final err =
        await ref.read(blockedUserIdsProvider.notifier).blockUser(blockedAuthorId);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err)),
      );
      return;
    }

    _cancelPendingPlayerAttach();
    await _releaseAllVideoResources();

    final afterList = _effectiveReelsList();
    if (!mounted) return;

    if (afterList.isEmpty) {
      setState(() {
        _currentIndex = 0;
        _pendingPageIndex = 0;
      });
      _activeIndexNotifier.value = 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Blocked ${reel.author.username}. Their reels are hidden.',
            style: TextStyle(color: ThemeHelper.getTextPrimary(context)),
          ),
          backgroundColor:
              ThemeHelper.getSurfaceColor(context).withOpacity(0.95),
        ),
      );
      return;
    }

    int newIndex;
    if (currentReelId != null) {
      final keptIdx = afterList.indexWhere((r) => r.id == currentReelId);
      if (keptIdx >= 0) {
        newIndex = keptIdx;
      } else if (currentIdx < beforeList.length &&
          beforeList[currentIdx].author.id == blockedAuthorId) {
        newIndex = currentIdx.clamp(0, afterList.length - 1);
      } else {
        final removedBefore = beforeList
            .take(currentIdx)
            .where((r) => r.author.id == blockedAuthorId)
            .length;
        newIndex =
            (currentIdx - removedBefore).clamp(0, afterList.length - 1);
      }
    } else {
      newIndex = 0;
    }

    _currentIndex = newIndex;
    _pendingPageIndex = newIndex;
    _activeIndexNotifier.value = newIndex;

    if (_pageController.hasClients) {
      _pageController.jumpToPage(newIndex);
    }

    setState(() {});

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isViewportActive) return;
      unawaited(_activateInitialReelIfNeeded());
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Blocked ${reel.author.username}. Their reels are hidden.',
          style: TextStyle(color: ThemeHelper.getTextPrimary(context)),
        ),
        backgroundColor: ThemeHelper.getSurfaceColor(context).withOpacity(0.95),
      ),
    );
  }

  void _showReelMoreMenu(BuildContext context, PostModel reel) {
    final currentUserId = ref.read(authProvider).currentUser?.id ?? '';
    final isOwnReel =
        currentUserId.isNotEmpty && currentUserId == reel.author.id;
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            child: const Text('Report'),
            onPressed: () async {
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
          if (!isOwnReel)
            CupertinoActionSheetAction(
              child: const Text('Block User'),
              isDestructiveAction: true,
              onPressed: () async {
                Navigator.pop(context);
                await _handleBlockedUser(reel);
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
                  backgroundColor: ThemeHelper.getSurfaceColor(context).withOpacity(0.95),
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
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ReelPlayerCover
// ─────────────────────────────────────────────────────────────────────────────

/// Fills the reel **viewport** (height from [LayoutBuilder] = tab area above the
/// bottom nav). Uses **cover** scaling only — `max(w, h)` — so there is no
/// letterboxed band inside this layer (the black strip users saw was empty
/// [ColoredBox] below a `contain`-sized frame, often triggered when the decoder
/// reports landscape pixels for a vertical clip). Cropping prefers sides for
/// wide clips; pixels are never stretched.
///
/// [SafeBetterPlayerWrapper] stays [AnimatedBuilder.child]; [_syncReelVideoAspectRatio]
/// sets the real aspect ratio + [BoxFit.cover] on BetterPlayer to match.
class _ReelPlayerCover extends StatefulWidget {
  const _ReelPlayerCover({required this.controller});

  final BetterPlayerController controller;

  @override
  State<_ReelPlayerCover> createState() => _ReelPlayerCoverState();
}

class _ReelPlayerCoverState extends State<_ReelPlayerCover> {
  Size? _videoSize;
  dynamic _listenedVpc;

  @override
  void initState() {
    super.initState();
    _attachListeners();
  }

  @override
  void didUpdateWidget(covariant _ReelPlayerCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _detachListeners(oldWidget.controller);
      _videoSize = null;
      _attachListeners();
    }
  }

  void _attachListeners() {
    widget.controller.addEventsListener(_onControllerEvent);
    final vpc = widget.controller.videoPlayerController;
    if (vpc != null) {
      _listenedVpc = vpc;
      vpc.addListener(_onVideoValueChanged);
      _checkAndStoreSize(vpc.value.size);
    }
  }

  void _detachListeners(BetterPlayerController controller) {
    try {
      (_listenedVpc as dynamic)?.removeListener(_onVideoValueChanged);
    } catch (_) {}
    _listenedVpc = null;
    try {
      controller.removeEventsListener(_onControllerEvent);
    } catch (_) {}
  }

  void _onControllerEvent(BetterPlayerEvent event) {
    if (event.betterPlayerEventType != BetterPlayerEventType.initialized) return;
    final vpc = widget.controller.videoPlayerController;
    if (vpc != null && !identical(_listenedVpc, vpc)) {
      try {
        _listenedVpc?.removeListener(_onVideoValueChanged);
      } catch (_) {}
      _listenedVpc = vpc;
      vpc.addListener(_onVideoValueChanged);
    }
    _checkAndStoreSize(vpc?.value.size);
  }

  void _onVideoValueChanged() {
    final vpc = _listenedVpc;
    if (vpc == null) return;
    _checkAndStoreSize(vpc.value.size);
  }

  void _checkAndStoreSize(Size? size) {
    if (size == null || size.width <= 0 || size.height <= 0) return;
    if (_videoSize == size) return;
    if (!mounted) return;
    // Use the real decoder-provided dimensions to lock aspect ratio. This
    // prevents the "initialized fired before size known" portrait fallback.
    try {
      widget.controller.setOverriddenAspectRatio(size.width / size.height);
      widget.controller.setOverriddenFit(BoxFit.cover);
    } catch (_) {}
    setState(() {
      _videoSize = size;
    });
  }

  @override
  void dispose() {
    _detachListeners(widget.controller);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = SafeBetterPlayerWrapper(
      key: ObjectKey(widget.controller),
      controller: widget.controller,
    );

    return ColoredBox(
      color: Colors.black,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final screenW = constraints.maxWidth;
          final screenH = constraints.maxHeight;
          final size = _videoSize;
          if (size == null) {
            return SizedBox.expand(child: player);
          }
          final scale = math.max(screenW / size.width, screenH / size.height);
          return ClipRect(
            child: SizedBox(
              width: screenW,
              height: screenH,
              child: Center(
                child: SizedBox(
                  width: size.width * scale,
                  height: size.height * scale,
                  child: player,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

enum _ReelWarmNeighbor { previous, next }

class _ReelWarmSlot {
  final String id;
  final String url;
  final BetterPlayerController controller;

  const _ReelWarmSlot({
    required this.id,
    required this.url,
    required this.controller,
  });
}

class _ReelPromotionResult {
  final BetterPlayerController controller;
  final BetterPlayerController? reusableController;

  const _ReelPromotionResult({
    required this.controller,
    this.reusableController,
  });
}

class _HeartBurstWidget extends StatefulWidget {
  const _HeartBurstWidget({
    required this.position,
    required this.onDone,
  });

  final Offset position;
  final VoidCallback onDone;

  @override
  State<_HeartBurstWidget> createState() => _HeartBurstWidgetState();
}

class _HeartBurstWidgetState extends State<_HeartBurstWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scale = Tween<double>(begin: 0.3, end: 1.4).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _opacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
      ),
    );
    _controller.forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.position.dx - 50,
      top: widget.position.dy - 50,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, __) => Opacity(
            opacity: _opacity.value,
            child: Transform.scale(
              scale: _scale.value,
              child: const Icon(
                Icons.favorite,
                color: Colors.white,
                size: 100,
                shadows: [Shadow(color: Colors.black38, blurRadius: 20)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ReelPageScrollPhysics
// ─────────────────────────────────────────────────────────────────────────────

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