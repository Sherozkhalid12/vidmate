import 'package:dio/dio.dart';

import '../../core/api/dio_client.dart';
import '../../core/constants/api_constants.dart';
import '../../core/models/blocked_user_model.dart';
import '../auth/auth_service.dart';

class BlockedUsersListResult {
  const BlockedUsersListResult({
    required this.success,
    this.users = const [],
    this.errorMessage,
  });

  final bool success;
  final List<BlockedUserModel> users;
  final String? errorMessage;

  factory BlockedUsersListResult.failure(String message) =>
      BlockedUsersListResult(success: false, errorMessage: message);
}

class BlockUserResult {
  const BlockUserResult({
    required this.success,
    this.blockedUserIds = const [],
    this.errorMessage,
  });

  final bool success;
  final List<String> blockedUserIds;
  final String? errorMessage;

  factory BlockUserResult.failure(String message) =>
      BlockUserResult(success: false, errorMessage: message);
}

/// Block / unblock users via VidConnect auth APIs.
class BlockedUsersService {
  final Dio _dio = DioClient.instance;
  final AuthService _authService = AuthService();

  Future<void> _ensureAuth() async {
    final token = await _authService.getToken();
    if (token != null && token.isNotEmpty) {
      DioClient.setAuthToken(token);
    }
  }

  Future<BlockedUsersListResult> fetchBlockedUsers() async {
    try {
      await _ensureAuth();
      final response = await _dio.get(ApiConstants.authBlocked);
      final data = response.data;
      if (data is! Map<String, dynamic> || data['success'] != true) {
        final msg = data is Map
            ? (data['message'] ?? data['error'] ?? 'Failed to load blocked users')
                .toString()
            : 'Failed to load blocked users';
        return BlockedUsersListResult.failure(msg);
      }

      final raw = data['blockedUsers'];
      final users = <BlockedUserModel>[];
      if (raw is List) {
        for (final item in raw) {
          if (item is Map<String, dynamic>) {
            users.add(BlockedUserModel.fromJson(item));
          } else if (item is Map) {
            users.add(BlockedUserModel.fromJson(Map<String, dynamic>.from(item)));
          }
        }
      }
      return BlockedUsersListResult(success: true, users: users);
    } on DioException catch (e) {
      final msg = _dioMessage(e, fallback: 'Failed to load blocked users');
      return BlockedUsersListResult.failure(msg);
    } catch (e) {
      return BlockedUsersListResult.failure(e.toString());
    }
  }

  Future<BlockUserResult> blockUser(String userId) async {
    final id = userId.trim();
    if (id.isEmpty) {
      return BlockUserResult.failure('Invalid user id');
    }
    try {
      await _ensureAuth();
      final response = await _dio.patch(ApiConstants.authBlockUser(id));
      final data = response.data;
      if (data is! Map<String, dynamic> || data['success'] != true) {
        final msg = data is Map
            ? (data['message'] ?? data['error'] ?? 'Failed to block user')
                .toString()
            : 'Failed to block user';
        return BlockUserResult.failure(msg);
      }
      final ids = _parseIdList(data['blockedUsers']);
      return BlockUserResult(success: true, blockedUserIds: ids);
    } on DioException catch (e) {
      return BlockUserResult.failure(_dioMessage(e, fallback: 'Failed to block user'));
    } catch (e) {
      return BlockUserResult.failure(e.toString());
    }
  }

  Future<BlockUserResult> unblockUser(String userId) async {
    final id = userId.trim();
    if (id.isEmpty) {
      return BlockUserResult.failure('Invalid user id');
    }
    try {
      await _ensureAuth();
      final response = await _dio.patch(ApiConstants.authUnblockUser(id));
      final data = response.data;
      if (data is! Map<String, dynamic> || data['success'] != true) {
        final msg = data is Map
            ? (data['message'] ?? data['error'] ?? 'Failed to unblock user')
                .toString()
            : 'Failed to unblock user';
        return BlockUserResult.failure(msg);
      }
      final ids = _parseIdList(data['blockedUsers']);
      return BlockUserResult(success: true, blockedUserIds: ids);
    } on DioException catch (e) {
      return BlockUserResult.failure(_dioMessage(e, fallback: 'Failed to unblock user'));
    } catch (e) {
      return BlockUserResult.failure(e.toString());
    }
  }

  List<String> _parseIdList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) => e?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
  }

  String _dioMessage(DioException e, {required String fallback}) {
    final data = e.response?.data;
    if (data is Map) {
      final msg = data['message'] ?? data['error'];
      if (msg != null && msg.toString().isNotEmpty) return msg.toString();
    }
    return fallback;
  }
}
