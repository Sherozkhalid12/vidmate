import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/story_model.dart';
import '../models/story_response_model.dart';
import '../models/user_model.dart';
import '../../services/posts/stories_service.dart';
import '../../services/storage/hive_content_store.dart';
import 'network_status_provider.dart';

/// State: stories grouped by user for UI, plus user list and loading/error.
class StoriesState {
  final Map<String, List<StoryModel>> userStoriesMap;
  final List<UserModel> users;
  final bool isLoading;
  final bool isRefreshing;
  final bool initialFetchCompleted;
  final String? error;
  final bool trayOfflineBanner;

  StoriesState({
    this.userStoriesMap = const {},
    this.users = const [],
    this.isLoading = false,
    this.isRefreshing = false,
    this.initialFetchCompleted = false,
    this.error,
    this.trayOfflineBanner = false,
  });

  StoriesState copyWith({
    Map<String, List<StoryModel>>? userStoriesMap,
    List<UserModel>? users,
    bool? isLoading,
    bool? isRefreshing,
    bool? initialFetchCompleted,
    String? error,
    bool clearError = false,
    bool? trayOfflineBanner,
  }) {
    return StoriesState(
      userStoriesMap: userStoriesMap ?? this.userStoriesMap,
      users: users ?? this.users,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      initialFetchCompleted:
          initialFetchCompleted ?? this.initialFetchCompleted,
      error: clearError ? null : (error ?? this.error),
      trayOfflineBanner: trayOfflineBanner ?? this.trayOfflineBanner,
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
    final mn = story.musicName.trim().isNotEmpty ? story.musicName.trim() : null;
    final mt = story.musicTitle.trim().isNotEmpty ? story.musicTitle.trim() : null;
    final mp = story.music.trim().isNotEmpty ? story.music.trim() : null;
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
        musicName: mn,
        musicTitle: mt,
        musicPreviewUrl: mp,
      ));
    }
  }
}

class StoriesNotifier extends StateNotifier<StoriesState> {
  StoriesNotifier(this._ref) : super(StoriesState()) {
    _tryHydrateFromHive();
    unawaited(_hydrateFromHiveRetryAsync());
  }

  final Ref _ref;
  final StoriesService _service = StoriesService();
  bool _loadInFlight = false;

  /// Debug: duplicate loads (Feature 5.8).
  static int loadStoriesInvocationCount = 0;

  void _tryHydrateFromHive() {
    if (!HiveContentStore.instance.isReady) return;
    final raw = HiveContentStore.instance.storiesTrayPayloadRaw;
    if (raw == null || raw.isEmpty) return;
    final parsed = _parseStoriesTrayRaw(raw);
    if (parsed == null) return;
    state = StoriesState(
      userStoriesMap: parsed.$1,
      users: parsed.$2,
      isLoading: false,
      isRefreshing: true,
      initialFetchCompleted: false,
      trayOfflineBanner: _ref.read(apiOfflineSignalProvider),
    );
  }

  (Map<String, List<StoryModel>>, List<UserModel>)? _parseStoriesTrayRaw(
      String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final d = Map<String, dynamic>.from(decoded);
      final entries = d['entries'];
      if (entries is! List) return null;
      final outMap = <String, List<StoryModel>>{};
      final outUsers = <UserModel>[];
      for (final e in entries) {
        if (e is! Map) continue;
        final em = Map<String, dynamic>.from(e);
        final uj = em['user'];
        final sj = em['stories'];
        if (uj is! Map || sj is! List) continue;
        final u = UserModel.fromJson(Map<String, dynamic>.from(uj));
        final list = <StoryModel>[];
        for (final sm in sj) {
          if (sm is Map) {
            list.add(StoryModel.fromCachedMap(
              Map<String, dynamic>.from(sm),
              u,
            ));
          }
        }
        if (list.isEmpty) continue;
        outUsers.add(u);
        outMap[u.id] = list;
      }
      if (outUsers.isEmpty) return null;
      return (outMap, outUsers);
    } catch (_) {
      return null;
    }
  }

  Future<void> _hydrateFromHiveRetryAsync() async {
    if (state.users.isNotEmpty) return;
    for (var i = 0; i < 8; i++) {
      if (i > 0) await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!HiveContentStore.instance.isReady) continue;
      final raw = HiveContentStore.instance.storiesTrayPayloadRaw;
      if (raw == null || raw.isEmpty) return;
      final parsed = _parseStoriesTrayRaw(raw);
      if (parsed == null) return;
      if (state.users.isNotEmpty) return;
      state = StoriesState(
        userStoriesMap: parsed.$1,
        users: parsed.$2,
        isLoading: false,
        isRefreshing: true,
        initialFetchCompleted: false,
        trayOfflineBanner: _ref.read(apiOfflineSignalProvider),
      );
      return;
    }
  }

  Future<void> _persistToHive() async {
    if (!HiveContentStore.instance.isReady) return;
    if (state.users.isEmpty) return;
    final entries = <Map<String, dynamic>>[];
    for (final u in state.users) {
      final stories = state.userStoriesMap[u.id] ?? [];
      if (stories.isEmpty) continue;
      entries.add({
        'user': u.toJson(),
        'stories': stories.map((s) => s.toCachedMap()).toList(),
      });
    }
    if (entries.isEmpty) return;
    await HiveContentStore.instance.saveStoriesTray({'entries': entries});
  }

  /// [forceNetwork] true: still show cached tray while refreshing (SWR).
  Future<void> loadStories() async {
    loadStoriesInvocationCount++;
    if (_loadInFlight) return;
    _loadInFlight = true;

    final hasCache = state.users.isNotEmpty;
    if (!hasCache) {
      state = state.copyWith(
        isLoading: true,
        isRefreshing: false,
        clearError: true,
        trayOfflineBanner: _ref.read(apiOfflineSignalProvider),
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        isRefreshing: true,
        clearError: true,
        trayOfflineBanner: _ref.read(apiOfflineSignalProvider),
      );
    }

    try {
      final result = await _service.getStories();
      if (!result.success) {
        state = state.copyWith(
          isLoading: false,
          isRefreshing: false,
          initialFetchCompleted: true,
          error: hasCache
              ? null
              : (result.errorMessage ?? 'Failed to load stories'),
          trayOfflineBanner: hasCache &&
              (result.errorMessage?.toLowerCase().contains('internet') ==
                      true ||
                  result.errorMessage?.toLowerCase().contains('connection') ==
                      true),
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
        isRefreshing: false,
        initialFetchCompleted: true,
        clearError: true,
        trayOfflineBanner: false,
      );
      _ref.read(apiOfflineSignalProvider.notifier).state = false;
      await _persistToHive();
    } on DioException catch (e) {
      final conn = e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout;
      if (conn) {
        _ref.read(apiOfflineSignalProvider.notifier).state = true;
      }
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        initialFetchCompleted: true,
        error: hasCache ? null : (e.message ?? 'Network error'),
        trayOfflineBanner: hasCache && conn,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        initialFetchCompleted: true,
        error: hasCache ? null : e.toString(),
      );
    } finally {
      _loadInFlight = false;
    }
  }

  Future<void> refresh() => loadStories();
}

final storiesProvider =
    StateNotifierProvider<StoriesNotifier, StoriesState>((ref) {
  ref.keepAlive();
  return StoriesNotifier(ref);
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

final storiesRefreshingProvider = Provider<bool>((ref) {
  return ref.watch(storiesProvider).isRefreshing;
});

final storiesErrorProvider = Provider<String?>((ref) {
  return ref.watch(storiesProvider).error;
});
