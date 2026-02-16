import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/dio_client.dart';
import '../../core/constants/api_constants.dart';
import '../../core/models/post_response_model.dart';

/// Maximum images allowed per post.
const int kMaxPostImages = 10;

/// Maximum video files allowed per post.
const int kMaxPostVideos = 1;

/// Result of create post API call.
class CreatePostResult {
  final bool success;
  final ApiPost? data;
  final String? errorMessage;

  CreatePostResult({
    required this.success,
    this.data,
    this.errorMessage,
  });

  factory CreatePostResult.failure(String message) =>
      CreatePostResult(success: false, errorMessage: message);

  factory CreatePostResult.success(ApiPost data) =>
      CreatePostResult(success: true, data: data);
}

/// Result of get posts (list) API call.
class GetPostsResult {
  final bool success;
  final List<ApiPostWithAuthor> posts;
  final String? errorMessage;

  GetPostsResult({
    required this.success,
    this.posts = const [],
    this.errorMessage,
  });

  factory GetPostsResult.failure(String message) =>
      GetPostsResult(success: false, errorMessage: message);

  factory GetPostsResult.success(List<ApiPostWithAuthor> posts) =>
      GetPostsResult(success: true, posts: posts);
}

/// Parameters for creating a post. All optional except validation rules.
class CreatePostParams {
  final List<File> images;
  final File? video;
  final String? caption;
  final List<String> locations;
  final List<String> taggedUsers;
  final List<String> feelings;

  CreatePostParams({
    this.images = const [],
    this.video,
    this.caption,
    this.locations = const [],
    this.taggedUsers = const [],
    this.feelings = const [],
  });

  /// Validates payload: max 10 images, max 1 video.
  String? validate() {
    if (images.length > kMaxPostImages) {
      return 'Maximum $kMaxPostImages images allowed';
    }
    if (video != null && video!.path.isEmpty) {
      return 'Invalid video file';
    }
    return null;
  }
}

/// Posts API service. Uses Dio with logging interceptor.
class PostsService {
  static const String _tokenKey = 'auth_token';
  final Dio _dio = DioClient.instance;

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// Creates a post via multipart/form-data. Validates images ≤ 10 and video ≤ 1.
  Future<CreatePostResult> createPost(CreatePostParams params) async {
    debugPrint('[PostsService] createPost started');
    final validationError = params.validate();
    if (validationError != null) {
      debugPrint('[PostsService] validation failed: $validationError');
      return CreatePostResult.failure(validationError);
    }

    final token = await _getToken();
    if (token == null || token.isEmpty) {
      debugPrint('[PostsService] not authenticated (no token)');
      return CreatePostResult.failure('Not authenticated');
    }

    try {
      DioClient.setAuthToken(token);
      final formData = FormData();

      if (params.caption != null && params.caption!.trim().isNotEmpty) {
        formData.fields.add(MapEntry('caption', params.caption!.trim()));
        debugPrint('[PostsService] caption length: ${params.caption!.trim().length}');
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

      var imageCount = 0;
      for (final file in params.images) {
        if (file.path.isEmpty || !await file.exists()) continue;
        final ext = _imageExtension(file.path);
        formData.files.add(MapEntry(
          'images',
          await MultipartFile.fromFile(
            file.path,
            filename: 'image_$imageCount$ext',
          ),
        ));
        imageCount++;
      }
      if (imageCount > 0) debugPrint('[PostsService] added $imageCount image(s)');

      if (params.video != null &&
          params.video!.path.isNotEmpty &&
          await params.video!.exists()) {
        final videoPath = params.video!.path;
        final videoExt = _videoExtension(videoPath);
        formData.files.add(MapEntry(
          'video',
          await MultipartFile.fromFile(
            videoPath,
            filename: 'video$videoExt',
          ),
        ));
        debugPrint('[PostsService] added 1 video');
      }

      final response = await _dio.post(
        ApiConstants.postCreate,
        data: formData,
      );

      final responseData = response.data as Map<String, dynamic>?;
      if (responseData == null || responseData['success'] != true) {
        final err = responseData?['message'] as String? ??
            responseData?['error'] as String? ??
            'Failed to create post';
        debugPrint('[PostsService] request failed: $err');
        return CreatePostResult.failure(err);
      }

      final postJson = responseData['post'] as Map<String, dynamic>?;
      if (postJson == null) {
        debugPrint('[PostsService] invalid response: missing post');
        return CreatePostResult.failure('Invalid response: missing post');
      }

      final post = ApiPost.fromJson(postJson);
      debugPrint('[PostsService] post created successfully, id: ${post.id}');
      return CreatePostResult.success(post);
    } on DioException catch (e) {
      debugPrint('[PostsService] DioException: ${e.message}');
      if (e.response != null) {
        final errorData = e.response?.data;
        final errorMsg = errorData is Map
            ? (errorData['message'] ?? errorData['error'] ?? 'Request failed')
            : 'Request failed';
        return CreatePostResult.failure(errorMsg.toString());
      }
      return CreatePostResult.failure(_networkErrorMessage(e.message));
    } on TimeoutException catch (_) {
      debugPrint('[PostsService] request timed out');
      return CreatePostResult.failure('Request timed out');
    } catch (e) {
      debugPrint('[PostsService] error: $e');
      return CreatePostResult.failure(
        e is Exception ? e.toString() : 'Something went wrong',
      );
    }
  }

  /// GET all posts (home feed). Uses auth token.
  Future<GetPostsResult> getPosts() async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      return GetPostsResult.failure('Not authenticated');
    }
    try {
      DioClient.setAuthToken(token);
      final response = await _dio.get(ApiConstants.postList);
      final data = response.data as Map<String, dynamic>?;
      if (data == null || data['success'] != true) {
        final err = data?['message'] as String? ??
            data?['error'] as String? ??
            'Failed to load posts';
        return GetPostsResult.failure(err.toString());
      }
      final list = data['posts'];
      if (list == null || list is! List) {
        return GetPostsResult.success([]);
      }
      final posts = <ApiPostWithAuthor>[];
      for (final e in list) {
        if (e is Map<String, dynamic>) {
          posts.add(ApiPostWithAuthor.fromJson(e));
        }
      }
      return GetPostsResult.success(posts);
    } on DioException catch (e) {
      if (e.response != null) {
        final d = e.response?.data;
        final msg = d is Map ? (d['message'] ?? d['error'] ?? 'Request failed') : 'Request failed';
        return GetPostsResult.failure(msg.toString());
      }
      return GetPostsResult.failure(_networkErrorMessage(e.message));
    } on TimeoutException catch (_) {
      return GetPostsResult.failure('Request timed out');
    } catch (e) {
      return GetPostsResult.failure(
        e is Exception ? e.toString() : 'Something went wrong',
      );
    }
  }

  /// GET posts for a specific user (profile). Uses auth token.
  Future<GetPostsResult> getUserPosts(String userId) async {
    if (userId.isEmpty) return GetPostsResult.success([]);
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      return GetPostsResult.failure('Not authenticated');
    }
    try {
      DioClient.setAuthToken(token);
      final response = await _dio.get(ApiConstants.postByUser(userId));
      final data = response.data as Map<String, dynamic>?;
      if (data == null || data['success'] != true) {
        final err = data?['message'] as String? ??
            data?['error'] as String? ??
            'Failed to load posts';
        return GetPostsResult.failure(err.toString());
      }
      final list = data['posts'];
      if (list == null || list is! List) {
        return GetPostsResult.success([]);
      }
      final posts = <ApiPostWithAuthor>[];
      for (final e in list) {
        if (e is Map<String, dynamic>) {
          posts.add(ApiPostWithAuthor.fromJson(e));
        }
      }
      return GetPostsResult.success(posts);
    } on DioException catch (e) {
      if (e.response != null) {
        final d = e.response?.data;
        final msg = d is Map ? (d['message'] ?? d['error'] ?? 'Request failed') : 'Request failed';
        return GetPostsResult.failure(msg.toString());
      }
      return GetPostsResult.failure(_networkErrorMessage(e.message));
    } on TimeoutException catch (_) {
      return GetPostsResult.failure('Request timed out');
    } catch (e) {
      return GetPostsResult.failure(
        e is Exception ? e.toString() : 'Something went wrong',
      );
    }
  }

  /// GET user posts by user ID. Uses auth token.
  /// Endpoint: /api/v1/post/userPosts/:id
  /// Accepts response with or without top-level "success" (treats presence of "posts" as success).
  Future<GetPostsResult> getUserPost(String userId) async {
    if (userId.isEmpty) return GetPostsResult.success([]);
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      return GetPostsResult.failure('Not authenticated');
    }
    try {
      DioClient.setAuthToken(token);
      final response = await _dio.get(ApiConstants.userPosts(userId));
      final data = response.data as Map<String, dynamic>?;
      if (data == null) {
        return GetPostsResult.failure('Invalid response');
      }
      final list = data['posts'];
      if (list == null || list is! List) {
        if (data['success'] == false) {
          final err = data['message'] as String? ??
              data['error'] as String? ??
              'Failed to load posts';
          return GetPostsResult.failure(err.toString());
        }
        return GetPostsResult.success([]);
      }
      final posts = <ApiPostWithAuthor>[];
      for (final e in list) {
        if (e is Map<String, dynamic>) {
          posts.add(ApiPostWithAuthor.fromJson(e));
        }
      }
      return GetPostsResult.success(posts);
    } on DioException catch (e) {
      if (e.response != null) {
        final d = e.response?.data;
        final msg = d is Map ? (d['message'] ?? d['error'] ?? 'Request failed') : 'Request failed';
        return GetPostsResult.failure(msg.toString());
      }
      return GetPostsResult.failure(_networkErrorMessage(e.message));
    } on TimeoutException catch (_) {
      return GetPostsResult.failure('Request timed out');
    } catch (e) {
      return GetPostsResult.failure(
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

  /// Image extension from path so server fileFilter accepts (image, video, audio only).
  String _imageExtension(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return '.png';
    if (lower.endsWith('.gif')) return '.gif';
    if (lower.endsWith('.webp')) return '.webp';
    if (lower.endsWith('.heic')) return '.heic';
    return '.jpg';
  }

  String _videoExtension(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.mp4')) return '.mp4';
    if (lower.endsWith('.mov')) return '.mov';
    if (lower.endsWith('.webm')) return '.webm';
    if (lower.endsWith('.mkv')) return '.mkv';
    if (lower.endsWith('.3gp')) return '.3gp';
    return '.mp4';
  }
}
