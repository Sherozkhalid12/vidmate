import 'dart:convert';

/// Top-level only — safe for [compute]; no closures or services.
/// Returns `success`, optional `message`, and `items` (raw post maps from API).
Map<String, dynamic> parseFeedJson(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return {
        'success': false,
        'message': 'Invalid response',
        'items': <Map<String, dynamic>>[],
      };
    }
    final m = Map<String, dynamic>.from(decoded);
    final ok = m['success'] == true;
    if (!ok) {
      final msg = m['message'] ?? m['error'];
      return {
        'success': false,
        'message': msg?.toString() ?? 'Failed to load posts',
        'items': <Map<String, dynamic>>[],
      };
    }
    final list = m['posts'];
    if (list is! List) {
      return {'success': true, 'items': <Map<String, dynamic>>[]};
    }
    final out = <Map<String, dynamic>>[];
    for (final e in list) {
      if (e is Map<String, dynamic>) {
        out.add(e);
      } else if (e is Map) {
        out.add(Map<String, dynamic>.from(e));
      }
    }
    return {'success': true, 'items': out};
  } catch (_) {
    return {
      'success': false,
      'message': 'Parse error',
      'items': <Map<String, dynamic>>[],
    };
  }
}
