import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class ReelEditPlaybackState {
  const ReelEditPlaybackState({
    this.positionMs = 0,
    this.durationMs = 0,
    this.isPlaying = false,
    this.trimStart = 0,
    this.trimEnd = 1,
  });

  final int positionMs;
  final int durationMs;
  final bool isPlaying;
  final double trimStart;
  final double trimEnd;

  double get trimmedDurationMs =>
      ((durationMs * (trimEnd - trimStart)).clamp(0, durationMs)).toDouble();

  /// Position relative to trimmed segment start, in seconds.
  double get relativePositionSec {
    if (durationMs <= 0) return 0;
    final trimStartMs = durationMs * trimStart;
    return ((positionMs - trimStartMs) / 1000).clamp(0, double.infinity);
  }

  double get videoDurationSec => durationMs / 1000;

  ReelEditPlaybackState copyWith({
    int? positionMs,
    int? durationMs,
    bool? isPlaying,
    double? trimStart,
    double? trimEnd,
  }) {
    return ReelEditPlaybackState(
      positionMs: positionMs ?? this.positionMs,
      durationMs: durationMs ?? this.durationMs,
      isPlaying: isPlaying ?? this.isPlaying,
      trimStart: trimStart ?? this.trimStart,
      trimEnd: trimEnd ?? this.trimEnd,
    );
  }
}

class ReelEditPlaybackNotifier extends StateNotifier<ReelEditPlaybackState> {
  ReelEditPlaybackNotifier() : super(const ReelEditPlaybackState());

  void sync({
    required int positionMs,
    required int durationMs,
    required bool isPlaying,
    required double trimStart,
    required double trimEnd,
  }) {
    if (state.positionMs == positionMs &&
        state.durationMs == durationMs &&
        state.isPlaying == isPlaying &&
        state.trimStart == trimStart &&
        state.trimEnd == trimEnd) {
      return;
    }
    state = state.copyWith(
      positionMs: positionMs,
      durationMs: durationMs,
      isPlaying: isPlaying,
      trimStart: trimStart,
      trimEnd: trimEnd,
    );
  }

  void seekRelativeSec(double sec) {
    if (state.durationMs <= 0) return;
    final trimStartMs = (state.durationMs * state.trimStart).round();
    final targetMs = (trimStartMs + sec * 1000).round();
    state = state.copyWith(positionMs: targetMs.clamp(0, state.durationMs));
  }
}

final reelEditPlaybackProvider = StateNotifierProvider.autoDispose<
    ReelEditPlaybackNotifier, ReelEditPlaybackState>(
  (ref) => ReelEditPlaybackNotifier(),
);
