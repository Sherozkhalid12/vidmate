import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/comment_model.dart';
import '../../services/posts/posts_service.dart';
import 'auth_provider_riverpod.dart';
import 'posts_provider_riverpod.dart';

/// State for comments of a single post.
class CommentsState {
  final List<PostComment> comments;
  final bool isLoading;
  final bool isSending;
  final String? error;

  CommentsState({
    this.comments = const [],
    this.isLoading = false,
    this.isSending = false,
    this.error,
  });

  CommentsState copyWith({
    List<PostComment>? comments,
    bool? isLoading,
    bool? isSending,
    String? error,
    bool clearError = false,
  }) {
    return CommentsState(
      comments: comments ?? this.comments,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Notifier for a single post's comments. Loads from API and appends new from socket.
class CommentsNotifier extends StateNotifier<CommentsState> {
  CommentsNotifier(this.postId, this._postsService, this._ref) : super(CommentsState()) {
    loadComments();
  }

  final String postId;
  final PostsService _postsService;
  final Ref _ref;

  Future<void> loadComments() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _postsService.getComments(postId);
    if (result.success) {
      final deduped = _dedupeComments(result.comments);
      state = state.copyWith(comments: deduped, isLoading: false);
    } else {
      state = state.copyWith(
        isLoading: false,
        error: result.errorMessage ?? 'Failed to load comments',
      );
    }
  }

  /// Add a new comment from API response or socket. Prepends to list.
  void appendComment(PostComment comment) {
    if (comment.postId != postId) return;
    final existsById = state.comments.any((c) => c.id == comment.id);
    if (existsById) return;
    final pendingMatch = state.comments.indexWhere(
      (c) => c.id.startsWith('pending-') && _isSimilarComment(c, comment),
    );
    if (pendingMatch != -1) {
      final updated = List<PostComment>.from(state.comments)
        ..removeAt(pendingMatch);
      state = state.copyWith(comments: [comment, ...updated]);
      return;
    }
    final existsSimilar = state.comments.any((c) => _isSimilarComment(c, comment));
    if (existsSimilar) return;
    state = state.copyWith(comments: [comment, ...state.comments]);
  }

  void _removePendingComment() {
    final without = state.comments.where((c) => !c.id.startsWith('pending-')).toList();
    if (without.length != state.comments.length) {
      state = state.copyWith(comments: without);
    }
  }

  /// Post a new comment. UI updates immediately with optimistic comment; API runs in background. Reverts on failure.
  Future<bool> addComment(String content) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return false;

    final user = _ref.read(authProvider).currentUser;
    final now = DateTime.now();
    final pendingId = 'pending-${now.millisecondsSinceEpoch}';
    final pending = PostComment(
      id: pendingId,
      postId: postId,
      userId: user?.id ?? '',
      content: trimmed,
      username: user?.username ?? user?.displayName ?? '',
      profilePicture: user?.avatarUrl ?? '',
      likes: const [],
      createdAt: now,
      updatedAt: now,
    );

    state = state.copyWith(
      comments: [pending, ...state.comments],
      isSending: true,
      clearError: true,
    );
    _ref.read(postsProvider.notifier).incrementCommentCount(postId);

    final result = await _postsService.addComment(postId: postId, content: trimmed);
    state = state.copyWith(isSending: false);

    if (result.success && result.comment != null) {
      _removePendingComment();
      appendComment(result.comment!);
      return true;
    }
    _removePendingComment();
    _ref.read(postsProvider.notifier).decrementCommentCount(postId);
    state = state.copyWith(
      error: result.errorMessage ?? 'Failed to post comment',
    );
    return false;
  }
}

List<PostComment> _dedupeComments(List<PostComment> comments) {
  final result = <PostComment>[];
  for (final c in comments) {
    final exists = result.any((r) => r.id == c.id || _isSimilarComment(r, c));
    if (!exists) result.add(c);
  }
  return result;
}

bool _isSimilarComment(PostComment a, PostComment b) {
  if (a.userId != b.userId) return false;
  if (a.content != b.content) return false;
  final diff = a.createdAt.difference(b.createdAt).inSeconds.abs();
  return diff <= 5;
}

/// Provider factory for comments by postId. Auto-dispose when no longer watched.
final commentsProvider = StateNotifierProvider.autoDispose.family<
    CommentsNotifier, CommentsState, String>((ref, postId) {
  return CommentsNotifier(postId, PostsService(), ref);
});
