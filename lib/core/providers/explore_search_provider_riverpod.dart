import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/post_model.dart';
import '../models/user_model.dart';
import '../perf/explore_perf_metrics.dart';
import '../../services/search/explore_service.dart';
import '../../services/storage/hive_content_store.dart';
import 'auth_provider_riverpod.dart';
import 'network_status_provider.dart';

class ExploreSearchState {
  final String query;
  final bool loading;
  final String? error;
  final List<String> recentSearches;
  final List<UserModel> users;
  final List<PostModel> posts;
  final List<PostModel> reels;
  final List<PostModel> longVideos;

  const ExploreSearchState({
    this.query = '',
    this.loading = false,
    this.error,
    this.recentSearches = const [],
    this.users = const [],
    this.posts = const [],
    this.reels = const [],
    this.longVideos = const [],
  });

  ExploreSearchState copyWith({
    String? query,
    bool? loading,
    String? error,
    bool clearError = false,
    List<String>? recentSearches,
    List<UserModel>? users,
    List<PostModel>? posts,
    List<PostModel>? reels,
    List<PostModel>? longVideos,
  }) {
    return ExploreSearchState(
      query: query ?? this.query,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      recentSearches: recentSearches ?? this.recentSearches,
      users: users ?? this.users,
      posts: posts ?? this.posts,
      reels: reels ?? this.reels,
      longVideos: longVideos ?? this.longVideos,
    );
  }
}

final exploreServiceProvider = Provider<ExploreService>((ref) {
  return ExploreService();
});

final exploreSearchProvider =
    StateNotifierProvider<ExploreSearchNotifier, ExploreSearchState>((ref) {
  ref.keepAlive();
  return ExploreSearchNotifier(ref);
});

class ExploreSearchNotifier extends StateNotifier<ExploreSearchState> {
  ExploreSearchNotifier(this._ref) : super(const ExploreSearchState()) {
    _hydrateRecentFromHive();
  }

  final Ref _ref;
  Timer? _debounce;
  CancelToken? _searchCancel;
  int _searchGeneration = 0;

  void _hydrateRecentFromHive() {
    unawaited(_hydrateRecentFromHiveAsync());
  }

  Future<void> _hydrateRecentFromHiveAsync() async {
    for (var attempt = 0; attempt < 6; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
      if (!HiveContentStore.instance.isReady) continue;
      final list = HiveContentStore.instance.readExploreRecentSearches();
      if (list.isEmpty) return;
      state = state.copyWith(recentSearches: list);
      return;
    }
  }

  Future<void> _persistRecent(List<String> recent) async {
    if (!HiveContentStore.instance.isReady) return;
    await HiveContentStore.instance.saveExploreRecentSearches(recent);
  }

  void setQuery(String value) {
    final next = value.trim();
    state = state.copyWith(query: next, clearError: true);
    _debounce?.cancel();
    if (next.isEmpty) {
      _searchCancel?.cancel();
      state = state.copyWith(
        loading: false,
        users: const [],
        posts: const [],
        reels: const [],
        longVideos: const [],
      );
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () {
      search(next);
    });
  }

  void clearQuery() {
    _debounce?.cancel();
    _searchCancel?.cancel();
    state = state.copyWith(
      query: '',
      loading: false,
      users: const [],
      posts: const [],
      reels: const [],
      longVideos: const [],
      clearError: true,
    );
  }

  void removeRecent(String value) {
    final next = List<String>.from(state.recentSearches)..remove(value);
    state = state.copyWith(recentSearches: next);
    unawaited(_persistRecent(next));
  }

  void clearRecent() {
    state = state.copyWith(recentSearches: const []);
    unawaited(_persistRecent(const []));
  }

  Future<void> search(String text) async {
    final query = text.trim();
    if (query.isEmpty) return;

    final gen = ++_searchGeneration;
    _searchCancel?.cancel();
    _searchCancel = CancelToken();

    state = state.copyWith(loading: true, clearError: true);

    final sw = Stopwatch()..start();
    final currentUserId = _ref.read(currentUserProvider)?.id;
    try {
      final res = await _ref.read(exploreServiceProvider).search(
            text: query,
            currentUserId: currentUserId,
            cancelToken: _searchCancel,
          );
      sw.stop();
      if (gen != _searchGeneration) return;

      final recent = List<String>.from(state.recentSearches);
      if (!recent.contains(query)) {
        recent.insert(0, query);
        if (recent.length > 20) {
          recent.removeRange(20, recent.length);
        }
      }
      await _persistRecent(recent);

      state = state.copyWith(
        loading: false,
        users: res.users,
        posts: res.posts,
        reels: res.reels,
        longVideos: res.longVideos,
        recentSearches: recent,
      );
      ExplorePerfMetrics.logSearchResultsMs(sw.elapsedMilliseconds);
      _ref.read(apiOfflineSignalProvider.notifier).state = false;
    } on DioException catch (e) {
      sw.stop();
      if (e.type == DioExceptionType.cancel) {
        if (gen == _searchGeneration) {
          state = state.copyWith(loading: false);
        }
        return;
      }
      if (gen != _searchGeneration) return;
      state = state.copyWith(
        loading: false,
        error: e.message ?? 'Search failed',
      );
      _maybeSetOffline(e);
    } catch (e) {
      sw.stop();
      if (gen != _searchGeneration) return;
      state = state.copyWith(
        loading: false,
        error: e.toString(),
      );
    }
  }

  void _maybeSetOffline(Object e) {
    if (e is DioException) {
      final t = e.type;
      if (t == DioExceptionType.connectionError ||
          t == DioExceptionType.connectionTimeout ||
          t == DioExceptionType.receiveTimeout) {
        _ref.read(apiOfflineSignalProvider.notifier).state = true;
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCancel?.cancel();
    super.dispose();
  }
}
