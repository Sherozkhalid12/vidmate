import 'story_viewer_model.dart';
import 'user_model.dart';

/// Story model (UI)
class StoryModel {
  final String id;
  /// Backend story `_id` (shared across segments).
  final String parentStoryId;
  final UserModel author;
  final String mediaUrl;
  final String? thumbnailUrl;
  final String caption;
  final bool isVideo;
  final DateTime createdAt;
  final bool isViewed;
  final List<String> locations;
  final List<String> taggedUsers;
  /// Song title (only for attribution when [musicTitle] is also set).
  final String? musicName;
  /// Artist / performer name (paired with [musicName] for display).
  final String? musicTitle;
  /// Preview URL for short playback (parent story; same for all segments).
  final String? musicPreviewUrl;
  /// Playable music URL (when distinct from preview); tray prewarm uses this first.
  final String? musicUrl;
  final int viewCount;
  final bool hasViewed;
  final List<StoryViewerModel> viewers;

  StoryModel({
    required this.id,
    this.parentStoryId = '',
    required this.author,
    required this.mediaUrl,
    this.thumbnailUrl,
    this.caption = '',
    this.isVideo = false,
    required this.createdAt,
    this.isViewed = false,
    this.locations = const [],
    this.taggedUsers = const [],
    this.musicName,
    this.musicTitle,
    this.musicPreviewUrl,
    this.musicUrl,
    this.viewCount = 0,
    this.hasViewed = false,
    this.viewers = const [],
  });

  /// URL used for story background audio (tray prewarm + viewer).
  String get storyMusicPlaybackUrl {
    final u = musicUrl?.trim() ?? '';
    if (u.isNotEmpty) return u;
    return musicPreviewUrl?.trim() ?? '';
  }

  /// Hive tray cache (author stored on parent user row).
  Map<String, dynamic> toCachedMap() => {
        'id': id,
        if (parentStoryId.isNotEmpty) 'parentStoryId': parentStoryId,
        'mediaUrl': mediaUrl,
        if (thumbnailUrl != null && thumbnailUrl!.trim().isNotEmpty)
          'thumbnailUrl': thumbnailUrl,
        'viewCount': viewCount,
        'hasViewed': hasViewed,
        if (caption.trim().isNotEmpty) 'caption': caption,
        'isVideo': isVideo,
        'createdAt': createdAt.toIso8601String(),
        'isViewed': isViewed,
        'locations': locations,
        'taggedUsers': taggedUsers,
        if (musicName != null && musicName!.isNotEmpty) 'musicName': musicName,
        if (musicTitle != null && musicTitle!.isNotEmpty) 'musicTitle': musicTitle,
        if (musicPreviewUrl != null && musicPreviewUrl!.trim().isNotEmpty)
          'musicPreviewUrl': musicPreviewUrl,
        if (musicUrl != null && musicUrl!.trim().isNotEmpty) 'musicUrl': musicUrl,
      };

  factory StoryModel.fromCachedMap(
    Map<String, dynamic> m,
    UserModel author,
  ) {
    final loc = m['locations'];
    final tags = m['taggedUsers'];
    final mn = m['musicName']?.toString();
    final mt = m['musicTitle']?.toString();
    final mp = (m['musicPreviewUrl'] ?? m['music'])?.toString();
    final mu = m['musicUrl']?.toString();
    final viewersRaw = m['viewers'];
    final viewers = viewersRaw is List
        ? viewersRaw
            .whereType<Map>()
            .map((e) => StoryViewerModel.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : const <StoryViewerModel>[];
    return StoryModel(
      id: m['id']?.toString() ?? '',
      parentStoryId: m['parentStoryId']?.toString() ?? '',
      author: author,
      mediaUrl: m['mediaUrl']?.toString() ?? '',
      thumbnailUrl: () {
        final t = m['thumbnailUrl']?.toString().trim() ?? '';
        return t.isNotEmpty ? t : null;
      }(),
      caption: m['caption']?.toString() ?? '',
      isVideo: m['isVideo'] == true,
      createdAt: DateTime.tryParse(m['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      isViewed: m['isViewed'] == true || m['hasViewed'] == true,
      viewCount: m['viewCount'] is int
          ? m['viewCount'] as int
          : int.tryParse('${m['viewCount']}') ?? 0,
      hasViewed: m['hasViewed'] == true || m['isViewed'] == true,
      viewers: viewers,
      locations: loc is List
          ? loc.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
          : const [],
      taggedUsers: tags is List
          ? tags.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
          : const [],
      musicName: (mn != null && mn.isNotEmpty) ? mn : null,
      musicTitle: (mt != null && mt.isNotEmpty) ? mt : null,
      musicPreviewUrl: (mp != null && mp.trim().isNotEmpty) ? mp.trim() : null,
      musicUrl: (mu != null && mu.trim().isNotEmpty) ? mu.trim() : null,
    );
  }
}


