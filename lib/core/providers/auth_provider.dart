import 'package:flutter/foundation.dart';
import '../api/auth_api.dart';
import '../models/user_model.dart';

/// Authentication state provider
class AuthProvider with ChangeNotifier {
  final AuthApi _authApi = AuthApi();
  
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;

  // Login
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _authApi.login(email, password);
      
      if (response['success'] == true) {
        _currentUser = UserModel.fromJson(response['user']);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = response['error'] ?? 'Login failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Sign up
  Future<bool> signUp({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _authApi.signUp(
        name: name,
        username: username,
        email: email,
        password: password,
      );
      debugPrint(response.toString());

      if (response['success'] == true) {
        debugPrint(response.toString());
        _currentUser = UserModel.fromJson(response['user']);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = response['error'] ?? 'Sign up failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    await _authApi.logout();
    _currentUser = null;
    notifyListeners();
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}


