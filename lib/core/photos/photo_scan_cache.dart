import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/geo_tagged_photo.dart';

class PhotoScanCache {
  static const _timestampKey = 'photo_scan_last_timestamp_v2';
  static const _photosKey = 'photo_scan_cached_photos_v2';

  PhotoScanCache(this._prefs);

  final SharedPreferences _prefs;

  DateTime? get lastScanTimestamp {
    final s = _prefs.getString(_timestampKey);
    return s != null ? DateTime.parse(s) : null;
  }

  List<GeoTaggedPhoto> loadCachedPhotos() {
    final raw = _prefs.getString(_photosKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => GeoTaggedPhoto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> save({
    required List<GeoTaggedPhoto> photos,
    required DateTime timestamp,
  }) async {
    await _prefs.setString(_timestampKey, timestamp.toIso8601String());
    await _prefs.setString(_photosKey, jsonEncode(photos.map((p) => p.toJson()).toList()));
  }

  Future<void> clear() async {
    await _prefs.remove(_timestampKey);
    await _prefs.remove(_photosKey);
  }
}
