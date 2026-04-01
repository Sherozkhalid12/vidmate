import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/providers/live_stream_provider.dart';
import '../../core/services/mock_data_service.dart';

/// Modern luxury live stream screen for the streamer.
/// Cinematic dark UI: glass panels, accent glow, animated stats, minimal chrome.
class LiveStreamScreen extends ConsumerStatefulWidget {
  const LiveStreamScreen({super.key});

  @override
  ConsumerState<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends ConsumerState<LiveStreamScreen>
    with TickerProviderStateMixin {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  String? _cameraError;
  final _scrollController = ScrollController();

  late AnimationController _pulseController;
  late AnimationController _waveController;
  late Animation<double> _pulseAnim;
  late Animation<double> _waveAnim;

  int _durationSeconds = 0;
  Timer? _durationTimer;
  int _viewerCount = 142;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _waveAnim = Tween<double>(begin: 0.0, end: 1.0).animate(_waveController);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(liveStreamProvider.notifier).startLive();
    });

    _initCamera();
    _simulateCommentsAndLikes();
    _startDurationTimer();
    _startViewerSimulation();
  }

  void _startDurationTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _durationSeconds++);
    });
  }

  void _startViewerSimulation() {
    Timer.periodic(const Duration(seconds: 5), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _viewerCount += (Random().nextInt(11) - 4).clamp(-20, 20);
        if (_viewerCount < 10) _viewerCount = 10;
      });
    });
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        if (mounted) setState(() => _cameraError = 'No camera found');
        return;
      }
      final front = _cameras!.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras!.first,
      );
      _controller = CameraController(
        front,
        ResolutionPreset.high,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await _controller!.initialize();
      if (mounted) setState(() {
        _isCameraInitialized = true;
        _cameraError = null;
      });
    } catch (e) {
      if (mounted) setState(() => _cameraError = e.toString());
    }
  }

  void _simulateCommentsAndLikes() {
    final notifier = ref.read(liveStreamProvider.notifier);
    final users = MockDataService.mockUsers;
    final messages = [
      'Hello!', 'So cool 🔥', 'Nice stream', 'Hey everyone',
      'Love this content', '👋 watching from work', 'Great stuff!',
      'This is fire 🔥', 'W streamer', 'Let\'s gooo',
    ];
    int tick = 0;
    Timer.periodic(const Duration(seconds: 3), (t) {
      if (!mounted) { t.cancel(); return; }
      final state = ref.read(liveStreamProvider);
      if (!state.isLive) { t.cancel(); return; }
      final user = users[tick % users.length];
      notifier.addComment(user.username, messages[tick % messages.length]);
      if (tick % 2 == 1) notifier.incrementLike();
      tick++;
    });
  }

  @override
  void dispose() {
    ref.read(liveStreamProvider.notifier).endLive();
    _pulseController.dispose();
    _waveController.dispose();
    _scrollController.dispose();
    _durationTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  String get _durationFormatted {
    final h = _durationSeconds ~/ 3600;
    final m = (_durationSeconds % 3600) ~/ 60;
    final s = _durationSeconds % 60;
    if (h > 0) return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  void _endLive() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final liveState = ref.watch(liveStreamProvider);
    final size = MediaQuery.of(context).size;
    final topPad = MediaQuery.of(context).padding.top;
    final accentColor = ThemeHelper.getAccentColor(context);

    return Scaffold(
      backgroundColor: ThemeHelper.getBackgroundColor(context),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Camera / background ──────────────────────────────────────────
          _buildCameraPreview(context),

          // Cinematic vignette overlay (theme-aware)
          _buildVignette(context),

          // ── TOP BAR ─────────────────────────────────────────────────────
          Positioned(
            top: topPad + 12,
            left: 16,
            right: 16,
            child: _buildTopBar(context, liveState.likeCount),
          ),

          // ── RIGHT STATS COLUMN ───────────────────────────────────────────
          Positioned(
            right: 16,
            top: topPad + 88,
            child: _buildStatsColumn(context, liveState.likeCount),
          ),

          // ── COMMENT STRIP (bottom-left) ──────────────────────────────────
          Positioned(
            left: 16,
            right: 100,
            bottom: MediaQuery.of(context).padding.bottom + 96,
            height: min(size.height * 0.32, 240),
            child: _buildCommentFeed(context, liveState.comments),
          ),

          // ── LIKE BUBBLES ─────────────────────────────────────────────────
          ...liveState.likeAnimationKeys.map(
                (k) => _LikeBubble(animationKey: k, accent: accentColor),
          ),

          // ── BOTTOM ACTION BAR ────────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomBar(context),
          ),
        ],
      ),
    );
  }

  // ── Camera / fallback ────────────────────────────────────────────────────

  Widget _buildCameraPreview(BuildContext context) {
    final bgColor = ThemeHelper.getBackgroundColor(context);
    final mutedColor = ThemeHelper.getTextMuted(context);
    final accentColor = ThemeHelper.getAccentColor(context);

    if (_cameraError != null) {
      return Container(
        color: bgColor,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam_off_rounded, size: 56, color: mutedColor),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  _cameraError!,
                  style: TextStyle(color: mutedColor, fontSize: 13, height: 1.5),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (!_isCameraInitialized || _controller == null) {
      return Container(
        color: bgColor,
        child: Center(
          child: AnimatedBuilder(
            animation: _pulseAnim,
            builder: (context, _) => Opacity(
              opacity: _pulseAnim.value,
              child: Icon(Icons.videocam_rounded, size: 56, color: accentColor),
            ),
          ),
        ),
      );
    }
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: _controller!.value.previewSize?.height ?? 1,
        height: _controller!.value.previewSize?.width ?? 1,
        child: CameraPreview(_controller!),
      ),
    );
  }

  Widget _buildVignette(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vignetteColor = isDark
        ? Colors.black.withOpacity(0.55)
        : Colors.white.withOpacity(0.35);
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.0,
            colors: [Colors.transparent, vignetteColor],
          ),
        ),
      ),
    );
  }

  // ── Top bar ──────────────────────────────────────────────────────────────

  Widget _buildTopBar(BuildContext context, int likeCount) {
    final iconColor = ThemeHelper.getHighContrastIconColor(context);
    return Row(
      children: [
        // Back / exit button
        _GlassButton(
          size: 44,
          child: Icon(Icons.arrow_back_ios_new_rounded, color: iconColor, size: 18),
          onTap: _endLive,
        ),

        const SizedBox(width: 12),

        // LIVE indicator pill
        _buildLivePill(context),

        const SizedBox(width: 10),

        // Duration
        _buildDurationBadge(context),

        const Spacer(),

        // Flip camera
        _GlassButton(
          size: 44,
          child: Icon(Icons.flip_camera_ios_rounded, color: iconColor, size: 20),
          onTap: () {}, // hook up flip camera if desired
        ),
      ],
    );
  }

  Widget _buildLivePill(BuildContext context) {
    final accentColor = ThemeHelper.getAccentColor(context);
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: accentColor.withOpacity(0.5), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(0.15 * _pulseAnim.value),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor,
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withOpacity(_pulseAnim.value),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'LIVE',
                style: TextStyle(
                  color: accentColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.0,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDurationBadge(BuildContext context) {
    final surfaceColor = ThemeHelper.getSurfaceColor(context);
    final borderColor = ThemeHelper.getBorderColor(context);
    final textColor = ThemeHelper.getTextPrimary(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: surfaceColor.withOpacity(0.6),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Text(
            _durationFormatted,
            style: TextStyle(
              color: textColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }

  // ── Right stats column ───────────────────────────────────────────────────

  Widget _buildStatsColumn(BuildContext context, int likeCount) {
    final accentColor = ThemeHelper.getAccentColor(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildStatCard(
          context: context,
          icon: Icons.visibility_rounded,
          value: _formatCount(_viewerCount),
          label: 'watching',
          iconColor: accentColor,
        ),
        const SizedBox(height: 12),
        _buildStatCard(
          context: context,
          icon: Icons.favorite_rounded,
          value: _formatCount(likeCount),
          label: 'likes',
          iconColor: const Color(0xFFFF4D6D),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required BuildContext context,
    required IconData icon,
    required String value,
    required String label,
    required Color iconColor,
  }) {
    final panelBg = ThemeHelper.getSurfaceColor(context).withOpacity(0.85);
    final borderColor = ThemeHelper.getBorderColor(context);
    final textPrimary = ThemeHelper.getTextPrimary(context);
    final textMuted = ThemeHelper.getTextMuted(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: 80,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: panelBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  color: textMuted,
                  fontSize: 10,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Comment feed ─────────────────────────────────────────────────────────

  Widget _buildCommentFeed(BuildContext context, List<LiveComment> comments) {
    if (comments.isEmpty) return const SizedBox.shrink();

    final fadeColor = ThemeHelper.getTextPrimary(context);
    return ShaderMask(
      shaderCallback: (rect) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, fadeColor],
        stops: const [0.0, 0.35],
      ).createShader(rect),
      blendMode: BlendMode.dstIn,
      child: ListView.builder(
        controller: _scrollController,
        reverse: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: comments.length > 8 ? 8 : comments.length,
        itemBuilder: (context, index) {
          final c = comments[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _CommentBubble(username: c.username, message: c.message),
          );
        },
      ),
    );
  }

  // ── Bottom bar ───────────────────────────────────────────────────────────

  Widget _buildBottomBar(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overlayColor = isDark ? Colors.black : Colors.white;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPad + 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                overlayColor.withOpacity(0.7),
                overlayColor.withOpacity(0.0),
              ],
            ),
          ),
          child: Row(
            children: [
              // Quick action pills
              _QuickActionPill(
                icon: Icons.mic_rounded,
                label: 'Mic',
                onTap: () {},
              ),
              const SizedBox(width: 10),
              _QuickActionPill(
                icon: Icons.share_rounded,
                label: 'Share',
                onTap: () {},
              ),
              const Spacer(),
              // End stream button
              _EndStreamButton(onTap: _endLive),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Subwidgets ───────────────────────────────────────────────────────────────

class _GlassButton extends StatelessWidget {
  final Widget child;
  final double size;
  final VoidCallback onTap;

  const _GlassButton({
    required this.child,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceColor = ThemeHelper.getSurfaceColor(context);
    final borderColor = ThemeHelper.getBorderColor(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: surfaceColor.withOpacity(0.5),
              borderRadius: BorderRadius.circular(size / 2),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

class _CommentBubble extends StatelessWidget {
  final String username;
  final String message;

  const _CommentBubble({required this.username, required this.message});

  @override
  Widget build(BuildContext context) {
    final panelBg = ThemeHelper.getSurfaceColor(context).withOpacity(0.85);
    final borderColor = ThemeHelper.getBorderColor(context);
    final accentColor = ThemeHelper.getAccentColor(context);
    final messageColor = ThemeHelper.getTextSecondary(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: panelBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: RichText(
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: TextStyle(fontSize: 13.5, height: 1.4, color: messageColor),
              children: [
                TextSpan(
                  text: '$username  ',
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                TextSpan(
                  text: message,
                  style: TextStyle(color: messageColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceColor = ThemeHelper.getSurfaceColor(context);
    final borderColor = ThemeHelper.getBorderColor(context);
    final textColor = ThemeHelper.getTextPrimary(context);
    final iconColor = ThemeHelper.getHighContrastIconColor(context);
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: surfaceColor.withOpacity(0.5),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: iconColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
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

class _EndStreamButton extends StatelessWidget {
  final VoidCallback onTap;

  const _EndStreamButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final errorColor = colorScheme.error;
    final onError = colorScheme.onError;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [errorColor, errorColor.withOpacity(0.85)],
          ),
          boxShadow: [
            BoxShadow(
              color: errorColor.withOpacity(0.4),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.stop_rounded, color: onError, size: 20),
            const SizedBox(width: 8),
            Text(
              'End Live',
              style: TextStyle(
                color: onError,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Floating like animation ──────────────────────────────────────────────────

class _LikeBubble extends ConsumerStatefulWidget {
  final int animationKey;
  final Color accent;

  const _LikeBubble({required this.animationKey, required this.accent});

  @override
  ConsumerState<_LikeBubble> createState() => _LikeBubbleState();
}

class _LikeBubbleState extends ConsumerState<_LikeBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<double> _scale;
  late Animation<Offset> _offset;
  late double _xDrift;

  @override
  void initState() {
    super.initState();
    final rng = Random(widget.animationKey);
    _xDrift = (rng.nextDouble() - 0.5) * 0.6;

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );
    _opacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 90),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _scale = Tween<double>(begin: 0.4, end: 1.4).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _offset = Tween<Offset>(
      begin: const Offset(0.0, 0.8),
      end: const Offset(0.0, -0.2),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward().then((_) {
      ref.read(liveStreamProvider.notifier).removeLikeAnimationKey(widget.animationKey);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Align(
              alignment: Alignment(
                0.6 + _xDrift,
                _offset.value.dy,
              ),
              child: Opacity(
                opacity: _opacity.value,
                child: Transform.scale(
                  scale: _scale.value,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFF4D6D).withOpacity(0.18),
                      border: Border.all(
                        color: const Color(0xFFFF4D6D).withOpacity(0.4),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.favorite_rounded,
                      color: Color(0xFFFF4D6D),
                      size: 22,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}