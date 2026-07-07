import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/chat_provider_riverpod.dart';
import '../../../core/utils/theme_helper.dart';

/// Theme-aware chat composer used by both DM and group chats.
class ChatInputBar extends ConsumerWidget {
  final TextEditingController controller;
  final String composerKey;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final bool sending;
  final String hintText;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.composerKey,
    required this.onSend,
    required this.onAttach,
    this.sending = false,
    this.hintText = 'Message...',
  });

  static const int _maxLines = 5;
  static const double _lineHeight = 22;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final composer = ref.watch(chatComposerProvider(composerKey));
    final surface = ThemeHelper.getSecondaryBackgroundColor(context);
    final fieldFill = isDark
        ? ThemeHelper.getBackgroundColor(context).withValues(alpha: 0.55)
        : ThemeHelper.getSurfaceColor(context);

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: surface.withValues(alpha: isDark ? 0.92 : 0.98),
          border: Border(
            top: BorderSide(
              color: ThemeHelper.getBorderColor(context).withValues(alpha: 0.35),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (composer.resolvingPost || composer.resolvedPostPreview != null)
              _PostPreviewBanner(composerKey: composerKey, composer: composer),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _AttachButton(onTap: onAttach),
                const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(
                      minHeight: 44,
                      maxHeight: _lineHeight * _maxLines + 24,
                    ),
                    decoration: BoxDecoration(
                      color: fieldFill,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: ThemeHelper.getBorderColor(context)
                            .withValues(alpha: isDark ? 0.45 : 0.55),
                      ),
                    ),
                    child: TextField(
                      controller: controller,
                      enabled: !sending,
                      minLines: 1,
                      maxLines: _maxLines,
                      textCapitalization: TextCapitalization.sentences,
                      style: TextStyle(
                        color: ThemeHelper.getTextPrimary(context),
                        fontSize: 15,
                        height: 1.35,
                      ),
                      decoration: InputDecoration(
                        hintText: hintText,
                        hintStyle: TextStyle(
                          color: ThemeHelper.getTextMuted(context),
                          fontSize: 15,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (_) => onSend(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _SendButton(onTap: sending ? null : onSend),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AttachButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: ThemeHelper.getAccentColor(context).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.add_rounded,
            color: ThemeHelper.getAccentColor(context),
            size: 24,
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final VoidCallback? onTap;

  const _SendButton({this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: ThemeHelper.getAccentGradient(context),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: ThemeHelper.getAccentColor(context).withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(
            Icons.arrow_upward_rounded,
            color: ThemeHelper.getOnAccentColor(context),
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _PostPreviewBanner extends ConsumerWidget {
  final String composerKey;
  final ChatComposerState composer;

  const _PostPreviewBanner({
    required this.composerKey,
    required this.composer,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ThemeHelper.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ThemeHelper.getBorderColor(context).withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          if (composer.resolvingPost)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: ThemeHelper.getAccentColor(context),
              ),
            )
          else
            Icon(Icons.link_rounded, size: 16, color: ThemeHelper.getAccentColor(context)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              composer.resolvingPost ? 'Resolving link...' : 'Link preview ready',
              style: TextStyle(
                color: ThemeHelper.getTextPrimary(context),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () =>
                ref.read(chatComposerProvider(composerKey).notifier).clearPreview(),
            icon: Icon(Icons.close_rounded, size: 16, color: ThemeHelper.getTextMuted(context)),
          ),
        ],
      ),
    );
  }
}
