import 'dart:convert';

/// JSON decode + list normalization on a background isolate (Feature 4.5).
/// No [Ref], [BuildContext], or singletons — safe for [compute].
Map<String, dynamic> parseExploreSearchResponseJson(String rawBody) {
  final decoded = jsonDecode(rawBody);
  if (decoded is! Map) {
    return {'success': false, 'message': 'Invalid response'};
  }
  final map = Map<String, dynamic>.from(decoded);

  List<Map<String, dynamic>> mapList(dynamic v) {
    if (v is! List) return const [];
    final out = <Map<String, dynamic>>[];
    for (final e in v) {
      if (e is Map<String, dynamic>) {
        out.add(e);
      } else if (e is Map) {
        out.add(Map<String, dynamic>.from(e));
      }
    }
    return out;
  }

  final countsRaw = map['counts'] is Map
      ? Map<String, dynamic>.from(map['counts'] as Map)
      : <String, dynamic>{};

  return {
    'success': map['success'] == true,
    'message': map['message']?.toString(),
    'error': map['error']?.toString(),
    'searchText': map['searchText']?.toString(),
    'counts': countsRaw,
    'users': mapList(map['users']),
    'posts': mapList(map['posts']),
    'reels': mapList(map['reels']),
    'longVideos': mapList(map['longVideos']),
  };
}
