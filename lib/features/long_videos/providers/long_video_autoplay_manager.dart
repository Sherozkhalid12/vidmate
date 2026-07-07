import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Dominant inline tile for long-video feed.
@immutable
class LongVideoAutoplayManagerState {
  final String? dominantVideoId;
  final bool isEnabled;

  const LongVideoAutoplayManagerState({
    this.dominantVideoId,
    this.isEnabled = true,
  });
}

/// Picks the feed tile whose **player** is most visible (YouTube-style).
class LongVideoAutoplayManager extends StateNotifier<LongVideoAutoplayManagerState> {
  LongVideoAutoplayManager() : super(const LongVideoAutoplayManagerState());

  final Map<String, double> _playerVisibility = {};
  Timer? _recomputeDebounce;

  /// Player must be at least this visible to win autoplay.
  static const double _playThreshold = 0.42;

  /// Keep current tile until it drops below this (hysteresis).
  static const double _holdThreshold = 0.22;

  void reportPlayerVisibility(String videoId, double visibleFraction) {
    if (!state.isEnabled) return;
    final id = videoId.trim();
    if (id.isEmpty) return;

    final fraction = visibleFraction.clamp(0.0, 1.0);
    if (fraction <= 0.001) {
      _playerVisibility.remove(id);
    } else {
      _playerVisibility[id] = fraction;
    }
    _scheduleRecompute();
  }

  void _scheduleRecompute() {
    _recomputeDebounce?.cancel();
    _recomputeDebounce = Timer(const Duration(milliseconds: 100), _recomputeDominant);
  }

  void _recomputeDominant() {
    if (!state.isEnabled) return;

    if (_playerVisibility.isEmpty) {
      _setDominantIfChanged(null);
      return;
    }

    final current = state.dominantVideoId;
    final currentFraction =
        current != null ? (_playerVisibility[current] ?? 0.0) : 0.0;

    String? bestId;
    var bestFraction = 0.0;
    for (final entry in _playerVisibility.entries) {
      if (entry.value > bestFraction) {
        bestFraction = entry.value;
        bestId = entry.key;
      }
    }

    if (bestId == null || bestFraction < _playThreshold) {
      if (current != null && currentFraction >= _holdThreshold) return;
      _setDominantIfChanged(null);
      return;
    }

    // Hysteresis: don't switch unless challenger clearly beats incumbent.
    if (current != null &&
        current != bestId &&
        currentFraction >= _holdThreshold &&
        bestFraction < currentFraction + 0.12) {
      return;
    }

    _setDominantIfChanged(bestId);
  }

  void _setDominantIfChanged(String? videoId) {
    if (videoId == state.dominantVideoId) return;
    state = LongVideoAutoplayManagerState(
      dominantVideoId: videoId,
      isEnabled: state.isEnabled,
    );
  }

  void setDominant(String? videoId) {
    if (!state.isEnabled) return;
    _setDominantIfChanged(videoId);
  }

  void removeVideo(String videoId) {
    _playerVisibility.remove(videoId);
    if (state.dominantVideoId == videoId) {
      state = LongVideoAutoplayManagerState(
        dominantVideoId: null,
        isEnabled: state.isEnabled,
      );
      _scheduleRecompute();
    }
  }

  void clearVisibilityReports() {
    _playerVisibility.clear();
    _recomputeDebounce?.cancel();
  }

  void disable() {
    clearVisibilityReports();
    state = const LongVideoAutoplayManagerState(isEnabled: false);
  }

  void enable() {
    state = const LongVideoAutoplayManagerState(isEnabled: true);
  }

  @override
  void dispose() {
    _recomputeDebounce?.cancel();
    super.dispose();
  }
}

final longVideoAutoplayManagerProvider =
    StateNotifierProvider<LongVideoAutoplayManager, LongVideoAutoplayManagerState>(
  (ref) {
    ref.keepAlive();
    return LongVideoAutoplayManager();
  },
);
