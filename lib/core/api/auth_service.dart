import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../data/models/auth_state.dart';
import 'api_config.dart';

class AuthService {
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/auth/signin');
    final http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 30));
    } on Exception catch (e) {
      throw Exception(_friendlyNetworkError(e));
    }

    if (response.statusCode != 200) {
      final body = _tryDecode(response.body);
      throw Exception(body?['detail'] ?? 'Sign in failed (${response.statusCode})');
    }

    return AuthResponse.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/auth/signup');
    final http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'password': password,
              'display_name': displayName,
            }),
          )
          .timeout(const Duration(seconds: 30));
    } on Exception catch (e) {
      throw Exception(_friendlyNetworkError(e));
    }

    if (response.statusCode != 200 && response.statusCode != 201) {
      final body = _tryDecode(response.body);
      throw Exception(body?['detail'] ?? 'Sign up failed (${response.statusCode})');
    }

    return AuthResponse.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  static Map<String, dynamic>? _tryDecode(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static String _friendlyNetworkError(Exception e) {
    final msg = e.toString();
    if (msg.contains('TimeoutException')) {
      return 'Request timed out — check that the backend is running and reachable at ${ApiConfig.baseUrl}';
    }
    if (msg.contains('SocketException') || msg.contains('Connection refused')) {
      return 'Cannot reach backend at ${ApiConfig.baseUrl} — is it running?';
    }
    return msg;
  }
}
