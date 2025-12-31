import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../theme/app_colors.dart';
import '../utils/theme_helper.dart';
import 'package:flutter_application_1/features/profile/profile_screen.dart';
import '../../features/feed/comments_screen.dart';

/// Video tile widget redesigned to match Instagram-style post card
class VideoTile extends StatefulWidget {
  final String thumbnailUrl;
  final String title;
  final String? channelName;
  final String? channelAvatar;
  final int views;
  final int likes;
  final int comments;
  final Duration? duration;
  final VoidCallback? onTap;
  final String? videoUrl; // Add video URL for inline playback
  final bool isPlaying;

  const VideoTile({
    super.key,
    required this.thumbnailUrl,
    required this.title,
    this.channelName,
    this.channelAvatar,
    this.views = 0,
    this.likes = 0,
    this.comments = 0,
    this.duration,
    this.onTap,
    this.videoUrl,
    this.isPlaying = false,
  });

  @override
  State<VideoTile> createState() => _VideoTileState();
}

class _VideoTileState extends State<VideoTile> {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isLiked = false;
  bool _isSaved = false;
  bool _isVideoVisible = true; // Track visibility for auto-pause

  @override
  void initState() {
    super.initState();
    // Initialize video if URL provided
    if (widget.videoUrl != null) {
      _initializeVideo();
    }
  }

  @override
  void dispose() {
    _videoController?.pause();
    _videoController?.dispose();
    super.dispose();
  }

  void _initializeVideo() {
    if (widget.videoUrl == null) return;
    
    _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl!))
      ..setLooping(true)
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isVideoInitialized = true;
          });
          // Auto-play if visible and widget.isPlaying is true
          if (_isVideoVisible && widget.isPlaying) {
            _videoController?.play();
          }
        }
      }).catchError((error) {
        // Handle video initialization error
        if (mounted) {
          setState(() {
            _isVideoInitialized = false;
          });
        }
      });
    
    // Add listener for instant UI updates
    _videoController?.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _togglePlayPause() {
    if (_videoController == null || !_isVideoInitialized) {
      widget.onTap?.call();
      return;
    }

    // Instant play/pause - call directly without setState delay
    if (_videoController!.value.isPlaying) {
      _videoController!.pause();
    } else {
      _videoController!.play();
    }
    // State will update via listener, but force immediate update for UI
    if (mounted) {
      setState(() {});
    }
  }

  void _seekForward() {
    if (_videoController == null || !_isVideoInitialized) return;
    final currentPosition = _videoController!.value.position;
    final newPosition = currentPosition + const Duration(seconds: 10);
    final duration = _videoController!.value.duration;
    _videoController!.seekTo(newPosition > duration ? duration : newPosition);
  }

  void _seekBackward() {
    if (_videoController == null || !_isVideoInitialized) return;
    final currentPosition = _videoController!.value.position;
    final newPosition = currentPosition - const Duration(seconds: 10);
    _videoController!.seekTo(newPosition < Duration.zero ? Duration.zero : newPosition);
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

  @override
  Widget build(BuildContext context) {
    // Auto-pause when not visible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final renderObject = context.findRenderObject();
      if (renderObject != null && renderObject.attached) {
        final isVisible = renderObject is RenderBox && 
                         renderObject.hasSize && 
                         renderObject.size.height > 0;
        if (_isVideoVisible != isVisible) {
          setState(() {
            _isVideoVisible = isVisible;
          });
          if (!isVisible && _videoController?.value.isPlaying == true) {
            _videoController?.pause();
          }
        }
      }
    });

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      color: ThemeHelper.getBackgroundColor(context),
      child: Column(
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
                  Icon(
                    CupertinoIcons.ellipsis,
                    color: ThemeHelper.getTextPrimary(context),
                    size: 20,
                  ),
                ],
              ),
            ),

          // Video/Thumbnail - Instagram style
          GestureDetector(
            onTap: _togglePlayPause,
            onDoubleTap: () {
              // Double tap right side = forward, left side = backward
              final screenWidth = MediaQuery.of(context).size.width;
              final tapPosition = (context.findRenderObject() as RenderBox?)
                  ?.localToGlobal(Offset.zero);
              if (tapPosition != null) {
                // This is a simplified version - in real implementation, use GestureDetector's onTapDown
                _seekForward();
              }
            },
            child: Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1.0,
                  child: _isVideoInitialized && _videoController != null
                      ? VideoPlayer(_videoController!)
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
                // Play/Pause overlay
                if (_isVideoInitialized && _videoController != null)
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: _togglePlayPause,
                      child: Container(
                        color: Colors.transparent,
                        child: Center(
                          child: Icon(
                            _videoController!.value.isPlaying
                                ? CupertinoIcons.pause_circle_fill
                                : CupertinoIcons.play_circle_fill,
                            size: 60,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.1),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            CupertinoIcons.play_fill,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                  ),
                // Forward/Backward controls overlay
                if (_isVideoInitialized && _videoController != null)
                  Positioned.fill(
                    child: Row(
                      children: [
                        // Left side - backward
                        Expanded(
                          child: GestureDetector(
                            onTap: _seekBackward,
                            child: Container(
                              color: Colors.transparent,
                              child: Center(
                                child: Icon(
                                  CupertinoIcons.backward_fill,
                                  color: Colors.white.withOpacity(0.7),
                                  size: 40,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Right side - forward
                        Expanded(
                          child: GestureDetector(
                            onTap: _seekForward,
                            child: Container(
                              color: Colors.transparent,
                              child: Center(
                                child: Icon(
                                  CupertinoIcons.forward_fill,
                                  color: Colors.white.withOpacity(0.7),
                                  size: 40,
                                ),
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

          // Actions row - Instagram style
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _isLiked = !_isLiked),
                  child: Icon(
                    _isLiked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                    size: 28,
                    color: _isLiked ? Colors.red : ThemeHelper.getTextPrimary(context),
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: widget.onTap,
                  child: Icon(
                    CupertinoIcons.chat_bubble,
                    size: 28,
                    color: ThemeHelper.getTextPrimary(context),
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  CupertinoIcons.paperplane,
                  size: 28,
                  color: ThemeHelper.getTextPrimary(context),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _isSaved = !_isSaved),
                  child: Icon(
                    _isSaved ? CupertinoIcons.bookmark_fill : CupertinoIcons.bookmark,
                    size: 28,
                    color: _isSaved ? Colors.amber : ThemeHelper.getTextPrimary(context),
                  ),
                ),
              ],
            ),
          ),

          // Likes count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '${_formatCount((_isLiked ? 1 : 0) + widget.likes)} likes',
              style: TextStyle(
                color: ThemeHelper.getTextPrimary(context),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
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
      ),
    );
  }
}
