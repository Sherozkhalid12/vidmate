import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/media/app_media_cache.dart';
import '../../core/models/story_model.dart';
import '../../core/models/user_model.dart';
import '../../core/perf/stories_perf_metrics.dart';
import '../../core/services/mock_data_service.dart';
import '../../core/utils/theme_helper.dart';
import '../../services/reels/reel_video_prefetch.dart';

/// Vertical stories viewer (like reels) - swipe vertically between users
/// Horizontal swipe within each user's multiple stories
class StoriesViewerScreen extends StatefulWidget {
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
  State<StoriesViewerScreen> createState() => _StoriesViewerScreenState();
}

class _StoriesViewerScreenState extends State<StoriesViewerScreen> {
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

  @override
  void initState() {
    super.initState();
    _viewerOpenStopwatch = Stopwatch()..start();
    _metricsUserIndex = widget.initialUserIndex;
    _initializeStories();
    _currentUserIndex = widget.initialUserIndex;
    _userPageController = PageController(initialPage: widget.initialUserIndex);
    _storyPageControllers = {};
    _initializeStoryController(_currentUserIndex);
    _startStoryProgress(_currentUserIndex, widget.initialStoryIndex);
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _userPageController.dispose();
    for (var controller in _storyPageControllers.values) {
      controller.dispose();
    }
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
    _storyLoaded[userHash] = false;

    // Initialize video if needed
    if (story.isVideo) {
      unawaited(_initializeVideo(userHash, storyIndex, story.mediaUrl));
    } else {
      // For images, mark as loaded after a short delay
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _storyLoaded[userHash] = true;
          });
        }
      });
    }

    // Reset progress
    setState(() {
      _storyProgress[userHash] = 0.0;
    });

    // Wait for content to load and PageView to be ready
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      
      // Verify controller is ready
      final storyController = _storyPageControllers[userHash];
      if (storyController != null && !storyController.hasClients) {
        // Retry after more time
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && storyController.hasClients && _storyLoaded[userHash] != false) {
            _animateProgress(userHash, userIndex, storyIndex);
          }
        });
        return;
      }

      // Start progress only if content is loaded
      if (_storyLoaded[userHash] != false) {
        _animateProgress(userHash, userIndex, storyIndex);
      } else {
        // Wait a bit more for content to load
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _animateProgress(userHash, userIndex, storyIndex);
          }
        });
      }
    });

    _warmNextRelativeTo(userIndex, storyIndex);
  }

  void _animateProgress(int userHash, int userIndex, int storyIndex) {
    if (!mounted) return;
    
    // Cancel any existing timer
    _progressTimer?.cancel();
    
    // Animate progress from 0 to 1 over 8 seconds (slower, more professional)
    const totalDuration = Duration(seconds: 8);
    const updateInterval = Duration(milliseconds: 50);
    final totalSteps = totalDuration.inMilliseconds ~/ updateInterval.inMilliseconds;
    
    int step = 0;
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
    
    // Cancel any progress timer
    _progressTimer?.cancel();
    _progressTimer = null;
    
    final user = _users[userIndex];
    final userHash = user.id.hashCode;
    final stories = _userStoriesMap[user.id] ?? [];
    final currentStoryIdx = _currentStoryIndex[userHash] ?? 0;

    // Pause current video
    _pauseCurrentVideo(userHash, currentStoryIdx);

    if (currentStoryIdx < stories.length - 1) {
      // Next story in same user
      final nextStoryIdx = currentStoryIdx + 1;
      final storyController = _storyPageControllers[userHash];
      if (storyController != null && storyController.hasClients) {
        storyController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        _startStoryProgress(userIndex, nextStoryIdx);
      }
    } else {
      // Move to next user
      if (userIndex < _users.length - 1) {
        if (_userPageController.hasClients) {
          _userPageController.nextPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      } else {
        // Last story of last user - close viewer immediately
        _closeViewer();
      }
    }
  }

  void _closeViewer() {
    if (!mounted) return;
    
    // Cancel any timers
    _progressTimer?.cancel();
    _progressTimer = null;
    
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

    // Pause current video
    _pauseCurrentVideo(userHash, currentStoryIdx);

    if (currentStoryIdx > 0) {
      // Previous story in same user
      final prevStoryIdx = currentStoryIdx - 1;
      final storyController = _storyPageControllers[userHash];
      if (storyController != null && storyController.hasClients) {
        storyController.previousPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        _startStoryProgress(userIndex, prevStoryIdx);
      }
      } else {
        // Move to previous user
        if (userIndex > 0) {
          if (_userPageController.hasClients) {
            _userPageController.previousPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
        } else {
          // First story of first user - close viewer
          _closeViewer();
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
    
    setState(() {
      _currentUserIndex = index;
    });
    _initializeStoryController(index);
    final user = _users[index];
    final userHash = user.id.hashCode;
    final storyIndex = _currentStoryIndex[userHash] ?? 0;
    
    // Reset progress, loading state, and errors
    setState(() {
      _storyProgress[userHash] = 0.0;
      _storyLoaded[userHash] = false;
      // Clear errors for this user's stories
      _videoErrors.removeWhere((key, _) => key.startsWith('${userHash}_'));
    });
    
    // Wait for PageView to be built before starting progress
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _startStoryProgress(index, storyIndex);
      }
    });
  }

  void _onStoryPageChanged(int userIndex, int storyIndex) {
    if (userIndex < 0 || userIndex >= _users.length) return;

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

    // Cancel previous progress timer
    _progressTimer?.cancel();
    _progressTimer = null;
    
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
    
    // Update current story index
    _currentStoryIndex[userHash] = storyIndex;
    
    // Reset progress, loading state, and errors
    setState(() {
      _storyProgress[userHash] = 0.0;
      _storyLoaded[userHash] = false;
      // Clear errors for this user's stories
      _videoErrors.removeWhere((key, _) => key.startsWith('${userHash}_'));
    });
    
    // Start progress for new story
    _startStoryProgress(userIndex, storyIndex);
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
                              if (index == currentStoryIdx)
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 100),
                                  width: MediaQuery.of(context).size.width *
                                      (_storyProgress[userHash] ?? 0.0) /
                                      stories.length,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(2),
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
                      CircleAvatar(
                        radius: 20,
                        backgroundImage: CachedNetworkImageProvider(user.avatarUrl),
                        backgroundColor: Colors.grey,
                        onBackgroundImageError: (exception, stackTrace) {
                          // Error will show backgroundColor
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

  Widget _buildStoryContent(StoryModel story, int userHash, int storyIndex) {
    final isCurrentStory = _currentStoryIndex[userHash] == storyIndex;
    final videoController = _videoControllers[userHash]?[storyIndex];
    final isLoaded = _storyLoaded[userHash] ?? false;
    final errorKey = '${userHash}_$storyIndex';
    final hasVideoError = _videoErrors[errorKey] ?? false;
    final hasTags = story.locations.isNotEmpty || story.taggedUsers.isNotEmpty;

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
              : _buildImageStory(story, isLoaded),
          if (hasTags)
            Positioned(
              bottom: 24,
              left: 12,
              right: 12,
              child: _buildStoryChips(story),
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

    return Container(
      color: Colors.black,
      child: Center(
        child: AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: VideoPlayer(controller),
        ),
      ),
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

  Widget _buildImageStory(StoryModel story, bool isLoaded) {
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
            : CachedNetworkImage(
                imageUrl: story.mediaUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                cacheManager: AppMediaCache.feedMedia,
                fadeInDuration: const Duration(milliseconds: 200),
                imageBuilder: (context, imageProvider) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _logFirstFrameOnce();
                  });
                  return Image(
                    image: imageProvider,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  );
                },
                placeholder: (context, url) => _fullBleedMediaPlaceholder(context),
                errorWidget: (context, url, error) => Container(
                  color: Colors.black,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image_not_supported_outlined,
                          color: Colors.white.withValues(alpha: 0.75),
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.offline ? 'Unavailable offline' : 'Failed to load',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
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
