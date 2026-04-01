import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/post_model.dart';
import '../../../core/providers/auth_provider_riverpod.dart';
import '../../../services/posts/long_video_service.dart';
import '../../../services/posts/posts_service.dart';
import '../../../services/storage/user_storage_service.dart';

/// Long Videos State
class LongVideosState {
  final List<PostModel> videos;
  final bool isLoading;
  final String? error;
  final bool hasMore;
  final int currentPage;
  final Map<String, bool> likedVideos; // Track liked videos
  final Map<String, int> likeCounts; // Track like counts

  LongVideosState({
    this.videos = const [],
    this.isLoading = false,
    this.error,
    this.hasMore = true,
    this.currentPage = 0,
    Map<String, bool>? likedVideos,
    Map<String, int>? likeCounts,
  })  : likedVideos = likedVideos ?? {},
        likeCounts = likeCounts ?? {};

  LongVideosState copyWith({
    List<PostModel>? videos,
    bool? isLoading,
    String? error,
    bool? hasMore,
    int? currentPage,
    Map<String, bool>? likedVideos,
    Map<String, int>? likeCounts,
    bool clearError = false,
    bool appendVideos = false,
  }) {
    return LongVideosState(
      videos: appendVideos
          ? [...this.videos, ...(videos ?? [])]
          : (videos ?? this.videos),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      likedVideos: likedVideos ?? this.likedVideos,
      likeCounts: likeCounts ?? this.likeCounts,
    );
  }
}

/// Long Videos Notifier using Riverpod StateNotifier
class LongVideosNotifier extends StateNotifier<LongVideosState> {
  LongVideosNotifier(this._ref) : super(LongVideosState()) {
    loadVideos();
  }

  final Ref _ref;
  final LongVideoService _service = LongVideoService();
  final PostsService _postsService = PostsService();

  /// Load initial videos or refresh from API
  Future<void> loadVideos({bool refresh = false}) async {
    if (refresh) {
      state = state.copyWith(
        isLoading: true,
        clearError: true,
        currentPage: 0,
        videos: [],
      );
    } else {
      state = state.copyWith(isLoading: true, clearError: true);
    }

    try {
      final result = await _service.getLongVideos();
      if (!result.success) {
        state = state.copyWith(
          isLoading: false,
          error: result.errorMessage ?? 'Failed to load long videos',
        );
        return;
      }
      final currentUserId = _ref.read(authProvider).currentUser?.id;
      final allVideos = result.videos
          .map((v) => PostModel.fromLongVideo(v, currentUserId: currentUserId))
          .toList();
      final likedVideos = <String, bool>{};
      final likeCounts = <String, int>{};
      for (var video in allVideos) {
        likedVideos[video.id] = video.isLiked;
        likeCounts[video.id] = video.likes;
      }

      state = state.copyWith(
        videos: allVideos,
        isLoading: false,
        likedVideos: likedVideos,
        likeCounts: likeCounts,
        hasMore: false,
        currentPage: 1,
      );
      UserStorageService.instance.runInBackground(() async {
        await UserStorageService.instance.cacheUnseenLongVideos(videos: allVideos);
      });
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Load more videos (pagination-ready; API may support later)
  Future<void> loadMoreVideos() async {
    if (state.isLoading || !state.hasMore) return;
    state = state.copyWith(isLoading: true);
    try {
      // API currently returns all; keep structure for future pagination
      state = state.copyWith(isLoading: false, hasMore: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Toggle like on a video
  void toggleLike(String videoId) {
    final currentLiked = state.likedVideos[videoId] ?? false;
    final currentCount = state.likeCounts[videoId] ?? 0;

    final newLikedVideos = Map<String, bool>.from(state.likedVideos);
    final newLikeCounts = Map<String, int>.from(state.likeCounts);

    newLikedVideos[videoId] = !currentLiked;
    newLikeCounts[videoId] = currentLiked
        ? (currentCount - 1).clamp(0, double.infinity).toInt()
        : currentCount + 1;

    final updatedVideos = _updateVideosList(
      state.videos,
      videoId: videoId,
      isLiked: newLikedVideos[videoId],
      likes: newLikeCounts[videoId],
    );
    state = state.copyWith(
      likedVideos: newLikedVideos,
      likeCounts: newLikeCounts,
      videos: updatedVideos,
    );
    UserStorageService.instance.runInBackground(() async {
      await UserStorageService.instance.cacheUnseenLongVideos(videos: updatedVideos);
    });
  }

  Future<void> toggleLikeWithApi(String videoId) async {
    if (videoId.isEmpty) return;
    final previousLiked = state.likedVideos[videoId] ?? false;
    toggleLike(videoId);
    final result = await _postsService.likePost(videoId);
    if (!result.success) {
      toggleLike(videoId);
      return;
    }
    final action = result.action;
    final count = result.likesCount;
    if (action == null && count == null) return;
    final updatedLiked = Map<String, bool>.from(state.likedVideos);
    final updatedCounts = Map<String, int>.from(state.likeCounts);
    if (action == 'liked') updatedLiked[videoId] = true;
    if (action == 'unliked') updatedLiked[videoId] = false;
    if (count != null) updatedCounts[videoId] = count;
    final updatedVideos = _updateVideosList(
      state.videos,
      videoId: videoId,
      isLiked: updatedLiked[videoId] ?? previousLiked,
      likes: updatedCounts[videoId],
    );
    state = state.copyWith(
      likedVideos: updatedLiked,
      likeCounts: updatedCounts,
      videos: updatedVideos,
    );
    UserStorageService.instance.runInBackground(() async {
      await UserStorageService.instance.cacheUnseenLongVideos(videos: updatedVideos);
    });
  }

  void applyLikesUpdate({required String postId, int? likesCount, String? action}) {
    if (postId.isEmpty) return;
    final updatedLiked = Map<String, bool>.from(state.likedVideos);
    final updatedCounts = Map<String, int>.from(state.likeCounts);
    if (action == 'liked') updatedLiked[postId] = true;
    if (action == 'unliked') updatedLiked[postId] = false;
    if (likesCount != null) updatedCounts[postId] = likesCount;
    final updatedVideos = _updateVideosList(
      state.videos,
      videoId: postId,
      isLiked: updatedLiked[postId],
      likes: updatedCounts[postId],
    );
    state = state.copyWith(
      likedVideos: updatedLiked,
      likeCounts: updatedCounts,
      videos: updatedVideos,
    );
    UserStorageService.instance.runInBackground(() async {
      await UserStorageService.instance.cacheUnseenLongVideos(videos: updatedVideos);
    });
  }

  /// Get video by ID
  PostModel? getVideoById(String videoId) {
    try {
      return state.videos.firstWhere((v) => v.id == videoId);
    } catch (e) {
      return null;
    }
  }
}

List<PostModel> _updateVideosList(
  List<PostModel> videos, {
  required String videoId,
  bool? isLiked,
  int? likes,
}) {
  if (videos.isEmpty) return videos;
  return videos
      .map((v) => v.id == videoId
          ? PostModel(
              id: v.id,
              author: v.author,
              imageUrl: v.imageUrl,
              imageUrls: v.imageUrls,
              videoUrl: v.videoUrl,
              thumbnailUrl: v.thumbnailUrl,
              caption: v.caption,
              createdAt: v.createdAt,
              likes: likes ?? v.likes,
              comments: v.comments,
              shares: v.shares,
              isLiked: isLiked ?? v.isLiked,
              videoDuration: v.videoDuration,
              isVideo: v.isVideo,
              audioId: v.audioId,
              audioName: v.audioName,
              postType: v.postType,
            )
          : v)
      .toList();
}

/// Long Videos Provider
final longVideosProvider =
    StateNotifierProvider<LongVideosNotifier, LongVideosState>((ref) {
  return LongVideosNotifier(ref);
});

/// Convenience Providers
final longVideosListProvider = Provider<List<PostModel>>((ref) {
  return ref.watch(longVideosProvider).videos;
});

final longVideosLoadingProvider = Provider<bool>((ref) {
  return ref.watch(longVideosProvider).isLoading;
});

final longVideosErrorProvider = Provider<String?>((ref) {
  return ref.watch(longVideosProvider).error;
});

final longVideosHasMoreProvider = Provider<bool>((ref) {
  return ref.watch(longVideosProvider).hasMore;
});

final longVideoLikedProvider = Provider.family<bool, String>((ref, videoId) {
  return ref.watch(longVideosProvider).likedVideos[videoId] ?? false;
});

final longVideoLikeCountProvider = Provider.family<int, String>((ref, videoId) {
  return ref.watch(longVideosProvider).likeCounts[videoId] ?? 0;
});

final longVideoByIdProvider = Provider.family<PostModel?, String>((ref, videoId) {
  return ref.read(longVideosProvider.notifier).getVideoById(videoId);
});





