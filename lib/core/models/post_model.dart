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
  });
}


