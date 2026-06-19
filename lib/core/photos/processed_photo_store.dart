import 'package:shared_preferences/shared_preferences.dart';

class ProcessedPhotoStore {
  static const _key = 'processed_photo_ids';

  ProcessedPhotoStore(this._prefs);

  final SharedPreferences _prefs;
  Set<String> _ids = {};

  /// Call once at startup (or lazily before first use).
  void load() {
    final raw = _prefs.getStringList(_key) ?? [];
    _ids = raw.toSet();
  }

  bool contains(String photoId) => _ids.contains(photoId);

  Future<void> markDone(Iterable<String> photoIds) async {
    _ids.addAll(photoIds);
    await _prefs.setStringList(_key, _ids.toList());
  }

  int get count => _ids.length;
}
