import 'user_model.dart';

/// API response model for create post. Matches server response structure.
class CreatePostResponse {
  final bool success;
  final String? message;
  final ApiPost? post;

  CreatePostResponse({
    required this.success,
    this.message,
    this.post,
  });

  factory CreatePostResponse.fromJson(Map<String, dynamic> json) {
    ApiPost? postData;
    final postJson = json['post'];
    if (postJson != null && postJson is Map<String, dynamic>) {
      postData = ApiPost.fromJson(postJson);
    }
    return CreatePostResponse(
      success: json['success'] == true,
      message: json['message'] as String?,
      post: postData,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      if (message != null) 'message': message,
      if (post != null) 'post': post!.toJson(),
    };
  }
}

/// Inner post object from create post API. Reusable for feed and other features.
class ApiPost {
  final String userId;
  final List<String> images;
  final String video;
  final String caption;
  final List<String> locations;
  final List<String> taggedUsers;
  final List<String> feelings;
  final String id;
  final DateTime createdAt;
  final int? version;
  /// Content type: 'post' | 'reel' | 'longVideo' | 'story'
  final String type;
  /// User IDs who liked (from backend). Used for count and isLiked.
  final List<String> likes;
  /// Comment count from backend (API may send 'Comments' or 'comments').
  final int commentsCount;

  ApiPost({
    required this.userId,
    required this.images,
    required this.video,
    required this.caption,
    required this.locations,
    required this.taggedUsers,
    required this.feelings,
    required this.id,
    required this.createdAt,
    this.version,
    this.type = 'post',
    List<String>? likes,
    int? commentsCount,
  })  : likes = likes ?? const [],
        commentsCount = commentsCount ?? 0;

  static String _string(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  static List<String> _stringList(dynamic value) {
    if (value == null || value is! List) return [];
    return value
        .map((e) => e == null ? '' : e.toString())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static int _int(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  static DateTime _dateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    try {
      return DateTime.parse(value.toString());
    } catch (_) {
      return DateTime.now();
    }
  }

  factory ApiPost.fromJson(Map<String, dynamic> json) {
    final typeRaw = _string(json['type']).toLowerCase();
    final type = typeRaw.isEmpty ? 'post' : typeRaw;
    final likesRaw = json['likes'];
    final likesList = likesRaw is List ? _stringList(likesRaw) : const <String>[];
    final commentsVal = json['Comments'] ?? json['comments'];
    final commentsCount = commentsVal is int
        ? commentsVal
        : (commentsVal is List ? (commentsVal as List).length : _int(commentsVal));
    return ApiPost(
      userId: _string(json['userId']),
      images: _stringList(json['images']),
      video: _string(json['video']),
      caption: _string(json['caption']),
      locations: _stringList(json['locations']),
      taggedUsers: _stringList(json['taggedUsers']),
      feelings: _stringList(json['feelings']),
      id: _string(json['_id'] ?? json['id']),
      createdAt: _dateTime(json['createdAt']),
      version: json['__v'] is int ? json['__v'] as int : null,
      type: type,
      likes: likesList,
      commentsCount: commentsCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'images': images,
      'video': video,
      'caption': caption,
      'locations': locations,
      'taggedUsers': taggedUsers,
      'feelings': feelings,
      '_id': id,
      'createdAt': createdAt.toIso8601String(),
      if (version != null) '__v': version,
      'type': type,
      'likes': likes,
      'comments': commentsCount,
    };
  }
}

/// Post from GET list API, with optional populated author.
class ApiPostWithAuthor {
  final ApiPost post;
  final UserModel? author;

  ApiPostWithAuthor({required this.post, this.author});

  static ApiPostWithAuthor fromJson(Map<String, dynamic> json) {
    final post = ApiPost.fromJson(json);
    final userJson = json['user'];
    UserModel? author;
    if (userJson != null && userJson is Map<String, dynamic>) {
      try {
        author = UserModel.fromJson(userJson);
      } catch (_) {}
    }
    return ApiPostWithAuthor(post: post, author: author);
  }
}
