import 'user_model.dart';

/// Story model (UI)
class StoryModel {
  final String id;
  final UserModel author;
  final String mediaUrl;
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

  StoryModel({
    required this.id,
    required this.author,
    required this.mediaUrl,
    this.isVideo = false,
    required this.createdAt,
    this.isViewed = false,
    this.locations = const [],
    this.taggedUsers = const [],
    this.musicName,
    this.musicTitle,
    this.musicPreviewUrl,
  });

  /// Hive tray cache (author stored on parent user row).
  Map<String, dynamic> toCachedMap() => {
        'id': id,
        'mediaUrl': mediaUrl,
        'isVideo': isVideo,
        'createdAt': createdAt.toIso8601String(),
        'isViewed': isViewed,
        'locations': locations,
        'taggedUsers': taggedUsers,
        if (musicName != null && musicName!.isNotEmpty) 'musicName': musicName,
        if (musicTitle != null && musicTitle!.isNotEmpty) 'musicTitle': musicTitle,
        if (musicPreviewUrl != null && musicPreviewUrl!.trim().isNotEmpty)
          'musicPreviewUrl': musicPreviewUrl,
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
    return StoryModel(
      id: m['id']?.toString() ?? '',
      author: author,
      mediaUrl: m['mediaUrl']?.toString() ?? '',
      isVideo: m['isVideo'] == true,
      createdAt: DateTime.tryParse(m['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      isViewed: m['isViewed'] == true,
      locations: loc is List
          ? loc.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
          : const [],
      taggedUsers: tags is List
          ? tags.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
          : const [],
      musicName: (mn != null && mn.isNotEmpty) ? mn : null,
      musicTitle: (mt != null && mt.isNotEmpty) ? mt : null,
      musicPreviewUrl: (mp != null && mp.trim().isNotEmpty) ? mp.trim() : null,
    );
  }
}


