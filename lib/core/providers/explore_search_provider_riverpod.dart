import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/post_model.dart';
import '../models/user_model.dart';
import '../../services/search/explore_service.dart';
import 'auth_provider_riverpod.dart';

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
  return ExploreSearchNotifier(ref);
});

class ExploreSearchNotifier extends StateNotifier<ExploreSearchState> {
  ExploreSearchNotifier(this._ref)
      : super(const ExploreSearchState(recentSearches: [
          'john_doe',
          'jane_smith',
          'design',
          'tech',
        ]));

  final Ref _ref;
  Timer? _debounce;

  void setQuery(String value) {
    final next = value.trim();
    state = state.copyWith(query: next, clearError: true);
    _debounce?.cancel();
    if (next.isEmpty) {
      state = state.copyWith(
        loading: false,
        users: const [],
        posts: const [],
        reels: const [],
        longVideos: const [],
      );
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () {
      search(next);
    });
  }

  void clearQuery() {
    _debounce?.cancel();
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
  }

  void clearRecent() {
    state = state.copyWith(recentSearches: const []);
  }

  Future<void> search(String text) async {
    final query = text.trim();
    if (query.isEmpty) return;
    state = state.copyWith(loading: true, clearError: true);

    final currentUserId = _ref.read(currentUserProvider)?.id;
    try {
      final res = await _ref.read(exploreServiceProvider).search(
            text: query,
            currentUserId: currentUserId,
          );
      final recent = List<String>.from(state.recentSearches);
      if (!recent.contains(query)) {
        recent.insert(0, query);
      }
      state = state.copyWith(
        loading: false,
        users: res.users,
        posts: res.posts,
        reels: res.reels,
        longVideos: res.longVideos,
        recentSearches: recent,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: e.toString(),
      );
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
