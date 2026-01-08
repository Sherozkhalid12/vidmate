import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/services/mock_data_service.dart';
import '../../core/models/story_model.dart';
import '../../core/models/user_model.dart';
import 'package:video_player/video_player.dart';

/// Vertical stories viewer (like reels) - swipe vertically between users
/// Horizontal swipe within each user's multiple stories
class StoriesViewerScreen extends StatefulWidget {
  final int initialUserIndex;
  final int initialStoryIndex;

  const StoriesViewerScreen({
    super.key,
    this.initialUserIndex = 0,
    this.initialStoryIndex = 0,
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

  @override
  void initState() {
    super.initState();
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
    final allStories = MockDataService.getMockStories();
    _userStoriesMap = {};
    _users = [];

    // Group stories by user
    for (var story in allStories) {
      if (!_userStoriesMap.containsKey(story.author.id)) {
        _userStoriesMap[story.author.id] = [];
        _users.add(story.author);
      }
      _userStoriesMap[story.author.id]!.add(story);
    }

    // Initialize current story index for each user
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
      _initializeVideo(userHash, storyIndex, story.mediaUrl);
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

  void _initializeVideo(int userHash, int storyIndex, String videoUrl) {
    final errorKey = '${userHash}_$storyIndex';
    
    // If this story already has an error, skip initialization
    if (_videoErrors[errorKey] == true) {
      return;
    }
    
    if (_videoControllers[userHash]?.containsKey(storyIndex) ?? false) {
      return; // Already initialized
    }

    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl))
        ..setLooping(false);

      _videoControllers[userHash] ??= {};
      _videoControllers[userHash]![storyIndex] = controller;

      controller.initialize().then((_) {
        if (mounted) {
          // Clear error if initialization succeeds
          _videoErrors.remove(errorKey);
          
          final currentUser = _users[_currentUserIndex];
          if (userHash == currentUser.id.hashCode &&
              _currentStoryIndex[userHash] == storyIndex) {
            try {
              controller.play();
            } catch (e) {
              // Silently handle play error
              _handleVideoError(userHash, storyIndex);
            }
          }
          // Mark as loaded on success
          setState(() {
            _storyLoaded[userHash] = true;
          });
        }
      }).catchError((error) {
        // Handle video initialization error gracefully - suppress repeated errors
        if (mounted && _videoErrors[errorKey] != true) {
          _handleVideoError(userHash, storyIndex);
        }
      });
    } catch (e) {
      // Handle controller creation error
      if (mounted && _videoErrors[errorKey] != true) {
        _handleVideoError(userHash, storyIndex);
      }
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
    
    // Cancel previous progress timer
    _progressTimer?.cancel();
    _progressTimer = null;
    
    final user = _users[userIndex];
    final userHash = user.id.hashCode;
    final previousStoryIdx = _currentStoryIndex[userHash] ?? 0;
    
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
              return Container(
                color: Colors.black,
                child: Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                  ),
                ),
              );
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
                            color: Colors.black.withOpacity(0.5),
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

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: story.isVideo
          ? (hasVideoError || videoController == null)
              ? _buildVideoErrorFallback(story)
              : _buildVideoStory(videoController, isCurrentStory, isLoaded)
          : _buildImageStory(story, isLoaded),
    );
  }

  Widget _buildVideoStory(VideoPlayerController controller, bool isCurrentStory, bool isLoaded) {
    if (!isLoaded || !controller.value.isInitialized) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading video...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

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
              'Skipping to next story...',
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
        CachedNetworkImage(
          imageUrl: story.mediaUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          placeholder: (context, url) => Container(
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
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
                    'Failed to load',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
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

