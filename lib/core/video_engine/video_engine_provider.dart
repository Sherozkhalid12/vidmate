import 'package:better_player/better_player.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'global_video_engine.dart';
import 'global_video_engine_state.dart';

final globalVideoEngineProvider =
    StateNotifierProvider<GlobalVideoEngine, GlobalVideoEngineState>((ref) {
  ref.keepAlive();
  return GlobalVideoEngine();
});

final videoEngineActiveControllerProvider =
    Provider<BetterPlayerController?>((ref) {
  return ref.watch(globalVideoEngineProvider).activeSlot?.controller;
});

final videoEngineActiveIdProvider = Provider<String?>((ref) {
  return ref.watch(globalVideoEngineProvider).activeSlot?.id;
});

final videoEngineFeatureProvider = Provider<VideoEngineFeature>((ref) {
  return ref.watch(globalVideoEngineProvider).activeFeature;
});

final videoEngineIsTransitioningProvider = Provider<bool>((ref) {
  return ref.watch(globalVideoEngineProvider).isTransitioning;
});

final videoEnginePrefetchedUrlProvider = Provider<String?>((ref) {
  return ref.watch(globalVideoEngineProvider).prefetchedUrl;
});
