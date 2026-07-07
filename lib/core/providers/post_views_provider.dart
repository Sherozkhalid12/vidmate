import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/posts/post_views_service.dart';

final postViewsServiceProvider = Provider<PostViewsService>((ref) {
  return PostViewsService();
});

/// View count overrides from API after `recordView`, keyed by post id.
final postViewCountOverridesProvider =
    StateNotifierProvider<PostViewCountOverrides, Map<String, int>>((ref) {
  return PostViewCountOverrides(ref);
});

class PostViewCountOverrides extends StateNotifier<Map<String, int>> {
  PostViewCountOverrides(this._ref) : super({});

  final Ref _ref;

  void seedCount(String postId, int views) {
    final id = postId.trim();
    if (id.isEmpty || views <= 0) return;
    if (state[id] == views) return;
    state = {...state, id: views};
  }

  Future<void> recordAndUpdate(String postId, {int fallback = 0}) async {
    final id = postId.trim();
    if (id.isEmpty) return;

    final service = _ref.read(postViewsServiceProvider);
    final cached = await service.getCachedViewCount(id);
    final baseline = _maxPositive(fallback, cached, state[id]);

    if (cached != null && cached > 0 && state[id] != cached) {
      state = {...state, id: cached};
    }

    final apiCount = await service.recordView(id, baseline: baseline);
    final resolved = _maxPositive(apiCount, cached, state[id], fallback);
    if (resolved > 0 && state[id] != resolved) {
      state = {...state, id: resolved};
    }
  }

  int resolveCount(String postId, {required int baseCount}) {
    final override = state[postId];
    if (override != null && override > 0) return override;
    return baseCount;
  }

  void applySocketUpdate({required String postId, required int viewCount}) {
    final id = postId.trim();
    if (id.isEmpty || viewCount <= 0) return;
    if (state[id] == viewCount) return;
    state = {...state, id: viewCount};
  }

  int _maxPositive(int? a, int? b, int? c, [int? d]) {
    var max = 0;
    for (final v in [a, b, c, d]) {
      if (v != null && v > max) max = v;
    }
    return max;
  }
}
