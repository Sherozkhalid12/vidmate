import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/theme_extensions.dart';
import 'package:video_player/video_player.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/models/user_model.dart';
import '../../core/models/post_model.dart';
import '../feed/comments_screen.dart';

/// YouTube-style long-form video player
class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String title;
  final UserModel author;
  final PostModel? post; // Optional post for like/comment/share

  const VideoPlayerScreen({
    super.key,
    required this.videoUrl,
    required this.title,
    required this.author,
    this.post,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _isPlaying = false;
  bool _isInitialized = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _showControls = true;
  bool _isLiked = false;
  int _likeCount = 0;
  int _commentCount = 0;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
    if (widget.post != null) {
      _isLiked = widget.post!.isLiked;
      _likeCount = widget.post!.likes;
      _commentCount = widget.post!.comments;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _initializePlayer() {
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _controller.initialize().then((_) {
      setState(() {
        _isInitialized = true;
        _duration = _controller.value.duration;
        _isPlaying = _controller.value.isPlaying;
      });
      _controller.addListener(_videoListener);
      _controller.play();
    });
  }

  void _videoListener() {
    if (mounted) {
      setState(() {
        _position = _controller.value.position;
        _isPlaying = _controller.value.isPlaying;
      });
    }
  }

  void _togglePlayPause() {
    setState(() {
      if (_isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
      _isPlaying = !_isPlaying;
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          onTap: () {
            setState(() {
              _showControls = !_showControls;
            });
          },
          child: Stack(
            children: [
              // Video player
              Center(
                child: _isInitialized
                    ? AspectRatio(
                        aspectRatio: _controller.value.aspectRatio,
                        child: VideoPlayer(_controller),
                      )
                    : const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.neonPurple,
                        ),
                      ),
              ),
              // Controls overlay
              if (_showControls)
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
                          Colors.black.withOpacity(0.8),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Progress bar
                        VideoProgressIndicator(
                          _controller,
                          allowScrubbing: true,
                          colors: VideoProgressColors(
                            playedColor: AppColors.neonPurple,
                            bufferedColor: context.textMuted,
                            backgroundColor: context.surfaceColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Time and controls
                        Row(
                          children: [
                            Text(
                              _formatDuration(_position),
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 12,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: Icon(
                                _isPlaying ? Icons.pause : Icons.play_arrow,
                                color: context.textPrimary,
                              ),
                              onPressed: _togglePlayPause,
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.fullscreen,
                                color: context.textPrimary,
                              ),
                              onPressed: () {
                                setState(() {
                                  // Toggle fullscreen mode
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Fullscreen mode toggled'),
                                    backgroundColor: AppColors.cyanGlow,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatDuration(_duration),
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              // Top bar
              if (_showControls)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    leading: IconButton(
                      icon: Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context),
                    ),
                    actions: [
                      IconButton(
                        icon: Icon(Icons.more_vert),
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: context.secondaryBackgroundColor,
                            builder: (context) => Container(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: Icon(Icons.share, color: AppColors.neonPurple),
                                    title: Text('Share', style: TextStyle(color: context.textPrimary)),
                                    onTap: () {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Share feature coming soon'),
                                          backgroundColor: AppColors.cyanGlow,
                                        ),
                                      );
                                    },
                                  ),
                                  ListTile(
                                    leading: Icon(Icons.download, color: AppColors.neonPurple),
                                    title: Text('Download', style: TextStyle(color: context.textPrimary)),
                                    onTap: () {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Download feature coming soon'),
                                          backgroundColor: AppColors.cyanGlow,
                                        ),
                                      );
                                    },
                                  ),
                                  ListTile(
                                    leading: Icon(Icons.report, color: AppColors.warning),
                                    title: Text('Report', style: TextStyle(color: context.textPrimary)),
                                    onTap: () {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Report feature coming soon'),
                                          backgroundColor: AppColors.cyanGlow,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              // Video info card
              if (_showControls)
                Positioned(
                  bottom: 120,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: GlassCard(
                      padding: const EdgeInsets.all(16),
                      borderRadius: BorderRadius.circular(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl: widget.author.avatarUrl,
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    width: 40,
                                    height: 40,
                                    color: context.surfaceColor,
                                    child: const Center(
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.neonPurple,
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
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.author.displayName,
                                      style: TextStyle(
                                        color: context.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '${_formatCount(widget.author.followers)} subscribers',
                                      style: TextStyle(
                                        color: context.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  gradient: AppColors.purpleGradient,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Subscribe',
                                  style: TextStyle(
                                    color: context.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // Like, Comment, Share buttons
                          if (widget.post != null) ...[
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildActionButton(
                                  icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                                  label: _formatCount(_likeCount),
                                  color: _isLiked ? AppColors.warning : context.textPrimary,
                                  onTap: () {
                                    setState(() {
                                      _isLiked = !_isLiked;
                                      _likeCount += _isLiked ? 1 : -1;
                                      _likeCount = _likeCount.clamp(0, double.infinity).toInt();
                                    });
                                  },
                                ),
                                _buildActionButton(
                                  icon: Icons.comment_outlined,
                                  label: _formatCount(_commentCount),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => CommentsScreen(
                                          postId: widget.post!.id,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                _buildActionButton(
                                  icon: Icons.share_outlined,
                                  label: 'Share',
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text('Share feature coming soon'),
                                        backgroundColor: AppColors.cyanGlow,
                                        behavior: SnackBarBehavior.floating,
                                        margin: const EdgeInsets.all(16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    Color? color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
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
              color: color ?? context.textPrimary,
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
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

