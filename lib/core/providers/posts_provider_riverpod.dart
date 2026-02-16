import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/post_model.dart';
import '../models/post_response_model.dart';
import '../models/user_model.dart';
import 'auth_provider_riverpod.dart';
import '../../services/posts/posts_service.dart';

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

  final PostsService _postsService = PostsService();

  /// Load posts from API (all users, home feed).
  Future<void> loadPosts() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final result = await _postsService.getPosts();
      if (!result.success) {
        state = state.copyWith(
          isLoading: false,
          error: result.errorMessage ?? 'Failed to load posts',
        );
        return;
      }
      final postModels = result.posts
          .map((p) => PostModel.fromApiPost(
                p.post,
                p.author ?? PostModel.authorPlaceholder(p.post.userId),
              ))
          .toList();
      final likedPosts = <String, bool>{};
      final likeCounts = <String, int>{};
      for (var post in postModels) {
        likedPosts[post.id] = post.isLiked;
        likeCounts[post.id] = post.likes;
      }
      state = state.copyWith(
        posts: postModels,
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

  /// Add a newly created post to the feed (e.g. after create post API success).
  void addPost(PostModel post) {
    final newPosts = [post, ...state.posts];
    final newLikedPosts = Map<String, bool>.from(state.likedPosts);
    final newLikeCounts = Map<String, int>.from(state.likeCounts);
    newLikedPosts[post.id] = post.isLiked;
    newLikeCounts[post.id] = post.likes;
    state = state.copyWith(
      posts: newPosts,
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

// --- User posts (profile) ---

/// State for a single user's posts (profile page).
class UserPostsState {
  final List<PostModel> posts;
  final bool isLoading;
  final String? error;

  UserPostsState({
    this.posts = const [],
    this.isLoading = false,
    this.error,
  });

  UserPostsState copyWith({
    List<PostModel>? posts,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return UserPostsState(
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Notifier for one user's posts. Used by profile.
class UserPostsNotifier extends StateNotifier<UserPostsState> {
  UserPostsNotifier(this._userId, this._postsService) : super(UserPostsState()) {
    load();
  }

  final String _userId;
  final PostsService _postsService;

  Future<void> load() async {
    if (_userId.isEmpty) {
      state = state.copyWith(isLoading: false);
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _postsService.getUserPost(_userId);
      if (!result.success) {
        state = state.copyWith(
          isLoading: false,
          error: result.errorMessage ?? 'Failed to load posts',
        );
        return;
      }
      final postModels = result.posts
          .map((p) => PostModel.fromApiPost(
                p.post,
                p.author ?? PostModel.authorPlaceholder(p.post.userId),
              ))
          .toList();
      state = state.copyWith(posts: postModels, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final userPostsProvider = StateNotifierProvider.autoDispose
    .family<UserPostsNotifier, UserPostsState, String>((ref, userId) {
  return UserPostsNotifier(userId, PostsService());
});

// --- Create Post (Riverpod only) ---

/// State for create post flow: loading and error only.
class CreatePostState {
  final bool isCreating;
  final String? error;

  CreatePostState({this.isCreating = false, this.error});

  CreatePostState copyWith({bool? isCreating, String? error, bool clearError = false}) {
    return CreatePostState(
      isCreating: isCreating ?? this.isCreating,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Notifier for create post. Calls PostsService and updates feed on success.
class CreatePostNotifier extends StateNotifier<CreatePostState> {
  CreatePostNotifier(this._ref) : super(CreatePostState());
  final Ref _ref;
  final PostsService _postsService = PostsService();

  Future<bool> createPost({
    List<File>? images,
    File? video,
    String? caption,
    List<String>? locations,
    List<String>? taggedUsers,
    List<String>? feelings,
  }) async {
    if (state.isCreating) {
      debugPrint('[CreatePost] ignored duplicate submit (already creating)');
      return false;
    }
    debugPrint('[CreatePost] upload started');
    state = state.copyWith(isCreating: true, clearError: true);

    final imageList = images ?? [];
    final params = CreatePostParams(
      images: imageList,
      video: video,
      caption: caption?.trim().isEmpty == true ? "" : caption,
      locations: locations ?? [],
      taggedUsers: taggedUsers ?? [],
      feelings: feelings ?? [],
    );
    debugPrint('[CreatePost] params: ${imageList.length} image(s), video: ${video != null}, caption: ${caption != null && caption.trim().isNotEmpty}');

    final result = await _postsService.createPost(params);

    if (!result.success) {
      debugPrint('[CreatePost] failed: ${result.errorMessage}');
      state = state.copyWith(
        isCreating: false,
        error: result.errorMessage ?? 'Failed to create post',
      );
      return false;
    }

    final apiPost = result.data;
    if (apiPost == null) {
      debugPrint('[CreatePost] invalid response (no post data)');
      state = state.copyWith(isCreating: false, error: 'Invalid response');
      return false;
    }

    final currentUser = _ref.read(authProvider).currentUser;
    if (currentUser == null) {
      debugPrint('[CreatePost] not authenticated (no current user)');
      state = state.copyWith(isCreating: false, error: 'Not authenticated');
      return false;
    }

    final postModel = PostModel.fromApiPost(apiPost, currentUser);
    _ref.read(postsProvider.notifier).addPost(postModel);
    _ref.invalidate(userPostsProvider(currentUser.id));
    debugPrint('[CreatePost] success, post added to feed id=${apiPost.id}');
    state = state.copyWith(isCreating: false);
    return true;
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

final createPostProvider =
    StateNotifierProvider<CreatePostNotifier, CreatePostState>((ref) {
  return CreatePostNotifier(ref);
});