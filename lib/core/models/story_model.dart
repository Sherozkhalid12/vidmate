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

  StoryModel({
    required this.id,
    required this.author,
    required this.mediaUrl,
    this.isVideo = false,
    required this.createdAt,
    this.isViewed = false,
    this.locations = const [],
    this.taggedUsers = const [],
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
      };

  factory StoryModel.fromCachedMap(
    Map<String, dynamic> m,
    UserModel author,
  ) {
    final loc = m['locations'];
    final tags = m['taggedUsers'];
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
    );
  }
}


