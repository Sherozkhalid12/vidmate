import 'package:flutter/material.dart';

import '../audio/attached_music_preview.dart';
import '../utils/theme_helper.dart';

/// Instagram-style music line with optional tap-to-play (30s preview, shared player).
class MusicStickerRow extends StatelessWidget {
  final String? previewUrl;
  final String? musicName;
  final String? musicTitle;
  final EdgeInsetsGeometry padding;
  /// When set (e.g. story overlay), overrides theme text/icon colors.
  final Color? textColor;
  final Color? iconColor;
  final Color? playButtonColor;

  const MusicStickerRow({
    super.key,
    required this.previewUrl,
    required this.musicName,
    required this.musicTitle,
    this.padding = EdgeInsets.zero,
    this.textColor,
    this.iconColor,
    this.playButtonColor,
  });

  @override
  Widget build(BuildContext context) {
    final n = musicName?.trim() ?? '';
    final t = musicTitle?.trim() ?? '';
    final url = previewUrl?.trim() ?? '';
    final hasAudio = url.isNotEmpty;

    final line = (n.isNotEmpty && t.isNotEmpty)
        ? '$n · $t'
        : (n.isNotEmpty
            ? n
            : (t.isNotEmpty ? t : (hasAudio ? 'Music' : '')));
    if (line.isEmpty) return const SizedBox.shrink();

    final iconC = iconColor ?? ThemeHelper.getTextMuted(context);
    final textC = textColor ?? ThemeHelper.getTextSecondary(context);
    final accent = playButtonColor ?? ThemeHelper.getAccentColor(context);

    return Padding(
      padding: padding,
      child: ListenableBuilder(
        listenable: AttachedMusicPreview.instance,
        builder: (context, _) {
          final playing = hasAudio && AttachedMusicPreview.instance.isPlayingUrl(url);
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: hasAudio
                  ? () => AttachedMusicPreview.instance.toggleSticker(url)
                  : null,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (hasAudio) ...[
                      Icon(
                        playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
                        size: 28,
                        color: accent,
                      ),
                      const SizedBox(width: 8),
                    ] else
                      Icon(
                        Icons.music_note_rounded,
                        size: 14,
                        color: iconC,
                      ),
                    if (!hasAudio) const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        line,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textC,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
