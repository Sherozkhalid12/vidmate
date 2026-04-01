import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/dio_client.dart';
import '../../core/constants/api_constants.dart';
import '../../core/models/livestream_model.dart';
import '../../core/utils/app_logger.dart';

class LivestreamResult<T> {
  final bool success;
  final T? data;
  final String? errorMessage;

  const LivestreamResult({
    required this.success,
    this.data,
    this.errorMessage,
  });

  factory LivestreamResult.success(T data) =>
      LivestreamResult(success: true, data: data);

  factory LivestreamResult.failure(String message) =>
      LivestreamResult(success: false, errorMessage: message);
}

class LivestreamService {
  static const String _tokenKey = 'auth_token';
  final Dio _dio = DioClient.instance;

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<LivestreamResult<LivestreamAgoraAuth>> startLive({
    required String channelName,
    int uid = 0,
    String? title,
    String? description,
    String? thumbnail,
  }) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      return LivestreamResult.failure('Not authenticated');
    }

    try {
      DioClient.setAuthToken(token);
      final body = <String, dynamic>{
        'channelName': channelName,
        if (uid != 0) 'uid': uid,
        // Backend may expect these keys during creation, so always send if provided.
        if (title != null) 'title': title.trim(),
        if (description != null) 'description': description.trim(),
        if (thumbnail != null && thumbnail.trim().isNotEmpty)
          'thumbnail': thumbnail.trim(),
      };

      final response = await _dio.post(ApiConstants.liveStart, data: body);
      final map = response.data as Map<String, dynamic>?;
      if (map == null || map['success'] != true) {
        final msg = map?['message']?.toString() ??
            map?['error']?.toString() ??
            'Failed to start livestream';
        return LivestreamResult.failure(msg);
      }

      final data = map['data'] as Map<String, dynamic>?;
      if (data == null) {
        return LivestreamResult.failure('Invalid response: missing data');
      }

      final appId = data['appId']?.toString() ?? '';
      final ch = data['channelName']?.toString() ?? '';
      final agoraToken = data['token']?.toString() ?? '';
      final returnedUid = data['uid'] is int
          ? data['uid'] as int
          : int.tryParse(data['uid']?.toString() ?? '') ?? 0;
      final role = data['role']?.toString() ?? 'publisher';

      final streamJson = data['stream'] as Map<String, dynamic>?;
      if (appId.isEmpty || ch.isEmpty || agoraToken.isEmpty || streamJson == null) {
        return LivestreamResult.failure('Invalid response: incomplete data');
      }

      final stream = LivestreamModel.fromJson(streamJson);
      return LivestreamResult.success(
        LivestreamAgoraAuth(
          appId: appId,
          channelName: ch,
          token: agoraToken,
          uid: returnedUid,
          role: role,
          stream: stream,
        ),
      );
    } on DioException catch (e) {
      final d = e.response?.data;
      final msg = d is Map
          ? (d['message'] ?? d['error'] ?? e.message).toString()
          : (e.message ?? 'Request failed');
      return LivestreamResult.failure(msg);
    } catch (e) {
      return LivestreamResult.failure(e.toString());
    }
  }

  Future<LivestreamResult<LivestreamAgoraAuth>> tokenForLive({
    required String streamId,
    int uid = 0,
    String role = 'subscriber',
  }) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      return LivestreamResult.failure('Not authenticated');
    }

    try {
      DioClient.setAuthToken(token);
      final body = <String, dynamic>{
        'streamId': streamId,
        if (uid != 0) 'uid': uid,
        if (role.trim().isNotEmpty) 'role': role.trim(),
      };

      final response = await _dio.post(ApiConstants.liveToken, data: body);
      final map = response.data as Map<String, dynamic>?;
      if (map == null || map['success'] != true) {
        final msg = map?['message']?.toString() ??
            map?['error']?.toString() ??
            'Failed to generate livestream token';
        return LivestreamResult.failure(msg);
      }

      final data = map['data'] as Map<String, dynamic>?;
      if (data == null) {
        return LivestreamResult.failure('Invalid response: missing data');
      }

      final appId = data['appId']?.toString() ?? '';
      final ch = data['channelName']?.toString() ?? '';
      final agoraToken = data['token']?.toString() ?? '';
      final returnedUid = data['uid'] is int
          ? data['uid'] as int
          : int.tryParse(data['uid']?.toString() ?? '') ?? 0;
      final returnedRole = data['role']?.toString() ?? 'subscriber';
      final streamJson = data['stream'] as Map<String, dynamic>?;
      if (appId.isEmpty || ch.isEmpty || agoraToken.isEmpty || streamJson == null) {
        return LivestreamResult.failure('Invalid response: incomplete data');
      }

      final stream = LivestreamModel.fromJson(streamJson);
      return LivestreamResult.success(
        LivestreamAgoraAuth(
          appId: appId,
          channelName: ch,
          token: agoraToken,
          uid: returnedUid,
          role: returnedRole,
          stream: stream,
        ),
      );
    } on DioException catch (e) {
      final d = e.response?.data;
      final msg = d is Map
          ? (d['message'] ?? d['error'] ?? e.message).toString()
          : (e.message ?? 'Request failed');
      return LivestreamResult.failure(msg);
    } catch (e) {
      return LivestreamResult.failure(e.toString());
    }
  }

  Future<LivestreamResult<List<LivestreamModel>>> getActive({int limit = 20}) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      return LivestreamResult.failure('Not authenticated');
    }
    final l = limit.clamp(1, 100);
    try {
      DioClient.setAuthToken(token);
      final response = await _dio.get(
        ApiConstants.liveActive,
        queryParameters: {'limit': l},
      );
      final map = response.data as Map<String, dynamic>?;
      if (map == null || map['success'] != true) {
        final msg = map?['message']?.toString() ??
            map?['error']?.toString() ??
            'Failed to fetch livestreams';
        return LivestreamResult.failure(msg);
      }
      final list = map['streams'];
      if (list is! List) return LivestreamResult.success(const []);
      final streams = <LivestreamModel>[];
      for (final e in list) {
        if (e is Map<String, dynamic>) streams.add(LivestreamModel.fromJson(e));
      }
      return LivestreamResult.success(streams);
    } on DioException catch (e) {
      final d = e.response?.data;
      final msg = d is Map
          ? (d['message'] ?? d['error'] ?? e.message).toString()
          : (e.message ?? 'Request failed');
      return LivestreamResult.failure(msg);
    } catch (e) {
      return LivestreamResult.failure(e.toString());
    }
  }

  Future<LivestreamResult<LivestreamModel>> getById(String streamId) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      return LivestreamResult.failure('Not authenticated');
    }
    if (streamId.isEmpty) return LivestreamResult.failure('Invalid streamId');
    try {
      DioClient.setAuthToken(token);
      final response = await _dio.get(ApiConstants.liveById(streamId));
      final map = response.data as Map<String, dynamic>?;
      if (map == null || map['success'] != true) {
        final msg = map?['message']?.toString() ??
            map?['error']?.toString() ??
            'Failed to fetch livestream';
        return LivestreamResult.failure(msg);
      }
      final s = map['stream'];
      if (s is! Map<String, dynamic>) {
        return LivestreamResult.failure('Invalid response: missing stream');
      }
      return LivestreamResult.success(LivestreamModel.fromJson(s));
    } on DioException catch (e) {
      final d = e.response?.data;
      final msg = d is Map
          ? (d['message'] ?? d['error'] ?? e.message).toString()
          : (e.message ?? 'Request failed');
      return LivestreamResult.failure(msg);
    } catch (e) {
      return LivestreamResult.failure(e.toString());
    }
  }

  Future<LivestreamResult<LivestreamModel>> join(String streamId) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      return LivestreamResult.failure('Not authenticated');
    }
    if (streamId.isEmpty) return LivestreamResult.failure('Invalid streamId');
    try {
      DioClient.setAuthToken(token);
      final response =
          await _dio.post(ApiConstants.liveJoin, data: {'streamId': streamId});
      final map = response.data as Map<String, dynamic>?;
      if (map == null || map['success'] != true) {
        final msg = map?['message']?.toString() ??
            map?['error']?.toString() ??
            'Failed to join livestream';
        return LivestreamResult.failure(msg);
      }
      final s = map['stream'];
      if (s is! Map<String, dynamic>) {
        return LivestreamResult.failure('Invalid response: missing stream');
      }
      return LivestreamResult.success(LivestreamModel.fromJson(s));
    } on DioException catch (e) {
      final d = e.response?.data;
      final msg = d is Map
          ? (d['message'] ?? d['error'] ?? e.message).toString()
          : (e.message ?? 'Request failed');
      return LivestreamResult.failure(msg);
    } catch (e) {
      return LivestreamResult.failure(e.toString());
    }
  }

  Future<LivestreamResult<LivestreamModel>> leave(String streamId) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      return LivestreamResult.failure('Not authenticated');
    }
    if (streamId.isEmpty) return LivestreamResult.failure('Invalid streamId');
    try {
      DioClient.setAuthToken(token);
      final response =
          await _dio.post(ApiConstants.liveLeave, data: {'streamId': streamId});
      final map = response.data as Map<String, dynamic>?;
      if (map == null || map['success'] != true) {
        final msg = map?['message']?.toString() ??
            map?['error']?.toString() ??
            'Failed to leave livestream';
        return LivestreamResult.failure(msg);
      }
      final s = map['stream'];
      if (s is! Map<String, dynamic>) {
        return LivestreamResult.failure('Invalid response: missing stream');
      }
      return LivestreamResult.success(LivestreamModel.fromJson(s));
    } on DioException catch (e) {
      final d = e.response?.data;
      final msg = d is Map
          ? (d['message'] ?? d['error'] ?? e.message).toString()
          : (e.message ?? 'Request failed');
      return LivestreamResult.failure(msg);
    } catch (e) {
      return LivestreamResult.failure(e.toString());
    }
  }

  Future<LivestreamResult<LivestreamModel>> end(String streamId) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      return LivestreamResult.failure('Not authenticated');
    }
    if (streamId.isEmpty) return LivestreamResult.failure('Invalid streamId');
    try {
      DioClient.setAuthToken(token);
      final response =
          await _dio.patch(ApiConstants.liveEndById(streamId));
      final map = response.data as Map<String, dynamic>?;
      if (map == null || map['success'] != true) {
        final msg = map?['message']?.toString() ??
            map?['error']?.toString() ??
            'Failed to end livestream';
        return LivestreamResult.failure(msg);
      }
      final s = map['stream'];
      if (s is! Map<String, dynamic>) {
        return LivestreamResult.failure('Invalid response: missing stream');
      }
      return LivestreamResult.success(LivestreamModel.fromJson(s));
    } on DioException catch (e) {
      final d = e.response?.data;
      final msg = d is Map
          ? (d['message'] ?? d['error'] ?? e.message).toString()
          : (e.message ?? 'Request failed');
      return LivestreamResult.failure(msg);
    } catch (e) {
      return LivestreamResult.failure(e.toString());
    }
  }

  /// POST /calls/live/end-all (backend ends all active streams for host on restart).
  Future<LivestreamResult<LivestreamModel>> endAllActive() async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      return LivestreamResult.failure('Not authenticated');
    }
    try {
      DioClient.setAuthToken(token);
      AppLogger.d('LiveService', 'POST ${ApiConstants.liveEndAll}');
      final response = await _dio.post(ApiConstants.liveEndAll);
      AppLogger.d('LiveService', 'POST ${ApiConstants.liveEndAll} -> ${response.statusCode}');
      final map = response.data as Map<String, dynamic>?;
      if (map == null || map['success'] != true) {
        final msg = map?['message']?.toString() ??
            map?['error']?.toString() ??
            'Failed to end livestream';
        AppLogger.d('LiveService', 'POST end-all error: $msg');
        return LivestreamResult.failure(msg);
      }
      final s = map['stream'];
      if (s is! Map<String, dynamic>) {
        return LivestreamResult.failure('Invalid response: missing stream');
      }
      return LivestreamResult.success(LivestreamModel.fromJson(s));
    } on DioException catch (e) {
      final d = e.response?.data;
      final msg = d is Map
          ? (d['message'] ?? d['error'] ?? e.message).toString()
          : (e.message ?? 'Request failed');
      AppLogger.d('LiveService', 'POST end-all error: $msg');
      return LivestreamResult.failure(msg);
    } catch (e) {
      AppLogger.d('LiveService', 'POST end-all error: $e');
      return LivestreamResult.failure(e.toString());
    }
  }

  /// POST /live/message/:id (or /live/message with {streamId})
  Future<LivestreamResult<Map<String, dynamic>>> sendMessage({
    required String streamId,
    required String message,
  }) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      return LivestreamResult.failure('Not authenticated');
    }
    if (streamId.isEmpty) return LivestreamResult.failure('Invalid streamId');
    if (message.trim().isEmpty) return LivestreamResult.failure('Empty message');
    try {
      DioClient.setAuthToken(token);
      final res = await _dio.post(
        ApiConstants.liveMessageById(streamId),
        data: {'message': message.trim()},
      );
      final map = res.data as Map<String, dynamic>?;
      if (map == null || map['success'] != true) {
        final msg = map?['message']?.toString() ??
            map?['error']?.toString() ??
            'Failed to send message';
        return LivestreamResult.failure(msg);
      }
      return LivestreamResult.success(Map<String, dynamic>.from(map));
    } on DioException catch (e) {
      final d = e.response?.data;
      final msg = d is Map
          ? (d['message'] ?? d['error'] ?? e.message).toString()
          : (e.message ?? 'Request failed');
      return LivestreamResult.failure(msg);
    } catch (e) {
      return LivestreamResult.failure(e.toString());
    }
  }

  /// GET /live/:id/messages?limit=...
  Future<LivestreamResult<List<Map<String, dynamic>>>> getMessages({
    required String streamId,
    int limit = 50,
  }) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      return LivestreamResult.failure('Not authenticated');
    }
    if (streamId.isEmpty) return LivestreamResult.failure('Invalid streamId');
    final l = limit.clamp(1, 200);
    try {
      DioClient.setAuthToken(token);
      final res = await _dio.get(
        ApiConstants.liveMessagesById(streamId),
        queryParameters: {'limit': l},
      );
      final map = res.data as Map<String, dynamic>?;
      if (map == null || map['success'] != true) {
        final msg = map?['message']?.toString() ??
            map?['error']?.toString() ??
            'Failed to load messages';
        return LivestreamResult.failure(msg);
      }
      final list = map['messages'];
      if (list is! List) return LivestreamResult.success(const []);
      final out = <Map<String, dynamic>>[];
      for (final e in list) {
        if (e is Map) out.add(Map<String, dynamic>.from(e));
      }
      return LivestreamResult.success(out);
    } on DioException catch (e) {
      final d = e.response?.data;
      final msg = d is Map
          ? (d['message'] ?? d['error'] ?? e.message).toString()
          : (e.message ?? 'Request failed');
      return LivestreamResult.failure(msg);
    } catch (e) {
      return LivestreamResult.failure(e.toString());
    }
  }

  /// POST /live/like/:id (toggle). Returns liked true/false + likeCount.
  Future<LivestreamResult<Map<String, dynamic>>> toggleLike({
    required String streamId,
  }) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      return LivestreamResult.failure('Not authenticated');
    }
    if (streamId.isEmpty) return LivestreamResult.failure('Invalid streamId');
    try {
      DioClient.setAuthToken(token);
      final res = await _dio.post(ApiConstants.liveLikeById(streamId));
      final map = res.data as Map<String, dynamic>?;
      if (map == null || map['success'] != true) {
        final msg = map?['message']?.toString() ??
            map?['error']?.toString() ??
            'Failed to like';
        return LivestreamResult.failure(msg);
      }
      return LivestreamResult.success(Map<String, dynamic>.from(map));
    } on DioException catch (e) {
      final d = e.response?.data;
      final msg = d is Map
          ? (d['message'] ?? d['error'] ?? e.message).toString()
          : (e.message ?? 'Request failed');
      return LivestreamResult.failure(msg);
    } catch (e) {
      return LivestreamResult.failure(e.toString());
    }
  }

  /// GET /live/:id/likes
  Future<LivestreamResult<Map<String, dynamic>>> getLikes({
    required String streamId,
  }) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      return LivestreamResult.failure('Not authenticated');
    }
    if (streamId.isEmpty) return LivestreamResult.failure('Invalid streamId');
    try {
      DioClient.setAuthToken(token);
      final res = await _dio.get(ApiConstants.liveLikesById(streamId));
      final map = res.data as Map<String, dynamic>?;
      if (map == null || map['success'] != true) {
        final msg = map?['message']?.toString() ??
            map?['error']?.toString() ??
            'Failed to load likes';
        return LivestreamResult.failure(msg);
      }
      return LivestreamResult.success(Map<String, dynamic>.from(map));
    } on DioException catch (e) {
      final d = e.response?.data;
      final msg = d is Map
          ? (d['message'] ?? d['error'] ?? e.message).toString()
          : (e.message ?? 'Request failed');
      return LivestreamResult.failure(msg);
    } catch (e) {
      return LivestreamResult.failure(e.toString());
    }
  }
}

