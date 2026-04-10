import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:better_player/better_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/providers/auth_provider_riverpod.dart';
import '../../core/providers/follow_provider_riverpod.dart';
import '../../core/providers/posts_provider_riverpod.dart';
import '../../core/providers/reels_provider_riverpod.dart';
import '../../core/providers/video_player_provider.dart';
import '../../core/models/post_model.dart';
import '../../core/utils/theme_helper.dart';
import '../profile/profile_screen.dart';
import '../../core/widgets/safe_better_player.dart';

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

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    // Seed provider with incoming reels so counts are synced everywhere.
    ref.read(reelsProvider.notifier).seedReels(widget.videos);
    
    // Start playing initial video
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playCurrentVideo();
    });
  }

  @override
  void dispose() {
    // Do not use ref in dispose() — it is invalid once the widget is torn down.
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
          // Ignore
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
        if (videoUrl != null && isInitialized && playerState?.hasValidController == true && playerState?.controller != null)
          Container(
            color: Colors.black,
            child: Center(
              child: AspectRatio(
                aspectRatio: playerState!.controller!.getAspectRatio() ?? 1.0,
                child: SafeBetterPlayerWrapper(controller: playerState.controller!),
              ),
            ),
          )
        else
          Container(
            color: Colors.black,
            child: Stack(
              children: [
                // Show thumbnail
                if (video.thumbnailUrl != null && video.thumbnailUrl!.isNotEmpty)
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
                        count: ref.watch(reelLikeCountProvider(video.id)),
                        isActive: ref.watch(reelLikedProvider(video.id)),
                        onTap: () {
                          ref.read(reelsProvider.notifier).toggleLikeWithApi(video.id);
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
                      Row(
                        children: [
                          // Follow button - hide when author is current user
                          if (ref.watch(currentUserProvider)?.id != video.author.id)
                            Consumer(
                              builder: (context, ref, _) {
                                final followState = ref.watch(followProvider);
                                final overrideStatus =
                                    ref.watch(followStateProvider)[video.author.id];
                                final isFollowing =
                                    overrideStatus == FollowRelationshipStatus.following ||
                                        (overrideStatus == null &&
                                            (followState.followingIds.isNotEmpty
                                                ? followState.followingIds
                                                    .contains(video.author.id)
                                                : video.author.isFollowing));
                                return GestureDetector(
                                  onTap: () => ref.read(followProvider.notifier).toggleFollow(video.author.id),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isFollowing ? Colors.transparent : Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: isFollowing ? Border.all(color: Colors.white70, width: 1.5) : null,
                                    ),
                                    child: Text(
                                      isFollowing ? 'Following' : 'Follow',
                                      style: TextStyle(
                                        color: isFollowing ? Colors.white : Colors.black,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          if (ref.watch(currentUserProvider)?.id != video.author.id) const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProfileScreen(user: video.author),
                                ),
                              );
                            },
                            child: CircleAvatar(
                              radius: 20,
                              backgroundImage: CachedNetworkImageProvider(video.author.avatarUrl),
                              backgroundColor: Colors.grey[800],
                              onBackgroundImageError: (exception, stackTrace) {
                                // Error will show backgroundColor
                              },
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
}
