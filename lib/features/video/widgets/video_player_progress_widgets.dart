import 'package:flutter/material.dart';

import '../../../core/providers/video_player_provider.dart';

/// Thin progress bar from [VideoPlayerState] (Better Player route).
Widget buildVideoPlayerLinearProgressBar(
  BuildContext context,
  VideoPlayerState playerState,
) {
  final durationMs = playerState.duration.inMilliseconds;
  final positionMs = playerState.position.inMilliseconds;
  final progress =
      durationMs > 0 ? (positionMs / durationMs).clamp(0.0, 1.0) : 0.0;
  return SizedBox(
    height: 4,
    child: LinearProgressIndicator(
      value: progress,
      backgroundColor: Colors.white.withValues(alpha: 0.2),
      valueColor: AlwaysStoppedAnimation<Color>(
        Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}

/// Thin progress bar from explicit durations (e.g. long-form inline player).
Widget buildVideoPlayerLinearProgressBarFromDurations(
  BuildContext context,
  Duration position,
  Duration duration,
) {
  final durationMs = duration.inMilliseconds;
  final positionMs = position.inMilliseconds;
  final progress =
      durationMs > 0 ? (positionMs / durationMs).clamp(0.0, 1.0) : 0.0;
  return SizedBox(
    height: 4,
    child: LinearProgressIndicator(
      value: progress,
      backgroundColor: Colors.white.withValues(alpha: 0.2),
      valueColor: AlwaysStoppedAnimation<Color>(
        Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}
