import 'package:flutter/material.dart';

/// Fixed left rail with mute / delete actions outside the scrollable tracks.
class ReelTrackRail extends StatelessWidget {
  const ReelTrackRail({
    super.key,
    required this.videoMuted,
    required this.musicMuted,
    required this.canDeleteClip,
    required this.onToggleVideoMute,
    required this.onToggleMusicMute,
    required this.onDeleteClip,
  });

  final bool videoMuted;
  final bool musicMuted;
  final bool canDeleteClip;
  final VoidCallback onToggleVideoMute;
  final VoidCallback onToggleMusicMute;
  final VoidCallback onDeleteClip;

  static const videoTrackH = 30.0;
  static const audioTrackH = 62.0;
  static const gap = 8.0;
  static const railWidth = 36.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: railWidth,
      child: Column(
        children: [
          SizedBox(
            height: videoTrackH,
            child: Center(
              child: _RailIcon(
                icon: videoMuted ? Icons.videocam_off_outlined : Icons.videocam_outlined,
                active: videoMuted,
                tooltip: videoMuted ? 'Unmute video audio' : 'Mute video audio',
                onTap: onToggleVideoMute,
              ),
            ),
          ),
          const SizedBox(height: gap),
          SizedBox(
            height: audioTrackH,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _RailIcon(
                  icon: musicMuted
                      ? Icons.music_off_outlined
                      : Icons.library_music_outlined,
                  active: musicMuted,
                  tooltip: musicMuted ? 'Unmute music' : 'Mute music',
                  onTap: onToggleMusicMute,
                ),
                _RailIcon(
                  icon: Icons.delete_outline,
                  active: canDeleteClip,
                  enabled: canDeleteClip,
                  tooltip: 'Delete selected clip',
                  onTap: onDeleteClip,
                  danger: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RailIcon extends StatelessWidget {
  const _RailIcon({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.active = false,
    this.enabled = true,
    this.danger = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final bool active;
  final bool enabled;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = !enabled
        ? Colors.white24
        : active
            ? (danger ? const Color(0xFFF87171) : const Color(0xFF60A5FA))
            : Colors.white60;

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: active
                ? color.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: active ? color.withValues(alpha: 0.5) : Colors.white12,
            ),
          ),
          child: Icon(icon, size: 15, color: color),
        ),
      ),
    );
  }
}
