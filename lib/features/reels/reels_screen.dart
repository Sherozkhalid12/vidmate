import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/theme_extensions.dart';
import 'package:video_player/video_player.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/mock_data_service.dart';
import '../../core/models/post_model.dart';

/// Reels screen with full-screen vertical swipe videos
class ReelsScreen extends StatefulWidget {
  const ReelsScreen({super.key});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  final PageController _pageController = PageController();
  final List<PostModel> _reels = [];
  int _currentIndex = 0;
  final Map<int, VideoPlayerController> _controllers = {};
  final Map<String, bool> _likedPosts = {}; // Track liked posts
  final Map<String, int> _likeCounts = {}; // Track like counts

  @override
  void initState() {
    super.initState();
    _loadReels();
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _loadReels() {
    final posts = MockDataService.getMockPosts();
    final videoPosts = posts.where((p) => p.isVideo).toList();
    setState(() {
      _reels.addAll(videoPosts);
      // Initialize like states
      for (var reel in videoPosts) {
        _likedPosts[reel.id] = reel.isLiked;
        _likeCounts[reel.id] = reel.likes;
      }
    });
    _initializeVideo(0);
    // Preload next videos
    if (videoPosts.length > 1) {
      _initializeVideo(1);
    }
    if (videoPosts.length > 2) {
      _initializeVideo(2);
    }
  }

  void _initializeVideo(int index) {
    if (index < 0 || index >= _reels.length) return;
    if (_controllers.containsKey(index)) return;

    final reel = _reels[index];
    if (reel.videoUrl != null) {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(reel.videoUrl!),
      )..setLooping(true);
      
      _controllers[index] = controller;
      
      // Initialize asynchronously without blocking UI
      controller.initialize().then((_) {
        if (mounted) {
          if (index == _currentIndex) {
            controller.play();
          }
          if (mounted) {
            setState(() {});
          }
        }
      }).catchError((error) {
        // Handle error silently, UI will show loading state
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  void _onPageChanged(int index) {
    if (index < 0 || index >= _reels.length) return;
    
    // Pause previous video smoothly
    if (_controllers.containsKey(_currentIndex)) {
      _controllers[_currentIndex]!.pause();
    }
    
    setState(() {
      _currentIndex = index;
    });
    
    // Play current video with smooth transition
    _initializeVideo(index);
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && _controllers.containsKey(index)) {
        final controller = _controllers[index]!;
        if (controller.value.isInitialized && !controller.value.isPlaying) {
          controller.play();
        }
      }
    });
    
    // Preload next 3 videos for ultra-smooth scrolling
    if (index + 1 < _reels.length) {
      _initializeVideo(index + 1);
    }
    if (index + 2 < _reels.length) {
      _initializeVideo(index + 2);
    }
    if (index + 3 < _reels.length) {
      _initializeVideo(index + 3);
    }
    
    // Preload previous video for backward scrolling
    if (index - 1 >= 0) {
      _initializeVideo(index - 1);
    }
    
    // Dispose videos that are far away to save memory (keep only 5 videos in memory)
    final disposeThreshold = 5;
    final keysToRemove = <int>[];
    _controllers.forEach((key, controller) {
      if ((key - index).abs() > disposeThreshold) {
        controller.dispose();
        keysToRemove.add(key);
      }
    });
    for (var key in keysToRemove) {
      _controllers.remove(key);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_reels.isEmpty) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
          ),
        ),
      );
    }

    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      onPageChanged: _onPageChanged,
      itemCount: _reels.length,
      physics: const ClampingScrollPhysics(),
      itemBuilder: (context, index) {
        if (index < 0 || index >= _reels.length) {
          return Container(color: Colors.black);
        }
        return _buildReelItem(_reels[index], index);
      },
    );
  }

  Widget _buildReelItem(PostModel reel, int index) {
    final controller = _controllers[index];
    final isPlaying = controller?.value.isPlaying ?? false;
    final isInitialized = controller?.value.isInitialized ?? false;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Video player with smooth loading
        if (controller != null && isInitialized)
          Container(
            color: Colors.black,
            child: Center(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: VideoPlayer(controller),
              ),
            ),
          )
        else
          Container(
            color: Colors.black,
            child: Stack(
              children: [
                // Show thumbnail if available
                if (reel.thumbnailUrl != null)
                  Center(
                    child: CachedNetworkImage(
                      imageUrl: reel.thumbnailUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                // Loading overlay
                Container(
                  color: Colors.black.withValues(alpha: 0.5),
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
              ],
            ),
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
                // Left side - Action buttons
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildActionButton(
                      icon: Icons.favorite,
                      count: _likeCounts[reel.id] ?? reel.likes,
                      isActive: _likedPosts[reel.id] ?? reel.isLiked,
                      onTap: () {
                        setState(() {
                          final currentLiked = _likedPosts[reel.id] ?? reel.isLiked;
                          final currentCount = _likeCounts[reel.id] ?? reel.likes;
                          
                          _likedPosts[reel.id] = !currentLiked;
                          _likeCounts[reel.id] = currentLiked 
                              ? (currentCount - 1).clamp(0, double.infinity).toInt()
                              : currentCount + 1;
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildActionButton(
                      icon: Icons.comment,
                      count: reel.comments,
                      onTap: () {
                        // Navigate to comments
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Opening comments...'),
                            backgroundColor: Theme.of(context).colorScheme.primary, // Theme-aware background
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildActionButton(
                      icon: Icons.share,
                      count: reel.shares,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Share feature coming soon'),
                            backgroundColor: Theme.of(context).colorScheme.primary, // Theme-aware background
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildActionButton(
                      icon: isPlaying ? Icons.pause : Icons.play_arrow,
                      onTap: () {
                        if (controller != null) {
                          if (isPlaying) {
                            controller.pause();
                          } else {
                            controller.play();
                          }
                          setState(() {});
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(width: 20),
                // Right side - Author info and caption
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: reel.author.avatarUrl,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                width: 40,
                                height: 40,
                                color: context.surfaceColor,
                                child: Center(
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: context.buttonColor,
                                    ),
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                width: 40,
                                height: 40,
                                color: context.surfaceColor,
                                child: Icon(
                                  Icons.person,
                                  color: context.textSecondary,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            reel.author.username,
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        reel.caption,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Progress indicator on left edge
        Positioned(
          left: 8,
          top: 0,
          bottom: 0,
          child: _buildProgressIndicator(),
        ),
      ],
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
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: context.borderColor,
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: isActive ? AppColors.warning : context.textPrimary,
              size: 24,
            ),
          ),
        ),
        if (count != null) ...[
          const SizedBox(height: 4),
          Text(
            _formatCount(count),
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProgressIndicator() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(_reels.length, (index) {
        return Container(
          width: 3,
          height: 40,
          decoration: BoxDecoration(
            color: index == _currentIndex
                ? context.buttonColor
                : context.textMuted.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
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

