import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/io_client.dart';

/// Singleton named caches for thumbnails (reels, feed, explore).
class AppMediaCache {
  AppMediaCache._();

  static final IOClient _feedImageClient = IOClient(
    HttpClient()
      ..maxConnectionsPerHost = 4
      ..connectionTimeout = const Duration(seconds: 10),
  );

  /// Isolated pool so long-video row JPEGs are not queued behind feed images.
  static final IOClient _longVideoThumbClient = IOClient(
    HttpClient()
      ..maxConnectionsPerHost = 8
      ..connectionTimeout = const Duration(seconds: 12),
  );

  static final CacheManager reelsThumbnails = CacheManager(
    Config(
      'vidconnect_reels_thumbs',
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 600,
    ),
  );

  /// Feed post thumbnails, avatars, and explore (Feature 2.8).
  static final CacheManager feedMedia = CacheManager(
    Config(
      'vidconnect_feed_media',
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 800,
      fileService: HttpFileService(httpClient: _feedImageClient),
    ),
  );

  /// Long Videos tab row thumbnails (isolated from feed eviction pressure).
  static final CacheManager longVideoThumbnails = CacheManager(
    Config(
      'vidconnect_longvideo_thumbs',
      stalePeriod: const Duration(days: 14),
      maxNrOfCacheObjects: 500,
      fileService: HttpFileService(httpClient: _longVideoThumbClient),
    ),
  );
}
