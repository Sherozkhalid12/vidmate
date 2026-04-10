import 'dart:convert';

/// Top-level for [compute] — JSON decode + list normalization only (no Hive singletons).
List<Map<String, dynamic>> parseHivePostsPayloadJson(String raw) {
  if (raw.isEmpty) return [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return [];
    final m = Map<String, dynamic>.from(decoded);
    final list = m['items'];
    if (list is! List) return [];
    final out = <Map<String, dynamic>>[];
    for (final e in list) {
      if (e is Map<String, dynamic>) {
        out.add(e);
      } else if (e is Map) {
        out.add(Map<String, dynamic>.from(e));
      }
    }
    return out;
  } catch (_) {
    return [];
  }
}
