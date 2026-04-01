import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/dio_client.dart';
import '../../core/constants/api_constants.dart';
import '../../core/models/long_video_response_model.dart';

class CreateLongVideoResult {
  final bool success;
  final LongVideoModelApi? data;
  final String? errorMessage;

  CreateLongVideoResult({
    required this.success,
    this.data,
    this.errorMessage,
  });

  factory CreateLongVideoResult.failure(String message) =>
      CreateLongVideoResult(success: false, errorMessage: message);

  factory CreateLongVideoResult.success(LongVideoModelApi data) =>
      CreateLongVideoResult(success: true, data: data);
}

class GetLongVideosResult {
  final bool success;
  final List<LongVideoWithUserModel> videos;
  final String? errorMessage;

  GetLongVideosResult({
    required this.success,
    this.videos = const [],
    this.errorMessage,
  });

  factory GetLongVideosResult.failure(String message) =>
      GetLongVideosResult(success: false, errorMessage: message);

  factory GetLongVideosResult.success(List<LongVideoWithUserModel> videos) =>
      GetLongVideosResult(success: true, videos: videos);
}

class CreateLongVideoParams {
  final File? video;
  final File? thumbnailFile;
  final String? thumbnailUrl;
  final String? caption;

  CreateLongVideoParams({
    this.video,
    this.thumbnailFile,
    this.thumbnailUrl,
    this.caption,
  });

  String? validate() {
    if (video == null || video!.path.isEmpty) return 'Video is required';
    if (thumbnailFile != null && thumbnailFile!.path.isEmpty) {
      return 'Invalid thumbnail file';
    }
    return null;
  }
}

class LongVideoService {
  static const String _tokenKey = 'auth_token';
  final Dio _dio = DioClient.instance;

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<CreateLongVideoResult> createLongVideo(CreateLongVideoParams params) async {
    final validationError = params.validate();
    if (validationError != null) {
      return CreateLongVideoResult.failure(validationError);
    }

    final token = await _getToken();
    if (token == null || token.isEmpty) {
      return CreateLongVideoResult.failure('Not authenticated');
    }

    try {
      DioClient.setAuthToken(token);
      final formData = FormData();

      if (params.caption != null && params.caption!.trim().isNotEmpty) {
        formData.fields.add(MapEntry('caption', params.caption!.trim()));
      }

      if (params.thumbnailFile != null &&
          params.thumbnailFile!.path.isNotEmpty &&
          params.thumbnailFile!.existsSync()) {
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

      final video = params.video!;
      if (video.path.isNotEmpty && video.existsSync()) {
        final ext = _videoExtension(video.path);
        formData.files.add(MapEntry(
          'video',
          await MultipartFile.fromFile(video.path, filename: 'long_video$ext'),
        ));
      }

      debugPrint('[LongVideo] Creating long video...');
      final response = await _dio.post(
        ApiConstants.longVideoCreate,
        data: formData,
        options: Options(
          // Long video uploads can take several minutes on slow networks.
          // Do not abort just because it exceeds the default 60s sendTimeout.
          sendTimeout: const Duration(minutes: 10),
          receiveTimeout: const Duration(minutes: 5),
        ),
      );

      // Success code 201 per spec
      if (response.statusCode != 201 && response.statusCode != 200) {
        final err = (response.data is Map
                ? (response.data['message'] ?? response.data['error'])
                : null) ??
            'Failed to create long video';
        return CreateLongVideoResult.failure(err.toString());
      }

      final responseData = response.data as Map<String, dynamic>?;
      if (responseData == null) {
        return CreateLongVideoResult.failure('Invalid response');
      }

      final inner = responseData['longVideo'] ??
          responseData['video'] ??
          responseData['data'];
      final videoData = inner is Map<String, dynamic>
          ? inner
          : responseData;
      final created = LongVideoModelApi.fromJson(videoData);
      debugPrint('[LongVideo] Created: ${created.id}');
      return CreateLongVideoResult.success(created);
    } on DioException catch (e) {
      if (e.response != null) {
        final errorData = e.response?.data;
        final errorMsg = errorData is Map
            ? (errorData['message'] ?? errorData['error'] ?? 'Request failed')
            : 'Request failed';
        final msg = errorMsg.toString();
        debugPrint('[LongVideo] Failed: $msg');
        return CreateLongVideoResult.failure(msg);
      }
      final msg = _networkErrorMessage(e.message);
      debugPrint('[LongVideo] Failed: $msg');
      return CreateLongVideoResult.failure(msg);
    } on TimeoutException catch (_) {
      debugPrint('[LongVideo] Failed: Request timed out');
      return CreateLongVideoResult.failure('Request timed out');
    } catch (e) {
      debugPrint('[LongVideo] Failed: $e');
      return CreateLongVideoResult.failure(
        e is Exception ? e.toString() : 'Something went wrong',
      );
    }
  }

  Future<GetLongVideosResult> getLongVideos() async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      return GetLongVideosResult.failure('Not authenticated');
    }
    try {
      DioClient.setAuthToken(token);
      final response = await _dio.get(ApiConstants.longVideoList);
      final data = response.data as Map<String, dynamic>?;
      if (data == null || data['success'] != true) {
        final err = data?['message'] as String? ??
            data?['error'] as String? ??
            'Failed to load long videos';
        return GetLongVideosResult.failure(err.toString());
      }
      final list = data['longVideos'] ?? data['videos'] ?? data['data'];
      if (list == null || list is! List) {
        return GetLongVideosResult.success([]);
      }
      final videos = <LongVideoWithUserModel>[];
      for (final e in list) {
        if (e is Map<String, dynamic>) {
          videos.add(LongVideoWithUserModel.fromJson(e));
        }
      }
      return GetLongVideosResult.success(videos);
    } on DioException catch (e) {
      if (e.response != null) {
        final d = e.response?.data;
        final msg = d is Map ? (d['message'] ?? d['error'] ?? 'Request failed') : 'Request failed';
        return GetLongVideosResult.failure(msg.toString());
      }
      return GetLongVideosResult.failure(_networkErrorMessage(e.message));
    } on TimeoutException catch (_) {
      return GetLongVideosResult.failure('Request timed out');
    } catch (e) {
      return GetLongVideosResult.failure(
        e is Exception ? e.toString() : 'Something went wrong',
      );
    }
  }

  Future<GetLongVideosResult> getLongVideosByUserId(String userId) async {
    if (userId.isEmpty) return GetLongVideosResult.success([]);
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      return GetLongVideosResult.failure('Not authenticated');
    }
    try {
      DioClient.setAuthToken(token);
      final response = await _dio.get(ApiConstants.longVideoByUser(userId));
      final data = response.data as Map<String, dynamic>?;
      if (data == null || data['success'] != true) {
        final err = data?['message'] as String? ??
            data?['error'] as String? ??
            'Failed to load long videos';
        return GetLongVideosResult.failure(err.toString());
      }
      final list = data['longVideos'] ?? data['videos'] ?? data['data'];
      if (list == null || list is! List) {
        return GetLongVideosResult.success([]);
      }
      final videos = <LongVideoWithUserModel>[];
      for (final e in list) {
        if (e is Map<String, dynamic>) {
          videos.add(LongVideoWithUserModel.fromJson(e));
        }
      }
      return GetLongVideosResult.success(videos);
    } on DioException catch (e) {
      if (e.response != null) {
        final d = e.response?.data;
        final msg = d is Map ? (d['message'] ?? d['error'] ?? 'Request failed') : 'Request failed';
        return GetLongVideosResult.failure(msg.toString());
      }
      return GetLongVideosResult.failure(_networkErrorMessage(e.message));
    } on TimeoutException catch (_) {
      return GetLongVideosResult.failure('Request timed out');
    } catch (e) {
      return GetLongVideosResult.failure(
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
