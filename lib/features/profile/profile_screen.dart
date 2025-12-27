import 'package:flutter/material.dart';
import 'dart:ui';
import '../../core/utils/theme_helper.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../core/services/mock_data_service.dart';
import '../../core/models/user_model.dart';
import '../../core/models/post_model.dart';
import '../../core/widgets/glass_card.dart';
import 'followers_list_screen.dart';
import '../settings/settings_screen.dart';

/// Instagram-style profile screen with full-width header and tabbed content
class ProfileScreen extends StatefulWidget {
  final UserModel? user;

  const ProfileScreen({
    super.key,
    this.user,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late UserModel _user;
  final List<PostModel> _posts = [];
  final List<PostModel> _reels = [];
  final List<PostModel> _videos = [];
  final List<PostModel> _saved = [];
  bool _isFollowing = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _user = widget.user ?? MockDataService.mockUsers[0];
    _isFollowing = _user.isFollowing;
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Rebuild to update tab colors
    });
    _loadContent();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadContent() {
    final allPosts = MockDataService.getMockPosts();
    setState(() {
      // Filter posts by author
      _posts.addAll(allPosts.where((p) => p.author.id == _user.id && !p.isVideo));
      _reels.addAll(allPosts.where((p) => p.author.id == _user.id && p.isVideo && p.videoDuration != null && p.videoDuration!.inSeconds <= 60));
      _videos.addAll(allPosts.where((p) => p.author.id == _user.id && p.isVideo && p.videoDuration != null && p.videoDuration!.inSeconds > 60));
      // Saved posts (mix of all types)
      _saved.addAll(allPosts.take(12));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: ThemeHelper.getBackgroundGradient(context),
        ),
        child: CustomScrollView(
                slivers: [
                  // App Bar
                  SliverAppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    automaticallyImplyLeading: false, // Remove back button
                    title: Text(
                      _user.username,
                      style: TextStyle(
                        color: ThemeHelper.getHighContrastIconColor(context), // Theme-aware: white in dark, black in light
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.3),
                            offset: const Offset(0, 1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      IconButton(
                        icon: Icon(Icons.menu),
                        color: ThemeHelper.getHighContrastIconColor(context), // Theme-aware: white in dark, black in light
                        onPressed: _showMenuBottomSheet,
                      ),
                    ],
                  ),
            // Profile Header (Full-width with image background)
            SliverToBoxAdapter(
              child: _buildProfileHeader(),
            ),
            // Followers/Following Glass Cards
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildFollowersCard(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildFollowingCard(),
                    ),
                  ],
                ),
              ),
            ),
            // Tab Bar (Sticky) - No shade, with stats
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                Container(
                  color: Colors.transparent,
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: ThemeHelper.getAccentColor(context),
                    labelColor: ThemeHelper.getAccentColor(context),
                    unselectedLabelColor: ThemeHelper.getTextMuted(context),
                    tabs: [
                      _buildTabWithStat(
                        icon: Icons.grid_on,
                        count: _user.posts,
                        isSelected: _tabController.index == 0,
                        context: context,
                      ),
                      _buildTabWithStat(
                        icon: Icons.play_circle_outline,
                        count: _reels.length,
                        isSelected: _tabController.index == 1,
                        context: context,
                      ),
                      _buildTabWithStat(
                        icon: Icons.video_library,
                        count: _videos.length,
                        isSelected: _tabController.index == 2,
                        context: context,
                      ),
                      _buildTabWithStat(
                        icon: Icons.bookmark_border,
                        count: _saved.length,
                        isSelected: _tabController.index == 3,
                        context: context,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Tab Content
            SliverFillRemaining(
              hasScrollBody: true,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPostsGrid(),
                  _buildReelsGrid(),
                  _buildVideosGrid(),
                  _buildSavedGrid(),
                ],
              ),
            ),
          ],
                ) // closes Padding
        ), // closes Container (line 72) and body parameter
    ); // closes Scaffold and return statement
  }

  Widget _buildProfileHeader() {
    return Container(
      height: 480,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: ThemeHelper.getBackgroundGradient(context),
        image: DecorationImage(
          image: NetworkImage(
            _user.avatarUrl.isNotEmpty
                ? _user.avatarUrl
                    .replaceAll('/150?', '/800?')
                    .replaceAll('/150', '/800')
                    .replaceAll('?img=', '?img=')
                    .replaceAll('w=150', 'w=800')
                    .replaceAll('h=150', 'h=800')
                : 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=1200&h=1200&fit=crop&q=90&auto=format',
          ),
          fit: BoxFit.cover,
          onError: (exception, stackTrace) {
            // Fallback handled by gradient background
          },
        ),
      ),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.transparent,
              Colors.black.withOpacity(0.3),
              Colors.black.withOpacity(0.7),
              Colors.black.withOpacity(0.9),
            ],
            stops: const [0.0, 0.3, 0.6, 0.85, 1.0],
          ),
        ),
        alignment: Alignment.bottomLeft,
        child:  Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Display name (large, bold) with Follow button to the right
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _user.displayName.isNotEmpty ? _user.displayName : _user.username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              offset: Offset(0, 1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '@${_user.username}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(.5),
                          fontSize: 16,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              offset: Offset(0, 1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _isFollowing
                    ? OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _isFollowing = !_isFollowing;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20), // More rounded
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    backgroundColor: Colors.white.withOpacity(0.2),
                  ),
                  child: const Text(
                    'Following',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                )
                    : ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isFollowing = !_isFollowing;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20), // More rounded
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Follow',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            // Bio below name
            if (_user.bio != null && _user.bio!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _user.bio!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  shadows: [
                    Shadow(
                      color: Colors.black54,
                      offset: Offset(0, 1),
                      blurRadius: 4,
                    ),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 30,),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(int value, String label) {
    return GestureDetector(
      onTap: () {
        if (label == 'Followers') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FollowersListScreen(
                userId: _user.id,
                isFollowers: true,
              ),
            ),
          );
        } else if (label == 'Following') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FollowersListScreen(
                userId: _user.id,
                isFollowers: false,
              ),
            ),
          );
        }
      },
      child: Column(
        children: [
          Text(
            _formatCount(value),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  color: Colors.black54,
                  offset: Offset(0, 1),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              shadows: [
                Shadow(
                  color: Colors.black54,
                  offset: Offset(0, 1),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowersCard() {
    return GlassCard(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FollowersListScreen(
              userId: _user.id,
              isFollowers: true,
            ),
          ),
        );
      },
      padding: const EdgeInsets.all(12),
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatars above text (matching screenshot)
          Row(
            children: [
              for (int index = 0; index < (_user.followers > 0 ? 3 : 0); index++)
                Transform.translate(
                  offset: Offset(index * -8.0, 0),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: ThemeHelper.getBackgroundColor(context),
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: Image.network(
                        'https://i.pravatar.cc/150?img=${index + 1}',
                        width: 24,
                        height: 24,
                        fit: BoxFit.cover,
                        cacheWidth: 48, // Cache HD version but display small
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 24,
                            height: 24,
                            color: ThemeHelper.getSurfaceColor(context),
                            child: Icon(
                              Icons.person,
                              size: 14,
                              color: ThemeHelper.getTextSecondary(context),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                _formatCount(_user.followers),
                style: TextStyle(
                  color: ThemeHelper.getTextPrimary(context), // Theme-aware text color
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                'followers',
                style: TextStyle(
                  color: ThemeHelper.getTextSecondary(context), // Theme-aware text color
                  fontSize: 12,
                ),
              ),
            ],
          ),

        ],
      ),
    );
  }

  Widget _buildFollowingCard() {
    return GlassCard(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FollowersListScreen(
              userId: _user.id,
              isFollowers: false,
            ),
          ),
        );
      },
      padding: const EdgeInsets.all(12),
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatars above text (matching screenshot)
          Row(
            children: [
              for (int index = 0; index < (_user.following > 0 ? 3 : 0); index++)
                Transform.translate(
                  offset: Offset(index * -8.0, 0),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: ThemeHelper.getBackgroundColor(context),
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: Image.network(
                        'https://i.pravatar.cc/150?img=${index + 5}',
                        width: 24,
                        height: 24,
                        fit: BoxFit.cover,
                        cacheWidth: 48, // Cache HD version but display small
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 24,
                            height: 24,
                            color: ThemeHelper.getSurfaceColor(context),
                            child: Icon(
                              Icons.person,
                              size: 14,
                              color: ThemeHelper.getTextSecondary(context),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                _formatCount(_user.following),
                style: TextStyle(
                  color: ThemeHelper.getTextPrimary(context), // Theme-aware text color
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                'following',
                style: TextStyle(
                  color: ThemeHelper.getTextSecondary(context), // Theme-aware text color
                  fontSize: 12,
                ),
              ),
            ],
          ),

        ],
      ),
    );
  }

  Widget _buildPostsGrid() {
    if (_posts.isEmpty) {
      return _buildEmptyState(
        icon: Icons.grid_on,
        title: 'No Posts Yet',
        message: 'When you share photos and videos, they\'ll appear here.',
      );
    }

    return AnimationLimiter(
      child: GridView.builder(
        padding: const EdgeInsets.all(2),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
          childAspectRatio: 1.0,
        ),
        itemCount: _posts.length,
        itemBuilder: (context, index) {
          return AnimationConfiguration.staggeredGrid(
            position: index,
            duration: const Duration(milliseconds: 375),
            columnCount: 2,
            child: ScaleAnimation(
              child: FadeInAnimation(
                child: _buildPostGridItem(_posts[index]),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildReelsGrid() {
    if (_reels.isEmpty) {
      return _buildEmptyState(
        icon: Icons.play_circle_outline,
        title: 'No Reels Yet',
        message: 'Reels you create will appear here.',
      );
    }

    return AnimationLimiter(
      child: GridView.builder(
        padding: const EdgeInsets.all(2),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
          childAspectRatio: 0.75, // Portrait aspect ratio for reels
        ),
        itemCount: _reels.length,
        itemBuilder: (context, index) {
          return AnimationConfiguration.staggeredGrid(
            position: index,
            duration: const Duration(milliseconds: 375),
            columnCount: 2,
            child: ScaleAnimation(
              child: FadeInAnimation(
                child: _buildReelGridItem(_reels[index]),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVideosGrid() {
    if (_videos.isEmpty) {
      return _buildEmptyState(
        icon: Icons.video_library,
        title: 'No Videos Yet',
        message: 'Long-form videos you upload will appear here.',
      );
    }

    return AnimationLimiter(
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _videos.length,
        itemBuilder: (context, index) {
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 375),
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: _buildVideoListItem(_videos[index]),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSavedGrid() {
    if (_saved.isEmpty) {
      return _buildEmptyState(
        icon: Icons.bookmark_border,
        title: 'Saved',
        message: 'Save photos and videos that you want to see again.',
      );
    }

    return AnimationLimiter(
      child: GridView.builder(
        padding: const EdgeInsets.all(2),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
          childAspectRatio: 1.0,
        ),
        itemCount: _saved.length,
        itemBuilder: (context, index) {
          return AnimationConfiguration.staggeredGrid(
            position: index,
            duration: const Duration(milliseconds: 375),
            columnCount: 3,
            child: ScaleAnimation(
              child: FadeInAnimation(
                child: _buildSavedGridItem(_saved[index]),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPostGridItem(PostModel post) {
    return GestureDetector(
      onTap: () {
        // Navigate to post detail
      },
      child: Container(
        decoration: BoxDecoration(
          color: ThemeHelper.getSurfaceColor(context),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              (post.imageUrl ?? post.thumbnailUrl ?? '').replaceAll('/600?', '/1200?').replaceAll('/800?', '/1200?'),
              fit: BoxFit.cover,
              cacheWidth: 600, // Cache HD version
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: ThemeHelper.getSurfaceColor(context),
                  child: Icon(
                    Icons.image_not_supported,
                    color: ThemeHelper.getTextMuted(context),
                    size: 32,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReelGridItem(PostModel reel) {
    return GestureDetector(
      onTap: () {
        // Navigate to reel player
      },
      child: Container(
        decoration: BoxDecoration(
          color: ThemeHelper.getSurfaceColor(context),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              (reel.thumbnailUrl ?? '').replaceAll('/600?', '/1200?').replaceAll('/800?', '/1200?'),
              fit: BoxFit.cover,
              cacheWidth: 600, // Cache HD version
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: ThemeHelper.getSurfaceColor(context),
                );
              },
            ),
            // Play icon overlay
            Center(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoListItem(PostModel video) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: ThemeHelper.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                (video.thumbnailUrl ?? '').replaceAll('/600?', '/1200?').replaceAll('/800?', '/1200?'),
                fit: BoxFit.cover,
                cacheWidth: 1200, // Cache HD version for full-width videos
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: ThemeHelper.getSurfaceColor(context),
                    child: Icon(
                      Icons.video_library,
                      color: ThemeHelper.getTextMuted(context),
                      size: 48,
                    ),
                  );
                },
              ),
            ),
            // Play icon overlay
            Positioned.fill(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
            ),
            // Duration badge
            if (video.videoDuration != null)
              Positioned(
                bottom: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _formatDuration(video.videoDuration!),
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
    );
  }

  Widget _buildSavedGridItem(PostModel saved) {
    return GestureDetector(
      onTap: () {
        // Navigate to saved item
      },
      child: Container(
        decoration: BoxDecoration(
          color: ThemeHelper.getSurfaceColor(context),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              (saved.imageUrl ?? saved.thumbnailUrl ?? '').replaceAll('/600?', '/1200?').replaceAll('/800?', '/1200?'),
              fit: BoxFit.cover,
              cacheWidth: 400, // Cache HD version
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: ThemeHelper.getSurfaceColor(context),
                  child: Icon(
                    Icons.image_not_supported,
                    color: ThemeHelper.getTextMuted(context),
                    size: 24,
                  ),
                );
              },
            ),
            // Type icon overlay
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  saved.isVideo ? Icons.play_arrow : Icons.image,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: ThemeHelper.getBorderColor(context),
                width: 2,
              ),
            ),
            child: Icon(
              icon,
              size: 40,
              color: ThemeHelper.getTextMuted(context),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: ThemeHelper.getTextPrimary(context), // Theme-aware text color
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              message,
              style: TextStyle(
                color: ThemeHelper.getTextMuted(context), // Theme-aware text color
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  void _showMenuBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allow bottom sheet to appear above bottom navbar
      backgroundColor: ThemeHelper.getBackgroundColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 
                  MediaQuery.of(context).padding.bottom + 78, // Add bottom nav height + safe area
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  Icons.settings,
                  color: ThemeHelper.getAccentColor(context),
                ),
                title: Text(
                  'Settings',
                  style: TextStyle(color: ThemeHelper.getTextPrimary(context)),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                },
              ),
            ListTile(
              leading: Icon(
                Icons.archive,
                color: ThemeHelper.getAccentColor(context),
              ),
              title: Text(
                'Archive',
                style: TextStyle(color: ThemeHelper.getTextPrimary(context)),
              ),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Archive feature coming soon'),
                    backgroundColor: ThemeHelper.getAccentColor(context),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(
                Icons.qr_code,
                color: ThemeHelper.getAccentColor(context),
              ),
              title: Text(
                'QR Code',
                style: TextStyle(color: ThemeHelper.getTextPrimary(context)),
              ),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('QR Code feature coming soon'),
                    backgroundColor: ThemeHelper.getAccentColor(context),
                  ),
                );
              },
            ),
          ],
            ), // closes Column
          ), // closes Container
        ), // closes Padding
    ); // closes showModalBottomSheet
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    if (minutes > 0) {
      return '${minutes}:${seconds.toString().padLeft(2, '0')}';
    }
    return '0:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildTabWithStat({
    required IconData icon,
    required int count,
    required bool isSelected,
    required BuildContext context,
  }) {
    return Tab(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon),
          const SizedBox(height: 4),
          Text(
            _formatCount(count),
            style: TextStyle(
              fontSize: 10,
              color: isSelected
                  ? ThemeHelper.getAccentColor(context)
                  : ThemeHelper.getTextMuted(context),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom delegate for sticky tab bar
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _SliverAppBarDelegate(this.child);

  @override
  double get minExtent => 48;

  @override
  double get maxExtent => 48;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
