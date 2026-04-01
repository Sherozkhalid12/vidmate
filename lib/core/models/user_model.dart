/// User model
class UserModel {
  final String id;
  final String username;
  final String displayName;
  final String avatarUrl;
  final bool verified;
  final String? bio;
  final int followers;
  final int following;
  final int posts;
  final bool isFollowing;
  final bool isOnline;
  final bool privateAccount;
  final bool showActivityStatus;
  final bool allowComments;
  final bool allowLikes;
  final bool allowShares;
  final bool allowStoryReplies;

  UserModel({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    this.verified = false,
    this.bio,
    this.followers = 0,
    this.following = 0,
    this.posts = 0,
    this.isFollowing = false,
    this.isOnline = false,
    this.privateAccount = false,
    this.showActivityStatus = true,
    this.allowComments = true,
    this.allowLikes = true,
    this.allowShares = true,
    this.allowStoryReplies = true,
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
      verified: json['verified'] == true,
      bio: _stringFromJsonNullable(json['bio']),
      followers: _countFromJson(json['followers']),
      following: _countFromJson(json['following']),
      posts: _countFromJson(json['posts']),
      isFollowing: json['isFollowing'] == true,
      isOnline: json['isOnline'] == true,
      privateAccount: json['privateAccount'] == true,
      showActivityStatus: json['showActivityStatus'] != false,
      allowComments: json['allowComments'] != false,
      allowLikes: json['allowLikes'] != false,
      allowShares: json['allowShares'] != false,
      allowStoryReplies: json['allowStoryReplies'] != false,
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
      'verified': verified,
      'bio': bio,
      'followers': followers,
      'following': following,
      'posts': posts,
      'isFollowing': isFollowing,
      'isOnline': isOnline,
      'privateAccount': privateAccount,
      'showActivityStatus': showActivityStatus,
      'allowComments': allowComments,
      'allowLikes': allowLikes,
      'allowShares': allowShares,
      'allowStoryReplies': allowStoryReplies,
    };
  }
}

