/// Single story segment (image or video) from API.
class StorySegmentModel {
  final String url;
  final String type; // 'image' | 'video'

  StorySegmentModel({required this.url, this.type = 'image'});

  bool get isVideo => type.toLowerCase() == 'video';

  static String _string(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  factory StorySegmentModel.fromJson(Map<String, dynamic> json) {
    return StorySegmentModel(
      url: _string(json['url'] ?? json['file'] ?? json['mediaUrl']),
      type: _string(json['type'] ?? json['mediaType'] ?? 'image').toLowerCase(),
    );
  }

  Map<String, dynamic> toJson() => {'url': url, 'type': type};
}

/// Story from API (one story = one or more segments).
class StoryModelApi {
  final String id;
  final String userId;
  final String caption;
  final List<String> locations;
  final List<String> taggedUsers;
  final List<String> feelings;
  final List<StorySegmentModel> segments;
  final DateTime createdAt;
  /// Optional preview URL used when creating the story (server may echo as `music`).
  final String music;
  final String musicName;
  final String musicTitle;

  StoryModelApi({
    required this.id,
    required this.userId,
    this.caption = '',
    this.locations = const [],
    this.taggedUsers = const [],
    this.feelings = const [],
    this.segments = const [],
    required this.createdAt,
    this.music = '',
    this.musicName = '',
    this.musicTitle = '',
  });

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

  static List<StorySegmentModel> _segmentList(dynamic value) {
    if (value == null || value is! List) return [];
    final list = <StorySegmentModel>[];
    for (final e in value) {
      if (e is Map<String, dynamic>) {
        list.add(StorySegmentModel.fromJson(e));
      } else if (e is String) {
        list.add(StorySegmentModel(url: e, type: 'image'));
      }
    }
    return list;
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

  factory StoryModelApi.fromJson(Map<String, dynamic> json) {
    final segmentsRaw = json['storySegments'] ?? json['segments'] ?? json['storyFiles'] ?? json['files'] ?? json['media'];
    final mn = _string(json['musicName'] ?? json['music_name'] ?? json['songName'] ?? json['trackTitle']);
    final mt = _string(json['musicTitle'] ?? json['music_title'] ?? json['artistName'] ?? json['artist']);
    return StoryModelApi(
      id: _string(json['_id'] ?? json['id']),
      userId: _string(json['userId'] ?? json['user']),
      caption: _string(json['caption']),
      locations: _stringList(json['locations']),
      taggedUsers: _stringList(json['taggedUsers']),
      feelings: _stringList(json['feelings']),
      segments: _segmentList(segmentsRaw),
      createdAt: _dateTime(json['createdAt']),
      music: _string(json['music'] ?? json['musicUrl'] ?? json['musicPreviewUrl']),
      musicName: mn,
      musicTitle: mt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'userId': userId,
      'caption': caption,
      'locations': locations,
      'taggedUsers': taggedUsers,
      'feelings': feelings,
      'segments': segments.map((s) => s.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      if (music.isNotEmpty) 'music': music,
      if (musicName.isNotEmpty) 'musicName': musicName,
      if (musicTitle.isNotEmpty) 'musicTitle': musicTitle,
    };
  }
}

/// Story from GET list API with optional populated user (StoryUserModel).
class StoryWithUserModel {
  final StoryModelApi story;
  final StoryUserModel? user;

  StoryWithUserModel({required this.story, this.user});

  factory StoryWithUserModel.fromJson(Map<String, dynamic> json) {
    final storyJson = json;
    final story = StoryModelApi.fromJson(
      storyJson is Map<String, dynamic>
          ? storyJson
          : Map<String, dynamic>.from(json),
    );
    StoryUserModel? user;
    final userJson = json['user'];
    if (userJson != null && userJson is Map<String, dynamic>) {
      try {
        user = StoryUserModel.fromJson(userJson);
      } catch (_) {}
    }
    return StoryWithUserModel(story: story, user: user);
  }
}

/// User info for story (lightweight or full).
class StoryUserModel {
  final String id;
  final String username;
  final String displayName;
  final String avatarUrl;

  StoryUserModel({
    required this.id,
    this.username = '',
    this.displayName = '',
    this.avatarUrl = '',
  });

  static String _string(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  factory StoryUserModel.fromJson(Map<String, dynamic> json) {
    return StoryUserModel(
      id: _string(json['_id'] ?? json['id']),
      username: _string(json['username'] ?? json['name']),
      displayName: _string(json['displayName'] ?? json['name'] ?? json['username']),
      avatarUrl: _string(json['avatarUrl'] ?? json['profilePicture'] ?? json['image']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
      };
}
