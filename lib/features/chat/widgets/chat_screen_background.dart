import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/chat_theme_preset.dart';
import '../../../core/providers/chat_settings_provider.dart';
import '../../../core/utils/theme_helper.dart';

/// Applies per-conversation chat background / theme.
class ChatScreenBackground extends ConsumerWidget {
  final String conversationId;
  final Widget child;

  const ChatScreenBackground({
    super.key,
    required this.conversationId,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(chatSettingsProvider.notifier).settingsFor(conversationId);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = settings.theme.gradientColors(isDark);
    final customUrl = settings.customBackgroundUrl;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (customUrl != null && customUrl.isNotEmpty)
            Opacity(
              opacity: isDark ? 0.35 : 0.25,
              child: CachedNetworkImage(
                imageUrl: customUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          // Subtle noise overlay for premium depth
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  ThemeHelper.getBackgroundColor(context).withValues(alpha: 0.05),
                  ThemeHelper.getBackgroundColor(context).withValues(alpha: 0.12),
                ],
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
