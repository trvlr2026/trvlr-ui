import 'package:http/http.dart' as http;

import 'api_config.dart';

enum BackendStatus {
  lanOnline,
  vpsOnline,
  offline;

  bool get isOnline => this != offline;

  /// The base URL to use for API calls, or null when offline.
  String? get activeBaseUrl => switch (this) {
        lanOnline => ApiConfig.baseUrl,
        vpsOnline => ApiConfig.vpsBaseUrl,
        offline => null,
      };
}

class HealthService {
  static const _retries = 3;
  static const _timeout = Duration(seconds: 5);

  /// Try [url]/health up to [_retries] times. Returns true on first success.
  Future<bool> _tryUrl(String url) async {
    for (var i = 0; i < _retries; i++) {
      try {
        final response = await http
            .get(Uri.parse('$url/health'))
            .timeout(_timeout);
        if (response.statusCode == 200) return true;
      } catch (_) {
        // swallow — try again
      }
    }
    return false;
  }

  Future<BackendStatus> checkStatus() async {
    if (await _tryUrl(ApiConfig.baseUrl)) return BackendStatus.lanOnline;
    if (await _tryUrl(ApiConfig.vpsBaseUrl)) return BackendStatus.vpsOnline;
    return BackendStatus.offline;
  }

  Stream<BackendStatus> healthStream() async* {
    while (true) {
      yield await checkStatus();
      await Future<void>.delayed(const Duration(seconds: 30));
    }
  }
}
