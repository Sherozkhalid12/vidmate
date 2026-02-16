import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../constants/api_constants.dart';

/// Shared Dio client with logging interceptor for all services.
/// Provides meaningful debug logs for requests, responses, and errors.
class DioClient {
  static Dio? _instance;

  static Dio get instance {
    _instance ??= _createDio();
    return _instance!;
  }

  static Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 60),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    // Add logging interceptor (only in debug mode)
    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(
          request: true,
          requestHeader: true,
          requestBody: true,
          responseHeader: true,
          responseBody: true,
          error: true,
          logPrint: (object) {
            // Only log meaningful information
            if (object.toString().isNotEmpty) {
              debugPrint('[Dio] $object');
            }
          },
        ),
      );
    }

    return dio;
  }

  /// Update authorization token for authenticated requests.
  static void setAuthToken(String? token) {
    if (token != null && token.isNotEmpty) {
      instance.options.headers['Authorization'] = 'Bearer $token';
    } else {
      instance.options.headers.remove('Authorization');
    }
  }

  /// Clear authorization token.
  static void clearAuthToken() {
    instance.options.headers.remove('Authorization');
  }
}
