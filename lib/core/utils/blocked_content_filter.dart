import '../models/post_model.dart';

/// Filters posts/reels whose authors are in [blockedUserIds].
List<PostModel> filterPostsByBlockedAuthors(
  List<PostModel> posts,
  Set<String> blockedUserIds,
) {
  if (blockedUserIds.isEmpty) return posts;
  return posts
      .where((p) => p.author.id.isEmpty || !blockedUserIds.contains(p.author.id))
      .toList();
}
