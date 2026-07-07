import 'package:flutter/material.dart';
import '../../features/feed/create_content_screen.dart';
import '../../features/live/live_stream_studio_screen.dart';
import '../utils/theme_helper.dart';

/// Bottom sheet for creating new content (Post, Story, Reel, Long Video, Live).
void showCreateContentSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final bgColor = ThemeHelper.getBackgroundColor(context);
      final surfaceColor = ThemeHelper.getSurfaceColor(context);
      final borderColor = ThemeHelper.getBorderColor(context);
      final textPrimary = ThemeHelper.getTextPrimary(context);
      final textSecondary = ThemeHelper.getTextSecondary(context);
      final accent = ThemeHelper.getAccentColor(context);

      final options = [
        (
          type: ContentType.story,
          label: 'Story',
          icon: Icons.auto_stories_outlined,
        ),
        (
          type: ContentType.reel,
          label: 'Reel',
          icon: Icons.video_library_outlined,
        ),
        (
          type: ContentType.longVideo,
          label: 'Long video',
          icon: Icons.movie_outlined,
        ),
        (
          type: ContentType.live,
          label: 'Live',
          icon: Icons.live_tv_rounded,
        ),
      ];

      return Container(
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor.withOpacity(0.6), width: 1),
          color: bgColor,
          boxShadow: [
            BoxShadow(
              color: textPrimary.withOpacity(isDark ? 0.25 : 0.12),
              blurRadius: 24,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Create',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      splashRadius: 20,
                      icon: Icon(
                        Icons.close_rounded,
                        color: textSecondary,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Choose what you want to share.',
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 20),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final opt = options[index];
                    final cardBg = surfaceColor;
                    final cardBorder =
                        borderColor.withOpacity(isDark ? 0.7 : 0.5);
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.pop(context);
                          if (opt.type == ContentType.live) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const LiveStreamStudioScreen(),
                              ),
                            );
                            return;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CreateContentScreen(
                                initialType: opt.type,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 8,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: cardBg,
                            border: Border.all(color: cardBorder, width: 1),
                            boxShadow: [
                              BoxShadow(
                                color: textPrimary
                                    .withOpacity(isDark ? 0.08 : 0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: accent.withOpacity(isDark ? 0.2 : 0.14),
                                ),
                                child: Icon(
                                  opt.icon,
                                  size: 22,
                                  color: accent,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                opt.label,
                                style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
