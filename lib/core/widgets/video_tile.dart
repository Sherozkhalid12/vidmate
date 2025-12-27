import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_colors.dart';
import '../utils/theme_helper.dart';
import 'glass_card.dart';

/// Video tile widget for feed – updated with beautiful Cupertino icons
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
    this.isPlaying = false,
  });

  @override
  State<VideoTile> createState() => _VideoTileState();
}

class _VideoTileState extends State<VideoTile> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) {
        setState(() => _isHovered = true);
        _controller.forward();
      },
      onTapUp: (_) {
        setState(() => _isHovered = false);
        _controller.reverse();
      },
      onTapCancel: () {
        setState(() => _isHovered = false);
        _controller.reverse();
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _isHovered ? _scaleAnimation.value : 1.0,
            child: GlassCard(
              padding: EdgeInsets.zero,
              margin: EdgeInsets.zero, // Let parent handle margins
              borderRadius: BorderRadius.circular(20),
              onTap: widget.onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thumbnail – fills completely to the card's rounded borders
                  Stack(
                    children: [
                      AspectRatio(
                        aspectRatio: 4 / 3, // or 9 / 16 for vertical videos
                        child: CachedNetworkImage(
                          imageUrl: widget.thumbnailUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          placeholder: (context, url) => Container(
                            color: ThemeHelper.getSurfaceColor(context),
                            child: Center(
                              child: SizedBox(
                                width: 40,
                                height: 40,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Theme.of(context).iconTheme.color ?? ThemeHelper.getTextPrimary(context),
                                ),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: ThemeHelper.getSurfaceColor(context),
                            child: Center(
                              child: Icon(
                                CupertinoIcons.exclamationmark_triangle_fill,
                                color: ThemeHelper.getTextSecondary(context),
                                size: 60,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Play overlay – theme-aware icon with high contrast
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.35),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Center(
                            child: Builder(
                              builder: (context) {
                                final isDark = Theme.of(context).brightness == Brightness.dark;
                                // High contrast: white in dark mode, black in light mode
                                final iconColor = isDark ? Colors.white : Colors.black;
                                return Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.25),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.white.withOpacity(0.4),
                                        blurRadius: 20,
                                        spreadRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    widget.isPlaying 
                                        ? CupertinoIcons.pause_fill 
                                        : CupertinoIcons.play_fill,
                                    color: Colors.black,
                                    size: 44,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),

                      // Duration badge - high contrast text on semi-transparent dark background
                      if (widget.duration != null)
                        Positioned(
                          bottom: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.75),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _formatDuration(widget.duration!),
                              style: const TextStyle(
                                color: Colors.white, // Always white on dark semi-transparent bg for contrast
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Title and channel info
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.channelAvatar != null) ...[
                          ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: widget.channelAvatar!,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                width: 40,
                                height: 40,
                                color: ThemeHelper.getSurfaceColor(context),
                                child: Center(
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Theme.of(context).iconTheme.color ?? ThemeHelper.getTextPrimary(context),
                                    ),
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                width: 40,
                                height: 40,
                                color: ThemeHelper.getSurfaceColor(context),
                                child: Icon(
                                  CupertinoIcons.person_crop_circle_fill,
                                  color: ThemeHelper.getTextSecondary(context),
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: ThemeHelper.getTextPrimary(context),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (widget.channelName != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  widget.channelName!,
                                  style: TextStyle(
                                    color: ThemeHelper.getTextSecondary(context),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Stats – using beautiful Cupertino icons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        _buildStat(CupertinoIcons.eye_fill, _formatNumber(widget.views)),
                        const SizedBox(width: 20),
                        _buildStat(CupertinoIcons.heart_fill, _formatNumber(widget.likes)),
                        const SizedBox(width: 20),
                        _buildStat(CupertinoIcons.bubble_left_bubble_right_fill, _formatNumber(widget.comments)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStat(IconData icon, String value) {
    return Builder(
      builder: (context) {
        // Use theme-aware colors for icons and text
        final iconColor = ThemeHelper.getTextSecondary(context);
        final textColor = ThemeHelper.getTextMuted(context);
        return Row(
          children: [
            Icon(
              icon,
              color: iconColor,
              size: 20,
            ),
            const SizedBox(width: 6),
            Text(
              value,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      },
    );
  }
}