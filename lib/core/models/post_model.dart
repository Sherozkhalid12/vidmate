import 'user_model.dart';
import 'post_response_model.dart';
import 'reel_response_model.dart';
import 'long_video_response_model.dart';
import '../utils/video_thumbnail_helper.dart';

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
  /// Content type from API: 'post' | 'reel' | 'longVideo' | 'story'
  final String postType;

  /// Get all image URLs. Always returns a non-null list.
  List<String> get imageUrls => _imageUrls;

  /// Thumbnail for display; uses thumbnailUrl or derived from video URL when missing.
  String? get effectiveThumbnailUrl {
    // Some reel thumbnails come from a protected CDN path (e.g. /posts/videos/.../thumbnail.jpg)
    // that can return 403. Prefer a generated thumbnail from the video URL when available.
    final generated = (videoUrl != null && videoUrl!.isNotEmpty)
        ? VideoThumbnailHelper.thumbnailFromVideoUrl(videoUrl!)
        : null;

    if (thumbnailUrl != null &&
        thumbnailUrl!.isNotEmpty &&
        // If the provided thumbnail is in a "posts/videos" path, it often 403s—use generated instead.
        !thumbnailUrl!.contains('/posts/videos/')) {
      return thumbnailUrl;
    }

    if (generated != null && generated.isNotEmpty) return generated;
    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) return thumbnailUrl;
    return imageUrl;
  }

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
    this.postType = 'post',
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

  /// Build feed post from API post and author. Uses backend like/comment counts.
  /// [currentUserId] used to set isLiked from api.likes; pass null to default false.
  static PostModel fromApiPost(ApiPost api, UserModel author, {String? currentUserId}) {
    final hasVideo = api.video.isNotEmpty;
    final type = api.type.isEmpty ? 'post' : api.type;
    final likeCount = api.likes.length;
    final isLiked = currentUserId != null && currentUserId.isNotEmpty && api.likes.contains(currentUserId);
    return PostModel(
      id: api.id,
      author: author,
      imageUrl: api.images.isNotEmpty ? api.images.first : null,
      imageUrls: api.images,
      videoUrl: hasVideo ? api.video : null,
      thumbnailUrl: api.images.isNotEmpty ? api.images.first : null,
      caption: api.caption,
      createdAt: api.createdAt,
      likes: likeCount,
      comments: api.commentsCount,
      shares: 0,
      isLiked: isLiked,
      isVideo: hasVideo,
      postType: type,
    );
  }

  /// Build post from API reel (for reels feed). Uses backend likes array length and Comments count.
  static PostModel fromReel(ReelWithUserModel r, {String? currentUserId}) {
    final author = r.user != null
        ? UserModel(
            id: r.user!.id,
            username: r.user!.username,
            displayName: r.user!.displayName,
            avatarUrl: r.user!.avatarUrl,
            verified: r.user!.verified,
            privateAccount: r.user!.privateAccount,
            showActivityStatus: r.user!.showActivityStatus,
            allowComments: r.user!.allowComments,
            allowLikes: r.user!.allowLikes,
            allowShares: r.user!.allowShares,
            allowStoryReplies: r.user!.allowStoryReplies,
          )
        : authorPlaceholder(r.reel.userId);
    final likeCount = r.reel.likes.length;
    final isLiked = currentUserId != null &&
        currentUserId.isNotEmpty &&
        r.reel.likes.contains(currentUserId);
    return PostModel(
      id: r.reel.id,
      author: author,
      videoUrl: r.reel.videoUrl,
      thumbnailUrl: r.reel.thumbnailUrl,
      caption: r.reel.caption,
      createdAt: r.reel.createdAt,
      likes: likeCount,
      comments: r.reel.commentsCount,
      isLiked: isLiked,
      isVideo: true,
      postType: 'reel',
    );
  }

  /// Build post from API long video (for long videos feed). Uses backend likes array length and Comments count.
  static PostModel fromLongVideo(LongVideoWithUserModel v, {String? currentUserId}) {
    final author = v.user != null
        ? UserModel(
            id: v.user!.id,
            username: v.user!.username,
            displayName: v.user!.displayName,
            avatarUrl: v.user!.avatarUrl,
            verified: v.user!.verified,
            privateAccount: v.user!.privateAccount,
            showActivityStatus: v.user!.showActivityStatus,
            allowComments: v.user!.allowComments,
            allowLikes: v.user!.allowLikes,
            allowShares: v.user!.allowShares,
            allowStoryReplies: v.user!.allowStoryReplies,
          )
        : authorPlaceholder(v.video.userId);
    final likeCount = v.video.likes.length;
    final isLiked = currentUserId != null &&
        currentUserId.isNotEmpty &&
        v.video.likes.contains(currentUserId);
    return PostModel(
      id: v.video.id,
      author: author,
      videoUrl: v.video.videoUrl,
      thumbnailUrl: v.video.thumbnailUrl,
      caption: v.video.caption,
      createdAt: v.video.createdAt,
      likes: likeCount,
      comments: v.video.commentsCount,
      isLiked: isLiked,
      isVideo: true,
      postType: 'longVideo',
    );
  }
}

