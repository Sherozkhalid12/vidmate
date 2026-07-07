import 'post_model.dart';

/// Reel from API.
class ReelModelApi {
  final String id;
  final String userId;
  final String videoUrl; // HLS or direct URL
  final String? thumbnailUrl;
  /// Optional BlurHash / ThumbHash from API for instant placeholder.
  final String? blurHash;
  final String caption;
  final List<String> locations;
  final List<String> taggedUsers;
  final List<String> feelings;
  final DateTime createdAt;
  /// User IDs who liked (from backend). Count = length; isLiked = contains(currentUserId).
  final List<String> likes;
  /// Comment count from backend ('Comments' or 'comments').
  final int commentsCount;
  final int views;
  /// External music URL or legacy `music` field.
  final String? musicUrl;
  final String? musicTitle;
  final String? musicArtist;
  final String? musicName;
  final bool? isOriginalSound;
  final String? musicSource;
  final int? soundtrackDurationMs;

  ReelModelApi({
    required this.id,
    required this.userId,
    required this.videoUrl,
    this.thumbnailUrl,
    this.blurHash,
    this.caption = '',
    this.locations = const [],
    this.taggedUsers = const [],
    this.feelings = const [],
    required this.createdAt,
    List<String>? likes,
    int? commentsCount,
    int? views,
    this.musicUrl,
    this.musicTitle,
    this.musicArtist,
    this.musicName,
    this.isOriginalSound,
    this.musicSource,
    this.soundtrackDurationMs,
  })  : likes = likes ?? const [],
        commentsCount = commentsCount ?? 0,
        views = views ?? 0;

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

  static DateTime _dateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    try {
      return DateTime.parse(value.toString());
    } catch (_) {
      return DateTime.now();
    }
  }

  static int _int(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  static Map<String, dynamic>? _nestedMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  /// Display line for reel audio chip (library track or original sound title).
  String? displayAudioName({String? fallbackUsername}) {
    final title = (musicTitle ?? musicName ?? '').trim();
    final artist = (musicArtist ?? '').trim();
    if (isOriginalSound != true && (title.isNotEmpty || artist.isNotEmpty)) {
      if (title.isNotEmpty && artist.isNotEmpty) return '$title · $artist';
      return title.isNotEmpty ? title : artist;
    }
    if (title.isNotEmpty) return title;
    if (isOriginalSound == true &&
        fallbackUsername != null &&
        fallbackUsername.trim().isNotEmpty) {
      return 'Original sound - ${fallbackUsername.trim()}';
    }
    return null;
  }

  factory ReelModelApi.fromJson(Map<String, dynamic> json) {
    final video = _string(json['video'] ?? json['videoUrl'] ?? json['url']);
    final likesRaw = json['likes'];
    final likesList = likesRaw is List ? _stringList(likesRaw) : const <String>[];
    final commentsVal = json['Comments'] ?? json['comments'];
    final commentsCount = commentsVal is int
        ? commentsVal
        : (commentsVal is List ? commentsVal.length : _int(commentsVal));
    final soundtrack = _nestedMap(json['soundtrack']);
    final musicUrl = _string(
      json['musicUrl'] ??
          json['music'] ??
          soundtrack?['url'] ??
          soundtrack?['musicUrl'] ??
          '',
    ).trim();
    final musicTitle = _string(
      json['musicTitle'] ??
          json['soundtrackTitle'] ??
          soundtrack?['title'] ??
          json['musicName'] ??
          '',
    ).trim();
    final musicArtist = _string(
      json['musicArtist'] ??
          json['soundtrackArtist'] ??
          soundtrack?['artistName'] ??
          soundtrack?['artist'] ??
          '',
    ).trim();
    final musicName = _string(json['musicName'] ?? '').trim();
    final isOriginal = json['isOriginalSound'] == true ||
        soundtrack?['isOriginal'] == true;
    final musicSource = _string(
      json['musicSource'] ?? soundtrack?['source'] ?? '',
    ).trim();
    final durationMs = _int(
      json['soundtrackDurationMs'] ?? soundtrack?['durationMs'],
    );
    return ReelModelApi(
      id: _string(json['_id'] ?? json['id']),
      userId: _string(json['userId'] ?? json['user']),
      videoUrl: video,
      thumbnailUrl: _string(json['thumbnailUrl'] ?? json['thumbnail'] ?? '').isEmpty
          ? null
          : _string(json['thumbnailUrl'] ?? json['thumbnail']),
      blurHash: () {
        final b = _string(json['blurHash'] ?? json['blurhash'] ?? json['thumbHash'] ?? '');
        return b.isEmpty ? null : b;
      }(),
      caption: _string(json['caption']),
      locations: _stringList(json['locations']),
      taggedUsers: _stringList(json['taggedUsers']),
      feelings: _stringList(json['feelings']),
      createdAt: _dateTime(json['createdAt']),
      likes: likesList,
      commentsCount: commentsCount,
      views: PostModel.parseViewsField(json),
      musicUrl: musicUrl.isEmpty ? null : musicUrl,
      musicTitle: musicTitle.isEmpty ? null : musicTitle,
      musicArtist: musicArtist.isEmpty ? null : musicArtist,
      musicName: musicName.isEmpty ? null : musicName,
      isOriginalSound: isOriginal ? true : (json['isOriginalSound'] == false ? false : null),
      musicSource: musicSource.isEmpty ? null : musicSource,
      soundtrackDurationMs: durationMs > 0 ? durationMs : null,
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'userId': userId,
        'video': videoUrl,
        if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
        if (blurHash != null) 'blurHash': blurHash,
        'caption': caption,
        'locations': locations,
        'taggedUsers': taggedUsers,
        'feelings': feelings,
        'createdAt': createdAt.toIso8601String(),
      };
}

/// Reel from GET list with optional populated author.
class ReelWithUserModel {
  final ReelModelApi reel;
  final ReelUserModel? user;

  ReelWithUserModel({required this.reel, this.user});

  factory ReelWithUserModel.fromJson(Map<String, dynamic> json) {
    final reelJson = Map<String, dynamic>.from(json);
    final userJson = reelJson.remove('user');
    final reel = ReelModelApi.fromJson(reelJson);
    ReelUserModel? user;
    if (userJson != null && userJson is Map<String, dynamic>) {
      try {
        user = ReelUserModel.fromJson(userJson);
      } catch (_) {}
    }
    return ReelWithUserModel(reel: reel, user: user);
  }
}

/// User info for reel (lightweight).
class ReelUserModel {
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

  ReelUserModel({
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

  factory ReelUserModel.fromJson(Map<String, dynamic> json) {
    return ReelUserModel(
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
