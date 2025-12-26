import 'dart:io';
import 'api_base.dart';

/// Video upload and management API service
class VideoApi extends ApiBase {
  // Upload video (Long video, Reel, or Post)
  Future<Map<String, dynamic>> uploadVideo({
    required File videoFile,
    required String type, // 'long', 'reel', 'post'
    String? caption,
    String? thumbnailPath,
  }) async {
    // Step 1: Upload video file
    final videoResponse = await postMultipart(
      '/videos/upload',
      videoFile.path,
      'video',
      fields: {
        'type': type,
        if (caption != null) 'caption': caption,
      },
    );

    if (!videoResponse['success']) {
      return videoResponse;
    }

    // Step 2: Upload thumbnail if provided
    String? thumbnailUrl;
    if (thumbnailPath != null) {
      final thumbnailResponse = await postMultipart(
        '/videos/upload-thumbnail',
        thumbnailPath,
        'thumbnail',
        fields: {'videoId': videoResponse['videoId']},
      );
      thumbnailUrl = thumbnailResponse['thumbnailUrl'];
    }

    return {
      'success': true,
      'videoId': videoResponse['videoId'],
      'videoUrl': videoResponse['videoUrl'],
      'thumbnailUrl': thumbnailUrl ?? videoResponse['thumbnailUrl'],
      'playbackUrl': videoResponse['playbackUrl'],
    };
  }

  // Get video details
  Future<Map<String, dynamic>> getVideo(String videoId) async {
    return await get('/videos/$videoId');
  }

  // Increment video views
  Future<Map<String, dynamic>> incrementViews(String videoId) async {
    return await post('/videos/$videoId/views', {});
  }

  // Get trending videos
  Future<Map<String, dynamic>> getTrendingVideos({
    int page = 1,
    String type = 'all', // 'all', 'long', 'reel'
  }) async {
    return await get(
      '/videos/trending',
      queryParams: {
        'page': page.toString(),
        'type': type,
      },
    );
  }

  // Get video playback URL
  Future<Map<String, dynamic>> getPlaybackUrl(String videoId) async {
    return await get('/videos/$videoId/playback');
  }

  // Delete video
  Future<Map<String, dynamic>> deleteVideo(String videoId) async {
    return await delete('/videos/$videoId');
  }

  // Get video analytics
  Future<Map<String, dynamic>> getVideoAnalytics(String videoId) async {
    return await get('/videos/$videoId/analytics');
  }
}


