import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/post_model.dart';
import '../models/post_response_model.dart';
import '../../services/posts/posts_service.dart';
import 'auth_provider_riverpod.dart';

/// State for saved posts list and saved post IDs (for quick lookup on cards).
class SavedPostsState {
  final List<PostModel> posts;
  final Set<String> savedPostIds;
  final bool isLoading;
  final String? error;

  SavedPostsState({
    this.posts = const [],
    Set<String>? savedPostIds,
    this.isLoading = false,
    this.error,
  }) : savedPostIds = savedPostIds ?? const {};

  SavedPostsState copyWith({
    List<PostModel>? posts,
    Set<String>? savedPostIds,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return SavedPostsState(
      posts: posts ?? this.posts,
      savedPostIds: savedPostIds ?? this.savedPostIds,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Notifier for saved posts. Loads from API and tracks saved IDs for bookmark UI.
class SavedPostsNotifier extends StateNotifier<SavedPostsState> {
  SavedPostsNotifier(this._ref) : super(SavedPostsState());

  final Ref _ref;
  final PostsService _postsService = PostsService();

  Future<void> loadSavedPosts() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _postsService.getSavedPosts();
    if (!result.success) {
      state = state.copyWith(
        isLoading: false,
        error: result.errorMessage ?? 'Failed to load saved posts',
      );
      return;
    }
    final currentUserId = _ref.read(authProvider).currentUser?.id;
    final postModels = result.posts
        .map((p) => PostModel.fromApiPost(
              p.post,
              p.author ?? PostModel.authorPlaceholder(p.post.userId),
              currentUserId: currentUserId,
            ))
        .toList();
    final ids = postModels.map((p) => p.id).toSet();
    state = state.copyWith(posts: postModels, savedPostIds: ids, isLoading: false);
  }

  /// Toggle save for a post. Updates UI immediately; API runs in background. Reverts on failure.
  Future<bool> toggleSave(String postId) async {
    final wasSaved = state.savedPostIds.contains(postId);
    final newSet = Set<String>.from(state.savedPostIds);
    if (wasSaved) {
      newSet.remove(postId);
      state = state.copyWith(
        savedPostIds: newSet,
        posts: state.posts.where((p) => p.id != postId).toList(),
      );
    } else {
      newSet.add(postId);
      state = state.copyWith(savedPostIds: newSet);
    }

    final result = await _postsService.savePost(postId);
    if (result.success) {
      if (result.action == 'saved') {
        loadSavedPosts();
      }
      return true;
    }
    if (wasSaved) {
      newSet.add(postId);
      state = state.copyWith(savedPostIds: newSet);
      loadSavedPosts();
    } else {
      newSet.remove(postId);
      state = state.copyWith(savedPostIds: newSet);
    }
    return false;
  }

  /// Whether a post is saved (from last API state). Call loadSavedPosts or toggleSave to refresh.
  bool isSaved(String postId) => state.savedPostIds.contains(postId);
}

final savedPostsProvider =
    StateNotifierProvider<SavedPostsNotifier, SavedPostsState>((ref) {
  return SavedPostsNotifier(ref);
});

/// Convenience: is this post saved?
final isPostSavedProvider = Provider.family<bool, String>((ref, postId) {
  return ref.watch(savedPostsProvider).savedPostIds.contains(postId);
});
