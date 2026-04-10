import 'dart:typed_data';
import 'dart:ui';

import 'package:blurhash_dart/blurhash_dart.dart' as bh;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:shimmer/shimmer.dart';

import '../media/app_media_cache.dart';
import '../media/feed_image_decode_limits.dart';
import '../utils/theme_helper.dart';

/// Post media image with named cache, BlurHash / gradient / persisted dominant color placeholders.
class FeedCachedPostImage extends StatefulWidget {
  final String imageUrl;
  final String postId;
  final String? blurHash;
  final BoxFit fit;
  /// While the network image loads, show shimmer instead of blur/gradient preview.
  final bool useShimmerWhileLoading;

  const FeedCachedPostImage({
    super.key,
    required this.imageUrl,
    required this.postId,
    this.blurHash,
    this.fit = BoxFit.cover,
    this.useShimmerWhileLoading = false,
  });

  @override
  State<FeedCachedPostImage> createState() => _FeedCachedPostImageState();
}

class _FeedCachedPostImageState extends State<FeedCachedPostImage> {
  static bool _isProtectedCdnThumb(String u) => u.contains('/posts/videos/');

  Widget _shimmerLoading(BuildContext context) {
    final base = Theme.of(context).brightness == Brightness.dark
        ? Colors.white10
        : Colors.black12;
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: base.withValues(alpha: 0.35),
      child: Container(
        color: Colors.white,
        width: double.infinity,
        height: double.infinity,
      ),
    );
  }

  Widget _softBase(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ThemeHelper.getSurfaceColor(context),
            ThemeHelper.getSurfaceColor(context).withOpacity(0.65),
          ],
        ),
      ),
    );
  }

  Widget _blurredTransparentFromImage(Size size, double dpr) {
    if (_isProtectedCdnThumb(widget.imageUrl)) {
      return const SizedBox.shrink();
    }
    final dims = feedMemCacheDimensions(size, dpr);
    final previewW = (dims.w ~/ 6).clamp(48, 220);
    final previewH = (dims.h ~/ 6).clamp(64, 280);
    return Opacity(
      opacity: 0.52,
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 11, sigmaY: 11),
        child: Image(
          image: ResizeImage(
            CachedNetworkImageProvider(
              widget.imageUrl,
              cacheManager: AppMediaCache.feedMedia,
            ),
            width: previewW,
            height: previewH,
          ),
          fit: widget.fit,
          width: double.infinity,
          height: double.infinity,
          filterQuality: FilterQuality.low,
          gaplessPlayback: true,
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    if (widget.useShimmerWhileLoading) {
      if (widget.blurHash != null && widget.blurHash!.isNotEmpty) {
        try {
          final decoded = bh.BlurHash.decode(widget.blurHash!);
          final raster = decoded.toImage(96, 96);
          final jpg = img.encodeJpg(raster, quality: 82);
          return Stack(
            fit: StackFit.expand,
            children: [
              _shimmerLoading(context),
              Positioned.fill(
                child: Opacity(
                  opacity: 0.42,
                  child: Image.memory(
                    Uint8List.fromList(jpg),
                    fit: widget.fit,
                    width: double.infinity,
                    height: double.infinity,
                    filterQuality: FilterQuality.low,
                  ),
                ),
              ),
            ],
          );
        } catch (_) {}
      }
      return _shimmerLoading(context);
    }
    final size = MediaQuery.sizeOf(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final h = widget.blurHash;
    final base = _softBase(context);
    if (h != null && h.isNotEmpty) {
      try {
        final decoded = bh.BlurHash.decode(h);
        final raster = decoded.toImage(96, 96);
        final jpg = img.encodeJpg(raster, quality: 82);
        return Stack(
          fit: StackFit.expand,
          children: [
            base,
            Positioned.fill(
              child: Opacity(
                opacity: 0.42,
                child: Image.memory(
                  Uint8List.fromList(jpg),
                  fit: widget.fit,
                  width: double.infinity,
                  height: double.infinity,
                  filterQuality: FilterQuality.low,
                ),
              ),
            ),
          ],
        );
      } catch (_) {}
    }
    if (widget.imageUrl.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          base,
          _blurredTransparentFromImage(size, dpr),
        ],
      );
    }
    return base;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrl.isEmpty) {
      return _placeholder(context);
    }
    final mq = MediaQuery.sizeOf(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final dims = feedMemCacheDimensions(mq, dpr);
    return CachedNetworkImage(
      imageUrl: widget.imageUrl,
      cacheManager: AppMediaCache.feedMedia,
      cacheKey: widget.imageUrl,
      fit: widget.fit,
      width: double.infinity,
      height: double.infinity,
      memCacheWidth: dims.w,
      memCacheHeight: dims.h,
      // Avoid placeholder flash when parent rebuilds after SWR — image stays in memory cache.
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholderFadeInDuration: Duration.zero,
      useOldImageOnUrlChange: true,
      placeholder: (context, url) => _placeholder(context),
      errorWidget: (context, url, error) => Container(
        color: ThemeHelper.getSurfaceColor(context),
        child: Center(
          child: Icon(
            CupertinoIcons.exclamationmark_triangle_fill,
            color: ThemeHelper.getTextSecondary(context),
            size: 48,
          ),
        ),
      ),
      imageBuilder: (context, provider) => Image(
        image: provider,
        fit: widget.fit,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}
