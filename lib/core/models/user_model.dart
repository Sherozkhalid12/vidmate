/// User model
class UserModel {
  final String id;
  final String username;
  final String displayName;
  final String avatarUrl;
  final String? bio;
  final int followers;
  final int following;
  final int posts;
  final bool isFollowing;
  final bool isOnline;

  UserModel({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    this.bio,
    this.followers = 0,
    this.following = 0,
    this.posts = 0,
    this.isFollowing = false,
    this.isOnline = false,
  });

  /// Safely parse count from JSON (API may return int or list).
  static int _countFromJson(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is List) return value.length;
    return 0;
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: _stringFromJson(json['id'] ?? json['_id']),
      username: _stringFromJson(json['username'] ?? json['name'] ?? ''),
      displayName: _stringFromJson(
          json['displayName'] ?? json['name'] ?? json['username'] ?? ''),
      avatarUrl: _stringFromJson(
          json['avatarUrl'] ?? json['profilePicture'] ?? json['image'] ?? ''),
      bio: _stringFromJsonNullable(json['bio']),
      followers: _countFromJson(json['followers']),
      following: _countFromJson(json['following']),
      posts: _countFromJson(json['posts']),
      isFollowing: json['isFollowing'] == true,
      isOnline: json['isOnline'] == true,
    );
  }

  static String _stringFromJson(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  static String? _stringFromJsonNullable(dynamic value) {
    if (value == null) return null;
    final s = value.toString();
    return s.isEmpty ? null : s;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'bio': bio,
      'followers': followers,
      'following': following,
      'posts': posts,
      'isFollowing': isFollowing,
      'isOnline': isOnline,
    };
  }
}

