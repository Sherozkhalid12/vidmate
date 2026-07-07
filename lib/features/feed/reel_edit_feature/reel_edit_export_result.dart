import 'dart:io';

/// Soundtrack metadata for `POST /post/reel/create`.
class ReelSoundtrackInfo {
  const ReelSoundtrackInfo({
    this.trackId,
    this.musicUrl,
    this.title,
    this.artist,
    this.musicSource = 'library',
    this.durationMs,
  });

  final String? trackId;
  final String? musicUrl;
  final String? title;
  final String? artist;
  final String musicSource;
  final int? durationMs;

  bool get hasLibraryMusic =>
      (musicUrl != null && musicUrl!.trim().isNotEmpty) ||
      (title != null && title!.trim().isNotEmpty) ||
      (trackId != null && trackId!.trim().isNotEmpty);

  Map<String, dynamic> toJson() => {
        if (trackId != null) 'trackId': trackId,
        if (musicUrl != null) 'musicUrl': musicUrl,
        if (title != null) 'title': title,
        if (artist != null) 'artist': artist,
        'musicSource': musicSource,
        if (durationMs != null) 'durationMs': durationMs,
      };
}

/// Result of exporting from [ReelEditScreen] (video file + optional soundtrack).
class ReelEditExportResult {
  const ReelEditExportResult({
    required this.video,
    this.soundtrack,
  });

  final File video;
  final ReelSoundtrackInfo? soundtrack;
}
