part of '../reel_edit_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════
// TRIM PANEL
// ═══════════════════════════════════════════════════════════════════════════

class _TrimPanel extends StatefulWidget {
  final VideoPlayerController? controller;
  final double trimStart;
  final double trimEnd;
  final ValueNotifier<bool> isPlaying;
  final void Function(double start, double end) onTrimChanged;
  final VoidCallback onTogglePlay;
  final void Function(double position) onSeek;

  const _TrimPanel({
    super.key,
    required this.controller,
    required this.trimStart,
    required this.trimEnd,
    required this.isPlaying,
    required this.onTrimChanged,
    required this.onTogglePlay,
    required this.onSeek,
  });

  @override
  State<_TrimPanel> createState() => _TrimPanelState();
}

class _TrimPanelState extends State<_TrimPanel> {
  @override
  Widget build(BuildContext context) {
    final duration = widget.controller?.value.duration ?? Duration.zero;
    final startMs = (duration.inMilliseconds * widget.trimStart).round();
    final endMs = (duration.inMilliseconds * widget.trimEnd).round();
    final trimmedDurationMs = endMs - startMs;

    return Container(
      color: _ReelEditTheme.of(context).surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text('TRIM VIDEO',
                  style: _DS.label(context,
                      color: _ReelEditTheme.of(context).textDim, size: 11)),
              const Spacer(),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _ReelEditTheme.of(context).surface2,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${_formatDuration(startMs)} → ${_formatDuration(endMs)} (${_formatDuration(trimmedDurationMs)})',
                  style: _DS.label(context,
                      size: 10, color: _ReelEditTheme.of(context).accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _TrimRangeSlider(
            controller: widget.controller,
            trimStart: widget.trimStart,
            trimEnd: widget.trimEnd,
            onTrimChanged: widget.onTrimChanged,
            onSeek: widget.onSeek,
          ),
          const SizedBox(height: 16),
          _buildPlaybackControls(duration),
        ],
      ),
    );
  }

  String _formatDuration(int ms) {
    final totalSeconds = ms / 1000;
    final minutes = (totalSeconds / 60).floor();
    final seconds = (totalSeconds % 60).floor();
    final millis = ((totalSeconds % 1) * 10).floor();

    if (minutes > 0) {
      return '$minutes:${seconds.toString().padLeft(2, '0')}.$millis';
    }
    return '${seconds}.$millis s';
  }

  Widget _buildPlaybackControls(Duration duration) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _PlaybackButton(
          icon: Icons.skip_previous_rounded,
          tooltip: 'Go to start',
          onTap: () => widget.onSeek(widget.trimStart),
        ),
        const SizedBox(width: 12),
        _PlaybackButton(
          icon: Icons.replay_5_rounded,
          tooltip: 'Back 5s',
          onTap: () {
            final current =
                widget.controller?.value.position.inMilliseconds ?? 0;
            final newPos = (current - 5000) / duration.inMilliseconds;
            widget.onSeek(newPos.clamp(widget.trimStart, widget.trimEnd));
          },
        ),
        const SizedBox(width: 12),
        ValueListenableBuilder<bool>(
          valueListenable: widget.isPlaying,
          builder: (_, playing, __) {
            return GestureDetector(
              onTap: widget.onTogglePlay,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _ReelEditTheme.of(context).accent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color:
                      _ReelEditTheme.of(context).accent.withOpacity(0.3),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.black,
                  size: 30,
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 12),
        _PlaybackButton(
          icon: Icons.forward_5_rounded,
          tooltip: 'Forward 5s',
          onTap: () {
            final current =
                widget.controller?.value.position.inMilliseconds ?? 0;
            final newPos = (current + 5000) / duration.inMilliseconds;
            widget.onSeek(newPos.clamp(widget.trimStart, widget.trimEnd));
          },
        ),
        const SizedBox(width: 12),
        _PlaybackButton(
          icon: Icons.skip_next_rounded,
          tooltip: 'Go to end',
          onTap: () => widget.onSeek(widget.trimEnd - 0.01),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TRIM RANGE SLIDER
// ═══════════════════════════════════════════════════════════════════════════

class _TrimRangeSlider extends StatefulWidget {
  final VideoPlayerController? controller;
  final double trimStart;
  final double trimEnd;
  final void Function(double start, double end) onTrimChanged;
  final void Function(double position) onSeek;

  const _TrimRangeSlider({
    required this.controller,
    required this.trimStart,
    required this.trimEnd,
    required this.onTrimChanged,
    required this.onSeek,
  });

  @override
  State<_TrimRangeSlider> createState() => _TrimRangeSliderState();
}

class _TrimRangeSliderState extends State<_TrimRangeSlider> {
  static const double _handleWidth = 24.0;
  static const double _trackHeight = 56.0;

  _DragTarget? _currentDrag;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final trackWidth = totalWidth - _handleWidth;

        final startHandleLeft = widget.trimStart * trackWidth;
        final endHandleLeft = widget.trimEnd * trackWidth;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (details) =>
              _onDragStart(details, trackWidth),
          onHorizontalDragUpdate: (details) =>
              _onDragUpdate(details, trackWidth),
          onHorizontalDragEnd: (_) => _onDragEnd(),
          onTapUp: (details) => _onTap(details, trackWidth),
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
                      color: _ReelEditTheme.of(context).surface2,
                      borderRadius: BorderRadius.circular(4),
                      border:
                      Border.all(color: _ReelEditTheme.of(context).border),
                    ),
                    child: CustomPaint(
                      painter: _TimelineGridPainter(
                        borderColor: _ReelEditTheme.of(context).border,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: _handleWidth / 2,
                  top: 8,
                  width: startHandleLeft,
                  height: _trackHeight,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(4),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: endHandleLeft + _handleWidth / 2,
                  right: _handleWidth / 2,
                  top: 8,
                  height: _trackHeight,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(4),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: startHandleLeft + _handleWidth / 2,
                  width: endHandleLeft - startHandleLeft,
                  top: 8,
                  height: _trackHeight,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                            color: _ReelEditTheme.of(context).accent,
                            width: 3),
                        bottom: BorderSide(
                            color: _ReelEditTheme.of(context).accent,
                            width: 3),
                      ),
                      color:
                      _ReelEditTheme.of(context).accent.withOpacity(0.08),
                    ),
                  ),
                ),
                if (widget.controller != null &&
                    widget.controller!.value.isInitialized)
                  _buildPlayhead(trackWidth),
                Positioned(
                  left: startHandleLeft,
                  top: 4,
                  child: _TrimHandle(
                    isStart: true,
                    isActive: _currentDrag == _DragTarget.start,
                    height: _trackHeight + 8,
                    width: _handleWidth,
                  ),
                ),
                Positioned(
                  left: endHandleLeft,
                  top: 4,
                  child: _TrimHandle(
                    isStart: false,
                    isActive: _currentDrag == _DragTarget.end,
                    height: _trackHeight + 8,
                    width: _handleWidth,
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildTimeLabels(trackWidth),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlayhead(double trackWidth) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: widget.controller!,
      builder: (_, value, __) {
        final duration = value.duration.inMilliseconds;
        if (duration == 0) return const SizedBox.shrink();

        final position = value.position.inMilliseconds / duration;
        final left = position * trackWidth + _handleWidth / 2;

        return Positioned(
          left: left - 1.5,
          top: 4,
          child: Container(
            width: 3,
            height: _trackHeight + 8,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimeLabels(double trackWidth) {
    final duration = widget.controller?.value.duration ?? Duration.zero;

    return Padding(
      padding:
      EdgeInsets.only(left: _handleWidth / 2, right: _handleWidth / 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _formatTime(
                (duration.inMilliseconds * widget.trimStart).round()),
            style: _DS.label(context,
                size: 9, color: _ReelEditTheme.of(context).accent),
          ),
          Text(
            _formatTime((duration.inMilliseconds * widget.trimEnd).round()),
            style: _DS.label(context,
                size: 9, color: _ReelEditTheme.of(context).accent),
          ),
        ],
      ),
    );
  }

  String _formatTime(int ms) {
    final seconds = (ms / 1000).floor();
    final millis = ((ms % 1000) / 100).floor();
    return '$seconds.${millis}s';
  }

  void _onDragStart(DragStartDetails details, double trackWidth) {
    final localX = details.localPosition.dx;

    final startHandleCenter =
        widget.trimStart * trackWidth + _handleWidth / 2;
    final endHandleCenter = widget.trimEnd * trackWidth + _handleWidth / 2;

    final distToStart = (localX - startHandleCenter).abs();
    final distToEnd = (localX - endHandleCenter).abs();

    const touchTolerance = 40.0;

    if (distToStart < touchTolerance && distToStart <= distToEnd) {
      setState(() => _currentDrag = _DragTarget.start);
      _DS.hapticLight();
    } else if (distToEnd < touchTolerance) {
      setState(() => _currentDrag = _DragTarget.end);
      _DS.hapticLight();
    } else {
      setState(() => _currentDrag = _DragTarget.playhead);
    }
  }

  void _onDragUpdate(DragUpdateDetails details, double trackWidth) {
    if (_currentDrag == null) return;

    final delta = details.delta.dx / trackWidth;

    switch (_currentDrag!) {
      case _DragTarget.start:
        final newStart =
        (widget.trimStart + delta).clamp(0.0, widget.trimEnd - 0.05);
        widget.onTrimChanged(newStart, widget.trimEnd);
        widget.onSeek(newStart);
        break;

      case _DragTarget.end:
        final newEnd =
        (widget.trimEnd + delta).clamp(widget.trimStart + 0.05, 1.0);
        widget.onTrimChanged(widget.trimStart, newEnd);
        widget.onSeek(newEnd);
        break;

      case _DragTarget.playhead:
        final position =
            (details.localPosition.dx - _handleWidth / 2) / trackWidth;
        final clampedPosition =
        position.clamp(widget.trimStart, widget.trimEnd);
        widget.onSeek(clampedPosition);
        break;
    }
  }

  void _onDragEnd() {
    setState(() => _currentDrag = null);
  }

  void _onTap(TapUpDetails details, double trackWidth) {
    final localX = details.localPosition.dx;
    final position = (localX - _handleWidth / 2) / trackWidth;
    final clampedPosition = position.clamp(widget.trimStart, widget.trimEnd);
    widget.onSeek(clampedPosition);
  }
}

enum _DragTarget { start, end, playhead }

// ═══════════════════════════════════════════════════════════════════════════
// TRIM HANDLE
// ═══════════════════════════════════════════════════════════════════════════

class _TrimHandle extends StatelessWidget {
  final bool isStart;
  final bool isActive;
  final double height;
  final double width;

  const _TrimHandle({
    required this.isStart,
    required this.isActive,
    required this.height,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isActive
            ? _ReelEditTheme.of(context).accent
            : _ReelEditTheme.of(context).accent.withOpacity(0.9),
        borderRadius: BorderRadius.horizontal(
          left: isStart ? const Radius.circular(6) : Radius.zero,
          right: isStart ? Radius.zero : const Radius.circular(6),
        ),
        boxShadow: [
          BoxShadow(
            color: isActive
                ? _ReelEditTheme.of(context).accent.withOpacity(0.5)
                : Colors.black.withOpacity(0.3),
            blurRadius: isActive ? 12 : 4,
            spreadRadius: isActive ? 2 : 0,
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isStart ? Icons.chevron_right : Icons.chevron_left,
              color: Colors.black.withOpacity(0.5),
              size: 16,
            ),
            const SizedBox(height: 2),
            ...List.generate(
                3,
                    (_) => Container(
                  margin: const EdgeInsets.symmetric(vertical: 1.5),
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    shape: BoxShape.circle,
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TIMELINE GRID PAINTER
// ═══════════════════════════════════════════════════════════════════════════

class _TimelineGridPainter extends CustomPainter {
  const _TimelineGridPainter({required this.borderColor});
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..strokeWidth = 1;

    const segments = 20;
    for (int i = 0; i <= segments; i++) {
      final x = (size.width / segments) * i;
      final isMain = i % 5 == 0;

      paint.color = borderColor.withOpacity(isMain ? 0.5 : 0.2);

      canvas.drawLine(
        Offset(x, isMain ? 0 : size.height * 0.3),
        Offset(x, size.height),
        paint,
      );
    }

    paint.color = borderColor.withOpacity(0.3);
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _TimelineGridPainter oldDelegate) =>
      oldDelegate.borderColor != borderColor;
}

// ═══════════════════════════════════════════════════════════════════════════
// PLAYBACK BUTTON
// ═══════════════════════════════════════════════════════════════════════════

class _PlaybackButton extends StatelessWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback onTap;

  const _PlaybackButton({
    required this.icon,
    this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: () async {
          await _DS.hapticLight();
          onTap();
        },
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _ReelEditTheme.of(context).surface2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _ReelEditTheme.of(context).border),
          ),
          child:
          Icon(icon, color: _ReelEditTheme.of(context).textSec, size: 22),
        ),
      ),
    );
  }
}
