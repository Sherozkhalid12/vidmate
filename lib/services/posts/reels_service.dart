import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/dio_client.dart';
import '../../core/constants/api_constants.dart';
import '../../core/models/reel_response_model.dart';
import '../../core/utils/reels_json_parser.dart';

class CreateReelResult {
  final bool success;
  final ReelModelApi? data;
  final String? errorMessage;

  CreateReelResult({
    required this.success,
    this.data,
    this.errorMessage,
  });

  factory CreateReelResult.failure(String message) =>
      CreateReelResult(success: false, errorMessage: message);

  factory CreateReelResult.success(ReelModelApi data) =>
      CreateReelResult(success: true, data: data);
}

class GetReelsResult {
  final bool success;
  final List<ReelWithUserModel> reels;
  final String? errorMessage;

  GetReelsResult({
    required this.success,
    this.reels = const [],
    this.errorMessage,
  });

  factory GetReelsResult.failure(String message) =>
      GetReelsResult(success: false, errorMessage: message);

  factory GetReelsResult.success(List<ReelWithUserModel> reels) =>
      GetReelsResult(success: true, reels: reels);
}

class CreateReelParams {
  final File? video;
  final File? thumbnailFile;
  final String? thumbnailUrl;
  final String? music;
  final String? caption;
  final List<String> locations;
  final List<String> taggedUsers;
  final List<String> feelings;

  CreateReelParams({
    this.video,
    this.thumbnailFile,
    this.thumbnailUrl,
    this.music,
    this.caption,
    this.locations = const [],
    this.taggedUsers = const [],
    this.feelings = const [],
  });

  String? validate() {
    if (video == null || video!.path.isEmpty) return 'Video is required';
    if (thumbnailFile != null && thumbnailFile!.path.isEmpty) {
      return 'Invalid thumbnail file';
    }
    if (!video!.path.toLowerCase().endsWith('.mp4') &&
        !video!.path.toLowerCase().endsWith('.mov') &&
        !video!.path.toLowerCase().endsWith('.webm')) {
      return 'Invalid video format';
    }
    return null;
  }
}

class ReelsService {
  static const String _tokenKey = 'auth_token';
  final Dio _dio = DioClient.instance;

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<CreateReelResult> createReel(CreateReelParams params) async {
    final validationError = params.validate();
    if (validationError != null) {
      return CreateReelResult.failure(validationError);
    }

    final token = await _getToken();
    if (token == null || token.isEmpty) {
      return CreateReelResult.failure('Not authenticated');
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
      if (params.music != null && params.music!.trim().isNotEmpty) {
        formData.fields.add(MapEntry('music', params.music!.trim()));
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
          await MultipartFile.fromFile(video.path, filename: 'reel$ext'),
        ));
      }

      debugPrint('[Reels] Creating reel...');
      final response = await _dio.post(
        ApiConstants.reelCreate,
        data: formData,
      );

      final responseData = response.data as Map<String, dynamic>?;
      if (responseData == null || responseData['success'] != true) {
        final err = responseData?['message'] as String? ??
            responseData?['error'] as String? ??
            'Failed to create reel';
        debugPrint('[Reels] Failed: $err');
        return CreateReelResult.failure(err);
      }

      final reelJson = responseData['reel'] as Map<String, dynamic>?;
      if (reelJson == null) {
        debugPrint('[Reels] Failed: Invalid response (missing reel)');
        return CreateReelResult.failure('Invalid response: missing reel');
      }

      final reel = ReelModelApi.fromJson(reelJson);
      debugPrint('[Reels] Created: ${reel.id}');
      return CreateReelResult.success(reel);
    } on DioException catch (e) {
      if (e.response != null) {
        final errorData = e.response?.data;
        final errorMsg = errorData is Map
            ? (errorData['message'] ?? errorData['error'] ?? 'Request failed')
            : 'Request failed';
        final msg = errorMsg.toString();
        debugPrint('[Reels] Failed: $msg');
        return CreateReelResult.failure(msg);
      }
      final msg = _networkErrorMessage(e.message);
      debugPrint('[Reels] Failed: $msg');
      return CreateReelResult.failure(msg);
    } on TimeoutException catch (_) {
      debugPrint('[Reels] Failed: Request timed out');
      return CreateReelResult.failure('Request timed out');
    } catch (e) {
      debugPrint('[Reels] Failed: $e');
      return CreateReelResult.failure(
        e is Exception ? e.toString() : 'Something went wrong',
      );
    }
  }

  Future<GetReelsResult> getReels() async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      return GetReelsResult.failure('Not authenticated');
    }
    try {
      DioClient.setAuthToken(token);
      final response = await _dio.get<String>(
        ApiConstants.reelList,
        options: Options(responseType: ResponseType.plain),
      );
      final body = response.data ?? '';
      final envelope = await compute(parseReelsApiEnvelope, body);
      final ok = envelope['success'] == true;
      if (!ok) {
        return GetReelsResult.failure(
          envelope['message']?.toString() ?? 'Failed to load reels',
        );
      }
      final items = envelope['items'];
      final reels = <ReelWithUserModel>[];
      if (items is List) {
        for (final e in items) {
          if (e is Map<String, dynamic>) {
            reels.add(ReelWithUserModel.fromJson(e));
          } else if (e is Map) {
            reels.add(ReelWithUserModel.fromJson(Map<String, dynamic>.from(e)));
          }
        }
      }
      return GetReelsResult.success(reels);
    } on DioException catch (e) {
      if (e.response != null) {
        final d = e.response?.data;
        final msg = d is Map ? (d['message'] ?? d['error'] ?? 'Request failed') : 'Request failed';
        return GetReelsResult.failure(msg.toString());
      }
      return GetReelsResult.failure(_networkErrorMessage(e.message));
    } on TimeoutException catch (_) {
      return GetReelsResult.failure('Request timed out');
    } catch (e) {
      return GetReelsResult.failure(
        e is Exception ? e.toString() : 'Something went wrong',
      );
    }
  }

  Future<GetReelsResult> getReelsByUserId(String userId) async {
    if (userId.isEmpty) return GetReelsResult.success([]);
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      return GetReelsResult.failure('Not authenticated');
    }
    try {
      DioClient.setAuthToken(token);
      final response = await _dio.get(ApiConstants.reelByUser(userId));
      final data = response.data as Map<String, dynamic>?;
      if (data == null || data['success'] != true) {
        final err = data?['message'] as String? ??
            data?['error'] as String? ??
            'Failed to load reels';
        return GetReelsResult.failure(err.toString());
      }
      final list = data['reels'] ?? data['data'];
      if (list == null || list is! List) {
        return GetReelsResult.success([]);
      }
      final reels = <ReelWithUserModel>[];
      for (final e in list) {
        if (e is Map<String, dynamic>) {
          reels.add(ReelWithUserModel.fromJson(e));
        }
      }
      return GetReelsResult.success(reels);
    } on DioException catch (e) {
      if (e.response != null) {
        final d = e.response?.data;
        final msg = d is Map ? (d['message'] ?? d['error'] ?? 'Request failed') : 'Request failed';
        return GetReelsResult.failure(msg.toString());
      }
      return GetReelsResult.failure(_networkErrorMessage(e.message));
    } on TimeoutException catch (_) {
      return GetReelsResult.failure('Request timed out');
    } catch (e) {
      return GetReelsResult.failure(
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
