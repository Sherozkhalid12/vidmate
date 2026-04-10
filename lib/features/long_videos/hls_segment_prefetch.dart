import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Client-side HLS head prefetch for the **next** long video while the current one plays.
///
/// **Server / CDN expectations** (Feature 3.4 — document for backend):
/// - Master playlist exposes a sensible bitrate ladder (720p / 1080p variants).
/// - Media segments are typically **2s** (or shorter) for low live latency; coordinate with CDN.
/// - Segments and playlists should be served with cache-friendly `Cache-Control` and support byte-range where applicable.
///
/// This module resolves **real** segment URLs by fetching and parsing `.m3u8` playlists (no guessed paths).
/// Prefetched bytes are stored via [CacheManager] so repeated URL loads hit disk; ExoPlayer/BetterPlayer
/// may still maintain a separate native [SimpleCache] for the same URLs on Android.
class LongVideoHlsPrefetch {
  LongVideoHlsPrefetch._();

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 45),
      responseType: ResponseType.plain,
      validateStatus: (s) => s != null && s < 500,
    ),
  );

  static final CacheManager _cache = CacheManager(
    Config(
      'vidconnect_longvideo_hls_segments',
      stalePeriod: const Duration(days: 2),
      maxNrOfCacheObjects: 400,
    ),
  );

  /// In-flight guard: one prefetch per master URL at a time.
  static final Set<String> _inFlight = <String>{};

  /// Fetches master (if needed), media playlist, then downloads the first [maxSegments] media segment URLs.
  static Future<void> prefetchHeadSegments(
    String masterOrMediaUrl, {
    int maxSegments = 4,
    CancelToken? cancelToken,
  }) async {
    if (masterOrMediaUrl.isEmpty) return;
    final u = masterOrMediaUrl.toLowerCase();
    if (!u.contains('.m3u8')) return;

    if (_inFlight.contains(masterOrMediaUrl)) return;
    _inFlight.add(masterOrMediaUrl);
    try {
      String body = await _fetchText(masterOrMediaUrl, cancelToken: cancelToken);
      if (body.isEmpty) return;

      String mediaPlaylistUrl;
      String mediaBody;

      if (body.contains('#EXT-X-STREAM-INF')) {
        final variant = _pickFirstVariantUrl(body, masterOrMediaUrl);
        if (variant == null) return;
        mediaPlaylistUrl = variant;
        mediaBody = await _fetchText(variant, cancelToken: cancelToken);
      } else {
        mediaPlaylistUrl = masterOrMediaUrl;
        mediaBody = body;
      }

      if (mediaBody.isEmpty) return;

      final segmentUrls = _segmentUrlsFromMediaPlaylist(mediaBody, mediaPlaylistUrl, maxSegments);
      for (final seg in segmentUrls) {
        if (cancelToken?.isCancelled == true) return;
        try {
          await _cache.getSingleFile(seg);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[LongVideoHlsPrefetch] segment cache miss/err: $e');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[LongVideoHlsPrefetch] failed: $e');
      }
    } finally {
      _inFlight.remove(masterOrMediaUrl);
    }
  }

  static Future<String> _fetchText(String url, {CancelToken? cancelToken}) async {
    final res = await _dio.get<String>(url, cancelToken: cancelToken);
    if (res.statusCode != 200 || res.data == null) return '';
    return res.data!;
  }

  static String? _pickFirstVariantUrl(String masterBody, String masterUrl) {
    final lines = masterBody.split('\n');
    String? nextUri;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.startsWith('#EXT-X-STREAM-INF')) {
        if (i + 1 < lines.length) {
          final candidate = lines[i + 1].trim();
          if (candidate.isNotEmpty && !candidate.startsWith('#')) {
            nextUri = candidate;
            break;
          }
        }
      }
    }
    if (nextUri == null) {
      for (final line in lines) {
        final t = line.trim();
        if (t.isEmpty || t.startsWith('#')) continue;
        if (t.contains('.m3u8')) {
          nextUri = t;
          break;
        }
      }
    }
    if (nextUri == null) return null;
    return _resolveUrl(masterUrl, nextUri);
  }

  static List<String> _segmentUrlsFromMediaPlaylist(
    String mediaBody,
    String mediaPlaylistUrl,
    int max,
  ) {
    final out = <String>[];
    for (final raw in mediaBody.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      if (line.endsWith('.m3u8')) continue;
      final absolute = _resolveUrl(mediaPlaylistUrl, line);
      out.add(absolute);
      if (out.length >= max) break;
    }
    return out;
  }

  static String _resolveUrl(String base, String ref) {
    if (ref.startsWith('http://') || ref.startsWith('https://')) return ref;
    final baseUri = Uri.parse(base);
    return baseUri.resolve(ref).toString();
  }
}
