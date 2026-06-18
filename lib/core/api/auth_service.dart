import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../data/models/auth_state.dart';
import 'api_config.dart';

class AuthService {
  /// Ordered list of base URLs to try — LAN first, VPS as fallback.
  static const _baseUrls = [ApiConfig.baseUrl, ApiConfig.vpsBaseUrl];

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    Exception? lastError;
    for (final base in _baseUrls) {
      try {
        return await _doSignIn(base, email: email, password: password);
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
      }
    }
    throw lastError ?? Exception('Sign in failed — no backend reachable');
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    Exception? lastError;
    for (final base in _baseUrls) {
      try {
        return await _doSignUp(base, email: email, password: password, displayName: displayName);
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
      }
    }
    throw lastError ?? Exception('Sign up failed — no backend reachable');
  }

  // ── Internal per-URL helpers ──────────────────────────────────────────────

  Future<AuthResponse> _doSignIn(
    String baseUrl, {
    required String email,
    required String password,
  }) async {
    final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$baseUrl/auth/signin'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 30));
    } on Exception catch (e) {
      throw Exception(_friendlyNetworkError(e, baseUrl));
    }

    if (response.statusCode != 200 && response.statusCode != 201) {
      final body = _tryDecode(response.body);
      throw Exception(body?['detail'] ?? 'Sign in failed (${response.statusCode})');
    }

    return AuthResponse.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<AuthResponse> _doSignUp(
    String baseUrl, {
    required String email,
    required String password,
    required String displayName,
  }) async {
    final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$baseUrl/auth/signup'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'password': password,
              'display_name': displayName,
            }),
          )
          .timeout(const Duration(seconds: 30));
    } on Exception catch (e) {
      throw Exception(_friendlyNetworkError(e, baseUrl));
    }

    if (response.statusCode != 200 && response.statusCode != 201) {
      final body = _tryDecode(response.body);
      throw Exception(body?['detail'] ?? 'Sign up failed (${response.statusCode})');
    }

    return AuthResponse.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  // ── Utilities ─────────────────────────────────────────────────────────────

  static Map<String, dynamic>? _tryDecode(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static String _friendlyNetworkError(Exception e, String baseUrl) {
    final msg = e.toString();
    if (msg.contains('TimeoutException')) {
      return 'Timed out connecting to $baseUrl';
    }
    if (msg.contains('SocketException') || msg.contains('Connection refused')) {
      return 'Cannot reach $baseUrl';
    }
    return msg;
  }
}
