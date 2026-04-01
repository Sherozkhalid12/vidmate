import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Single live comment model for the live stream overlay.
class LiveComment {
  final String id;
  final String username;
  final String message;
  final DateTime at;

  LiveComment({
    required this.id,
    required this.username,
    required this.message,
    required this.at,
  });
}

/// State for the live stream screen: comments, like count, and like animation triggers.
class LiveStreamState {
  final bool isLive;
  final List<LiveComment> comments;
  final int likeCount;
  final List<int> likeAnimationKeys; // Keys to trigger floating like animations

  const LiveStreamState({
    this.isLive = false,
    this.comments = const [],
    this.likeCount = 0,
    this.likeAnimationKeys = const [],
  });

  LiveStreamState copyWith({
    bool? isLive,
    List<LiveComment>? comments,
    int? likeCount,
    List<int>? likeAnimationKeys,
  }) {
    return LiveStreamState(
      isLive: isLive ?? this.isLive,
      comments: comments ?? this.comments,
      likeCount: likeCount ?? this.likeCount,
      likeAnimationKeys: likeAnimationKeys ?? this.likeAnimationKeys,
    );
  }
}

/// Notifier for live stream overlay state (comments, likes, animations).
class LiveStreamNotifier extends StateNotifier<LiveStreamState> {
  LiveStreamNotifier() : super(const LiveStreamState());

  void startLive() {
    state = state.copyWith(isLive: true, comments: [], likeCount: 0, likeAnimationKeys: []);
  }

  void endLive() {
    state = state.copyWith(isLive: false);
  }

  void addComment(String username, String message) {
    final comment = LiveComment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      username: username,
      message: message,
      at: DateTime.now(),
    );
    state = state.copyWith(
      comments: [comment, ...state.comments].take(50).toList(),
    );
  }

  void incrementLike() {
    final key = DateTime.now().millisecondsSinceEpoch;
    state = state.copyWith(
      likeCount: state.likeCount + 1,
      likeAnimationKeys: [...state.likeAnimationKeys, key],
    );
  }

  void removeLikeAnimationKey(int key) {
    state = state.copyWith(
      likeAnimationKeys: state.likeAnimationKeys.where((k) => k != key).toList(),
    );
  }
}

final liveStreamProvider =
    StateNotifierProvider<LiveStreamNotifier, LiveStreamState>((ref) {
  return LiveStreamNotifier();
});
