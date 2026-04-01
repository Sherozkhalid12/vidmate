/// Comment on a post (API response shape).
class PostComment {
  final String id;
  final String postId;
  final String userId;
  final String content;
  final String username;
  final String profilePicture;
  final List<String> likes;
  final DateTime createdAt;
  final DateTime updatedAt;

  PostComment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.content,
    required this.username,
    required this.profilePicture,
    List<String>? likes,
    required this.createdAt,
    required this.updatedAt,
  }) : likes = likes ?? const [];

  static String _str(dynamic v) => v?.toString() ?? '';

  static DateTime _date(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is DateTime) return v;
    try {
      return DateTime.parse(v.toString());
    } catch (_) {
      return DateTime.now();
    }
  }

  static List<String> _strList(dynamic v) {
    if (v == null || v is! List) return [];
    return v.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
  }

  factory PostComment.fromJson(Map<String, dynamic> json) {
    return PostComment(
      id: _str(json['_id'] ?? json['id']),
      postId: _str(json['postId']),
      userId: _str(json['userId']),
      content: _str(json['content']),
      username: _str(json['username']),
      profilePicture: _str(json['profilePicture']),
      likes: _strList(json['likes']),
      createdAt: _date(json['createdAt']),
      updatedAt: _date(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'postId': postId,
      'userId': userId,
      'content': content,
      'username': username,
      'profilePicture': profilePicture,
      'likes': likes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
