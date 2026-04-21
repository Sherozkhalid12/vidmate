import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Dominant inline tile for long-video feed (visibility-driven).
@immutable
class LongVideoAutoplayManagerState {
  final String? dominantVideoId;
  final bool isEnabled;

  const LongVideoAutoplayManagerState({
    this.dominantVideoId,
    this.isEnabled = true,
  });
}

/// Picks the most visible tile; hysteresis avoids rapid swaps at 50/50 scroll.
class LongVideoAutoplayManager extends StateNotifier<LongVideoAutoplayManagerState> {
  LongVideoAutoplayManager() : super(const LongVideoAutoplayManagerState());

  final Map<String, double> _ratios = {};
  /// 0 = top of viewport, 1 = bottom — used to prefer the tile in the upper half
  /// when two clips are both highly visible.
  final Map<String, double> _verticalAnchor = {};
  final Map<String, int> _above60Streak = {};

  static const double _kUpperHalfBias = 0.18;

  double _sortScore(String videoId) {
    final fr = _ratios[videoId] ?? 0.0;
    final anchor = _verticalAnchor[videoId] ?? 0.5;
    return fr + _kUpperHalfBias * (1.0 - anchor);
  }

  /// First dominant pick: require a clearly visible strip (not a sliver of the row below).
  static const double _kAdoptWhenBlank = 0.58;
  static const double _kAdoptThreshold = 0.52;
  static const double _kSwitchThreshold = 0.66;
  static const double _kDropThreshold = 0.35;
  static const double _kHardDropThreshold = 0.22;
  static const double _kAggressiveSwitchThreshold = 0.82;

  String? _bestAbove(double minFraction) {
    String? bestId;
    var bestScore = -1.0;
    for (final e in _ratios.entries) {
      if (e.value < minFraction) continue;
      final s = _sortScore(e.key);
      if (s > bestScore) {
        bestScore = s;
        bestId = e.key;
      }
    }
    return bestId;
  }

  void reportVisibility(
    String videoId,
    double visibleFraction, {
    double verticalAnchorNorm = 0.5,
  }) {
    if (!state.isEnabled) return;

    final normalized = visibleFraction.clamp(0.0, 1.0);
    _ratios[videoId] = normalized;
    _verticalAnchor[videoId] = verticalAnchorNorm.clamp(0.0, 1.0);

    if (normalized >= _kSwitchThreshold) {
      _above60Streak[videoId] = (_above60Streak[videoId] ?? 0) + 1;
    } else {
      _above60Streak[videoId] = 0;
    }

    final current = state.dominantVideoId;
    final curFr = current != null ? (_ratios[current] ?? 0.0) : 0.0;

    String? next = current;

    if (current == null) {
      final cand = _bestAbove(_kAdoptWhenBlank);
      if (cand != null) {
        next = cand;
      }
    } else if (curFr < _kDropThreshold) {
      final cand = _bestAbove(_kDropThreshold);
      if (cand != null) {
        next = cand;
      } else {
        next = curFr < _kHardDropThreshold ? null : current;
      }
    } else {
      final challenging = _bestAbove(_kSwitchThreshold);
      final chaFr = challenging != null ? (_ratios[challenging] ?? 0.0) : 0.0;
      final chaAnchor = challenging != null ? (_verticalAnchor[challenging] ?? 0.5) : 1.0;
      final curAnchor = _verticalAnchor[current] ?? 0.5;
      // Prefer staying on the upper tile unless the challenger is clearly more
      // visible or has been strongly above threshold for multiple frames.
      final anchorFavorsChallenger = chaAnchor < curAnchor - 0.04;
      final fractionFavorsChallenger = chaFr - curFr >= 0.16;
      if (challenging != null &&
          challenging != current &&
          chaFr >= 0.58 &&
          (anchorFavorsChallenger || fractionFavorsChallenger) &&
          (((chaFr) >= _kAggressiveSwitchThreshold) ||
              (((chaFr - curFr) >= 0.12) &&
                  ((_above60Streak[challenging] ?? 0) >= 1)) ||
              ((_above60Streak[challenging] ?? 0) >= 2))) {
        next = challenging;
      }
    }

    if (next != state.dominantVideoId) {
      state = LongVideoAutoplayManagerState(
        dominantVideoId: next,
        isEnabled: state.isEnabled,
      );
    }
  }

  void removeVideo(String videoId) {
    _ratios.remove(videoId);
    _verticalAnchor.remove(videoId);
    _above60Streak.remove(videoId);
    if (state.dominantVideoId == videoId) {
      final replacement = _bestAbove(0.45);
      state = LongVideoAutoplayManagerState(
        dominantVideoId: replacement,
        isEnabled: state.isEnabled,
      );
    }
  }

  void disable() {
    _ratios.clear();
    _verticalAnchor.clear();
    _above60Streak.clear();
    state = const LongVideoAutoplayManagerState(isEnabled: false);
  }

  void enable() {
    _ratios.clear();
    _verticalAnchor.clear();
    _above60Streak.clear();
    state = const LongVideoAutoplayManagerState(isEnabled: true);
  }

  /// When [VisibilityDetector] has not fired yet, seed the first row so feed
  /// autoplay can start without waiting on a null [dominantVideoId].
  void adoptHeadIfUnset(String videoId) {
    if (!state.isEnabled) return;
    if (state.dominantVideoId != null) return;
    _ratios[videoId] = 0.78;
    _verticalAnchor[videoId] = 0.06;
    state = LongVideoAutoplayManagerState(
      dominantVideoId: videoId,
      isEnabled: state.isEnabled,
    );
  }
}

final longVideoAutoplayManagerProvider =
    StateNotifierProvider<LongVideoAutoplayManager, LongVideoAutoplayManagerState>(
  (ref) {
    ref.keepAlive();
    return LongVideoAutoplayManager();
  },
);
