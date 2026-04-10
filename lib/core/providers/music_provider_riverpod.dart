import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/music_model.dart';
import '../../services/music/music_service.dart';
import '../../services/storage/user_storage_service.dart';

class MusicState {
  final List<MusicModel> tracks;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final int page;
  final bool hasMore;
  final int total;
  final bool initialFetchCompleted;

  const MusicState({
    this.tracks = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.page = 0,
    this.hasMore = true,
    this.total = 0,
    this.initialFetchCompleted = false,
  });

  MusicState copyWith({
    List<MusicModel>? tracks,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    int? page,
    bool? hasMore,
    int? total,
    bool? initialFetchCompleted,
    bool clearError = false,
  }) {
    return MusicState(
      tracks: tracks ?? this.tracks,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      total: total ?? this.total,
      initialFetchCompleted: initialFetchCompleted ?? this.initialFetchCompleted,
    );
  }
}

/// Music provider using Riverpod StateNotifier for API-backed tracks.
class MusicNotifier extends StateNotifier<MusicState> {
  MusicNotifier(this._service) : super(const MusicState()) {
    unawaited(_bootstrap());
  }

  final MusicService _service;

  Future<void> _bootstrap() async {
    final cached = await UserStorageService.instance.getCachedMusicLibraryPage1();
    if (cached != null && cached.tracks.isNotEmpty) {
      state = MusicState(
        tracks: cached.tracks,
        page: cached.page,
        hasMore: cached.hasMore,
        total: cached.total,
        initialFetchCompleted: false,
      );
    }
    await loadInitial();
  }

  /// Load first page (skips if a completed fetch already populated the list).
  Future<void> loadInitial() async {
    if (state.initialFetchCompleted && state.tracks.isNotEmpty) return;
    if (state.isLoading) return;
    await _loadPage(reset: true);
  }

  Future<void> refresh() async {
    await _loadPage(reset: true);
  }

  /// Load next page for pagination.
  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || state.isLoading) return;
    await _loadPage(reset: false);
  }

  Future<void> _loadPage({required bool reset}) async {
    final nextPage = reset ? 1 : (state.page + 1);
    final hadLocal = state.tracks.isNotEmpty;

    if (reset) {
      state = state.copyWith(
        isLoading: !hadLocal,
        isLoadingMore: false,
        clearError: true,
        page: 0,
        hasMore: true,
      );
    } else {
      state = state.copyWith(
        isLoadingMore: true,
        clearError: true,
      );
    }

    final result = await _service.getMusics(page: nextPage);
    if (!result.success) {
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        error: result.errorMessage ?? 'Failed to load music',
        initialFetchCompleted: true,
      );
      return;
    }

    final existing = reset ? <MusicModel>[] : state.tracks;
    final combined = [...existing, ...result.tracks];
    final total = result.total;
    final hasMore = total == 0 ? result.tracks.isNotEmpty : combined.length < total;

    state = state.copyWith(
      tracks: combined,
      isLoading: false,
      isLoadingMore: false,
      page: nextPage,
      hasMore: hasMore,
      total: total,
      initialFetchCompleted: true,
    );

    if (reset && combined.isNotEmpty) {
      UserStorageService.instance.runInBackground(() async {
        await UserStorageService.instance.cacheMusicLibraryPage1(
          tracks: combined,
          total: total,
          page: nextPage,
          hasMore: hasMore,
        );
      });
    }
  }

  /// Simple local like toggle for UI only (no API yet).
  void toggleLike(String id) {
    final idx = state.tracks.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    final current = state.tracks[idx];
    final updated = current.copyWith(
      isLiked: !current.isLiked,
      likes: current.isLiked
          ? (current.likes - 1).clamp(0, 1 << 31)
          : current.likes + 1,
    );
    final list = List<MusicModel>.from(state.tracks);
    list[idx] = updated;
    state = state.copyWith(tracks: list);
  }
}

final musicProvider =
    StateNotifierProvider<MusicNotifier, MusicState>((ref) {
  return MusicNotifier(MusicService());
});

