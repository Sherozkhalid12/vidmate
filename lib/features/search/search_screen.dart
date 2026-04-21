import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/media/app_media_cache.dart';
import '../../core/models/post_model.dart';
import '../../core/models/user_model.dart';
import '../../core/providers/explore_search_provider_riverpod.dart';
import '../../core/providers/network_status_provider.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/utils/video_thumbnail_helper.dart';
import '../../core/widgets/feed_cached_post_image.dart';
import '../../core/widgets/feed_image_precache.dart';
import '../profile/profile_screen.dart';
import '../profile/profile_post_viewer_screen.dart';

/// Instagram-style Search Screen
class SearchScreen extends ConsumerStatefulWidget {
  final double? bottomPadding;

  const SearchScreen({super.key, this.bottomPadding});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String? _precachedSearchThumbSig;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    ref.read(exploreSearchProvider.notifier).setQuery(value);
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(exploreSearchProvider.notifier).clearQuery();
    _searchFocusNode.unfocus();
  }

  void _removeRecentSearch(String search) {
    ref.read(exploreSearchProvider.notifier).removeRecent(search);
  }

  void _clearAllRecent() {
    ref.read(exploreSearchProvider.notifier).clearRecent();
  }

  void _precacheSearchResultThumbs(ExploreSearchState state) {
    final sig =
        '${state.query}|${state.users.length}|${state.posts.length}|${state.reels.length}|${state.longVideos.length}';
    if (sig == _precachedSearchThumbSig) return;
    _precachedSearchThumbSig = sig;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !context.mounted) return;
      final dpr = MediaQuery.devicePixelRatioOf(context);
      final cell = (MediaQuery.sizeOf(context).width / 3 - 8).clamp(48.0, 400.0);
      final memW = (cell * dpr).round().clamp(48, 420);
      final memH = memW;

      Iterable<String> urlsFromPosts(List<PostModel> list) sync* {
        for (final p in list) {
          final u = _searchPostThumbUrl(p);
          if (u.isNotEmpty && !isProtectedVideoCdnThumbnailUrl(u)) yield u;
        }
      }

      final urls = <String>[];
      for (final u in urlsFromPosts(state.posts)) {
        if (urls.length >= 12) break;
        if (!urls.contains(u)) urls.add(u);
      }
      for (final u in urlsFromPosts(state.reels)) {
        if (urls.length >= 12) break;
        if (!urls.contains(u)) urls.add(u);
      }
      for (final u in urlsFromPosts(state.longVideos)) {
        if (urls.length >= 12) break;
        if (!urls.contains(u)) urls.add(u);
      }
      for (final u in urls) {
        precacheFeedImageSafe(
          ResizeImage(
            CachedNetworkImageProvider(
              u,
              cacheManager: AppMediaCache.feedMedia,
            ),
            width: memW,
            height: memH,
          ),
          context,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final searchState = ref.watch(exploreSearchProvider);
    final isSearching = searchState.query.isNotEmpty;

    if (isSearching &&
        !searchState.loading &&
        searchState.error == null &&
        (searchState.users.isNotEmpty ||
            searchState.posts.isNotEmpty ||
            searchState.reels.isNotEmpty ||
            searchState.longVideos.isNotEmpty)) {
      _precacheSearchResultThumbs(searchState);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: ThemeHelper.getBackgroundGradient(context),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top bar with back button and search
              Container(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  border: Border(
                    bottom: BorderSide(
                      color: ThemeHelper.getBorderColor(context).withOpacity(0.3),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.pop(context),
                      child: Icon(
                        CupertinoIcons.back,
                        color: ThemeHelper.getAccentColor(context),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: ThemeHelper.getSurfaceColor(context),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: ThemeHelper.getBorderColor(context),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              CupertinoIcons.search,
                              color: ThemeHelper.getTextSecondary(context),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                focusNode: _searchFocusNode,
                                autofocus: true,
                                onChanged: _onSearchChanged,
                                style: TextStyle(
                                  color: ThemeHelper.getTextPrimary(context),
                                  fontSize: 16,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Search',
                                  hintStyle: TextStyle(
                                    color: ThemeHelper.getTextSecondary(context),
                                    fontSize: 16,
                                  ),
                                  border: OutlineInputBorder(
                                    borderSide: BorderSide(width: 0, color: Colors.transparent),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(width: 0, color: Colors.transparent),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(width: 0, color: Colors.transparent),
                                  ),
                                  disabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(width: 0, color: Colors.transparent),
                                  ),
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                            if (searchState.query.isNotEmpty)
                              GestureDetector(
                                onTap: _clearSearch,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: ThemeHelper.getTextMuted(context).withOpacity(0.3),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.close,
                                    color: ThemeHelper.getTextPrimary(context),
                                    size: 14,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: isSearching ? _buildSearchResults(searchState) : _buildRecentSearches(searchState),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentSearches(ExploreSearchState state) {
    if (state.recentSearches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.search,
              size: 80,
              color: ThemeHelper.getTextMuted(context).withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No recent searches',
              style: TextStyle(
                color: ThemeHelper.getTextMuted(context),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      key: const PageStorageKey<String>('search_recent_list'),
      padding: EdgeInsets.only(
        bottom: (widget.bottomPadding ?? 0) + 16,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent',
                    style: TextStyle(
                      color: ThemeHelper.getTextPrimary(context),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Container(
                    width: 50,
                    height: 2,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: ThemeHelper.getAccentColor(context),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: _clearAllRecent,
                child: Text(
                  'Clear All',
                  style: TextStyle(
                    color: ThemeHelper.getAccentColor(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...AnimationConfiguration.toStaggeredList(
          duration: const Duration(milliseconds: 375),
          childAnimationBuilder: (widget) => SlideAnimation(
            verticalOffset: 50.0,
            child: FadeInAnimation(child: widget),
          ),
          children: state.recentSearches.map((search) {
            return GestureDetector(
              onTap: () {
                _searchController.text = search;
                _searchController.selection = TextSelection.fromPosition(
                  TextPosition(offset: search.length),
                );
                ref.read(exploreSearchProvider.notifier).setQuery(search);
              },
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: ThemeHelper.getBorderColor(context).withOpacity(0.2),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(
                        CupertinoIcons.clock,
                        color: ThemeHelper.getTextSecondary(context),
                        size: 20,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              search,
                              style: TextStyle(
                                color: ThemeHelper.getTextPrimary(context),
                                fontSize: 15,
                              ),
                            ),
                            Container(
                              width: 50,
                              height: 1.5,
                              margin: const EdgeInsets.only(top: 2),
                              decoration: BoxDecoration(
                                color: ThemeHelper.getAccentColor(context),
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _removeRecentSearch(search),
                        child: Icon(
                          Icons.close,
                          color: ThemeHelper.getTextMuted(context),
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  (Color, Color) _shimmerColors() {
    final base = Theme.of(context).brightness == Brightness.dark
        ? Colors.white10
        : Colors.black12;
    return (base, base.withValues(alpha: 0.35));
  }

  Widget _buildSearchLoadingSkeleton() {
    final (base, hi) = _shimmerColors();
    return ListView(
      key: const PageStorageKey<String>('search_results_skeleton'),
      padding: EdgeInsets.only(
        bottom: (widget.bottomPadding ?? 0) + 16,
        top: 8,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Shimmer.fromColors(
            baseColor: base,
            highlightColor: hi,
            child: Row(
              children: [
                Container(
                  width: 80,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ),
        ...List.generate(6, (i) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Shimmer.fromColors(
              baseColor: base,
              highlightColor: hi,
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 14,
                          width: double.infinity,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 12,
                          width: 120,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Shimmer.fromColors(
            baseColor: base,
            highlightColor: hi,
            child: Container(
              height: 18,
              width: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1,
            ),
            itemCount: 9,
            itemBuilder: (_, __) {
              return Shimmer.fromColors(
                baseColor: base,
                highlightColor: hi,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResults(ExploreSearchState state) {
    final offline = ref.watch(isOfflineProvider);

    if (state.loading) {
      return _buildSearchLoadingSkeleton();
    }
    if (state.error != null) {
      final message = offline
          ? 'Search unavailable offline'
          : state.error!;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ThemeHelper.getTextMuted(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }
    final hasAny = state.users.isNotEmpty ||
        state.posts.isNotEmpty ||
        state.reels.isNotEmpty ||
        state.longVideos.isNotEmpty;
    if (!hasAny) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.search,
              size: 80,
              color: ThemeHelper.getTextMuted(context).withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Column(
              children: [
                Text(
                  'No results found',
                  style: TextStyle(
                    color: ThemeHelper.getTextPrimary(context),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  width: 120,
                  height: 2,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: ThemeHelper.getAccentColor(context),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return ListView(
      key: const PageStorageKey<String>('search_results_list'),
      padding: EdgeInsets.only(
        bottom: (widget.bottomPadding ?? 0) + 16,
        top: 8,
      ),
      children: [
        if (offline && state.query.isNotEmpty)
          Material(
            color: ThemeHelper.getSurfaceColor(context).withValues(alpha: 0.9),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.wifi_off_rounded,
                    size: 18,
                    color: ThemeHelper.getTextSecondary(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Results may be incomplete while offline',
                      style: TextStyle(
                        fontSize: 12,
                        color: ThemeHelper.getTextSecondary(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (state.users.isNotEmpty) ...[
          _buildSectionHeader('Users'),
          _buildUserGrid(state.users),
        ],
        if (state.posts.isNotEmpty) ...[
          _buildSectionHeader('Posts'),
          _buildPostGrid(state.posts),
        ],
        if (state.reels.isNotEmpty) ...[
          _buildSectionHeader('Reels'),
          _buildPostGrid(state.reels),
        ],
        if (state.longVideos.isNotEmpty) ...[
          _buildSectionHeader('Long Videos'),
          _buildPostGrid(state.longVideos),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              color: ThemeHelper.getTextPrimary(context),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 1,
              color: ThemeHelper.getBorderColor(context).withOpacity(0.25),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserGrid(List<UserModel> users) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.6,
      ),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final avatarPx = (40 * dpr).round().clamp(40, 200);
        return RepaintBoundary(
          child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProfileScreen(user: user),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: ThemeHelper.getSurfaceColor(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: ThemeHelper.getBorderColor(context).withOpacity(0.4),
              ),
            ),
            child: Row(
              children: [
                ClipOval(
                  child: user.avatarUrl.isEmpty
                      ? Container(
                          width: 40,
                          height: 40,
                          color: ThemeHelper.getSurfaceColor(context),
                          child: Icon(
                            Icons.person,
                            color: ThemeHelper.getTextSecondary(context),
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: user.avatarUrl,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          cacheManager: AppMediaCache.feedMedia,
                          memCacheWidth: avatarPx,
                          memCacheHeight: avatarPx,
                          errorWidget: (_, __, ___) => Container(
                            width: 40,
                            height: 40,
                            color: ThemeHelper.getSurfaceColor(context),
                            child: Icon(
                              Icons.person,
                              color: ThemeHelper.getTextSecondary(context),
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ThemeHelper.getTextPrimary(context),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ThemeHelper.getTextMuted(context),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        );
      },
    );
  }

  Widget _buildPostGrid(List<PostModel> posts) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: MasonryGridView.count(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: posts.length,
        itemBuilder: (context, index) {
          final post = posts[index];
          return AnimationConfiguration.staggeredGrid(
            position: index,
            duration: const Duration(milliseconds: 220),
            columnCount: 3,
            child: ScaleAnimation(
              child: FadeInAnimation(
                child: _buildPostTile(post, posts, index),
              ),
            ),
          );
        },
      ),
    );
  }

  String _searchPostThumbUrl(PostModel post) {
    final u = post.effectiveThumbnailUrl ?? post.thumbnailUrl ?? '';
    if (u.isEmpty) return '';
    if (!isProtectedVideoCdnThumbnailUrl(u)) return u;
    final v = post.videoUrl ?? '';
    final gen = VideoThumbnailHelper.thumbnailFromVideoUrl(v);
    if (gen != null &&
        gen.isNotEmpty &&
        !isProtectedVideoCdnThumbnailUrl(gen)) {
      return gen;
    }
    return u;
  }

  Widget _buildPostTile(PostModel post, List<PostModel> list, int index) {
    final thumb = _searchPostThumbUrl(post);
    final isVideo = post.isVideo;
    return RepaintBoundary(
      child: GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProfilePostViewerScreen(
              posts: list,
              initialIndex: index,
            ),
          ),
        );
      },
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: FeedCachedPostImage(
                imageUrl: thumb,
                postId: post.id,
                blurHash: post.blurHash,
                fit: BoxFit.cover,
                useShimmerWhileLoading: true,
              ),
            ),
            if (isVideo)
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 16,
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
