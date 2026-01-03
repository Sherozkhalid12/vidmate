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
            // Grid of story cards - 2 per row for better presentation
            Expanded(
              child: _users.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.auto_stories_outlined,
                            size: 64,
                            color: ThemeHelper.getTextSecondary(context),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No stories available',
                            style: TextStyle(
                              color: ThemeHelper.getTextPrimary(context),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Stories will appear here',
                            style: TextStyle(
                              color: ThemeHelper.getTextSecondary(context),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 24,
                        mainAxisSpacing: 32,
                        childAspectRatio: 0.75, // Taller to accommodate name below
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Circular story widget with shadow and gradient border
          Expanded(
            child: AspectRatio(
              aspectRatio: 1.0,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      ThemeHelper.getAccentColor(context),
                      ThemeHelper.getAccentColor(context).withOpacity(0.6),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: ThemeHelper.getAccentColor(context).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(4), // Border thickness
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ThemeHelper.getBackgroundColor(context),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: ClipOval(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Story media background
                        firstStory.isVideo
                            ? Container(
                                color: Colors.black,
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.play_circle_filled,
                                      size: 40,
                                      color: Colors.white,
                                    ),
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
                                      strokeWidth: 3,
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: ThemeHelper.getSurfaceColor(context),
                                  child: Icon(
                                    Icons.image_not_supported,
                                    color: ThemeHelper.getTextSecondary(context),
                                    size: 32,
                                  ),
                                ),
                              ),
                        // Story count badge (if multiple stories) - enhanced design
                        if (stories.length > 1)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    ThemeHelper.getAccentColor(context),
                                    ThemeHelper.getAccentColor(context).withOpacity(0.8),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                '${stories.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // User name below circle - enhanced typography
          Text(
            user.displayName,
            style: TextStyle(
              color: ThemeHelper.getTextPrimary(context),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
