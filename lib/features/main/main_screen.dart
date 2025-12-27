import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/widgets/bottom_nav_bar.dart';
import '../../core/widgets/story_avatar.dart';
import '../../core/widgets/video_tile.dart';
import '../../core/widgets/instagram_post_card.dart';
import '../../core/services/mock_data_service.dart';
import '../../core/models/post_model.dart';
import '../search/search_screen.dart';
import '../reels/reels_screen.dart';
import '../video/video_player_screen.dart';
import '../stories/stories_viewer_screen.dart';
import '../notifications/notifications_screen.dart';
import '../settings/settings_screen.dart';
import '../feed/create_post_screen.dart';
import '../upload/story_upload_screen.dart';
import '../profile/profile_screen.dart';
import '../chat/chat_screen.dart';
import '../../core/theme/app_colors.dart';
/// Root screen with persistent glassmorphic bottom navigation
/// Uses Stack architecture: PageView for content, BottomNavBar as overlay
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNavItemTapped(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onPageChanged(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate bottom nav bar height for content padding
    final bottomNavHeight = 78.0;
    final safeAreaBottom = MediaQuery.of(context).padding.bottom;
    final totalBottomPadding = bottomNavHeight + safeAreaBottom;

    // Get theme-aware gradient background
    final gradient = ThemeHelper.getBackgroundGradient(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        // Apply gradient background at root level - fills entire screen
        decoration: BoxDecoration(
          gradient: gradient,
        ),
        child: Stack(
          children: [
            // Main content layer - scrollable pages
            Padding(
              padding: const EdgeInsets.only(bottom: 72.0),
              child: PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(), // Disable swipe, only tap nav
                onPageChanged: _onPageChanged,
                itemCount: 5,
                itemBuilder: (context, index) {
                  return _buildPage(index, totalBottomPadding);
                },
              ),
            ),

            // Persistent bottom navigation bar overlay
            // Positioned at bottom so glass blur reveals scrolling gradient/content
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: BottomNavBar(
                currentIndex: _currentIndex,
                onTap: _onNavItemTapped,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(int index, double bottomPadding) {
    switch (index) {
      case 0: // Home Feed
        return HomeFeedPage(bottomPadding: bottomPadding);
      case 1: // Explore / Search
        return ExplorePage(bottomPadding: bottomPadding);
      case 2: // Create
        return CreatePage(bottomPadding: bottomPadding);
      case 3: // Reels
        return ReelsPage(bottomPadding: bottomPadding);
      case 4: // Profile
        return ProfilePage(bottomPadding: bottomPadding);
      default:
        return const SizedBox.shrink();
    }
  }
}

/// Home Feed Page - extracted from HomeScreen
class HomeFeedPage extends StatefulWidget {
  final double bottomPadding;

  const HomeFeedPage({super.key, required this.bottomPadding});

  @override
  State<HomeFeedPage> createState() => _HomeFeedPageState();
}

class _HomeFeedPageState extends State<HomeFeedPage> {
  final ScrollController _scrollController = ScrollController();
  final List<PostModel> _posts = [];
  bool _isLoading = false;
  String _sortBy = 'latest';

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

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        var newPosts = List<PostModel>.from(MockDataService.getMockPosts());

        if (_sortBy == 'popular') {
          newPosts.sort((a, b) => b.likes.compareTo(a.likes));
        } else {
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

  @override
  Widget build(BuildContext context) {
    // Gradient is applied at MainScreen root, so no need to duplicate here
    // Just use transparent container to let gradient show through
    return SafeArea(
      bottom: false, // Bottom nav handles safe area
      child: Column(
        children: [
          // App Bar
          _buildAppBar(),
          // Scrollable content
          Expanded(
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
                    SliverPadding(
                      padding: EdgeInsets.only(bottom: widget.bottomPadding),
                      sliver: SliverList(
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
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(
            'SocialVideo',
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.keyboard_arrow_down,
            size: 20,
            color: context.textSecondary,
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.search),
            color: context.textPrimary,
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
            icon: Icon(Icons.favorite_border),
            color: context.textPrimary,
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
            icon: Icon(Icons.chat_bubble_outline),
            color: context.textPrimary,
            tooltip: 'Messages',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ChatScreen(),
                ),
              );
            },
          ),
        ],
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
        itemCount: stories.length + 1,
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
    if (!post.isVideo || post.imageUrl != null) {
      return InstagramPostCard(post: post);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: VideoTile(
        thumbnailUrl: post.thumbnailUrl ?? post.imageUrl ?? '',
        title: post.caption,
        channelName: post.author.displayName,
        channelAvatar: post.author.avatarUrl,
        views: post.likes * 10,
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
                  post: post,
                ),
              ),
            );
          }
        },
      ),
    );
  }
}

/// Explore Page
class ExplorePage extends StatelessWidget {
  final double bottomPadding;

  const ExplorePage({super.key, required this.bottomPadding});

  @override
  Widget build(BuildContext context) {
    // Gradient is applied at MainScreen root
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          // App Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Text(
                  'Explore',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: SearchScreen(
              onBackToHome: null, // No back button needed in main nav
              bottomPadding: bottomPadding, // Pass bottom padding for nav bar
            ),
          ),
        ],
      ),
    );
  }
}

/// Reels Page
class ReelsPage extends StatelessWidget {
  final double bottomPadding;

  const ReelsPage({super.key, required this.bottomPadding});

  @override
  Widget build(BuildContext context) {
    // Gradient is applied at MainScreen root
    return SafeArea(
      bottom: false,
      child: const ReelsScreen(),
    );
  }
}

/// Create Page
class CreatePage extends StatelessWidget {
  final double bottomPadding;

  const CreatePage({super.key, required this.bottomPadding});

  @override
  Widget build(BuildContext context) {
    // Gradient is applied at MainScreen root
    return SafeArea(
      bottom: false,
      child: CreatePostScreen(
        bottomNavigationBar: null, // No nav bar needed, handled by main screen
      ),
    );
  }
}

/// Profile Page
class ProfilePage extends StatelessWidget {
  final double bottomPadding;

  const ProfilePage({super.key, required this.bottomPadding});

  @override
  Widget build(BuildContext context) {
    // Gradient is applied at MainScreen root
    return SafeArea(
      bottom: false,
      child: const ProfileScreen(),
    );
  }
}

