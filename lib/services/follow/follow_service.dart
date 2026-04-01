import 'package:dio/dio.dart';

import '../../core/api/dio_client.dart';
import '../../core/constants/api_constants.dart';
import '../../core/models/user_model.dart';
import '../auth/auth_service.dart';

/// Result of follow/unfollow API call.
class FollowOperationResult {
  final bool success;
  final String? status; // 'following' | 'pending' | 'cancelled' | etc.
  final String? requestId;
  final String? errorMessage;

  FollowOperationResult({
    required this.success,
    this.status,
    this.requestId,
    this.errorMessage,
  });

  factory FollowOperationResult.failure(String message) =>
      FollowOperationResult(success: false, errorMessage: message);

  factory FollowOperationResult.success() =>
      FollowOperationResult(success: true);

  factory FollowOperationResult.successWith({
    String? status,
    String? requestId,
  }) =>
      FollowOperationResult(success: true, status: status, requestId: requestId);
}

/// Result of get followings/followers list API call.
class FollowListResult {
  final bool success;
  final List<UserModel> users;
  final int count;
  final String? errorMessage;

  FollowListResult({
    required this.success,
    this.users = const [],
    this.count = 0,
    this.errorMessage,
  });

  factory FollowListResult.failure(String message) =>
      FollowListResult(success: false, errorMessage: message);

  factory FollowListResult.success(List<UserModel> users, int count) =>
      FollowListResult(success: true, users: users, count: count);
}

/// Follow/unfollow and get followings/followers API service.
/// Uses same Dio client and auth token pattern as AuthService.
class FollowService {
  final Dio _dio = DioClient.instance;
  final AuthService _authService = AuthService();

  Future<void> _ensureAuth() async {
    final token = await _authService.getToken();
    if (token != null && token.isNotEmpty) {
      DioClient.setAuthToken(token);
    }
  }

  /// PATCH follow user by id. Returns success/error.
  Future<FollowOperationResult> follow(String userId) async {
    try {
      await _ensureAuth();
      final response = await _dio.patch(
        ApiConstants.followUser(userId),
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final success = data['success'] == true;
        if (success) {
          return FollowOperationResult.successWith(
            status: data['status']?.toString(),
            requestId: data['requestId']?.toString(),
          );
        }
        return FollowOperationResult.failure(
          data['message']?.toString() ?? 'Follow failed',
        );
      }
      return FollowOperationResult.failure('Invalid response');
    } on DioException catch (e) {
      final errorData = e.response?.data;
      final msg = errorData is Map
          ? (errorData['message'] ?? errorData['error'] ?? 'Follow failed')
          : 'Follow failed';
      return FollowOperationResult.failure(msg.toString());
    } catch (e) {
      return FollowOperationResult.failure('Follow failed: ${e.toString()}');
    }
  }

  /// PATCH unfollow user by id. Returns success/error.
  Future<FollowOperationResult> unfollow(String userId) async {
    try {
      await _ensureAuth();
      final response = await _dio.patch(
        ApiConstants.unfollowUser(userId),
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final success = data['success'] == true;
        if (success) {
          return FollowOperationResult.successWith(
            status: data['status']?.toString(),
          );
        }
        return FollowOperationResult.failure(
          data['message']?.toString() ?? 'Unfollow failed',
        );
      }
      return FollowOperationResult.failure('Invalid response');
    } on DioException catch (e) {
      final errorData = e.response?.data;
      final msg = errorData is Map
          ? (errorData['message'] ?? errorData['error'] ?? 'Unfollow failed')
          : 'Unfollow failed';
      return FollowOperationResult.failure(msg.toString());
    } catch (e) {
      return FollowOperationResult.failure('Unfollow failed: ${e.toString()}');
    }
  }

  /// GET current user's following list.
  Future<FollowListResult> getFollowings() async {
    try {
      await _ensureAuth();
      final response = await _dio.get(ApiConstants.getFollowings);
      return _parseFollowListResponse(response.data, 'following');
    } on DioException catch (e) {
      final errorData = e.response?.data;
      final msg = errorData is Map
          ? (errorData['message'] ?? errorData['error'] ?? 'Failed to load following')
          : 'Failed to load following';
      return FollowListResult.failure(msg.toString());
    } catch (e) {
      return FollowListResult.failure(
        'Failed to load following: ${e.toString()}',
      );
    }
  }

  /// GET current user's followers list.
  Future<FollowListResult> getFollowers() async {
    try {
      await _ensureAuth();
      final response = await _dio.get(ApiConstants.getFollowers);
      return _parseFollowListResponse(response.data, 'followers');
    } on DioException catch (e) {
      final errorData = e.response?.data;
      final msg = errorData is Map
          ? (errorData['message'] ?? errorData['error'] ?? 'Failed to load followers')
          : 'Failed to load followers';
      return FollowListResult.failure(msg.toString());
    } catch (e) {
      return FollowListResult.failure(
        'Failed to load followers: ${e.toString()}',
      );
    }
  }

  /// Parse API response: { success, count, following?: [], followers?: [] }.
  FollowListResult _parseFollowListResponse(
    dynamic data,
    String listKey,
  ) {
    if (data is! Map<String, dynamic>) {
      return FollowListResult.failure('Invalid response');
    }
    if (data['success'] != true) {
      return FollowListResult.failure(
        data['message']?.toString() ?? 'Request failed',
      );
    }
    final count = (data['count'] is int) ? data['count'] as int : 0;
    final list = data[listKey];
    if (list is! List) {
      return FollowListResult.success([], count);
    }
    final users = <UserModel>[];
    for (final item in list) {
      if (item is Map<String, dynamic>) {
        try {
          users.add(UserModel.fromJson(item));
        } catch (_) {
          // skip invalid item
        }
      }
    }
    return FollowListResult.success(users, count);
  }
}
