import 'package:http/http.dart' as http;

class HealthService {
  // 127.0.0.1 / 10.0.2.2 are unreachable from a physical device.
  // Use your machine's LAN IP (find it with `ipconfig` on Windows).
  // Make sure your phone and PC are on the same Wi-Fi network.
  static const _baseUrl = 'http://192.168.29.98:8000';

  Future<bool> checkHealth() async {
    try {
      final url = Uri.parse('$_baseUrl/health');
      // ignore: avoid_print
      print('[HealthService] GET $url');
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      // ignore: avoid_print
      print('[HealthService] status=${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      // ignore: avoid_print
      print('[HealthService] error: $e');
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
