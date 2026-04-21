import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One-shot: next [VideoPlayerNotifier] init for this URL starts at 0:00 (e.g.
/// embedded suggested pick). Cleared when consumed in [_initializePlayer].
class LongVideoColdStartEmbeddedIntent {
  final String videoUrl;

  const LongVideoColdStartEmbeddedIntent(this.videoUrl);
}

final longVideoColdStartIntentProvider =
    StateProvider<LongVideoColdStartEmbeddedIntent?>((ref) => null);
