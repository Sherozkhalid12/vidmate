import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'stories_viewer_screen.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/services/mock_data_service.dart';
import '../../core/models/story_model.dart';
import '../../core/models/user_model.dart';

/// Story Page - Grid layout like WhatsApp Status
class StoryPage extends StatefulWidget {
  final double bottomPadding;

  const StoryPage({super.key, required this.bottomPadding});

  @override
  State<StoryPage> createState() => _StoryPageState();
}

class _StoryPageState extends State<StoryPage> {
  final List<UserModel> _users = [];
  final Map<String, List<StoryModel>> _userStoriesMap = {};

  @override
  void initState() {
    super.initState();
    _loadStories();
  }

  void _loadStories() {
    final allStories = MockDataService.getMockStories();
    _userStoriesMap.clear();
    _users.clear();

    // Group stories by user
    for (var story in allStories) {
      if (!_userStoriesMap.containsKey(story.author.id)) {
        _userStoriesMap[story.author.id] = [];
        _users.add(story.author);
      }
      _userStoriesMap[story.author.id]!.add(story);
    }

    setState(() {});
  }

  void _openStoryViewer(int userIndex, int storyIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StoriesViewerScreen(
          initialUserIndex: userIndex,
          initialStoryIndex: storyIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        decoration: BoxDecoration(
          gradient: ThemeHelper.getBackgroundGradient(context),
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Text(
                    'Stories',
                    style: TextStyle(
                      color: ThemeHelper.getTextPrimary(context),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            // Grid of story cards
            Expanded(
              child: _users.isEmpty
                  ? Center(
                      child: Text(
                        'No stories available',
                        style: TextStyle(
                          color: ThemeHelper.getTextSecondary(context),
                        ),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.5, // Rectangular shape (taller)
                      ),
                      itemCount: _users.length,
                      itemBuilder: (context, index) {
                        final user = _users[index];
                        final stories = _userStoriesMap[user.id] ?? [];
                        if (stories.isEmpty) return const SizedBox.shrink();
                        
                        return _buildStoryCard(user, stories, index);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryCard(UserModel user, List<StoryModel> stories, int userIndex) {
    final firstStory = stories.first;
    
    return GestureDetector(
      onTap: () => _openStoryViewer(userIndex, 0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: ThemeHelper.getBorderColor(context),
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Story media background
              firstStory.isVideo
                  ? Container(
                      color: Colors.black,
                      child: Center(
                        child: Icon(
                          Icons.play_circle_filled,
                          size: 48,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: firstStory.mediaUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: ThemeHelper.getSurfaceColor(context),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: ThemeHelper.getAccentColor(context),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: ThemeHelper.getSurfaceColor(context),
                        child: Icon(
                          Icons.image_not_supported,
                          color: ThemeHelper.getTextSecondary(context),
                        ),
                      ),
                    ),
              // Gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
              ),
              // Profile picture and name overlay
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      // Profile picture with border
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: ThemeHelper.getAccentColor(context),
                            width: 2,
                          ),
                        ),
                        child: ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: user.avatarUrl,
                            width: 32,
                            height: 32,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              width: 32,
                              height: 32,
                              color: ThemeHelper.getSurfaceColor(context),
                            ),
                            errorWidget: (context, url, error) => Container(
                              width: 32,
                              height: 32,
                              color: ThemeHelper.getSurfaceColor(context),
                              child: Icon(
                                Icons.person,
                                size: 20,
                                color: ThemeHelper.getTextSecondary(context),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // User name
                      Expanded(
                        child: Text(
                          user.displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Story count badge (if multiple stories)
              if (stories.length > 1)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${stories.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
