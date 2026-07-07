import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/reel_audio_clip.dart';
import '../providers/reel_audio_timeline_provider.dart';
import 'reel_audio_waveform_painter.dart';

class ReelAudioClipWidget extends ConsumerStatefulWidget {
  const ReelAudioClipWidget({
    super.key,
    required this.clip,
    required this.pixelsPerSecond,
    required this.isSelected,
    required this.onSelect,
  });

  final ReelAudioClip clip;
  final double pixelsPerSecond;
  final bool isSelected;
  final VoidCallback onSelect;

  @override
  ConsumerState<ReelAudioClipWidget> createState() =>
      _ReelAudioClipWidgetState();
}

class _ReelAudioClipWidgetState extends ConsumerState<ReelAudioClipWidget> {
  static const _clipColor = Color(0xFF9B59F5);
  static const _handleWidth = 22.0;

  double _dragOffsetPx = 0;
  double _trimStartDeltaPx = 0;
  double _trimEndDeltaPx = 0;
  _DragMode _dragMode = _DragMode.none;

  ReelAudioClip get clip => widget.clip;
  double get pps => widget.pixelsPerSecond;

  ReelAudioTimelineNotifier get _notifier =>
      ref.read(reelAudioTimelineProvider.notifier);

  void _beginDrag(_DragMode mode) {
    _dragMode = mode;
    _dragOffsetPx = 0;
    _trimStartDeltaPx = 0;
    _trimEndDeltaPx = 0;
    _notifier.setClipDragging(true);
  }

  void _endDrag() {
    if (_dragMode == _DragMode.none) return;

    switch (_dragMode) {
      case _DragMode.move:
        if (_dragOffsetPx.abs() > 0.5) {
          final deltaSec = _dragOffsetPx / pps;
          _notifier.moveClip(
            clip.id,
            clip.timelineOffsetSec + deltaSec,
          );
        }
      case _DragMode.trimStart:
        if (_trimStartDeltaPx.abs() > 0.5) {
          final deltaSec = _trimStartDeltaPx / pps;
          _notifier.trimClipStart(
            clip.id,
            clip.sourceTrimStartSec + deltaSec,
          );
        }
      case _DragMode.trimEnd:
        if (_trimEndDeltaPx.abs() > 0.5) {
          final deltaSec = _trimEndDeltaPx / pps;
          _notifier.trimClipEnd(
            clip.id,
            clip.effectiveTrimEndSec + deltaSec,
          );
        }
      case _DragMode.none:
        break;
    }

    setState(() {
      _dragMode = _DragMode.none;
      _dragOffsetPx = 0;
      _trimStartDeltaPx = 0;
      _trimEndDeltaPx = 0;
    });
    _notifier.setClipDragging(false);
  }

  void _cancelDrag() {
    if (_dragMode == _DragMode.none) return;
    setState(() {
      _dragMode = _DragMode.none;
      _dragOffsetPx = 0;
      _trimStartDeltaPx = 0;
      _trimEndDeltaPx = 0;
    });
    _notifier.setClipDragging(false);
  }

  @override
  Widget build(BuildContext context) {
    final trimStartSec = _trimStartDeltaPx / pps;
    final trimEndSec = _trimEndDeltaPx / pps;
    final previewClip = _dragMode == _DragMode.trimStart
        ? clip.copyWith(
            sourceTrimStartSec: (clip.sourceTrimStartSec + trimStartSec)
                .clamp(0.0, clip.effectiveTrimEndSec - 0.25),
            timelineOffsetSec: clip.timelineOffsetSec + trimStartSec,
          )
        : _dragMode == _DragMode.trimEnd
            ? clip.copyWith(
                sourceTrimEndSec: (clip.effectiveTrimEndSec + trimEndSec)
                    .clamp(
                      clip.sourceTrimStartSec + 0.25,
                      clip.sourceDurationSec,
                    ),
              )
            : clip;

    final width = (previewClip.clipDurationSec * pps).clamp(56.0, double.infinity);
    final left = previewClip.timelineOffsetSec * pps + _dragOffsetPx;

    return Positioned(
      left: left,
      top: 2,
      width: width,
      height: 48,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: _clipColor.withValues(
                  alpha: widget.isSelected ? 0.95 : 0.85,
                ),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: widget.isSelected ? Colors.white : Colors.white30,
                  width: widget.isSelected ? 2 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: Stack(
                  children: [
                    Positioned.fill(
                      top: 14,
                      bottom: 2,
                      left: _handleWidth,
                      right: _handleWidth,
                      child: CustomPaint(
                        painter: ReelAudioWaveformPainter(
                          samples: previewClip.waveformSamples,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                    Positioned(
                      left: _handleWidth + 4,
                      right: _handleWidth + 4,
                      top: 3,
                      child: Text(
                        previewClip.displayLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          shadows: [
                            Shadow(color: Colors.black45, blurRadius: 2),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: _handleWidth,
            right: _handleWidth,
            top: 0,
            bottom: 0,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: widget.onSelect,
              onHorizontalDragStart: (_) => _beginDrag(_DragMode.move),
              onHorizontalDragUpdate: (d) {
                setState(() => _dragOffsetPx += d.delta.dx);
              },
              onHorizontalDragEnd: (_) => _endDrag(),
              onHorizontalDragCancel: _cancelDrag,
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: _handleWidth,
            child: _TrimHandle(
              isStart: true,
              onDragStart: () => _beginDrag(_DragMode.trimStart),
              onDragUpdate: (dx) {
                setState(() => _trimStartDeltaPx += dx);
              },
              onDragEnd: _endDrag,
              onDragCancel: _cancelDrag,
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: _handleWidth,
            child: _TrimHandle(
              isStart: false,
              onDragStart: () => _beginDrag(_DragMode.trimEnd),
              onDragUpdate: (dx) {
                setState(() => _trimEndDeltaPx += dx);
              },
              onDragEnd: _endDrag,
              onDragCancel: _cancelDrag,
            ),
          ),
        ],
      ),
    );
  }
}

enum _DragMode { none, move, trimStart, trimEnd }

class _TrimHandle extends StatelessWidget {
  const _TrimHandle({
    required this.isStart,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onDragCancel,
  });

  final bool isStart;
  final VoidCallback onDragStart;
  final void Function(double dx) onDragUpdate;
  final VoidCallback onDragEnd;
  final VoidCallback onDragCancel;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) => onDragStart(),
      onHorizontalDragUpdate: (d) => onDragUpdate(d.delta.dx),
      onHorizontalDragEnd: (_) => onDragEnd(),
      onHorizontalDragCancel: onDragCancel,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.horizontal(
            left: isStart ? const Radius.circular(5) : Radius.zero,
            right: isStart ? Radius.zero : const Radius.circular(5),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isStart ? Icons.chevron_left : Icons.chevron_right,
              size: 14,
              color: const Color(0xFF5B2C9E),
            ),
            ...List.generate(
              3,
              (_) => Container(
                width: 3,
                height: 3,
                margin: const EdgeInsets.symmetric(vertical: 1.5),
                decoration: const BoxDecoration(
                  color: Color(0xFF5B2C9E),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
