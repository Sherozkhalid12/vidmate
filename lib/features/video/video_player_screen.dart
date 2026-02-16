import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:better_player/better_player.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/providers/video_player_provider.dart';
import '../../core/models/user_model.dart';
import '../../core/models/post_model.dart';
import '../../core/services/mock_data_service.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/comments_bottom_sheet.dart';
import '../../core/widgets/share_bottom_sheet.dart';
import '../../core/widgets/safe_better_player.dart';
import '../profile/profile_screen.dart';
import 'dart:ui';

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
  List<PostModel>? _cachedSuggestedVideos;

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
    if (_cachedNotifier != null) {
      try {
        _cachedNotifier!.pause();
      } catch (e) {
        // Ignore
      }
    }
    // Do not use ref or ref.invalidate in dispose() — ref is invalid once the widget is torn down.
    
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    
    // Only start timer if controls are currently visible
    // This prevents auto-showing controls after user explicitly hides them
    final currentState = ref.read(videoPlayerProvider(widget.videoUrl));
    if (!currentState.showControls) {
      return; // Don't start timer if controls are hidden
    }
    
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        final state = ref.read(videoPlayerProvider(widget.videoUrl));
        // Only auto-hide if controls are still visible (user didn't show them again)
        if (state.showControls) {
        ref.read(videoPlayerProvider(widget.videoUrl).notifier).toggleControls();
        }
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

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays >= 7) {
      final weeks = difference.inDays ~/ 7;
      return '$weeks week${weeks > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} min ago';
    }
    return 'Just now';
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
                        content: Text(
                          'Link copied to clipboard!',
                          style: TextStyle(
                            color: ThemeHelper.getTextPrimary(context),
                          ),
                        ),
                        backgroundColor: ThemeHelper.getSurfaceColor(context).withOpacity(0.95),
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
          if (state.controller != null && state.isInitialized) {
            if (state.isPlaying) {
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
        body: playerState.isFullscreen
            ? _buildFullscreenView(playerState, notifier)
            : _buildEmbeddedView(playerState, notifier),
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context, VideoPlayerState playerState) {
    final durationMs = playerState.duration.inMilliseconds;
    final positionMs = playerState.position.inMilliseconds;
    final progress = durationMs > 0 ? (positionMs / durationMs).clamp(0.0, 1.0) : 0.0;
    return SizedBox(
      height: 4,
      child: LinearProgressIndicator(
        value: progress,
        backgroundColor: Colors.white.withOpacity(0.2),
        valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
      ),
    );
  }

  Widget _buildFullscreenView(VideoPlayerState playerState, VideoPlayerNotifier notifier) {
    return SafeArea(
        child: GestureDetector(
          onTap: () {
          // Single tap: Only toggle controls, don't skip
            // Close playback speed menu if open
            if (playerState.showPlaybackSpeedMenu) {
              notifier.togglePlaybackSpeedMenu();
            }
          
          // Toggle controls
            notifier.toggleControls();
          
          // Get the new state after toggle
          final newState = ref.read(videoPlayerProvider(widget.videoUrl));
          
          // Only start timer if controls are now visible (to auto-hide them)
          // If controls are hidden, cancel timer and don't restart it
          if (newState.showControls) {
            // Controls are now visible - start timer to auto-hide
            _startControlsTimer();
          } else {
            // Controls are now hidden - cancel timer
            _controlsTimer?.cancel();
          }
          },
          onDoubleTapDown: (details) {
          // Double tap: Skip forward/backward
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
                child: playerState.isInitialized && playerState.hasValidController && playerState.controller != null
                    ? Stack(
                        children: [
                          AspectRatio(
                        aspectRatio: playerState.controller!.getAspectRatio() ?? 1.0,
                        child: SafeBetterPlayerWrapper(controller: playerState.controller!),
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
                                      // Removed "Buffering..." text as per requirements
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
                            // Removed "Loading video..." text as per requirements
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
                              // Only exit fullscreen, don't navigate away
                              _toggleFullscreen();
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
                              _buildProgressBar(context, playerState),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Time and controls with modern design
                        Row(
                          children: [
                            // Time display with glass background
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                              _formatDuration(playerState.position),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const Spacer(),
                            // Backward 10 seconds button
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.15),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.replay_10,
                                  color: Colors.white,
                                  size: 26,
                                ),
                                onPressed: () {
                                  // Seek backward without pausing
                                  final wasPlaying = playerState.isPlaying;
                                  notifier.seekBackward();
                                  // Ensure video continues playing
                                  if (wasPlaying && !playerState.isPlaying) {
                                    notifier.play();
                                  }
                                  _startControlsTimer();
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Play/Pause button with prominent gradient
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Theme.of(context).colorScheme.primary,
                                    Theme.of(context).colorScheme.primary.withOpacity(0.8),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                iconSize: 32,
                                icon: Icon(
                                  playerState.isPlaying ? Icons.pause : Icons.play_arrow,
                                  color: Colors.white,
                                ),
                                onPressed: () {
                                  notifier.togglePlayPause();
                                  _startControlsTimer();
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Forward 10 seconds button
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.15),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.forward_10,
                                  color: Colors.white,
                                  size: 26,
                                ),
                                onPressed: () {
                                  notifier.seekForward();
                                  _startControlsTimer();
                                },
                              ),
                            ),
                            const Spacer(),
                            // Playback speed button
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.15),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: IconButton(
                              icon: Stack(
                                children: [
                                    const Icon(
                                    Icons.speed,
                                      color: Colors.white,
                                      size: 24,
                                  ),
                                  if (playerState.playbackSpeed != 1.0)
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      child: Container(
                                          padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.primary,
                                          shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                                                blurRadius: 4,
                                              ),
                                            ],
                                        ),
                                        constraints: const BoxConstraints(
                                            minWidth: 14,
                                            minHeight: 14,
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
                            ),
                            const SizedBox(width: 12),
                            // Fullscreen toggle button
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.15),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: IconButton(
                              icon: Icon(
                                playerState.isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                                  color: Colors.white,
                                  size: 24,
                              ),
                              onPressed: () {
                                _toggleFullscreen();
                                _startControlsTimer();
                              },
                            ),
                            ),
                            const SizedBox(width: 12),
                            // Duration with glass background
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                              _formatDuration(playerState.duration),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
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
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (context) => CommentsBottomSheet(
                                        postId: widget.post?.id ?? '',
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
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (context) => ShareBottomSheet(
                                        postId: widget.post?.id,
                                        videoUrl: widget.videoUrl,
                                        imageUrl: widget.post?.imageUrl,
                                      ),
                                    );
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
    );
  }

  Widget _buildEmbeddedView(VideoPlayerState playerState, VideoPlayerNotifier notifier) {
    return SafeArea(
      child: Column(
        children: [
          // Embedded video player with constrained overlay
          _buildEmbeddedVideoPlayer(playerState, notifier),
          // Scrollable content below video player
          Expanded(
            child: _buildVideoDescriptionContent(playerState, notifier),
          ),
        ],
      ),
    );
  }

  Widget _buildEmbeddedVideoPlayer(VideoPlayerState playerState, VideoPlayerNotifier notifier) {
    const double embeddedHeight = 240.0;
    
    return GestureDetector(
      onTap: () {
        // Close playback speed menu if open
        if (playerState.showPlaybackSpeedMenu) {
          notifier.togglePlaybackSpeedMenu();
        }
        
        // Toggle controls
        notifier.toggleControls();
        
        // Get the new state after toggle
        final newState = ref.read(videoPlayerProvider(widget.videoUrl));
        
        // Only start timer if controls are now visible (to auto-hide them)
        if (newState.showControls) {
          // Controls are now visible - start timer to auto-hide
          _startControlsTimer();
        } else {
          // Controls are now hidden - cancel timer
          _controlsTimer?.cancel();
        }
      },
      onDoubleTapDown: (details) {
        final playerWidth = MediaQuery.of(context).size.width;
        if (details.localPosition.dx < playerWidth / 2) {
          notifier.seekBackward();
        } else {
          notifier.seekForward();
        }
        _startControlsTimer();
      },
      child: Container(
        height: embeddedHeight,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
          child: Stack(
            children: [
            // Video player
            Center(
              child: playerState.isInitialized && playerState.hasValidController && playerState.controller != null
                  ? AspectRatio(
                      aspectRatio: playerState.controller!.getAspectRatio() ?? 1.0,
                      child: SafeBetterPlayerWrapper(controller: playerState.controller!),
                    )
                  : Center(
                      child: CircularProgressIndicator(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
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
            // Overlay controls - beautiful glass effect
            Positioned.fill(
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
                          Colors.black.withOpacity(0.85),
                          Colors.black.withOpacity(0.3),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Progress bar
                        GestureDetector(
                          onHorizontalDragStart: (details) {
                            if (!playerState.showControls) {
                              notifier.toggleControls();
                            }
                            _startControlsTimer();
                          },
                          onHorizontalDragUpdate: (details) {
                            if (!playerState.isInitialized) return;
                            final box = context.findRenderObject() as RenderBox?;
                            if (box == null) return;
                            
                            final padding = 12.0;
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
                            
                            final padding = 12.0;
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
                              _buildProgressBar(context, playerState),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Controls row with modern design
                        Row(
                          children: [
                            // Time display with glass background
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                _formatDuration(playerState.position),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const Spacer(),
                            // Backward 10 seconds with glass background
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.1),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.replay_10, color: Colors.white, size: 22),
                                onPressed: () {
                                  // Seek backward without pausing
                                  final wasPlaying = playerState.isPlaying;
                                  notifier.seekBackward();
                                  // Ensure video continues playing
                                  if (wasPlaying && !playerState.isPlaying) {
                                    notifier.play();
                                  }
                                  _startControlsTimer();
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Play/Pause with gradient background
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Theme.of(context).colorScheme.primary,
                                    Theme.of(context).colorScheme.primary.withOpacity(0.8),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                icon: Icon(
                                  playerState.isPlaying ? Icons.pause : Icons.play_arrow,
                                  color: Colors.white,
                                  size: 26,
                                ),
                                onPressed: () {
                                  notifier.togglePlayPause();
                                  _startControlsTimer();
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Forward 10 seconds with glass background
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.1),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.forward_10, color: Colors.white, size: 22),
                                onPressed: () {
                                  notifier.seekForward();
                                  _startControlsTimer();
                                },
                              ),
                            ),
                            const Spacer(),
                            // Fullscreen toggle with glass background
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.1),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.fullscreen, color: Colors.white, size: 22),
                                onPressed: () {
                                  _toggleFullscreen();
                                  _startControlsTimer();
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Duration with glass background
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                _formatDuration(playerState.duration),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
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
            // Seek indicator
            if (playerState.showSeekIndicator)
              Center(
                child: AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          playerState.seekDirection == 'forward'
                              ? Icons.forward_10
                              : Icons.replay_10,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDuration(playerState.seekTarget),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            // Back button at top left - always visible (placed last to ensure it's on top)
            Positioned(
              top: 8,
              left: 8,
              child: SafeArea(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withOpacity(0.6),
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
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

  Widget _buildVideoDescriptionContent(VideoPlayerState playerState, VideoPlayerNotifier notifier) {
    return Container(
      decoration: BoxDecoration(
        gradient: ThemeHelper.getBackgroundGradient(context),
      ),
          child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Video info section with glass card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  // Text(
                  //   widget.title,
                  //   style: TextStyle(
                  //     color: ThemeHelper.getTextPrimary(context),
                  //     fontSize: 20,
                  //     fontWeight: FontWeight.bold,
                  //     height: 1.3,
                  //   ),
                  // ),
                  // const SizedBox(height: 12),
                  // // Metadata with icons
                  // Row(
                  //   children: [
                  //     Icon(
                  //       Icons.favorite,
                  //       size: 16,
                  //       color: Colors.red,
                  //     ),
                  //     const SizedBox(width: 4),
                  //     Text(
                  //       _formatCount(_likeCount),
                  //       style: TextStyle(
                  //         color: ThemeHelper.getTextSecondary(context),
                  //         fontSize: 14,
                  //         fontWeight: FontWeight.w600,
                  //       ),
                  //     ),
                  //     const SizedBox(width: 20),
                  //     Icon(
                  //       Icons.comment,
                  //       size: 16,
                  //       color: Theme.of(context).colorScheme.primary,
                  //     ),
                  //     const SizedBox(width: 4),
                  //     Text(
                  //       _formatCount(_commentCount),
                  //       style: TextStyle(
                  //         color: ThemeHelper.getTextSecondary(context),
                  //         fontSize: 14,
                  //         fontWeight: FontWeight.w600,
                  //       ),
                  //     ),
                  //   ],
                  // ),
                  // const SizedBox(height: 16),
                  // Divider
                  // Container(
                  //   height: 1,
                  //   decoration: BoxDecoration(
                  //     gradient: LinearGradient(
                  //       colors: [
                  //         Colors.transparent,
                  //         ThemeHelper.getBorderColor(context),
                  //         Colors.transparent,
                  //       ],
                  //     ),
                  //   ),
                  // ),
                  // const SizedBox(height: 16),
                  // Author info and action buttons row
                  Row(
                    children: [
                      // Author image
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 20,
                          backgroundImage: NetworkImage(widget.author.avatarUrl),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Author name and followers in column
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.author.displayName,
                              style: TextStyle(
                                color: ThemeHelper.getTextPrimary(context),
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_formatCount(widget.author.followers)} followers',
                              style: TextStyle(
                                color: ThemeHelper.getTextSecondary(context),
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {},
                            borderRadius: BorderRadius.circular(999),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Text(
                                'Follow',
                                style: TextStyle(
                                  color: context.buttonTextColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Share icon
                      GestureDetector(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => ShareBottomSheet(
                              postId: widget.post?.id,
                              videoUrl: widget.videoUrl,
                              imageUrl: widget.post?.imageUrl,
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
                                size: 24,
                                color: ThemeHelper.getTextPrimary(context),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatCount(widget.post?.shares ?? 0),
                              style: TextStyle(
                                color: ThemeHelper.getTextSecondary(context),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Comments icon
                      GestureDetector(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => CommentsBottomSheet(
                              postId: widget.post?.id ?? '',
                            ),
                          );
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.mode_comment_outlined,
                              size: 24,
                              color: ThemeHelper.getTextPrimary(context),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatCount(_commentCount),
                              style: TextStyle(
                                color: ThemeHelper.getTextSecondary(context),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Heart icon
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isLiked = !_isLiked;
                            _likeCount += _isLiked ? 1 : -1;
                          });
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isLiked ? Icons.favorite : Icons.favorite_border,
                              size: 24,
                              color: _isLiked ? Colors.red : ThemeHelper.getTextPrimary(context),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatCount(_likeCount),
                              style: TextStyle(
                                color: ThemeHelper.getTextSecondary(context),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Views display with eye icon and time ago
                  Row(
                    children: [
                      Icon(
                        Icons.visibility_outlined,
                        size: 18,
                        color: ThemeHelper.getTextSecondary(context),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.post != null
                            ? ' ${_formatCount((widget.post!.likes) * 10)} views • ${_formatTimeAgo(widget.post!.createdAt)}'
                            : '${_formatCount((_likeCount) * 10)} views',
                        style: TextStyle(
                          color: ThemeHelper.getTextSecondary(context),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Description
                  Text(
                    widget.post?.caption ?? widget.title,
                    style: TextStyle(
                      color: ThemeHelper.getTextPrimary(context),
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Suggested videos header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.primary.withOpacity(0.5),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Suggested Videos',
                  style: TextStyle(
                    color: ThemeHelper.getTextPrimary(context),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Suggested videos list
          _buildSuggestedVideosList(),
          const SizedBox(height: 16),
        ],
      ),
      ),
    );
  }

  Widget _buildDescriptionActionButton({
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
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  List<PostModel> _getSuggestedVideos() {
    // Return cached videos if they exist to prevent changing during playback
    if (_cachedSuggestedVideos != null) {
      return _cachedSuggestedVideos!;
    }
    
    // Get suggested videos from mock data - show exactly 3 unique videos
    final allPosts = MockDataService.getMockPosts();
    var suggestedVideos = allPosts
        .where((p) => p.isVideo && p.id != widget.post?.id)
        .toList();
    
    // Generate additional videos if needed to ensure we have enough unique videos
    if (suggestedVideos.length < 3) {
      final additionalVideos = List.generate(10, (index) {
        final userIndex = index % MockDataService.mockUsers.length;
        return PostModel(
          id: 'suggested_video_${index + 100}',
          author: MockDataService.mockUsers[userIndex],
          videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
          thumbnailUrl: 'https://picsum.photos/800/450?random=${index + 200}',
          caption: 'Suggested video ${index + 1}',
          createdAt: DateTime.now().subtract(Duration(hours: index)),
          likes: (index + 1) * 500,
          comments: (index + 1) * 25,
          shares: (index + 1) * 10,
          isLiked: false,
          videoDuration: Duration(minutes: index % 10 + 1, seconds: (index * 7) % 60),
          isVideo: true,
        );
      });
      suggestedVideos.addAll(additionalVideos);
    }
    
    // Filter out current video again in case it was in additional videos
    suggestedVideos = suggestedVideos
        .where((p) => p.id != widget.post?.id)
        .toList();
    
    // Shuffle to get different videos each time (only once when first loading)
    suggestedVideos.shuffle();
    
    // Take exactly 3 videos
    suggestedVideos = suggestedVideos.take(3).toList();
    
    // Cache the videos so they don't change during playback
    _cachedSuggestedVideos = suggestedVideos;
    
    return suggestedVideos;
  }

  Widget _buildSuggestedVideosList() {
    final suggestedVideos = _getSuggestedVideos();

    if (suggestedVideos.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: suggestedVideos.length,
      itemBuilder: (context, index) {
        final video = suggestedVideos[index];
        return _buildSuggestedVideoItem(video);
      },
    );
  }

  Widget _buildSuggestedVideoItem(PostModel video) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        onTap: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => VideoPlayerScreen(
                videoUrl: video.videoUrl ?? '',
                title: video.caption,
                author: video.author,
                post: video,
              ),
            ),
          );
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail with gradient overlay
            Container(
              width: 140,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    Colors.transparent,
                  ],
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    video.thumbnailUrl != null
                        ? Image.network(
                            video.thumbnailUrl!,
                            width: 140,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: ThemeHelper.getSurfaceColor(context),
                                child: Icon(
                                  Icons.video_library,
                                  color: ThemeHelper.getTextSecondary(context),
                                ),
                              );
                            },
                          )
                        : Container(
                            color: ThemeHelper.getSurfaceColor(context),
                            child: Icon(
                              Icons.video_library,
                              color: ThemeHelper.getTextSecondary(context),
                            ),
                          ),
                    // Duration badge
                    if (video.videoDuration != null)
                      Positioned(
                        bottom: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _formatDuration(video.videoDuration!),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Video info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    video.caption,
                    style: TextStyle(
                      color: ThemeHelper.getTextPrimary(context),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    video.author.displayName,
                    style: TextStyle(
                      color: ThemeHelper.getTextSecondary(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.play_circle_outline,
                        size: 14,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_formatCount(video.likes)} views',
                        style: TextStyle(
                          color: ThemeHelper.getTextSecondary(context),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
