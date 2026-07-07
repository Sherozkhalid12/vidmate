/// User who viewed a story (owner-visible list from API).
class StoryViewerModel {
  final String id;
  final String name;
  final String image;
  final bool verified;
  final DateTime? viewedAt;

  const StoryViewerModel({
    required this.id,
    required this.name,
    this.image = '',
    this.verified = false,
    this.viewedAt,
  });

  static String _str(dynamic v) => v?.toString() ?? '';

  static bool _bool(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    final s = v.toString().toLowerCase();
    return s == 'true' || s == '1';
  }

  static DateTime? _date(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }

  factory StoryViewerModel.fromJson(Map<String, dynamic> json) {
    return StoryViewerModel(
      id: _str(json['id'] ?? json['_id'] ?? json['userId']),
      name: _str(json['name'] ?? json['username'] ?? json['displayName']),
      image: _str(
        json['image'] ??
            json['profilePicture'] ??
            json['profilePictureUrl'] ??
            json['avatarUrl'] ??
            json['avatar'],
      ),
      verified: _bool(json['verified']),
      viewedAt: _date(
        json['viewedAt'] ?? json['viewed_at'] ?? json['createdAt'],
      ),
    );
  }
}
