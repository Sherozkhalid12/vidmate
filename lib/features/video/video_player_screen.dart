import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/providers/video_player_provider.dart';
import '../../core/models/user_model.dart';
import '../../core/models/post_model.dart';

/// Long-form video player with Riverpod state management
class VideoPlayerScreen extends ConsumerStatefulWidget {
  final String videoUrl;
  final String title;
  final UserModel author;
  final PostModel? post;

  const VideoPlayerScreen({
    super.key,
    required this.videoUrl,
    required this.title,
    required this.author,
    this.post,
  });

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> {
  bool _isLiked = false;
  int _likeCount = 0;
  int _commentCount = 0;
  Timer? _controlsTimer;

  @override
  void initState() {
    super.initState();
    if (widget.post != null) {
      _isLiked = widget.post!.isLiked;
      _likeCount = widget.post!.likes;
      _commentCount = widget.post!.comments;
    }
    _startControlsTimer();
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        ref.read(videoPlayerProvider(widget.videoUrl).notifier).toggleControls();
      }
    });
  }

  void _toggleFullscreen() {
    final notifier = ref.read(videoPlayerProvider(widget.videoUrl).notifier);
    notifier.toggleFullscreen();
    
    final state = ref.read(videoPlayerProvider(widget.videoUrl));
    if (state.isFullscreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(videoPlayerProvider(widget.videoUrl));
    final notifier = ref.read(videoPlayerProvider(widget.videoUrl).notifier);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          onTap: () {
            notifier.toggleControls();
            _startControlsTimer();
          },
          onDoubleTapDown: (details) {
            final screenWidth = MediaQuery.of(context).size.width;
            if (details.localPosition.dx < screenWidth / 2) {
              notifier.seekBackward();
            } else {
              notifier.seekForward();
            }
            _startControlsTimer();
          },
          child: Stack(
            children: [
              // Video player
              Center(
                child: playerState.isInitialized && playerState.controller != null
                    ? AspectRatio(
                        aspectRatio: playerState.controller!.value.aspectRatio,
                        child: VideoPlayer(playerState.controller!),
                      )
                    : Center(
                        child: CircularProgressIndicator(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
              ),
              
              // Minimal title at top (only in fullscreen)
              if (playerState.isFullscreen && playerState.showControls)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.7),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () {
                              _toggleFullscreen();
                              Navigator.pop(context);
                            },
                          ),
                          Expanded(
                            child: Text(
                              '${widget.title} - ${widget.author.displayName}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Controls overlay
              if (playerState.showControls)
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
                        // Draggable Progress bar
                        GestureDetector(
                          onHorizontalDragStart: (_) {
                            notifier.toggleControls();
                            _startControlsTimer();
                          },
                          onHorizontalDragUpdate: (details) {
                            if (!playerState.isInitialized) return;
                            final box = context.findRenderObject() as RenderBox?;
                            if (box == null) return;
                            final dragPosition = details.localPosition.dx;
                            final totalWidth = box.size.width;
                            final progress = (dragPosition / totalWidth).clamp(0.0, 1.0);
                            final targetPosition = Duration(
                              milliseconds: (playerState.duration.inMilliseconds * progress).round(),
                            );
                            notifier.seekTo(targetPosition);
                          },
                          onHorizontalDragEnd: (_) {
                            _startControlsTimer();
                          },
                          child: Stack(
                            children: [
                              VideoProgressIndicator(
                                playerState.controller!,
                                allowScrubbing: true,
                                colors: VideoProgressColors(
                                  playedColor: Theme.of(context).colorScheme.primary,
                                  bufferedColor: context.textMuted,
                                  backgroundColor: context.surfaceColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Time and controls
                        Row(
                          children: [
                            Text(
                              _formatDuration(playerState.position),
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 12,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: Icon(
                                playerState.isPlaying ? Icons.pause : Icons.play_arrow,
                                color: context.textPrimary,
                              ),
                              onPressed: () {
                                notifier.togglePlayPause();
                                _startControlsTimer();
                              },
                            ),
                            IconButton(
                              icon: Icon(
                                playerState.isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                                color: context.textPrimary,
                              ),
                              onPressed: () {
                                _toggleFullscreen();
                                _startControlsTimer();
                              },
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatDuration(playerState.duration),
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
              
              // Top bar (only in portrait mode)
              if (!playerState.isFullscreen && playerState.showControls)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),

              // Video info card (only in portrait mode, not fullscreen)
              if (!playerState.isFullscreen && playerState.showControls)
                Positioned(
                  bottom: 120,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
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
                        const SizedBox(height: 4),
                        Text(
                          widget.author.displayName,
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Seek indicator overlay
              if (playerState.showSeekIndicator)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          playerState.seekDirection == 'forward'
                              ? Icons.forward_10
                              : Icons.replay_10,
                          color: Colors.white,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _formatDuration(playerState.seekTarget),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
