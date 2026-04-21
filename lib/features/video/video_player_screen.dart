import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:better_player/better_player.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/providers/auth_provider_riverpod.dart';
import '../../core/providers/follow_provider_riverpod.dart';
import '../../core/providers/posts_provider_riverpod.dart';
import '../long_videos/providers/long_videos_provider.dart';
import '../../core/providers/video_player_provider.dart';
import '../../core/models/user_model.dart';
import '../../core/models/post_model.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/comments_bottom_sheet.dart';
import '../../core/widgets/share_bottom_sheet.dart';
import '../../core/widgets/safe_better_player.dart';
import '../../core/utils/share_link_helper.dart';
import '../profile/profile_screen.dart';

int _asmsTrackSortHeight(BetterPlayerAsmsTrack t) {
  final h = t.height;
  if (h != null && h > 0) return h;
  final w = t.width;
  if (w != null && w > 0) return w;
  return 0;
}

String _asmsTrackLabelFallback(BetterPlayerAsmsTrack t) {
  final h = t.height;
  if (h != null && h > 0) return '${h}p';
  final br = t.bitrate;
  if (br != null && br > 0) {
    return '${(br / 1000000).toStringAsFixed(1)} Mbps';
  }
  final id = t.id;
  if (id != null && id.isNotEmpty) return id;
  return 'Quality';
}

/// YouTube-style labels for HLS ladder rows (Auto is separate in the UI).
String _resolutionLabelYoutubeStyle(BetterPlayerAsmsTrack t) {
  final h = t.height;
  if (h != null && h > 0) {
    if (h >= 4320) return '4320p (8K)';
    if (h >= 2160) return '2160p (4K)';
    if (h >= 1440) return '1440p';
    if (h >= 1080) return '1080p HD';
    if (h >= 720) return '720p HD';
    if (h >= 480) return '480p';
    if (h >= 360) return '360p';
    if (h >= 240) return '240p';
    if (h >= 144) return '144p';
    return '${h}p';
  }
  return _asmsTrackLabelFallback(t);
}

List<BetterPlayerAsmsTrack> _asmsTracksDescendingByResolution(
    List<BetterPlayerAsmsTrack> tracks) {
  final list = [...tracks];
  list.sort((a, b) {
    final ha = _asmsTrackSortHeight(a);
    final hb = _asmsTrackSortHeight(b);
    if (ha != hb) return hb.compareTo(ha);
    return (b.bitrate ?? 0).compareTo(a.bitrate ?? 0);
  });
  return list;
}

/// Long-form video player with Riverpod state management
class VideoPlayerScreen extends ConsumerStatefulWidget {
  final String videoUrl;
  final String title;
  final UserModel author;
  final PostModel? post;

  /// When set (embedded long-video session host), suggested videos switch in-place
  /// instead of [Navigator.pushReplacement], matching feed stability and reducing
  /// decoder/surface churn.
  final ValueChanged<PostModel>? onSuggestedLongVideoSelected;

  const VideoPlayerScreen({
    super.key,
    required this.videoUrl,
    required this.title,
    required this.author,
    this.post,
    this.onSuggestedLongVideoSelected,
  });

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen>
    with WidgetsBindingObserver {
  String? _betterPlayerLayoutSig;

  bool _isLiked = false;
  int _likeCount = 0;
  int _commentCount = 0;
  Timer? _controlsTimer;
  VideoPlayerNotifier? _cachedNotifier;

  /// Embedded long-video scroll: hide details until player is ready; suggested list loads async.
  bool _embeddedDetailsReady = false;
  bool _embeddedSuggestedReady = false;
  bool _embeddedDetailsRevealScheduled = false;
  bool _embeddedDetailsFallbackScheduled = false;

  bool _deferEmbeddedShimmers() {
    final p = widget.post;
    return p == null || p.postType == 'longVideo';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (widget.post != null) {
      _isLiked = widget.post!.isLiked;
      _likeCount = widget.post!.likes;
      _commentCount = widget.post!.comments;
    }

    // Never call ref.read / _startControlsTimer in initState — the element is
    // not yet safe for ProviderScope (crashes opening from long-video search).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _startControlsTimer();
      try {
        _cachedNotifier =
            ref.read(videoPlayerProvider(widget.videoUrl).notifier);
        _startVideoPlayback();
      } catch (_) {}
      if (_deferEmbeddedShimmers()) {
        unawaited(_loadEmbeddedSuggestedSectionReady());
      }
    });
  }

  Future<void> _loadEmbeddedSuggestedSectionReady() async {
    if (!_deferEmbeddedShimmers() || !mounted) return;
    final lv0 = ref.read(longVideosProvider);
    final waitingForFeed = lv0.isLoading && !lv0.initialFetchCompleted;
    if (waitingForFeed) {
      setState(() => _embeddedSuggestedReady = false);
    }

    var waited = 0;
    while (mounted && context.mounted && waited < 4000) {
      final lv = ref.read(longVideosProvider);
      if (!lv.isLoading || lv.initialFetchCompleted) break;
      await Future<void>.delayed(const Duration(milliseconds: 100));
      waited += 100;
    }
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted || !context.mounted) return;
    if (_embeddedSuggestedReady != true) {
      setState(() => _embeddedSuggestedReady = true);
    }
  }

  @override
  void didUpdateWidget(VideoPlayerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _betterPlayerLayoutSig = null;
      _embeddedDetailsReady = false;
      _embeddedDetailsRevealScheduled = false;
      _embeddedDetailsFallbackScheduled = false;
      if (_deferEmbeddedShimmers()) {
        final lv = ref.read(longVideosProvider);
        if (lv.isLoading && !lv.initialFetchCompleted) {
          _embeddedSuggestedReady = false;
        }
        unawaited(_loadEmbeddedSuggestedSectionReady());
      }
      final newUrl = widget.videoUrl;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || widget.videoUrl != newUrl) return;
        try {
          _cachedNotifier =
              ref.read(videoPlayerProvider(widget.videoUrl).notifier);
          if (widget.post != null) {
            setState(() {
              _isLiked = widget.post!.isLiked;
              _likeCount = widget.post!.likes;
              _commentCount = widget.post!.comments;
            });
          }
          _startVideoPlayback();
        } catch (_) {}
      });
    } else if (oldWidget.post?.id != widget.post?.id && widget.post != null) {
      setState(() {
        _isLiked = widget.post!.isLiked;
        _likeCount = widget.post!.likes;
        _commentCount = widget.post!.comments;
      });
    }
  }

  Future<void> _toggleLikeApi() async {
    final post = widget.post;
    if (post == null) return;
    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });
    if (post.postType == 'longVideo') {
      await ref.read(longVideosProvider.notifier).toggleLikeWithApi(post.id);
      if (!mounted) return;
      final liked = ref.read(longVideoLikedProvider(post.id));
      final count = ref.read(longVideoLikeCountProvider(post.id));
      setState(() {
        _isLiked = liked;
        _likeCount = count;
      });
      return;
    }
    await ref.read(postsProvider.notifier).toggleLikeWithApi(post.id);
    if (!mounted) return;
    final liked = ref.read(postLikedProvider(post.id));
    final count = ref.read(postLikeCountProvider(post.id));
    setState(() {
      _isLiked = liked;
      _likeCount = count;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Pause video when app goes to background
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
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
          ref
              .read(videoPlayerProvider(widget.videoUrl).notifier)
              .toggleControls();
        }
      }
    });
  }

  void _startVideoPlayback() {
    if (!mounted) return;

    try {
      final notifier = _cachedNotifier ??
          ref.read(videoPlayerProvider(widget.videoUrl).notifier);
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

  bool _isValidRemoteUrl(String? value) {
    if (value == null || value.trim().isEmpty) return false;
    final uri = Uri.tryParse(value.trim());
    if (uri == null) return false;
    if (!(uri.scheme == 'http' || uri.scheme == 'https')) return false;
    return uri.host.isNotEmpty;
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                    final postId = widget.post?.id;
                    final thumb = widget.post?.effectiveThumbnailUrl;
                    if (postId == null || postId.isEmpty) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Unable to copy link for this content',
                            style: TextStyle(
                                color: ThemeHelper.getTextPrimary(context)),
                          ),
                          backgroundColor: ThemeHelper.getSurfaceColor(context)
                              .withOpacity(0.95),
                        ),
                      );
                      return;
                    }

                    final link = ShareLinkHelper.build(
                      contentId: postId,
                      thumbnailUrl: thumb,
                    );

                    Navigator.pop(context);
                    Clipboard.setData(ClipboardData(text: link));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Link copied!',
                          style: TextStyle(
                            color: ThemeHelper.getTextPrimary(context),
                          ),
                        ),
                        backgroundColor: ThemeHelper.getSurfaceColor(context)
                            .withOpacity(0.95),
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

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(videoPlayerProvider(widget.videoUrl));

    // Ensure cached notifier is available
    if (_cachedNotifier == null) {
      _cachedNotifier = ref.read(videoPlayerProvider(widget.videoUrl).notifier);
    }

    final notifier = _cachedNotifier!;

    _syncBetterPlayerLayout(playerState);

    if (_deferEmbeddedShimmers() && !_embeddedDetailsReady) {
      final ready = playerState.isInitialized &&
          playerState.hasValidController &&
          playerState.controller != null;
      if (ready && !_embeddedDetailsRevealScheduled) {
        _embeddedDetailsRevealScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _embeddedDetailsReady = true);
        });
      }
      if (!ready && !_embeddedDetailsFallbackScheduled) {
        _embeddedDetailsFallbackScheduled = true;
        Future<void>.delayed(const Duration(seconds: 12), () {
          if (mounted && !_embeddedDetailsReady) {
            setState(() => _embeddedDetailsReady = true);
          }
        });
      }
    }

    return PopScope(
      canPop: !playerState.isFullscreen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _toggleFullscreen();
          return;
        }
        try {
          ref
              .read(videoPlayerProvider(widget.videoUrl).notifier)
              .transferToLongVideoFeedIfPossibleSync();
        } catch (_) {}
        if (_cachedNotifier != null) {
          try {
            _cachedNotifier!.pause();
          } catch (_) {}
        }
        try {
          final s = ref.read(videoPlayerProvider(widget.videoUrl));
          if (s.controller != null && s.isInitialized && s.isPlaying) {
            s.controller!.pause();
          }
        } catch (_) {}
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
    final progress =
        durationMs > 0 ? (positionMs / durationMs).clamp(0.0, 1.0) : 0.0;
    return SizedBox(
      height: 4,
      child: LinearProgressIndicator(
        value: progress,
        backgroundColor: Colors.white.withOpacity(0.2),
        valueColor: AlwaysStoppedAnimation<Color>(
            Theme.of(context).colorScheme.primary),
      ),
    );
  }

  void _syncBetterPlayerLayout(VideoPlayerState ps) {
    final c = ps.controller;
    if (!ps.hasValidController || c == null) return;
    final vpc = c.videoPlayerController;
    var ar = 16 / 9;
    final av = vpc?.value.aspectRatio;
    if (av != null && av > 0.01) {
      ar = av;
    }
    final sig = '${ps.isFullscreen}_${ar.toStringAsFixed(4)}';
    if (_betterPlayerLayoutSig == sig) return;
    _betterPlayerLayoutSig = sig;
    if (ps.isFullscreen) {
      c.setOverriddenFit(BoxFit.cover);
    } else {
      c.setOverriddenFit(BoxFit.contain);
    }
    c.setOverriddenAspectRatio(ar);
  }

  /// Letterboxed size for [aspectRatio] inside a [maxWidth]×[maxHeight] slot (YouTube-style).
  Size _letterboxedVideoSize(
      double maxWidth, double maxHeight, double aspectRatio) {
    final a = aspectRatio <= 0.01 ? 16 / 9 : aspectRatio;
    if (maxWidth / maxHeight > a) {
      final h = maxHeight;
      final w = h * a;
      return Size(w, h);
    }
    final w = maxWidth;
    final h = w / a;
    return Size(w, h);
  }

  Future<void> _showPlaybackQualitySheet(
    VideoPlayerNotifier notifier,
    VideoPlayerState playerState, {
    bool nestedRootMenu = false,
  }) async {
    if (!mounted) return;
    if (playerState.showPlaybackSpeedMenu) {
      notifier.togglePlaybackSpeedMenu();
    }
    if (nestedRootMenu) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _LongVideoEmbeddedPlaybackRootSheet(
          videoUrl: widget.videoUrl,
          notifier: notifier,
          onFinished: _startControlsTimer,
        ),
      );
      return;
    }
    final tracks = playerState.controller?.betterPlayerAsmsTracks ?? [];
    const speeds = <double>[0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.48,
          minChildSize: 0.32,
          maxChildSize: 0.88,
          builder: (_, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: ThemeHelper.getSurfaceColor(context),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border.all(
                  color: ThemeHelper.getBorderColor(context).withValues(alpha: 0.35),
                ),
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  const SizedBox(height: 10),
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: ThemeHelper.getBorderColor(context)
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Text(
                      'Playback & quality',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: ThemeHelper.getTextPrimary(context),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                    child: Text(
                      'Speed',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: ThemeHelper.getTextSecondary(context),
                      ),
                    ),
                  ),
                  for (final s in speeds)
                    ListTile(
                      title: Text(
                        s == 1.0 ? 'Normal (1.0×)' : '${s.toString()}×',
                        style: TextStyle(
                          color: ThemeHelper.getTextPrimary(context),
                          fontWeight: playerState.playbackSpeed == s
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      trailing: playerState.playbackSpeed == s
                          ? Icon(Icons.check,
                              color: ThemeHelper.getAccentColor(context))
                          : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        unawaited(notifier.setPlaybackSpeed(s));
                        _startControlsTimer();
                      },
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                    child: Text(
                      'Quality',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: ThemeHelper.getTextSecondary(context),
                      ),
                    ),
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.auto_awesome_motion,
                      color: ThemeHelper.getAccentColor(context),
                    ),
                    title: Text(
                      'Auto (recommended)',
                      style: TextStyle(
                        color: ThemeHelper.getTextPrimary(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'Uses connection type to pick a rung.',
                      style: TextStyle(
                        fontSize: 12,
                        color: ThemeHelper.getTextMuted(context),
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      unawaited(notifier.applyAutoQualityIfAdaptive(
                        settleDelay: Duration.zero,
                      ));
                      _startControlsTimer();
                    },
                  ),
                  if (tracks.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'No separate quality rungs for this stream (e.g. progressive MP4).',
                        style: TextStyle(
                          fontSize: 12,
                          color: ThemeHelper.getTextMuted(context),
                        ),
                      ),
                    )
                  else
                    for (final t in _asmsTracksDescendingByResolution(tracks))
                      ListTile(
                        leading: Icon(
                          Icons.high_quality_outlined,
                          color: ThemeHelper.getTextSecondary(context),
                        ),
                        title: Text(
                          _resolutionLabelYoutubeStyle(t),
                          style: TextStyle(
                            color: ThemeHelper.getTextPrimary(context),
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          unawaited(notifier.setVideoQualityTrack(t));
                          _startControlsTimer();
                        },
                      ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Fullscreen stack: top-right fullscreen + overflow (YouTube-style).
  Widget _buildTopRightVideoActions(
    VideoPlayerState playerState,
    VideoPlayerNotifier notifier,
  ) {
    final top = MediaQuery.paddingOf(context).top + 4;
    return Positioned(
      top: top,
      right: 8,
      child: Material(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(24),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip:
                  playerState.isFullscreen ? 'Exit fullscreen' : 'Fullscreen',
              icon: Icon(
                playerState.isFullscreen
                    ? Icons.fullscreen_exit
                    : Icons.fullscreen,
                color: Colors.white,
                size: 24,
              ),
              onPressed: () {
                _toggleFullscreen();
                _startControlsTimer();
              },
            ),
            IconButton(
              tooltip: 'Playback and quality',
              icon: const Icon(Icons.more_vert, color: Colors.white, size: 24),
              onPressed: () {
                unawaited(_showPlaybackQualitySheet(notifier, playerState));
                _startControlsTimer();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullscreenView(
      VideoPlayerState playerState, VideoPlayerNotifier notifier) {
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
              child: playerState.isInitialized &&
                      playerState.hasValidController &&
                      playerState.controller != null
                  ? Stack(
                      children: [
                        AspectRatio(
                          aspectRatio:
                              playerState.controller!.getAspectRatio() ?? 1.0,
                          child: SafeBetterPlayerWrapper(
                              controller: playerState.controller!),
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
            _buildTopRightVideoActions(playerState, notifier),

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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
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
                                icon: const Icon(CupertinoIcons.back,
                                    color: Colors.white, size: 26),
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
                                      color:
                                          Colors.white.withValues(alpha: 0.8),
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
                            final box =
                                context.findRenderObject() as RenderBox?;
                            if (box == null) return;

                            // Calculate progress with padding consideration
                            final padding = 20.0; // Match container padding
                            final dragPosition =
                                (details.localPosition.dx - padding)
                                    .clamp(0.0, box.size.width - padding * 2);
                            final totalWidth = (box.size.width - padding * 2)
                                .clamp(1.0, double.infinity);
                            final progress =
                                (dragPosition / totalWidth).clamp(0.0, 1.0);
                            final targetPosition = Duration(
                              milliseconds:
                                  (playerState.duration.inMilliseconds *
                                          progress)
                                      .round(),
                            );
                            notifier.seekTo(targetPosition);
                          },
                          onHorizontalDragEnd: (_) {
                            _startControlsTimer();
                          },
                          onTapDown: (details) {
                            if (!playerState.isInitialized) return;
                            final box =
                                context.findRenderObject() as RenderBox?;
                            if (box == null) return;

                            // Tap to seek
                            final padding = 20.0;
                            final tapPosition =
                                (details.localPosition.dx - padding)
                                    .clamp(0.0, box.size.width - padding * 2);
                            final totalWidth = (box.size.width - padding * 2)
                                .clamp(1.0, double.infinity);
                            final progress =
                                (tapPosition / totalWidth).clamp(0.0, 1.0);
                            final targetPosition = Duration(
                              milliseconds:
                                  (playerState.duration.inMilliseconds *
                                          progress)
                                      .round(),
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
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
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
                                    Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withOpacity(0.8),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withOpacity(0.5),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                iconSize: 32,
                                icon: Icon(
                                  playerState.isPlaying
                                      ? Icons.pause
                                      : Icons.play_arrow,
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
                            // Duration with glass background
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
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
                        icon: const Icon(CupertinoIcons.back, size: 28),
                        color: ThemeHelper.getTextPrimary(context),
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
                              if (widget.author.allowLikes)
                                _buildPortraitActionButton(
                                  icon: _isLiked
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  label: _formatCount(_likeCount),
                                  color: _isLiked ? Colors.red : Colors.white,
                                  onTap: () {
                                    _toggleLikeApi();
                                    _startControlsTimer();
                                  },
                                ),
                              // Comment button
                              if (widget.author.allowComments)
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
                              if (widget.author.allowShares)
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
                                        imageUrl:
                                            widget.post?.effectiveThumbnailUrl,
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
                                      builder: (context) =>
                                          ProfileScreen(user: widget.author),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
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

          ],
        ),
      ),
    );
  }

  Widget _buildEmbeddedView(
      VideoPlayerState playerState, VideoPlayerNotifier notifier) {
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

  Widget _buildEmbeddedVideoPlayer(
      VideoPlayerState playerState, VideoPlayerNotifier notifier) {
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
              // Video player — letterboxed in fixed height (YouTube-style; fit synced in build).
              Center(
                child: playerState.isInitialized &&
                        playerState.hasValidController &&
                        playerState.controller != null
                    ? LayoutBuilder(
                        builder: (context, constraints) {
                          final c = playerState.controller!;
                          final vpc = c.videoPlayerController;
                          var ar = 16 / 9;
                          final av = vpc?.value.aspectRatio;
                          if (av != null && av > 0.01) ar = av;
                          final sz = _letterboxedVideoSize(
                            constraints.maxWidth,
                            constraints.maxHeight,
                            ar,
                          );
                          return SizedBox(
                            width: sz.width,
                            height: sz.height,
                            child: SafeBetterPlayerWrapper(controller: c),
                          );
                        },
                      )
                    : Center(
                        child: CircularProgressIndicator(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
              ),
              // Buffering indicator (no text — matches fullscreen UX)
              if (playerState.isBuffering)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.3),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                    minWidth: 40, minHeight: 40),
                                icon: const Icon(
                                  CupertinoIcons.back,
                                  color: Colors.white,
                                  size: 26,
                                ),
                                onPressed: () => Navigator.pop(context),
                              ),
                              const Spacer(),
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                    minWidth: 40, minHeight: 40),
                                tooltip: 'Fullscreen',
                                icon: const Icon(
                                  Icons.fullscreen,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                onPressed: () {
                                  _toggleFullscreen();
                                  _startControlsTimer();
                                },
                              ),
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                    minWidth: 40, minHeight: 40),
                                tooltip: 'Playback and quality',
                                icon: const Icon(
                                  Icons.more_vert,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                onPressed: () {
                                  unawaited(_showPlaybackQualitySheet(
                                    notifier,
                                    playerState,
                                    nestedRootMenu: _deferEmbeddedShimmers(),
                                  ));
                                  _startControlsTimer();
                                },
                              ),
                            ],
                          ),
                          const Spacer(),
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
                              final box =
                                  context.findRenderObject() as RenderBox?;
                              if (box == null) return;

                              final padding = 12.0;
                              final dragPosition =
                                  (details.localPosition.dx - padding)
                                      .clamp(0.0, box.size.width - padding * 2);
                              final totalWidth = (box.size.width - padding * 2)
                                  .clamp(1.0, double.infinity);
                              final progress =
                                  (dragPosition / totalWidth).clamp(0.0, 1.0);
                              final targetPosition = Duration(
                                milliseconds:
                                    (playerState.duration.inMilliseconds *
                                            progress)
                                        .round(),
                              );
                              notifier.seekTo(targetPosition);
                            },
                            onHorizontalDragEnd: (_) {
                              _startControlsTimer();
                            },
                            onTapDown: (details) {
                              if (!playerState.isInitialized) return;
                              final box =
                                  context.findRenderObject() as RenderBox?;
                              if (box == null) return;

                              final padding = 12.0;
                              final tapPosition =
                                  (details.localPosition.dx - padding)
                                      .clamp(0.0, box.size.width - padding * 2);
                              final totalWidth = (box.size.width - padding * 2)
                                  .clamp(1.0, double.infinity);
                              final progress =
                                  (tapPosition / totalWidth).clamp(0.0, 1.0);
                              final targetPosition = Duration(
                                milliseconds:
                                    (playerState.duration.inMilliseconds *
                                            progress)
                                        .round(),
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
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
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
                                  icon: const Icon(Icons.replay_10,
                                      color: Colors.white, size: 22),
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
                                      Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withOpacity(0.8),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withOpacity(0.4),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    playerState.isPlaying
                                        ? Icons.pause
                                        : Icons.play_arrow,
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
                                  icon: const Icon(Icons.forward_10,
                                      color: Colors.white, size: 22),
                                  onPressed: () {
                                    notifier.seekForward();
                                    _startControlsTimer();
                                  },
                                ),
                              ),
                              const Spacer(),
                              // Duration with glass background
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
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
            ],
          ),
        ),
      ),
    );
  }

  (Color, Color) _embeddedShimmerColors() {
    final base = Theme.of(context).brightness == Brightness.dark
        ? Colors.white10
        : Colors.black12;
    return (base, base.withValues(alpha: 0.35));
  }

  Widget _buildEmbeddedVideoDetailsShimmer() {
    final (base, hi) = _embeddedShimmerColors();
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: hi,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 14,
                      width: 160,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 11,
                      width: 100,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 32,
                width: 88,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 13,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            height: 13,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            height: 13,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            height: 13,
            width: 200,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmbeddedSuggestedSectionShimmer() {
    final (base, hi) = _embeddedShimmerColors();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Shimmer.fromColors(
            baseColor: base,
            highlightColor: hi,
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  height: 22,
                  width: 180,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...List.generate(3, (i) {
          return Padding(
            key: ValueKey<String>('embedded_suggested_shimmer_$i'),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Shimmer.fromColors(
              baseColor: base,
              highlightColor: hi,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 140,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 14,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 12,
                          width: 120,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          height: 11,
                          width: 90,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildEmbeddedVideoDetailsColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                backgroundImage: _isValidRemoteUrl(widget.author.avatarUrl)
                    ? NetworkImage(widget.author.avatarUrl)
                    : null,
                child: !_isValidRemoteUrl(widget.author.avatarUrl)
                    ? Icon(
                        Icons.person,
                        color: ThemeHelper.getTextSecondary(context),
                      )
                    : null,
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

            ref.watch(currentUserProvider)?.id == widget.author.id
                ? const SizedBox.shrink()
                : Consumer(
                    builder: (context, ref, _) {
                      final followState = ref.watch(followProvider);
                      final overrideStatus =
                          ref.watch(followStateProvider)[widget.author.id];
                      final isFollowing = overrideStatus ==
                              FollowRelationshipStatus.following ||
                          (overrideStatus == null &&
                              (followState.followingIds.isNotEmpty
                                  ? followState.followingIds
                                      .contains(widget.author.id)
                                  : widget.author.isFollowing));
                      final isPending =
                          overrideStatus == FollowRelationshipStatus.pending;
                      return Container(
                        decoration: BoxDecoration(
                          color: isFollowing
                              ? Colors.transparent
                              : Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(999),
                          border: isFollowing
                              ? Border.all(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 1.5)
                              : null,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              ref
                                  .read(followProvider.notifier)
                                  .toggleFollow(widget.author.id);
                            },
                            borderRadius: BorderRadius.circular(999),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: Text(
                                isFollowing
                                    ? 'Following'
                                    : (isPending ? 'Requested' : 'Follow'),
                                style: TextStyle(
                                  color: isFollowing
                                      ? ThemeHelper.getTextPrimary(context)
                                      : context.buttonTextColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
            const SizedBox(width: 8),
            if (widget.author.allowShares) ...[
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
                      imageUrl: widget.post?.effectiveThumbnailUrl,
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
            ],
            if (widget.author.allowComments) ...[
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
            ],
            if (widget.author.allowLikes)
              GestureDetector(
                onTap: () {
                  _toggleLikeApi();
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isLiked ? Icons.favorite : Icons.favorite_border,
                      size: 24,
                      color: _isLiked
                          ? Colors.red
                          : ThemeHelper.getTextPrimary(context),
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
    );
  }

  Widget _buildVideoDescriptionContent(
      VideoPlayerState playerState, VideoPlayerNotifier notifier) {
    final defer = _deferEmbeddedShimmers();
    final showDetailsShimmer = defer && !_embeddedDetailsReady;
    final showSuggestedShimmer = defer && !_embeddedSuggestedReady;
    final longVideosState = ref.watch(longVideosProvider);
    final suggestedLongVideos =
        _suggestedLongVideosFromList(longVideosState.videos);

    return Container(
      decoration: BoxDecoration(
        gradient: ThemeHelper.getBackgroundGradient(context),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GlassCard(
                padding: const EdgeInsets.all(20),
                child: showDetailsShimmer
                    ? _buildEmbeddedVideoDetailsShimmer()
                    : _buildEmbeddedVideoDetailsColumn(),
              ),
            ),
            const SizedBox(height: 24),
            if (showSuggestedShimmer)
              _buildEmbeddedSuggestedSectionShimmer()
            else ...[
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
                            Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.5),
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
              _buildSuggestedVideosList(suggestedLongVideos),
            ],
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

  /// Other long-form items from [longVideosProvider] (same list as the Long Videos tab), excluding the playing clip.
  static const int _kMaxSuggestedLongVideos = 8;

  List<PostModel> _suggestedLongVideosFromList(List<PostModel> longVideos) {
    final excludeId = widget.post?.id;
    final excludeUrl = widget.videoUrl;

    Iterable<PostModel> candidates = longVideos.where((p) {
      if (excludeId != null && excludeId.isNotEmpty && p.id == excludeId) {
        return false;
      }
      if (excludeUrl.isNotEmpty && (p.videoUrl ?? '') == excludeUrl) {
        return false;
      }
      if ((p.videoUrl ?? '').isEmpty) return false;
      return p.postType == 'longVideo' || p.isVideo;
    });

    final list = candidates.take(_kMaxSuggestedLongVideos).toList();
    return list;
  }

  Widget _buildSuggestedVideosList(List<PostModel> suggestedVideos) {
    if (suggestedVideos.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Text(
          'More long videos will appear here when available.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: ThemeHelper.getTextSecondary(context),
            fontSize: 13,
          ),
        ),
      );
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
          final nextUrl = _isValidRemoteUrl(video.videoUrl) ? (video.videoUrl ?? '') : '';
          if (nextUrl.isEmpty) return;
          final sessionSwitch = widget.onSuggestedLongVideoSelected;
          if (sessionSwitch != null) {
            sessionSwitch(video);
            return;
          }
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => VideoPlayerScreen(
                key: ValueKey<String>('lv_embedded_$nextUrl'),
                videoUrl: nextUrl,
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
                    _isValidRemoteUrl(video.thumbnailUrl)
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
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

enum _EmbeddedPbMenuPage { root, speed, quality }

class _LongVideoEmbeddedPlaybackRootSheet extends ConsumerStatefulWidget {
  const _LongVideoEmbeddedPlaybackRootSheet({
    required this.videoUrl,
    required this.notifier,
    required this.onFinished,
  });

  final String videoUrl;
  final VideoPlayerNotifier notifier;
  final VoidCallback onFinished;

  @override
  ConsumerState<_LongVideoEmbeddedPlaybackRootSheet> createState() =>
      _LongVideoEmbeddedPlaybackRootSheetState();
}

class _LongVideoEmbeddedPlaybackRootSheetState
    extends ConsumerState<_LongVideoEmbeddedPlaybackRootSheet> {
  _EmbeddedPbMenuPage _page = _EmbeddedPbMenuPage.root;

  static const List<double> _speeds = [
    0.25,
    0.5,
    0.75,
    1.0,
    1.25,
    1.5,
    1.75,
    2.0,
  ];

  void _close() {
    Navigator.pop(context);
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(videoPlayerProvider(widget.videoUrl));
    final tracks = playerState.controller?.betterPlayerAsmsTracks ??
        const <BetterPlayerAsmsTrack>[];
    final sorted = _asmsTracksDescendingByResolution(tracks);

    return DraggableScrollableSheet(
      initialChildSize: 0.42,
      minChildSize: 0.28,
      maxChildSize: 0.88,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: ThemeHelper.getSurfaceColor(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border.all(
              color:
                  ThemeHelper.getBorderColor(context).withValues(alpha: 0.35),
            ),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ThemeHelper.getBorderColor(context)
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (_page != _EmbeddedPbMenuPage.root)
                ListTile(
                  leading: Icon(
                    Icons.arrow_back,
                    color: ThemeHelper.getTextPrimary(context),
                  ),
                  title: Text(
                    _page == _EmbeddedPbMenuPage.speed
                        ? 'Playback speed'
                        : 'Video quality',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: ThemeHelper.getTextPrimary(context),
                    ),
                  ),
                  onTap: () => setState(() => _page = _EmbeddedPbMenuPage.root),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text(
                    'Playback settings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: ThemeHelper.getTextPrimary(context),
                    ),
                  ),
                ),
              if (_page == _EmbeddedPbMenuPage.root) ...[
                ListTile(
                  leading: Icon(
                    Icons.speed,
                    color: ThemeHelper.getAccentColor(context),
                  ),
                  title: Text(
                    'Playback speed',
                    style: TextStyle(
                      color: ThemeHelper.getTextPrimary(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    playerState.playbackSpeed == 1.0
                        ? 'Normal'
                        : '${playerState.playbackSpeed}×',
                    style: TextStyle(
                      fontSize: 12,
                      color: ThemeHelper.getTextMuted(context),
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: ThemeHelper.getTextSecondary(context),
                  ),
                  onTap: () => setState(() => _page = _EmbeddedPbMenuPage.speed),
                ),
                ListTile(
                  leading: Icon(
                    Icons.hd_outlined,
                    color: ThemeHelper.getAccentColor(context),
                  ),
                  title: Text(
                    'Video quality',
                    style: TextStyle(
                      color: ThemeHelper.getTextPrimary(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    tracks.length < 2
                        ? 'Auto (only one stream)'
                        : 'Auto or fixed resolution',
                    style: TextStyle(
                      fontSize: 12,
                      color: ThemeHelper.getTextMuted(context),
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: ThemeHelper.getTextSecondary(context),
                  ),
                  onTap: () =>
                      setState(() => _page = _EmbeddedPbMenuPage.quality),
                ),
              ] else if (_page == _EmbeddedPbMenuPage.speed) ...[
                for (final s in _speeds)
                  ListTile(
                    title: Text(
                      s == 1.0 ? 'Normal' : '${s}×',
                      style: TextStyle(
                        color: ThemeHelper.getTextPrimary(context),
                        fontWeight: playerState.playbackSpeed == s
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    trailing: playerState.playbackSpeed == s
                        ? Icon(Icons.check,
                            color: ThemeHelper.getAccentColor(context))
                        : null,
                    onTap: () {
                      unawaited(widget.notifier.setPlaybackSpeed(s));
                      _close();
                    },
                  ),
              ] else ...[
                ListTile(
                  leading: Icon(
                    Icons.auto_awesome_motion,
                    color: ThemeHelper.getAccentColor(context),
                  ),
                  title: Text(
                    'Auto (recommended)',
                    style: TextStyle(
                      color: ThemeHelper.getTextPrimary(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Best for your connection',
                    style: TextStyle(
                      fontSize: 12,
                      color: ThemeHelper.getTextMuted(context),
                    ),
                  ),
                  onTap: () {
                    unawaited(widget.notifier.applyAutoQualityIfAdaptive(
                      settleDelay: Duration.zero,
                    ));
                    _close();
                  },
                ),
                if (sorted.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'No separate resolutions for this video.',
                      style: TextStyle(
                        fontSize: 12,
                        color: ThemeHelper.getTextMuted(context),
                      ),
                    ),
                  )
                else
                  for (final t in sorted)
                    ListTile(
                      leading: Icon(
                        Icons.high_quality_outlined,
                        color: ThemeHelper.getTextSecondary(context),
                      ),
                      title: Text(
                        _resolutionLabelYoutubeStyle(t),
                        style: TextStyle(
                          color: ThemeHelper.getTextPrimary(context),
                        ),
                      ),
                      onTap: () {
                        unawaited(widget.notifier.setVideoQualityTrack(t));
                        _close();
                      },
                    ),
              ],
            ],
          ),
        );
      },
    );
  }
}
