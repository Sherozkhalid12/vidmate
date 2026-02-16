import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/dio_client.dart';
import '../../core/constants/api_constants.dart';
import '../../core/models/auth_response_model.dart';
import '../../core/models/user_model.dart';

/// Result of an auth API call. [data] on success, [errorMessage] on failure.
class AuthServiceResult {
  final bool success;
  final AuthResponseModel? data;
  final String? errorMessage;

  AuthServiceResult({
    required this.success,
    this.data,
    this.errorMessage,
  });

  factory AuthServiceResult.failure(String message) =>
      AuthServiceResult(success: false, errorMessage: message);

  factory AuthServiceResult.success(AuthResponseModel data) =>
      AuthServiceResult(success: true, data: data);
}

/// Result for non-auth responses (e.g. OTP send/verify).
class AuthOperationResult {
  final bool success;
  final String? errorMessage;

  AuthOperationResult({required this.success, this.errorMessage});

  factory AuthOperationResult.failure(String message) =>
      AuthOperationResult(success: false, errorMessage: message);

  factory AuthOperationResult.success() =>
      AuthOperationResult(success: true);
}

/// Authentication API service. Uses Dio with logging interceptor.
class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'auth_user';
  final Dio _dio = DioClient.instance;

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// Public for AuthNotifier.loadFromStorage().
  Future<String?> getToken() => _getToken();

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  /// Persist user so app can restore session (e.g. from splash, offline).
  Future<void> saveUser(Map<String, dynamic> userJson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(userJson));
  }

  /// Load stored user JSON; null if none or invalid.
  Future<Map<String, dynamic>?> getStoredUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// Clear token only (e.g. for backward compatibility).
  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  /// Clear all auth data (token + user). Use on logout.
  Future<void> clearAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }


  Future<AuthServiceResult> signup({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      DioClient.clearAuthToken();
      final response = await _dio.post(
        ApiConstants.authSignup,
        data: {
          'username': username,
          'email': email,
          'password': password,
        },
      );

      final responseData = response.data as Map<String, dynamic>?;
      if (responseData == null) {
        return AuthServiceResult.failure('Invalid response');
      }

      final token = responseData['token'];
      final userJson = responseData['user'];
      if (token == null || token.toString().trim().isEmpty) {
        return AuthServiceResult.failure('Invalid sign up response: missing token');
      }
      if (userJson == null || userJson is! Map<String, dynamic>) {
        return AuthServiceResult.failure('Invalid sign up response: missing user');
      }

      UserModel user;
      try {
        user = UserModel.fromJson(userJson);
      } catch (e) {
        return AuthServiceResult.failure('Invalid user data: $e');
      }

      await _saveToken(token.toString());
      await saveUser(userJson);
      final authResponse = AuthResponseModel(
        success: true,
        user: user,
        token: token.toString(),
      );
      return AuthServiceResult.success(authResponse);
    } on DioException catch (e) {
      final errorData = e.response?.data;
      final errorMsg = errorData is Map
          ? (errorData['message'] ?? errorData['error'] ?? 'Sign up failed')
          : 'Sign up failed';
      return AuthServiceResult.failure(errorMsg.toString());
    } on TimeoutException catch (_) {
      return AuthServiceResult.failure('Request timed out');
    } catch (e) {
      return AuthServiceResult.failure('Sign up failed: ${e.toString()}');
    }
  }


  Future<AuthServiceResult> login({
    required String email,
    required String password,
  }) async {
    try {
      DioClient.clearAuthToken();
      final response = await _dio.post(
        ApiConstants.authLogin,
        data: {
          'email': email,
          'password': password,
        },
      );

      final responseData = response.data as Map<String, dynamic>?;
      if (responseData == null) {
        return AuthServiceResult.failure('Invalid response');
      }

      final token = responseData['token'];
      final userJson = responseData['user'];
      if (token == null || token.toString().trim().isEmpty) {
        return AuthServiceResult.failure('Invalid login response: missing token');
      }
      if (userJson == null || userJson is! Map<String, dynamic>) {
        return AuthServiceResult.failure('Invalid login response: missing user');
      }

      UserModel user;
      try {
        user = UserModel.fromJson(userJson);
      } catch (e) {
        return AuthServiceResult.failure('Invalid user data: $e');
      }

      await _saveToken(token.toString());
      await saveUser(userJson);
      final authResponse = AuthResponseModel(
        success: true,
        user: user,
        token: token.toString(),
      );
      return AuthServiceResult.success(authResponse);
    } on DioException catch (e) {
      final errorData = e.response?.data;
      final errorMsg = errorData is Map
          ? (errorData['message'] ?? errorData['error'] ?? 'Login failed')
          : 'Login failed';
      return AuthServiceResult.failure(errorMsg.toString());
    } on TimeoutException catch (_) {
      return AuthServiceResult.failure('Request timed out');
    } catch (e) {
      return AuthServiceResult.failure('Login failed: ${e.toString()}');
    }
  }

  /// Update user profile. [profilePicture] is optional file. Email cannot be changed.
  Future<AuthServiceResult> updateUser({
    required String userId,
    String? name,
    String? username,
    String? bio,
    File? profilePicture,
  }) async {
    try {
      final token = await _getToken();
      if (token == null || token.isEmpty) {
        return AuthServiceResult.failure('Not authenticated');
      }

      DioClient.setAuthToken(token);
      final formData = FormData();

      if (name != null && name.trim().isNotEmpty) {
        formData.fields.add(MapEntry('name', name.trim()));
      }
      if (username != null && username.trim().isNotEmpty) {
        formData.fields.add(MapEntry('username', username.trim()));
      }
      if (bio != null) {
        formData.fields.add(MapEntry('bio', bio));
      }
      if (profilePicture != null) {
        formData.files.add(MapEntry(
          'profilePicture',
          await MultipartFile.fromFile(profilePicture.path),
        ));
      }

      final response = await _dio.patch(
        ApiConstants.authUpdate,
        queryParameters: {'userId': userId},
        data: formData,
      );

      final responseData = response.data as Map<String, dynamic>?;
      if (responseData == null) {
        return AuthServiceResult.failure('Invalid response');
      }

      final tokenFromResult = responseData['token'] as String? ?? token;
      final userJson = responseData['user'] as Map<String, dynamic>?;
      if (userJson != null) {
        await _saveToken(tokenFromResult);
        await saveUser(userJson);
        final authResponse = AuthResponseModel(
          success: true,
          user: UserModel.fromJson(userJson),
          token: tokenFromResult,
        );
        return AuthServiceResult.success(authResponse);
      }
      return AuthServiceResult.failure('Invalid update response');
    } on DioException catch (e) {
      final errorData = e.response?.data;
      final errorMsg = errorData is Map
          ? (errorData['message'] ?? errorData['error'] ?? 'Update failed')
          : 'Update failed';
      return AuthServiceResult.failure(errorMsg.toString());
    } on TimeoutException catch (_) {
      return AuthServiceResult.failure('Request timed out');
    } catch (e) {
      return AuthServiceResult.failure(
        e is Exception ? e.toString() : 'Something went wrong',
      );
    }
  }

  Future<AuthOperationResult> sendEmailOTP({required String email}) async {
    try {
      DioClient.clearAuthToken();
      await _dio.post(
        ApiConstants.authSendEmailOTP,
        data: {'email': email},
      );
      return AuthOperationResult.success();
    } on DioException catch (e) {
      final errorData = e.response?.data;
      final errorMsg = errorData is Map
          ? (errorData['message'] ?? errorData['error'] ?? 'Failed to send OTP')
          : 'Failed to send OTP';
      return AuthOperationResult.failure(errorMsg.toString());
    } on TimeoutException catch (_) {
      return AuthOperationResult.failure('Request timed out');
    } catch (e) {
      return AuthOperationResult.failure(
        e is Exception ? e.toString() : 'Something went wrong',
      );
    }
  }

  Future<AuthOperationResult> verifyEmailOtp({
    required String email,
    required String otp,
  }) async {
    try {
      DioClient.clearAuthToken();
      await _dio.post(
        ApiConstants.authVerifyEmailOtp,
        data: {'email': email, 'otp': otp},
      );
      return AuthOperationResult.success();
    } on DioException catch (e) {
      final errorData = e.response?.data;
      final errorMsg = errorData is Map
          ? (errorData['message'] ?? errorData['error'] ?? 'Invalid OTP')
          : 'Invalid OTP';
      return AuthOperationResult.failure(errorMsg.toString());
    } on TimeoutException catch (_) {
      return AuthOperationResult.failure('Request timed out');
    } catch (e) {
      return AuthOperationResult.failure(
        e is Exception ? e.toString() : 'Something went wrong',
      );
    }
  }
}
