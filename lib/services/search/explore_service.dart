import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/dio_client.dart';
import '../../core/constants/api_constants.dart';
import '../../core/models/post_model.dart';
import '../../core/models/user_model.dart';
import '../../core/utils/explore_search_response_parse.dart';

class ExploreSearchResult {
  final String searchText;
  final Map<String, int> counts;
  final List<UserModel> users;
  final List<PostModel> posts;
  final List<PostModel> reels;
  final List<PostModel> longVideos;

  const ExploreSearchResult({
    required this.searchText,
    required this.counts,
    required this.users,
    required this.posts,
    required this.reels,
    required this.longVideos,
  });
}

class ExploreService {
  static const String _tokenKey = 'auth_token';
  static const int _computeParseThreshold = 20;
  final Dio _dio = DioClient.instance;

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static int _rawListItemCount(Map<String, dynamic> map) {
    var n = 0;
    for (final k in ['users', 'posts', 'reels', 'longVideos']) {
      final v = map[k];
      if (v is List) n += v.length;
    }
    return n;
  }

  Future<ExploreSearchResult> search({
    required String text,
    int userLimit = 20,
    int postLimit = 20,
    int reelLimit = 20,
    int longVideoLimit = 20,
    String? currentUserId,
    CancelToken? cancelToken,
  }) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated');
    }
    final query = text.trim();
    if (query.isEmpty) {
      throw Exception('Search text required');
    }

    DioClient.setAuthToken(token);
    final body = {
      'text': query,
      'userLimit': userLimit.clamp(1, 100),
      'postLimit': postLimit.clamp(1, 100),
      'reelLimit': reelLimit.clamp(1, 100),
      'longVideoLimit': longVideoLimit.clamp(1, 100),
    };

    try {
      final res = await _dio.post(
        ApiConstants.search,
        data: body,
        options: Options(contentType: Headers.jsonContentType),
        cancelToken: cancelToken,
      );
      final root = res.data;
      if (root is! Map) {
        throw Exception('Invalid search response');
      }
      final rawMap = Map<String, dynamic>.from(root);
      final encoded = jsonEncode(rawMap);

      final Map<String, dynamic> norm = _rawListItemCount(rawMap) >=
              _computeParseThreshold
          ? await compute(parseExploreSearchResponseJson, encoded)
          : parseExploreSearchResponseJson(encoded);

      if (norm['success'] != true) {
        final msg = norm['message']?.toString() ??
            norm['error']?.toString() ??
            'Failed to search data';
        throw Exception(msg);
      }

      final countsRaw = norm['counts'] is Map
          ? Map<String, dynamic>.from(norm['counts'] as Map)
          : <String, dynamic>{};
      final counts = {
        'users': _int(countsRaw['users']),
        'posts': _int(countsRaw['posts']),
        'reels': _int(countsRaw['reels']),
        'longVideos': _int(countsRaw['longVideos']),
      };

      final users = _usersFromMaps(_asMapList(norm['users']));
      final posts = _postsFromMaps(_asMapList(norm['posts']), currentUserId);
      final reels = _postsFromMaps(_asMapList(norm['reels']), currentUserId);
      final longVideos =
          _postsFromMaps(_asMapList(norm['longVideos']), currentUserId);

      return ExploreSearchResult(
        searchText: norm['searchText']?.toString() ?? query,
        counts: counts,
        users: users,
        posts: posts,
        reels: reels,
        longVideos: longVideos,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        rethrow;
      }
      final d = e.response?.data;
      final msg = d is Map
          ? (d['message'] ?? d['error'] ?? e.message).toString()
          : (e.message ?? 'Request failed');
      throw Exception(msg);
    }
  }

  static List<Map<String, dynamic>> _asMapList(dynamic v) {
    if (v is! List) return const [];
    final out = <Map<String, dynamic>>[];
    for (final e in v) {
      if (e is Map<String, dynamic>) {
        out.add(e);
      } else if (e is Map) {
        out.add(Map<String, dynamic>.from(e));
      }
    }
    return out;
  }

  static int _int(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }

  static String _str(dynamic v) => v?.toString() ?? '';

  static List<String> _strListFromValue(dynamic v) {
    if (v is! List) return const [];
    return v
        .map((e) => e?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static DateTime _date(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString()) ?? DateTime.now();
  }

  static List<UserModel> _usersFromMaps(List<Map<String, dynamic>> raw) {
    return raw.map(UserModel.fromJson).toList();
  }

  static List<PostModel> _postsFromMaps(
    List<Map<String, dynamic>> raw,
    String? currentUserId,
  ) {
    return raw.map((json) {
      final userJson = json['user'] is Map
          ? Map<String, dynamic>.from(json['user'] as Map)
          : null;
      final author = userJson != null
          ? UserModel.fromJson(userJson)
          : PostModel.authorPlaceholder(_str(json['userId']));

      final images = _strListFromValue(json['images']);
      final video = _str(json['video']);
      final thumbnail = _str(json['thumbnail']);
      final likes = _strListFromValue(json['likes']);
      final commentsVal = json['Comments'] ?? json['comments'];
      final commentsCount = commentsVal is int
          ? commentsVal
          : (commentsVal is List ? commentsVal.length : _int(commentsVal));
      final type = _str(json['type']).isEmpty ? 'post' : _str(json['type']);

      return PostModel(
        id: _str(json['_id'] ?? json['id']),
        author: author,
        imageUrl: images.isNotEmpty ? images.first : null,
        imageUrls: images,
        videoUrl: video.isNotEmpty ? video : null,
        thumbnailUrl: thumbnail.isNotEmpty ? thumbnail : null,
        caption: _str(json['caption']),
        createdAt: _date(json['createdAt']),
        likes: likes.length,
        comments: commentsCount,
        shares: _int(json['shares']),
        isLiked: currentUserId != null && likes.contains(currentUserId),
        isVideo: video.isNotEmpty,
        postType: type,
      );
    }).toList();
  }
}
