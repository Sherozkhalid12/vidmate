import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/post_model.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/widgets/feed_cached_post_image.dart';
import '../../core/widgets/feed_image_precache.dart';
import '../video/video_player_screen.dart';
import 'long_video_embedded_session_host.dart';
import 'providers/long_video_feed_search_query_provider.dart';
import 'providers/long_video_search_filtered_provider.dart';

/// In-feed long video search: thumbnail rows only; tap opens [VideoPlayerScreen] (Section 4).
class LongVideosSearchScreen extends ConsumerStatefulWidget {
  final String initialQuery;
  final double bottomPadding;

  const LongVideosSearchScreen({
    super.key,
    this.initialQuery = '',
    this.bottomPadding = 0,
  });

  @override
  ConsumerState<LongVideosSearchScreen> createState() =>
      _LongVideosSearchScreenState();
}

class _LongVideosSearchScreenState extends ConsumerState<LongVideosSearchScreen> {
  late final TextEditingController _searchController;
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(longVideoFeedSearchQueryProvider.notifier).state =
          widget.initialQuery;
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _clearQuery() {
    ref.read(longVideoFeedSearchQueryProvider.notifier).state = '';
  }

  String _formatViews(int views) {
    if (views >= 1000000) return '${(views / 1000000).toStringAsFixed(1)}M';
    if (views >= 1000) return '${(views / 1000).toStringAsFixed(1)}K';
    return '$views';
  }

  void _openPlayer(PostModel video) {
    final videoUrl = video.videoUrl;
    if (videoUrl == null || videoUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No video URL for this post.')),
      );
      return;
    }
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => video.postType == 'longVideo'
            ? LongVideoEmbeddedSessionHost(post: video)
            : VideoPlayerScreen(
                key: ValueKey<String>('lv_search_$videoUrl'),
                videoUrl: videoUrl,
                title: video.caption,
                author: video.author,
                post: video,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = ref.watch(longVideoSearchFilteredProvider);
    final query = ref.watch(longVideoFeedSearchQueryProvider);
    final hasQuery = query.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: ThemeHelper.getBackgroundGradient(context),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: ThemeHelper.getBorderColor(context)
                          .withValues(alpha: 0.3),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        final q = _searchController.text.trim();
                        _searchController.clear();
                        _clearQuery();
                        Navigator.pop(context, q);
                      },
                      child: Icon(
                        CupertinoIcons.back,
                        color: ThemeHelper.getAccentColor(context),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        onChanged: (v) {
                          ref
                              .read(longVideoFeedSearchQueryProvider.notifier)
                              .state = v;
                        },
                        style: TextStyle(
                          color: ThemeHelper.getTextPrimary(context),
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: ThemeHelper.getSurfaceColor(context)
                              .withValues(alpha: 0.42),
                          hintText: 'Search long videos',
                          hintStyle: TextStyle(
                            color: ThemeHelper.getTextSecondary(context),
                            fontSize: 16,
                          ),
                          prefixIcon: Icon(
                            CupertinoIcons.search,
                            color: ThemeHelper.getTextSecondary(context),
                            size: 20,
                          ),
                          suffixIcon: hasQuery
                              ? IconButton(
                                  icon: Icon(
                                    CupertinoIcons.clear_circled_solid,
                                    size: 20,
                                    color: ThemeHelper.getTextMuted(context),
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    _clearQuery();
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide(
                              color: ThemeHelper.getAccentColor(context),
                              width: 1.5,
                            ),
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            hasQuery
                                ? 'No long videos found'
                                : 'Search long videos by title or creator',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: ThemeHelper.getTextSecondary(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          12,
                          12,
                          12,
                          widget.bottomPadding + 12,
                        ),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final video = filtered[index];
                          final rawThumb = video.effectiveThumbnailUrl ??
                              video.thumbnailUrl ??
                              video.imageUrl ??
                              '';
                          final thumb = rawThumb.isNotEmpty &&
                                  !isProtectedVideoCdnThumbnailUrl(rawThumb)
                              ? rawThumb
                              : '';
                          return Material(
                            color: ThemeHelper.getSurfaceColor(context)
                                .withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => _openPlayer(video),
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: SizedBox(
                                        width: 140,
                                        height: 86,
                                        child: thumb.isEmpty
                                            ? ColoredBox(
                                                color:
                                                    ThemeHelper.getBorderColor(
                                                  context,
                                                ),
                                                child: Icon(
                                                  Icons.video_library,
                                                  color:
                                                      ThemeHelper.getTextMuted(
                                                    context,
                                                  ),
                                                ),
                                              )
                                            : FeedCachedPostImage(
                                                imageUrl: thumb,
                                                postId: video.id,
                                                blurHash: video.blurHash,
                                                fit: BoxFit.cover,
                                              ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            video.caption.isEmpty
                                                ? 'Untitled video'
                                                : video.caption,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: ThemeHelper.getTextPrimary(
                                                context,
                                              ),
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            video.author.displayName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color:
                                                  ThemeHelper.getTextSecondary(
                                                context,
                                              ),
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${_formatViews(video.likes * 10)} views',
                                            style: TextStyle(
                                              color: ThemeHelper.getTextMuted(
                                                context,
                                              ),
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
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
