import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;
import '../../core/utils/theme_helper.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/models/music_model.dart';
import '../../core/widgets/glass_card.dart';

/// Beautiful modern music player screen with theme awareness
class MusicPlayerScreen extends StatefulWidget {
  final MusicModel track;
  final List<MusicModel> tracks;
  final int initialIndex;

  const MusicPlayerScreen({
    super.key,
    required this.track,
    required this.tracks,
    this.initialIndex = 0,
  });

  @override
  State<MusicPlayerScreen> createState() => _MusicPlayerScreenState();
}

class _MusicPlayerScreenState extends State<MusicPlayerScreen>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _playPauseController;
  late AnimationController _likeController;
  late AnimationController _waveController;
  Timer? _progressTimer;
  Duration _currentPosition = Duration.zero;
  bool _isPlaying = false;
  bool _isLiked = false;
  bool _isRepeat = false;
  bool _isShuffle = false;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _isLiked = widget.track.isLiked;
    
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );
    
    _playPauseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _likeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    
    if (_isLiked) _likeController.forward();
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _rotationController.dispose();
    _playPauseController.dispose();
    _likeController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    if (_isPlaying) {
      _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        if (mounted) {
          setState(() {
            _currentPosition = Duration(
              milliseconds: _currentPosition.inMilliseconds + 100,
            );
            if (_currentPosition >= widget.tracks[_currentIndex].duration) {
              _currentPosition = Duration.zero;
              if (_isRepeat) {
                // Repeat current track
              } else {
                _nextTrack();
              }
            }
          });
        }
      });
    }
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
    });
    if (_isPlaying) {
      _rotationController.repeat();
      _playPauseController.forward();
      _startProgressTimer();
    } else {
      _rotationController.stop();
      _playPauseController.reverse();
      _progressTimer?.cancel();
    }
  }

  void _toggleLike() {
    setState(() {
      _isLiked = !_isLiked;
    });
    if (_isLiked) {
      _likeController.forward();
    } else {
      _likeController.reverse();
    }
  }

  void _previousTrack() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _currentPosition = Duration.zero;
        _isLiked = widget.tracks[_currentIndex].isLiked;
        if (_isLiked) {
          _likeController.forward();
        } else {
          _likeController.reverse();
        }
      });
    }
  }

  void _nextTrack() {
    if (_currentIndex < widget.tracks.length - 1) {
      setState(() {
        _currentIndex++;
        _currentPosition = Duration.zero;
        _isLiked = widget.tracks[_currentIndex].isLiked;
        if (_isLiked) {
          _likeController.forward();
        } else {
          _likeController.reverse();
        }
      });
    } else if (_isRepeat) {
      setState(() {
        _currentIndex = 0;
        _currentPosition = Duration.zero;
        _isLiked = widget.tracks[_currentIndex].isLiked;
      });
    } else {
      setState(() {
        _currentPosition = Duration.zero;
        _isPlaying = false;
        _rotationController.stop();
        _playPauseController.reverse();
        _progressTimer?.cancel();
      });
    }
  }

  void _seekTo(Duration position) {
    setState(() {
      _currentPosition = position;
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  @override
  Widget build(BuildContext context) {
    final currentTrack = widget.tracks[_currentIndex];
    final progress = currentTrack.duration.inMilliseconds > 0
        ? _currentPosition.inMilliseconds / currentTrack.duration.inMilliseconds
        : 0.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: BoxDecoration(
          gradient: ThemeHelper.getBackgroundGradient(context),
        ),
        child: Stack(
          children: [
            // Blurred Background
            _buildBlurredBackground(currentTrack),
            
            // Content
            SafeArea(
              child: Column(
                children: [
                  // App Bar
                  _buildAppBar(currentTrack),
                  
                  // Album Art Section
                  Expanded(
                    flex: 2,
                    child: _buildAlbumArtSection(currentTrack),
                  ),
                  
                  // Controls Section
                  Expanded(
                    flex: 2,
                    child: _buildControlsSection(currentTrack, progress),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlurredBackground(MusicModel track) {
    return Positioned.fill(
      child: Hero(
        tag: 'track_${track.id}_bg',
        child: track.coverUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: track.coverUrl,
                fit: BoxFit.cover,
                imageBuilder: (context, imageProvider) {
                  return Container(
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: imageProvider,
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              ThemeHelper.getBackgroundColor(context).withOpacity(0.6),
                              ThemeHelper.getBackgroundColor(context).withOpacity(0.9),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              )
            : Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      ThemeHelper.getBackgroundColor(context).withOpacity(0.6),
                      ThemeHelper.getBackgroundColor(context).withOpacity(0.9),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildAppBar(MusicModel track) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: ThemeHelper.getSurfaceColor(context).withOpacity(0.3),
                shape: BoxShape.circle,
                border: Border.all(
                  color: ThemeHelper.getBorderColor(context),
                  width: 1,
                ),
              ),
              child: Icon(
                CupertinoIcons.chevron_down,
                color: ThemeHelper.getTextPrimary(context),
                size: 24,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                children: [
                  Text(
                    'Now Playing',
                    style: TextStyle(
                      color: ThemeHelper.getTextPrimary(context),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    track.album,
                    style: TextStyle(
                      color: ThemeHelper.getTextSecondary(context),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              // Show queue/options
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: ThemeHelper.getSurfaceColor(context).withOpacity(0.3),
                shape: BoxShape.circle,
                border: Border.all(
                  color: ThemeHelper.getBorderColor(context),
                  width: 1,
                ),
              ),
              child: Icon(
                CupertinoIcons.list_bullet,
                color: ThemeHelper.getTextPrimary(context),
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumArtSection(MusicModel track) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Vinyl Record Effect with Waves
          Stack(
            alignment: Alignment.center,
            children: [
              // Animated waves
              ...List.generate(3, (index) {
                return AnimatedBuilder(
                  animation: _waveController,
                  builder: (context, child) {
                    final delay = index * 0.33;
                    final animValue = (_waveController.value + delay) % 1.0;
                    return Container(
                      width: 300 + (animValue * 80),
                      height: 300 + (animValue * 80),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: ThemeHelper.getAccentColor(context)
                              .withOpacity((1 - animValue) * 0.3),
                          width: 2,
                        ),
                      ),
                    );
                  },
                );
              }),
              
              // Main Album Art
              AnimatedBuilder(
                animation: _rotationController,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _isPlaying
                        ? _rotationController.value * 2 * math.pi
                        : 0,
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: ThemeHelper.getAccentColor(context)
                                .withOpacity(0.4),
                            blurRadius: 60,
                            spreadRadius: 20,
                          ),
                          BoxShadow(
                            color: ThemeHelper.getBackgroundColor(context).withOpacity(0.3),
                            blurRadius: 40,
                            spreadRadius: 10,
                            offset: const Offset(0, 20),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          // Outer ring (vinyl)
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  ThemeHelper.getBackgroundColor(context).withOpacity(0.8),
                                  ThemeHelper.getBackgroundColor(context).withOpacity(0.4),
                                ],
                              ),
                            ),
                          ),
                          // Album cover
                          Center(
                            child: Hero(
                              tag: 'track_${track.id}',
                              child: ClipOval(
                                child: Container(
                                  width: 200,
                                  height: 200,
                                  child: track.coverUrl.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: track.coverUrl,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) => Container(
                                            color: ThemeHelper.getSurfaceColor(context),
                                            child: Center(
                                              child: CupertinoActivityIndicator(
                                                color: ThemeHelper.getAccentColor(context),
                                              ),
                                            ),
                                          ),
                                          errorWidget: (context, url, error) => Container(
                                            color: ThemeHelper.getSurfaceColor(context),
                                            child: Icon(
                                              CupertinoIcons.music_note_2,
                                              color: ThemeHelper.getTextSecondary(context),
                                              size: 60,
                                            ),
                                          ),
                                        )
                                      : Container(
                                          color: ThemeHelper.getSurfaceColor(context),
                                          child: Icon(
                                            CupertinoIcons.music_note_2,
                                            color: ThemeHelper.getTextSecondary(context),
                                            size: 60,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),
                          // Center dot
                          Center(
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: ThemeHelper.getBackgroundColor(context).withOpacity(0.6),
                                border: Border.all(
                                  color: ThemeHelper.getBorderColor(context),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlsSection(MusicModel track, double progress) {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Track Info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                children: [
                  Text(
                    track.title,
                    style: TextStyle(
                      color: ThemeHelper.getTextPrimary(context),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    track.artist,
                    style: TextStyle(
                      color: ThemeHelper.getTextSecondary(context),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Progress Bar
            _buildEnhancedProgressBar(track, progress),
            
            const SizedBox(height: 32),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
              _buildActionButton(
                icon: CupertinoIcons.shuffle,
                isActive: _isShuffle,
                onTap: () {
                  setState(() {
                    _isShuffle = !_isShuffle;
                  });
                },
              ),
              _buildActionButton(
                icon: _isLiked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                isActive: _isLiked,
                color: _isLiked ? Colors.red : null,
                onTap: _toggleLike,
                scale: _likeController,
              ),
              _buildActionButton(
                icon: CupertinoIcons.repeat,
                isActive: _isRepeat,
                onTap: () {
                  setState(() {
                    _isRepeat = !_isRepeat;
                  });
                },
              ),
            ],
          ),
          
          const SizedBox(height: 24),

          // Playback Controls
          _buildPlaybackControls(),
          
          const SizedBox(height: 16),
          
          // Track Counter
          if (widget.tracks.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${_currentIndex + 1} of ${widget.tracks.length}',
                style: TextStyle(
                  color: ThemeHelper.getTextMuted(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedProgressBar(MusicModel track, double progress) {
    return Column(
      children: [
        Stack(
          children: [
            // Background track
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: ThemeHelper.getSurfaceColor(context).withOpacity(0.5),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            // Progress track
            FractionallySizedBox(
              widthFactor: progress.clamp(0.0, 1.0),
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      ThemeHelper.getAccentColor(context),
                      ThemeHelper.getAccentColor(context).withOpacity(0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: [
                    BoxShadow(
                      color: ThemeHelper.getAccentColor(context).withOpacity(0.5),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
            // Interactive slider
            Positioned.fill(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 6,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 0,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 16,
                  ),
                  activeTrackColor: Colors.transparent,
                  inactiveTrackColor: Colors.transparent,
                ),
                child: Slider(
                  value: progress.clamp(0.0, 1.0),
                  onChanged: (value) {
                    final newPosition = Duration(
                      milliseconds: (value * track.duration.inMilliseconds).round(),
                    );
                    _seekTo(newPosition);
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(_currentPosition),
                style: TextStyle(
                  color: ThemeHelper.getTextSecondary(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                _formatDuration(track.duration),
                style: TextStyle(
                  color: ThemeHelper.getTextSecondary(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
    bool isActive = false,
    Color? color,
    Animation<double>? scale,
  }) {
    Widget button = GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: isActive
              ? (color ?? ThemeHelper.getAccentColor(context)).withOpacity(0.2)
              : ThemeHelper.getSurfaceColor(context).withOpacity(0.3),
          shape: BoxShape.circle,
          border: Border.all(
            color: isActive
                ? (color ?? ThemeHelper.getAccentColor(context)).withOpacity(0.5)
                : ThemeHelper.getBorderColor(context),
            width: 1.5,
          ),
        ),
        child: Icon(
          icon,
          color: isActive
              ? (color ?? ThemeHelper.getAccentColor(context))
              : ThemeHelper.getTextPrimary(context),
          size: 24,
        ),
      ),
    );

    if (scale != null) {
      return ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 1.2).animate(
          CurvedAnimation(parent: scale, curve: Curves.easeInOut),
        ),
        child: button,
      );
    }

    return button;
  }

  Widget _buildPlaybackControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Previous
        _buildControlButton(
          icon: CupertinoIcons.backward_end_fill,
          size: 36,
          onTap: _currentIndex > 0 ? _previousTrack : null,
        ),
        const SizedBox(width: 24),

        // Play/Pause (Large)
        GestureDetector(
          onTap: _togglePlayPause,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  ThemeHelper.getAccentColor(context),
                  ThemeHelper.getAccentColor(context).withOpacity(0.8),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: ThemeHelper.getAccentColor(context).withOpacity(0.5),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
                BoxShadow(
                  color: ThemeHelper.getBackgroundColor(context).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(
              _isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
              color: ThemeHelper.getOnAccentColor(context),
              size: 38,
            ),
          ),
        ),
        const SizedBox(width: 24),

        // Next
        _buildControlButton(
          icon: CupertinoIcons.forward_end_fill,
          size: 36,
          onTap: _currentIndex < widget.tracks.length - 1 ? _nextTrack : null,
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required double size,
    VoidCallback? onTap,
  }) {
    final isEnabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: ThemeHelper.getSurfaceColor(context).withOpacity(isEnabled ? 0.3 : 0.1),
          shape: BoxShape.circle,
          border: Border.all(
            color: ThemeHelper.getBorderColor(context).withOpacity(isEnabled ? 1.0 : 0.5),
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          color: isEnabled 
              ? ThemeHelper.getTextPrimary(context)
              : ThemeHelper.getTextMuted(context),
          size: size,
        ),
      ),
    );
  }
}
