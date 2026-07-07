import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/reel_audio_clip.dart';
import '../models/reel_audio_timeline_state.dart';
import '../services/reel_audio_cache_service.dart';
import 'reel_edit_playback_provider.dart';

class ReelAudioTimelineNotifier extends StateNotifier<ReelAudioTimelineState> {
  ReelAudioTimelineNotifier(this.ref) : super(const ReelAudioTimelineState());

  final Ref ref;

  void setVideoDurationSec(double seconds) {
    if (seconds <= 0 || state.videoDurationSec == seconds) return;
    state = state.copyWith(videoDurationSec: seconds);
  }

  void selectClip(String? clipId) {
    state = state.copyWith(
      selectedClipId: clipId,
      clearSelectedClip: clipId == null,
    );
  }

  void setZoom(double pixelsPerSecond) {
    state = state.copyWith(
      pixelsPerSecond: pixelsPerSecond.clamp(24, 160),
    );
  }

  void setScrollOffsetSec(double offsetSec) {
    state = state.copyWith(scrollOffsetSec: offsetSec.clamp(0, double.infinity));
  }

  void toggleVideoAudioMuted() {
    state = state.copyWith(videoAudioMuted: !state.videoAudioMuted);
  }

  void toggleMusicMuted() {
    state = state.copyWith(musicMuted: !state.musicMuted);
  }

  void nudgeZoom(double delta) {
    setZoom(state.pixelsPerSecond + delta);
  }

  void setClipDragging(bool dragging) {
    if (state.isClipDragging == dragging) return;
    state = state.copyWith(isClipDragging: dragging);
  }

  Future<void> addClipFromPicker(Map<String, dynamic> pickerResult) async {
    final playback = ref.read(reelEditPlaybackProvider);
    final durationSec = playback.videoDurationSec > 0
        ? playback.videoDurationSec
        : state.videoDurationSec;

    var clip = ReelAudioClip.fromPickerMap(
      pickerResult,
      videoDurationSec: durationSec,
    );

    state = state.copyWith(
      isBusy: true,
      busyMessage: 'Downloading audio…',
    );

    final localPath = await ReelAudioCacheService.instance.ensureLocalFile(
      url: clip.sourceUrl,
      clipId: clip.id,
    );

    if (localPath != null) {
      clip = clip.copyWith(localFilePath: localPath);
    }

    state = state.copyWith(
      clips: [...state.clips, clip],
      selectedClipId: clip.id,
      isBusy: false,
      clearBusyMessage: true,
    );
  }

  Future<void> addLocalClip({
    required String filePath,
    required String title,
    ReelAudioClipType type = ReelAudioClipType.voiceover,
    double sourceDurationSec = 30,
  }) async {
    final id = '${DateTime.now().microsecondsSinceEpoch}';
    final clip = ReelAudioClip(
      id: id,
      trackId: id,
      title: title,
      subtitle: type.name,
      sourceUrl: 'file://$filePath',
      localFilePath: filePath,
      type: type,
      sourceDurationSec: sourceDurationSec,
      sourceTrimEndSec: sourceDurationSec,
      waveformSamples: generatePseudoWaveform(id),
    );
    state = state.copyWith(
      clips: [...state.clips, clip],
      selectedClipId: clip.id,
    );
  }

  void moveClip(String clipId, double newTimelineOffsetSec) {
    final maxOffset = (state.videoDurationSec - 0.1).clamp(0, double.infinity);
    final clamped = newTimelineOffsetSec.clamp(0, maxOffset).toDouble();
    state = state.copyWith(
      clips: state.clips
          .map((c) => c.id == clipId
              ? c.copyWith(timelineOffsetSec: clamped)
              : c)
          .toList(),
    );
  }

  void trimClipStart(String clipId, double newSourceTrimStartSec) {
    state = state.copyWith(
      clips: state.clips.map((clip) {
        if (clip.id != clipId) return clip;
        final maxStart = clip.effectiveTrimEndSec - 0.25;
        final newStart =
            newSourceTrimStartSec.clamp(0.0, maxStart).toDouble();
        final delta = newStart - clip.sourceTrimStartSec;
        return clip.copyWith(
          sourceTrimStartSec: newStart,
          timelineOffsetSec:
              (clip.timelineOffsetSec + delta).clamp(0.0, double.infinity),
        );
      }).toList(),
    );
  }

  void trimClipEnd(String clipId, double newSourceTrimEndSec) {
    state = state.copyWith(
      clips: state.clips.map((clip) {
        if (clip.id != clipId) return clip;
        final end = newSourceTrimEndSec.clamp(
          clip.sourceTrimStartSec + 0.25,
          clip.sourceDurationSec,
        ).toDouble();
        return clip.copyWith(sourceTrimEndSec: end);
      }).toList(),
    );
  }

  Future<void> removeClip(String clipId) async {
    await ReelAudioCacheService.instance.clearClip(clipId);
    state = state.copyWith(
      clips: state.clips.where((c) => c.id != clipId).toList(),
      clearSelectedClip: state.selectedClipId == clipId,
    );
  }
}

final reelAudioTimelineProvider = StateNotifierProvider.autoDispose<
    ReelAudioTimelineNotifier, ReelAudioTimelineState>(
  ReelAudioTimelineNotifier.new,
);
