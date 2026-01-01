import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/providers/video_player_provider.dart';
import '../../core/models/user_model.dart';
import '../../core/models/post_model.dart';
import '../profile/profile_screen.dart';

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

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> with WidgetsBindingObserver {
  bool _isLiked = false;
  int _likeCount = 0;
  int _commentCount = 0;
  Timer? _controlsTimer;
  VideoPlayerNotifier? _cachedNotifier;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    if (widget.post != null) {
      _isLiked = widget.post!.isLiked;
      _likeCount = widget.post!.likes;
      _commentCount = widget.post!.comments;
    }
    _startControlsTimer();
    
    // Cache notifier and start playing video when screen is shown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          _cachedNotifier = ref.read(videoPlayerProvider(widget.videoUrl).notifier);
          _startVideoPlayback();
        } catch (e) {
          // Provider might not be ready yet
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Pause video when app goes to background
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _cachedNotifier?.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controlsTimer?.cancel();
    
    // Use cached notifier to avoid using ref after disposal
    if (_cachedNotifier != null) {
      try {
        // Force pause first to stop any background playback
        _cachedNotifier!.pause();
      } catch (e) {
        // Ignore errors
      }
    }
    
    // Try to pause via controller directly if available (before ref is disposed)
    try {
      final state = ref.read(videoPlayerProvider(widget.videoUrl));
      if (state.controller != null && state.controller!.value.isInitialized) {
        if (state.controller!.value.isPlaying) {
          state.controller!.pause();
        }
      }
    } catch (e) {
      // ref might be disposed, ignore
    }
    
    // Invalidate provider to trigger disposal (this might fail if ref is already disposed)
    try {
      ref.invalidate(videoPlayerProvider(widget.videoUrl));
    } catch (e) {
      // Ignore if already disposed/invalidated
    }
    
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

  void _startVideoPlayback() {
    if (!mounted) return;
    
    try {
      final notifier = _cachedNotifier ?? ref.read(videoPlayerProvider(widget.videoUrl).notifier);
      if (notifier == null) return;
      
      final state = ref.read(videoPlayerProvider(widget.videoUrl));
      
      // Only play if initialized and not already playing
      if (state.isInitialized && !state.isPlaying && state.controller != null) {
        notifier.play();
      } else if (!state.isInitialized) {
        // If not initialized yet, wait a bit and try again
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _startVideoPlayback();
          }
        });
      }
    } catch (e) {
      // Provider might be disposed, ignore
    }
  }

  void _toggleFullscreen() {
    final notifier = ref.read(videoPlayerProvider(widget.videoUrl).notifier);
    final currentState = ref.read(videoPlayerProvider(widget.videoUrl));
    
    // Close playback speed menu if open
    if (currentState.showPlaybackSpeedMenu) {
      notifier.togglePlaybackSpeedMenu();
    }
    
    notifier.toggleFullscreen();
    
    // Use a small delay for smoother transition
    Future.delayed(const Duration(milliseconds: 100), () {
    final state = ref.read(videoPlayerProvider(widget.videoUrl));
    if (state.isFullscreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
        SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.immersiveSticky,
          overlays: [],
        );
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
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

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullscreenActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool isVisible,
    required VoidCallback onTap,
  }) {
    return AnimatedOpacity(
      opacity: isVisible ? 1.0 : 0.5,
      duration: const Duration(milliseconds: 300),
      child: IgnorePointer(
        ignoring: !isVisible,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.black.withValues(alpha: 0.85),
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPortraitActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showShareDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.9),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Share Video',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildShareOption(
                  icon: Icons.link,
                  label: 'Copy Link',
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Link copied to clipboard!'),
                        backgroundColor: Colors.black.withOpacity(0.8),
                      ),
                    );
                  },
                ),
                _buildShareOption(
                  icon: Icons.message,
                  label: 'Message',
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Share via message'),
                        backgroundColor: Colors.black.withOpacity(0.8),
                      ),
                    );
                  },
                ),
                _buildShareOption(
                  icon: Icons.more_horiz,
                  label: 'More',
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('More sharing options'),
                        backgroundColor: Colors.black.withOpacity(0.8),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildShareOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedOption(
    VideoPlayerNotifier notifier,
    double speed,
    double currentSpeed,
    String label,
  ) {
    final isSelected = (speed - currentSpeed).abs() < 0.01;
    return InkWell(
      onTap: () {
        notifier.setPlaybackSpeed(speed);
        _startControlsTimer();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              Icon(
                Icons.check,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              )
            else
              const SizedBox(width: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.white,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(videoPlayerProvider(widget.videoUrl));
    
    // Ensure cached notifier is available
    if (_cachedNotifier == null) {
      _cachedNotifier = ref.read(videoPlayerProvider(widget.videoUrl).notifier);
    }
    
    final notifier = _cachedNotifier!;

    return WillPopScope(
      onWillPop: () async {
        // Pause video when back button is pressed
        if (_cachedNotifier != null) {
          try {
            _cachedNotifier!.pause();
          } catch (e) {
            // Ignore errors
          }
        }
        
        // Also try to pause via controller directly
        try {
          final state = ref.read(videoPlayerProvider(widget.videoUrl));
          if (state.controller != null && state.controller!.value.isInitialized) {
            if (state.controller!.value.isPlaying) {
              state.controller!.pause();
            }
          }
        } catch (e) {
          // Ignore errors
        }
        
        return true;
      },
      child: Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          onTap: () {
            // Close playback speed menu if open
            if (playerState.showPlaybackSpeedMenu) {
              notifier.togglePlaybackSpeedMenu();
            }
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
              // Video player with left/right tap gestures
              Center(
                child: playerState.isInitialized && playerState.controller != null
                    ? Stack(
                        children: [
                          AspectRatio(
                        aspectRatio: playerState.controller!.value.aspectRatio,
                        child: VideoPlayer(playerState.controller!),
                          ),
                          // Left/Right tap areas for seeking
                          Row(
                            children: [
                              // Left tap area - backward
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    notifier.seekBackward();
                                    _startControlsTimer();
                                  },
                                  child: Container(
                                    color: Colors.transparent,
                                    child: Center(
                                      child: AnimatedOpacity(
                                        opacity: playerState.showControls ? 0.6 : 0.0,
                                        duration: const Duration(milliseconds: 200),
                                        child: Icon(
                                          Icons.replay_10,
                                          color: Colors.white,
                                          size: 50,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Center tap area - play/pause toggle
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    notifier.togglePlayPause();
                                    _startControlsTimer();
                                  },
                                  child: Container(
                                    color: Colors.transparent,
                                  ),
                                ),
                              ),
                              // Right tap area - forward
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    notifier.seekForward();
                                    _startControlsTimer();
                                  },
                                  child: Container(
                                    color: Colors.transparent,
                                    child: Center(
                                      child: AnimatedOpacity(
                                        opacity: playerState.showControls ? 0.6 : 0.0,
                                        duration: const Duration(milliseconds: 200),
                                        child: Icon(
                                          Icons.forward_10,
                                          color: Colors.white,
                                          size: 50,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // Buffering indicator
                          if (playerState.isBuffering)
                            Positioned.fill(
                              child: Container(
                                color: Colors.black.withOpacity(0.3),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 3,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Buffering...',
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
                            ),
                        ],
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                          color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Loading video...',
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
              
              // Beautiful fullscreen header with gradient
              if (playerState.isFullscreen)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: AnimatedOpacity(
                    opacity: playerState.showControls ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: IgnorePointer(
                      ignoring: !playerState.showControls,
                  child: SafeArea(
                    child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                                Colors.black.withValues(alpha: 0.85),
                                Colors.black.withValues(alpha: 0.5),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Row(
                        children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                            onPressed: () {
                              _toggleFullscreen();
                              Navigator.pop(context);
                            },
                          ),
                              ),
                              const SizedBox(width: 12),
                          Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      widget.title,
                              style: const TextStyle(
                                color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      widget.author.displayName,
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.8),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Beautiful fullscreen action buttons - Always visible and prominent
              if (playerState.isFullscreen)
                Positioned(
                  right: 20,
                  bottom: 200,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Like button with animation
                      _buildFullscreenActionButton(
                        icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                        label: _formatCount(_likeCount),
                        color: _isLiked ? Colors.red : Colors.white,
                        isVisible: playerState.showControls,
                        onTap: () {
                          setState(() {
                            _isLiked = !_isLiked;
                            _likeCount += _isLiked ? 1 : -1;
                          });
                          _startControlsTimer();
                        },
                      ),
                      const SizedBox(height: 20),
                      // Comment button
                      _buildFullscreenActionButton(
                        icon: Icons.comment_outlined,
                        label: _formatCount(_commentCount),
                        color: Colors.white,
                        isVisible: playerState.showControls,
                        onTap: () {
                          _startControlsTimer();
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
                      // Share button
                      _buildFullscreenActionButton(
                        icon: Icons.share_outlined,
                        label: 'Share',
                        color: Colors.white,
                        isVisible: playerState.showControls,
                        onTap: () {
                          _startControlsTimer();
                          _showShareDialog(context);
                        },
                      ),
                      const SizedBox(height: 20),
                      // Visit profile button
                      _buildFullscreenActionButton(
                        icon: Icons.person_outline,
                        label: 'Profile',
                        color: Colors.white,
                        isVisible: playerState.showControls,
                        onTap: () {
                          _startControlsTimer();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProfileScreen(user: widget.author),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

              // Controls overlay with smooth animation
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                child: AnimatedOpacity(
                  opacity: playerState.showControls ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: IgnorePointer(
                    ignoring: !playerState.showControls,
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
                        // Draggable Progress bar with smooth scrubbing
                        GestureDetector(
                          onHorizontalDragStart: (details) {
                            // Keep controls visible while scrubbing
                            if (!playerState.showControls) {
                            notifier.toggleControls();
                            }
                            _startControlsTimer();
                          },
                          onHorizontalDragUpdate: (details) {
                            if (!playerState.isInitialized) return;
                            final box = context.findRenderObject() as RenderBox?;
                            if (box == null) return;
                            
                            // Calculate progress with padding consideration
                            final padding = 20.0; // Match container padding
                            final dragPosition = (details.localPosition.dx - padding).clamp(0.0, box.size.width - padding * 2);
                            final totalWidth = (box.size.width - padding * 2).clamp(1.0, double.infinity);
                            final progress = (dragPosition / totalWidth).clamp(0.0, 1.0);
                            final targetPosition = Duration(
                              milliseconds: (playerState.duration.inMilliseconds * progress).round(),
                            );
                            notifier.seekTo(targetPosition);
                          },
                          onHorizontalDragEnd: (_) {
                            _startControlsTimer();
                          },
                          onTapDown: (details) {
                            if (!playerState.isInitialized) return;
                            final box = context.findRenderObject() as RenderBox?;
                            if (box == null) return;
                            
                            // Tap to seek
                            final padding = 20.0;
                            final tapPosition = (details.localPosition.dx - padding).clamp(0.0, box.size.width - padding * 2);
                            final totalWidth = (box.size.width - padding * 2).clamp(1.0, double.infinity);
                            final progress = (tapPosition / totalWidth).clamp(0.0, 1.0);
                            final targetPosition = Duration(
                              milliseconds: (playerState.duration.inMilliseconds * progress).round(),
                            );
                            notifier.seekTo(targetPosition);
                            _startControlsTimer();
                          },
                          child: Stack(
                            children: [
                              if (playerState.controller != null)
                                VideoProgressIndicator(
                                  playerState.controller!,
                                  allowScrubbing: true,
                                  colors: VideoProgressColors(
                                    playedColor: Theme.of(context).colorScheme.primary,
                                    bufferedColor: Colors.white.withOpacity(0.3),
                                    backgroundColor: Colors.white.withOpacity(0.2),
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
                            // Playback speed button
                            IconButton(
                              icon: Stack(
                                children: [
                                  Icon(
                                    Icons.speed,
                                    color: context.textPrimary,
                                  ),
                                  if (playerState.playbackSpeed != 1.0)
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.primary,
                                          shape: BoxShape.circle,
                                        ),
                                        constraints: const BoxConstraints(
                                          minWidth: 12,
                                          minHeight: 12,
                                        ),
                                        child: Text(
                                          playerState.playbackSpeed.toStringAsFixed(1),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              onPressed: () {
                                notifier.togglePlaybackSpeedMenu();
                                _startControlsTimer();
                              },
                            ),
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
              ),
            ),
              // Top bar (only in portrait mode) with smooth animation
              if (!playerState.isFullscreen)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: AnimatedOpacity(
                    opacity: playerState.showControls ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: IgnorePointer(
                      ignoring: !playerState.showControls,
                  child: AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ),
                  ),
                ),

              // Video info card with action buttons (only in portrait mode, not fullscreen)
              if (!playerState.isFullscreen)
                Positioned(
                  bottom: 120,
                  left: 0,
                  right: 0,
                  child: AnimatedOpacity(
                    opacity: playerState.showControls ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: IgnorePointer(
                      ignoring: !playerState.showControls,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                            // Title and Author
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
                            const SizedBox(height: 16),
                            // Action buttons row (Like, Comment, Share, Profile)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                // Like button
                                _buildPortraitActionButton(
                                  icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                                  label: _formatCount(_likeCount),
                                  color: _isLiked ? Colors.red : Colors.white,
                                  onTap: () {
                                    setState(() {
                                      _isLiked = !_isLiked;
                                      _likeCount += _isLiked ? 1 : -1;
                                    });
                                    _startControlsTimer();
                                  },
                                ),
                                // Comment button
                                _buildPortraitActionButton(
                                  icon: Icons.comment_outlined,
                                  label: _formatCount(_commentCount),
                                  color: Colors.white,
                                  onTap: () {
                                    _startControlsTimer();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text('Comments feature coming soon!'),
                                        backgroundColor: Colors.black.withValues(alpha: 0.9),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                ),
                                // Share button
                                _buildPortraitActionButton(
                                  icon: Icons.share_outlined,
                                  label: 'Share',
                                  color: Colors.white,
                                  onTap: () {
                                    _startControlsTimer();
                                    _showShareDialog(context);
                                  },
                                ),
                                // Visit profile button
                                _buildPortraitActionButton(
                                  icon: Icons.person_outline,
                                  label: 'Profile',
                                  color: Colors.white,
                                  onTap: () {
                                    _startControlsTimer();
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ProfileScreen(user: widget.author),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Seek indicator overlay
              if (playerState.showSeekIndicator)
                Center(
                  child: AnimatedOpacity(
                    opacity: 1.0,
                    duration: const Duration(milliseconds: 200),
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
                ),

              // Playback speed menu
              if (playerState.showPlaybackSpeedMenu)
                Positioned(
                  bottom: 100,
                  right: 20,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildSpeedOption(notifier, 0.25, playerState.playbackSpeed, '0.25x'),
                          _buildSpeedOption(notifier, 0.5, playerState.playbackSpeed, '0.5x'),
                          _buildSpeedOption(notifier, 0.75, playerState.playbackSpeed, '0.75x'),
                          _buildSpeedOption(notifier, 1.0, playerState.playbackSpeed, 'Normal'),
                          _buildSpeedOption(notifier, 1.25, playerState.playbackSpeed, '1.25x'),
                          _buildSpeedOption(notifier, 1.5, playerState.playbackSpeed, '1.5x'),
                          _buildSpeedOption(notifier, 1.75, playerState.playbackSpeed, '1.75x'),
                          _buildSpeedOption(notifier, 2.0, playerState.playbackSpeed, '2x'),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}
