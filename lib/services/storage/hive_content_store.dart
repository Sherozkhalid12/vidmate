import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Hive-backed cache for feed posts, reels, and long videos. Open once at app init.
class HiveContentStore {
  HiveContentStore._();
  static final HiveContentStore instance = HiveContentStore._();

  static const String _boxName = 'vidconnect_content';
  static const String migrationFlagKey = 'hive_migration_v1_done';

  static const String _keyPosts = 'posts';
  static const String _keyReels = 'reels';
  static const String _keyLongVideos = 'longVideos';
  static const String _keyDominantColors = 'dominant_colors';
  static const String _keyExploreRecent = 'explore_recent_searches';
  static const String _keyStoriesTray = 'stories_tray';

  Box<String>? _box;

  bool get isReady => _box != null && _box!.isOpen;

  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox<String>(_boxName);
    await _migrateFromSharedPreferencesIfNeeded();
  }

  /// One-time migration from legacy user-map JSON blobs.
  Future<void> _migrateFromSharedPreferencesIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(migrationFlagKey) == true) {
      if (kDebugMode) debugPrint('hive_migration_skipped');
      return;
    }
    try {
      final userId = prefs.getString('storage.currentUserId');
      if (userId == null || userId.isEmpty) {
        await prefs.setBool(migrationFlagKey, true);
        if (kDebugMode) debugPrint('hive_migration_skipped');
        return;
      }
      final raw = prefs.getString('storage.user.map.$userId');
      if (raw == null || raw.isEmpty) {
        await prefs.setBool(migrationFlagKey, true);
        if (kDebugMode) debugPrint('hive_migration_skipped');
        return;
      }
      final map = jsonDecode(raw);
      if (map is! Map) {
        await prefs.setBool(migrationFlagKey, true);
        return;
      }
      final userMap = Map<String, dynamic>.from(map);
      bool wrote = false;

      for (final key in [_keyPosts, _keyReels, _keyLongVideos]) {
        final list = userMap[key];
        if (list is List && list.isNotEmpty) {
          final items = list
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          if (items.isNotEmpty) {
            await _putSection(key, items);
            userMap.remove(key);
            userMap.remove('${key}UpdatedAt');
            wrote = true;
          }
        }
      }

      if (wrote) {
        await prefs.setString('storage.user.map.$userId', jsonEncode(userMap));
      }
      await prefs.setBool(migrationFlagKey, true);
      if (kDebugMode) debugPrint('hive_migration_ok');
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('hive_migration_failed: $e');
        debugPrint('$st');
      }
    }
  }

  Future<void> _putSection(String section, List<Map<String, dynamic>> items) async {
    final b = _box;
    if (b == null) return;
    final payload = jsonEncode({
      'items': items,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
    await b.put(section, payload);
  }

  Future<void> savePosts(List<Map<String, dynamic>> items) async {
    await _putSection(_keyPosts, items);
  }

  Future<void> saveReels(List<Map<String, dynamic>> items) async {
    await _putSection(_keyReels, items);
  }

  Future<void> saveLongVideos(List<Map<String, dynamic>> items) async {
    await _putSection(_keyLongVideos, items);
  }

  ({List<Map<String, dynamic>> items, DateTime? updatedAt}) readSection(String section) {
    final b = _box;
    if (b == null) return (items: <Map<String, dynamic>>[], updatedAt: null);
    final raw = b.get(section);
    if (raw is! String || raw.isEmpty) {
      return (items: <Map<String, dynamic>>[], updatedAt: null);
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return (items: <Map<String, dynamic>>[], updatedAt: null);
      }
      final m = Map<String, dynamic>.from(decoded);
      final list = m['items'];
      final updatedMs = m['updatedAt'];
      DateTime? updatedAt;
      if (updatedMs is int) {
        updatedAt = DateTime.fromMillisecondsSinceEpoch(updatedMs);
      } else if (updatedMs != null) {
        updatedAt = DateTime.tryParse(updatedMs.toString());
      }
      if (list is! List) {
        return (items: <Map<String, dynamic>>[], updatedAt: updatedAt);
      }
      final out = <Map<String, dynamic>>[];
      for (final e in list) {
        if (e is Map<String, dynamic>) {
          out.add(e);
        } else if (e is Map) {
          out.add(Map<String, dynamic>.from(e));
        }
      }
      return (items: out, updatedAt: updatedAt);
    } catch (_) {
      return (items: <Map<String, dynamic>>[], updatedAt: null);
    }
  }

  List<Map<String, dynamic>> get postsMaps => readSection(_keyPosts).items;

  /// Raw JSON blob for posts (for [compute] decode off the UI isolate).
  String? get postsPayloadRaw {
    final b = _box;
    if (b == null || !b.isOpen) return null;
    final raw = b.get(_keyPosts);
    if (raw is! String || raw.isEmpty) return null;
    return raw;
  }
  List<Map<String, dynamic>> get reelsMaps => readSection(_keyReels).items;
  List<Map<String, dynamic>> get longVideosMaps => readSection(_keyLongVideos).items;

  Future<int?> getDominantColorArgb(String postId) async {
    final b = _box;
    if (b == null) return null;
    final raw = b.get(_keyDominantColors);
    if (raw is! String || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final v = decoded[postId];
      if (v is int) return v;
      return int.tryParse(v?.toString() ?? '');
    } catch (_) {
      return null;
    }
  }

  /// Recent explore/search queries (Feature 4.2 / 4.8).
  Future<void> saveExploreRecentSearches(List<String> queries) async {
    final b = _box;
    if (b == null) return;
    final capped = queries.take(20).toList();
    await b.put(_keyExploreRecent, jsonEncode({'queries': capped}));
  }

  /// Serialized `{ "entries": [ { "user": map, "stories": [ story maps ] } ], "updatedAt": ms }`
  Future<void> saveStoriesTray(Map<String, dynamic> doc) async {
    final b = _box;
    if (b == null) return;
    final copy = Map<String, dynamic>.from(doc);
    copy['updatedAt'] = DateTime.now().millisecondsSinceEpoch;
    await b.put(_keyStoriesTray, jsonEncode(copy));
  }

  String? get storiesTrayPayloadRaw {
    final b = _box;
    if (b == null || !b.isOpen) return null;
    final r = b.get(_keyStoriesTray);
    if (r is! String || r.isEmpty) return null;
    return r;
  }

  List<String> readExploreRecentSearches() {
    final b = _box;
    if (b == null) return const [];
    final raw = b.get(_keyExploreRecent);
    if (raw is! String || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const [];
      final q = decoded['queries'];
      if (q is! List) return const [];
      return q.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> setDominantColorArgb(String postId, int argb) async {
    final b = _box;
    if (b == null) return;
    Map<String, dynamic> map = {};
    final raw = b.get(_keyDominantColors);
    if (raw is String && raw.isNotEmpty) {
      try {
        final d = jsonDecode(raw);
        if (d is Map) map = Map<String, dynamic>.from(d);
      } catch (_) {}
    }
    map[postId] = argb;
    await b.put(_keyDominantColors, jsonEncode(map));
  }
}
