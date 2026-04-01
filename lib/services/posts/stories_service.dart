import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/dio_client.dart';
import '../../core/constants/api_constants.dart';
import '../../core/models/story_response_model.dart';

const int kMaxStoryFiles = 100;

class CreateStoryResult {
  final bool success;
  final StoryModelApi? data;
  final String? errorMessage;

  CreateStoryResult({
    required this.success,
    this.data,
    this.errorMessage,
  });

  factory CreateStoryResult.failure(String message) =>
      CreateStoryResult(success: false, errorMessage: message);

  factory CreateStoryResult.success(StoryModelApi data) =>
      CreateStoryResult(success: true, data: data);
}

class GetStoriesResult {
  final bool success;
  final List<StoryWithUserModel> stories;
  final String? errorMessage;

  GetStoriesResult({
    required this.success,
    this.stories = const [],
    this.errorMessage,
  });

  factory GetStoriesResult.failure(String message) =>
      GetStoriesResult(success: false, errorMessage: message);

  factory GetStoriesResult.success(List<StoryWithUserModel> stories) =>
      GetStoriesResult(success: true, stories: stories);
}

class CreateStoryParams {
  final List<File> storyFiles;
  final String? caption;
  final List<String> locations;
  final List<String> taggedUsers;
  final List<String> feelings;

  CreateStoryParams({
    this.storyFiles = const [],
    this.caption,
    this.locations = const [],
    this.taggedUsers = const [],
    this.feelings = const [],
  });

  String? validate() {
    if (storyFiles.isEmpty) return 'At least one story file is required';
    if (storyFiles.length > kMaxStoryFiles) {
      return 'Maximum $kMaxStoryFiles files allowed';
    }
    return null;
  }
}

class StoriesService {
  static const String _tokenKey = 'auth_token';
  final Dio _dio = DioClient.instance;

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<CreateStoryResult> createStory(CreateStoryParams params) async {
    final validationError = params.validate();
    if (validationError != null) {
      return CreateStoryResult.failure(validationError);
    }

    final token = await _getToken();
    if (token == null || token.isEmpty) {
      return CreateStoryResult.failure('Not authenticated');
    }

    try {
      DioClient.setAuthToken(token);
      final formData = FormData();

      if (params.caption != null && params.caption!.trim().isNotEmpty) {
        formData.fields.add(MapEntry('caption', params.caption!.trim()));
      }
      if (params.locations.isNotEmpty) {
        formData.fields.add(MapEntry('locations', jsonEncode(params.locations)));
      }
      if (params.taggedUsers.isNotEmpty) {
        formData.fields.add(MapEntry('taggedUsers', jsonEncode(params.taggedUsers)));
      }
      if (params.feelings.isNotEmpty) {
        formData.fields.add(MapEntry('feelings', jsonEncode(params.feelings)));
      }

      int fileIndex = 0;
      for (final file in params.storyFiles) {
        if (file.path.isEmpty || !await file.exists()) continue;
        final ext = _mediaExtension(file.path);
        formData.files.add(MapEntry(
          'storyFiles',
          await MultipartFile.fromFile(
            file.path,
            filename: 'story_$fileIndex$ext',
          ),
        ));
        fileIndex++;
      }

      debugPrint('[Stories] Creating story (${params.storyFiles.length} file(s))...');
      final response = await _dio.post(
        ApiConstants.storyCreate,
        data: formData,
      );

      final responseData = response.data as Map<String, dynamic>?;
      if (responseData == null || responseData['success'] != true) {
        final err = responseData?['message'] as String? ??
            responseData?['error'] as String? ??
            'Failed to create story';
        debugPrint('[Stories] Failed: $err');
        return CreateStoryResult.failure(err);
      }

      final storyJson = responseData['story'] as Map<String, dynamic>?;
      if (storyJson == null) {
        debugPrint('[Stories] Failed: Invalid response (missing story)');
        return CreateStoryResult.failure('Invalid response: missing story');
      }

      final story = StoryModelApi.fromJson(storyJson);
      debugPrint('[Stories] Created: ${story.id}');
      return CreateStoryResult.success(story);
    } on DioException catch (e) {
      if (e.response != null) {
        final errorData = e.response?.data;
        final errorMsg = errorData is Map
            ? (errorData['message'] ?? errorData['error'] ?? 'Request failed')
            : 'Request failed';
        final msg = errorMsg.toString();
        debugPrint('[Stories] Failed: $msg');
        return CreateStoryResult.failure(msg);
      }
      final msg = _networkErrorMessage(e.message);
      debugPrint('[Stories] Failed: $msg');
      return CreateStoryResult.failure(msg);
    } on TimeoutException catch (_) {
      debugPrint('[Stories] Failed: Request timed out');
      return CreateStoryResult.failure('Request timed out');
    } catch (e) {
      debugPrint('[Stories] Failed: $e');
      return CreateStoryResult.failure(
        e is Exception ? e.toString() : 'Something went wrong',
      );
    }
  }

  Future<GetStoriesResult> getStories() async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      return GetStoriesResult.failure('Not authenticated');
    }
    try {
      DioClient.setAuthToken(token);
      final response = await _dio.get(
        ApiConstants.storyList,
        options: Options(
          extra: {'noCache': true},
          headers: {'Cache-Control': 'no-cache, no-store, must-revalidate', 'Pragma': 'no-cache'},
        ),
      );
      final data = response.data as Map<String, dynamic>?;
      if (data == null || data['success'] != true) {
        final err = data?['message'] as String? ??
            data?['error'] as String? ??
            'Failed to load stories';
        return GetStoriesResult.failure(err.toString());
      }
      List<StoryWithUserModel> stories = [];
      var list = data['stories'] ?? data['data'];
      if (list != null && list is List) {
        for (final e in list) {
          if (e is Map<String, dynamic>) {
            stories.add(StoryWithUserModel.fromJson(e));
          }
        }
      }
      // Also accept posts array with type "story" and storySegments (e.g. same shape as getUserPosts)
      if (stories.isEmpty) {
        final posts = data['posts'];
        if (posts is List) {
          for (final e in posts) {
            if (e is Map<String, dynamic> && (e['type'] == 'story' || (e['storySegments'] is List && (e['storySegments'] as List).isNotEmpty))) {
              stories.add(StoryWithUserModel.fromJson(e));
            }
          }
        }
      }
      return GetStoriesResult.success(stories);
    } on DioException catch (e) {
      if (e.response != null) {
        final d = e.response?.data;
        final msg = d is Map ? (d['message'] ?? d['error'] ?? 'Request failed') : 'Request failed';
        return GetStoriesResult.failure(msg.toString());
      }
      return GetStoriesResult.failure(_networkErrorMessage(e.message));
    } on TimeoutException catch (_) {
      return GetStoriesResult.failure('Request timed out');
    } catch (e) {
      return GetStoriesResult.failure(
        e is Exception ? e.toString() : 'Something went wrong',
      );
    }
  }

  Future<GetStoriesResult> getStoriesByUserId(String userId) async {
    if (userId.isEmpty) return GetStoriesResult.success([]);
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      return GetStoriesResult.failure('Not authenticated');
    }
    try {
      DioClient.setAuthToken(token);
      final response = await _dio.get(ApiConstants.storyByUser(userId));
      final data = response.data as Map<String, dynamic>?;
      if (data == null || data['success'] != true) {
        final err = data?['message'] as String? ??
            data?['error'] as String? ??
            'Failed to load stories';
        return GetStoriesResult.failure(err.toString());
      }
      List<StoryWithUserModel> stories = [];
      var list = data['stories'] ?? data['data'];
      if (list != null && list is List) {
        for (final e in list) {
          if (e is Map<String, dynamic>) {
            stories.add(StoryWithUserModel.fromJson(e));
          }
        }
      }
      if (stories.isEmpty && data['posts'] is List) {
        for (final e in data['posts'] as List) {
          if (e is Map<String, dynamic> && (e['type'] == 'story' || (e['storySegments'] is List && (e['storySegments'] as List).isNotEmpty))) {
            stories.add(StoryWithUserModel.fromJson(e));
          }
        }
      }
      return GetStoriesResult.success(stories);
    } on DioException catch (e) {
      if (e.response != null) {
        final d = e.response?.data;
        final msg = d is Map ? (d['message'] ?? d['error'] ?? 'Request failed') : 'Request failed';
        return GetStoriesResult.failure(msg.toString());
      }
      return GetStoriesResult.failure(_networkErrorMessage(e.message));
    } on TimeoutException catch (_) {
      return GetStoriesResult.failure('Request timed out');
    } catch (e) {
      return GetStoriesResult.failure(
        e is Exception ? e.toString() : 'Something went wrong',
      );
    }
  }

  String _networkErrorMessage(String? message) {
    if (message == null || message.isEmpty) return 'Network error';
    if (message.contains('Failed host lookup') ||
        message.contains('Connection refused') ||
        message.contains('SocketException')) {
      return 'No internet connection';
    }
    return message;
  }

  String _mediaExtension(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return '.png';
    if (lower.endsWith('.gif')) return '.gif';
    if (lower.endsWith('.webp')) return '.webp';
    if (lower.endsWith('.heic')) return '.heic';
    if (lower.endsWith('.mp4')) return '.mp4';
    if (lower.endsWith('.mov')) return '.mov';
    if (lower.endsWith('.webm')) return '.webm';
    if (lower.endsWith('.mkv')) return '.mkv';
    if (lower.endsWith('.3gp')) return '.3gp';
    return '.jpg';
  }
}
