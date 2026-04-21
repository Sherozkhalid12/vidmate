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
  /// Music track title for attribution (image posts / API).
  final String? musicName;
  /// Music artist for attribution (image posts / API).
  final String? musicTitle;
  /// Preview / CDN URL for short licensed playback (e.g. Deezer 30s).
  final String? musicPreviewUrl;
  /// Content type from API: 'post' | 'reel' | 'longVideo' | 'story'
  final String postType;
  /// Optional BlurHash string for reels/posts (instant placeholder).
  final String? blurHash;

  /// Get all image URLs. Always returns a non-null list.
  List<String> get imageUrls => _imageUrls;

  /// Thumbnail for display; uses thumbnailUrl or derived from video URL when missing.
  String? get effectiveThumbnailUrl {
    // Long-form feed: API provides [thumbnailUrl]; do not substitute heuristic URLs
    // derived from the manifest (they look like "video frames" and often differ from art).
    if (postType == 'longVideo') {
      final api = thumbnailUrl?.trim();
      if (api != null && api.isNotEmpty) return api;
      final img = imageUrl?.trim();
      if (img != null && img.isNotEmpty) return img;
      if (videoUrl != null && videoUrl!.isNotEmpty) {
        final g = VideoThumbnailHelper.thumbnailFromVideoUrl(videoUrl!);
        if (g != null && g.isNotEmpty) return g;
      }
      return null;
    }

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
    this.musicName,
    this.musicTitle,
    this.musicPreviewUrl,
    this.postType = 'post',
    this.blurHash,
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
    String? thumb = (api.thumbnailUrl != null && api.thumbnailUrl!.trim().isNotEmpty)
        ? api.thumbnailUrl!.trim()
        : null;
    if (thumb == null || thumb.isEmpty) {
      thumb = api.images.isNotEmpty ? api.images.first : null;
    }
    if ((thumb == null || thumb.isEmpty) && hasVideo) {
      thumb = VideoThumbnailHelper.thumbnailFromVideoUrl(api.video);
    }
    return PostModel(
      id: api.id,
      author: author,
      imageUrl: api.images.isNotEmpty ? api.images.first : null,
      imageUrls: api.images,
      videoUrl: hasVideo ? api.video : null,
      thumbnailUrl: thumb,
      caption: api.caption,
      createdAt: api.createdAt,
      likes: likeCount,
      comments: api.commentsCount,
      shares: 0,
      isLiked: isLiked,
      isVideo: hasVideo,
      postType: type,
      blurHash: api.blurHash,
      musicName: api.musicName,
      musicTitle: api.musicTitle,
      musicPreviewUrl: api.musicPreviewUrl,
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
      blurHash: r.reel.blurHash,
    );
  }

  /// Hydrate from [UserStorageService] cached map (`_postToMap` shape).
  factory PostModel.fromCachedMap(Map<String, dynamic> map) {
    final authorRaw = map['author'];
    final UserModel author = authorRaw is Map
        ? UserModel.fromJson(Map<String, dynamic>.from(authorRaw))
        : authorPlaceholder(map['userId']?.toString() ?? '');
    DateTime created;
    try {
      created = DateTime.parse(map['createdAt']?.toString() ?? '');
    } catch (_) {
      created = DateTime.now();
    }
    final blur = map['blurHash']?.toString();
    Duration? videoDuration;
    final msRaw = map['videoDurationMs'];
    if (msRaw is int) {
      videoDuration = Duration(milliseconds: msRaw);
    } else if (msRaw != null) {
      final p = int.tryParse('$msRaw');
      if (p != null && p > 0) videoDuration = Duration(milliseconds: p);
    }
    return PostModel(
      id: map['id']?.toString() ?? '',
      author: author,
      imageUrl: map['imageUrl']?.toString(),
      imageUrls: (map['imageUrls'] is List)
          ? (map['imageUrls'] as List).map((e) => e.toString()).toList()
          : null,
      videoUrl: map['videoUrl']?.toString(),
      thumbnailUrl: map['thumbnailUrl']?.toString(),
      caption: map['caption']?.toString() ?? '',
      createdAt: created,
      likes: (map['likes'] is int) ? map['likes'] as int : int.tryParse('${map['likes']}') ?? 0,
      comments: (map['comments'] is int) ? map['comments'] as int : int.tryParse('${map['comments']}') ?? 0,
      shares: (map['shares'] is int) ? map['shares'] as int : int.tryParse('${map['shares']}') ?? 0,
      isLiked: map['isLiked'] == true,
      videoDuration: videoDuration,
      isVideo: map['isVideo'] == true,
      audioId: map['audioId']?.toString(),
      audioName: map['audioName']?.toString(),
      musicName: map['musicName']?.toString(),
      musicTitle: map['musicTitle']?.toString(),
      musicPreviewUrl: (map['musicPreviewUrl'] ?? map['music'])?.toString(),
      postType: map['postType']?.toString() ?? 'post',
      blurHash: (blur != null && blur.isNotEmpty) ? blur : null,
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

