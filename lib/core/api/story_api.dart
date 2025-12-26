import 'dart:io';
import 'api_base.dart';

/// Story API service
class StoryApi extends ApiBase {
  // Upload story
  Future<Map<String, dynamic>> uploadStory({
    required File mediaFile,
    required bool isVideo,
    String? caption,
    bool isPrivate = false,
  }) async {
    return await postMultipart(
      '/stories/upload',
      mediaFile.path,
      'media',
      fields: {
        'isVideo': isVideo.toString(),
        if (caption != null) 'caption': caption,
        'isPrivate': isPrivate.toString(),
      },
    );
  }

  // Get stories
  Future<Map<String, dynamic>> getStories({String? userId}) async {
    if (userId != null) {
      return await get('/stories/user/$userId');
    }
    return await get('/stories');
  }

  // Get story viewers
  Future<Map<String, dynamic>> getStoryViewers(String storyId) async {
    return await get('/stories/$storyId/viewers');
  }

  // Delete story
  Future<Map<String, dynamic>> deleteStory(String storyId) async {
    return await delete('/stories/$storyId');
  }

  // Mark story as viewed
  Future<Map<String, dynamic>> markStoryViewed(String storyId) async {
    return await post('/stories/$storyId/view', {});
  }
}


