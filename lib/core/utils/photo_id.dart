import 'dart:convert';

/// Generates a deterministic 16-character hex ID for a geotagged photo using
/// FNV-1a 64-bit hash over "lat_lon_timestamp".
///
/// Same photo → same lat/lon/timestamp → same ID, every time, on any device.
/// Different photos never collide as long as their location or timestamp differs.
String generatePhotoId(double lat, double lon, DateTime? takenAt) {
  final input = '${lat.toStringAsFixed(6)}_'
      '${lon.toStringAsFixed(6)}_'
      '${takenAt?.millisecondsSinceEpoch ?? 0}';

  // FNV-1a 64-bit
  var hash = 0xcbf29ce484222325;
  for (final byte in utf8.encode(input)) {
    hash ^= byte;
    hash = (hash * 0x100000001b3) & 0xffffffffffffffff;
  }

  return hash.toRadixString(16).padLeft(16, '0');
}
