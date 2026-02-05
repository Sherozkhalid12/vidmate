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
