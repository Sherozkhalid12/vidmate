import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/post_model.dart';
import 'long_video_feed_search_query_provider.dart';
import 'long_videos_provider.dart';

/// Long-video list rows filtered by [longVideoFeedSearchQueryProvider].
final longVideoSearchFilteredProvider = Provider<List<PostModel>>((ref) {
  final list = ref.watch(longVideosListProvider);
  final q = ref.watch(longVideoFeedSearchQueryProvider).trim().toLowerCase();
  if (q.isEmpty) return list;
  return list.where((video) {
    return video.caption.toLowerCase().contains(q) ||
        video.author.displayName.toLowerCase().contains(q) ||
        video.author.username.toLowerCase().contains(q);
  }).toList(growable: false);
});
