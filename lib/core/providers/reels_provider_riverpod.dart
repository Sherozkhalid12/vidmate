import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/mock_data_service.dart';
import '../models/post_model.dart';

/// Reels state
class ReelsState {
  final List<PostModel> reels;
  final int currentIndex;
  final bool isLoading;
  final String? error;
  final Map<String, bool> likedReels; // Track liked reels
  final Map<String, int> likeCounts; // Track like counts

  ReelsState({
    this.reels = const [],
    this.currentIndex = 0,
    this.isLoading = false,
    this.error,
    Map<String, bool>? likedReels,
    Map<String, int>? likeCounts,
  })  : likedReels = likedReels ?? {},
        likeCounts = likeCounts ?? {};

  ReelsState copyWith({
    List<PostModel>? reels,
    int? currentIndex,
    bool? isLoading,
    String? error,
    Map<String, bool>? likedReels,
    Map<String, int>? likeCounts,
    bool clearError = false,
  }) {
    return ReelsState(
      reels: reels ?? this.reels,
      currentIndex: currentIndex ?? this.currentIndex,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      likedReels: likedReels ?? this.likedReels,
      likeCounts: likeCounts ?? this.likeCounts,
    );
  }
}

/// Reels provider using Riverpod StateNotifier for super fast performance
class ReelsNotifier extends StateNotifier<ReelsState> {
  ReelsNotifier() : super(ReelsState()) {
    loadReels();
  }

  /// Load reels
  Future<void> loadReels() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final posts = MockDataService.getMockPosts();
      final videoPosts = posts.where((p) => p.isVideo).toList();
      final likedReels = <String, bool>{};
      final likeCounts = <String, int>{};

      // Initialize like states
      for (var reel in videoPosts) {
        likedReels[reel.id] = reel.isLiked;
        likeCounts[reel.id] = reel.likes;
      }

      state = state.copyWith(
        reels: videoPosts,
        isLoading: false,
        likedReels: likedReels,
        likeCounts: likeCounts,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Set current reel index
  void setCurrentIndex(int index) {
    if (index >= 0 && index < state.reels.length) {
      state = state.copyWith(currentIndex: index);
    }
  }

  /// Toggle like on a reel
  void toggleLike(String reelId) {
    final currentLiked = state.likedReels[reelId] ?? false;
    final currentCount = state.likeCounts[reelId] ?? 0;

    final newLikedReels = Map<String, bool>.from(state.likedReels);
    final newLikeCounts = Map<String, int>.from(state.likeCounts);

    newLikedReels[reelId] = !currentLiked;
    newLikeCounts[reelId] = currentLiked
        ? (currentCount - 1).clamp(0, double.infinity).toInt()
        : currentCount + 1;

    state = state.copyWith(
      likedReels: newLikedReels,
      likeCounts: newLikeCounts,
    );
  }
}

/// Reels provider
final reelsProvider = StateNotifierProvider<ReelsNotifier, ReelsState>((ref) {
  return ReelsNotifier();
});

/// Convenience providers
final reelsListProvider = Provider<List<PostModel>>((ref) {
  return ref.watch(reelsProvider).reels;
});

final currentReelIndexProvider = Provider<int>((ref) {
  return ref.watch(reelsProvider).currentIndex;
});

final reelLikedProvider = Provider.family<bool, String>((ref, reelId) {
  return ref.watch(reelsProvider).likedReels[reelId] ?? false;
});

final reelLikeCountProvider = Provider.family<int, String>((ref, reelId) {
  return ref.watch(reelsProvider).likeCounts[reelId] ?? 0;
});

