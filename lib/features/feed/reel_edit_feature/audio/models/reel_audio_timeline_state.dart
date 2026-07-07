import 'package:flutter/foundation.dart';

import 'reel_audio_clip.dart';

@immutable
class ReelAudioTimelineState {
  const ReelAudioTimelineState({
    this.clips = const [],
    this.selectedClipId,
    this.videoDurationSec = 0,
    this.pixelsPerSecond = 56,
    this.scrollOffsetSec = 0,
    this.isBusy = false,
    this.busyMessage,
    this.videoAudioMuted = false,
    this.musicMuted = false,
    this.isClipDragging = false,
  });

  final List<ReelAudioClip> clips;
  final String? selectedClipId;
  final double videoDurationSec;
  final double pixelsPerSecond;
  final double scrollOffsetSec;
  final bool isBusy;
  final String? busyMessage;
  final bool videoAudioMuted;
  final bool musicMuted;
  final bool isClipDragging;

  ReelAudioClip? get selectedClip {
    final id = selectedClipId;
    if (id == null) return null;
    for (final clip in clips) {
      if (clip.id == id) return clip;
    }
    return null;
  }

  bool get hasClips => clips.isNotEmpty;

  double get timelineWidthPx =>
      (videoDurationSec * pixelsPerSecond).clamp(120, double.infinity);

  ReelAudioTimelineState copyWith({
    List<ReelAudioClip>? clips,
    String? selectedClipId,
    bool clearSelectedClip = false,
    double? videoDurationSec,
    double? pixelsPerSecond,
    double? scrollOffsetSec,
    bool? isBusy,
    String? busyMessage,
    bool clearBusyMessage = false,
    bool? videoAudioMuted,
    bool? musicMuted,
    bool? isClipDragging,
  }) {
    return ReelAudioTimelineState(
      clips: clips ?? this.clips,
      selectedClipId:
          clearSelectedClip ? null : (selectedClipId ?? this.selectedClipId),
      videoDurationSec: videoDurationSec ?? this.videoDurationSec,
      pixelsPerSecond: pixelsPerSecond ?? this.pixelsPerSecond,
      scrollOffsetSec: scrollOffsetSec ?? this.scrollOffsetSec,
      isBusy: isBusy ?? this.isBusy,
      busyMessage:
          clearBusyMessage ? null : (busyMessage ?? this.busyMessage),
      videoAudioMuted: videoAudioMuted ?? this.videoAudioMuted,
      musicMuted: musicMuted ?? this.musicMuted,
      isClipDragging: isClipDragging ?? this.isClipDragging,
    );
  }
}
