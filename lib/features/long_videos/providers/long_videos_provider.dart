import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/post_model.dart';
import '../../../core/perf/long_video_perf_metrics.dart';
import '../../../core/providers/auth_provider_riverpod.dart';
import '../../../core/providers/network_status_provider.dart';
import '../../../services/posts/long_video_service.dart';
import '../../../services/posts/posts_service.dart';
import '../../../services/storage/user_storage_service.dart';
import '../hls_segment_prefetch.dart';

/// Long Videos State (Feature 3.2 SWR).
class LongVideosState {
  final List<PostModel> videos;
  final bool isLoading;
  final bool isRefreshing;
  final bool initialFetchCompleted;
  final String? error;
  final bool hasMore;
  final int currentPage;
  final Map<String, bool> likedVideos;
  final Map<String, int> likeCounts;
  final bool feedOfflineBanner;

  LongVideosState({
    this.videos = const [],
    this.isLoading = false,
    this.isRefreshing = false,
    this.initialFetchCompleted = false,
    this.error,
    this.hasMore = true,
    this.currentPage = 0,
    Map<String, bool>? likedVideos,
    Map<String, int>? likeCounts,
    this.feedOfflineBanner = false,
  })  : likedVideos = likedVideos ?? {},
        likeCounts = likeCounts ?? {};

  LongVideosState copyWith({
    List<PostModel>? videos,
    bool? isLoading,
    bool? isRefreshing,
    bool? initialFetchCompleted,
    String? error,
    bool? hasMore,
    int? currentPage,
    Map<String, bool>? likedVideos,
    Map<String, int>? likeCounts,
    bool clearError = false,
    bool appendVideos = false,
    bool? feedOfflineBanner,
  }) {
    return LongVideosState(
      videos: appendVideos
          ? [...this.videos, ...(videos ?? [])]
          : (videos ?? this.videos),
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      initialFetchCompleted:
      initialFetchCompleted ?? this.initialFetchCompleted,
      error: clearError ? null : (error ?? this.error),
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      likedVideos: likedVideos ?? this.likedVideos,
      likeCounts: likeCounts ?? this.likeCounts,
      feedOfflineBanner: feedOfflineBanner ?? this.feedOfflineBanner,
    );
  }
}

class LongVideosNotifier extends StateNotifier<LongVideosState> {
  LongVideosNotifier(this._ref) : super(LongVideosState()) {
    unawaited(_hydrateFromHiveAsync());
  }

  final Ref _ref;
  final LongVideoService _service = LongVideoService();
  final PostsService _postsService = PostsService();
  bool _loadVideosInFlight = false;
  CancelToken? _loadCancel;

  /// Debug: list fetch should not repeat on tab switch (Feature 3.9).
  int loadVideosInvocationCount = 0;

  Future<void> _hydrateFromHiveAsync() async {
    final sw = Stopwatch()..start();
    try {
      final maps =
      await UserStorageService.instance.getCachedUnseenLongVideos();
      if (maps.isEmpty) return;

      final hydrated = <PostModel>[];
      final likedVideos = <String, bool>{};
      final likeCounts = <String, int>{};

      for (final m in maps) {
        try {
          final p = PostModel.fromCachedMap(m);
          if (p.id.isEmpty) continue;
          if (p.videoUrl == null || p.videoUrl!.isEmpty) continue;
          hydrated.add(p);
          likedVideos[p.id] = p.isLiked;
          likeCounts[p.id] = p.likes;
        } catch (_) {}
      }
      if (hydrated.isEmpty) return;
      final dedupedHydrated = _dedupeByIdPreserveOrder(hydrated);

      if (state.videos.isNotEmpty) return;

      state = state.copyWith(
        videos: dedupedHydrated,
        isLoading: false,
        isRefreshing: true,
        likedVideos: likedVideos,
        likeCounts: likeCounts,
        clearError: true,
        feedOfflineBanner: false,
      );
    } catch (_) {}
    sw.stop();
    LongVideoPerfMetrics.logLongVideoHydrateMs(sw.elapsedMilliseconds);
  }

  /// Remove one video locally after delete or optimistic UI.
  void removeVideoById(String videoId) {
    if (videoId.isEmpty) return;
    final next = state.videos.where((v) => v.id != videoId).toList();
    final liked = Map<String, bool>.from(state.likedVideos)..remove(videoId);
    final counts = Map<String, int>.from(state.likeCounts)..remove(videoId);
    state = state.copyWith(
      videos: next,
      likedVideos: liked,
      likeCounts: counts,
    );
    UserStorageService.instance.runInBackground(() async {
      await UserStorageService.instance.cacheUnseenLongVideos(videos: next);
    });
  }

  /// Cancel in-flight list fetch (e.g. user left the tab mid-request).
  void cancelPendingNetworkLoad() {
    _loadCancel?.cancel();
    _loadCancel = null;
  }

  /// Prefetch first HLS segments for the next video after [currentVideoId] (Feature 3.5).
  void prefetchNextAfter(String currentVideoId) {
    final list = state.videos;
    final idx = list.indexWhere((v) => v.id == currentVideoId);
    if (idx < 0 || idx + 1 >= list.length) return;
    final next = list[idx + 1];
    final url = next.videoUrl;
    if (url == null || url.isEmpty) return;
    unawaited(LongVideoHlsPrefetch.prefetchHeadSegments(url));
  }

  /// Load initial videos or refresh from API.
  Future<void> loadVideos({bool refresh = false}) async {
    if (_loadVideosInFlight && !refresh) return;

    if (!refresh &&
        state.videos.isNotEmpty &&
        state.initialFetchCompleted) {
      LongVideoPerfMetrics.logLoadVideosSkipped();
      return;
    }

    _loadVideosInFlight = true;
    loadVideosInvocationCount++;
    _loadCancel?.cancel();
    _loadCancel = CancelToken();
    final cancel = _loadCancel!;

    if (refresh) {
      state = state.copyWith(
        isLoading: state.videos.isEmpty,
        isRefreshing: state.videos.isNotEmpty,
        clearError: true,
        feedOfflineBanner: false,
      );
    } else {
      final hasCache = state.videos.isNotEmpty;
      state = state.copyWith(
        isLoading: !hasCache,
        isRefreshing: hasCache,
        clearError: true,
        feedOfflineBanner: false,
      );
    }

    try {
      final result = await _service.getLongVideos(cancelToken: cancel);
      if (!result.success) {
        _ref.read(apiOfflineSignalProvider.notifier).state =
            result.connectionError;
        state = state.copyWith(
          isLoading: false,
          isRefreshing: false,
          initialFetchCompleted: true,
          error: state.videos.isEmpty
              ? (result.connectionError
              ? null
              : (result.errorMessage ?? 'Failed to load long videos'))
              : state.error,
          feedOfflineBanner: result.connectionError && state.videos.isNotEmpty,
        );
        return;
      }
      _ref.read(apiOfflineSignalProvider.notifier).state = false;

      final currentUserId = _ref.read(authProvider).currentUser?.id;
      final allVideos = result.videos
          .map((v) => PostModel.fromLongVideo(v, currentUserId: currentUserId))
          .toList();
      final dedupedVideos = _dedupeByIdPreserveOrder(allVideos);
      final likedVideos = <String, bool>{};
      final likeCounts = <String, int>{};
      for (final video in dedupedVideos) {
        likedVideos[video.id] = video.isLiked;
        likeCounts[video.id] = video.likes;
      }

      state = state.copyWith(
        videos: dedupedVideos,
        isLoading: false,
        isRefreshing: false,
        initialFetchCompleted: true,
        likedVideos: likedVideos,
        likeCounts: likeCounts,
        hasMore: false,
        currentPage: 1,
        feedOfflineBanner: false,
      );
      UserStorageService.instance.runInBackground(() async {
        await UserStorageService.instance.cacheUnseenLongVideos(videos: dedupedVideos);
      });
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        initialFetchCompleted: true,
        error: state.videos.isEmpty ? e.toString() : state.error,
      );
    } finally {
      _loadVideosInFlight = false;
    }
  }

  Future<void> loadMoreVideos() async {
    if (state.isLoading || !state.hasMore) return;
    state = state.copyWith(isLoading: true);
    try {
      state = state.copyWith(isLoading: false, hasMore: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

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

  PostModel? getVideoById(String videoId) {
    try {
      return state.videos.firstWhere((v) => v.id == videoId);
    } catch (e) {
      return null;
    }
  }
}

List<PostModel> _dedupeByIdPreserveOrder(List<PostModel> videos) {
  if (videos.length < 2) return videos;
  final seen = <String>{};
  final out = <PostModel>[];
  for (final v in videos) {
    if (v.id.isEmpty) continue;
    if (seen.add(v.id)) {
      out.add(v);
    }
  }
  return out;
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
    blurHash: v.blurHash,
  )
      : v)
      .toList();
}

final longVideosProvider =
StateNotifierProvider<LongVideosNotifier, LongVideosState>((ref) {
  ref.keepAlive();
  return LongVideosNotifier(ref);
});

final longVideosListProvider = Provider<List<PostModel>>((ref) {
  return ref.watch(longVideosProvider).videos;
});

final longVideosLoadingProvider = Provider<bool>((ref) {
  return ref.watch(longVideosProvider).isLoading;
});

final longVideosRefreshingProvider = Provider<bool>((ref) {
  return ref.watch(longVideosProvider).isRefreshing;
});

final longVideosInitialFetchCompletedProvider = Provider<bool>((ref) {
  return ref.watch(longVideosProvider).initialFetchCompleted;
});

final longVideosErrorProvider = Provider<String?>((ref) {
  return ref.watch(longVideosProvider).error;
});

final longVideosOfflineBannerProvider = Provider<bool>((ref) {
  return ref.watch(longVideosProvider).feedOfflineBanner;
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
