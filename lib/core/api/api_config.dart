class ApiConfig {
  /// Local LAN backend — preferred when on the same Wi-Fi as the dev machine.
  static const baseUrl = 'http://192.168.29.98:8000';

  /// VPS fallback — used when the LAN backend is unreachable.
  static const vpsBaseUrl = 'http://213.136.67.24:80';
}
