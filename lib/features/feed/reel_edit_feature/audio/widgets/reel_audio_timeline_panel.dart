import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../select_music_screen.dart';
import '../providers/reel_audio_preview_provider.dart';
import '../providers/reel_audio_timeline_provider.dart';
import '../models/reel_audio_timeline_state.dart';
import '../providers/reel_edit_playback_provider.dart';
import 'reel_audio_clip_widget.dart';
import 'reel_track_rail.dart';
import 'reel_video_thumbnail_strip.dart';

/// Instagram Reels–style audio timeline with video strip, clips, and playhead.
class ReelAudioTimelinePanel extends ConsumerStatefulWidget {
  const ReelAudioTimelinePanel({
    super.key,
    required this.videoFilePath,
    this.onTogglePlay,
    this.onSeekRelativeSec,
  });

  final String videoFilePath;
  final VoidCallback? onTogglePlay;
  final void Function(double relativeSec)? onSeekRelativeSec;

  @override
  ConsumerState<ReelAudioTimelinePanel> createState() =>
      _ReelAudioTimelinePanelState();
}

class _ReelAudioTimelinePanelState
    extends ConsumerState<ReelAudioTimelinePanel> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(reelAudioPreviewProvider);

    final timeline = ref.watch(reelAudioTimelineProvider);
    final playback = ref.watch(reelEditPlaybackProvider);
    final pps = timeline.pixelsPerSecond;
    final durationSec = timeline.videoDurationSec > 0
        ? timeline.videoDurationSec
        : playback.videoDurationSec;
    final trackWidth = durationSec * pps;
    final playheadLeft = playback.relativePositionSec * pps;
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(playback, timeline),
          const SizedBox(height: 8),
          if (timeline.isBusy) _buildBusyRow(timeline.busyMessage),
          Text(
            'Drag center to move · Drag edges to trim · Tap video to seek',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ReelTrackRail(
                videoMuted: timeline.videoAudioMuted,
                musicMuted: timeline.musicMuted,
                canDeleteClip: timeline.selectedClipId != null,
                onToggleVideoMute: () => ref
                    .read(reelAudioTimelineProvider.notifier)
                    .toggleVideoAudioMuted(),
                onToggleMusicMute: () => ref
                    .read(reelAudioTimelineProvider.notifier)
                    .toggleMusicMuted(),
                onDeleteClip: () {
                  final id = timeline.selectedClipId;
                  if (id != null) {
                    ref.read(reelAudioTimelineProvider.notifier).removeClip(id);
                  }
                },
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 100,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                      decelerationRate: ScrollDecelerationRate.fast,
                    ),
                    child: SizedBox(
                      width: trackWidth.clamp(120, double.infinity),
                      height: 100,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: 0,
                            top: 0,
                            width: trackWidth,
                            height: ReelTrackRail.videoTrackH,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTapDown: (details) => _seekToTimelineX(
                                details.localPosition.dx,
                                durationSec,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: ReelVideoThumbnailStrip(
                                  videoPath: widget.videoFilePath,
                                  durationSec: durationSec,
                                  pixelsPerSecond: pps,
                                  width: trackWidth,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            top: ReelTrackRail.videoTrackH +
                                ReelTrackRail.gap,
                            width: trackWidth,
                            height: ReelTrackRail.audioTrackH,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.white12),
                                  ),
                                ),
                                ...timeline.clips.map(
                                  (clip) => ReelAudioClipWidget(
                                    clip: clip,
                                    pixelsPerSecond: pps,
                                    isSelected:
                                        timeline.selectedClipId == clip.id,
                                    onSelect: () => ref
                                        .read(reelAudioTimelineProvider
                                            .notifier)
                                        .selectClip(clip.id),
                                  ),
                                ),
                                if (timeline.clips.isEmpty)
                                  const Center(
                                    child: Text(
                                      'Tap Add music below',
                                      style: TextStyle(
                                        color: Colors.white38,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Positioned(
                            left: playheadLeft,
                            top: 0,
                            bottom: 0,
                            child: IgnorePointer(
                              child: Container(
                                width: 2,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.4),
                                      blurRadius: 3,
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
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _ActionChip(
                icon: Icons.library_music_outlined,
                label: 'Add music',
                onTap: () => _pickMusic(context),
              ),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () => ref
                    .read(reelAudioTimelineProvider.notifier)
                    .nudgeZoom(-8),
                icon:
                    const Icon(Icons.remove, color: Colors.white54, size: 18),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () => ref
                    .read(reelAudioTimelineProvider.notifier)
                    .nudgeZoom(8),
                icon: const Icon(Icons.add, color: Colors.white54, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBusyRow(String? message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text(
            message ?? 'Loading…',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    ReelEditPlaybackState playback,
    ReelAudioTimelineState timeline,
  ) {
    final pos = _formatTime(playback.relativePositionSec);
    final dur = _formatTime(playback.trimmedDurationMs / 1000);

    return Row(
      children: [
        GestureDetector(
          onTap: widget.onTogglePlay,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              playback.isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$pos / $dur',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const Spacer(),
        Text(
          '${timeline.clips.length} clip(s)',
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
      ],
    );
  }

  Future<void> _pickMusic(BuildContext context) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const SelectMusicScreen()),
    );
    if (result == null) return;
    await ref.read(reelAudioTimelineProvider.notifier).addClipFromPicker(result);
  }

  void _seekToTimelineX(double x, double durationSec) {
    if (durationSec <= 0) return;
    final pps = ref.read(reelAudioTimelineProvider).pixelsPerSecond;
    final sec = (x / pps).clamp(0.0, durationSec);
    widget.onSeekRelativeSec?.call(sec);
  }

  String _formatTime(double seconds) {
    final s = seconds.floor();
    final ms = ((seconds - s) * 10).floor();
    final m = s ~/ 60;
    final rem = s % 60;
    if (m > 0) {
      return '$m:${rem.toString().padLeft(2, '0')}.$ms';
    }
    return '0:${rem.toString().padLeft(2, '0')}.$ms';
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF334155),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white70),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
