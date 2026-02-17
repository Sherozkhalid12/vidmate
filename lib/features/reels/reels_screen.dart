import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/widgets/comments_bottom_sheet.dart';
import '../../core/widgets/share_bottom_sheet.dart';
import '../../core/providers/posts_provider_riverpod.dart';
import '../../core/models/user_model.dart';
import 'package:video_player/video_player.dart';
import '../../core/services/mock_data_service.dart';
import '../../core/models/post_model.dart';
import '../../core/utils/create_content_visibility.dart';
import 'audio_detail_screen.dart';
import 'audio_reels_screen.dart';

/// Reels screen with full-screen vertical swipe videos
class ReelsScreen extends ConsumerStatefulWidget {
  const ReelsScreen({super.key});

  @override
  ConsumerState<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends ConsumerState<ReelsScreen> {
  final PageController _pageController = PageController();
  final List<PostModel> _reels = [];
  int _currentIndex = 0;
  final Map<int, VideoPlayerController> _controllers = {};
  final Map<String, bool> _likedPosts = {}; // Track liked posts
  final Map<String, int> _likeCounts = {}; // Track like counts
  final Map<String, bool> _savedReels = {}; // Track saved/bookmarked reels

  @override
  void initState() {
    super.initState();
    _loadReels();
    createContentVisibleNotifier.addListener(_onCreateContentVisibilityChanged);
  }

  void _onCreateContentVisibilityChanged() {
    if (createContentVisibleNotifier.value) {
      _pauseAndDisposeAllVideos();
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    createContentVisibleNotifier.removeListener(_onCreateContentVisibilityChanged);
    _pageController.dispose();
    _pauseAndDisposeAllVideos();
    super.dispose();
  }

  /// Pause and dispose all reel videos (e.g. when opening AudioDetailScreen or CreateContentScreen)
  void _pauseAndDisposeAllVideos() {
    for (var entry in _controllers.entries.toList()) {
      try {
        final controller = entry.value;
        if (controller.value.isInitialized && controller.value.isPlaying) {
          controller.pause();
        }
        controller.dispose();
      } catch (_) {}
      _controllers.remove(entry.key);
    }
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
    if (_controllers.containsKey(index)) {
      // If already initialized and it's the current index, ensure it's playing
      if (index == _currentIndex && _controllers[index]!.value.isInitialized) {
        if (!_controllers[index]!.value.isPlaying) {
          try {
            _controllers[index]!.play();
          } catch (e) {
            // Ignore play errors
          }
        }
      }
      return;
    }

    final reel = _reels[index];
    if (reel.videoUrl != null) {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(reel.videoUrl!),
      )..setLooping(true);
      
      _controllers[index] = controller;
      
      // Initialize asynchronously without blocking UI
      controller.initialize().then((_) {
        if (mounted && _controllers.containsKey(index)) {
          // Only play if this is still the current index
          if (index == _currentIndex) {
            try {
              controller.play();
            } catch (e) {
              // Ignore play errors
            }
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
    
    // Pause ALL videos first (YouTube/Instagram style - only one plays at a time)
    for (var entry in _controllers.entries) {
      final controller = entry.value;
      if (controller.value.isInitialized && controller.value.isPlaying) {
        try {
          controller.pause();
        } catch (e) {
          // Ignore errors during pause
        }
      }
    }
    
    // Dispose previous video controller to free resources immediately
    if (_controllers.containsKey(_currentIndex) && _currentIndex != index) {
      try {
        final oldController = _controllers[_currentIndex];
        if (oldController != null) {
          oldController.removeListener(() {});
          if (oldController.value.isInitialized) {
            oldController.pause();
          }
          oldController.dispose();
          _controllers.remove(_currentIndex);
        }
      } catch (e) {
        // Ignore errors during disposal
      }
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
          try {
            controller.play();
          } catch (e) {
            // Ignore play errors
          }
        }
      }
    });
    
    // Preload next 2 videos for smooth scrolling (reduced from 3 to save memory)
    if (index + 1 < _reels.length) {
      _initializeVideo(index + 1);
    }
    if (index + 2 < _reels.length) {
      _initializeVideo(index + 2);
    }
    
    // Preload previous video for backward scrolling
    if (index - 1 >= 0) {
      _initializeVideo(index - 1);
    }
    
    // Dispose videos that are far away to save memory (keep only 3 videos in memory)
    final disposeThreshold = 3;
    final keysToRemove = <int>[];
    _controllers.forEach((key, controller) {
      if ((key - index).abs() > disposeThreshold) {
        try {
          controller.removeListener(() {});
          if (controller.value.isInitialized) {
            controller.pause();
          }
          controller.dispose();
          keysToRemove.add(key);
        } catch (e) {
          // Ignore errors during disposal
          keysToRemove.add(key);
        }
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
                if (reel.thumbnailUrl != null && reel.thumbnailUrl!.isNotEmpty)
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
                        // Removed "Loading..." text as per requirements
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
                            backgroundImage: CachedNetworkImageProvider(reel.author.avatarUrl),
                            backgroundColor: Colors.grey[800],
                            onBackgroundImageError: (exception, stackTrace) {
                              // Error will show backgroundColor
                            },
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
                          // Follow button - same style as instagram_post_card but fully rounded
                          Consumer(
                            builder: (context, ref, child) {
                              final posts = ref.watch(postsListProvider);
                              bool isFollowing = reel.author.isFollowing;
                              if (posts.isNotEmpty) {
                                try {
                                  final post = posts.firstWhere(
                                    (p) => p.author.id == reel.author.id,
                                  );
                                  isFollowing = post.author.isFollowing;
                                } catch (_) {
                                  // Keep reel.author.isFollowing when no matching post
                                }
                              }

                              return GestureDetector(
                                onTap: () {
                                  // Toggle follow state through provider
                                  ref.read(postsProvider.notifier).toggleFollow(reel.author.id);
                                  setState(() {
                                    // Update local reel state
                                    final updatedAuthor = UserModel(
                                      id: reel.author.id,
                                      username: reel.author.username,
                                      displayName: reel.author.displayName,
                                      avatarUrl: reel.author.avatarUrl,
                                      bio: reel.author.bio,
                                      followers: reel.author.followers,
                                      following: reel.author.following,
                                      posts: reel.author.posts,
                                      isFollowing: !reel.author.isFollowing,
                                      isOnline: reel.author.isOnline,
                                    );
                                    // Create new PostModel with updated author
                                    final updatedReel = PostModel(
                                      id: reel.id,
                                      author: updatedAuthor,
                                      imageUrl: reel.imageUrl,
                                      videoUrl: reel.videoUrl,
                                      thumbnailUrl: reel.thumbnailUrl,
                                      caption: reel.caption,
                                      createdAt: reel.createdAt,
                                      likes: reel.likes,
                                      comments: reel.comments,
                                      shares: reel.shares,
                                      isLiked: reel.isLiked,
                                      videoDuration: reel.videoDuration,
                                      isVideo: reel.isVideo,
                                    );
                                    // Update in list
                                    final index = _reels.indexWhere((r) => r.id == reel.id);
                                    if (index >= 0) {
                                      _reels[index] = updatedReel;
                                    }
                                  });
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
                                    isFollowing ? 'Following' : 'Follow',
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
                            // Pause and dispose ALL reel videos before navigating (stops audio when CreateContentScreen is opened)
                            _pauseAndDisposeAllVideos();
                            if (mounted) setState(() {});
                            final audioId = reel.audioId ?? 'original_${reel.author.id}';
                            final audioName = reel.audioName ?? 'Original sound - ${reel.author.username}';
                            final sameAudioReels = _reels.where((r) => (r.audioId ?? 'original_${r.author.id}') == audioId).toList();
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
                                _initializeVideo(_currentIndex);
                                if (_currentIndex + 1 < _reels.length) _initializeVideo(_currentIndex + 1);
                                if (_currentIndex + 2 < _reels.length) _initializeVideo(_currentIndex + 2);
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
                    const SizedBox(height: 14),
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
                    GestureDetector(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => ShareBottomSheet(
                            postId: reel.id,
                            videoUrl: reel.videoUrl,
                            imageUrl: reel.imageUrl,
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
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoActionSheetAction(
            child: const Text('Copy Link'),
            onPressed: () => Navigator.pop(context),
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
