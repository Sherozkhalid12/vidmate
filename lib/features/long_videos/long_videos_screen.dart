import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/models/post_model.dart';
import '../../core/providers/video_player_provider.dart';
import '../video/video_player_screen.dart';
import '../profile/profile_screen.dart';
import 'providers/long_videos_provider.dart';
import 'providers/long_video_playback_provider.dart';
import 'providers/long_video_widget_provider.dart';
import '../../core/services/mock_data_service.dart';
import 'dart:async';

/// Long Videos Page - YouTube-style video feed with Riverpod state management
class LongVideosScreen extends ConsumerStatefulWidget {
  const LongVideosScreen({super.key});

  @override
  ConsumerState<LongVideosScreen> createState() => _LongVideosScreenState();
}

class _LongVideosScreenState extends ConsumerState<LongVideosScreen> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, Timer> _controlsTimers = {};
  final Map<String, GlobalKey> _videoKeys = {}; // Track widget keys for position detection
  DateTime? _lastPlayActionTime; // Prevent rapid play/pause toggles
  Timer? _scrollThrottleTimer; // Throttle scroll events
  DateTime? _lastScrollCheck; // Last time we checked scroll position

  @override
  void initState() {
    super.initState();
    // Setup scroll listener for pagination
    _scrollController.addListener(_onScroll);
  }

  void _pauseVideoById(String videoId) {
    final videos = ref.read(longVideosListProvider);
    try {
      final video = videos.firstWhere((v) => v.id == videoId);
      if (video.videoUrl != null) {
        try {
          final key = VideoWidgetKey(video.id, video.videoUrl!);
          final notifier = ref.read(longVideoWidgetProvider(key).notifier);
          if (notifier.state.isPlaying) {
            notifier.pause();
          }
        } catch (e) {
          // Ignore errors
        }
      }
    } catch (e) {
      // Video not found, ignore
    }
  }

  /// Pause all videos except the one with the given ID
  void _pauseAllVideosExcept(String exceptVideoId) {
    final videos = ref.read(longVideosListProvider);
    
    for (var video in videos) {
      // Skip the video that should be playing
      if (video.id == exceptVideoId) continue;
      
      // Skip if no video URL
      if (video.videoUrl == null) continue;
      
      try {
        final key = VideoWidgetKey(video.id, video.videoUrl!);
        final notifier = ref.read(longVideoWidgetProvider(key).notifier);
        if (notifier.state.isPlaying) {
          notifier.pause();
        }
      } catch (e) {
        // Provider might not exist, ignore
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _scrollThrottleTimer?.cancel();
    // Cancel all timers
    for (var timer in _controlsTimers.values) {
      timer.cancel();
    }
    _controlsTimers.clear();
    _videoKeys.clear();
    
    // Pause any playing video using Riverpod state
    final playbackState = ref.read(longVideoPlaybackProvider);
    if (playbackState.currentlyPlayingVideoId != null) {
      // Find and pause the currently playing video
      final videos = ref.read(longVideosListProvider);
      final playingVideo = videos.firstWhere(
        (v) => v.id == playbackState.currentlyPlayingVideoId,
        orElse: () => videos.isNotEmpty ? videos.first : PostModel(
          id: '',
          author: MockDataService.mockUsers.first,
          caption: '',
          createdAt: DateTime.now(),
        ),
      );
      
      if (playingVideo.videoUrl != null) {
        try {
          final key = VideoWidgetKey(playingVideo.id, playingVideo.videoUrl!);
          final notifier = ref.read(longVideoWidgetProvider(key).notifier);
          notifier.pause();
        } catch (e) {
          // Ignore errors
        }
      }
      
      // Clear the currently playing video
      ref.read(longVideoPlaybackProvider.notifier).clearCurrentlyPlaying();
    }
    
    super.dispose();
  }

  void _startControlsTimer(String videoId) {
    _controlsTimers[videoId]?.cancel();
    _controlsTimers[videoId] = Timer(const Duration(seconds: 3), () {
      // Only update if widget is still mounted and video is still playing
      if (mounted) {
        try {
          final playbackState = ref.read(longVideoPlaybackProvider);
          // Only hide controls if this video is still the currently playing one
          if (playbackState.currentlyPlayingVideoId == videoId) {
            ref.read(longVideoPlaybackProvider.notifier).setControlsVisibility(videoId, false);
          }
        } catch (e) {
          // Provider might be disposed, ignore
        }
      }
    });
  }

  void _showControlsTemporarily(String videoId) {
    if (mounted) {
      ref.read(longVideoPlaybackProvider.notifier).setControlsVisibility(videoId, true);
      _startControlsTimer(videoId);
    }
  }

  void _pauseAllOtherVideos(String currentVideoId, String? currentVideoUrl) {
    if (currentVideoUrl == null) return;
    
    final videos = ref.read(longVideosListProvider);
    
    // CRITICAL: Pause ALL videos except the current one
    // Each widget has its own provider instance, so this is safe
    for (var video in videos) {
      // Skip the current video
      if (video.id == currentVideoId) continue;
      
      // Skip if no video URL
      if (video.videoUrl == null) continue;
      
      try {
        final key = VideoWidgetKey(video.id, video.videoUrl!);
        final notifier = ref.read(longVideoWidgetProvider(key).notifier);
        if (notifier.state.isPlaying) {
          notifier.pause();
        }
      } catch (e) {
        // Provider might not exist, ignore
      }
    }
  }

  void _onScroll() {
    // Throttle scroll events to improve performance
    _scrollThrottleTimer?.cancel();
    _scrollThrottleTimer = Timer(const Duration(milliseconds: 150), () {
      _handleScroll();
    });
  }

  void _handleScroll() {
    if (!mounted) return;

    // Check pagination
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      // Load more when 80% scrolled
      final notifier = ref.read(longVideosProvider.notifier);
      notifier.loadMoreVideos();
    }
    
    // Check if manually played video is still visible
    _checkManualPlayVideoVisibility();
  }

  /// Check if manually played video is still visible, if not, stop it
  /// If a video was manually played and user scrolls away, STOP it immediately
  void _checkManualPlayVideoVisibility() {
    if (!mounted) return;

    final playbackState = ref.read(longVideoPlaybackProvider);
    if (!playbackState.isManualPlay || playbackState.currentlyPlayingVideoId == null) {
      return;
    }

    final videoId = playbackState.currentlyPlayingVideoId!;
    final key = _videoKeys[videoId];
    if (key?.currentContext == null) {
      // Video widget is not in tree, stop it
      _pauseVideoById(videoId);
      ref.read(longVideoPlaybackProvider.notifier).clearCurrentlyPlaying();
      return;
    }

    try {
      final renderBox = key!.currentContext!.findRenderObject() as RenderBox?;
      if (renderBox == null || !renderBox.attached) {
        // Video is not visible, stop it
        _pauseVideoById(videoId);
        ref.read(longVideoPlaybackProvider.notifier).clearCurrentlyPlaying();
        return;
      }

      final screenHeight = MediaQuery.of(context).size.height;
      final position = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;

      // Check if video is still sufficiently visible (at least 40% on screen)
      // Use 40% threshold to stop video before it completely scrolls away
      final visibleTop = position.dy.clamp(0.0, screenHeight);
      final visibleBottom = (position.dy + size.height).clamp(0.0, screenHeight);
      final visibleHeight = visibleBottom - visibleTop;
      final visibleRatio = visibleHeight / size.height;

      if (visibleRatio < 0.4) {
        // Video scrolled out of view, STOP it immediately
        _pauseVideoById(videoId);
        ref.read(longVideoPlaybackProvider.notifier).clearCurrentlyPlaying();
        // Show controls so play icon appears when video is paused
        ref.read(longVideoPlaybackProvider.notifier).setControlsVisibility(videoId, true);
      }
    } catch (e) {
      // On error, assume video is not visible, stop it
      _pauseVideoById(videoId);
      ref.read(longVideoPlaybackProvider.notifier).clearCurrentlyPlaying();
    }
  }


  String _formatViews(int views) {
    if (views >= 1000000) {
      return '${(views / 1000000).toStringAsFixed(1)}M views';
    } else if (views >= 1000) {
      return '${(views / 1000).toStringAsFixed(1)}K views';
    }
    return '$views views';
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    }
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    final videosState = ref.watch(longVideosProvider);
    final videos = ref.watch(longVideosListProvider);
    final isLoading = ref.watch(longVideosLoadingProvider);
    final error = ref.watch(longVideosErrorProvider);
    
    // Listen to playback state changes to pause other videos
    // This is called in build, which is safe for ref.listen
    // Only listen once per build cycle to prevent multiple subscriptions
    ref.listen<LongVideoPlaybackState>(
      longVideoPlaybackProvider,
      (previous, next) {
        if (previous?.currentlyPlayingVideoId != next.currentlyPlayingVideoId && mounted) {
          // A new video started playing, pause ALL other videos immediately
          if (next.currentlyPlayingVideoId != null) {
            // Pause all videos except the new one
            _pauseAllVideosExcept(next.currentlyPlayingVideoId!);
          }
        }
      },
    );

    return Scaffold(
      backgroundColor: ThemeHelper.getBackgroundColor(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // App Header
            _buildHeader(),
            // Video Feed
            Expanded(
              child: error != null && videos.isEmpty
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
                            'Error loading videos',
                            style: TextStyle(
                              color: ThemeHelper.getTextPrimary(context),
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () {
                              ref.read(longVideosProvider.notifier).loadVideos(refresh: true);
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : isLoading && videos.isEmpty
                      ? Center(
                          child: CircularProgressIndicator(
                            color: ThemeHelper.getAccentColor(context),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () async {
                            await ref
                                .read(longVideosProvider.notifier)
                                .loadVideos(refresh: true);
                          },
                          color: ThemeHelper.getAccentColor(context),
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: EdgeInsets.zero,
                            itemCount: videos.length + (isLoading ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == videos.length) {
                                // Loading indicator at the bottom
                                return const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }
                              // Create or get GlobalKey for this video
                              final video = videos[index];
                              if (!_videoKeys.containsKey(video.id)) {
                                _videoKeys[video.id] = GlobalKey();
                              }
                              // Use video ID as key to prevent unnecessary rebuilds
                              return _buildVideoCard(video, key: _videoKeys[video.id]);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: ThemeHelper.getBackgroundColor(context),
        border: Border(
          bottom: BorderSide(
            color: ThemeHelper.getBorderColor(context),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // App Logo/Name
          Text(
            'VidConnect',
            style: TextStyle(
              color: ThemeHelper.getTextPrimary(context),
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoCard(PostModel video, {GlobalKey? key}) {
    final views = video.likes * 10; // Convert likes to views for display
    final formattedViews = _formatViews(views);
    final timeAgo = _formatTimeAgo(video.createdAt);

    return Column(
      key: key ?? ValueKey(video.id),
      children: [
        Container(
          color: ThemeHelper.getBackgroundColor(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          // User Info Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Profile Picture - Clickable
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfileScreen(user: video.author),
                      ),
                    );
                  },
                  child: ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: video.author.avatarUrl,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 40,
                        height: 40,
                        color: ThemeHelper.getSurfaceColor(context),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: ThemeHelper.getAccentColor(context),
                            ),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 40,
                        height: 40,
                        color: ThemeHelper.getSurfaceColor(context),
                        child: Icon(
                          Icons.person,
                          color: ThemeHelper.getTextSecondary(context),
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // User Name and Views - Clickable
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProfileScreen(user: video.author),
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          video.author.displayName,
                          style: TextStyle(
                            color: ThemeHelper.getTextPrimary(context),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$formattedViews • $timeAgo',
                          style: TextStyle(
                            color: ThemeHelper.getTextSecondary(context),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Follow Button
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: ThemeHelper.getSurfaceColor(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: ThemeHelper.getBorderColor(context),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    'Follow',
                    style: TextStyle(
                      color: ThemeHelper.getTextPrimary(context),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Video Player/Thumbnail
          _buildVideoPlayer(video),
            ],
          ),
        ),
        // Beautiful divider between posts
        _buildPostDivider(),
      ],
    );
  }

  Widget _buildPostDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    ThemeHelper.getBorderColor(context).withOpacity(0.2),
                    ThemeHelper.getBorderColor(context).withOpacity(0.5),
                  ],
                ),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ThemeHelper.getBorderColor(context).withOpacity(0.4),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    ThemeHelper.getBorderColor(context).withOpacity(0.5),
                    ThemeHelper.getBorderColor(context).withOpacity(0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  Widget _buildVideoPlayer(PostModel video) {
    final videoUrl = video.videoUrl;
    
    if (videoUrl == null) {
      return Container(
        width: double.infinity,
        height: 220,
        color: ThemeHelper.getSurfaceColor(context),
        child: Icon(
          Icons.video_library,
          color: ThemeHelper.getTextSecondary(context),
          size: 48,
        ),
      );
    }

    // CRITICAL: Use per-widget provider with unique key (widgetId + videoUrl)
    // This ensures each widget has its own independent video player instance
    final key = VideoWidgetKey(video.id, videoUrl);
    final widgetState = ref.watch(longVideoWidgetProvider(key));
    final playbackState = ref.watch(longVideoPlaybackProvider);
    
    final isVideoInitialized = widgetState.isInitialized;
    final isPlaying = widgetState.isPlaying;
    final isThisVideoPlaying = playbackState.currentlyPlayingVideoId == video.id && isPlaying;
    final showControls = playbackState.showControls[video.id] ?? true;

    return Stack(
      children: [
          // Video player or thumbnail with tap handler
          GestureDetector(
            onTap: () {
              // Navigate to embedded view when tapping anywhere (except play button)
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VideoPlayerScreen(
                    videoUrl: videoUrl,
                    title: video.caption,
                    author: video.author,
                    post: video,
                  ),
                ),
              );
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: double.infinity,
              height: 220,
              color: Colors.black,
              // CRITICAL: Show VideoPlayer when:
              // 1. Video is playing, OR
              // 2. Video is initialized and seeking (to prevent thumbnail flash)
              // Show thumbnail otherwise
              child: (isVideoInitialized && 
                      widgetState.controller != null && 
                      (isThisVideoPlaying || widgetState.isSeeking))
                  ? VideoPlayer(widgetState.controller!)
                  : CachedNetworkImage(
                      imageUrl: video.thumbnailUrl ?? video.imageUrl ?? '',
                      width: double.infinity,
                      height: 220,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: double.infinity,
                        height: 220,
                        color: ThemeHelper.getSurfaceColor(context),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: ThemeHelper.getAccentColor(context),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: double.infinity,
                        height: 220,
                        color: ThemeHelper.getSurfaceColor(context),
                        child: Icon(
                          Icons.video_library,
                          color: ThemeHelper.getTextSecondary(context),
                          size: 48,
                        ),
                      ),
                    ),
            ),
          ),
          
          // Play/Pause button - same as video_tile.dart
          if (isVideoInitialized && widgetState.controller != null)
            Positioned.fill(
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    // Prevent rapid toggles (debounce)
                    final now = DateTime.now();
                    if (_lastPlayActionTime != null &&
                        now.difference(_lastPlayActionTime!) < const Duration(milliseconds: 300)) {
                      return; // Ignore rapid taps
                    }
                    _lastPlayActionTime = now;
                    
                    // CRITICAL: Pause ALL other videos FIRST, before toggling this one
                    // This prevents multiple videos from playing simultaneously
                    _pauseAllOtherVideos(video.id, videoUrl);
                    
                    // DISABLE AUTOPLAY when user manually plays a video
                    ref.read(longVideoPlaybackProvider.notifier).disableAutoplay();
                    
                    // Then toggle play/pause for this video (with lazy initialization)
                    final widgetKey = VideoWidgetKey(video.id, videoUrl);
                    final notifier = ref.read(longVideoWidgetProvider(widgetKey).notifier);
                    
                    notifier.togglePlayPause().then((_) {
                      // Update currently playing video after async operation
                      if (mounted) {
                        if (notifier.state.isPlaying) {
                          // Set this video as currently playing
                          ref.read(longVideoPlaybackProvider.notifier).setCurrentlyPlaying(video.id);
                          _showControlsTemporarily(video.id);
                        } else {
                          // If paused, clear currently playing
                          ref.read(longVideoPlaybackProvider.notifier).clearCurrentlyPlaying();
                          ref.read(longVideoPlaybackProvider.notifier).setControlsVisibility(video.id, false);
                        }
                      }
                    });
                  },
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedOpacity(
                    // Show play/pause button when:
                    // 1. Video is playing AND controls are visible (show pause icon)
                    // 2. Video is initialized but NOT playing (always show play icon when paused)
                    // 3. Video is not initialized (show play icon)
                    opacity: (isThisVideoPlaying && showControls) || 
                             (isVideoInitialized && !isThisVideoPlaying) || 
                             (!isVideoInitialized)
                        ? 1.0 
                        : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.6),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        isPlaying && isThisVideoPlaying
                            ? CupertinoIcons.pause_circle_fill
                            : CupertinoIcons.play_circle_fill,
                        size: 70,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
            // Play button overlay when video not initialized (same as video_tile.dart)
            Positioned.fill(
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    // Prevent rapid toggles (debounce)
                    final now = DateTime.now();
                    if (_lastPlayActionTime != null &&
                        now.difference(_lastPlayActionTime!) < const Duration(milliseconds: 300)) {
                      return; // Ignore rapid taps
                    }
                    _lastPlayActionTime = now;
                    
                    // CRITICAL: Pause ALL other videos FIRST, before playing this one
                    // This prevents multiple videos from playing simultaneously
                    _pauseAllOtherVideos(video.id, videoUrl);
                    
                    // DISABLE AUTOPLAY when user manually plays a video
                    ref.read(longVideoPlaybackProvider.notifier).disableAutoplay();
                    
                    // Then initialize and play this video (lazy initialization)
                    final widgetKey = VideoWidgetKey(video.id, videoUrl);
                    final notifier = ref.read(longVideoWidgetProvider(widgetKey).notifier);
                    
                    // Play will trigger lazy initialization if needed
                    notifier.play().then((_) {
                      // Set this video as currently playing after initialization
                      if (mounted) {
                        ref.read(longVideoPlaybackProvider.notifier).setCurrentlyPlaying(video.id);
                        _showControlsTemporarily(video.id);
                      }
                    });
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      CupertinoIcons.play_fill,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
          
          // Forward/Backward buttons - appear outside thumbnail on bottom left when playing
          if (isThisVideoPlaying && isVideoInitialized)
            Positioned(
              left: 12,
              bottom: 12,
              child: Row(
                children: [
                  // Backward 10s button
                  GestureDetector(
                    onTap: () async {
                      // Stop propagation to prevent navigation
                      final key = VideoWidgetKey(video.id, videoUrl);
                      final notifier = ref.read(longVideoWidgetProvider(key).notifier);
                      await notifier.seekBackward();
                      if (mounted) {
                        _showControlsTemporarily(video.id);
                      }
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.replay_10,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Forward 10s button
                  GestureDetector(
                    onTap: () async {
                      // Stop propagation to prevent navigation
                      final key = VideoWidgetKey(video.id, videoUrl);
                      final notifier = ref.read(longVideoWidgetProvider(key).notifier);
                      await notifier.seekForward();
                      if (mounted) {
                        _showControlsTemporarily(video.id);
                      }
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.forward_10,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // Duration badge
          if (video.videoDuration != null)
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _formatDuration(video.videoDuration!),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
      ],
    );
  }

}

