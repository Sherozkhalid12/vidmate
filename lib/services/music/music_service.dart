import 'dart:async';

import 'package:dio/dio.dart';

import '../../core/api/dio_client.dart';
import '../../core/constants/api_constants.dart';
import '../../core/models/music_model.dart';

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
          tracks.add(_mapSongToMusicModel(item));
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

  MusicModel _mapSongToMusicModel(Map<String, dynamic> json) {
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
}

