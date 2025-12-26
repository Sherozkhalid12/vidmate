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

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? json['_id'] ?? '',
      username: json['username'] ?? '',
      displayName: json['displayName'] ?? json['name'] ?? '',
      avatarUrl: json['avatarUrl'] ?? json['profilePicture'] ?? '',
      bio: json['bio'],
      followers: json['followers'] ?? 0,
      following: json['following'] ?? 0,
      posts: json['posts'] ?? 0,
      isFollowing: json['isFollowing'] ?? false,
      isOnline: json['isOnline'] ?? false,
    );
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

