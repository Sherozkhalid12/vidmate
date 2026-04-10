import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/features/feed/create_content_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/theme_extensions.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/models/user_model.dart';
import '../../core/models/post_model.dart';
import '../../core/providers/auth_provider_riverpod.dart';
import '../../core/providers/follow_provider_riverpod.dart';
import '../../core/providers/posts_provider_riverpod.dart';
import '../../core/providers/fetched_users_provider_riverpod.dart';
import '../../core/providers/reels_provider_riverpod.dart';
import '../../features/long_videos/providers/long_videos_provider.dart';
import '../../core/utils/theme_helper.dart';
import '../settings/settings_screen.dart';
import '../chat/chat_screen.dart';
import 'edit/edit_profile_screen.dart';
import 'profile_post_viewer_screen.dart';
import '../live/live_stream_studio_screen.dart';

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
  String? _displayedUserId;
  String? _followPrefetchUserId;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 0);
    _prefetchOtherUserIfNeeded();
  }

  void _prefetchOtherUserIfNeeded() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final currentUserId = ref.read(currentUserProvider)?.id;
      final incoming = widget.user;
      if (incoming == null) return;
      final incomingId = incoming.id.trim();
      if (incomingId.isEmpty) return;
      if (currentUserId != null && incomingId == currentUserId.trim()) return;
      final cached = ref.read(fetchedUserProvider(incomingId));
      if (cached != null) return;
      ref.read(fetchedUsersProvider.notifier).fetchIfNeeded(incomingId);
    });
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user?.id != widget.user?.id) {
      _prefetchOtherUserIfNeeded();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  (Color, Color) _shimmerPair(BuildContext context) {
    final base = Theme.of(context).brightness == Brightness.dark
        ? Colors.white10
        : Colors.black12;
    return (base, base.withValues(alpha: 0.35));
  }

  /// Full-screen shimmer while profile user is resolving (self not loaded yet, or other user fetch).
  Widget _buildProfileLoadingShell(BuildContext context) {
    final (base, hi) = _shimmerPair(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(gradient: context.backgroundGradient),
        child: SafeArea(
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  child: Column(
                    children: [
                      Shimmer.fromColors(
                        baseColor: base,
                        highlightColor: hi,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Shimmer.fromColors(
                        baseColor: base,
                        highlightColor: hi,
                        child: Container(
                          height: 16,
                          width: 140,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(
                          3,
                          (i) => Shimmer.fromColors(
                            baseColor: base,
                            highlightColor: hi,
                            child: Column(
                              children: [
                                Container(
                                  width: 36,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  width: 56,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(2),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 2,
                    mainAxisSpacing: 2,
                    childAspectRatio: 1,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return Shimmer.fromColors(
                        baseColor: base,
                        highlightColor: hi,
                        child: Container(color: Colors.white),
                      );
                    },
                    childCount: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileTabGridShimmer(BuildContext context) {
    final (base, hi) = _shimmerPair(context);
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: 12,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: base,
          highlightColor: hi,
          child: Container(color: Colors.white),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final incomingUser = widget.user;
    final incomingId = incomingUser?.id.trim() ?? '';
    // IMPORTANT: treat it as "other user" even if currentUser hasn't loaded yet,
    // otherwise the fetched user won't be watched and UI can get stuck on placeholder/loading.
    final isOtherUser = incomingUser != null &&
        (currentUser == null || incomingId != currentUser.id.trim());
    final fetchedUser = (isOtherUser && incomingId.isNotEmpty)
        ? ref.watch(fetchedUserProvider(incomingId))
        : null;
    final isFetchingOtherUser = (isOtherUser && incomingId.isNotEmpty)
        ? ref.watch(fetchedUserLoadingProvider(incomingId))
        : false;
    final otherUserError = (isOtherUser && incomingId.isNotEmpty)
        ? ref.watch(fetchedUserErrorProvider(incomingId))
        : null;
    final user = (isOtherUser ? (fetchedUser ?? incomingUser) : (incomingUser ?? currentUser));
    if (user == null) {
      return _buildProfileLoadingShell(context);
    }
    if (isOtherUser && fetchedUser == null && isFetchingOtherUser) {
      return _buildProfileLoadingShell(context);
    }
    if (isOtherUser && fetchedUser == null && otherUserError != null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: BoxDecoration(gradient: context.backgroundGradient),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline,
                      color: ThemeHelper.getTextMuted(context), size: 34),
                  const SizedBox(height: 10),
                  Text(
                    otherUserError,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ThemeHelper.getTextSecondary(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: incomingId.isEmpty
                          ? null
                          : () => ref
                              .read(fetchedUsersProvider.notifier)
                              .fetch(incomingId),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThemeHelper.getAccentColor(context),
                        foregroundColor: ThemeHelper.getOnAccentColor(context),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Retry',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    if (user.id != _displayedUserId) {
      _displayedUserId = user.id;
    }
    final userPostsState = ref.watch(userPostsProvider(user.id));
    final posts = userPostsState.posts;
    final reelsState = ref.watch(reelsProvider);
    final longVideosState = ref.watch(longVideosProvider);
    final reelPosts = () {
      final set = <String>{};
      final list = <PostModel>[];
      for (final p in posts.where((p) => p.postType == 'reel')) {
        if (set.add(p.id)) list.add(p);
      }
      for (final p in reelsState.reels.where((r) => r.author.id == user.id)) {
        if (set.add(p.id)) list.add(p);
      }
      return list;
    }();

    final longVideoPosts = () {
      final set = <String>{};
      final list = <PostModel>[];
      for (final p in posts.where((p) => p.postType == 'longVideo')) {
        if (set.add(p.id)) list.add(p);
      }
      for (final p in longVideosState.videos.where((v) => v.author.id == user.id)) {
        if (set.add(p.id)) list.add(p);
      }
      return list;
    }();
    final showProfilePostsSkeleton = userPostsState.isLoading &&
        posts.isEmpty &&
        !userPostsState.initialFetchCompleted;
    final isCurrentUser = currentUser != null && currentUser.id == user.id;
    final followOverrides = ref.watch(followStateProvider);
    final followState = ref.watch(followProvider);
    final overrideStatus = followOverrides[user.id];
    final isFollowing = overrideStatus == FollowRelationshipStatus.following ||
        (overrideStatus == null &&
            (followState.followingIds.isNotEmpty
                ? followState.followingIds.contains(user.id)
                : user.isFollowing));
    final isPending = overrideStatus == FollowRelationshipStatus.pending ||
        (overrideStatus == null &&
            followState.outgoingPendingRequests.containsKey(user.id));
    final followersCount =
        isCurrentUser ? followState.followersList.length : user.followers;
    final followingCount =
        isCurrentUser ? followState.followingIds.length : user.following;
    if (isCurrentUser && _followPrefetchUserId != user.id) {
      _followPrefetchUserId = user.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(followProvider.notifier).ensureFollowListsLoaded();
      });
    }

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
                        onTap: () {
                          _showCreateContentSheet();
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
                if (isCurrentUser)
                  IconButton(
                    icon: const Icon(CupertinoIcons.line_horizontal_3),
                    onPressed: () {
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
                          if (user.verified)
                            Container(
                              width: 16,
                              height: 16,
                              decoration: const BoxDecoration(
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
                        _buildStatColumn(followersCount, "Follower's", isCurrentUser),
                        _buildStatColumn(followingCount, 'Following', isCurrentUser),
                        _buildStatColumn(
                          userPostsState.isLoading && posts.isEmpty
                              ? user.posts
                              : posts.where((p) => p.postType != 'story').length,
                          'Posts',
                          false,
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
                                child: isFollowing
                                    ? OutlinedButton(
                                        onPressed: () {
                                          ref.read(followProvider.notifier).unfollow(user.id);
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
                                          ref.read(followProvider.notifier).follow(user.id);
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
                                          isPending ? 'Requested' : 'Follow',
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
                                        builder: (context) => ChatScreen(user: user),
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
            // Content grid - categorize by postType from API
            SliverFillRemaining(
              hasScrollBody: true,
              child: showProfilePostsSkeleton
                  ? _buildProfileTabGridShimmer(context)
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildPostsGrid(posts.where((p) => p.postType == 'post').toList()),
                        _buildReelsGrid(reelPosts),
                        _buildLongVideosGrid(longVideoPosts),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(int value, String label, [bool canOpenSheet = false]) {
    return GestureDetector(
      onTap: canOpenSheet
          ? () {
              _showFollowersFollowingSheet(label.toLowerCase().contains('follower'));
            }
          : null,
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

  /// Hovering bottom sheet for creating new content (Post, Story, Reel, Long Video, Live).
  /// Opaque background for both light and dark modes; improved card design.
  void _showCreateContentSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bgColor = ThemeHelper.getBackgroundColor(context);
        final surfaceColor = ThemeHelper.getSurfaceColor(context);
        final borderColor = ThemeHelper.getBorderColor(context);
        final textPrimary = ThemeHelper.getTextPrimary(context);
        final textSecondary = ThemeHelper.getTextSecondary(context);
        final accent = ThemeHelper.getAccentColor(context);

        final options = [
          (
            type: ContentType.post,
            label: 'Post',
            icon: Icons.grid_on_outlined,
          ),
          (
            type: ContentType.story,
            label: 'Story',
            icon: Icons.auto_stories_outlined,
          ),
          (
            type: ContentType.reel,
            label: 'Reel',
            icon: Icons.video_library_outlined,
          ),
          (
            type: ContentType.longVideo,
            label: 'Long video',
            icon: Icons.movie_outlined,
          ),
          (
            type: ContentType.live,
            label: 'Live',
            icon: Icons.live_tv_rounded,
          ),
        ];

        return Container(
          margin: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor.withOpacity(0.6), width: 1),
            color: bgColor,
            boxShadow: [
              BoxShadow(
                color: textPrimary.withOpacity(isDark ? 0.25 : 0.12),
                blurRadius: 24,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Create',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        splashRadius: 20,
                        icon: Icon(
                          Icons.close_rounded,
                          color: textSecondary,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Choose what you want to share.',
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 20),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.9,
                    ),
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final opt = options[index];
                      final cardBg = surfaceColor;
                      final cardBorder = borderColor.withOpacity(isDark ? 0.7 : 0.5);
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.pop(context);
                            if (opt.type == ContentType.live) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const LiveStreamStudioScreen(),
                                ),
                              );
                              return;
                            }
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CreateContentScreen(
                                  initialType: opt.type,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: cardBg,
                              border: Border.all(color: cardBorder, width: 1),
                              boxShadow: [
                                BoxShadow(
                                  color: textPrimary.withOpacity(isDark ? 0.08 : 0.06),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: accent.withOpacity(isDark ? 0.2 : 0.14),
                                  ),
                                  child: Icon(
                                    opt.icon,
                                    size: 22,
                                    color: accent,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  opt.label,
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showFollowersFollowingSheet(bool isFollowers) {
    final followState = ref.read(followProvider);
    final users = isFollowers
        ? followState.followersList
        : followState.followingList;
    final isLoading = isFollowers
        ? followState.isLoadingFollowers
        : followState.isLoadingFollowing;
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
        builder: (context, scrollController) => Consumer(
          builder: (context, ref, _) {
            final followStateLive = ref.watch(followProvider);
            final usersLive = isFollowers
                ? followStateLive.followersList
                : followStateLive.followingList;
            final isLoadingLive = isFollowers
                ? followStateLive.isLoadingFollowers
                : followStateLive.isLoadingFollowing;
            final currentUserId = ref.watch(currentUserProvider)?.id;
            return Column(
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
                  child: isLoadingLive && usersLive.isEmpty
                      ? Center(
                          child: CircularProgressIndicator(
                            color: ThemeHelper.getAccentColor(context),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: usersLive.length,
                          itemBuilder: (context, index) {
                            final listUser = usersLive[index];
                            final isFollowingUser = followStateLive.followingIds.contains(listUser.id) || listUser.isFollowing;
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: listUser.avatarUrl.isNotEmpty
                                    ? NetworkImage(listUser.avatarUrl)
                                    : null,
                                backgroundColor: ThemeHelper.getSurfaceColor(context),
                                child: listUser.avatarUrl.isEmpty
                                    ? Icon(Icons.person, color: ThemeHelper.getTextSecondary(context))
                                    : null,
                              ),
                              title: Text(
                                listUser.username,
                                style: TextStyle(
                                  color: ThemeHelper.getTextPrimary(context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                listUser.displayName,
                                style: TextStyle(
                                  color: ThemeHelper.getTextSecondary(context),
                                ),
                              ),
                              trailing: currentUserId == listUser.id
                                  ? const SizedBox.shrink()
                                  : isFollowingUser
                                      ? OutlinedButton(
                                          onPressed: () {
                                            ref.read(followProvider.notifier).unfollow(listUser.id);
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
                                          onPressed: () {
                                            ref.read(followProvider.notifier).follow(listUser.id);
                                          },
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
            );
          },
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
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfilePostViewerScreen(
                          posts: posts,
                          initialIndex: index,
                        ),
                      ),
                    );
                  },
                        child: Container(
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        (() {
                          final imageUrl =
                              posts[index].effectiveThumbnailUrl ?? posts[index].imageUrl ?? '';
                          if (imageUrl.isEmpty) {
                            return Container(
                              color: context.surfaceColor,
                              child: Icon(
                                Icons.image_not_supported,
                                color: context.textMuted,
                              ),
                            );
                          }
                          return CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            fadeInDuration: const Duration(milliseconds: 180),
                            placeholder: (context, url) => Container(
                              color: context.surfaceColor,
                              child: Icon(
                                Icons.image,
                                color: context.textMuted,
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: context.surfaceColor,
                              child: Icon(
                                Icons.image_not_supported,
                                color: context.textMuted,
                              ),
                            ),
                          );
                        })(),
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
    if (posts.isEmpty) {
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
        itemCount: posts.length,
        itemBuilder: (context, index) {
          return AnimationConfiguration.staggeredGrid(
            position: index,
            duration: const Duration(milliseconds: 375),
            columnCount: 3,
            child: ScaleAnimation(
              child: FadeInAnimation(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfilePostViewerScreen(
                          posts: posts,
                          initialIndex: index,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        (() {
                          final post = posts[index];
                          final imageUrl =
                              post.effectiveThumbnailUrl ?? post.imageUrl ?? '';
                          if (imageUrl.isEmpty) {
                            return Container(
                              color: context.surfaceColor,
                              alignment: Alignment.center,
                              child: Icon(Icons.video_library_outlined,
                                  color: context.textMuted, size: 24),
                            );
                          }
                          return CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            fadeInDuration: const Duration(milliseconds: 120),
                            placeholder: (context, url) => Container(
                              color: context.surfaceColor,
                              alignment: Alignment.center,
                              child: Icon(Icons.video_library_outlined,
                                  color: context.textMuted, size: 20),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: context.surfaceColor,
                              alignment: Alignment.center,
                              child: Icon(Icons.video_library_outlined,
                                  color: context.textMuted, size: 22),
                            ),
                          );
                        })(),
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
    if (posts.isEmpty) {
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
        itemCount: posts.length,
        itemBuilder: (context, index) {
          return AnimationConfiguration.staggeredGrid(
            position: index,
            duration: const Duration(milliseconds: 375),
            columnCount: 3,
            child: ScaleAnimation(
              child: FadeInAnimation(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfilePostViewerScreen(
                          posts: posts,
                          initialIndex: index,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        (() {
                          final thumbnailUrl = posts[index].effectiveThumbnailUrl ?? posts[index].thumbnailUrl ?? '';
                          if (thumbnailUrl.isEmpty) {
                            return Container(
                              color: context.surfaceColor,
                            );
                          }
                          return CachedNetworkImage(
                            imageUrl: thumbnailUrl,
                            fit: BoxFit.cover,
                            fadeInDuration: const Duration(milliseconds: 180),
                            placeholder: (context, url) => Container(
                              color: context.surfaceColor,
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: context.surfaceColor,
                            ),
                          );
                        })(),
                        Center(
                          child: Icon(
                            Icons.play_circle_filled,
                            color: context.textPrimary,
                            size: 32,
                          ),
                        ),
                        if (posts[index].videoDuration != null)
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
                                _formatDuration(posts[index].videoDuration!),
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
