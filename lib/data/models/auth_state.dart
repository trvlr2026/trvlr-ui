/// Response body returned by /auth/signin and /auth/signup.
class AuthResponse {
  const AuthResponse({
    required this.userId,
    required this.token,
    required this.displayName,
  });

  final String userId;
  final String token;
  final String displayName;

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
        userId: json['user_id'] as String,
        token: json['token'] as String,
        displayName: json['display_name'] as String,
      );
}

/// In-memory representation of a signed-in session.
/// Persisted to / loaded from SharedPreferences.
class AuthState {
  const AuthState({
    required this.userId,
    required this.token,
    required this.displayName,
  });

  final String userId;
  final String token;
  final String displayName;
}
