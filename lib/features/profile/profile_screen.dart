import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/features/feed/create_content_screen.dart';
import 'package:flutter_application_1/features/feed/create_post_screen.dart';
import '../../core/theme/theme_extensions.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/mock_data_service.dart';
import '../../core/models/user_model.dart';
import '../../core/models/post_model.dart';
import '../../core/utils/theme_helper.dart';
import '../settings/settings_screen.dart';
import 'followers_list_screen.dart';
import 'edit/edit_profile_screen.dart';

/// Instagram-style profile screen
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
  bool _isFollowing = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _user = widget.user ?? MockDataService.mockUsers[0];
    _isFollowing = _user.isFollowing;
    _tabController = TabController(length: 4, vsync: this, initialIndex: 0);
    _loadPosts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadPosts() {
    final allPosts = MockDataService.getMockPosts();
    setState(() {
      _posts.addAll(allPosts.where((p) => p.author.id == _user.id));
    });
  }

  @override
  Widget build(BuildContext context) {
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
                _user.username,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.menu),
                 onPressed: (){
                   _showMenuBottomSheet();
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
                    // Profile info row
                    Row(
                      children: [
                        // Profile picture
                        Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: _isFollowing
                                    ? null
                                    : LinearGradient(
                                  colors: [
                                    context.buttonColor.withOpacity(0.8),
                                    context.buttonColor.withOpacity(0.6),
                                  ],
                                ),
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: context.backgroundColor,
                                ),
                                padding: const EdgeInsets.all(2),
                                child: ClipOval(
                                  child: Image.network(
                                    _user.avatarUrl,
                                    width: 90,
                                    height: 90,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: 90,
                                        height: 90,
                                        color: context.surfaceColor,
                                        child: Icon(
                                          Icons.person,
                                          color: context.textSecondary,
                                          size: 45,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                            if (_user.isOnline)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: context.buttonColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: context.backgroundGradient.colors.first,
                                      width: 3,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 20),
                        // Stats
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatColumn(_user.posts, 'posts'),
                              _buildStatColumn(_user.followers, 'followers'),
                              _buildStatColumn(_user.following, 'following'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Username and bio
                    Text(
                      _user.displayName,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_user.bio != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _user.bio!,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    // Action buttons
                    Row(
                      children: [
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
                                color: context.borderColor,
                                width: 1,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            child: Text(
                              'Following',
                              style: TextStyle(
                                color: context.textPrimary,
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
                              backgroundColor: context.buttonColor,
                              foregroundColor: context.buttonTextColor,
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
                              // Navigate to chat with this user
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Opening chat with ${_user.username}...'),
                                  backgroundColor: context.surfaceColor,
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: context.borderColor,
                                width: 1,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            child: Text(
                              'Message',
                              style: TextStyle(
                                color: context.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditProfileScreen(user: _user),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: context.borderColor,
                              width: 1,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.all(8),
                            minimumSize: const Size(40, 40),
                          ),
                          child: Icon(
                            Icons.person_add_outlined,
                            color: context.textPrimary,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Highlights/Stories
                    SizedBox(
                      height: 90,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: 5,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 66,
                                  height: 66,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [
                                        context.buttonColor.withOpacity(0.8),
                                        context.buttonColor.withOpacity(0.6),
                                      ],
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(2.5),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: context.backgroundColor,
                                    ),
                                    child: ClipOval(
                                      child: Image.network(
                                        'https://i.pravatar.cc/150?img=${index + 10}',
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            color: context.surfaceColor,
                                            child: Icon(
                                              Icons.add,
                                              color: context.textSecondary,
                                              size: 20,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                SizedBox(
                                  width: 66,
                                  child: Text(
                                    index == 0 ? 'New' : 'Story ${index}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: context.textSecondary,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Tab bar
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  indicatorColor: context.textPrimary,
                  labelColor: context.textPrimary,
                  unselectedLabelColor: context.textMuted,
                  tabs: const [
                    Tab(icon: Icon(Icons.grid_on)),
                    Tab(icon: Icon(Icons.play_circle_outline)),
                    Tab(icon: Icon(Icons.video_library)),
                    Tab(icon: Icon(Icons.bookmark_border)),
                  ],
                ),
              ),
            ),
            // Content grid
            SliverFillRemaining(
              hasScrollBody: true,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPostsGrid(),
                  _buildReelsGrid(),
                  _buildLongVideosGrid(),
                  _buildSavedGrid(),
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
        if (label == 'followers') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FollowersListScreen(
                userId: _user.id,
                isFollowers: true,
              ),
            ),
          );
        } else if (label == 'following') {
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

  Widget _buildPostsGrid() {
    if (_posts.isEmpty) {
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
                Icons.grid_on,
                size: 40,
                color: context.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No Posts Yet',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'When you share photos and videos, they\'ll appear here.',
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

    return AnimationLimiter(
      child: GridView.builder(
        padding: const EdgeInsets.all(2),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
        itemCount: _posts.length,
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
                          _posts[index].thumbnailUrl ??
                              _posts[index].imageUrl ??
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
                        if (_posts[index].isVideo)
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

  Widget _buildReelsGrid() {
    final reels = _posts.where((p) => p.isVideo).toList();

    if (reels.isEmpty) {
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
                Icons.play_circle_outline,
                size: 40,
                color: context.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No Reels Yet',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Reels you create will appear here.',
              style: TextStyle(
                color: context.textMuted,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
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

  Widget _buildLongVideosGrid() {
    final longVideos = _posts.where((p) => p.isVideo && (p.videoDuration?.inMinutes ?? 0) >= 1).toList();

    if (longVideos.isEmpty) {
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
                Icons.video_library,
                size: 40,
                color: context.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No Long Videos Yet',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Long videos you upload will appear here.',
              style: TextStyle(
                color: context.textMuted,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
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
              Icons.bookmark_border,
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