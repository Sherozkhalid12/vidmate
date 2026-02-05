import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'stories_viewer_screen.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/services/mock_data_service.dart';
import '../../core/models/story_model.dart';
import '../../core/models/user_model.dart';
import '../feed/create_content_screen.dart';

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
            // Stories layout: "Your story" at top center, then 2 columns below
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
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        children: [
                          // "Your story" at top center
                          _buildYourStoryCard(),
                          const SizedBox(height: 12),
                          // 2 columns of user stories
                          _buildStoriesGrid(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYourStoryCard() {
    // Use first mock user as "Your story"
    final currentUser = MockDataService.mockUsers.first;
    final currentUserStories = _userStoriesMap[currentUser.id] ?? [];
    final hasStories = currentUserStories.isNotEmpty;
    
    return GestureDetector(
      onTap: () {
        if (hasStories) {
          // Show bottom sheet with View Story or Add Story options
          _showYourStoryOptions();
        } else {
          // No story - navigate to create content screen with stories tab
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreateContentScreen(
                initialType: ContentType.story,
              ),
            ),
          );
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Smaller circular story widget
          Container(
            width: 120,
            height: 120,
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
            padding: const EdgeInsets.all(3),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ThemeHelper.getBackgroundColor(context),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircleAvatar(
                    backgroundImage: CachedNetworkImageProvider(currentUser.avatarUrl),
                    backgroundColor: ThemeHelper.getSurfaceColor(context),
                    onBackgroundImageError: (exception, stackTrace) {
                      // Error will show backgroundColor
                    },
                  ),
                  // Plus icon overlay
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: ThemeHelper.getAccentColor(context),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: ThemeHelper.getBackgroundColor(context),
                          width: 3,
                        ),
                      ),
                      child: Icon(
                        Icons.add,
                        color: ThemeHelper.getOnAccentColor(context),
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your story',
            style: TextStyle(
              color: ThemeHelper.getTextPrimary(context),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStoriesGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 0,
        mainAxisSpacing: 0,
        childAspectRatio: 0.95,
      ),
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final user = _users[index];
        final stories = _userStoriesMap[user.id] ?? [];
        if (stories.isEmpty) return const SizedBox.shrink();
        
        return _buildStoryCard(user, stories, index);
      },
    );
  }

  Widget _buildStoryCard(UserModel user, List<StoryModel> stories, int userIndex) {
    final firstStory = stories.first;
    
    return GestureDetector(
      onTap: () => _openStoryViewer(userIndex, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Smaller circular story widget
          Container(
            width: 120,
            height: 120,
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
            padding: const EdgeInsets.all(3),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ThemeHelper.getBackgroundColor(context),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Story media background using CircleAvatar
                  firstStory.isVideo
                      ? CircleAvatar(
                          backgroundColor: Colors.black,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.play_circle_filled,
                              size: 30,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : CircleAvatar(
                          backgroundImage: CachedNetworkImageProvider(firstStory.mediaUrl),
                          backgroundColor: ThemeHelper.getSurfaceColor(context),
                          onBackgroundImageError: (exception, stackTrace) {
                            // Error will show backgroundColor
                          },
                        ),
                  // Story count badge (if multiple stories)
                  if (stories.length > 1)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              ThemeHelper.getAccentColor(context),
                              ThemeHelper.getAccentColor(context).withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: ThemeHelper.getAccentColor(context).withOpacity(0.4),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          '${stories.length}',
                          style: TextStyle(
                            color: ThemeHelper.getOnAccentColor(context),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // User name below circle
          Text(
            user.displayName,
            style: TextStyle(
              color: ThemeHelper.getTextPrimary(context),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showYourStoryOptions() {
    final currentUser = MockDataService.mockUsers.first;
    final currentUserStories = _userStoriesMap[currentUser.id] ?? [];
    final userIndex = _users.indexWhere((u) => u.id == currentUser.id);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: ThemeHelper.getBackgroundColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                Icons.visibility,
                color: ThemeHelper.getAccentColor(context),
              ),
              title: Text(
                'View Story',
                style: TextStyle(
                  color: ThemeHelper.getTextPrimary(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                if (userIndex >= 0) {
                  _openStoryViewer(userIndex, 0);
                }
              },
            ),
            Divider(color: ThemeHelper.getBorderColor(context)),
            ListTile(
              leading: Icon(
                Icons.add_circle_outline,
                color: ThemeHelper.getAccentColor(context),
              ),
              title: Text(
                'Add Story',
                style: TextStyle(
                  color: ThemeHelper.getTextPrimary(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreateContentScreen(
                      initialType: ContentType.story,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
