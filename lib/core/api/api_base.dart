import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Base API service class
class ApiBase {
  static const String baseUrl = 'https://api.socialvideo.com/v1'; // Replace with your API URL
  static const Duration timeout = Duration(seconds: 30);

  // Get auth token from storage
  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // Save auth token
  Future<void> _saveAuthToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  // GET request
  Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, String>? queryParams,
    bool requiresAuth = true,
  }) async {
    try {
      final token = requiresAuth ? await _getAuthToken() : null;
      final uri = Uri.parse('$baseUrl$endpoint').replace(
        queryParameters: queryParams,
      );

      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final response = await http
          .get(uri, headers: headers)
          .timeout(timeout);

      return _handleResponse(response);
    } catch (e) {
      return {'error': e.toString(), 'success': false};
    }
  }

  // POST request
  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body, {
    bool requiresAuth = true,
  }) async {
    try {
      final token = requiresAuth ? await _getAuthToken() : null;
      final uri = Uri.parse('$baseUrl$endpoint');

      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final response = await http
          .post(
            uri,
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(timeout);

      return _handleResponse(response);
    } catch (e) {
      return {'error': e.toString(), 'success': false};
    }
  }

  // PUT request
  Future<Map<String, dynamic>> put(
    String endpoint,
    Map<String, dynamic> body, {
    bool requiresAuth = true,
  }) async {
    try {
      final token = requiresAuth ? await _getAuthToken() : null;
      final uri = Uri.parse('$baseUrl$endpoint');

      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final response = await http
          .put(
            uri,
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(timeout);

      return _handleResponse(response);
    } catch (e) {
      return {'error': e.toString(), 'success': false};
    }
  }

  // DELETE request
  Future<Map<String, dynamic>> delete(
    String endpoint, {
    bool requiresAuth = true,
  }) async {
    try {
      final token = requiresAuth ? await _getAuthToken() : null;
      final uri = Uri.parse('$baseUrl$endpoint');

      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final response = await http
          .delete(uri, headers: headers)
          .timeout(timeout);

      return _handleResponse(response);
    } catch (e) {
      return {'error': e.toString(), 'success': false};
    }
  }

  // Multipart POST for file uploads
  Future<Map<String, dynamic>> postMultipart(
    String endpoint,
    String filePath,
    String fileField, {
    Map<String, String>? fields,
    bool requiresAuth = true,
  }) async {
    try {
      final token = requiresAuth ? await _getAuthToken() : null;
      final uri = Uri.parse('$baseUrl$endpoint');

      final request = http.MultipartRequest('POST', uri);
      
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.files.add(
        await http.MultipartFile.fromPath(fileField, filePath),
      );

      if (fields != null) {
        request.fields.addAll(fields);
      }

      final streamedResponse = await request.send().timeout(timeout);
      final response = await http.Response.fromStream(streamedResponse);

      return _handleResponse(response);
    } catch (e) {
      return {'error': e.toString(), 'success': false};
    }
  }

  // Handle API response
  Map<String, dynamic> _handleResponse(http.Response response) {
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true, ...data};
      } else {
        return {
          'success': false,
          'error': data['message'] ?? 'Request failed',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to parse response',
        'statusCode': response.statusCode,
      };
    }
  }

  // Login and save token
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await post(
      '/auth/login',
      {'email': email, 'password': password},
      requiresAuth: false,
    );

    if (response['success'] == true && response['token'] != null) {
      await _saveAuthToken(response['token']);
    }

    return response;
  }

  // Logout and clear token
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }
}


