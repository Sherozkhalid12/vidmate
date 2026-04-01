import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/post_model.dart';
import '../../services/posts/reels_service.dart';
import '../../services/posts/posts_service.dart';
import 'auth_provider_riverpod.dart';
import '../../services/storage/user_storage_service.dart';

class ReelsState {
  final List<PostModel> reels;
  final bool isLoading;
  final String? error;
  final Map<String, bool> likedReels;
  final Map<String, int> likeCounts;

  ReelsState({
    this.reels = const [],
    this.isLoading = false,
    this.error,
    Map<String, bool>? likedReels,
    Map<String, int>? likeCounts,
  })  : likedReels = likedReels ?? {},
        likeCounts = likeCounts ?? {};

  ReelsState copyWith({
    List<PostModel>? reels,
    bool? isLoading,
    String? error,
    Map<String, bool>? likedReels,
    Map<String, int>? likeCounts,
    bool clearError = false,
  }) {
    return ReelsState(
      reels: reels ?? this.reels,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      likedReels: likedReels ?? this.likedReels,
      likeCounts: likeCounts ?? this.likeCounts,
    );
  }
}

class ReelsNotifier extends StateNotifier<ReelsState> {
  ReelsNotifier(this._ref) : super(ReelsState()) {
    loadReels();
  }

  final Ref _ref;
  final ReelsService _service = ReelsService();
  final PostsService _postsService = PostsService();

  Future<void> loadReels() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _service.getReels();
      if (!result.success) {
        state = state.copyWith(
          isLoading: false,
          error: result.errorMessage ?? 'Failed to load reels',
        );
        return;
      }
      final currentUserId = _ref.read(authProvider).currentUser?.id;
      final list = result.reels
          .map((r) => PostModel.fromReel(r, currentUserId: currentUserId))
          .toList();
      final liked = <String, bool>{};
      final counts = <String, int>{};
      for (var reel in list) {
        liked[reel.id] = reel.isLiked;
        counts[reel.id] = reel.likes;
      }
      state = state.copyWith(
        reels: list,
        isLoading: false,
        likedReels: liked,
        likeCounts: counts,
      );
      UserStorageService.instance.runInBackground(() async {
        await UserStorageService.instance.cacheUnseenReels(reels: list);
      });
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> refresh() async {
    await loadReels();
  }

  void toggleLike(String reelId) {
    final current = state.likedReels[reelId] ?? false;
    final count = state.likeCounts[reelId] ?? 0;
    final newLiked = Map<String, bool>.from(state.likedReels);
    final newCounts = Map<String, int>.from(state.likeCounts);
    newLiked[reelId] = !current;
    newCounts[reelId] = current ? (count - 1).clamp(0, 0x7fffffff) : count + 1;
    final updatedReels = _updateReelsList(
      state.reels,
      reelId: reelId,
      isLiked: newLiked[reelId],
      likes: newCounts[reelId],
    );
    state = state.copyWith(
      likedReels: newLiked,
      likeCounts: newCounts,
      reels: updatedReels,
    );
    UserStorageService.instance.runInBackground(() async {
      await UserStorageService.instance.cacheUnseenReels(reels: updatedReels);
    });
  }

  Future<void> toggleLikeWithApi(String reelId) async {
    if (reelId.isEmpty) return;
    final previousLiked = state.likedReels[reelId] ?? false;
    toggleLike(reelId);
    final result = await _postsService.likePost(reelId);
    if (!result.success) {
      // revert optimistic update
      toggleLike(reelId);
      return;
    }
    final action = result.action;
    final count = result.likesCount;
    if (action == null && count == null) return;
    final updatedLiked = Map<String, bool>.from(state.likedReels);
    final updatedCounts = Map<String, int>.from(state.likeCounts);
    if (action == 'liked') updatedLiked[reelId] = true;
    if (action == 'unliked') updatedLiked[reelId] = false;
    if (count != null) updatedCounts[reelId] = count;
    final updatedReels = _updateReelsList(
      state.reels,
      reelId: reelId,
      isLiked: updatedLiked[reelId] ?? previousLiked,
      likes: updatedCounts[reelId],
    );
    state = state.copyWith(
      likedReels: updatedLiked,
      likeCounts: updatedCounts,
      reels: updatedReels,
    );
    UserStorageService.instance.runInBackground(() async {
      await UserStorageService.instance.cacheUnseenReels(reels: updatedReels);
    });
  }

  void applyLikesUpdate({required String postId, int? likesCount, String? action}) {
    if (postId.isEmpty) return;
    final updatedLiked = Map<String, bool>.from(state.likedReels);
    final updatedCounts = Map<String, int>.from(state.likeCounts);
    if (action == 'liked') updatedLiked[postId] = true;
    if (action == 'unliked') updatedLiked[postId] = false;
    if (likesCount != null) updatedCounts[postId] = likesCount;
    final updatedReels = _updateReelsList(
      state.reels,
      reelId: postId,
      isLiked: updatedLiked[postId],
      likes: updatedCounts[postId],
    );
    state = state.copyWith(
      likedReels: updatedLiked,
      likeCounts: updatedCounts,
      reels: updatedReels,
    );
    UserStorageService.instance.runInBackground(() async {
      await UserStorageService.instance.cacheUnseenReels(reels: updatedReels);
    });
  }

  void seedReels(List<PostModel> reels) {
    if (reels.isEmpty) return;
    final updatedLiked = Map<String, bool>.from(state.likedReels);
    final updatedCounts = Map<String, int>.from(state.likeCounts);
    final existing = {for (final r in state.reels) r.id};
    final merged = List<PostModel>.from(state.reels);
    for (final r in reels) {
      if (r.id.isEmpty) continue;
      updatedLiked.putIfAbsent(r.id, () => r.isLiked);
      updatedCounts.putIfAbsent(r.id, () => r.likes);
      if (!existing.contains(r.id)) {
        merged.add(r);
      }
    }
    state = state.copyWith(
      likedReels: updatedLiked,
      likeCounts: updatedCounts,
      reels: merged,
    );
    UserStorageService.instance.runInBackground(() async {
      await UserStorageService.instance.cacheUnseenReels(reels: merged);
    });
  }
}

List<PostModel> _updateReelsList(
  List<PostModel> reels, {
  required String reelId,
  bool? isLiked,
  int? likes,
}) {
  if (reels.isEmpty) return reels;
  return reels
      .map((r) => r.id == reelId
          ? PostModel(
              id: r.id,
              author: r.author,
              imageUrl: r.imageUrl,
              imageUrls: r.imageUrls,
              videoUrl: r.videoUrl,
              thumbnailUrl: r.thumbnailUrl,
              caption: r.caption,
              createdAt: r.createdAt,
              likes: likes ?? r.likes,
              comments: r.comments,
              shares: r.shares,
              isLiked: isLiked ?? r.isLiked,
              videoDuration: r.videoDuration,
              isVideo: r.isVideo,
              audioId: r.audioId,
              audioName: r.audioName,
              postType: r.postType,
            )
          : r)
      .toList();
}

final reelsProvider = StateNotifierProvider<ReelsNotifier, ReelsState>((ref) {
  return ReelsNotifier(ref);
});

final reelsListProvider = Provider<List<PostModel>>((ref) {
  return ref.watch(reelsProvider).reels;
});

final reelsLoadingProvider = Provider<bool>((ref) {
  return ref.watch(reelsProvider).isLoading;
});

final reelsErrorProvider = Provider<String?>((ref) {
  return ref.watch(reelsProvider).error;
});

final reelLikedProvider = Provider.family<bool, String>((ref, reelId) {
  return ref.watch(reelsProvider).likedReels[reelId] ?? false;
});

final reelLikeCountProvider = Provider.family<int, String>((ref, reelId) {
  return ref.watch(reelsProvider).likeCounts[reelId] ?? 0;
});

/// When set, ReelsScreen should jump to the reel with this post id (e.g. from home feed video tap).
final initialReelPostIdProvider = StateProvider<String?>((ref) => null);
