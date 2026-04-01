import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/models/post_model.dart';
import '../../core/providers/saved_posts_provider_riverpod.dart';
import '../../core/widgets/instagram_post_card.dart';

/// Saved content screen with tab bar (Post, Reels, Long Videos).
/// Opened from Settings when user taps the Saved tile.
class SavedScreen extends ConsumerStatefulWidget {
  const SavedScreen({super.key});

  @override
  ConsumerState<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends ConsumerState<SavedScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(savedPostsProvider.notifier).loadSavedPosts();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: ThemeHelper.getBackgroundGradient(context),
        ),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new,
                  size: 20,
                  color: ThemeHelper.getTextPrimary(context),
                ),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'Saved',
                style: TextStyle(
                  color: ThemeHelper.getTextPrimary(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SavedSliverTabBarDelegate(
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
            SliverFillRemaining(
              hasScrollBody: true,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildSavedTab('post'),
                  _buildSavedTab('reel'),
                  _buildSavedTab('longVideo'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedTab(String postType) {
    final state = ref.watch(savedPostsProvider);
    if (state.isLoading && state.posts.isEmpty) {
      return Center(
        child: CircularProgressIndicator(color: ThemeHelper.getAccentColor(context)),
      );
    }
    final filtered = state.posts.where((p) => p.postType == postType).toList();
    if (filtered.isEmpty) return _buildSavedEmptyState();
    return RefreshIndicator(
      onRefresh: () => ref.read(savedPostsProvider.notifier).loadSavedPosts(),
      color: ThemeHelper.getAccentColor(context),
      child: GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          childAspectRatio: 1,
        ),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final post = filtered[index];
          return _buildSavedGridItem(post);
        },
      ),
    );
  }

  Widget _buildSavedGridItem(PostModel post) {
    final thumb = post.effectiveThumbnailUrl ?? post.imageUrl ?? '';
    return GestureDetector(
      onTap: () => _openSavedPost(post),
      child: Container(
        color: ThemeHelper.getSurfaceColor(context),
        child: thumb.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: thumb,
                fit: BoxFit.cover,
                placeholder: (_, __) => Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: ThemeHelper.getAccentColor(context),
                    ),
                  ),
                ),
                errorWidget: (_, __, ___) => Icon(
                  Icons.broken_image_outlined,
                  color: ThemeHelper.getTextMuted(context),
                  size: 32,
                ),
              )
            : Icon(
                Icons.image_not_supported_outlined,
                color: ThemeHelper.getTextMuted(context),
                size: 32,
              ),
      ),
    );
  }

  void _openSavedPost(PostModel post) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          backgroundColor: ThemeHelper.getBackgroundColor(context),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new, color: ThemeHelper.getTextPrimary(context)),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: SingleChildScrollView(
            child: InstagramPostCard(post: post),
          ),
        ),
      ),
    );
  }

  Widget _buildSavedEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
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
                Icons.bookmark_border_rounded,
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
      ),
    );
  }
}

class _SavedSliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SavedSliverTabBarDelegate(this.tabBar);

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
  bool shouldRebuild(_SavedSliverTabBarDelegate oldDelegate) {
    return false;
  }
}
