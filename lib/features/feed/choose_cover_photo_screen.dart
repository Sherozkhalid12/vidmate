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

class _ChooseCoverPhotoScreenState extends State<ChooseCoverPhotoScreen> {
  int _durationMs = 1;
  int _positionMs = 0;
  bool _isExtracting = false;
  int _lastSeekMs = -1;
  bool _isDraggingTimeline = false;
  bool _initializing = true;
  File? _previewFrame;
  bool _previewLoading = false;
  Timer? _previewDebounce;
  int _previewRequestId = 0;
  double? _videoAspectRatio;

  static Color _alpha(Color c, double opacity) =>
      c.withAlpha((opacity.clamp(0.0, 1.0) * 255).round());

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final d = await VideoFrameExtractor.getDurationMs(widget.videoFile);
      final size = await VideoFrameExtractor.getVideoSize(widget.videoFile);
      final aspect = (size != null && size.width > 0 && size.height > 0)
          ? (size.width / size.height)
          : null;
      final durationMs = d > 0 ? d : 1;
      if (!mounted) return;
      setState(() {
        _durationMs = durationMs;
        _positionMs = 0;
        _initializing = false;
        _videoAspectRatio = aspect;
      });
      await _refreshPreview(immediate: true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
      });
    }
  }

  @override
  void dispose() {
    _previewDebounce?.cancel();
    super.dispose();
  }

  Future<void> _seekToMs(int ms) async {
    final clamped = ms.clamp(0, _durationMs);
    // Throttle seeking while dragging to avoid too many seeks.
    // Keep this low so the preview frame updates smoothly.
    if ((_lastSeekMs - clamped).abs() < 35) {
      if (mounted) setState(() => _positionMs = clamped);
      return;
    }
    _lastSeekMs = clamped;
    if (mounted) setState(() => _positionMs = clamped);
    // While dragging, wait until drag end to extract preview (saves CPU/memory on large videos).
    if (_isDraggingTimeline) return;
    _previewDebounce?.cancel();
    _previewDebounce = Timer(const Duration(milliseconds: 140), () {
      _refreshPreview();
    });
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

  Future<void> _refreshPreview({bool immediate = false}) async {
    final requestId = ++_previewRequestId;
    if (!mounted) return;
    setState(() => _previewLoading = true);
    try {
      final file = await VideoFrameExtractor.extractJpegFrame(
        videoFile: widget.videoFile,
        positionMs: _positionMs,
        // Keep preview light to avoid OOM on huge videos.
        maxWidth: 720,
      );
      if (!mounted || requestId != _previewRequestId) return;
      setState(() {
        _previewFrame = file;
        _previewLoading = false;
      });
    } catch (_) {
      if (!mounted || requestId != _previewRequestId) return;
      setState(() => _previewLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = ThemeHelper.getBackgroundColor(context);
    final surface = ThemeHelper.getSurfaceColor(context);
    final border = ThemeHelper.getBorderColor(context);
    final accent = ThemeHelper.getAccentColor(context);
    final textPrimary = ThemeHelper.getTextPrimary(context);
    final textSecondary = ThemeHelper.getTextSecondary(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: surface,
        elevation: 0,
        title: Text(
          'Choose cover photo',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      body: SafeArea(
        top: false,
        child: _initializing
            ? Center(child: CircularProgressIndicator(color: accent))
            : _durationMs <= 1
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Could not load video preview.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: textSecondary, fontWeight: FontWeight.w600),
                      ),
                    ),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Container(
                                color: Colors.black,
                                child: _previewFrame == null
                                    ? const SizedBox.shrink()
                                    : (_videoAspectRatio != null
                                        ? Center(
                                            child: AspectRatio(
                                              aspectRatio: _videoAspectRatio!,
                                              child: Image.file(
                                                _previewFrame!,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          )
                                        : Image.file(
                                            _previewFrame!,
                                            fit: BoxFit.cover,
                                          )),
                              ),
                            ),
                            if (_previewLoading)
                              Positioned(
                                top: 12,
                                right: 12,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _alpha(Colors.black, 0.45),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: _alpha(Colors.white, 0.9),
                                    ),
                                  ),
                                ),
                              ),
                            Positioned(
                              top: 12,
                              left: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _alpha(isDark ? Colors.black : scheme.scrim, 0.45),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: _alpha(Colors.white, 0.12)),
                                ),
                                child: Text(
                                  'Cover frame',
                                  style: TextStyle(
                                    color: _alpha(Colors.white, 0.92),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      _alpha(Colors.black, 0.0),
                                      _alpha(Colors.black, 0.55),
                                      _alpha(Colors.black, 0.78),
                                    ],
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          child: _SeekTimeline(
                                            durationMs: _durationMs,
                                            positionMs: _positionMs,
                                            accentColor: accent,
                                            backgroundColor: _alpha(Colors.white, isDark ? 0.10 : 0.14),
                                            borderColor: _alpha(Colors.white, isDark ? 0.14 : 0.18),
                                            textMuted: _alpha(Colors.white, 0.72),
                                            onSeek: _seekToMs,
                                            onDragStart: () {
                                              _isDraggingTimeline = true;
                                            },
                                            onDragEnd: () async {
                                              _isDraggingTimeline = false;
                                              await _refreshPreview();
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _formatDuration(_positionMs),
                                            style: TextStyle(
                                              color: _alpha(Colors.white, 0.75),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        SizedBox(
                                          height: 44,
                                          child: ElevatedButton(
                                            onPressed: _isExtracting ? null : _useThisFrame,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: accent,
                                              foregroundColor: ThemeHelper.getOnAccentColor(context),
                                              padding: const EdgeInsets.symmetric(horizontal: 16),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(14),
                                              ),
                                              elevation: 0,
                                            ),
                                            child: _isExtracting
                                                ? const SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child: CircularProgressIndicator(strokeWidth: 2.5),
                                                  )
                                                : const Text(
                                                    'Use frame',
                                                    style: TextStyle(fontWeight: FontWeight.w800),
                                                  ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'Drag the timeline to pick a sharp, clean frame.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: _alpha(Colors.white, 0.72),
                                        fontSize: 12,
                                        height: 1.25,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: Container(
                                height: 0.5,
                                color: _alpha(border, 0.25),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  String _formatDuration(int ms) {
    final totalSeconds = ms / 1000.0;
    final minutes = (totalSeconds / 60).floor();
    final seconds = (totalSeconds % 60).floor();
    final millis = ((totalSeconds % 1) * 1000).floor();
    final fraction = (millis / 100).floor(); // 0..9
    if (minutes > 0) {
      return '$minutes:${seconds.toString().padLeft(2, '0')}.$fraction';
    }
    return '$seconds.$fraction s';
  }
}

/// Draggable timeline with a single playhead, similar to the reel trim interaction.
class _SeekTimeline extends StatefulWidget {
  final int durationMs;
  final int positionMs;
  final Color accentColor;
  final Color backgroundColor;
  final Color borderColor;
  final Color textMuted;
  final ValueChanged<int> onSeek;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;

  const _SeekTimeline({
    required this.durationMs,
    required this.positionMs,
    required this.accentColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.textMuted,
    required this.onSeek,
    required this.onDragStart,
    required this.onDragEnd,
  });

  @override
  State<_SeekTimeline> createState() => _SeekTimelineState();
}

class _SeekTimelineState extends State<_SeekTimeline> {
  static const double _handleWidth = 26.0;
  static const double _trackHeight = 56.0;

  bool _isDragging = false;

  int _clampMs(int ms) => ms.clamp(0, widget.durationMs);

  int _msFromDx(double dx, double trackWidth) {
    final ratio = (dx / (trackWidth == 0 ? 1 : trackWidth)).clamp(0.0, 1.0);
    return (ratio * widget.durationMs).round();
  }

  void _seekFromLocal(Offset localPosition, double trackWidth) {
    final ms = _msFromDx(localPosition.dx, trackWidth);
    widget.onSeek(_clampMs(ms));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final trackWidth = totalWidth - _handleWidth;
        final clampedPos = _clampMs(widget.positionMs);

        final handleX =
            (clampedPos / (widget.durationMs == 0 ? 1 : widget.durationMs)) * trackWidth;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) {
            setState(() => _isDragging = true);
            widget.onDragStart();
          },
          onHorizontalDragUpdate: (d) {
            if (!_isDragging) return;
            _seekFromLocal(d.localPosition, trackWidth);
          },
          onHorizontalDragEnd: (_) {
            setState(() => _isDragging = false);
            widget.onDragEnd();
          },
          onTapDown: (d) {
            widget.onSeek(_clampMs(_msFromDx(d.localPosition.dx, trackWidth)));
          },
          child: SizedBox(
            height: _trackHeight + 16,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: _handleWidth / 2,
                  right: _handleWidth / 2,
                  top: 8,
                  height: _trackHeight,
                  child: Container(
                    decoration: BoxDecoration(
                      color: widget.backgroundColor,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: widget.borderColor),
                    ),
                  ),
                ),
                Positioned(
                  left: _handleWidth / 2,
                  top: 8,
                  width: handleX,
                  height: _trackHeight,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(6),
                      ),
                      color: _ChooseCoverPhotoScreenState._alpha(
                        widget.accentColor,
                        0.15,
                      ),
                      border: Border(
                        top: BorderSide(color: widget.accentColor, width: 3),
                        bottom: BorderSide(color: widget.accentColor, width: 3),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: _handleWidth / 2 + handleX,
                  top: 4,
                  width: _handleWidth,
                  height: _trackHeight + 8,
                  child: Column(
                    children: [
                      if (_isDragging)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: widget.accentColor,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _formatTimeline(clampedPos),
                            style: TextStyle(
                              color: ThemeHelper.getOnAccentColor(context),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      Expanded(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: widget.accentColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: _ChooseCoverPhotoScreenState._alpha(
                                    widget.accentColor,
                                    0.35,
                                  ),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatTimeline(int ms) {
    final totalSeconds = ms / 1000.0;
    final seconds = totalSeconds.floor();
    final fraction = ((totalSeconds - seconds) * 10).floor(); // 0..9
    return '${seconds.toString().padLeft(2, '0')}.$fraction';
  }
}

