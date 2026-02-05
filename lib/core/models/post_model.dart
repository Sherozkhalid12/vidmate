import 'user_model.dart';

/// Post model for feed
class PostModel {
  final String id;
  final UserModel author;
  final String? imageUrl;
  final String? videoUrl;
  final String? thumbnailUrl;
  final String caption;
  final DateTime createdAt;
  final int likes;
  final int comments;
  final int shares;
  final bool isLiked;
  final Duration? videoDuration;
  final bool isVideo;
  /// Optional audio track id for reels (e.g. "original_sound_authorId")
  final String? audioId;
  /// Display name for audio (e.g. "Original sound - username")
  final String? audioName;

  PostModel({
    required this.id,
    required this.author,
    this.imageUrl,
    this.videoUrl,
    this.thumbnailUrl,
    required this.caption,
    required this.createdAt,
    this.likes = 0,
    this.comments = 0,
    this.shares = 0,
    this.isLiked = false,
    this.videoDuration,
    this.isVideo = false,
    this.audioId,
    this.audioName,
  });
}


