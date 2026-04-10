import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/utils/video_frame_extractor.dart';
import '../../core/utils/theme_helper.dart';

class ChooseCoverPhotoScreen extends StatefulWidget {
  final File videoFile;

  const ChooseCoverPhotoScreen({super.key, required this.videoFile});

  @override
  State<ChooseCoverPhotoScreen> createState() => _ChooseCoverPhotoScreenState();
}

class _ChooseCoverPhotoScreenState extends State<ChooseCoverPhotoScreen>
    with SingleTickerProviderStateMixin {
  int _durationMs = 1;
  int _positionMs = 0;
  double? _videoAspectRatio;
  bool _initializing = true;

  File? _previewFrame;
  bool _previewLoading = false;

  int _frameRequestId = 0;

  bool _isDragging = false;

  bool _isExtracting = false;

  int _lastDispatchedMs = -1;

  final Map<int, File> _filmstripCache = {};
  static const int _filmCells = 10;

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _init();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final d = await VideoFrameExtractor.getDurationMs(widget.videoFile);
      final size = await VideoFrameExtractor.getVideoSize(widget.videoFile);
      final aspect =
          (size != null && size.width > 0 && size.height > 0)
              ? size.width / size.height
              : null;

      if (!mounted) return;
      setState(() {
        _durationMs = d > 0 ? d : 1;
        _positionMs = 0;
        _videoAspectRatio = aspect;
        _initializing = false;
      });

      await _fetchPreview(0);

      _prefillFilmstrip();
    } catch (_) {
      if (!mounted) return;
      setState(() => _initializing = false);
    }
  }

  Future<void> _prefillFilmstrip() async {
    for (int i = 0; i < _filmCells; i++) {
      if (!mounted) return;
      final ms =
          ((_durationMs / (_filmCells - 1)) * i).round().clamp(0, _durationMs);
      if (!_filmstripCache.containsKey(ms)) {
        try {
          final file = await VideoFrameExtractor.extractJpegFrame(
            videoFile: widget.videoFile,
            positionMs: ms,
            maxWidth: 120,
          );
          if (!mounted) return;
          _filmstripCache[ms] = file;
          setState(() {});
        } catch (_) {}
      }
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> _fetchPreview(int ms) async {
    final id = ++_frameRequestId;

    if (!mounted) return;
    setState(() => _previewLoading = true);

    try {
      final file = await VideoFrameExtractor.extractJpegFrame(
        videoFile: widget.videoFile,
        positionMs: ms,
        maxWidth: 720,
      );

      if (!mounted || id != _frameRequestId) return;

      setState(() {
        _previewFrame = file;
        _previewLoading = false;
      });
    } catch (_) {
      if (!mounted || id != _frameRequestId) return;
      setState(() => _previewLoading = false);
    }
  }

  void _seekToMs(int ms) {
    final clamped = ms.clamp(0, _durationMs);

    if (mounted) setState(() => _positionMs = clamped);

    final minDelta = (_durationMs * 0.01).clamp(200, 500).toInt();
    if ((clamped - _lastDispatchedMs).abs() >= minDelta ||
        _lastDispatchedMs < 0) {
      _lastDispatchedMs = clamped;
      _fetchPreview(clamped);
    }
  }

  Future<void> _onDragEnd() async {
    _isDragging = false;
    _lastDispatchedMs = _positionMs;
    await _fetchPreview(_positionMs);
  }

  Future<void> _useThisFrame() async {
    setState(() => _isExtracting = true);
    try {
      final file = await VideoFrameExtractor.extractJpegFrame(
        videoFile: widget.videoFile,
        positionMs: _positionMs,
        maxWidth: 1080,
      );
      if (!mounted) return;
      Navigator.pop(context, file);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isExtracting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  String _formatMs(int ms) {
    final s = ms / 1000.0;
    final minutes = (s / 60).floor();
    final seconds = (s % 60).floor();
    final frac = ((s % 1) * 10).floor();
    if (minutes > 0) {
      return '$minutes:${seconds.toString().padLeft(2, '0')}.$frac';
    }
    return '$seconds.$frac s';
  }

  double get _progress =>
      _durationMs <= 1 ? 0 : _positionMs / _durationMs;

  @override
  Widget build(BuildContext context) {
    final surface = ThemeHelper.getSurfaceColor(context);
    final accent = ThemeHelper.getAccentColor(context);
    final textPrimary = ThemeHelper.getTextPrimary(context);
    final textSecondary = ThemeHelper.getTextSecondary(context);
    final textMuted = ThemeHelper.getTextMuted(context);
    final border = ThemeHelper.getBorderColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stageBg = isDark
        ? Colors.black
        : ThemeHelper.getSecondaryBackgroundColor(context);
    final panelBg = isDark
        ? ThemeHelper.getSecondaryBackgroundColor(context)
        : surface;
    final chipFill = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : textPrimary.withValues(alpha: 0.06);
    final chipBorder = border.withValues(alpha: 0.35);

    return Scaffold(
      backgroundColor: ThemeHelper.getBackgroundColor(context),
      appBar: _buildAppBar(surface, textPrimary, border, isDark),
      body: SafeArea(
        top: false,
        child: _initializing
            ? Center(child: CircularProgressIndicator(color: accent))
            : _durationMs <= 1
                ? _buildError(textSecondary)
                : Column(
                    children: [
                      Expanded(
                        child: _PreviewPane(
                          previewFrame: _previewFrame,
                          previewLoading: _previewLoading,
                          videoAspectRatio: _videoAspectRatio,
                          accent: accent,
                          onAccent: ThemeHelper.getOnAccentColor(context),
                          pulseAnim: _pulseAnim,
                          positionMs: _positionMs,
                          isDragging: _isDragging,
                          formatMs: _formatMs,
                          stageBackground: stageBg,
                          isDark: isDark,
                        ),
                      ),
                      _buildControls(
                        accent: accent,
                        onAccent: ThemeHelper.getOnAccentColor(context),
                        textPrimary: textPrimary,
                        textMuted: textMuted,
                        border: border,
                        panelBg: panelBg,
                        isDark: isDark,
                        chipFill: chipFill,
                        chipBorder: chipBorder,
                      ),
                    ],
                  ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    Color surface,
    Color textPrimary,
    Color border,
    bool isDark,
  ) {
    return AppBar(
      backgroundColor: surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: textPrimary),
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: Icon(Icons.arrow_back_ios_new_rounded,
            color: textPrimary, size: 20),
      ),
      title: Text(
        'Choose cover photo',
        style: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w800,
          fontSize: 16,
          letterSpacing: -0.3,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0.5),
        child: Container(
          height: 0.5,
          color: border.withValues(alpha: isDark ? 0.35 : 0.45),
        ),
      ),
    );
  }

  Widget _buildError(Color textSecondary) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_off_rounded,
                color: textSecondary, size: 48),
            const SizedBox(height: 16),
            Text(
              'Could not load video preview.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls({
    required Color accent,
    required Color onAccent,
    required Color textPrimary,
    required Color textMuted,
    required Color border,
    required Color panelBg,
    required bool isDark,
    required Color chipFill,
    required Color chipBorder,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      decoration: BoxDecoration(
        color: panelBg,
        border: Border(
          top: BorderSide(
            color: border.withValues(alpha: 0.35),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                'TIMELINE',
                style: TextStyle(
                  color: textMuted.withValues(alpha: 0.9),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              AnimatedOpacity(
                opacity: _previewLoading ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: Row(
                  children: [
                    SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: accent.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'loading frame…',
                      style: TextStyle(
                        color: textMuted.withValues(alpha: 0.85),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          _FilmstripScrubber(
            durationMs: _durationMs,
            positionMs: _positionMs,
            progress: _progress,
            accentColor: accent,
            filmstripCache: _filmstripCache,
            filmCells: _filmCells,
            isDragging: _isDragging,
            formatMs: _formatMs,
            onSeek: _seekToMs,
            onDragStart: () => setState(() => _isDragging = true),
            onDragEnd: _onDragEnd,
            borderColor: border,
            trackMutedFill: textPrimary.withValues(alpha: isDark ? 0.06 : 0.05),
            tickColor: textMuted,
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: chipFill,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: chipBorder,
                    width: 0.5,
                  ),
                ),
                child: Text(
                  _formatMs(_positionMs),
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),

              const Spacer(),

              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 44,
                child: ElevatedButton(
                  onPressed: _isExtracting ? null : _useThisFrame,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: onAccent,
                    disabledBackgroundColor:
                        accent.withValues(alpha: 0.45),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: _isExtracting
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: onAccent,
                          ),
                        )
                      : const Text(
                          'Use frame',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14),
                        ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Text(
            'Drag the timeline to pick a sharp, clean frame',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textMuted.withValues(alpha: 0.95),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewPane extends StatelessWidget {
  final File? previewFrame;
  final bool previewLoading;
  final double? videoAspectRatio;
  final Color accent;
  final Color onAccent;
  final Animation<double> pulseAnim;
  final int positionMs;
  final bool isDragging;
  final String Function(int) formatMs;
  final Color stageBackground;
  final bool isDark;

  const _PreviewPane({
    required this.previewFrame,
    required this.previewLoading,
    required this.videoAspectRatio,
    required this.accent,
    required this.onAccent,
    required this.pulseAnim,
    required this.positionMs,
    required this.isDragging,
    required this.formatMs,
    required this.stageBackground,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final scrim = Colors.black.withValues(alpha: isDark ? 0.5 : 0.42);
    final onVideo = Colors.white;
    final subtleBorder = onVideo.withValues(alpha: 0.14);

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: stageBackground),

        if (previewFrame != null)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 80),
            child: _frameImage(previewFrame!),
          ),

        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.12),
                  Colors.black.withValues(alpha: isDark ? 0.55 : 0.38),
                ],
                stops: const [0.5, 0.8, 1.0],
              ),
            ),
          ),
        ),

        Positioned(
          top: 14,
          left: 14,
          child: _Badge(
            fill: scrim,
            borderColor: subtleBorder,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.photo_camera_rounded,
                    color: onVideo.withValues(alpha: 0.9),
                    size: 11),
                const SizedBox(width: 5),
                Text(
                  'Cover frame',
                  style: TextStyle(
                    color: onVideo.withValues(alpha: 0.95),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),

        Positioned(
          top: 14,
          right: 14,
          child: AnimatedOpacity(
            opacity: previewLoading ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 150),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: scrim,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: subtleBorder,
                  width: 0.5,
                ),
              ),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: FadeTransition(
                    opacity: pulseAnim,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: onVideo.withValues(alpha: 0.92),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        Positioned(
          bottom: 16,
          left: 0,
          right: 0,
          child: AnimatedOpacity(
            opacity: isDragging ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 150),
            child: Center(
              child: _Badge(
                fill: accent.withValues(alpha: 0.92),
                borderColor: accent.withValues(alpha: 0.35),
                child: Text(
                  formatMs(positionMs),
                  style: TextStyle(
                    color: onAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _frameImage(File file) {
    final child = Image.file(
      file,
      key: ValueKey(file.path),
      fit: BoxFit.cover,
      gaplessPlayback: true,
    );

    if (videoAspectRatio != null) {
      return Center(
        child: AspectRatio(
          aspectRatio: videoAspectRatio!,
          child: child,
        ),
      );
    }
    return Positioned.fill(child: child);
  }
}

class _FilmstripScrubber extends StatefulWidget {
  final int durationMs;
  final int positionMs;
  final double progress;
  final Color accentColor;
  final Map<int, File> filmstripCache;
  final int filmCells;
  final bool isDragging;
  final String Function(int) formatMs;
  final ValueChanged<int> onSeek;
  final VoidCallback onDragStart;
  final Future<void> Function() onDragEnd;
  final Color borderColor;
  final Color trackMutedFill;
  final Color tickColor;

  const _FilmstripScrubber({
    required this.durationMs,
    required this.positionMs,
    required this.progress,
    required this.accentColor,
    required this.filmstripCache,
    required this.filmCells,
    required this.isDragging,
    required this.formatMs,
    required this.onSeek,
    required this.onDragStart,
    required this.onDragEnd,
    required this.borderColor,
    required this.trackMutedFill,
    required this.tickColor,
  });

  @override
  State<_FilmstripScrubber> createState() => _FilmstripScrubberState();
}

class _FilmstripScrubberState extends State<_FilmstripScrubber> {
  static const double _trackHeight = 58;
  static const double _handleW = 3.0;

  int _msFromLocalX(double localX, double trackWidth) {
    final ratio = (localX / trackWidth).clamp(0.0, 1.0);
    return (ratio * widget.durationMs).round();
  }

  void _handlePointerDown(PointerDownEvent e, double trackWidth) {
    widget.onDragStart();
    widget.onSeek(_msFromLocalX(e.localPosition.dx, trackWidth));
  }

  void _handlePointerMove(PointerMoveEvent e, double trackWidth) {
    widget.onSeek(_msFromLocalX(e.localPosition.dx, trackWidth));
  }

  Future<void> _handlePointerUp(PointerUpEvent e) async {
    await widget.onDragEnd();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (e) =>
                  _handlePointerDown(e, totalWidth),
              onPointerMove: (e) =>
                  _handlePointerMove(e, totalWidth),
              onPointerUp: _handlePointerUp,
              child: SizedBox(
                height: _trackHeight,
                width: totalWidth,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Row(
                          children: List.generate(
                            widget.filmCells,
                            (i) => Expanded(
                              child: _FilmCell(
                                index: i,
                                filmCells: widget.filmCells,
                                durationMs: widget.durationMs,
                                filmstripCache: widget.filmstripCache,
                                dividerColor: widget.borderColor
                                    .withValues(alpha: 0.35),
                                emptyFill: widget.trackMutedFill,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: widget.borderColor.withValues(alpha: 0.45),
                            width: 0.5,
                          ),
                        ),
                      ),
                    ),

                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: (totalWidth * widget.progress)
                          .clamp(0, totalWidth),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(10),
                          ),
                          border: Border(
                            top: BorderSide(
                                color: widget.accentColor,
                                width: 2.5),
                            bottom: BorderSide(
                                color: widget.accentColor,
                                width: 2.5),
                          ),
                          color:
                              widget.accentColor.withValues(alpha: 0.18),
                        ),
                      ),
                    ),

                    Positioned(
                      left: (totalWidth * widget.progress)
                          .clamp(0, totalWidth - _handleW),
                      top: -5,
                      bottom: -5,
                      width: _handleW,
                      child: _Playhead(
                        accentColor: widget.accentColor,
                        onAccent: ThemeHelper.getOnAccentColor(context),
                        isDragging: widget.isDragging,
                        positionMs: widget.positionMs,
                        formatMs: widget.formatMs,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 6),

            _TickRow(
              durationMs: widget.durationMs,
              formatMs: widget.formatMs,
              tickColor: widget.tickColor,
            ),
          ],
        );
      },
    );
  }
}

class _FilmCell extends StatelessWidget {
  final int index;
  final int filmCells;
  final int durationMs;
  final Map<int, File> filmstripCache;
  final Color dividerColor;
  final Color emptyFill;

  const _FilmCell({
    required this.index,
    required this.filmCells,
    required this.durationMs,
    required this.filmstripCache,
    required this.dividerColor,
    required this.emptyFill,
  });

  @override
  Widget build(BuildContext context) {
    final ms = ((durationMs / (filmCells - 1)) * index)
        .round()
        .clamp(0, durationMs);
    final file = filmstripCache[ms];

    return Container(
      decoration: BoxDecoration(
        color: emptyFill,
        border: Border(
          right: index < filmCells - 1
              ? BorderSide(
                  color: dividerColor,
                  width: 0.5,
                )
              : BorderSide.none,
        ),
      ),
      child: file != null
          ? Image.file(
              file,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              cacheWidth: 80,
            )
          : const SizedBox.expand(),
    );
  }
}

class _Playhead extends StatelessWidget {
  final Color accentColor;
  final Color onAccent;
  final bool isDragging;
  final int positionMs;
  final String Function(int) formatMs;

  const _Playhead({
    required this.accentColor,
    required this.onAccent,
    required this.isDragging,
    required this.positionMs,
    required this.formatMs,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(2),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.45),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ),

        Positioned(
          top: 2,
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: accentColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.92),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.35),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ),

        if (isDragging)
          Positioned(
            top: -32,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Text(
                formatMs(positionMs),
                style: TextStyle(
                  color: onAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TickRow extends StatelessWidget {
  final int durationMs;
  final String Function(int) formatMs;
  final Color tickColor;

  const _TickRow({
    required this.durationMs,
    required this.formatMs,
    required this.tickColor,
  });

  @override
  Widget build(BuildContext context) {
    const tickCount = 5;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(tickCount, (i) {
        final ms =
            ((durationMs / (tickCount - 1)) * i).round().clamp(0, durationMs);
        return Text(
          formatMs(ms),
          style: TextStyle(
            color: tickColor.withValues(alpha: 0.75),
            fontSize: 9,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        );
      }),
    );
  }
}

class _Badge extends StatelessWidget {
  final Widget child;
  final Color fill;
  final Color borderColor;

  const _Badge({
    required this.child,
    required this.fill,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: borderColor,
          width: 0.5,
        ),
      ),
      child: child,
    );
  }
}
