import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/providers/video_player_provider.dart';
import '../../core/models/post_model.dart';
import '../profile/profile_screen.dart';

/// Reel-style fullscreen viewer for home page videos
class HomeReelsViewerScreen extends ConsumerStatefulWidget {
  final List<PostModel> videos;
  final int initialIndex;

  const HomeReelsViewerScreen({
    super.key,
    required this.videos,
    required this.initialIndex,
  });

  @override
  ConsumerState<HomeReelsViewerScreen> createState() => _HomeReelsViewerScreenState();
}

class _HomeReelsViewerScreenState extends ConsumerState<HomeReelsViewerScreen> {
  late PageController _pageController;
  int _currentIndex = 0;
  final Map<String, bool> _likedPosts = {};
  final Map<String, int> _likeCounts = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    
    // Initialize like states
    for (var video in widget.videos) {
      _likedPosts[video.id] = video.isLiked;
      _likeCounts[video.id] = video.likes;
    }
    
    // Start playing initial video
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playCurrentVideo();
    });
  }

  @override
  void dispose() {
    // Pause all videos before disposing
    _pauseAllVideos();
    _pageController.dispose();
    super.dispose();
  }

  void _pauseAllVideos() {
    for (var video in widget.videos) {
      if (video.videoUrl != null) {
        try {
          final notifier = ref.read(videoPlayerProvider(video.videoUrl!).notifier);
          notifier.pause();
        } catch (e) {
          // Ignore errors
        }
      }
    }
  }

  void _playCurrentVideo() {
    if (_currentIndex < 0 || _currentIndex >= widget.videos.length) return;
    
    final currentVideo = widget.videos[_currentIndex];
    if (currentVideo.videoUrl != null) {
      try {
        final notifier = ref.read(videoPlayerProvider(currentVideo.videoUrl!).notifier);
        notifier.play();
      } catch (e) {
        // Ignore errors
      }
    }
    
    // Pause other videos
    for (int i = 0; i < widget.videos.length; i++) {
      if (i != _currentIndex && widget.videos[i].videoUrl != null) {
        try {
          final notifier = ref.read(videoPlayerProvider(widget.videos[i].videoUrl!).notifier);
          notifier.pause();
        } catch (e) {
          // Ignore errors
        }
      }
    }
  }

  void _onPageChanged(int index) {
    if (index < 0 || index >= widget.videos.length) return;
    
    setState(() {
      _currentIndex = index;
    });
    
    _playCurrentVideo();
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.videos.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (didPop) {
          // Pause all videos when popping - smooth back navigation
          _pauseAllVideos();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            onPageChanged: _onPageChanged,
            itemCount: widget.videos.length,
            physics: const ClampingScrollPhysics(),
            itemBuilder: (context, index) {
              if (index < 0 || index >= widget.videos.length) {
                return Container(color: Colors.black);
              }
              return _buildReelItem(widget.videos[index], index);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildReelItem(PostModel video, int index) {
    final videoUrl = video.videoUrl;
    final playerState = videoUrl != null 
        ? ref.watch(videoPlayerProvider(videoUrl))
        : null;
    final isInitialized = playerState?.isInitialized ?? false;
    final isPlaying = playerState?.isPlaying ?? false;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Video player
        if (videoUrl != null && isInitialized && playerState?.controller != null)
          Container(
            color: Colors.black,
            child: Center(
              child: AspectRatio(
                aspectRatio: playerState!.controller!.value.aspectRatio,
                child: VideoPlayer(playerState.controller!),
              ),
            ),
          )
        else
          Container(
            color: Colors.black,
            child: Stack(
              children: [
                // Show thumbnail
                if (video.thumbnailUrl != null)
                  Center(
                    child: CachedNetworkImage(
                      imageUrl: video.thumbnailUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                // Loading overlay
                Container(
                  color: Colors.black.withValues(alpha: 0.5),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Back button with smooth animation
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      // Pause videos before navigating back
                      _pauseAllVideos();
                      Navigator.of(context).pop();
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Bottom overlay with actions
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
                      count: _likeCounts[video.id] ?? video.likes,
                      isActive: _likedPosts[video.id] ?? video.isLiked,
                      onTap: () {
                        setState(() {
                          final currentLiked = _likedPosts[video.id] ?? video.isLiked;
                          final currentCount = _likeCounts[video.id] ?? video.likes;
                          _likedPosts[video.id] = !currentLiked;
                          _likeCounts[video.id] = currentLiked 
                              ? (currentCount - 1).clamp(0, double.infinity).toInt()
                              : currentCount + 1;
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildActionButton(
                      icon: Icons.comment_outlined,
                      count: video.comments,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Comments feature coming soon!'),
                            backgroundColor: Colors.black.withValues(alpha: 0.9),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildActionButton(
                      icon: Icons.share_outlined,
                      count: video.shares,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Share feature coming soon!'),
                            backgroundColor: Colors.black.withValues(alpha: 0.9),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildActionButton(
                      icon: isPlaying ? Icons.pause : Icons.play_arrow,
                      onTap: () {
                        if (videoUrl != null) {
                          final notifier = ref.read(videoPlayerProvider(videoUrl).notifier);
                          notifier.togglePlayPause();
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
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                        child: Row(
                          children: [
                            ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: video.author.avatarUrl,
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  width: 40,
                                  height: 40,
                                  color: Colors.grey[800],
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  width: 40,
                                  height: 40,
                                  color: Colors.grey[800],
                                  child: const Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              video.author.displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        video.caption,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(widget.videos.length, (idx) {
              return Container(
                width: 3,
                height: 40,
                decoration: BoxDecoration(
                  color: idx == _currentIndex
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
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
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: isActive ? Colors.red : Colors.white,
              size: 24,
            ),
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
}

