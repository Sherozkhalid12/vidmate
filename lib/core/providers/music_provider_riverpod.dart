import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/music_model.dart';
import '../../services/music/music_service.dart';

class MusicState {
  final List<MusicModel> tracks;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final int page;
  final bool hasMore;
  final int total;

  const MusicState({
    this.tracks = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.page = 0,
    this.hasMore = true,
    this.total = 0,
  });

  MusicState copyWith({
    List<MusicModel>? tracks,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    int? page,
    bool? hasMore,
    int? total,
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
    );
  }
}

/// Music provider using Riverpod StateNotifier for API-backed tracks.
class MusicNotifier extends StateNotifier<MusicState> {
  MusicNotifier(this._service) : super(const MusicState());

  final MusicService _service;

  /// Load first page of tracks if not already loaded.
  Future<void> loadInitial() async {
    if (state.tracks.isNotEmpty || state.isLoading) return;
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

    if (reset) {
      state = state.copyWith(
        isLoading: true,
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
    );
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

