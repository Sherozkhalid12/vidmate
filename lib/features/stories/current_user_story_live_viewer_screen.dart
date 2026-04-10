import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/story_model.dart';
import '../../core/models/user_model.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/providers/network_status_provider.dart';
import '../feed/create_content_screen.dart';
import 'stories_viewer_screen.dart';

/// Full-screen story viewer for the signed-in user only (no Live tab).
class CurrentUserStoriesViewerScreen extends ConsumerWidget {
  final UserModel currentUser;
  final List<StoryModel> stories;

  const CurrentUserStoriesViewerScreen({
    super.key,
    required this.currentUser,
    required this.stories,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(isOfflineProvider);
    if (stories.isEmpty) {
      final bg = ThemeHelper.getBackgroundColor(context);
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.close, color: ThemeHelper.getTextPrimary(context)),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_stories_outlined,
                    size: 56, color: ThemeHelper.getTextSecondary(context)),
                const SizedBox(height: 14),
                Text(
                  'No stories yet',
                  style: TextStyle(
                    color: ThemeHelper.getTextPrimary(context),
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: ThemeHelper.getAccentColor(context),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CreateContentScreen(
                          initialType: ContentType.story,
                        ),
                      ),
                    );
                  },
                  child: const Text('Add Story'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return StoriesViewerScreen(
      initialUserIndex: 0,
      initialStoryIndex: 0,
      users: [currentUser],
      userStoriesMap: {currentUser.id: stories},
      offline: offline,
    );
  }
}
