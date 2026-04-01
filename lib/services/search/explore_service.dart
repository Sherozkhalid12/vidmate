import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/dio_client.dart';
import '../../core/constants/api_constants.dart';
import '../../core/models/post_model.dart';
import '../../core/models/user_model.dart';

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
  final Dio _dio = DioClient.instance;

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<ExploreSearchResult> search({
    required String text,
    int userLimit = 20,
    int postLimit = 20,
    int reelLimit = 20,
    int longVideoLimit = 20,
    String? currentUserId,
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
      );
      final map = res.data as Map<String, dynamic>?;
      if (map == null || map['success'] != true) {
        final msg = map?['message']?.toString() ??
            map?['error']?.toString() ??
            'Failed to search data';
        throw Exception(msg);
      }

      final countsRaw = map['counts'] is Map
          ? Map<String, dynamic>.from(map['counts'] as Map)
          : <String, dynamic>{};
      final counts = {
        'users': _int(countsRaw['users']),
        'posts': _int(countsRaw['posts']),
        'reels': _int(countsRaw['reels']),
        'longVideos': _int(countsRaw['longVideos']),
      };

      final users = _usersFromList(map['users']);
      final posts = _postsFromList(map['posts'], currentUserId);
      final reels = _postsFromList(map['reels'], currentUserId);
      final longVideos = _postsFromList(map['longVideos'], currentUserId);

      return ExploreSearchResult(
        searchText: map['searchText']?.toString() ?? query,
        counts: counts,
        users: users,
        posts: posts,
        reels: reels,
        longVideos: longVideos,
      );
    } on DioException catch (e) {
      final d = e.response?.data;
      final msg = d is Map
          ? (d['message'] ?? d['error'] ?? e.message).toString()
          : (e.message ?? 'Request failed');
      throw Exception(msg);
    }
  }

  static int _int(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }

  static String _str(dynamic v) => v?.toString() ?? '';

  static List<String> _strList(dynamic v) {
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

  static List<UserModel> _usersFromList(dynamic v) {
    if (v is! List) return const [];
    return v.whereType<Map>().map((raw) {
      return UserModel.fromJson(Map<String, dynamic>.from(raw));
    }).toList();
  }

  static List<PostModel> _postsFromList(dynamic v, String? currentUserId) {
    if (v is! List) return const [];
    return v.whereType<Map>().map((raw) {
      final json = Map<String, dynamic>.from(raw);
      final userJson = json['user'] is Map
          ? Map<String, dynamic>.from(json['user'] as Map)
          : null;
      final author = userJson != null
          ? UserModel.fromJson(userJson)
          : PostModel.authorPlaceholder(_str(json['userId']));

      final images = _strList(json['images']);
      final video = _str(json['video']);
      final thumbnail = _str(json['thumbnail']);
      final likes = _strList(json['likes']);
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
