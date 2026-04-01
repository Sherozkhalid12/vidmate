import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/post_model.dart';
import '../models/post_response_model.dart';
import '../models/user_model.dart';
import 'auth_provider_riverpod.dart';
import '../../services/posts/posts_service.dart';
import '../../services/storage/user_storage_service.dart';

/// Posts state
class PostsState {
  final List<PostModel> posts;
  final bool isLoading;
  final String? error;
  final Map<String, bool> likedPosts;
  final Map<String, int> likeCounts;
  final Map<String, int> commentCounts;

  PostsState({
    this.posts = const [],
    this.isLoading = false,
    this.error,
    Map<String, bool>? likedPosts,
    Map<String, int>? likeCounts,
    Map<String, int>? commentCounts,
  })  : likedPosts = likedPosts ?? {},
        likeCounts = likeCounts ?? {},
        commentCounts = commentCounts ?? {};

  PostsState copyWith({
    List<PostModel>? posts,
    bool? isLoading,
    String? error,
    Map<String, bool>? likedPosts,
    Map<String, int>? likeCounts,
    Map<String, int>? commentCounts,
    bool clearError = false,
  }) {
    return PostsState(
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      likedPosts: likedPosts ?? this.likedPosts,
      likeCounts: likeCounts ?? this.likeCounts,
      commentCounts: commentCounts ?? this.commentCounts,
    );
  }
}

/// Posts provider using Riverpod StateNotifier for super fast performance.
/// Like/comment counts come from backend; optimistic updates on user actions.
class PostsNotifier extends StateNotifier<PostsState> {
  PostsNotifier(this._ref) : super(PostsState()) {
    loadPosts();
  }

  final Ref _ref;
  final PostsService _postsService = PostsService();

  /// Load posts from API (all users, home feed). Uses backend like/comment counts.
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
      final currentUserId = _ref.read(authProvider).currentUser?.id;
      final postModels = result.posts
          .map((p) => PostModel.fromApiPost(
                p.post,
                p.author ?? PostModel.authorPlaceholder(p.post.userId),
                currentUserId: currentUserId,
              ))
          .toList();
      final likedPosts = <String, bool>{};
      final likeCounts = <String, int>{};
      final commentCounts = <String, int>{};
      for (var post in postModels) {
        likedPosts[post.id] = post.isLiked;
        likeCounts[post.id] = post.likes;
        commentCounts[post.id] = post.comments;
      }
      state = state.copyWith(
        posts: postModels,
        isLoading: false,
        likedPosts: likedPosts,
        likeCounts: likeCounts,
        commentCounts: commentCounts,
      );
      UserStorageService.instance.runInBackground(() async {
        await UserStorageService.instance.cacheUnseenFeed(posts: postModels);
      });
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Toggle like on a post (local state only). Used for revert on API failure.
  void toggleLike(String postId) {
    final currentLiked = state.likedPosts[postId] ?? false;
    final currentCount = state.likeCounts[postId] ?? 0;

    final newLikedPosts = Map<String, bool>.from(state.likedPosts);
    final newLikeCounts = Map<String, int>.from(state.likeCounts);

    newLikedPosts[postId] = !currentLiked;
    newLikeCounts[postId] = currentLiked
        ? (currentCount - 1).clamp(0, double.infinity).toInt()
        : currentCount + 1;

    final updatedPosts = _updatePostsList(
      state.posts,
      postId: postId,
      isLiked: newLikedPosts[postId],
      likes: newLikeCounts[postId],
    );
    state = state.copyWith(
      likedPosts: newLikedPosts,
      likeCounts: newLikeCounts,
      posts: updatedPosts,
    );
    UserStorageService.instance.runInBackground(() async {
      await UserStorageService.instance.cacheUnseenFeed(posts: updatedPosts);
    });
  }

  /// Toggle like with API call. Optimistic update, reverts on failure.
  Future<void> toggleLikeWithApi(String postId) async {
    toggleLike(postId);
    final result = await _postsService.likePost(postId);
    if (!result.success) {
      toggleLike(postId);
      return;
    }
    applyLikesUpdate(
      postId: postId,
      likesCount: result.likesCount,
      action: result.action,
    );
  }

  /// Apply like update from API response or socket (likes:updated).
  void applyLikesUpdate({required String postId, int? likesCount, String? action}) {
    final newLikeCounts = Map<String, int>.from(state.likeCounts);
    final newLikedPosts = Map<String, bool>.from(state.likedPosts);
    if (likesCount != null) newLikeCounts[postId] = likesCount;
    if (action == 'liked') newLikedPosts[postId] = true;
    if (action == 'unliked') newLikedPosts[postId] = false;
    final updatedPosts = _updatePostsList(
      state.posts,
      postId: postId,
      isLiked: newLikedPosts[postId],
      likes: newLikeCounts[postId],
    );
    state = state.copyWith(
      likedPosts: newLikedPosts,
      likeCounts: newLikeCounts,
      posts: updatedPosts,
    );
    UserStorageService.instance.runInBackground(() async {
      await UserStorageService.instance.cacheUnseenFeed(posts: updatedPosts);
    });
  }

  /// Increment comment count for a post (optimistic when user adds a comment).
  void incrementCommentCount(String postId) {
    final current = state.commentCounts[postId] ?? 0;
    final newCounts = Map<String, int>.from(state.commentCounts);
    newCounts[postId] = current + 1;
    state = state.copyWith(commentCounts: newCounts);
  }

  /// Decrement comment count (revert optimistic update on API failure).
  void decrementCommentCount(String postId) {
    final current = state.commentCounts[postId] ?? 0;
    if (current <= 0) return;
    final newCounts = Map<String, int>.from(state.commentCounts);
    newCounts[postId] = current - 1;
    state = state.copyWith(commentCounts: newCounts);
  }

  /// Add a newly created post to the feed (e.g. after create post API success).
  void addPost(PostModel post) {
    final newPosts = [post, ...state.posts];
    final newLikedPosts = Map<String, bool>.from(state.likedPosts);
    final newLikeCounts = Map<String, int>.from(state.likeCounts);
    final newCommentCounts = Map<String, int>.from(state.commentCounts);
    newLikedPosts[post.id] = post.isLiked;
    newLikeCounts[post.id] = post.likes;
    newCommentCounts[post.id] = post.comments;
    state = state.copyWith(
      posts: newPosts,
      likedPosts: newLikedPosts,
      likeCounts: newLikeCounts,
      commentCounts: newCommentCounts,
    );
  }

  /// Delete a post
  void deletePost(String postId) {
    final newPosts = state.posts.where((p) => p.id != postId).toList();
    final newLikedPosts = Map<String, bool>.from(state.likedPosts);
    final newLikeCounts = Map<String, int>.from(state.likeCounts);
    final newCommentCounts = Map<String, int>.from(state.commentCounts);

    newLikedPosts.remove(postId);
    newLikeCounts.remove(postId);
    newCommentCounts.remove(postId);

    state = state.copyWith(
      posts: newPosts,
      likedPosts: newLikedPosts,
      likeCounts: newLikeCounts,
      commentCounts: newCommentCounts,
    );
  }

  /// Toggle follow on a user
  void toggleFollow(String userId) {
    // Update posts to reflect follow state change
    final newPosts = state.posts.map((post) {
      if (post.author.id == userId) {
        final isFollowingNow = !post.author.isFollowing;
        final updatedFollowers = isFollowingNow
            ? post.author.followers + 1
            : (post.author.followers > 0 ? post.author.followers - 1 : 0);
        final updatedAuthor = UserModel(
          id: post.author.id,
          username: post.author.username,
          displayName: post.author.displayName,
          avatarUrl: post.author.avatarUrl,
          bio: post.author.bio,
          followers: updatedFollowers,
          following: post.author.following,
          posts: post.author.posts,
          isFollowing: isFollowingNow,
          isOnline: post.author.isOnline,
        );
        return PostModel(
          id: post.id,
          author: updatedAuthor,
          imageUrl: post.imageUrl,
          imageUrls: post.imageUrls,
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
          postType: post.postType,
        );
      }
      return post;
    }).toList();

    state = state.copyWith(posts: newPosts);
  }
}

List<PostModel> _updatePostsList(
  List<PostModel> posts, {
  required String postId,
  bool? isLiked,
  int? likes,
}) {
  if (posts.isEmpty) return posts;
  return posts
      .map((p) => p.id == postId
          ? PostModel(
              id: p.id,
              author: p.author,
              imageUrl: p.imageUrl,
              imageUrls: p.imageUrls,
              videoUrl: p.videoUrl,
              thumbnailUrl: p.thumbnailUrl,
              caption: p.caption,
              createdAt: p.createdAt,
              likes: likes ?? p.likes,
              comments: p.comments,
              shares: p.shares,
              isLiked: isLiked ?? p.isLiked,
              videoDuration: p.videoDuration,
              isVideo: p.isVideo,
              audioId: p.audioId,
              audioName: p.audioName,
              postType: p.postType,
            )
          : p)
      .toList();
}

/// Posts provider
final postsProvider = StateNotifierProvider<PostsNotifier, PostsState>((ref) {
  return PostsNotifier(ref);
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

/// Effective comment count (from backend + optimistic increments).
final postCommentCountProvider = Provider.family<int, String>((ref, postId) {
  return ref.watch(postsProvider).commentCounts[postId] ?? 0;
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

/// Notifier for one user's posts. Used by profile. Uses backend like/comment counts.
class UserPostsNotifier extends StateNotifier<UserPostsState> {
  UserPostsNotifier(this._userId, this._postsService, this._ref) : super(UserPostsState()) {
    load();
  }

  final String _userId;
  final PostsService _postsService;
  final Ref _ref;
  bool _hasLoaded = false;

  Future<void> load({bool force = false}) async {
    if (_userId.isEmpty) {
      state = state.copyWith(isLoading: false);
      return;
    }
    if (state.isLoading) return;
    if (!force && _hasLoaded && state.posts.isNotEmpty) return;
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
      final currentUserId = _ref.read(authProvider).currentUser?.id;
      final postModels = result.posts
          .map((p) => PostModel.fromApiPost(
                p.post,
                p.author ?? PostModel.authorPlaceholder(p.post.userId),
                currentUserId: currentUserId,
              ))
          .toList();
      _hasLoaded = true;
      state = state.copyWith(posts: postModels, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final userPostsProvider =
    StateNotifierProvider.family<UserPostsNotifier, UserPostsState, String>(
        (ref, userId) {
  return UserPostsNotifier(userId, PostsService(), ref);
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
    File? thumbnailFile,
    String? thumbnailUrl,
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
      thumbnailFile: thumbnailFile,
      thumbnailUrl: thumbnailUrl,
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

// --- Follow state (e.g. profile) - no setState, Riverpod only ---
enum FollowRelationshipStatus { none, pending, following }

class FollowStateNotifier
    extends StateNotifier<Map<String, FollowRelationshipStatus>> {
  FollowStateNotifier() : super({});

  void setStatus(String userId, FollowRelationshipStatus status) {
    state = {...state, userId: status};
  }
}

final followStateProvider =
    StateNotifierProvider<FollowStateNotifier,
        Map<String, FollowRelationshipStatus>>((ref) {
  return FollowStateNotifier();
});
