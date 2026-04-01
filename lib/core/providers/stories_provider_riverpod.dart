import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/story_model.dart';
import '../models/story_response_model.dart';
import '../models/user_model.dart';
import '../../services/posts/stories_service.dart';

/// State: stories grouped by user for UI, plus user list and loading/error.
class StoriesState {
  final Map<String, List<StoryModel>> userStoriesMap;
  final List<UserModel> users;
  final bool isLoading;
  final String? error;

  StoriesState({
    this.userStoriesMap = const {},
    this.users = const [],
    this.isLoading = false,
    this.error,
  });

  StoriesState copyWith({
    Map<String, List<StoryModel>>? userStoriesMap,
    List<UserModel>? users,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return StoriesState(
      userStoriesMap: userStoriesMap ?? this.userStoriesMap,
      users: users ?? this.users,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

UserModel _userFromStoryUser(StoryUserModel? u, String userId) {
  if (u == null) {
    return UserModel(
      id: userId,
      username: '',
      displayName: '',
      avatarUrl: '',
      followers: 0,
      following: 0,
      posts: 0,
    );
  }
  return UserModel(
    id: u.id,
    username: u.username,
    displayName: u.displayName,
    avatarUrl: u.avatarUrl,
    followers: 0,
    following: 0,
    posts: 0,
  );
}

/// Converts API list to grouped map + user list (one entry per user with stories).
void _groupStories(
  List<StoryWithUserModel> apiStories,
  Map<String, List<StoryModel>> outMap,
  List<UserModel> outUsers,
) {
  outMap.clear();
  outUsers.clear();
  final seenUserIds = <String>{};
  for (final swu in apiStories) {
    final story = swu.story;
    final user = _userFromStoryUser(swu.user, story.userId);
    if (story.segments.isEmpty) continue;
    if (!seenUserIds.contains(user.id)) {
      seenUserIds.add(user.id);
      outUsers.add(user);
    }
    final list = outMap.putIfAbsent(user.id, () => []);
    for (var i = 0; i < story.segments.length; i++) {
      final seg = story.segments[i];
      list.add(StoryModel(
        id: '${story.id}_$i',
        author: user,
        mediaUrl: seg.url,
        isVideo: seg.isVideo,
        createdAt: story.createdAt,
        isViewed: false,
        locations: story.locations,
        taggedUsers: story.taggedUsers,
      ));
    }
  }
}

class StoriesNotifier extends StateNotifier<StoriesState> {
  StoriesNotifier() : super(StoriesState()) {
    loadStories();
  }

  final StoriesService _service = StoriesService();

  Future<void> loadStories() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _service.getStories();
      if (!result.success) {
        state = state.copyWith(
          isLoading: false,
          error: result.errorMessage ?? 'Failed to load stories',
        );
        return;
      }
      final outMap = <String, List<StoryModel>>{};
      final outUsers = <UserModel>[];
      _groupStories(result.stories, outMap, outUsers);
      state = state.copyWith(
        userStoriesMap: outMap,
        users: outUsers,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Refresh (pull-to-refresh). Invalidates and reloads.
  Future<void> refresh() async {
    await loadStories();
  }
}

final storiesProvider =
    StateNotifierProvider<StoriesNotifier, StoriesState>((ref) {
  return StoriesNotifier();
});

final storiesUserStoriesMapProvider =
    Provider<Map<String, List<StoryModel>>>((ref) {
  return ref.watch(storiesProvider).userStoriesMap;
});

final storiesUsersProvider = Provider<List<UserModel>>((ref) {
  return ref.watch(storiesProvider).users;
});

final storiesLoadingProvider = Provider<bool>((ref) {
  return ref.watch(storiesProvider).isLoading;
});

final storiesErrorProvider = Provider<String?>((ref) {
  return ref.watch(storiesProvider).error;
});
