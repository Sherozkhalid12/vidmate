import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/dio_client.dart';
import '../../core/models/music_model.dart';
import '../../core/utils/preview_url_expiry.dart';
import '../auth/auth_service.dart';
import 'music_service.dart';

/// Persisted snapshot of the Add Music (Deezer browse) payload.
class MusicBrowseCacheSnapshot {
  final List<DeezerPlaylistSummary> playlists;
  final List<MusicModel> songs;
  final String? activePlaylistId;
  final DateTime? updatedAt;

  const MusicBrowseCacheSnapshot({
    required this.playlists,
    required this.songs,
    required this.activePlaylistId,
    this.updatedAt,
  });
}

/// Local cache for Deezer browse (playlists + default playlist tracks).
///
/// Uses [SharedPreferences] only so WorkManager isolates can read/write
/// without Hive/Flutter plugin dependencies beyond prefs.
class MusicLibraryCacheService {
  MusicLibraryCacheService._();
  static final MusicLibraryCacheService instance = MusicLibraryCacheService._();

  static const String _prefsKey = 'music_library.deezer_browse_cache_v1';
  static const int _jsonVersion = 1;

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  Map<String, dynamic> _playlistToMap(DeezerPlaylistSummary p) => {
        'id': p.id,
        'title': p.title,
        'picture': p.picture,
        'trackCount': p.trackCount,
      };

  DeezerPlaylistSummary _playlistFromMap(Map<String, dynamic> m) {
    return DeezerPlaylistSummary(
      id: (m['id'] ?? '').toString(),
      title: (m['title'] ?? '').toString(),
      picture: (m['picture'] ?? '').toString(),
      trackCount: m['trackCount'] is num
          ? (m['trackCount'] as num).toInt()
          : int.tryParse('${m['trackCount']}') ?? 0,
    );
  }

  /// Merges [fresh] order with stored tracks: keeps stored row when its
  /// preview URL is still valid; otherwise uses the fresh row.
  List<MusicModel> mergeSongsByPreviewExpiry({
    required List<MusicModel> stored,
    required List<MusicModel> fresh,
  }) {
    final storedById = {for (final t in stored) t.id: t};
    return fresh.map((f) {
      final old = storedById[f.id];
      if (old == null) return f;
      final url = old.audioUrl.trim();
      if (url.isEmpty || isPreviewUrlExpired(url)) {
        return f.copyWith(isLiked: old.isLiked);
      }
      return old;
    }).toList();
  }

  Future<MusicBrowseCacheSnapshot?> readBrowseCache() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      if ((decoded['version'] is num ? (decoded['version'] as num).toInt() : 0) !=
          _jsonVersion) {
        return null;
      }
      final plRaw = decoded['playlists'];
      final playlists = <DeezerPlaylistSummary>[];
      if (plRaw is List) {
        for (final e in plRaw) {
          if (e is Map<String, dynamic>) {
            playlists.add(_playlistFromMap(e));
          }
        }
      }
      final songsRaw = decoded['songs'];
      final songs = <MusicModel>[];
      if (songsRaw is List) {
        for (final e in songsRaw) {
          if (e is Map<String, dynamic>) {
            try {
              songs.add(MusicModel.fromJson(e));
            } catch (_) {}
          }
        }
      }
      final activeId = decoded['activePlaylistId']?.toString();
      final updatedAtStr = decoded['updatedAt']?.toString();
      return MusicBrowseCacheSnapshot(
        playlists: playlists,
        songs: songs,
        activePlaylistId:
            (activeId != null && activeId.isNotEmpty) ? activeId : null,
        updatedAt: DateTime.tryParse(updatedAtStr ?? ''),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> writeBrowseCache({
    required List<DeezerPlaylistSummary> playlists,
    required List<MusicModel> songs,
    String? activePlaylistId,
  }) async {
    final prefs = await _prefs;
    final map = <String, dynamic>{
      'version': _jsonVersion,
      'playlists': playlists.map(_playlistToMap).toList(),
      'songs': songs.map((s) => s.toJson()).toList(),
      'activePlaylistId': activePlaylistId,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    };
    await prefs.setString(_prefsKey, jsonEncode(map));
  }

  /// Fetches Deezer browse from the API, merges preview URLs using [isPreviewUrlExpired],
  /// and persists. Safe for WorkManager isolates (HTTP + prefs only).
  Future<bool> syncBrowseFromNetwork() async {
    final token = await AuthService().getToken();
    if (token != null && token.isNotEmpty) {
      DioClient.setAuthToken(token);
    } else {
      DioClient.clearAuthToken();
    }

    final fresh = await MusicService().fetchDeezerPlaylistsBrowse(
      limit: 24,
      playlistLimit: 24,
    );
    if (!fresh.success) {
      if (kDebugMode) {
        debugPrint('[MusicLibraryCache] browse failed: ${fresh.errorMessage}');
      }
      return false;
    }

    final existing = await readBrowseCache();
    final mergedSongs = mergeSongsByPreviewExpiry(
      stored: existing?.songs ?? const [],
      fresh: fresh.songs,
    );
    final initialId = fresh.selectedPlaylist?.id ??
        (fresh.playlists.isNotEmpty ? fresh.playlists.first.id : null);

    await writeBrowseCache(
      playlists: fresh.playlists,
      songs: mergedSongs,
      activePlaylistId: initialId,
    );
    return true;
  }
}
