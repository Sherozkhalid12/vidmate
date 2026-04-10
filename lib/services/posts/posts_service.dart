import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/dio_client.dart';
import '../../core/utils/feed_json_parser.dart';
import '../../core/constants/api_constants.dart';
import '../../core/models/comment_model.dart';
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
  /// True when failure was due to transport/timeout (authoritative offline-style signal).
  final bool connectionError;

  GetPostsResult({
    required this.success,
    this.posts = const [],
    this.errorMessage,
    this.connectionError = false,
  });

  factory GetPostsResult.failure(String message, {bool connectionError = false}) =>
      GetPostsResult(success: false, errorMessage: message, connectionError: connectionError);

  factory GetPostsResult.success(List<ApiPostWithAuthor> posts) =>
      GetPostsResult(success: true, posts: posts);
}

/// Result of like post API.
class LikePostResult {
  final bool success;
  final String? postId;
  final int? likesCount;
  final String? action; // 'liked' | 'unliked'
  final String? errorMessage;

  LikePostResult({
    required this.success,
    this.postId,
    this.likesCount,
    this.action,
    this.errorMessage,
  });
}

/// Result of add comment API.
class AddCommentResult {
  final bool success;
  final PostComment? comment;
  final String? errorMessage;

  AddCommentResult({
    required this.success,
    this.comment,
    this.errorMessage,
  });
}

/// Result of get comments API.
class GetCommentsResult {
  final bool success;
  final List<PostComment> comments;
  final String? errorMessage;

  GetCommentsResult({
    required this.success,
    this.comments = const [],
    this.errorMessage,
  });
}

/// Result of save post API.
class SavePostResult {
  final bool success;
  final String? postId;
  final String? action; // 'saved' | 'unsaved'
  final List<String>? savedPosts;
  final String? errorMessage;

  SavePostResult({
    required this.success,
    this.postId,
    this.action,
    this.savedPosts,
    this.errorMessage,
  });
}

/// Result of delete post API call.
class DeletePostResult {
  final bool success;
  final String? postId;
  final String? errorMessage;

  const DeletePostResult({
    required this.success,
    this.postId,
    this.errorMessage,
  });

  factory DeletePostResult.failure(String message) =>
      DeletePostResult(success: false, errorMessage: message);

  factory DeletePostResult.success(String postId) =>
      DeletePostResult(success: true, postId: postId);
}

/// Result of report post API call.
class ReportPostResult {
  final bool success;
  final String? postId;
  final String? errorMessage;

  const ReportPostResult({
    required this.success,
    this.postId,
    this.errorMessage,
  });

  factory ReportPostResult.failure(String message) =>
      ReportPostResult(success: false, errorMessage: message);

  factory ReportPostResult.success(String postId) =>
      ReportPostResult(success: true, postId: postId);
}

/// Result of share post API call.
class SharePostResult {
  final bool success;
  final String? postId;
  final String? action;
  final String? errorMessage;

  const SharePostResult({
    required this.success,
    this.postId,
    this.action,
    this.errorMessage,
  });

  factory SharePostResult.failure(String message) =>
      SharePostResult(success: false, errorMessage: message);

  factory SharePostResult.success({String? postId, String? action}) =>
      SharePostResult(success: true, postId: postId, action: action);
}

/// Parameters for creating a post. All optional except validation rules.
class CreatePostParams {
  final List<File> images;
  final File? video;
  final File? thumbnailFile;
  final String? thumbnailUrl;
  final String? caption;
  final List<String> locations;
  final List<String> taggedUsers;
  final List<String> feelings;

  CreatePostParams({
    this.images = const [],
    this.video,
    this.thumbnailFile,
    this.thumbnailUrl,
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
    if (thumbnailFile != null && thumbnailFile!.path.isEmpty) {
      return 'Invalid thumbnail file';
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

      // Thumbnail: either file (preferred) OR URL string
      if (params.thumbnailFile != null &&
          params.thumbnailFile!.path.isNotEmpty &&
          await params.thumbnailFile!.exists()) {
        formData.files.add(MapEntry(
          'thumbnail',
          await MultipartFile.fromFile(
            params.thumbnailFile!.path,
            filename: 'thumbnail.jpg',
          ),
        ));
      } else if (params.thumbnailUrl != null &&
          params.thumbnailUrl!.trim().isNotEmpty) {
        formData.fields
            .add(MapEntry('thumbnail', params.thumbnailUrl!.trim()));
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

  /// GET all posts (home feed). Uses auth token. JSON decode runs in [compute] isolate.
  /// [skip] / [limit] are sent as query params when set (backend may ignore).
  Future<GetPostsResult> getPosts({
    CancelToken? cancelToken,
    int skip = 0,
    int? limit,
  }) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      return GetPostsResult.failure('Not authenticated');
    }
    try {
      DioClient.setAuthToken(token);
      final query = <String, dynamic>{};
      if (skip > 0) query['skip'] = skip;
      if (limit != null && limit > 0) {
        query['limit'] = limit;
      }
      final response = await _dio.get<String>(
        ApiConstants.postList,
        queryParameters: query.isEmpty ? null : query,
        options: Options(responseType: ResponseType.plain),
        cancelToken: cancelToken,
      );
      final raw = response.data ?? '';
      final parsed = await compute(parseFeedJson, raw);
      if (parsed['success'] != true) {
        final err = parsed['message']?.toString() ?? 'Failed to load posts';
        return GetPostsResult.failure(err);
      }
      final list = parsed['items'];
      if (list is! List) {
        return GetPostsResult.success([]);
      }
      final posts = <ApiPostWithAuthor>[];
      for (final e in list) {
        if (e is Map<String, dynamic>) {
          posts.add(ApiPostWithAuthor.fromJson(e));
        } else if (e is Map) {
          posts.add(ApiPostWithAuthor.fromJson(Map<String, dynamic>.from(e)));
        }
      }
      return GetPostsResult.success(posts);
    } on DioException catch (e) {
      if (e.response != null) {
        final d = e.response?.data;
        final msg = d is Map ? (d['message'] ?? d['error'] ?? 'Request failed') : 'Request failed';
        return GetPostsResult.failure(msg.toString());
      }
      final conn = e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout;
      return GetPostsResult.failure(_networkErrorMessage(e.message), connectionError: conn);
    } on TimeoutException catch (_) {
      return GetPostsResult.failure('Request timed out', connectionError: true);
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

  /// POST like/unlike a post.
  Future<LikePostResult> likePost(String postId) async {
    if (postId.isEmpty) return LikePostResult(success: false, errorMessage: 'Invalid post id');
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      return LikePostResult(success: false, errorMessage: 'Not authenticated');
    }
    try {
      DioClient.setAuthToken(token);
      final response = await _dio.post(ApiConstants.postLike(postId));
      final data = response.data as Map<String, dynamic>?;
      if (data == null) return LikePostResult(success: false, errorMessage: 'Invalid response');
      final count = data['likesCount'];
      return LikePostResult(
        success: true,
        postId: data['postId']?.toString(),
        likesCount: count is int ? count : (count != null ? int.tryParse(count.toString()) : null),
        action: data['action']?.toString(),
      );
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response?.data['message'] ?? e.response?.data['error'] ?? 'Request failed').toString()
          : 'Request failed';
      return LikePostResult(success: false, errorMessage: msg);
    } catch (e) {
      return LikePostResult(success: false, errorMessage: e.toString());
    }
  }

  /// POST add comment to a post.
  Future<AddCommentResult> addComment({required String postId, required String content}) async {
    if (postId.isEmpty || content.trim().isEmpty) {
      return AddCommentResult(success: false, errorMessage: 'Invalid input');
    }
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      return AddCommentResult(success: false, errorMessage: 'Not authenticated');
    }
    try {
      DioClient.setAuthToken(token);
      final response = await _dio.post(
        ApiConstants.postComment,
        data: {'postId': postId, 'content': content.trim()},
      );
      final data = response.data as Map<String, dynamic>?;
      if (data == null) return AddCommentResult(success: false, errorMessage: 'Invalid response');
      final commentJson = data['comment'] as Map<String, dynamic>?;
      if (commentJson == null) return AddCommentResult(success: false, errorMessage: 'No comment in response');
      return AddCommentResult(success: true, comment: PostComment.fromJson(commentJson));
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response?.data['message'] ?? e.response?.data['error'] ?? 'Request failed').toString()
          : 'Request failed';
      return AddCommentResult(success: false, errorMessage: msg);
    } catch (e) {
      return AddCommentResult(success: false, errorMessage: e.toString());
    }
  }

  /// GET comments for a post.
  Future<GetCommentsResult> getComments(String postId) async {
    if (postId.isEmpty) return GetCommentsResult(success: false, errorMessage: 'Invalid post id');
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      return GetCommentsResult(success: false, errorMessage: 'Not authenticated');
    }
    try {
      DioClient.setAuthToken(token);
      final response = await _dio.get(ApiConstants.postComments(postId));
      final data = response.data as Map<String, dynamic>?;
      if (data == null) return GetCommentsResult(success: false, errorMessage: 'Invalid response');
      final list = data['comments'];
      if (list == null || list is! List) {
        return GetCommentsResult(success: true, comments: []);
      }
      final comments = <PostComment>[];
      for (final e in list) {
        if (e is Map<String, dynamic>) comments.add(PostComment.fromJson(e));
      }
      return GetCommentsResult(success: true, comments: comments);
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response?.data['message'] ?? e.response?.data['error'] ?? 'Request failed').toString()
          : 'Request failed';
      return GetCommentsResult(success: false, errorMessage: msg);
    } catch (e) {
      return GetCommentsResult(success: false, errorMessage: e.toString());
    }
  }

  /// POST save/unsave a post.
  Future<SavePostResult> savePost(String postId) async {
    if (postId.isEmpty) return SavePostResult(success: false, errorMessage: 'Invalid post id');
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      return SavePostResult(success: false, errorMessage: 'Not authenticated');
    }
    try {
      DioClient.setAuthToken(token);
      final response = await _dio.post(ApiConstants.postSave(postId));
      final data = response.data as Map<String, dynamic>?;
      if (data == null) return SavePostResult(success: false, errorMessage: 'Invalid response');
      final savedList = data['savedPosts'];
      final list = savedList is List ? savedList.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList() : null;
      return SavePostResult(
        success: true,
        postId: data['postId']?.toString(),
        action: data['action']?.toString(),
        savedPosts: list,
      );
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response?.data['message'] ?? e.response?.data['error'] ?? 'Request failed').toString()
          : 'Request failed';
      return SavePostResult(success: false, errorMessage: msg);
    } catch (e) {
      return SavePostResult(success: false, errorMessage: e.toString());
    }
  }

  /// DELETE a post.
  ///
  /// Allowed only when [currentUserId] matches [postAuthorId].
  Future<DeletePostResult> deletePost({
    required String postId,
    required String currentUserId,
    required String postAuthorId,
  }) async {
    if (postId.isEmpty) return DeletePostResult.failure('Invalid post id');
    if (currentUserId.isEmpty) return DeletePostResult.failure('Not authenticated');
    if (currentUserId != postAuthorId) {
      return DeletePostResult.failure('You are not allowed to delete this post');
    }

    final token = await _getToken();
    if (token == null || token.isEmpty) {
      return DeletePostResult.failure('Not authenticated');
    }

    try {
      DioClient.setAuthToken(token);
      final response = await _dio.delete(ApiConstants.postDelete(postId));
      final data = response.data as Map<String, dynamic>?;
      if (data == null || data['success'] != true) {
        final err = data?['message']?.toString() ??
            data?['error']?.toString() ??
            'Failed to delete post';
        return DeletePostResult.failure(err);
      }
      return DeletePostResult.success(postId);
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response?.data['message'] ?? e.response?.data['error'] ?? 'Request failed').toString()
          : 'Request failed';
      return DeletePostResult.failure(msg);
    } catch (e) {
      return DeletePostResult.failure(e.toString());
    }
  }

  /// POST report a post.
  ///
  /// Allowed only when [currentUserId] is NOT the author.
  Future<ReportPostResult> reportPost({
    required String postId,
    required String currentUserId,
    required String postAuthorId,
  }) async {
    if (postId.isEmpty) return ReportPostResult.failure('Invalid post id');
    if (currentUserId.isEmpty) return ReportPostResult.failure('Not authenticated');
    if (currentUserId == postAuthorId) {
      return ReportPostResult.failure('You cannot report your own post');
    }

    final token = await _getToken();
    if (token == null || token.isEmpty) {
      return ReportPostResult.failure('Not authenticated');
    }

    try {
      DioClient.setAuthToken(token);
      final response = await _dio.post(ApiConstants.postReport(postId));
      final data = response.data as Map<String, dynamic>?;
      if (data == null || data['success'] != true) {
        final err = data?['message']?.toString() ??
            data?['error']?.toString() ??
            'Failed to report post';
        return ReportPostResult.failure(err);
      }
      return ReportPostResult.success(postId);
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response?.data['message'] ?? e.response?.data['error'] ?? 'Request failed').toString()
          : 'Request failed';
      return ReportPostResult.failure(msg);
    } catch (e) {
      return ReportPostResult.failure(e.toString());
    }
  }

  /// POST share a post.
  Future<SharePostResult> sharePost(String postId) async {
    if (postId.isEmpty) return SharePostResult.failure('Invalid post id');
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      return SharePostResult.failure('Not authenticated');
    }

    try {
      DioClient.setAuthToken(token);
      final response = await _dio.post(ApiConstants.postShare(postId));
      final data = response.data as Map<String, dynamic>?;
      if (data == null || data['success'] != true) {
        final err = data?['message']?.toString() ??
            data?['error']?.toString() ??
            'Failed to share post';
        return SharePostResult.failure(err);
      }
      return SharePostResult.success(
        postId: data['postId']?.toString() ?? postId,
        action: data['action']?.toString(),
      );
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response?.data['message'] ?? e.response?.data['error'] ?? 'Request failed').toString()
          : 'Request failed';
      return SharePostResult.failure(msg);
    } catch (e) {
      return SharePostResult.failure(e.toString());
    }
  }

  /// GET saved posts.
  Future<GetPostsResult> getSavedPosts() async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      return GetPostsResult.failure('Not authenticated');
    }
    try {
      DioClient.setAuthToken(token);
      final response = await _dio.get(ApiConstants.postGetSavedPosts);
      final data = response.data as Map<String, dynamic>?;
      if (data == null || data['success'] != true) {
        final err = data?['message'] ?? data?['error'] ?? 'Failed to load saved posts';
        return GetPostsResult.failure(err.toString());
      }
      final list = data['savedPosts'];
      if (list == null || list is! List) return GetPostsResult.success([]);
      final posts = <ApiPostWithAuthor>[];
      for (final e in list) {
        if (e is Map<String, dynamic>) posts.add(ApiPostWithAuthor.fromJson(e));
      }
      return GetPostsResult.success(posts);
    } on DioException catch (e) {
      if (e.response != null) {
        final d = e.response?.data;
        final msg = d is Map ? (d['message'] ?? d['error'] ?? 'Request failed') : 'Request failed';
        return GetPostsResult.failure(msg.toString());
      }
      return GetPostsResult.failure(_networkErrorMessage(e.message));
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
