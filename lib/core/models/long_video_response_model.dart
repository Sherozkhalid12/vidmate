/// Long video from API (max 20 min).
class LongVideoModelApi {
  final String id;
  final String userId;
  final String videoUrl;
  final String? thumbnailUrl;
  final String caption;
  final DateTime createdAt;
  /// User IDs who liked (from backend).
  final List<String> likes;
  /// Comment count from backend ('Comments' or 'comments').
  final int commentsCount;

  LongVideoModelApi({
    required this.id,
    required this.userId,
    required this.videoUrl,
    this.thumbnailUrl,
    this.caption = '',
    required this.createdAt,
    List<String>? likes,
    int? commentsCount,
  })  : likes = likes ?? const [],
        commentsCount = commentsCount ?? 0;

  static String _string(dynamic value) {
    if (value == null) return '';
    return value.toString();
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

  factory LongVideoModelApi.fromJson(Map<String, dynamic> json) {
    final video = _string(json['video'] ?? json['videoUrl'] ?? json['url']);
    final likesRaw = json['likes'];
    final likesList = likesRaw is List ? _stringList(likesRaw) : const <String>[];
    final commentsVal = json['Comments'] ?? json['comments'];
    final commentsCount = commentsVal is int
        ? commentsVal
        : (commentsVal is List ? (commentsVal as List).length : _int(commentsVal));
    return LongVideoModelApi(
      id: _string(json['_id'] ?? json['id']),
      userId: _string(json['userId'] ?? json['user']),
      videoUrl: video,
      thumbnailUrl: _string(json['thumbnailUrl'] ?? json['thumbnail'] ?? '').isEmpty
          ? null
          : _string(json['thumbnailUrl'] ?? json['thumbnail']),
      caption: _string(json['caption']),
      createdAt: _dateTime(json['createdAt']),
      likes: likesList,
      commentsCount: commentsCount,
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'userId': userId,
        'video': videoUrl,
        if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
        'caption': caption,
        'createdAt': createdAt.toIso8601String(),
      };
}

/// Long video from GET list with optional populated author.
class LongVideoWithUserModel {
  final LongVideoModelApi video;
  final LongVideoUserModel? user;

  LongVideoWithUserModel({required this.video, this.user});

  factory LongVideoWithUserModel.fromJson(Map<String, dynamic> json) {
    final video = LongVideoModelApi.fromJson(
      json is Map<String, dynamic> ? json : Map<String, dynamic>.from(json),
    );
    LongVideoUserModel? user;
    final userJson = json['user'];
    if (userJson != null && userJson is Map<String, dynamic>) {
      try {
        user = LongVideoUserModel.fromJson(userJson);
      } catch (_) {}
    }
    return LongVideoWithUserModel(video: video, user: user);
  }
}

/// User info for long video.
class LongVideoUserModel {
  final String id;
  final String username;
  final String displayName;
  final String avatarUrl;
  final bool verified;
  final bool privateAccount;
  final bool showActivityStatus;
  final bool allowComments;
  final bool allowLikes;
  final bool allowShares;
  final bool allowStoryReplies;

  LongVideoUserModel({
    required this.id,
    this.username = '',
    this.displayName = '',
    this.avatarUrl = '',
    this.verified = false,
    this.privateAccount = false,
    this.showActivityStatus = true,
    this.allowComments = true,
    this.allowLikes = true,
    this.allowShares = true,
    this.allowStoryReplies = true,
  });

  static String _string(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  factory LongVideoUserModel.fromJson(Map<String, dynamic> json) {
    return LongVideoUserModel(
      id: _string(json['_id'] ?? json['id']),
      username: _string(json['username'] ?? json['name']),
      displayName: _string(json['displayName'] ?? json['name'] ?? json['username']),
      avatarUrl: _string(json['avatarUrl'] ?? json['profilePicture'] ?? json['image']),
      verified: json['verified'] == true,
      privateAccount: json['privateAccount'] == true,
      showActivityStatus: json['showActivityStatus'] != false,
      allowComments: json['allowComments'] != false,
      allowLikes: json['allowLikes'] != false,
      allowShares: json['allowShares'] != false,
      allowStoryReplies: json['allowStoryReplies'] != false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        'verified': verified,
        'privateAccount': privateAccount,
        'showActivityStatus': showActivityStatus,
        'allowComments': allowComments,
        'allowLikes': allowLikes,
        'allowShares': allowShares,
        'allowStoryReplies': allowStoryReplies,
      };
}
