/// Music track model
class MusicModel {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String coverUrl;
  final String audioUrl;
  final Duration duration;
  final int plays;
  final int likes;
  final bool isLiked;
  final DateTime releaseDate;
  final String? genre;

  MusicModel({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.coverUrl,
    required this.audioUrl,
    required this.duration,
    this.plays = 0,
    this.likes = 0,
    this.isLiked = false,
    required this.releaseDate,
    this.genre,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'coverUrl': coverUrl,
        'audioUrl': audioUrl,
        'durationMs': duration.inMilliseconds,
        'plays': plays,
        'likes': likes,
        'isLiked': isLiked,
        'releaseDate': releaseDate.toIso8601String(),
        if (genre != null) 'genre': genre,
      };

  factory MusicModel.fromJson(Map<String, dynamic> json) {
    final ms = json['durationMs'];
    final durMs = ms is int ? ms : int.tryParse('$ms') ?? 0;
    final rd = json['releaseDate']?.toString();
    return MusicModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      artist: json['artist']?.toString() ?? '',
      album: json['album']?.toString() ?? '',
      coverUrl: json['coverUrl']?.toString() ?? '',
      audioUrl: json['audioUrl']?.toString() ?? '',
      duration: Duration(milliseconds: durMs),
      plays: (json['plays'] is int) ? json['plays'] as int : int.tryParse('${json['plays']}') ?? 0,
      likes: (json['likes'] is int) ? json['likes'] as int : int.tryParse('${json['likes']}') ?? 0,
      isLiked: json['isLiked'] == true,
      releaseDate: DateTime.tryParse(rd ?? '') ?? DateTime.now(),
      genre: json['genre']?.toString(),
    );
  }

  MusicModel copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    String? coverUrl,
    String? audioUrl,
    Duration? duration,
    int? plays,
    int? likes,
    bool? isLiked,
    DateTime? releaseDate,
    String? genre,
  }) {
    return MusicModel(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      coverUrl: coverUrl ?? this.coverUrl,
      audioUrl: audioUrl ?? this.audioUrl,
      duration: duration ?? this.duration,
      plays: plays ?? this.plays,
      likes: likes ?? this.likes,
      isLiked: isLiked ?? this.isLiked,
      releaseDate: releaseDate ?? this.releaseDate,
      genre: genre ?? this.genre,
    );
  }
}
