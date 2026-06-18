import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api/auth_service.dart';
import '../data/models/auth_state.dart';

// SharedPreferences keys
const _kUserId = 'auth_user_id';
const _kToken = 'auth_token';
const _kDisplayName = 'auth_display_name';

class AuthNotifier extends StateNotifier<AuthState?> {
  AuthNotifier(this._prefs) : super(null) {
    _loadFromPrefs();
  }

  final SharedPreferences _prefs;
  final _service = AuthService();

  /// Restore session from SharedPreferences on startup.
  void _loadFromPrefs() {
    final userId = _prefs.getString(_kUserId);
    final token = _prefs.getString(_kToken);
    final displayName = _prefs.getString(_kDisplayName) ?? '';
    if (userId != null && token != null) {
      state = AuthState(userId: userId, token: token, displayName: displayName);
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    final response = await _service.signIn(email: email, password: password);
    await _persist(response);
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final response = await _service.signUp(
      email: email,
      password: password,
      displayName: displayName,
    );
    await _persist(response);
  }

  Future<void> signOut() async {
    await _prefs.remove(_kUserId);
    await _prefs.remove(_kToken);
    await _prefs.remove(_kDisplayName);
    state = null;
  }

  Future<void> _persist(AuthResponse response) async {
    await _prefs.setString(_kUserId, response.userId);
    await _prefs.setString(_kToken, response.token);
    await _prefs.setString(_kDisplayName, response.displayName);
    state = AuthState(
      userId: response.userId,
      token: response.token,
      displayName: response.displayName,
    );
  }
}
