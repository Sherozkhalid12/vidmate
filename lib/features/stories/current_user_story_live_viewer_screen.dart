import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/livestream_model.dart';
import '../../core/models/story_model.dart';
import '../../core/models/user_model.dart';
import '../../core/utils/theme_helper.dart';
import '../feed/create_content_screen.dart';
import '../live/live_join_overlay_screen.dart';
import '../live/live_stream_studio_screen.dart';
import 'stories_viewer_screen.dart';

class CurrentUserStoryLiveViewerScreen extends ConsumerWidget {
  final UserModel currentUser;
  final List<StoryModel> stories;
  final List<LivestreamModel> lives;

  const CurrentUserStoryLiveViewerScreen({
    super.key,
    required this.currentUser,
    required this.stories,
    required this.lives,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = ThemeHelper.getAccentColor(context);
    final bg = ThemeHelper.getBackgroundColor(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: Column(
            children: [
              Material(
                color: Colors.transparent,
                child: TabBar(
                  labelColor: accent,
                  unselectedLabelColor: ThemeHelper.getTextSecondary(context),
                  indicatorColor: accent,
                  tabs: const [
                    Tab(text: 'Stories'),
                    Tab(text: 'Live'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildStoriesTab(context, ref),
                    _buildLivesTab(context, ref),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStoriesTab(BuildContext context, WidgetRef ref) {
    if (stories.isEmpty) {
      return Center(
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
      );
    }

    return StoriesViewerScreen(
      initialUserIndex: 0,
      initialStoryIndex: 0,
      users: [currentUser],
      userStoriesMap: {currentUser.id: stories},
    );
  }

  Widget _buildLivesTab(BuildContext context, WidgetRef ref) {
    if (lives.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.live_tv_rounded,
                  size: 56, color: ThemeHelper.getTextSecondary(context)),
              const SizedBox(height: 14),
              Text(
                'No live streams yet',
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
                      builder: (_) => const LiveStreamStudioScreen(),
                    ),
                  );
                },
                child: const Text('Go Live'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: lives.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final l = lives[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LiveJoinOverlayScreen(stream: l),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: ThemeHelper.getSurfaceColor(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: ThemeHelper.getBorderColor(context),
                width: 1,
              ),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFFEF4444),
                        ThemeHelper.getAccentColor(context),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: ClipOval(
                    child: l.host?.profilePicture.isNotEmpty == true
                        ? Image.network(
                            l.host!.profilePicture,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: ThemeHelper.getSurfaceColor(context),
                              child: Icon(Icons.person,
                                  color: ThemeHelper.getTextSecondary(context)),
                            ),
                          )
                        : Container(
                            color: ThemeHelper.getSurfaceColor(context),
                            child: Icon(Icons.person,
                                color: ThemeHelper.getTextSecondary(context)),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.title.isNotEmpty ? l.title : 'Live',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ThemeHelper.getTextPrimary(context),
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '👁 ${l.viewerCount}',
                        style: TextStyle(
                          color: ThemeHelper.getTextSecondary(context),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.play_circle_fill_rounded),
              ],
            ),
          ),
        );
      },
    );
  }
}

