import 'dart:async';

import 'package:dio/dio.dart';

import '../../core/api/dio_client.dart';
import '../../core/constants/api_constants.dart';
import '../../core/models/music_model.dart';

/// One Deezer playlist row from `/music/deezer/playlists`.
class DeezerPlaylistSummary {
  final String id;
  final String title;
  final String picture;
  final int trackCount;

  const DeezerPlaylistSummary({
    required this.id,
    required this.title,
    required this.picture,
    required this.trackCount,
  });
}

/// First screen payload: playlist strip + songs for the selected playlist.
class DeezerBrowseResult {
  final bool success;
  final List<DeezerPlaylistSummary> playlists;
  final List<MusicModel> songs;
  final DeezerPlaylistSummary? selectedPlaylist;
  final String? errorMessage;

  const DeezerBrowseResult({
    required this.success,
    this.playlists = const [],
    this.songs = const [],
    this.selectedPlaylist,
    this.errorMessage,
  });

  const DeezerBrowseResult.failure(String message)
      : success = false,
        playlists = const [],
        songs = const [],
        selectedPlaylist = null,
        errorMessage = message;

  const DeezerBrowseResult.ok({
    required this.playlists,
    required this.songs,
    this.selectedPlaylist,
  })  : success = true,
        errorMessage = null;
}

class MusicListResult {
  final bool success;
  final List<MusicModel> tracks;
  final int total;
  final String? errorMessage;

  const MusicListResult({
    required this.success,
    this.tracks = const [],
    this.total = 0,
    this.errorMessage,
  });

  const MusicListResult.failure(String message)
      : success = false,
        tracks = const [],
        total = 0,
        errorMessage = message;

  const MusicListResult.success({
    required List<MusicModel> tracks,
    required int total,
  })  : success = true,
        tracks = tracks,
        total = total,
        errorMessage = null;
}

/// Music API service using shared Dio client.
class MusicService {
  final Dio _dio = DioClient.instance;

  String _pickPlayableAudioUrl(Map<String, dynamic> json) {
    // Backend may send different keys during development; prefer fields
    // that are usually direct URLs to audio files/streams.
    final candidates = <String>[
      'audioUrl',
      'audio_url',
      'streamUrl',
      'stream_url',
      'mp3Url',
      'mp3_url',
      'previewUrl',
      'preview_url',
      'fileUrl',
      'file_url',
      'url',
      'externalUrl',
    ];
    for (final key in candidates) {
      final v = json[key];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return '';
  }

  /// Fetch paginated music list.
  ///
  /// The backend returns shape:
  /// { success: true, total: number, songs: [ ... ] }
  Future<MusicListResult> getMusics({
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final response = await _dio.get(
        ApiConstants.musicList,
        queryParameters: {
          'page': page,
          'limit': limit,
        },
      );

      final data = response.data;
      if (data is! Map<String, dynamic> || data['success'] != true) {
        final message = data is Map<String, dynamic>
            ? (data['message']?.toString() ?? 'Failed to load music')
            : 'Failed to load music';
        return MusicListResult.failure(message);
      }

      final rawSongs = data['songs'];
      final total = (data['total'] is num) ? (data['total'] as num).toInt() : 0;
      if (rawSongs is! List) {
        return MusicListResult.success(tracks: const [], total: total);
      }

      final tracks = <MusicModel>[];
      for (final item in rawSongs) {
        if (item is! Map<String, dynamic>) continue;
        try {
          tracks.add(mapSongJsonToMusicModel(item));
        } catch (_) {
          // Ignore malformed items
        }
      }

      return MusicListResult.success(tracks: tracks, total: total);
    } on DioException catch (e) {
      final d = e.response?.data;
      final msg = d is Map
          ? (d['message'] ?? d['error'] ?? 'Failed to load music')
          : 'Failed to load music';
      return MusicListResult.failure(msg.toString());
    } on TimeoutException catch (_) {
      return const MusicListResult.failure('Music request timed out');
    } catch (e) {
      return MusicListResult.failure(e.toString());
    }
  }

  MusicModel mapSongJsonToMusicModel(Map<String, dynamic> json) {
    final id = (json['_id'] ?? json['id'] ?? '').toString();
    final name = (json['name'] ?? '').toString();
    final album = json['album'] is Map<String, dynamic>
        ? (json['album'] as Map<String, dynamic>)
        : <String, dynamic>{};
    final albumName = (album['name'] ?? '').toString();
    final thumbnail = (album['thumbnail'] ?? '').toString();

    final artists = <String>[];
    if (json['artists'] is List) {
      for (final a in (json['artists'] as List)) {
        if (a is Map<String, dynamic>) {
          final name = (a['name'] ?? '').toString();
          if (name.isNotEmpty) artists.add(name);
        }
      }
    }

    final durationMs = json['durationMs'] is num
        ? (json['durationMs'] as num).toInt()
        : 0;
    final externalUrl = _pickPlayableAudioUrl(json);

    DateTime releaseDate = DateTime.now();
    final albumRelease = album['releaseDate']?.toString();
    final createdAt = json['createdAt']?.toString();
    if (albumRelease != null && albumRelease.isNotEmpty) {
      releaseDate = DateTime.tryParse(albumRelease) ?? releaseDate;
    } else if (createdAt != null && createdAt.isNotEmpty) {
      releaseDate = DateTime.tryParse(createdAt) ?? releaseDate;
    }

    return MusicModel(
      id: id,
      title: name,
      artist: artists.isNotEmpty ? artists.join(', ') : 'Unknown Artist',
      album: albumName,
      coverUrl: thumbnail,
      audioUrl: externalUrl,
      duration: Duration(milliseconds: durationMs),
      plays: 0,
      likes: 0,
      isLiked: false,
      releaseDate: releaseDate,
      genre: null,
    );
  }

  List<DeezerPlaylistSummary> _parsePlaylistSummaries(dynamic raw) {
    if (raw is! List) return const [];
    final out = <DeezerPlaylistSummary>[];
    for (final item in raw) {
      if (item is! Map<String, dynamic>) continue;
      final id = (item['id'] ?? '').toString();
      if (id.isEmpty) continue;
      out.add(
        DeezerPlaylistSummary(
          id: id,
          title: (item['title'] ?? '').toString(),
          picture: (item['picture'] ?? '').toString(),
          trackCount: item['trackCount'] is num
              ? (item['trackCount'] as num).toInt()
              : int.tryParse('${item['trackCount']}') ?? 0,
        ),
      );
    }
    return out;
  }

  DeezerPlaylistSummary? _parseSelectedPlaylist(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;
    final id = (raw['id'] ?? '').toString();
    if (id.isEmpty) return null;
    return DeezerPlaylistSummary(
      id: id,
      title: (raw['title'] ?? '').toString(),
      picture: (raw['picture'] ?? '').toString(),
      trackCount: raw['trackCount'] is num
          ? (raw['trackCount'] as num).toInt()
          : int.tryParse('${raw['trackCount']}') ?? 0,
    );
  }

  List<MusicModel> _parseSongsList(dynamic raw) {
    if (raw is! List) return const [];
    final tracks = <MusicModel>[];
    for (final item in raw) {
      if (item is! Map<String, dynamic>) continue;
      try {
        tracks.add(mapSongJsonToMusicModel(item));
      } catch (_) {}
    }
    return tracks;
  }

  /// GET `/music/deezer/playlists` — playlist strip + `songs` for selected playlist.
  Future<DeezerBrowseResult> fetchDeezerPlaylistsBrowse({
    int limit = 20,
    int playlistLimit = 20,
  }) async {
    try {
      final response = await _dio.get(
        ApiConstants.musicDeezerPlaylists,
        queryParameters: {
          'limit': limit,
          'playlistLimit': playlistLimit,
        },
      );
      final data = response.data;
      if (data is! Map<String, dynamic> || data['success'] != true) {
        final message = data is Map<String, dynamic>
            ? (data['message']?.toString() ?? 'Failed to load playlists')
            : 'Failed to load playlists';
        return DeezerBrowseResult.failure(message);
      }
      final playlists = _parsePlaylistSummaries(data['playlists']);
      final songs = _parseSongsList(data['songs']);
      final selected = _parseSelectedPlaylist(data['selectedPlaylist']);
      return DeezerBrowseResult.ok(
        playlists: playlists,
        songs: songs,
        selectedPlaylist: selected,
      );
    } on DioException catch (e) {
      final d = e.response?.data;
      final msg = d is Map
          ? (d['message'] ?? d['error'] ?? 'Failed to load playlists')
              .toString()
          : 'Failed to load playlists';
      return DeezerBrowseResult.failure(msg);
    } catch (e) {
      return DeezerBrowseResult.failure(e.toString());
    }
  }

  /// GET `/music/deezer/playlists/:playlistId` — tracks for one playlist.
  Future<MusicListResult> fetchDeezerPlaylistSongs(
    String playlistId, {
    int limit = 30,
  }) async {
    if (playlistId.isEmpty) {
      return const MusicListResult.failure('Invalid playlist');
    }
    try {
      final response = await _dio.get(
        ApiConstants.musicDeezerPlaylist(playlistId),
        queryParameters: {'limit': limit},
      );
      final data = response.data;
      if (data is! Map<String, dynamic> || data['success'] != true) {
        final message = data is Map<String, dynamic>
            ? (data['message']?.toString() ?? 'Failed to load tracks')
            : 'Failed to load tracks';
        return MusicListResult.failure(message);
      }
      final songs = _parseSongsList(data['songs']);
      final total = songs.length;
      return MusicListResult.success(tracks: songs, total: total);
    } on DioException catch (e) {
      final d = e.response?.data;
      final msg = d is Map
          ? (d['message'] ?? d['error'] ?? 'Failed to load tracks').toString()
          : 'Failed to load tracks';
      return MusicListResult.failure(msg);
    } catch (e) {
      return MusicListResult.failure(e.toString());
    }
  }
}

