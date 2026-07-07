import 'story_viewer_model.dart';

/// Single story segment (image or video) from API.
class StorySegmentModel {
  final String url;
  final String type; // 'image' | 'video'
  final String? thumbnailUrl;

  StorySegmentModel({
    required this.url,
    this.type = 'image',
    this.thumbnailUrl,
  });

  bool get isVideo => type.toLowerCase() == 'video';

  static String _string(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  factory StorySegmentModel.fromJson(Map<String, dynamic> json) {
    final thumb = _string(
      json['thumbnail'] ??
          json['thumbnailUrl'] ??
          json['thumb'] ??
          json['poster'],
    );
    return StorySegmentModel(
      url: _string(json['url'] ?? json['file'] ?? json['mediaUrl']),
      type: _string(json['type'] ?? json['mediaType'] ?? 'image').toLowerCase(),
      thumbnailUrl: thumb.isNotEmpty ? thumb : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        'type': type,
        if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty)
          'thumbnailUrl': thumbnailUrl,
      };
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
  /// Playable preview URL (fresh per fetch) or legacy string.
  final String music;
  final String musicName;
  final String musicTitle;
  final String musicTrackId;
  final String musicSource;
  final int viewCount;
  final bool hasViewed;
  final List<String> viewedBy;
  final List<StoryViewerModel> viewers;

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
    this.musicTrackId = '',
    this.musicSource = '',
    this.viewCount = 0,
    this.hasViewed = false,
    this.viewedBy = const [],
    this.viewers = const [],
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

  static int _int(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }

  static bool _bool(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    final s = v.toString().toLowerCase();
    return s == 'true' || s == '1';
  }

  static List<StoryViewerModel> _viewersList(dynamic value) {
    if (value is! List) return const [];
    final out = <StoryViewerModel>[];
    for (final e in value) {
      if (e is Map<String, dynamic>) {
        out.add(StoryViewerModel.fromJson(e));
      } else if (e is Map) {
        out.add(StoryViewerModel.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    return out;
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
    final musicField =
        _string(json['music'] ?? json['musicUrl'] ?? json['musicPreviewUrl']);
    final musicLooksUrl =
        musicField.startsWith('http://') || musicField.startsWith('https://');
    final trackIdField = _string(json['musicTrackId']);
    final resolvedTrackId = trackIdField.isNotEmpty
        ? trackIdField
        : (!musicLooksUrl && musicField.isNotEmpty ? musicField : '');

    Map<String, dynamic>? details;
    final md = json['musicDetails'];
    if (md is Map<String, dynamic>) {
      details = md;
    } else if (md is Map) {
      details = Map<String, dynamic>.from(md);
    }

    var mn = _string(json['musicName'] ??
        json['music_name'] ??
        json['songName'] ??
        json['trackTitle']);
    var mt = _string(json['musicTitle'] ??
        json['music_title'] ??
        json['artistName'] ??
        json['artist']);
    if (details != null) {
      if (mn.isEmpty) {
        mn = _string(details['title'] ?? details['name']);
      }
      if (mt.isEmpty) {
        mt = _string(details['artistName'] ?? details['artist']);
      }
    }

    return StoryModelApi(
      id: _string(json['_id'] ?? json['id']),
      userId: _string(json['userId'] ?? json['user']),
      caption: _string(json['caption']),
      locations: _stringList(json['locations']),
      taggedUsers: _stringList(json['taggedUsers']),
      feelings: _stringList(json['feelings']),
      segments: _segmentList(segmentsRaw),
      createdAt: _dateTime(json['createdAt']),
      music: musicLooksUrl ? musicField : '',
      musicName: mn,
      musicTitle: mt,
      musicTrackId: resolvedTrackId,
      musicSource: _string(json['musicSource']),
      viewCount: _int(json['viewCount']),
      hasViewed: _bool(json['hasViewed']),
      viewedBy: _stringList(json['viewedBy']),
      viewers: _viewersList(json['viewers']),
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
      if (musicTrackId.isNotEmpty) 'musicTrackId': musicTrackId,
      if (musicSource.isNotEmpty) 'musicSource': musicSource,
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
