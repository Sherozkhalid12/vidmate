import 'api_base.dart';

/// Authentication API service
class AuthApi extends ApiBase {
  // Login
  Future<Map<String, dynamic>> login(String email, String password) async {
    return await super.login(email, password);
  }

  // Sign up
  Future<Map<String, dynamic>> signUp({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async {
    return await post(
      '/auth/signup',
      {
        'name': name,
        'username': username,
        'email': email,
        'password': password,
      },
      requiresAuth: false,
    );
  }

  // Verify email
  Future<Map<String, dynamic>> verifyEmail(String code) async {
    return await post(
      '/auth/verify-email',
      {'code': code},
      requiresAuth: false,
    );
  }

  // Forgot password
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    return await post(
      '/auth/forgot-password',
      {'email': email},
      requiresAuth: false,
    );
  }

  // Reset password
  Future<Map<String, dynamic>> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    return await post(
      '/auth/reset-password',
      {
        'token': token,
        'newPassword': newPassword,
      },
      requiresAuth: false,
    );
  }

  // Social login
  Future<Map<String, dynamic>> socialLogin({
    required String provider,
    required String token,
  }) async {
    return await post(
      '/auth/social-login',
      {
        'provider': provider, // 'google', 'apple', 'facebook'
        'token': token,
      },
      requiresAuth: false,
    );
  }
}


