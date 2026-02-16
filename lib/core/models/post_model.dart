import 'user_model.dart';
import 'post_response_model.dart';

/// Post model for feed
class PostModel {
  final String id;
  final UserModel author;
  final String? imageUrl; // First image (backward compatibility)
  final List<String> _imageUrls; // All images for carousel
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

  /// Get all image URLs. Always returns a non-null list.
  List<String> get imageUrls => _imageUrls;

  PostModel({
    required this.id,
    required this.author,
    this.imageUrl,
    List<String>? imageUrls,
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
  }) : _imageUrls = imageUrls != null && imageUrls.isNotEmpty
            ? imageUrls
            : (imageUrl != null ? [imageUrl] : <String>[]);

  /// Placeholder author when API does not return populated user.
  static UserModel authorPlaceholder(String userId) {
    return UserModel(
      id: userId,
      username: '',
      displayName: '',
      avatarUrl: '',
      followers: 0,
      following: 0,
      posts: 0,
    );
  }

  /// Build feed post from API post and author (e.g. current user).
  static PostModel fromApiPost(ApiPost api, UserModel author) {
    final hasVideo = api.video.isNotEmpty;
    return PostModel(
      id: api.id,
      author: author,
      imageUrl: api.images.isNotEmpty ? api.images.first : null,
      imageUrls: api.images,
      videoUrl: hasVideo ? api.video : null,
      thumbnailUrl: api.images.isNotEmpty ? api.images.first : null,
      caption: api.caption,
      createdAt: api.createdAt,
      likes: 0,
      comments: 0,
      shares: 0,
      isLiked: false,
      isVideo: hasVideo,
    );
  }
}


