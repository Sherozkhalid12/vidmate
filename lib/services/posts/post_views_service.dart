import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/dio_client.dart';
import '../../core/constants/api_constants.dart';

/// Records and caches post view counts via `POST /post/:id/view` (Dio).
class PostViewsService {
  static const _recordedSessionKey = 'post_views_recorded_session';

  final Dio _dio = DioClient.instance;

  static int parseViewsFromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return 0;
    final raw = json['views'] ??
        json['viewCount'] ??
        json['viewsCount'] ??
        json['Views'] ??
        json['count'];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  /// Returns cached view count for [postId], or null if unknown.
  Future<int?> getCachedViewCount(String postId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('post_views_$postId');
  }

  Future<void> _cacheViewCount(String postId, int count) async {
    if (count <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('post_views_$postId', count);
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null || token.isEmpty) return null;
    return token;
  }

  /// Records one view per app session per post (deduped in prefs).
  /// Returns the authoritative view count from the API when available.
  Future<int?> recordView(String postId, {int baseline = 0}) async {
    final id = postId.trim();
    if (id.isEmpty) return null;

    await ensureSessionScope();
    final prefs = await SharedPreferences.getInstance();
    final sessionKey = prefs.getString(_recordedSessionKey) ?? '';
    final dedupeKey = 'post_view_sent_${sessionKey}_$id';
    if (prefs.getBool(dedupeKey) == true) {
      final cached = await getCachedViewCount(id);
      if (cached != null && cached > 0) return cached;
      return baseline > 0 ? baseline : null;
    }

    final token = await _getToken();
    if (token == null || token.isEmpty) return null;

    try {
      DioClient.setAuthToken(token);
      final count = await _postViewWithFallback(id, baseline: baseline);
      if (count != null && count > 0) {
        await _cacheViewCount(id, count);
        await prefs.setBool(dedupeKey, true);
        return count;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[PostViews] error postId=$id $e');
    }

    return getCachedViewCount(id);
  }

  Future<int?> _postViewWithFallback(String id, {required int baseline}) async {
    final endpoints = <String>[
      ApiConstants.postMarkView(id),
      '/videos/$id/views',
    ];

    for (final path in endpoints) {
      try {
        final response = await _dio.post(path);
        final status = response.statusCode ?? 0;
        if (status < 200 || status >= 300) continue;

        final data = response.data;
        if (data is! Map<String, dynamic>) {
          // 2xx with empty body — treat as success and bump locally.
          return _bumpFromBaseline(id, baseline);
        }

        final explicitFailure = data['success'] == false ||
            data['status'] == 'error' ||
            data['error'] != null && data['success'] != true;
        if (explicitFailure) {
          if (kDebugMode) {
            debugPrint(
              '[PostViews] record failed postId=$id path=$path msg=${data['message'] ?? data['error']}',
            );
          }
          continue;
        }

        int? count;
        for (final key in ['post', 'reel', 'video', 'data']) {
          final nested = data[key];
          if (nested is Map<String, dynamic>) {
            count = parseViewsFromJson(nested);
            if (count != null && count > 0) break;
          }
        }
        count ??= parseViewsFromJson(data);
        if (count != null && count > 0) return count;

        // API returns viewCount at top level for POST /post/:id/view
        final topLevel = data['viewCount'];
        if (topLevel is int && topLevel > 0) return topLevel;
        final parsedTop = int.tryParse(topLevel?.toString() ?? '');
        if (parsedTop != null && parsedTop > 0) return parsedTop;

        return _bumpFromBaseline(id, baseline);
      } on DioException catch (e) {
        if (kDebugMode) {
          debugPrint(
            '[PostViews] Dio error postId=$id path=$path status=${e.response?.statusCode}',
          );
        }
        if (e.response?.statusCode == 404) continue;
      }
    }
    return null;
  }

  Future<int> _bumpFromBaseline(String id, int baseline) async {
    final cached = await getCachedViewCount(id);
    final base = _maxPositive(baseline, cached) ?? 0;
    return base > 0 ? base + 1 : 1;
  }

  int? _maxPositive(int? a, int? b) {
    final values = [a, b].whereType<int>().where((v) => v > 0);
    if (values.isEmpty) return null;
    return values.reduce((x, y) => x > y ? x : y);
  }

  /// Call once per app cold start to scope session dedupe keys.
  static Future<void> ensureSessionScope() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_recordedSessionKey)) return;
    await prefs.setString(
      _recordedSessionKey,
      DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }
}
