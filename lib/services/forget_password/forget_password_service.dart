import 'dart:async';

import 'package:dio/dio.dart';

import '../../core/api/dio_client.dart';
import '../../core/constants/api_constants.dart';

/// Result for forget-password operations.
class ForgetPasswordResult {
  final bool success;
  final String? errorMessage;

  ForgetPasswordResult({required this.success, this.errorMessage});

  factory ForgetPasswordResult.failure(String message) =>
      ForgetPasswordResult(success: false, errorMessage: message);

  factory ForgetPasswordResult.success() =>
      ForgetPasswordResult(success: true);
}

/// Forget password API service. Uses Dio with logging interceptor.
class ForgetPasswordService {
  final Dio _dio = DioClient.instance;

  /// Send OTP to email for forget password.
  Future<ForgetPasswordResult> sendForgetPasswordOTP({
    required String email,
  }) async {
    try {
      DioClient.clearAuthToken();
      await _dio.post(
        ApiConstants.forgetPasswordSendOtp,
        data: {'email': email},
      );
      return ForgetPasswordResult.success();
    } on DioException catch (e) {
      final errorData = e.response?.data;
      final errorMsg = errorData is Map
          ? (errorData['message'] ?? errorData['error'] ?? 'Failed to send OTP')
          : 'Failed to send OTP';
      return ForgetPasswordResult.failure(errorMsg.toString());
    } on TimeoutException catch (_) {
      return ForgetPasswordResult.failure('Request timed out');
    } catch (e) {
      return ForgetPasswordResult.failure(
        e is Exception ? e.toString() : 'Something went wrong',
      );
    }
  }

  /// Verify OTP for forget password.
  Future<ForgetPasswordResult> verifyForgetPasswordOTP({
    required String email,
    required String otp,
  }) async {
    try {
      DioClient.clearAuthToken();
      await _dio.post(
        ApiConstants.forgetPasswordVerifyOtp,
        data: {'email': email, 'otp': otp},
      );
      return ForgetPasswordResult.success();
    } on DioException catch (e) {
      final errorData = e.response?.data;
      final errorMsg = errorData is Map
          ? (errorData['message'] ?? errorData['error'] ?? 'Invalid OTP')
          : 'Invalid OTP';
      return ForgetPasswordResult.failure(errorMsg.toString());
    } on TimeoutException catch (_) {
      return ForgetPasswordResult.failure('Request timed out');
    } catch (e) {
      return ForgetPasswordResult.failure(
        e is Exception ? e.toString() : 'Something went wrong',
      );
    }
  }

  /// Reset password after OTP verified.
  Future<ForgetPasswordResult> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    try {
      DioClient.clearAuthToken();
      await _dio.patch(
        ApiConstants.forgetPasswordReset,
        data: {
          'email': email,
          'newPassword': newPassword,
        },
      );
      return ForgetPasswordResult.success();
    } on DioException catch (e) {
      final errorData = e.response?.data;
      final errorMsg = errorData is Map
          ? (errorData['message'] ?? errorData['error'] ?? 'Failed to reset password')
          : 'Failed to reset password';
      return ForgetPasswordResult.failure(errorMsg.toString());
    } on TimeoutException catch (_) {
      return ForgetPasswordResult.failure('Request timed out');
    } catch (e) {
      return ForgetPasswordResult.failure(
        e is Exception ? e.toString() : 'Something went wrong',
      );
    }
  }
}
