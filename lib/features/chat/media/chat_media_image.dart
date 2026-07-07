import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/media/app_media_cache.dart';
import '../../../core/utils/theme_helper.dart';

/// Optimized chat media image.
///
/// Design goals (WhatsApp / Instagram parity):
/// - Decode at the *display* size, never the source size, so a grid of
///   thumbnails never inflates dozens of full-resolution bitmaps into memory.
/// - Share one disk cache ([AppMediaCache.chatMedia]) keyed by URL so the same
///   asset shown in a bubble, the grid, and the viewer is fetched only once.
/// - Cheap shimmer placeholder + no fade flashes on rebuild.
class ChatMediaImage extends StatelessWidget {
  final String url;
  final BoxFit fit;

  /// Logical target box; used to derive the in-memory decode dimensions.
  final double? targetWidth;
  final double? targetHeight;

  /// Full quality (viewer) skips the aggressive memory-cache downscale.
  final bool highQuality;

  const ChatMediaImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.targetWidth,
    this.targetHeight,
    this.highQuality = false,
  });

  int? _memCacheDimension(double? logical, double dpr, int cap) {
    if (highQuality || logical == null || logical <= 0) return null;
    final px = (logical * dpr).round();
    return px.clamp(1, cap);
  }

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return _broken(context);

    if (!url.startsWith('http')) {
      return Image.file(
        File(url),
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _broken(context),
      );
    }

    final dpr = MediaQuery.devicePixelRatioOf(context);
    final memW = _memCacheDimension(targetWidth, dpr, 1080);
    final memH = _memCacheDimension(targetHeight, dpr, 1920);

    return CachedNetworkImage(
      imageUrl: url,
      cacheKey: url,
      cacheManager: AppMediaCache.chatMedia,
      fit: fit,
      memCacheWidth: memW,
      memCacheHeight: memH,
      fadeInDuration: const Duration(milliseconds: 150),
      fadeOutDuration: Duration.zero,
      placeholderFadeInDuration: Duration.zero,
      useOldImageOnUrlChange: true,
      placeholder: (_, __) => _shimmer(context),
      errorWidget: (_, __, ___) => _broken(context),
    );
  }

  Widget _shimmer(BuildContext context) {
    final base = Theme.of(context).brightness == Brightness.dark
        ? Colors.white10
        : Colors.black12;
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: base.withValues(alpha: 0.35),
      child: const ColoredBox(color: Colors.white),
    );
  }

  Widget _broken(BuildContext context) {
    return ColoredBox(
      color: ThemeHelper.getSurfaceColor(context),
      child: Icon(
        Icons.broken_image_outlined,
        color: ThemeHelper.getTextMuted(context),
      ),
    );
  }
}
