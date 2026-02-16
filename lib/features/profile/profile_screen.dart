import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/features/feed/create_content_screen.dart';
import 'package:flutter_application_1/features/feed/create_post_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/theme_extensions.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/models/user_model.dart';
import '../../core/models/post_model.dart';
import '../../core/providers/auth_provider_riverpod.dart';
import '../../core/providers/posts_provider_riverpod.dart';
import '../../core/utils/theme_helper.dart';
import '../settings/settings_screen.dart';
import '../chat/chat_list_screen.dart';
import 'followers_list_screen.dart';
import 'edit/edit_profile_screen.dart';
import '../../core/services/mock_data_service.dart';

/// Instagram-style profile screen. If [user] is null, shows current user's profile (from API).
class ProfileScreen extends ConsumerStatefulWidget {
  final UserModel? user;

  const ProfileScreen({
    super.key,
    this.user,
  });

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  bool _isFollowing = false;
  String? _displayedUserId;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 0);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final user = widget.user ?? currentUser;
    if (user == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: BoxDecoration(gradient: context.backgroundGradient),
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (user.id != _displayedUserId) {
      _displayedUserId = user.id;
      _isFollowing = user.isFollowing;
    }
    final userPostsState = ref.watch(userPostsProvider(user.id));
    final posts = userPostsState.posts;
    final isCurrentUser = currentUser != null && currentUser.id == user.id;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: context.backgroundGradient,
        ),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leadingWidth: 100,
              leading: Padding(
                padding: EdgeInsets.only(left: 16.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: (){
                        Navigator.pop(context);
                      },
                      child: Icon(
                        Icons.arrow_back_ios_new,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 12,),
                    if (isCurrentUser)
                      InkWell(
                        onTap: (){
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>  CreateContentScreen(),
                            ),
                          );
                        },
                        child: Icon(
                          CupertinoIcons.plus,
                          size: 25,
                        ),
                      ),
                  ],
                ),
              ),
              title: Text(
                user.username,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.menu),
                  onPressed: () {
                    // Navigate directly to settings
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SettingsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),

            // Profile header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile picture - centered (same style as edit profile screen)
                    Center(
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: ThemeHelper.getBorderColor(context),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: ThemeHelper.getAccentColor(context).withOpacity(0.2),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(3),
                        child: ClipOval(
                          child: Image.network(
                            user.avatarUrl,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: context.surfaceColor,
                                child: Icon(
                                  Icons.person,
                                  color: context.textSecondary,
                                  size: 50,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Username with verified badge - centered
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            user.username,
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.blue,
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Stats - centered (posts count from API when loaded)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatColumn(user.followers, "Follower's"),
                        _buildStatColumn(user.following, 'Following'),
                        _buildStatColumn(
                          userPostsState.isLoading && posts.isEmpty
                              ? user.posts
                              : posts.length,
                          'Posts',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Action buttons - Edit profile for self, Follow/Message for others
                    Row(
                      children: isCurrentUser
                          ? [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => EditProfileScreen(
                                          user: user,
                                        ),
                                      ),
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: ThemeHelper.getTextPrimary(context),
                                      width: 1.5,
                                    ),
                                    backgroundColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                  child: Text(
                                    'Edit profile',
                                    style: TextStyle(
                                      color: ThemeHelper.getTextPrimary(context),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ]
                          : [
                              Expanded(
                                child: _isFollowing
                                    ? OutlinedButton(
                                        onPressed: () {
                                          setState(() {
                                            _isFollowing = !_isFollowing;
                                          });
                                        },
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(
                                            color: ThemeHelper.getTextPrimary(context),
                                            width: 1.5,
                                          ),
                                          backgroundColor: Colors.transparent,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                        ),
                                        child: Text(
                                          'Following',
                                          style: TextStyle(
                                            color: ThemeHelper.getTextPrimary(context),
                                            fontWeight: FontWeight.w600,
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
                                          backgroundColor: ThemeHelper.getAccentColor(context),
                                          foregroundColor: ThemeHelper.getOnAccentColor(context),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          elevation: 0,
                                        ),
                                        child: Text(
                                          'Follow',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ChatListScreen(),
                                      ),
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: ThemeHelper.getTextPrimary(context),
                                      width: 1.5,
                                    ),
                                    backgroundColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                  child: Text(
                                    'Message',
                                    style: TextStyle(
                                      color: ThemeHelper.getTextPrimary(context),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                    ),
                    const SizedBox(height: 12),
                    // Bio and link
                    if (user.bio != null) ...[
                      Text(
                        user.bio!,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                    // Link/Website if available
                    if (user.bio != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('🔗 '),
                          Text(
                            'Linktr.ee/${user.username}',
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 14,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Tab bar - theme-responsive: white (dark mode), black (light mode)
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorColor: ThemeHelper.getAccentColor(context),
                  indicatorWeight: 3,
                  dividerColor: Colors.transparent,
                  dividerHeight: 0,
                  labelColor: ThemeHelper.getHighContrastIconColor(context),
                  unselectedLabelColor: ThemeHelper.getTextMuted(context),
                  labelStyle: TextStyle(
                    color: ThemeHelper.getHighContrastIconColor(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  unselectedLabelStyle: TextStyle(
                    color: ThemeHelper.getTextMuted(context),
                    fontWeight: FontWeight.w400,
                    fontSize: 14,
                  ),
                  tabs: const [
                    Tab(text: 'Post.'),
                    Tab(text: 'Reels.'),
                    Tab(text: 'Long Videos'),
                  ],
                ),
              ),
            ),
            // Content grid
            SliverFillRemaining(
              hasScrollBody: true,
              child: userPostsState.isLoading && posts.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildPostsGrid(posts),
                        _buildReelsGrid(posts),
                        _buildLongVideosGrid(posts),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(int value, String label) {
    return GestureDetector(
      onTap: () {
        _showFollowersFollowingSheet(label.toLowerCase().contains('follower'));
      },
      child: Column(
        children: [
          Text(
            _formatCount(value),
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _showFollowersFollowingSheet(bool isFollowers) {
    final users = MockDataService.mockUsers.take(10).toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ThemeHelper.getBackgroundColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: ThemeHelper.getBorderColor(context),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isFollowers ? 'Followers' : 'Following',
                      style: TextStyle(
                        color: ThemeHelper.getTextPrimary(context),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: ThemeHelper.getTextPrimary(context),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: NetworkImage(user.avatarUrl),
                      backgroundColor: ThemeHelper.getSurfaceColor(context),
                    ),
                    title: Text(
                      user.username,
                      style: TextStyle(
                        color: ThemeHelper.getTextPrimary(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      user.displayName,
                      style: TextStyle(
                        color: ThemeHelper.getTextSecondary(context),
                      ),
                    ),
                    trailing: user.isFollowing
                        ? OutlinedButton(
                            onPressed: () {},
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: ThemeHelper.getTextPrimary(context),
                                width: 1.5,
                              ),
                              backgroundColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              'Following',
                              style: TextStyle(
                                color: ThemeHelper.getTextPrimary(context),
                                fontSize: 12,
                              ),
                            ),
                          )
                        : ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ThemeHelper.getAccentColor(context),
                              foregroundColor: ThemeHelper.getOnAccentColor(context),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              'Follow',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostsGrid(List<PostModel> posts) {
    if (posts.isEmpty) {
      return const SizedBox.shrink();
    }
    return AnimationLimiter(
      child: GridView.builder(
        padding: const EdgeInsets.all(2),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
        itemCount: posts.length,
        itemBuilder: (context, index) {
          return AnimationConfiguration.staggeredGrid(
            position: index,
            duration: const Duration(milliseconds: 375),
            columnCount: 3,
            child: ScaleAnimation(
              child: FadeInAnimation(
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          posts[index].thumbnailUrl ??
                              posts[index].imageUrl ??
                              '',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: context.surfaceColor,
                              child: Icon(
                                Icons.image_not_supported,
                                color: context.textMuted,
                              ),
                            );
                          },
                        ),
                        if (posts[index].isVideo)
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
                                Icons.play_arrow,
                                color: context.textPrimary,
                                size: 16,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildReelsGrid(List<PostModel> posts) {
    final reels = posts.where((p) => p.isVideo).toList();
    if (reels.isEmpty) {
      return const SizedBox.shrink();
    }
    return AnimationLimiter(
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(2),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
        itemCount: reels.length,
        itemBuilder: (context, index) {
          return AnimationConfiguration.staggeredGrid(
            position: index,
            duration: const Duration(milliseconds: 375),
            columnCount: 3,
            child: ScaleAnimation(
              child: FadeInAnimation(
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          reels[index].thumbnailUrl ?? '',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: context.surfaceColor,
                            );
                          },
                        ),
                        Center(
                          child: Icon(
                            Icons.play_circle_outline,
                            color: context.textPrimary,
                            size: 32,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLongVideosGrid(List<PostModel> posts) {
    final longVideos = posts.where((p) => p.isVideo && (p.videoDuration?.inMinutes ?? 0) >= 1).toList();
    if (longVideos.isEmpty) {
      return const SizedBox.shrink();
    }
    return AnimationLimiter(
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(2),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
        itemCount: longVideos.length,
        itemBuilder: (context, index) {
          return AnimationConfiguration.staggeredGrid(
            position: index,
            duration: const Duration(milliseconds: 375),
            columnCount: 3,
            child: ScaleAnimation(
              child: FadeInAnimation(
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          longVideos[index].thumbnailUrl ?? '',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: context.surfaceColor,
                            );
                          },
                        ),
                        Center(
                          child: Icon(
                            Icons.play_circle_filled,
                            color: context.textPrimary,
                            size: 32,
                          ),
                        ),
                        if (longVideos[index].videoDuration != null)
                          Positioned(
                            bottom: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _formatDuration(longVideos[index].videoDuration!),
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
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
          );
        },
      ),
    );
  }

  Widget _buildSavedGrid() {
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
                color: context.borderColor,
                width: 2,
              ),
            ),
            child: Icon(
              Icons.star_border,
              size: 40,
              color: context.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Saved',
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Save photos and videos that you want to see again.',
            style: TextStyle(
              color: context.textMuted,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
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
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }
}

// Custom delegate for sticky tab bar
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverAppBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.transparent,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}