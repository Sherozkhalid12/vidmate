import 'api_base.dart';

/// Search API service
class SearchApi extends ApiBase {
  // Search users
  Future<Map<String, dynamic>> searchUsers(String query, {int page = 1}) async {
    return await get(
      '/search/users',
      queryParams: {
        'q': query,
        'page': page.toString(),
      },
    );
  }

  // Search hashtags
  Future<Map<String, dynamic>> searchHashtags(String query, {int page = 1}) async {
    return await get(
      '/search/hashtags',
      queryParams: {
        'q': query,
        'page': page.toString(),
      },
    );
  }

  // Get trending hashtags
  Future<Map<String, dynamic>> getTrendingHashtags() async {
    return await get('/search/trending/hashtags');
  }

  // Get trending content
  Future<Map<String, dynamic>> getTrendingContent({
    String type = 'all', // 'all', 'posts', 'videos', 'reels'
  }) async {
    return await get(
      '/search/trending',
      queryParams: {'type': type},
    );
  }

  // Get recommendations
  Future<Map<String, dynamic>> getRecommendations({
    String type = 'users', // 'users', 'posts', 'videos'
  }) async {
    return await get(
      '/search/recommendations',
      queryParams: {'type': type},
    );
  }
}


