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
        },
      ),
    );

    // Minimal logging: one line per request/response (debug only)
    if (kDebugMode) {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            debugPrint('[API] ${options.method} ${options.uri.path}');
            handler.next(options);
          },
          onResponse: (response, handler) {
            debugPrint('[API] ${response.requestOptions.method} ${response.requestOptions.uri.path} -> ${response.statusCode}');
            handler.next(response);
          },
          onError: (err, handler) {
            final msg = err.response?.data is Map
                ? (err.response?.data['message'] ?? err.response?.data['error'] ?? err.message)
                : err.message;
            debugPrint('[API] ${err.requestOptions.method} ${err.requestOptions.uri.path} -> error: $msg');
            handler.next(err);
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
