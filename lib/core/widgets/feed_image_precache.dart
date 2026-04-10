import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';

import '../models/post_model.dart';
import '../media/app_media_cache.dart';
import '../media/feed_image_decode_limits.dart';
import '../utils/video_thumbnail_helper.dart';

/// CloudFront paths under [/posts/videos/] often return 403 without signed cookies — never precache.
bool isProtectedVideoCdnThumbnailUrl(String url) =>
    url.contains('/posts/videos/');

/// Fire-and-forget precache; failures (403, etc.) must not surface as framework errors.
void precacheFeedImageSafe(ImageProvider provider, BuildContext context) {
  if (!context.mounted) return;
  unawaited(precacheImage(provider, context).catchError((Object _) {}));
}

void _addPrecacheUrl(List<String> urls, String u) {
  if (u.isEmpty || isProtectedVideoCdnThumbnailUrl(u)) return;
  if (!urls.contains(u)) urls.add(u);
}

/// All network image URLs used by a post carousel (images + video thumbnail), in display order.
/// Excludes URLs that are known to fail HTTP fetch (403) so [precacheImage] does not throw.
List<String> feedCarouselImageUrls(PostModel post) {
  final urls = <String>[];
  for (final u in post.imageUrls) {
    if (u.isEmpty) continue;
    if (isProtectedVideoCdnThumbnailUrl(u)) {
      final v = post.videoUrl;
      if (v != null && v.isNotEmpty) {
        final gen = VideoThumbnailHelper.thumbnailFromVideoUrl(v);
        if (gen != null && gen.isNotEmpty) _addPrecacheUrl(urls, gen);
      }
      continue;
    }
    _addPrecacheUrl(urls, u);
  }
  final v = post.videoUrl;
  if (v != null && v.isNotEmpty) {
    final thumb = VideoThumbnailHelper.thumbnailFromVideoUrl(v);
    if (thumb != null && thumb.isNotEmpty) _addPrecacheUrl(urls, thumb);
  }
  if (urls.isEmpty) {
    for (final candidate in [
      post.imageUrl,
      post.thumbnailUrl,
      post.effectiveThumbnailUrl,
    ]) {
      if (candidate != null && candidate.isNotEmpty) {
        _addPrecacheUrl(urls, candidate);
        if (urls.isNotEmpty) break;
      }
    }
  }
  return urls;
}

/// Warm disk/memory cache for the first [max] feed thumbnails only.
void precacheFirstFeedImages(
  List<PostModel> posts, {
  required BuildContext context,
  int max = 4,
}) {
  if (!context.mounted || posts.isEmpty) return;
  final dpr = MediaQuery.devicePixelRatioOf(context);
  final dims = feedMemCacheDimensions(MediaQuery.sizeOf(context), dpr);
  final w = dims.w;
  final h = dims.h;
  for (final post in posts.take(max)) {
    final url = post.thumbnailUrl ??
        post.imageUrl ??
        post.effectiveThumbnailUrl ??
        (post.imageUrls.isNotEmpty ? post.imageUrls.first : null);
    if (url == null || url.isEmpty) continue;
    if (isProtectedVideoCdnThumbnailUrl(url)) continue;
    final provider = ResizeImage(
      CachedNetworkImageProvider(
        url,
        cacheManager: AppMediaCache.feedMedia,
      ),
      width: w,
      height: h,
    );
    precacheFeedImageSafe(provider, context);
  }
}

/// Precache every carousel image for the first [maxPosts] posts (same decode size as [FeedCachedPostImage]).
void precacheFeedCarouselImages(
  List<PostModel> posts, {
  required BuildContext context,
  int maxPosts = 12,
}) {
  if (!context.mounted || posts.isEmpty) return;
  final dpr = MediaQuery.devicePixelRatioOf(context);
  final dims = feedMemCacheDimensions(MediaQuery.sizeOf(context), dpr);
  final w = dims.w;
  final h = dims.h;
  for (final post in posts.take(maxPosts)) {
    for (final url in feedCarouselImageUrls(post)) {
      if (url.isEmpty) continue;
      final provider = ResizeImage(
        CachedNetworkImageProvider(
          url,
          cacheManager: AppMediaCache.feedMedia,
        ),
        width: w,
        height: h,
      );
      precacheFeedImageSafe(provider, context);
    }
  }
}
