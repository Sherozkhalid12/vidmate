import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/features/chat/chat_list_screen.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/widgets/bottom_nav_bar.dart';
import '../../core/widgets/story_avatar.dart';
import '../../core/widgets/video_tile.dart';
import '../../core/widgets/instagram_post_card.dart';
import '../../core/services/mock_data_service.dart';
import '../../core/models/post_model.dart';
import '../reels/reels_screen.dart';
import '../video/video_player_screen.dart';
import '../stories/stories_viewer_screen.dart';
import '../search/search_screen.dart';
import '../profile/profile_screen.dart';
import '../notifications/notifications_screen.dart';
import '../settings/settings_screen.dart';
import '../feed/create_post_screen.dart';
import '../upload/story_upload_screen.dart';

/// Home feed screen with mixed content
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final ScrollController _scrollController = ScrollController();
  final List<PostModel> _posts = [];
  bool _isLoading = false;
  String _sortBy = 'latest'; // 'latest' or 'popular'

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _loadPosts() {
    setState(() {
      _isLoading = true;
    });
    
    // Simulate network delay
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        var newPosts = List<PostModel>.from(MockDataService.getMockPosts());
        
        // Sort posts based on selected option
        if (_sortBy == 'popular') {
          newPosts.sort((a, b) => b.likes.compareTo(a.likes));
        } else {
          // Latest - sort by creation time
          newPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        }
        
        setState(() {
          _posts.addAll(newPosts);
          _isLoading = false;
        });
      }
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      if (!_isLoading) {
        _loadPosts();
      }
    }
  }

  void _navigateToScreen(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_currentIndex != 0) {
      return _buildOtherScreens();
    }

    return Scaffold(
      // Transparent background - gradient applied in body
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            Text(
              'SocialVideo',
              style: TextStyle(
                color: context.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              size: 20,
              color: context.textSecondary,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: context.textPrimary),
            tooltip: 'Search',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SearchScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.favorite_border, color: context.textPrimary),
            tooltip: 'Notifications',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsScreen(),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.sort, color: context.textPrimary),
            tooltip: 'Sort Feed',
            onSelected: (value) {
              setState(() {
                _sortBy = value;
                _posts.clear();
              });
              _loadPosts();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'latest',
                child: Row(
                  children: [
                    Icon(
                      _sortBy == 'latest' ? Icons.check : null,
                      color: context.buttonColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text('Latest'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'popular',
                child: Row(
                  children: [
                    Icon(
                      _sortBy == 'popular' ? Icons.check : null,
                      color: context.buttonColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text('Popular'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: Icon(CupertinoIcons.chat_bubble_2, color: context.textPrimary),
            tooltip: 'Chat',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ChatListScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _posts.clear();
            });
            _loadPosts();
          },
          color: context.buttonColor,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Stories bar
              SliverToBoxAdapter(
                child: _buildStoriesBar(),
              ),
              // Posts feed
              if (_isLoading && _posts.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(
                      color: context.buttonColor,
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index < _posts.length) {
                        return AnimationConfiguration.staggeredList(
                          position: index,
                          duration: const Duration(milliseconds: 375),
                          child: SlideAnimation(
                            verticalOffset: 50.0,
                            child: FadeInAnimation(
                              child: _buildPostCard(_posts[index]),
                            ),
                          ),
                        );
                      } else if (_isLoading) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: context.buttonColor,
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                    childCount: _posts.length + (_isLoading ? 1 : 0),
                  ),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: _navigateToScreen,
      ),
    );
  }

  Widget _buildStoriesBar() {
    final stories = MockDataService.getMockStories();
    return Container(
      height: 110,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: stories.length + 1, // +1 for "Your Story"
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(right: 16),
              child: StoryAvatar(
                imageUrl: 'https://i.pravatar.cc/150?img=10',
                username: 'Your Story',
                isOwnStory: true,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const StoryUploadScreen(),
                    ),
                  );
                },
              ),
            );
          }
          final story = stories[index - 1];
          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: StoryAvatar(
              imageUrl: story.author.avatarUrl,
              username: story.author.username,
              isViewed: story.isViewed,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StoriesViewerScreen(
                      initialIndex: index - 1,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

Widget _buildPostCard(PostModel post) {
  // Use Instagram-style post card for image posts
  if (!post.isVideo || post.imageUrl != null) {
    return InstagramPostCard(post: post);
  }
  
  // Use video tile for video posts with proper padding
  return Container(
    margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),   // Matches typical premium card radius
      color: Colors.black.withOpacity(0.2),      // Subtle dark fallback if thumbnail fails
    ),
    child: VideoTile(
    thumbnailUrl: post.thumbnailUrl ?? post.imageUrl ?? '',
    title: post.caption,
    channelName: post.author.displayName,
    channelAvatar: post.author.avatarUrl,
    views: post.likes * 10, // Mock views
    likes: post.likes,
    comments: post.comments,
    duration: post.videoDuration,
    onTap: () {
      if (post.isVideo) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoPlayerScreen(
              videoUrl: post.videoUrl!,
              title: post.caption,
              author: post.author,
              post: post, // Pass the post for like/comment/share
            ),
          ),
        );
      }
    },
  ),
  );
}

  Widget _buildOtherScreens() {
    switch (_currentIndex) {
      case 1: // Explore/Search
        return Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          body: Container(
            decoration: BoxDecoration(
              gradient: context.backgroundGradient,
            ),
            child: SearchScreen(
              onBackToHome: () {
                setState(() {
                  _currentIndex = 0;
                });
              },
            ),
          ),
          bottomNavigationBar: BottomNavBar(
            currentIndex: _currentIndex,
            onTap: _navigateToScreen,
          ),
        );
      case 2: // Reels
        return Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          body: Container(
            decoration: BoxDecoration(
              gradient: context.backgroundGradient,
            ),
            child: const ReelsScreen(),
          ),
          bottomNavigationBar: BottomNavBar(
            currentIndex: _currentIndex,
            onTap: _navigateToScreen,
          ),
        );
      case 3: // Create
        return CreatePostScreen(
          bottomNavigationBar: BottomNavBar(
            currentIndex: _currentIndex,
            onTap: _navigateToScreen,
          ),
        );
      case 4: // Profile
        return Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          body: Container(
            decoration: BoxDecoration(
              gradient: context.backgroundGradient,
            ),
            child: const ProfileScreen(),
          ),
          bottomNavigationBar: BottomNavBar(
            currentIndex: _currentIndex,
            onTap: _navigateToScreen,
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

