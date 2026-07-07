import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/content_publish_provider_riverpod.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/utils/theme_helper.dart';
import 'create_content_screen.dart';
import 'widgets/content_preview_display.dart';

/// Pre-publish preview with iOS-style send to start upload in the background.
class ContentPreviewScreen extends ConsumerWidget {
  const ContentPreviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(contentPublishProvider.select((s) => s.draft));
    if (draft == null) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(gradient: context.backgroundGradient),
          child: Center(
            child: Text(
              'Nothing to preview',
              style: TextStyle(color: ThemeHelper.getTextSecondary(context)),
            ),
          ),
        ),
      );
    }

    final isPublishing = ref.watch(contentPublishUploadingProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(gradient: context.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              _PreviewAppBar(
                typeLabel: draft.typeLabel,
                onBack: () => Navigator.maybePop(context),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        draft.type == ContentType.story
                            ? 'This is how your story will look'
                            : 'This is how it will look in the feed',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: ThemeHelper.getTextSecondary(context),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ContentPreviewDisplay(draft: draft),
                    ],
                  ),
                ),
              ),
              _IosSendBar(
                enabled: !isPublishing,
                typeLabel: draft.typeLabel,
                onSend: () {
                  ref.read(contentPublishProvider.notifier).startPublish();
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewAppBar extends StatelessWidget {
  final String typeLabel;
  final VoidCallback onBack;

  const _PreviewAppBar({
    required this.typeLabel,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: ThemeHelper.getTextPrimary(context), size: 22),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Preview',
                  style: TextStyle(
                    color: ThemeHelper.getTextPrimary(context),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  typeLabel,
                  style: TextStyle(
                    color: ThemeHelper.getTextSecondary(context),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IosSendBar extends StatelessWidget {
  final bool enabled;
  final String typeLabel;
  final VoidCallback onSend;

  const _IosSendBar({
    required this.enabled,
    required this.typeLabel,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final accent = ThemeHelper.getAccentColor(context);
    final onAccent = ThemeHelper.getOnAccentColor(context);
    final surface = ThemeHelper.getBackgroundColor(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: surface,
        border: Border(
          top: BorderSide(
            color: ThemeHelper.getBorderColor(context).withValues(alpha: 0.45),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Ready to share',
                  style: TextStyle(
                    color: ThemeHelper.getTextPrimary(context),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tap send — upload continues on the previous screen',
                  style: TextStyle(
                    color: ThemeHelper.getTextSecondary(context),
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: enabled ? onSend : null,
              customBorder: const CircleBorder(),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: enabled ? 1 : 0.45,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent,
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    CupertinoIcons.arrow_up,
                    color: onAccent,
                    size: 26,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
