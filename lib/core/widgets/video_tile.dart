import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../utils/theme_helper.dart';
import '../providers/video_player_provider.dart';
import '../providers/posts_provider_riverpod.dart';
import '../models/post_model.dart';
import 'comments_bottom_sheet.dart';
import 'share_bottom_sheet.dart';
import 'dart:async';
import 'dart:ui';

/// Video tile widget redesigned to match Instagram-style post card
class VideoTile extends ConsumerStatefulWidget {
  final String thumbnailUrl;
  final String title;
  final String? channelName;
  final String? channelAvatar;
  final int views;
  final int likes;
  final int comments;
  final int shares;
  final Duration? duration;
  final VoidCallback? onTap;
  final String? videoUrl; // Add video URL for inline playback
  final bool isPlaying;
  final String? postId; // Post ID for Riverpod state management

  const VideoTile({
    super.key,
    required this.thumbnailUrl,
    required this.title,
    this.channelName,
    this.channelAvatar,
    this.views = 0,
    this.likes = 0,
    this.comments = 0,
    this.shares = 0,
    this.duration,
    this.onTap,
    this.videoUrl,
    this.isPlaying = false,
    this.postId,
  });

  @override
  ConsumerState<VideoTile> createState() => _VideoTileState();
}

class _VideoTileState extends ConsumerState<VideoTile> with WidgetsBindingObserver, SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  bool _isSaved = false;
  bool _isVideoVisible = false; // Track visibility for auto-pause - start as false
  late AnimationController _playPauseAnimationController;
  bool _showControls = true;
  Timer? _controlsTimer;
  Timer? _visibilityCheckTimer;
  
  @override
  bool get wantKeepAlive => false; // Don't keep alive - dispose when not visible

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _playPauseAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    // Check visibility periodically for better detection
    _visibilityCheckTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      _checkVisibility();
    });
    // Video will be initialized by Riverpod provider when needed
    _startControlsTimer();
  }
  
  void _startControlsTimer() {
    _controlsTimer?.cancel();
    // YouTube style: Hide controls after 3 seconds of no interaction
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && widget.videoUrl != null) {
        try {
          final playerState = ref.read(videoPlayerProvider(widget.videoUrl!));
          if (playerState.isPlaying) {
            setState(() {
              _showControls = false;
            });
          }
        } catch (e) {
          // Ignore errors
        }
      }
    });
  }
  
  void _showControlsTemporarily() {
    if (mounted) {
      setState(() {
        _showControls = true;
      });
      _startControlsTimer();
    }
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _visibilityCheckTimer?.cancel();
    _playPauseAnimationController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    // Pause video when disposing
    if (widget.videoUrl != null) {
      try {
        final notifier = ref.read(videoPlayerProvider(widget.videoUrl!).notifier);
        notifier.pause();
      } catch (e) {
        // Ignore errors during dispose
      }
    }
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check visibility when dependencies change (e.g., after scroll)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkVisibility();
    });
  }

  void _playVideo() {
    if (widget.videoUrl == null || !mounted) return;
    
    try {
      final notifier = ref.read(videoPlayerProvider(widget.videoUrl!).notifier);
      notifier.play();
      // YouTube style: Show controls briefly, then hide when playing
      setState(() {
        _showControls = true;
      });
      _startControlsTimer();
    } catch (e) {
      debugPrint('Error playing video: $e');
    }
  }

  void _togglePlayPause() {
    if (widget.videoUrl == null) {
      widget.onTap?.call();
      return;
    }

    try {
      // Animate button press for smooth feedback
      _playPauseAnimationController.forward(from: 0.0).then((_) {
        _playPauseAnimationController.reverse();
      });
      
      final notifier = ref.read(videoPlayerProvider(widget.videoUrl!).notifier);
      notifier.togglePlayPause();
      
      // Show controls and reset timer
      _showControlsTemporarily();
      
      // Force immediate UI update for smooth response
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      // Handle any errors gracefully
      debugPrint('Error toggling play/pause: $e');
    }
  }

  void _onVideoTap() {
    // Always open full video player when tapping on video (not on play/pause button)
    widget.onTap?.call();
  }

  void _seekForward() {
    if (widget.videoUrl == null) return;
    try {
      final notifier = ref.read(videoPlayerProvider(widget.videoUrl!).notifier);
      notifier.seekForward();
      _showControlsTemporarily();
    } catch (e) {
      debugPrint('Error seeking forward: $e');
    }
  }

  void _seekBackward() {
    if (widget.videoUrl == null) return;
    try {
      final notifier = ref.read(videoPlayerProvider(widget.videoUrl!).notifier);
      final playerState = ref.read(videoPlayerProvider(widget.videoUrl!));
      // Seek backward without pausing
      final wasPlaying = playerState.isPlaying;
      notifier.seekBackward();
      // Ensure video continues playing
      if (wasPlaying && !playerState.isPlaying) {
        notifier.play();
      }
      _showControlsTemporarily();
    } catch (e) {
      debugPrint('Error seeking backward: $e');
    }
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

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  void _checkVisibility() {
    if (!mounted) return;
    
    try {
      final renderObject = context.findRenderObject();
      if (renderObject == null || !renderObject.attached || renderObject is! RenderBox) {
        // Not attached or not a RenderBox - pause video
        if (_isVideoVisible && widget.videoUrl != null) {
          _isVideoVisible = false;
          try {
            final notifier = ref.read(videoPlayerProvider(widget.videoUrl!).notifier);
            notifier.pause();
          } catch (e) {
            // Ignore pause errors
          }
        }
        return;
      }

      final box = renderObject;
      if (!box.hasSize) {
        if (_isVideoVisible && widget.videoUrl != null) {
          _isVideoVisible = false;
          try {
            final notifier = ref.read(videoPlayerProvider(widget.videoUrl!).notifier);
            notifier.pause();
          } catch (e) {
            // Ignore pause errors
          }
        }
        return;
      }

      // Check if widget is actually visible on screen with more accurate bounds
      final position = box.localToGlobal(Offset.zero);
      final size = box.size;
      final screenSize = MediaQuery.of(context).size;
      
      // Check if widget is within screen bounds (with margin for better detection)
      // Only consider visible if at least 50% is on screen (like YouTube/Instagram)
      final visibleHeight = (position.dy + size.height).clamp(0.0, screenSize.height) - 
                           position.dy.clamp(0.0, screenSize.height);
      final visibleRatio = visibleHeight / size.height;
      final isVisible = visibleRatio > 0.5 && 
                       position.dy < screenSize.height &&
                       position.dy + size.height > 0 &&
                       position.dx < screenSize.width &&
                       position.dx + size.width > 0;

      if (_isVideoVisible != isVisible) {
        _isVideoVisible = isVisible;
        
        if (!isVisible) {
          // Pause immediately when video goes out of view
          if (widget.videoUrl != null) {
            try {
              final notifier = ref.read(videoPlayerProvider(widget.videoUrl!).notifier);
              notifier.pause();
            } catch (e) {
              // Ignore pause errors
            }
          }
        }
        // Don't auto-play when visible - user must tap to play
      } else if (!isVisible && widget.videoUrl != null) {
        // Double-check: if not visible but playing, pause immediately
        try {
          final playerState = ref.read(videoPlayerProvider(widget.videoUrl!));
          if (playerState.isPlaying) {
            final notifier = ref.read(videoPlayerProvider(widget.videoUrl!).notifier);
            notifier.pause();
          }
        } catch (e) {
          // Ignore pause errors
        }
      }
    } catch (e) {
      // If visibility check fails, assume not visible and pause
      if (_isVideoVisible && widget.videoUrl != null) {
        _isVideoVisible = false;
        try {
          final notifier = ref.read(videoPlayerProvider(widget.videoUrl!).notifier);
          notifier.pause();
        } catch (e) {
          // Ignore pause errors
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    // Auto-pause when not visible - check on every build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkVisibility();
    });

    // Get video player state if video URL is available
    final playerState = widget.videoUrl != null 
        ? ref.watch(videoPlayerProvider(widget.videoUrl!))
        : null;
    final isVideoInitialized = playerState?.isInitialized ?? false;
    final isPlaying = playerState?.isPlaying ?? false;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: isDark
          ? Container(
              color: ThemeHelper.getBackgroundColor(context),
              child: _buildTileContent(isVideoInitialized, isPlaying, playerState),
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                  ),
                  child: _buildTileContent(isVideoInitialized, isPlaying, playerState),
                ),
              ),
            ),
    );
  }

  Widget _buildTileContent(bool isVideoInitialized, bool isPlaying, VideoPlayerState? playerState) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header - Instagram style
          if (widget.channelAvatar != null || widget.channelName != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  if (widget.channelAvatar != null)
                    GestureDetector(
                      onTap: widget.onTap,
                      child: ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: widget.channelAvatar!,
                          width: 32,
                          height: 32,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            width: 32,
                            height: 32,
                            color: ThemeHelper.getSurfaceColor(context),
                          ),
                          errorWidget: (context, url, error) => Container(
                            width: 32,
                            height: 32,
                            color: ThemeHelper.getSurfaceColor(context),
                            child: Icon(
                              CupertinoIcons.person_crop_circle,
                              size: 32,
                              color: ThemeHelper.getTextSecondary(context),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (widget.channelAvatar != null) const SizedBox(width: 12),
                  if (widget.channelName != null)
                    Expanded(
                      child: GestureDetector(
                        onTap: widget.onTap,
                        child: Text(
                          widget.channelName!,
                          style: TextStyle(
                            color: ThemeHelper.getTextPrimary(context),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  // Follow button (rounded style) - same as instagram_post_card, fully rounded
                  if (widget.channelName != null)
                    Consumer(
                      builder: (context, ref, child) {
                        // Get author from posts if available
                        final posts = ref.watch(postsListProvider);
                        PostModel? post;
                        if (widget.postId != null) {
                          try {
                            post = posts.firstWhere((p) => p.id == widget.postId);
                          } catch (e) {
                            // Post not found, use first post as fallback
                            post = posts.isNotEmpty ? posts.first : null;
                          }
                        } else {
                          post = posts.isNotEmpty ? posts.first : null;
                        }
                        
                        // If no post found, we can't determine follow state, so hide button
                        if (post == null) {
                          return const SizedBox.shrink();
                        }
                        
                        final isFollowing = post.author.isFollowing;
                        
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () {
                              // Handle follow action - toggle follow state
                              ref.read(postsProvider.notifier).toggleFollow(post!.author.id);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: isFollowing ? Colors.transparent : ThemeHelper.getAccentColor(context),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: isFollowing 
                                      ? ThemeHelper.getTextPrimary(context)
                                      : ThemeHelper.getAccentColor(context),
                                  width: isFollowing ? 1.5 : 1,
                                ),
                              ),
                              child: Text(
                                isFollowing ? 'Following' : 'Follow',
                                style: TextStyle(
                                  color: isFollowing 
                                      ? ThemeHelper.getTextPrimary(context)
                                      : ThemeHelper.getOnAccentColor(context),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  Icon(
                    CupertinoIcons.ellipsis,
                    color: ThemeHelper.getTextPrimary(context),
                    size: 20,
                  ),
                ],
              ),
            ),

          // Video/Thumbnail - Tap anywhere to open fullscreen, play/pause button for controls
          GestureDetector(
            onTap: () {
              // Only navigate if video is not initialized or if tapping outside play button
              // Play button will handle its own tap and stop propagation
              if (widget.videoUrl == null || !isVideoInitialized) {
                _onVideoTap();
              } else {
                // If video is initialized, only navigate if not playing
                // Otherwise let play button handle it
                if (!isPlaying) {
                  _onVideoTap();
                }
              }
            },
            onDoubleTapDown: (details) {
              if (widget.videoUrl == null || !isVideoInitialized) return;
              // Double tap for seek
              _showControlsTemporarily();
              final screenWidth = MediaQuery.of(context).size.width;
              if (details.localPosition.dx < screenWidth / 2) {
                _seekBackward();
              } else {
                _seekForward();
              }
            },
            behavior: HitTestBehavior.opaque,
            child: Stack(
              children: [
                // Video player or thumbnail
                AspectRatio(
                  aspectRatio: 1.0,
                  child: isVideoInitialized && playerState?.controller != null
                      ? VideoPlayer(playerState!.controller!)
                      : CachedNetworkImage(
                          imageUrl: widget.thumbnailUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          placeholder: (context, url) => Container(
                            color: ThemeHelper.getSurfaceColor(context),
                            child: Center(
                              child: CupertinoActivityIndicator(
                                color: ThemeHelper.getTextSecondary(context),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: ThemeHelper.getSurfaceColor(context),
                            child: Center(
                              child: Icon(
                                CupertinoIcons.exclamationmark_triangle_fill,
                                color: ThemeHelper.getTextSecondary(context),
                                size: 48,
                              ),
                            ),
                          ),
                        ),
                ),
                
                // Play/Pause button - centered, only handles taps on the button itself
                if (isVideoInitialized && playerState != null)
                  Positioned.fill(
                    child: Center(
                      child: GestureDetector(
                        onTap: () {
                          // Play/pause video - this stops event propagation
                          _togglePlayPause();
                          _showControlsTemporarily();
                        },
                        behavior: HitTestBehavior.opaque, // Changed to opaque to stop propagation
                        child: AnimatedOpacity(
                          opacity: _showControls ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 300),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                _togglePlayPause();
                                _showControlsTemporarily();
                              },
                              borderRadius: BorderRadius.circular(35),
                              splashColor: Colors.white.withOpacity(0.2),
                              highlightColor: Colors.white.withOpacity(0.1),
                              child: ScaleTransition(
                                scale: Tween<double>(begin: 1.0, end: 0.85).animate(
                                  CurvedAnimation(
                                    parent: _playPauseAnimationController,
                                    curve: Curves.easeInOut,
                                  ),
                                ),
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
                                    isPlaying
                                        ? CupertinoIcons.pause_circle_fill
                                        : CupertinoIcons.play_circle_fill,
                                    size: 70,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
              else
                Positioned.fill(
                  child: Stack(
                    children: [
                      // Background tap area - navigates to fullscreen
                      GestureDetector(
                        onTap: _onVideoTap,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          color: Colors.transparent,
                        ),
                      ),
                      // Play button - plays video inline, stops propagation
                      Center(
                        child: GestureDetector(
                          onTap: () {
                            // Initialize and play video inline
                            if (widget.videoUrl != null) {
                              _playVideo();
                            } else {
                              _onVideoTap();
                            }
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            padding: const EdgeInsets.all(16),
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
                    ],
                  ),
                ),
              
              // Duration badge
              if (widget.duration != null)
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _formatDuration(widget.duration!),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Actions row - Bookmark/Backward/Forward on LEFT, Share/Comment/Like on RIGHT
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // Left side - Bookmark, Backward, Forward (only when playing)
                GestureDetector(
                  onTap: () => setState(() => _isSaved = !_isSaved),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isSaved ? Icons.star : Icons.star_border,
                        size: 28,
                        color: _isSaved ? ThemeHelper.getAccentColor(context) : ThemeHelper.getTextPrimary(context),
                      ),
                    ],
                  ),
                ),
                // Backward 10s (only visible when playing - no empty space when hidden)
                if (isPlaying && isVideoInitialized) ...[
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: _seekBackward,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.replay_10,
                          size: 28,
                          color: ThemeHelper.getTextPrimary(context),
                        ),
                      ],
                    ),
                  ),
                ],
                // Forward 10s (only visible when playing - no empty space when hidden)
                if (isPlaying && isVideoInitialized) ...[
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: _seekForward,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.forward_10,
                          size: 28,
                          color: ThemeHelper.getTextPrimary(context),
                        ),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                // Right side actions - Share, Comment, Like (matching InstagramPostCard)
                GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => ShareBottomSheet(
                        postId: widget.postId,
                        videoUrl: widget.videoUrl,
                      ),
                    );
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Transform.rotate(
                        angle: -0.785398,
                        child: Icon(
                          Icons.send,
                          size: 28,
                          color: ThemeHelper.getTextPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatCount(widget.shares),
                        style: TextStyle(
                          color: ThemeHelper.getTextSecondary(context),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => CommentsBottomSheet(postId: widget.postId ?? ''),
                    );
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.mode_comment_outlined,
                        size: 28,
                        color: ThemeHelper.getTextPrimary(context),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatCount(widget.comments),
                        style: TextStyle(
                          color: ThemeHelper.getTextSecondary(context),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Consumer(
                  builder: (context, ref, child) {
                    if (widget.postId != null) {
                      final isLiked = ref.watch(postLikedProvider(widget.postId!));
                      final likeCount = ref.watch(postLikeCountProvider(widget.postId!));
                      return GestureDetector(
                        onTap: () {
                          ref.read(postsProvider.notifier).toggleLike(widget.postId!);
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isLiked ? Icons.favorite : Icons.favorite_border,
                              size: 28,
                              color: isLiked ? Colors.red : ThemeHelper.getTextPrimary(context),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatCount(likeCount),
                              style: TextStyle(
                                color: ThemeHelper.getTextSecondary(context),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    } else {
                      // Fallback for when postId is not provided
                      return GestureDetector(
                        onTap: () {},
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.favorite_border,
                              size: 28,
                              color: ThemeHelper.getTextPrimary(context),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatCount(widget.likes),
                              style: TextStyle(
                                color: ThemeHelper.getTextSecondary(context),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 4),

          // Caption
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  color: ThemeHelper.getTextPrimary(context),
                  fontSize: 14,
                ),
                children: [
                  if (widget.channelName != null)
                    TextSpan(
                      text: '${widget.channelName} ',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  TextSpan(text: widget.title),
                ],
              ),
            ),
          ),

          // View all comments
          if (widget.comments > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: GestureDetector(
                onTap: widget.onTap,
                child: Text(
                  'View all ${_formatCount(widget.comments)} comments',
                  style: TextStyle(
                    color: ThemeHelper.getTextSecondary(context),
                    fontSize: 14,
                  ),
                ),
              ),
            ),

          const SizedBox(height: 8),
        ],
      );
  }
}
