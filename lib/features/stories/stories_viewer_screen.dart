import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart' show LoopMode;
import 'package:video_player/video_player.dart';

import '../../core/audio/attached_music_preview.dart';
import '../../core/providers/auth_provider_riverpod.dart';
import '../../core/providers/stories_provider_riverpod.dart';
import '../../core/media/app_media_cache.dart';
import '../../core/models/story_model.dart';
import '../../core/models/user_model.dart';
import '../../core/perf/stories_perf_metrics.dart';
import '../../core/services/mock_data_service.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/widgets/music_sticker_row.dart';
import '../../services/reels/reel_video_prefetch.dart';
import '../../services/stories/story_audio_preloader.dart';
import '../../core/widgets/natural_aspect_image.dart';
import 'story_viewers_sheet.dart';

/// Vertical stories viewer (like reels) - swipe vertically between users
/// Horizontal swipe within each user's multiple stories
class StoriesViewerScreen extends ConsumerStatefulWidget {
  final int initialUserIndex;
  final int initialStoryIndex;
  /// Pre-loaded from API; when null, falls back to mock data.
  final List<UserModel>? users;
  final Map<String, List<StoryModel>>? userStoriesMap;

  /// When true, video/story media loads only from disk cache where possible.
  final bool offline;

  const StoriesViewerScreen({
    super.key,
    this.initialUserIndex = 0,
    this.initialStoryIndex = 0,
    this.users,
    this.userStoriesMap,
    this.offline = false,
  });

  @override
  ConsumerState<StoriesViewerScreen> createState() => _StoriesViewerScreenState();
}

class _StoriesViewerScreenState extends ConsumerState<StoriesViewerScreen>
    with WidgetsBindingObserver {
  late PageController _userPageController;
  late Map<int, PageController> _storyPageControllers;
  late Map<String, List<StoryModel>> _userStoriesMap;
  late List<UserModel> _users;
  int _currentUserIndex = 0;
  Map<int, int> _currentStoryIndex = {}; // Track current story index for each user
  Map<int, double> _storyProgress = {}; // Track progress for each user's current story
  Map<int, Map<int, VideoPlayerController>> _videoControllers = {}; // Video controllers by user and story index
  Timer? _progressTimer; // Timer for progress animation
  Map<int, bool> _storyLoaded = {}; // Track if story is loaded
  Map<String, bool> _videoErrors = {}; // Track video loading errors by "userHash_storyIndex"
  final Set<String> _preloadReadyKeys = {};
  late final Stopwatch _viewerOpenStopwatch;
  bool _firstFrameLogged = false;
  int? _metricsUserIndex;
  int _storyMusicGeneration = 0;
  String? _activeStoryMusicUrl;
  bool _pausedForViewsSheet = false;
  int _storyTransitionGeneration = 0;

  String _preloadKey(int userHash, int storyIndex) => '${userHash}_$storyIndex';

  void _logFirstFrameOnce() {
    if (_firstFrameLogged) return;
    _firstFrameLogged = true;
    StoriesPerfMetrics.logStoryFirstFrameMs(_viewerOpenStopwatch.elapsedMilliseconds);
  }

  Widget _fullBleedMediaPlaceholder(BuildContext context) {
    final accent = ThemeHelper.getAccentColor(context);
    final surface = ThemeHelper.getSurfaceColor(context);
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.22),
            const Color(0xFF0D0D0D),
            surface.withValues(alpha: 0.5),
          ],
        ),
      ),
    );
  }

  void _recordPreloadForStory(int userHash, int storyIndex) {
    if (!mounted) return;
    setState(() {
      _preloadReadyKeys.add(_preloadKey(userHash, storyIndex));
    });
  }

  void _warmStoryMedia(int userHash, int storyIndex, StoryModel story) {
    if (story.mediaUrl.isEmpty) return;
    final key = _preloadKey(userHash, storyIndex);
    if (_preloadReadyKeys.contains(key)) return;

    if (story.isVideo) {
      unawaited(_initializeVideo(userHash, storyIndex, story.mediaUrl, forPreloadOnly: true));
    } else {
      final provider = CachedNetworkImageProvider(
        story.mediaUrl,
        cacheManager: AppMediaCache.feedMedia,
      );
      // precacheImage reads MediaQuery from context; cannot run during initState.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_preloadReadyKeys.contains(key)) return;
        precacheImage(provider, context)
            .then((_) {
              if (mounted) _recordPreloadForStory(userHash, storyIndex);
            })
            .catchError((_) {});
      });
    }
  }

  void _warmNextRelativeTo(int userIndex, int storyIndex) {
    if (userIndex < 0 || userIndex >= _users.length) return;
    final user = _users[userIndex];
    final stories = _userStoriesMap[user.id] ?? [];
    final nextIdx = storyIndex + 1;
    if (nextIdx < stories.length) {
      _warmStoryMedia(user.id.hashCode, nextIdx, stories[nextIdx]);
    } else if (userIndex + 1 < _users.length) {
      final nu = _users[userIndex + 1];
      final ns = _userStoriesMap[nu.id] ?? [];
      if (ns.isNotEmpty) {
        _warmStoryMedia(nu.id.hashCode, 0, ns.first);
      }
    }
  }

  void _prewarmNeighborStoryAudio(int userIndex, int storyIndex) {
    if (userIndex < 0 || userIndex >= _users.length) return;
    final user = _users[userIndex];
    final stories = _userStoriesMap[user.id] ?? [];

    final nextStoryIndex = storyIndex + 1;
    if (nextStoryIndex < stories.length) {
      final nextUrl = stories[nextStoryIndex].storyMusicPlaybackUrl;
      if (nextUrl.isNotEmpty) {
        unawaited(StoryAudioPreloader.instance.prewarmSingle(nextUrl));
      }
    }

    final previousStoryIndex = storyIndex - 1;
    if (previousStoryIndex >= 0) {
      final previousUrl = stories[previousStoryIndex].storyMusicPlaybackUrl;
      if (previousUrl.isNotEmpty) {
        unawaited(StoryAudioPreloader.instance.prewarmSingle(previousUrl));
      }
    }

    final nextUserIndex = userIndex + 1;
    if (nextUserIndex < _users.length) {
      final nextUser = _users[nextUserIndex];
      final nextUserStories = _userStoriesMap[nextUser.id] ?? [];
      if (nextUserStories.isNotEmpty) {
        final firstUrl = nextUserStories.first.storyMusicPlaybackUrl;
        if (firstUrl.isNotEmpty) {
          unawaited(StoryAudioPreloader.instance.prewarmSingle(firstUrl));
        }
      }
    }

    final previousUserIndex = userIndex - 1;
    if (previousUserIndex >= 0) {
      final previousUser = _users[previousUserIndex];
      final previousUserStories = _userStoriesMap[previousUser.id] ?? [];
      if (previousUserStories.isNotEmpty) {
        final firstUrl = previousUserStories.first.storyMusicPlaybackUrl;
        if (firstUrl.isNotEmpty) {
          unawaited(StoryAudioPreloader.instance.prewarmSingle(firstUrl));
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _viewerOpenStopwatch = Stopwatch()..start();
    _metricsUserIndex = widget.initialUserIndex;
    _initializeStories();
    _currentUserIndex = widget.initialUserIndex;
    _userPageController = PageController(initialPage: widget.initialUserIndex);
    _storyPageControllers = {};
    _initializeStoryController(_currentUserIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_transitionToStory(
        userIndex: widget.initialUserIndex,
        storyIndex: widget.initialStoryIndex,
        markPreviousComplete: false,
      ));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _progressTimer?.cancel();
    _userPageController.dispose();
    for (var controller in _storyPageControllers.values) {
      controller.dispose();
    }
    unawaited(AttachedMusicPreview.instance.stop());
    unawaited(_disposeStorySegmentAudio());
    for (var userControllers in _videoControllers.values) {
      for (var controller in userControllers.values) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  void _initializeStories() {
    if (widget.users != null && widget.userStoriesMap != null) {
      _users = List.from(widget.users!);
      _userStoriesMap = Map.from(widget.userStoriesMap!);
    } else {
      final allStories = MockDataService.getMockStories();
      _userStoriesMap = {};
      _users = [];
      for (var story in allStories) {
        if (!_userStoriesMap.containsKey(story.author.id)) {
          _userStoriesMap[story.author.id] = [];
          _users.add(story.author);
        }
        _userStoriesMap[story.author.id]!.add(story);
      }
    }

    for (var user in _users) {
      _currentStoryIndex[user.id.hashCode] = 0;
      _storyProgress[user.id.hashCode] = 0.0;
    }
  }

  void _initializeStoryController(int userIndex) {
    if (userIndex < 0 || userIndex >= _users.length) return;
    final user = _users[userIndex];
    final userHash = user.id.hashCode;

    if (!_storyPageControllers.containsKey(userHash)) {
      final initialStoryIndex = _currentStoryIndex[userHash] ?? 0;
      _storyPageControllers[userHash] = PageController(
        initialPage: initialStoryIndex,
      );
    }
  }

  void _startStoryProgress(int userIndex, int storyIndex) {
    if (userIndex < 0 || userIndex >= _users.length) return;
    final user = _users[userIndex];
    final userHash = user.id.hashCode;
    final stories = _userStoriesMap[user.id] ?? [];

    if (storyIndex < 0 || storyIndex >= stories.length) return;

    // Cancel previous timer
    _progressTimer?.cancel();
    _progressTimer = null;

    final story = stories[storyIndex];
    _currentStoryIndex[userHash] = storyIndex;

    // Initialize video if needed
    if (story.isVideo) {
      unawaited(_initializeVideo(userHash, storyIndex, story.mediaUrl));
    }

    // Reset progress — timer starts only after media is displayed
    setState(() {
      _storyProgress[userHash] = 0.0;
      _storyLoaded[userHash] = false;
    });

    _warmNextRelativeTo(userIndex, storyIndex);
    _prewarmNeighborStoryAudio(userIndex, storyIndex);
  }

  Future<void> _disposeStorySegmentAudio() async {
    final url = _activeStoryMusicUrl;
    _activeStoryMusicUrl = null;
    if (url == null || url.isEmpty) return;
    await StoryAudioPreloader.instance.stopAndRewind(url);
  }

  Duration _resolveStoryDisplayDuration(
    StoryModel story,
    int userHash,
    int storyIndex,
  ) {
    if (story.storyMusicPlaybackUrl.isNotEmpty) {
      return const Duration(seconds: 20);
    }
    if (story.isVideo) {
      final c = _videoControllers[userHash]?[storyIndex];
      if (c != null &&
          c.value.isInitialized &&
          c.value.duration > Duration.zero) {
        return c.value.duration;
      }
      return const Duration(seconds: 10);
    }
    return const Duration(seconds: 5);
  }

  void _startProgressIfStillActive({
    required int userHash,
    required int userIndex,
    required int storyIndex,
  }) {
    if (!mounted) return;
    if (_currentUserIndex != userIndex) return;
    if (_currentStoryIndex[userHash] != storyIndex) return;
    if (_storyLoaded[userHash] != true) return;
    if (_progressTimer != null) return;
    _animateProgress(userHash, userIndex, storyIndex);

    final stories = _userStoriesMap[_users[userIndex].id] ?? [];
    if (storyIndex >= 0 && storyIndex < stories.length) {
      final gen = ++_storyMusicGeneration;
      unawaited(_scheduleStoryMusic(
        story: stories[storyIndex],
        generation: gen,
        userHash: userHash,
        storyIndex: storyIndex,
      ));
    }
  }

  Future<void> _scheduleStoryMusic({
    required StoryModel story,
    required int generation,
    required int userHash,
    required int storyIndex,
  }) async {
    if (!mounted || generation != _storyMusicGeneration) return;
    if (_currentUserIndex < 0 || _currentUserIndex >= _users.length) return;
    final activeUserHash = _users[_currentUserIndex].id.hashCode;
    if (activeUserHash != userHash) return;
    if (_currentStoryIndex[userHash] != storyIndex) return;

    final url = story.storyMusicPlaybackUrl;
    await AttachedMusicPreview.instance.stop();

    if (url.isEmpty) {
      await _disposeStorySegmentAudio();
      return;
    }

    await _disposeStorySegmentAudio();

    final player = await StoryAudioPreloader.instance.getPlayer(url);
    if (player == null) return;
    _activeStoryMusicUrl = url;
    try {
      await player.setVolume(1);
      await player.setLoopMode(LoopMode.one);
      await player.play();
    } catch (_) {
      await _disposeStorySegmentAudio();
    }
  }

  void _animateProgress(int userHash, int userIndex, int storyIndex) {
    if (!mounted) return;

    // Cancel any existing timer
    _progressTimer?.cancel();

    if (userIndex < 0 || userIndex >= _users.length) return;
    final uid = _users[userIndex].id;
    final stories = _userStoriesMap[uid] ?? [];
    if (storyIndex < 0 || storyIndex >= stories.length) return;
    final story = stories[storyIndex];

    final totalDuration =
        _resolveStoryDisplayDuration(story, userHash, storyIndex);
    const updateInterval = Duration(milliseconds: 50);
    final rawSteps =
        totalDuration.inMilliseconds ~/ updateInterval.inMilliseconds;
    final totalSteps = rawSteps < 1 ? 1 : rawSteps;
    
    final initialProgress = (_storyProgress[userHash] ?? 0.0).clamp(0.0, 1.0);
    int step = (initialProgress * totalSteps).round();
    _progressTimer = Timer.periodic(updateInterval, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      step++;
      final progress = (step / totalSteps).clamp(0.0, 1.0);
      setState(() {
        _storyProgress[userHash] = progress;
      });
      
      if (step >= totalSteps) {
        timer.cancel();
        _progressTimer = null;
        
        // Check if this is the last story before advancing
        final user = _users[userIndex];
        final userHash = user.id.hashCode;
        final stories = _userStoriesMap[user.id] ?? [];
        final currentStoryIdx = _currentStoryIndex[userHash] ?? 0;
        final isLastStory = currentStoryIdx >= stories.length - 1;
        final isLastUser = userIndex >= _users.length - 1;
        
        // Auto-advance after animation completes
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            if (isLastStory && isLastUser) {
              // Last story of last user - close immediately
              _closeViewer();
            } else {
              _nextStory(userIndex);
            }
          }
        });
      }
    });
  }

  Future<void> _initializeVideo(
    int userHash,
    int storyIndex,
    String videoUrl, {
    bool forPreloadOnly = false,
  }) async {
    final errorKey = '${userHash}_$storyIndex';

    if (_videoErrors[errorKey] == true) return;

    if (_videoControllers[userHash]?.containsKey(storyIndex) ?? false) {
      if (forPreloadOnly) {
        final c0 = _videoControllers[userHash]![storyIndex]!;
        if (c0.value.isInitialized) _recordPreloadForStory(userHash, storyIndex);
        return;
      }
      final existing = _videoControllers[userHash]![storyIndex]!;
      if (existing.value.isInitialized) {
        _videoErrors.remove(errorKey);
        final currentUser = _users[_currentUserIndex];
        if (userHash == currentUser.id.hashCode &&
            _currentStoryIndex[userHash] == storyIndex) {
          try {
            await existing.play();
          } catch (_) {
            _handleVideoError(userHash, storyIndex);
            return;
          }
        }
        if (mounted) {
          setState(() => _storyLoaded[userHash] = true);
          final activeUserIndex =
              _users.indexWhere((u) => u.id.hashCode == userHash);
          if (activeUserIndex >= 0) {
            _startProgressIfStillActive(
              userHash: userHash,
              userIndex: activeUserIndex,
              storyIndex: storyIndex,
            );
          }
        }
        return;
      }
      try {
        await existing.initialize();
      } catch (_) {
        if (mounted && _videoErrors[errorKey] != true) {
          _handleVideoError(userHash, storyIndex);
        }
        return;
      }
      if (!mounted) return;
      _videoErrors.remove(errorKey);
      final currentUser = _users[_currentUserIndex];
      if (userHash == currentUser.id.hashCode &&
          _currentStoryIndex[userHash] == storyIndex) {
        try {
          await existing.play();
        } catch (_) {
          _handleVideoError(userHash, storyIndex);
          return;
        }
      }
      setState(() => _storyLoaded[userHash] = true);
      final activeUserIndex = _users.indexWhere((u) => u.id.hashCode == userHash);
      if (activeUserIndex >= 0) {
        _startProgressIfStillActive(
          userHash: userHash,
          userIndex: activeUserIndex,
          storyIndex: storyIndex,
        );
      }
      return;
    }

    if (videoUrl.isEmpty) {
      if (!forPreloadOnly) _handleVideoError(userHash, storyIndex);
      return;
    }

    late final VideoPlayerController controller;
    try {
      final cached = await ReelVideoPrefetchService.instance.getCachedFile(videoUrl);
      if (cached != null && await cached.exists()) {
        controller = VideoPlayerController.file(cached);
      } else if (widget.offline) {
        if (!forPreloadOnly) {
          _videoErrors[errorKey] = true;
          if (mounted) {
            setState(() => _storyLoaded[userHash] = true);
          }
        }
        return;
      } else {
        controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      }
    } catch (_) {
      if (!forPreloadOnly) _handleVideoError(userHash, storyIndex);
      return;
    }

    controller.setLooping(false);
    _videoControllers[userHash] ??= {};
    _videoControllers[userHash]![storyIndex] = controller;

    try {
      await controller.initialize();
    } catch (_) {
      if (forPreloadOnly) {
        try {
          controller.dispose();
        } catch (_) {}
        _videoControllers[userHash]?.remove(storyIndex);
        return;
      }
      if (mounted && _videoErrors[errorKey] != true) {
        _handleVideoError(userHash, storyIndex);
      }
      return;
    }

    if (!mounted) return;
    _videoErrors.remove(errorKey);

    if (forPreloadOnly) {
      _recordPreloadForStory(userHash, storyIndex);
      return;
    }

    final currentUser = _users[_currentUserIndex];
    if (userHash == currentUser.id.hashCode &&
        _currentStoryIndex[userHash] == storyIndex) {
      try {
        await controller.play();
      } catch (_) {
        _handleVideoError(userHash, storyIndex);
        return;
      }
    }
    setState(() {
      _storyLoaded[userHash] = true;
    });
    final activeUserIndex = _users.indexWhere((u) => u.id.hashCode == userHash);
    if (activeUserIndex >= 0) {
      _startProgressIfStillActive(
        userHash: userHash,
        userIndex: activeUserIndex,
        storyIndex: storyIndex,
      );
    }
  }

  void _handleVideoError(int userHash, int storyIndex) {
    final errorKey = '${userHash}_$storyIndex';
    
    // Prevent duplicate error handling
    if (_videoErrors[errorKey] == true) {
      return;
    }
    
    // Mark video as error
    _videoErrors[errorKey] = true;
    
    // Dispose the failed controller
    final controller = _videoControllers[userHash]?[storyIndex];
    if (controller != null) {
      try {
        controller.dispose();
      } catch (e) {
        // Silently handle disposal error
      }
      _videoControllers[userHash]?.remove(storyIndex);
    }
    
    // Mark as loaded so progress can continue (will show error UI)
    setState(() {
      _storyLoaded[userHash] = true;
    });
    
    // Find user index
    final userIndex = _users.indexWhere((u) => u.id.hashCode == userHash);
    if (userIndex < 0) return;
    
    final stories = _userStoriesMap[_users[userIndex].id] ?? [];
    final isLastStory = storyIndex >= stories.length - 1;
    final isLastUser = userIndex >= _users.length - 1;
    
    // If it's the last story of the last user, close the viewer
    if (isLastStory && isLastUser) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _closeViewer();
        }
      });
    } else {
      // Auto-skip to next story after a short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _nextStory(userIndex);
        }
      });
    }
  }

  void _nextStory(int userIndex) {
    if (userIndex < 0 || userIndex >= _users.length) return;
    if (!mounted) return;

    final user = _users[userIndex];
    final userHash = user.id.hashCode;
    final stories = _userStoriesMap[user.id] ?? [];
    final currentStoryIdx = _currentStoryIndex[userHash] ?? 0;

    if (currentStoryIdx < stories.length - 1) {
      unawaited(_transitionToStory(
        userIndex: userIndex,
        storyIndex: currentStoryIdx + 1,
        markPreviousComplete: true,
      ));
    } else {
      if (userIndex < _users.length - 1) {
        unawaited(_transitionToStory(
          userIndex: userIndex + 1,
          storyIndex: 0,
          markPreviousComplete: true,
        ));
      } else {
        _closeViewer();
      }
    }
  }

  void _closeViewer() {
    if (!mounted) return;
    
    // Cancel any timers
    _progressTimer?.cancel();
    _progressTimer = null;
    unawaited(AttachedMusicPreview.instance.stop());
    unawaited(_disposeStorySegmentAudio());

    // Pause all videos
    for (var userControllers in _videoControllers.values) {
      for (var controller in userControllers.values) {
        try {
          if (controller.value.isPlaying) {
            controller.pause();
          }
        } catch (e) {
          // Silently handle pause errors
        }
      }
    }

    // Use post frame callback to ensure navigation happens after current frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    });
  }

  void _previousStory(int userIndex) {
    if (userIndex < 0 || userIndex >= _users.length) return;

    final user = _users[userIndex];
    final userHash = user.id.hashCode;
    final currentStoryIdx = _currentStoryIndex[userHash] ?? 0;

    if (currentStoryIdx > 0) {
      unawaited(_transitionToStory(
        userIndex: userIndex,
        storyIndex: currentStoryIdx - 1,
        markPreviousComplete: false,
      ));
    } else {
      if (userIndex > 0) {
        final previousUserStories = _userStoriesMap[_users[userIndex - 1].id] ?? [];
        final previousStoryIndex = previousUserStories.isEmpty
            ? 0
            : previousUserStories.length - 1;
        unawaited(_transitionToStory(
          userIndex: userIndex - 1,
          storyIndex: previousStoryIndex,
          markPreviousComplete: false,
        ));
      } else {
        _closeViewer();
      }
    }
  }

  Future<void> _transitionToStory({
    required int userIndex,
    required int storyIndex,
    required bool markPreviousComplete,
  }) async {
    if (!mounted) return;
    if (userIndex < 0 || userIndex >= _users.length) return;
    final targetUser = _users[userIndex];
    final targetStories = _userStoriesMap[targetUser.id] ?? [];
    if (targetStories.isEmpty) return;
    if (storyIndex < 0 || storyIndex >= targetStories.length) return;

    final previousUser = _users[_currentUserIndex];
    final previousUserIndex = _currentUserIndex;
    final isCrossUser = previousUserIndex != userIndex;
    final previousUserHash = previousUser.id.hashCode;
    final previousStoryIndex = _currentStoryIndex[previousUserHash] ?? 0;

    final transitionGen = ++_storyTransitionGeneration;
    _progressTimer?.cancel();
    _progressTimer = null;
    _pauseCurrentVideo(previousUserHash, previousStoryIndex);

    await AttachedMusicPreview.instance.stop();
    await _disposeStorySegmentAudio();
    if (!mounted || transitionGen != _storyTransitionGeneration) return;

    if (markPreviousComplete && userIndex == _currentUserIndex) {
      _storyProgress[previousUserHash] = 1.0;
    }

    setState(() {
      _currentUserIndex = userIndex;
      _currentStoryIndex[targetUser.id.hashCode] = storyIndex;
      _storyLoaded[targetUser.id.hashCode] = false;
      _storyProgress[targetUser.id.hashCode] = 0.0;
    });

    _initializeStoryController(userIndex);
    final targetUserHash = targetUser.id.hashCode;
    final storyController = _storyPageControllers[targetUserHash];
    if (storyController != null && storyController.hasClients) {
      storyController.animateToPage(
        storyIndex,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
      );
    }
    if (_userPageController.hasClients && isCrossUser) {
      _userPageController.animateToPage(
        userIndex,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }

    _warmNextRelativeTo(userIndex, storyIndex);
    _prewarmNeighborStoryAudio(userIndex, storyIndex);
    _startStoryProgress(userIndex, storyIndex);
    if (!mounted || transitionGen != _storyTransitionGeneration) return;

    final targetStory = targetStories[storyIndex];
    final parentId = targetStory.parentStoryId.isNotEmpty
        ? targetStory.parentStoryId
        : targetStory.id.split('_').first;
    unawaited(ref.read(storiesProvider.notifier).markStoryViewed(parentId));
  }

  void _pauseStoryForViewsSheet() {
    if (_pausedForViewsSheet) return;
    _pausedForViewsSheet = true;

    _progressTimer?.cancel();
    _progressTimer = null;

    if (_currentUserIndex >= 0 && _currentUserIndex < _users.length) {
      final userHash = _users[_currentUserIndex].id.hashCode;
      final storyIndex = _currentStoryIndex[userHash] ?? 0;
      _pauseCurrentVideo(userHash, storyIndex);
    }

    unawaited(StoryAudioPreloader.instance.pauseAll());
  }

  void _resumeStoryAfterViewsSheet() {
    if (!_pausedForViewsSheet) return;
    _pausedForViewsSheet = false;

    if (_currentUserIndex < 0 || _currentUserIndex >= _users.length) return;
    final userHash = _users[_currentUserIndex].id.hashCode;
    final storyIndex = _currentStoryIndex[userHash] ?? 0;
    final stories = _userStoriesMap[_users[_currentUserIndex].id] ?? [];
    if (storyIndex >= stories.length) return;

    final story = stories[storyIndex];
    if (story.isVideo) {
      final video = _videoControllers[userHash]?[storyIndex];
      if (video != null &&
          video.value.isInitialized &&
          !video.value.isPlaying) {
        unawaited(video.play());
      }
    }

    if (_activeStoryMusicUrl != null) {
      unawaited(
        StoryAudioPreloader.instance.resumePlayer(_activeStoryMusicUrl!),
      );
    }

    _startProgressIfStillActive(
      userHash: userHash,
      userIndex: _currentUserIndex,
      storyIndex: storyIndex,
    );
  }

  Future<void> _openStoryViewersSheet(StoryModel story) async {
    _pauseStoryForViewsSheet();
    await showStoryViewersSheet(context, story);
    if (mounted) _resumeStoryAfterViewsSheet();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (_users.isEmpty) return;
    if (_currentUserIndex < 0 || _currentUserIndex >= _users.length) return;
    final currentUser = _users[_currentUserIndex];
    final userHash = currentUser.id.hashCode;
    final storyIndex = _currentStoryIndex[userHash] ?? 0;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _progressTimer?.cancel();
      _progressTimer = null;
      _pauseCurrentVideo(userHash, storyIndex);
      unawaited(StoryAudioPreloader.instance.pauseAll());
      return;
    }

    if (state == AppLifecycleState.resumed) {
      final progress = (_storyProgress[userHash] ?? 0.0).clamp(0.0, 1.0);
      if (progress > 0.0 && progress < 1.0 && _progressTimer == null) {
        _animateProgress(userHash, _currentUserIndex, storyIndex);
      }
      final video = _videoControllers[userHash]?[storyIndex];
      if (video != null &&
          video.value.isInitialized &&
          !video.value.isPlaying) {
        unawaited(video.play());
      }
      if (_activeStoryMusicUrl != null) {
        unawaited(StoryAudioPreloader.instance.resumePlayer(_activeStoryMusicUrl!));
      }
    }
  }

  void _pauseCurrentVideo(int userHash, int storyIndex) {
    final controller = _videoControllers[userHash]?[storyIndex];
    if (controller != null && controller.value.isPlaying) {
      controller.pause();
    }
  }

  void _onUserPageChanged(int index) {
    if (index < 0 || index >= _users.length) return;
    if (index == _currentUserIndex) return;

    if (_metricsUserIndex != null && _metricsUserIndex != index) {
      final user = _users[index];
      final uh = user.id.hashCode;
      final si = _currentStoryIndex[uh] ?? 0;
      final key = _preloadKey(uh, si);
      if (_preloadReadyKeys.remove(key)) {
        StoriesPerfMetrics.recordPreloadHit();
      } else {
        StoriesPerfMetrics.recordPreloadMiss();
      }
    }
    _metricsUserIndex = index;

    // Cancel previous progress timer
    _progressTimer?.cancel();
    _progressTimer = null;
    
    // Pause ALL videos from previous user - YouTube/Instagram style
    final previousUser = _users[_currentUserIndex];
    final previousUserHash = previousUser.id.hashCode;
    if (_videoControllers.containsKey(previousUserHash)) {
      for (var controller in _videoControllers[previousUserHash]!.values) {
        if (controller.value.isInitialized && controller.value.isPlaying) {
          try {
            controller.pause();
            controller.seekTo(Duration.zero);
          } catch (e) {
            // Ignore pause errors
          }
        }
      }
    }
    
    final user = _users[index];
    final userHash = user.id.hashCode;
    final storyIndex = _currentStoryIndex[userHash] ?? 0;
    unawaited(_transitionToStory(
      userIndex: index,
      storyIndex: storyIndex,
      markPreviousComplete: false,
    ));
  }

  void _onStoryPageChanged(int userIndex, int storyIndex) {
    if (userIndex < 0 || userIndex >= _users.length) return;
    if (userIndex != _currentUserIndex) return;

    final user = _users[userIndex];
    final userHash = user.id.hashCode;
    final previousStoryIdx = _currentStoryIndex[userHash] ?? 0;
    if (previousStoryIdx != storyIndex) {
      final pk = _preloadKey(userHash, storyIndex);
      if (_preloadReadyKeys.remove(pk)) {
        StoriesPerfMetrics.recordPreloadHit();
      } else {
        StoriesPerfMetrics.recordPreloadMiss();
      }
    }

    if (previousStoryIdx == storyIndex && userIndex == _currentUserIndex) return;
    
    // Pause ALL videos for this user (not just previous) - YouTube/Instagram style
    if (_videoControllers.containsKey(userHash)) {
      for (var entry in _videoControllers[userHash]!.entries) {
        if (entry.key != storyIndex) {
          final controller = entry.value;
          if (controller.value.isInitialized && controller.value.isPlaying) {
            try {
              controller.pause();
              controller.seekTo(Duration.zero);
            } catch (e) {
              // Ignore pause errors
            }
          }
        }
      }
    }
    
    // Also pause previous story explicitly
    _pauseCurrentVideo(userHash, previousStoryIdx);
    
    unawaited(_transitionToStory(
      userIndex: userIndex,
      storyIndex: storyIndex,
      markPreviousComplete: storyIndex > previousStoryIdx,
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_users.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'No stories available',
            style: TextStyle(color: ThemeHelper.getTextPrimary(context)),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (details) {
          final screenWidth = MediaQuery.of(context).size.width;
          if (details.localPosition.dx < screenWidth / 2) {
            _previousStory(_currentUserIndex);
          } else {
            _nextStory(_currentUserIndex);
          }
        },
        child: PageView.builder(
          controller: _userPageController,
          scrollDirection: Axis.vertical,
          onPageChanged: _onUserPageChanged,
          itemCount: _users.length,
          physics: const ClampingScrollPhysics(),
          itemBuilder: (context, userIndex) {
            if (userIndex < 0 || userIndex >= _users.length) {
              // If somehow we get an invalid index, close the viewer
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _closeViewer();
                }
              });
              return _fullBleedMediaPlaceholder(context);
            }
            return _buildUserStories(userIndex);
          },
        ),
      ),
    );
  }

  Widget _buildUserStories(int userIndex) {
    final user = _users[userIndex];
    final userHash = user.id.hashCode;
    final stories = _userStoriesMap[user.id] ?? [];
    final currentStoryIdx = _currentStoryIndex[userHash] ?? 0;

    if (stories.isEmpty) {
      return Center(
        child: Text(
          'No stories',
          style: TextStyle(color: ThemeHelper.getTextPrimary(context)),
        ),
      );
    }

    _initializeStoryController(userIndex);

    return Stack(
      children: [
        // Stories content (horizontal scroll)
        PageView.builder(
          controller: _storyPageControllers[userHash],
          scrollDirection: Axis.horizontal,
          onPageChanged: (storyIndex) => _onStoryPageChanged(userIndex, storyIndex),
          itemCount: stories.length,
          physics: const ClampingScrollPhysics(),
          itemBuilder: (context, storyIndex) {
            if (storyIndex < 0 || storyIndex >= stories.length) {
              return Container(color: Colors.black);
            }
            return _buildStoryContent(stories[storyIndex], userHash, storyIndex);
          },
        ),
        // Top bar with progress and user info
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Column(
              children: [
                // Progress bars for current user's stories
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: List.generate(stories.length, (index) {
                      return Expanded(
                        child: Container(
                          height: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Stack(
                            children: [
                              if (index < currentStoryIdx)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                )
                              else if (index == currentStoryIdx)
                                FractionallySizedBox(
                                  widthFactor: (_storyProgress[userHash] ?? 0.0)
                                      .clamp(0.0, 1.0),
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                // User info
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Builder(
                        builder: (context) {
                          final avatarProvider = user.avatarUrl.isNotEmpty
                              ? CachedNetworkImageProvider(
                                  user.avatarUrl,
                                  cacheManager: AppMediaCache.feedMedia,
                                )
                              : null;
                          return CircleAvatar(
                            radius: 20,
                            backgroundImage: avatarProvider,
                            backgroundColor: ThemeHelper.getSurfaceColor(context),
                            child: avatarProvider == null
                                ? Icon(
                                    Icons.person,
                                    color: ThemeHelper.getTextSecondary(context),
                                    size: 22,
                                  )
                                : null,
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              _formatTime(stories[currentStoryIdx].createdAt),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Close button (X)
                      GestureDetector(
                        onTap: _closeViewer,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStoryViewsChip(StoryModel story) {
    var latest = story;
    final latestList =
        ref.read(storiesProvider).userStoriesMap[story.author.id];
    if (latestList != null) {
      for (final s in latestList) {
        if (s.id == story.id) {
          latest = s;
          break;
        }
      }
    }
    final count =
        latest.viewCount > 0 ? latest.viewCount : latest.viewers.length;

    return GestureDetector(
      onTap: () => unawaited(_openStoryViewersSheet(latest)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.visibility_outlined,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryContent(StoryModel story, int userHash, int storyIndex) {
    final isCurrentStory = _currentStoryIndex[userHash] == storyIndex;
    final videoController = _videoControllers[userHash]?[storyIndex];
    final isLoaded = _storyLoaded[userHash] ?? false;
    final errorKey = '${userHash}_$storyIndex';
    final hasVideoError = _videoErrors[errorKey] ?? false;
    final hasTags = story.locations.isNotEmpty || story.taggedUsers.isNotEmpty;
    final hasCaption = story.caption.trim().isNotEmpty;
    final hasMusicSticker = (story.musicName != null &&
            story.musicName!.trim().isNotEmpty &&
            story.musicTitle != null &&
            story.musicTitle!.trim().isNotEmpty) ||
        story.storyMusicPlaybackUrl.isNotEmpty;
    final currentUserId = ref.watch(currentUserProvider)?.id ?? '';
    final isOwnStory =
        currentUserId.isNotEmpty && currentUserId == story.author.id;
    final showViewsChip = isOwnStory && isCurrentStory;
    final bottomOverlayH = (hasCaption || hasMusicSticker || showViewsChip)
        ? MediaQuery.sizeOf(context).height * 0.2
        : 0.0;

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          story.isVideo
              ? (hasVideoError || videoController == null)
                  ? _buildVideoErrorFallback(story)
                  : _buildVideoStory(videoController, isCurrentStory, isLoaded)
              : _buildImageStory(
                  story,
                  isLoaded,
                  userHash: userHash,
                  storyIndex: storyIndex,
                ),
          if (hasTags)
            Positioned(
              bottom: bottomOverlayH > 0 ? bottomOverlayH + 8 : 24,
              left: 12,
              right: 12,
              child: _buildStoryChips(story),
            ),
          if (hasCaption || hasMusicSticker || showViewsChip)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: bottomOverlayH,
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
                  16,
                  8,
                  16,
                  12 + MediaQuery.paddingOf(context).bottom,
                ),
                alignment: Alignment.bottomLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasMusicSticker || showViewsChip)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (hasMusicSticker)
                            Expanded(
                              child: MusicStickerRow(
                                previewUrl:
                                    story.storyMusicPlaybackUrl.isNotEmpty
                                        ? story.storyMusicPlaybackUrl
                                        : null,
                                musicName: story.musicName,
                                musicTitle: story.musicTitle,
                                useMusicNoteLeadingForPreview: true,
                                textColor: Colors.white,
                                iconColor:
                                    Colors.white.withValues(alpha: 0.85),
                                playButtonColor: Colors.white,
                              ),
                            )
                          else
                            const Spacer(),
                          if (showViewsChip) ...[
                            if (hasMusicSticker) const SizedBox(width: 10),
                            _buildStoryViewsChip(story),
                          ],
                        ],
                      ),
                    if ((hasMusicSticker || showViewsChip) && hasCaption)
                      const SizedBox(height: 8),
                    if (hasCaption)
                      Text(
                        story.caption.trim(),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.left,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.6),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
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

  /// Minimal pill/chip row for locations and tagged users (matches theme, non-cluttered).
  Widget _buildStoryChips(StoryModel story) {
    final chips = <Widget>[];
    for (final loc in story.locations) {
      if (loc.isEmpty) continue;
      chips.add(
        Container(
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white24, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_on, size: 14, color: Colors.white.withValues(alpha: 0.9)),
              const SizedBox(width: 4),
              Text(
                loc,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.95),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }
    for (final user in story.taggedUsers) {
      if (user.isEmpty) continue;
      chips.add(
        Container(
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white24, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_outline, size: 14, color: Colors.white.withValues(alpha: 0.9)),
              const SizedBox(width: 4),
              Text(
                user,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.95),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: chips,
      ),
    );
  }

  Widget _buildVideoStory(VideoPlayerController controller, bool isCurrentStory, bool isLoaded) {
    if (!isLoaded || !controller.value.isInitialized) {
      return _fullBleedMediaPlaceholder(context);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && controller.value.isInitialized) _logFirstFrameOnce();
    });

    // YouTube/Instagram style: Only play current story, pause all others immediately
    if (isCurrentStory) {
      // Play current story if not playing
      if (!controller.value.isPlaying) {
        try {
          controller.play();
        } catch (e) {
          debugPrint('Error playing video: $e');
          // If play fails, show error fallback
          return _buildVideoErrorFallback(null);
        }
      }
    } else {
      // Immediately pause if not current story (critical for proper disposal)
      if (controller.value.isPlaying) {
        try {
          controller.pause();
          // Also seek to beginning for better UX when returning
          controller.seekTo(Duration.zero);
        } catch (e) {
          debugPrint('Error pausing video: $e');
        }
      }
    }

    final ar = controller.value.aspectRatio;
    if (ar <= 0) {
      return Container(color: Colors.black, child: const SizedBox.expand());
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight;
        var w = maxW;
        var h = w / ar;
        if (h > maxH) {
          h = maxH;
          w = h * ar;
        }
        return Container(
          color: Colors.black,
          alignment: Alignment.center,
          child: SizedBox(
            width: w,
            height: h,
            child: VideoPlayer(controller),
          ),
        );
      },
    );
  }

  Widget _buildVideoErrorFallback(StoryModel? story) {
    final offlineHint = widget.offline ? 'Unavailable offline' : 'Skipping to next story...';
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.videocam_off,
              color: Colors.white.withValues(alpha: 0.7),
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'Video unavailable',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              offlineHint,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageStory(
    StoryModel story,
    bool isLoaded, {
    required int userHash,
    required int storyIndex,
  }) {
    return Stack(
      children: [
        story.mediaUrl.isEmpty
            ? Container(
                color: Colors.black,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Colors.white,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.offline ? 'Unavailable offline' : 'Failed to load',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  final h = constraints.maxHeight;
                  final localPath = ref
                      .watch(storiesProvider)
                      .storyLocalMediaPaths[story.mediaUrl];
                  return SizedBox(
                    width: w,
                    height: h,
                    child: ColoredBox(
                      color: Colors.black,
                      child: Center(
                        child: StoryMediaImage(
                          imageUrl: story.mediaUrl,
                          localFilePath: localPath,
                          fit: BoxFit.contain,
                          onDisplayed: () {
                            if (!mounted) return;
                            if (_currentStoryIndex[userHash] != storyIndex) {
                              return;
                            }
                            if (_storyLoaded[userHash] == true) return;
                            setState(() {
                              _storyLoaded[userHash] = true;
                            });
                            final activeUserIndex = _users
                                .indexWhere((u) => u.id.hashCode == userHash);
                            if (activeUserIndex >= 0) {
                              _startProgressIfStillActive(
                                userHash: userHash,
                                userIndex: activeUserIndex,
                                storyIndex: storyIndex,
                              );
                            }
                            _logFirstFrameOnce();
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.3),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}
