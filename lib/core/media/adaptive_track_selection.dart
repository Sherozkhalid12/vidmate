import 'package:better_player/better_player.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Picks a reel HLS/DASH variant: never below [minHeight] when a suitable ladder exists.
BetterPlayerAsmsTrack? pickBetterPlayerTrackForConnectivity(
  List<BetterPlayerAsmsTrack> tracks,
  List<ConnectivityResult> connectivity, {
  int minHeight = 360,
}) {
  if (tracks.isEmpty) return null;
  final withDims = tracks.where((t) {
    final h = t.height ?? 0;
    final w = t.width ?? 0;
    return h > 0 || w > 0;
  }).toList();
  final pool = withDims.isNotEmpty ? withDims : tracks;

  int heightOf(BetterPlayerAsmsTrack t) {
    final h = t.height;
    if (h != null && h > 0) return h;
    final w = t.width;
    if (w != null && w > 0) return w;
    return 0;
  }

  final sorted = [...pool]..sort((a, b) => heightOf(a).compareTo(heightOf(b)));

  List<BetterPlayerAsmsTrack> eligible() {
    final e = sorted.where((t) => heightOf(t) >= minHeight).toList();
    return e.isNotEmpty ? e : sorted;
  }

  final e = eligible();
  final wifi = connectivity.any((c) =>
      c == ConnectivityResult.wifi || c == ConnectivityResult.ethernet);
  final cellular = connectivity.any((c) => c == ConnectivityResult.mobile);

  if (wifi) {
    return e.last;
  }
  if (cellular) {
    const cap = 720;
    BetterPlayerAsmsTrack? best;
    for (final t in e) {
      final h = heightOf(t);
      if (h <= cap) best = t;
    }
    return best ?? e.last;
  }
  return e.first;
}
