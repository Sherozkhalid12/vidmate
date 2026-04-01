import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/dio_client.dart';
import '../../core/constants/api_constants.dart';
import '../../core/models/call_model.dart';
import '../../core/utils/app_logger.dart';

class StartCallResult {
  final bool success;
  final String? errorMessage;
  final StartCallData? data;

  const StartCallResult({
    required this.success,
    this.errorMessage,
    this.data,
  });

  factory StartCallResult.failure(String message) =>
      StartCallResult(success: false, errorMessage: message);

  factory StartCallResult.success(StartCallData data) =>
      StartCallResult(success: true, data: data);
}

class StartCallData {
  final String appId;
  final String channelName;
  final String token;
  final int uid;
  final String callId;

  const StartCallData({
    required this.appId,
    required this.channelName,
    required this.token,
    required this.uid,
    required this.callId,
  });
}

class EndCallResult {
  final bool success;
  final String? errorMessage;
  final String? callId;

  const EndCallResult({
    required this.success,
    this.errorMessage,
    this.callId,
  });

  factory EndCallResult.failure(String message) =>
      EndCallResult(success: false, errorMessage: message);

  factory EndCallResult.success(String callId) =>
      EndCallResult(success: true, callId: callId);
}

class CallActionResult {
  final bool success;
  final String? errorMessage;
  final CallModel? call;

  const CallActionResult({
    required this.success,
    this.errorMessage,
    this.call,
  });

  factory CallActionResult.failure(String message) =>
      CallActionResult(success: false, errorMessage: message);

  factory CallActionResult.success({CallModel? call}) =>
      CallActionResult(success: true, call: call);
}

/// HTTP API wrapper for call lifecycle (Agora token + end call).
class CallsService {
  static const String _tokenKey = 'auth_token';
  final Dio _dio = DioClient.instance;

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// API 1: Start Call -> POST /api/v1/calls/agora/token
  ///
  /// Requires login (JWT).
  Future<StartCallResult> startAgoraCall({
    required String channelName,
    required String receiverId,
    int uid = 0,
    String? callerId,
  }) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      return StartCallResult.failure('Not authenticated');
    }

    try {
      DioClient.setAuthToken(token);

      final body = <String, dynamic>{
        'channelName': channelName,
        'receiverId': receiverId,
        'uid': uid,
      };
      if (callerId != null && callerId.trim().isNotEmpty) {
        body['callerId'] = callerId.trim();
      }

      final response = await _dio.post(
        ApiConstants.callsAgoraToken,
        data: body,
      );

      final data = response.data as Map<String, dynamic>?;
      final success = data?['success'] == true;
      if (!success) {
        final msg = data?['message']?.toString() ??
            data?['error']?.toString() ??
            'Failed to start call';
        return StartCallResult.failure(msg);
      }

      final payload = data?['data'] as Map<String, dynamic>?;
      if (payload == null) {
        return StartCallResult.failure('Invalid response: missing data');
      }

      final appId = payload['appId']?.toString() ?? '';
      final returnedChannelName = payload['channelName']?.toString() ?? '';
      final agToken = payload['token']?.toString() ?? '';
      final returnedUid = payload['uid'] is int
          ? payload['uid'] as int
          : int.tryParse(payload['uid']?.toString() ?? '') ?? uid;
      final callId = payload['callId']?.toString() ?? '';

      if (appId.isEmpty ||
          returnedChannelName.isEmpty ||
          agToken.isEmpty ||
          callId.isEmpty) {
        return StartCallResult.failure('Invalid response: incomplete data');
      }

      if (kDebugMode) {
        // Caller-side full payload logging (debounced by callId).
        const encoder = JsonEncoder.withIndent('  ');
        AppLogger.debounced(
          'calls:start:$callId',
          'CallsAPI',
          'POST /calls/agora/token -> 200\n${encoder.convert(payload)}',
          windowMs: 2000,
        );
      }

      return StartCallResult.success(
        StartCallData(
          appId: appId,
          channelName: returnedChannelName,
          token: agToken,
          uid: returnedUid,
          callId: callId,
        ),
      );
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response?.data['message'] ??
                  e.response?.data['error'] ??
                  e.message)
              ?.toString()
          : e.message;
      return StartCallResult.failure(msg?.isNotEmpty == true ? msg! : 'Request failed');
    } catch (e) {
      if (kDebugMode) debugPrint('[CallsService] startAgoraCall error: $e');
      return StartCallResult.failure(e.toString());
    }
  }

  /// API 2: End Call
  ///
  /// Tries Option A: PATCH /api/v1/calls/end/:id
  /// and falls back to Option B: POST /api/v1/calls/end {callId: ...}
  Future<EndCallResult> endCall(String callId) async {
    if (callId.trim().isEmpty) {
      return EndCallResult.failure('Invalid callId');
    }

    final token = await _getToken();
    if (token == null || token.isEmpty) {
      return EndCallResult.failure('Not authenticated');
    }

    try {
      DioClient.setAuthToken(token);

      try {
        await _dio.patch(ApiConstants.callsEndById(callId));
        return EndCallResult.success(callId);
      } catch (_) {
        final response = await _dio.post(
          ApiConstants.callsEnd,
          data: {'callId': callId},
        );
        final data = response.data as Map<String, dynamic>?;
        final ok = data?['success'] == true;
        if (!ok) {
          final msg = data?['message']?.toString() ??
              data?['error']?.toString() ??
              'Failed to end call';
          return EndCallResult.failure(msg);
        }
        return EndCallResult.success(callId);
      }
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response?.data['message'] ??
                  e.response?.data['error'] ??
                  e.message)
              ?.toString()
          : e.message;
      return EndCallResult.failure(msg?.isNotEmpty == true ? msg! : 'Request failed');
    } catch (e) {
      if (kDebugMode) debugPrint('[CallsService] endCall error: $e');
      return EndCallResult.failure(e.toString());
    }
  }

  /// API 2a: Accept Call
  /// Tries PATCH /api/v1/calls/accept/:id, falls back to POST /api/v1/calls/accept
  /// with body { "callId": "..." }.
  Future<CallActionResult> acceptCall(String callId) async {
    if (callId.trim().isEmpty) {
      return CallActionResult.failure('Invalid callId');
    }

    final token = await _getToken();
    if (token == null || token.isEmpty) {
      return CallActionResult.failure('Not authenticated');
    }

    try {
      DioClient.setAuthToken(token);

      Map<String, dynamic>? map;
      try {
        final response = await _dio.patch(ApiConstants.callsAcceptById(callId));
        map = response.data as Map<String, dynamic>?;
      } catch (_) {
        final response = await _dio.post(
          ApiConstants.callsAccept,
          data: {'callId': callId},
        );
        map = response.data as Map<String, dynamic>?;
      }

      final ok = map?['success'] == true;
      if (!ok) {
        final msg = map?['message']?.toString() ??
            map?['error']?.toString() ??
            'Failed to accept call';
        return CallActionResult.failure(msg);
      }

      final callJson = map?['call'] as Map<String, dynamic>?;
      final call = callJson == null ? null : CallModel.fromJson(callJson);
      return CallActionResult.success(call: call);
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response?.data['message'] ??
                  e.response?.data['error'] ??
                  e.message)
              ?.toString()
          : (e.message ?? 'Request failed');
      return CallActionResult.failure(msg?.isNotEmpty == true ? msg! : 'Request failed');
    } catch (e) {
      if (kDebugMode) debugPrint('[CallsService] acceptCall error: $e');
      return CallActionResult.failure(e.toString());
    }
  }

  /// API 2b: Reject Call
  /// Tries PATCH /api/v1/calls/reject/:id, falls back to POST /api/v1/calls/reject
  /// with body { "callId": "..." }.
  Future<CallActionResult> rejectCall(String callId) async {
    if (callId.trim().isEmpty) {
      return CallActionResult.failure('Invalid callId');
    }

    final token = await _getToken();
    if (token == null || token.isEmpty) {
      return CallActionResult.failure('Not authenticated');
    }

    try {
      DioClient.setAuthToken(token);

      Map<String, dynamic>? map;
      try {
        final response = await _dio.patch(ApiConstants.callsRejectById(callId));
        map = response.data as Map<String, dynamic>?;
      } catch (_) {
        final response = await _dio.post(
          ApiConstants.callsReject,
          data: {'callId': callId},
        );
        map = response.data as Map<String, dynamic>?;
      }

      final ok = map?['success'] == true;
      if (!ok) {
        final msg = map?['message']?.toString() ??
            map?['error']?.toString() ??
            'Failed to reject call';
        return CallActionResult.failure(msg);
      }

      final callJson = map?['call'] as Map<String, dynamic>?;
      final call = callJson == null ? null : CallModel.fromJson(callJson);
      return CallActionResult.success(call: call);
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response?.data['message'] ??
                  e.response?.data['error'] ??
                  e.message)
              ?.toString()
          : (e.message ?? 'Request failed');
      return CallActionResult.failure(msg?.isNotEmpty == true ? msg! : 'Request failed');
    } catch (e) {
      if (kDebugMode) debugPrint('[CallsService] rejectCall error: $e');
      return CallActionResult.failure(e.toString());
    }
  }
}

