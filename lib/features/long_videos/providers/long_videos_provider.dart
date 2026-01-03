import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../core/models/post_model.dart';

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
  LongVideosNotifier() : super(LongVideosState()) {
    loadVideos();
  }

  /// Load initial videos
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
      // Simulate network delay
      await Future.delayed(const Duration(milliseconds: 500));

      // Get video posts from mock data
      final allPosts = MockDataService.getMockPosts();
      final videoPosts = allPosts.where((p) => p.isVideo).toList();

      // Generate additional mock videos for better feed
      final additionalVideos = List.generate(10, (index) {
        final userIndex = index % MockDataService.mockUsers.length;
        return PostModel(
          id: 'video_${index + 10}',
          author: MockDataService.mockUsers[userIndex],
          videoUrl:
              'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
          thumbnailUrl: 'https://picsum.photos/800/450?random=${index + 100}',
          caption: 'Amazing video content ${index + 1}',
          createdAt: DateTime.now().subtract(Duration(hours: index)),
          likes: (index + 1) * 1000,
          comments: (index + 1) * 50,
          shares: (index + 1) * 20,
          isLiked: false,
          videoDuration:
              Duration(minutes: index % 10 + 1, seconds: (index * 7) % 60),
          isVideo: true,
        );
      });

      final allVideos = [...videoPosts, ...additionalVideos];
      final likedVideos = <String, bool>{};
      final likeCounts = <String, int>{};

      // Initialize like states
      for (var video in allVideos) {
        likedVideos[video.id] = video.isLiked;
        likeCounts[video.id] = video.likes;
      }

      state = state.copyWith(
        videos: allVideos,
        isLoading: false,
        likedVideos: likedVideos,
        likeCounts: likeCounts,
        hasMore: false, // For now, all videos loaded at once
        currentPage: 1,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Load more videos (pagination)
  Future<void> loadMoreVideos() async {
    if (state.isLoading || !state.hasMore) return;

    state = state.copyWith(isLoading: true);

    try {
      // Simulate network delay
      await Future.delayed(const Duration(milliseconds: 500));

      // For now, we don't have more videos to load
      // In a real app, this would fetch from API
      state = state.copyWith(
        isLoading: false,
        hasMore: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
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

    state = state.copyWith(
      likedVideos: newLikedVideos,
      likeCounts: newLikeCounts,
    );
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

/// Long Videos Provider
final longVideosProvider =
    StateNotifierProvider<LongVideosNotifier, LongVideosState>((ref) {
  return LongVideosNotifier();
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

