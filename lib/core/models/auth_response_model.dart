import 'user_model.dart';

/// Auth API response with user and token.
/// Used for login and signup success responses.
class AuthResponseModel {
  final bool success;
  final UserModel user;
  final String token;

  AuthResponseModel({
    required this.success,
    required this.user,
    required this.token,
  });

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    return AuthResponseModel(
      success: json['success'] as bool? ?? true,
      user: UserModel.fromJson(
        (json['user'] ?? json) as Map<String, dynamic>,
      ),
      token: (json['token'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'user': user.toJson(),
      'token': token,
    };
  }
}
