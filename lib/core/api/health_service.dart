import 'package:http/http.dart' as http;

import 'api_config.dart';

class HealthService {
  Future<bool> checkHealth() async {
    try {
      final response = await http
          .get(Uri.parse('${ApiConfig.baseUrl}/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Stream<bool> healthStream() async* {
    while (true) {
      yield await checkHealth();
      await Future<void>.delayed(const Duration(seconds: 30));
    }
  }
}
