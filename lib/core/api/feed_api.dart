import 'api_base.dart';

/// Feed API service
class FeedApi extends ApiBase {
  // Get feed posts
  Future<Map<String, dynamic>> getFeed({
    int page = 1,
    String sortBy = 'latest', // 'latest' or 'popular'
    int limit = 20,
  }) async {
    return await get(
      '/feed',
      queryParams: {
        'page': page.toString(),
        'sortBy': sortBy,
        'limit': limit.toString(),
      },
    );
  }

  // Create post
  Future<Map<String, dynamic>> createPost({
    required String caption,
    String? imageUrl,
    String? videoUrl,
    String? thumbnailUrl,
  }) async {
    return await post(
      '/feed/posts',
      {
        'caption': caption,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (videoUrl != null) 'videoUrl': videoUrl,
        if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      },
    );
  }

  // Delete post
  Future<Map<String, dynamic>> deletePost(String postId) async {
    return await delete('/feed/posts/$postId');
  }

  // Like post
  Future<Map<String, dynamic>> likePost(String postId) async {
    return await post('/feed/posts/$postId/like', {});
  }

  // Unlike post
  Future<Map<String, dynamic>> unlikePost(String postId) async {
    return await delete('/feed/posts/$postId/like');
  }

  // Comment on post
  Future<Map<String, dynamic>> commentPost(String postId, String comment) async {
    return await post(
      '/feed/posts/$postId/comments',
      {'comment': comment},
    );
  }

  // Get comments
  Future<Map<String, dynamic>> getComments(String postId, {int page = 1}) async {
    return await get(
      '/feed/posts/$postId/comments',
      queryParams: {'page': page.toString()},
    );
  }

  // Share post
  Future<Map<String, dynamic>> sharePost(String postId) async {
    return await post('/feed/posts/$postId/share', {});
  }
}


