import 'dart:io';
import 'api_base.dart';

/// User profile API service
class UserApi extends ApiBase {
  // Get user profile
  Future<Map<String, dynamic>> getUserProfile(String userId) async {
    return await get('/users/$userId');
  }

  // Update user profile
  Future<Map<String, dynamic>> updateProfile({
    String? name,
    String? username,
    String? bio,
    File? profilePicture,
  }) async {
    if (profilePicture != null) {
      // Upload profile picture first
      final uploadResponse = await postMultipart(
        '/users/upload-profile-picture',
        profilePicture.path,
        'profile_picture',
      );

      if (!uploadResponse['success']) {
        return uploadResponse;
      }

      return await put(
        '/users/profile',
        {
          if (name != null) 'name': name,
          if (username != null) 'username': username,
          if (bio != null) 'bio': bio,
          'profilePictureUrl': uploadResponse['url'],
        },
      );
    }

    return await put(
      '/users/profile',
      {
        if (name != null) 'name': name,
        if (username != null) 'username': username,
        if (bio != null) 'bio': bio,
      },
    );
  }

  // Get followers list
  Future<Map<String, dynamic>> getFollowers(String userId, {int page = 1}) async {
    return await get('/users/$userId/followers', queryParams: {'page': page.toString()});
  }

  // Get following list
  Future<Map<String, dynamic>> getFollowing(String userId, {int page = 1}) async {
    return await get('/users/$userId/following', queryParams: {'page': page.toString()});
  }

  // Follow user
  Future<Map<String, dynamic>> followUser(String userId) async {
    return await post('/users/$userId/follow', {});
  }

  // Unfollow user
  Future<Map<String, dynamic>> unfollowUser(String userId) async {
    return await delete('/users/$userId/follow');
  }

  // Get user settings
  Future<Map<String, dynamic>> getSettings() async {
    return await get('/users/settings');
  }

  // Update settings
  Future<Map<String, dynamic>> updateSettings({
    bool? notificationsEnabled,
    bool? darkMode,
    bool? autoPlay,
    bool? downloadOverWifiOnly,
  }) async {
    return await put(
      '/users/settings',
      {
        if (notificationsEnabled != null) 'notificationsEnabled': notificationsEnabled,
        if (darkMode != null) 'darkMode': darkMode,
        if (autoPlay != null) 'autoPlay': autoPlay,
        if (downloadOverWifiOnly != null) 'downloadOverWifiOnly': downloadOverWifiOnly,
      },
    );
  }
}


