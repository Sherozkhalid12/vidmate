/// Centralized API base URL and endpoints.
/// Change base URL or endpoints here to reflect everywhere automatically.
/// No hardcoded URLs inside services.
class ApiConstants {
  ApiConstants._();

  static const String baseUrl = 'http://52.205.129.217:3001';

  // Auth
  static const String authSignup = '/api/v1/auth/signup';
  static const String authLogin = '/api/v1/auth/login';
  /// PATCH with query: ?userId=...
  static const String authUpdate = '/api/v1/auth/update';
  static const String authSendEmailOTP = '/api/v1/auth/sendEmailOTP';
  static const String authVerifyEmailOtp = '/api/v1/auth/verifyEmailOtp';

  // Forget password
  static const String forgetPasswordSendOtp =
      '/api/v1/forgetPassword/sendForgetPasswordOTP';
  static const String forgetPasswordVerifyOtp =
      '/api/v1/forgetPassword/verifyForgetPasswordOTP';
  static const String forgetPasswordReset =
      '/api/v1/forgetPassword/resetPassword';

  // Posts
  static const String postCreate = '/api/v1/post/create';
  /// All users' posts (home feed).
  static const String postList = '/api/v1/post';
  /// Posts for a specific user (profile). Replace :id with userId.
  static String postByUser(String userId) => '/api/v1/post/$userId';
  /// User posts endpoint. Replace :id with userId.
  static String userPosts(String userId) => '/api/v1/post/userPosts/$userId';
}
