import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Progressive prefetch: first ~20–30% (capped), then completes the file in the
/// background. [getCachedFile] returns a path only when the download is **fully**
/// complete — incomplete files are never passed to ExoPlayer (avoids decode errors).
class ReelVideoPrefetchService {
  ReelVideoPrefetchService._();
  static final ReelVideoPrefetchService instance = ReelVideoPrefetchService._();

  static const int maxConcurrent = 1;
  static const int initialMaxBytes = 4 * 1024 * 1024;
  static const double initialFraction = 0.28;
  static const int appendChunkBytes = 2 * 1024 * 1024;

  final Dio _dio = Dio();
  int _active = 0;
  final Map<String, CancelToken> _tokens = {};
  final Map<String, Future<void>> _futures = {};

  bool wifiOnly = true;

  bool _isHls(String url) {
    final u = url.toLowerCase();
    return u.contains('.m3u8') || u.contains('.mpd');
  }

  /// Starts progressive download (initial segment first, remainder in background).
  Future<void> prefetchIfAllowed(String url) async {
    if (url.isEmpty || _isHls(url)) return;
    if (_futures.containsKey(url)) return;

    if (wifiOnly) {
      final results = await Connectivity().checkConnectivity();
      final ok = results.any((r) => r == ConnectivityResult.wifi || r == ConnectivityResult.ethernet);
      if (!ok) return;
    }

    while (_active >= maxConcurrent) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }

    final job = _progressiveDownload(url);
    _futures[url] = job;
    try {
      await job;
    } finally {
      _futures.remove(url);
    }
  }

  Future<void> _progressiveDownload(String url) async {
    _active++;
    final token = CancelToken();
    _tokens[url] = token;
    File? partial;
    try {
      final out = await _fileForUrl(url);
      partial = File('${out.path}.partial');

      if (await out.exists() && await out.length() > 0) {
        return;
      }
      if (await partial.exists()) {
        await partial.delete();
      }

      int? total;
      try {
        final head = await _dio.headUri(Uri.parse(url), cancelToken: token);
        final cl = head.headers.value(HttpHeaders.contentLengthHeader);
        if (cl != null) total = int.tryParse(cl);
      } catch (_) {}

      final firstByteEnd = _firstSegmentLastByteIndex(total);
      await _dio.download(
        url,
        partial.path,
        cancelToken: token,
        deleteOnError: true,
        options: Options(
          headers: {HttpHeaders.rangeHeader: 'bytes=0-$firstByteEnd'},
          validateStatus: (s) => s == 200 || s == 206,
        ),
      );

      if (token.isCancelled) return;

      var written = await partial.length();
      if (total != null && written >= total) {
        await _finalizePartial(url, partial, out);
        return;
      }

      if (total == null) {
        await _appendUnknownTotalTail(url, partial, written, token);
      } else {
        await _appendRemainder(url, partial, written, total, token);
      }
      if (token.isCancelled) {
        await _safeDelete(partial);
        return;
      }

      written = await partial.length();
      if (total != null && written < total) {
        if (kDebugMode) {
          debugPrint('[ReelPrefetch] short file $written < $total for $url');
        }
        await _safeDelete(partial);
        return;
      }

      await _finalizePartial(url, partial, out);
    } catch (e) {
      if (kDebugMode && e is! DioException) {
        debugPrint('[ReelPrefetch] $e');
      }
      if (partial != null) await _safeDelete(partial);
    } finally {
      _tokens.remove(url);
      _active--;
    }
  }

  int _firstSegmentLastByteIndex(int? total) {
    if (total == null || total <= 0) {
      return initialMaxBytes - 1;
    }
    final fromFraction = (total * initialFraction).round();
    final want = math.max(fromFraction, math.min(256 * 1024, total));
    final capped = math.min(want, initialMaxBytes);
    return math.min(capped, total) - 1;
  }

  /// When Content-Length was missing, fetch the rest in one ranged request (or accept 416 = already complete).
  Future<void> _appendUnknownTotalTail(
    String url,
    File partial,
    int startOffset,
    CancelToken token,
  ) async {
    if (token.isCancelled) return;
    final resp = await _dio.get<List<int>>(
      url,
      cancelToken: token,
      options: Options(
        responseType: ResponseType.bytes,
        headers: {HttpHeaders.rangeHeader: 'bytes=$startOffset-'},
        validateStatus: (s) => s == 200 || s == 206 || s == 416,
      ),
    );
    if (resp.statusCode == 416) return;
    final data = resp.data;
    if (data == null || data.isEmpty) return;
    final raf = await partial.open(mode: FileMode.append);
    try {
      await raf.writeFrom(data);
    } finally {
      await raf.close();
    }
  }

  Future<void> _appendRemainder(
    String url,
    File partial,
    int startOffset,
    int total,
    CancelToken token,
  ) async {
    var offset = startOffset;
    final raf = await partial.open(mode: FileMode.append);
    try {
      while (!token.isCancelled && offset < total) {
        final end = math.min(offset + appendChunkBytes - 1, total - 1);
        final resp = await _dio.get<List<int>>(
          url,
          cancelToken: token,
          options: Options(
            responseType: ResponseType.bytes,
            headers: {HttpHeaders.rangeHeader: 'bytes=$offset-$end'},
            validateStatus: (s) => s == 200 || s == 206,
          ),
        );
        final data = resp.data;
        if (data == null || data.isEmpty) break;
        await raf.writeFrom(data);
        offset += data.length;
      }
    } finally {
      await raf.close();
    }
  }

  Future<void> _finalizePartial(String url, File partial, File out) async {
    try {
      if (await out.exists()) await out.delete();
    } catch (_) {}
    try {
      await partial.rename(out.path);
    } catch (_) {
      try {
        await partial.copy(out.path);
        await partial.delete();
      } catch (_) {}
    }
  }

  Future<void> _safeDelete(File? f) async {
    if (f == null) return;
    try {
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  void cancel(String url) {
    final hadActive = _tokens.containsKey(url);
    _tokens[url]?.cancel();
    _tokens.remove(url);
    if (hadActive) {
      unawaited(_deletePartialOnly(url));
    }
  }

  Future<void> _deletePartialOnly(String url) async {
    try {
      final out = await _fileForUrl(url);
      final p = File('${out.path}.partial');
      if (await p.exists()) await p.delete();
    } catch (_) {}
  }

  Future<File> _fileForUrl(String url) async {
    final dir = await getTemporaryDirectory();
    final folder = Directory('${dir.path}/reel_prefetch');
    if (!await folder.exists()) await folder.create(recursive: true);
    return File('${folder.path}/${url.hashCode.abs()}.mp4');
  }

  /// Final `.mp4` only (never while `.partial` exists — avoids feeding ExoPlayer an incomplete file).
  Future<File?> getCachedFile(String url) async {
    if (url.isEmpty || _isHls(url)) return null;
    try {
      final f = await _fileForUrl(url);
      final part = File('${f.path}.partial');
      if (await part.exists()) return null;
      if (await f.exists() && await f.length() > 0) return f;
    } catch (_) {}
    return null;
  }

  /// Partial file on disk (for thumbnail / probing). May be absent or incomplete.
  Future<File?> getPartialFileIfAny(String url) async {
    if (url.isEmpty || _isHls(url)) return null;
    try {
      final out = await _fileForUrl(url);
      final p = File('${out.path}.partial');
      if (await p.exists() && await p.length() > 0) return p;
    } catch (_) {}
    return null;
  }

  void cancelAll() {
    for (final t in _tokens.values) {
      t.cancel();
    }
    _tokens.clear();
  }
}
