import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/mock_data_service.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';

/// Posts state
class PostsState {
  final List<PostModel> posts;
  final bool isLoading;
  final String? error;
  final Map<String, bool> likedPosts; // Track liked posts
  final Map<String, int> likeCounts; // Track like counts

  PostsState({
    this.posts = const [],
    this.isLoading = false,
    this.error,
    Map<String, bool>? likedPosts,
    Map<String, int>? likeCounts,
  })  : likedPosts = likedPosts ?? {},
        likeCounts = likeCounts ?? {};

  PostsState copyWith({
    List<PostModel>? posts,
    bool? isLoading,
    String? error,
    Map<String, bool>? likedPosts,
    Map<String, int>? likeCounts,
    bool clearError = false,
  }) {
    return PostsState(
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      likedPosts: likedPosts ?? this.likedPosts,
      likeCounts: likeCounts ?? this.likeCounts,
    );
  }
}

/// Posts provider using Riverpod StateNotifier for super fast performance
class PostsNotifier extends StateNotifier<PostsState> {
  PostsNotifier() : super(PostsState()) {
    loadPosts();
  }

  /// Load posts
  Future<void> loadPosts() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // Simulate network delay
      await Future.delayed(const Duration(milliseconds: 500));

      final posts = MockDataService.getMockPosts();
      final likedPosts = <String, bool>{};
      final likeCounts = <String, int>{};

      // Initialize like states
      for (var post in posts) {
        likedPosts[post.id] = post.isLiked;
        likeCounts[post.id] = post.likes;
      }

      state = state.copyWith(
        posts: posts,
        isLoading: false,
        likedPosts: likedPosts,
        likeCounts: likeCounts,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Toggle like on a post
  void toggleLike(String postId) {
    final currentLiked = state.likedPosts[postId] ?? false;
    final currentCount = state.likeCounts[postId] ?? 0;

    final newLikedPosts = Map<String, bool>.from(state.likedPosts);
    final newLikeCounts = Map<String, int>.from(state.likeCounts);

    newLikedPosts[postId] = !currentLiked;
    newLikeCounts[postId] = currentLiked
        ? (currentCount - 1).clamp(0, double.infinity).toInt()
        : currentCount + 1;

    state = state.copyWith(
      likedPosts: newLikedPosts,
      likeCounts: newLikeCounts,
    );
  }

  /// Delete a post
  void deletePost(String postId) {
    final newPosts = state.posts.where((p) => p.id != postId).toList();
    final newLikedPosts = Map<String, bool>.from(state.likedPosts);
    final newLikeCounts = Map<String, int>.from(state.likeCounts);

    newLikedPosts.remove(postId);
    newLikeCounts.remove(postId);

    state = state.copyWith(
      posts: newPosts,
      likedPosts: newLikedPosts,
      likeCounts: newLikeCounts,
    );
  }

  /// Toggle follow on a user
  void toggleFollow(String userId) {
    // Update posts to reflect follow state change
    final newPosts = state.posts.map((post) {
      if (post.author.id == userId) {
        final updatedAuthor = UserModel(
          id: post.author.id,
          username: post.author.username,
          displayName: post.author.displayName,
          avatarUrl: post.author.avatarUrl,
          bio: post.author.bio,
          followers: post.author.followers,
          following: post.author.following,
          posts: post.author.posts,
          isFollowing: !post.author.isFollowing,
          isOnline: post.author.isOnline,
        );
        return PostModel(
          id: post.id,
          author: updatedAuthor,
          imageUrl: post.imageUrl,
          videoUrl: post.videoUrl,
          thumbnailUrl: post.thumbnailUrl,
          caption: post.caption,
          createdAt: post.createdAt,
          likes: post.likes,
          comments: post.comments,
          shares: post.shares,
          isLiked: post.isLiked,
          videoDuration: post.videoDuration,
          isVideo: post.isVideo,
        );
      }
      return post;
    }).toList();

    state = state.copyWith(posts: newPosts);
  }
}

/// Posts provider
final postsProvider = StateNotifierProvider<PostsNotifier, PostsState>((ref) {
  return PostsNotifier();
});

/// Convenience providers
final postsListProvider = Provider<List<PostModel>>((ref) {
  return ref.watch(postsProvider).posts;
});

final postLikedProvider = Provider.family<bool, String>((ref, postId) {
  return ref.watch(postsProvider).likedPosts[postId] ?? false;
});

final postLikeCountProvider = Provider.family<int, String>((ref, postId) {
  return ref.watch(postsProvider).likeCounts[postId] ?? 0;
});

