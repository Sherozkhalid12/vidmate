import 'package:flutter/material.dart';

import '../utils/theme_helper.dart';

/// Music credit line: `[musicName] · [musicTitle]` when both are non-empty.
class MusicAttributionLabel extends StatelessWidget {
  final String? musicName;
  final String? musicTitle;
  final EdgeInsetsGeometry padding;
  final TextAlign textAlign;
  final int maxLines;
  /// When set (e.g. story overlay on black), overrides [ThemeHelper] text/icon colors.
  final Color? textColor;
  final Color? iconColor;

  const MusicAttributionLabel({
    super.key,
    required this.musicName,
    required this.musicTitle,
    this.padding = EdgeInsets.zero,
    this.textAlign = TextAlign.start,
    this.maxLines = 2,
    this.textColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final n = musicName?.trim() ?? '';
    final t = musicTitle?.trim() ?? '';
    if (n.isEmpty || t.isEmpty) return const SizedBox.shrink();

    final iconC = iconColor ?? ThemeHelper.getTextMuted(context);
    final textC = textColor ?? ThemeHelper.getTextSecondary(context);
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.music_note_rounded,
            size: 14,
            color: iconC,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$n · $t',
              textAlign: textAlign,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textC,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
