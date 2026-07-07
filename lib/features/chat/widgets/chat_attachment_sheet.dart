import 'package:flutter/material.dart';

import '../../../core/utils/theme_helper.dart';

typedef ChatAttachmentAction = void Function();

class ChatAttachmentOption {
  final IconData icon;
  final String semanticLabel;
  final ChatAttachmentAction onTap;

  const ChatAttachmentOption({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });
}

/// Floating rounded attachment picker — icon grid, no text labels.
void showChatAttachmentSheet(
  BuildContext context, {
  required List<ChatAttachmentOption> options,
  String title = 'Share',
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      final bg = ThemeHelper.getBackgroundColor(ctx);
      final surface = ThemeHelper.getSurfaceColor(ctx);
      final border = ThemeHelper.getBorderColor(ctx);
      final accent = ThemeHelper.getAccentColor(ctx);
      final textPrimary = ThemeHelper.getTextPrimary(ctx);

      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: bg,
            border: Border.all(color: border.withValues(alpha: 0.55)),
            boxShadow: [
              BoxShadow(
                color: textPrimary.withValues(alpha: isDark ? 0.28 : 0.12),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => Navigator.pop(ctx),
                        icon: Icon(Icons.close_rounded, color: ThemeHelper.getTextSecondary(ctx)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    alignment: WrapAlignment.start,
                    children: options.map((opt) {
                      return _IconTile(
                        icon: opt.icon,
                        label: opt.semanticLabel,
                        surface: surface,
                        border: border,
                        accent: accent,
                        isDark: isDark,
                        onTap: () {
                          Navigator.pop(ctx);
                          opt.onTap();
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _IconTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color surface;
  final Color border;
  final Color accent;
  final bool isDark;
  final VoidCallback onTap;

  const _IconTile({
    required this.icon,
    required this.label,
    required this.surface,
    required this.border,
    required this.accent,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: border.withValues(alpha: isDark ? 0.6 : 0.45),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: accent, size: 28),
          ),
        ),
      ),
    );
  }
}
