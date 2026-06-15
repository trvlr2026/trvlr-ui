import 'package:native_exif/native_exif.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../data/models/geo_tagged_photo.dart';
import '../../data/models/leaderboard_entry.dart';
import '../permissions/permission_service.dart';

class PhotoScannerService {
  static const maxPhotos = 2000;
  static const batchSize = 40;

  Future<List<PhotoCoord>> scanGallery({void Function(int scanned, int total)? onProgress}) async {
    final result = await scanGalleryAll(onProgress: onProgress);
    return result.photos
        .where((p) => p.hasLocation)
        .map((p) => PhotoCoord(latitude: p.latitude!, longitude: p.longitude!, takenAt: p.takenAt))
        .toList();
  }

  Future<GalleryScanResult> scanGalleryAll({
    void Function(int scanned, int total)? onProgress,
  }) async {
    var permission = await PhotoManager.getPermissionState(requestOption: photoPermissionRequest);
    if (!permission.hasAccess) {
      permission = await PhotoManager.requestPermissionExtend(requestOption: photoPermissionRequest);
    }
    if (!permission.hasAccess) {
      return const GalleryScanResult(
        totalPhotos: 0,
        geotaggedCount: 0,
        matchedPlacesCount: 0,
        photos: [],
        permissionDenied: true,
      );
    }

    final paths = await PhotoManager.getAssetPathList(type: RequestType.image, onlyAll: true);
    if (paths.isEmpty) {
      return const GalleryScanResult(
        totalPhotos: 0,
        geotaggedCount: 0,
        matchedPlacesCount: 0,
        photos: [],
      );
    }

    final album = paths.first;
    final count = await album.assetCountAsync;
    final limit = count > maxPhotos ? maxPhotos : count;
    final photos = <GeoTaggedPhoto>[];
    var geotagged = 0;

    for (var start = 0; start < limit; start += batchSize) {
      final end = (start + batchSize < limit) ? start + batchSize : limit;
      final batch = await album.getAssetListRange(start: start, end: end);

      for (var i = 0; i < batch.length; i++) {
        onProgress?.call(start + i + 1, limit);
        final asset = batch[i];
        final coords = await _resolveLocation(asset);
        if (coords != null) geotagged++;
        photos.add(GeoTaggedPhoto(
          assetId: asset.id,
          latitude: coords?.$1,
          longitude: coords?.$2,
          takenAt: asset.createDateTime,
        ));
      }
    }

    photos.sort((a, b) => (b.takenAt ?? DateTime(0)).compareTo(a.takenAt ?? DateTime(0)));

    return GalleryScanResult(
      totalPhotos: limit,
      geotaggedCount: geotagged,
      matchedPlacesCount: 0,
      photos: photos,
    );
  }

  Future<(double, double)?> _resolveLocation(AssetEntity asset) async {
    final cached = asset.latLng;
    if (cached != null) {
      return (cached.latitude, cached.longitude);
    }

    try {
      final fromPlugin = await asset.latlngAsync();
      if (fromPlugin != null) {
        return (fromPlugin.latitude, fromPlugin.longitude);
      }
    } catch (_) {}

    try {
      final file = await asset.originFile ?? await asset.file;
      if (file != null) {
        return _readExifGps(file.path);
      }
    } catch (_) {}

    return null;
  }

  Future<(double, double)?> _readExifGps(String path) async {
    Exif? exif;
    try {
      exif = await Exif.fromPath(path);
      final latLong = await exif.getLatLong();
      if (latLong != null) {
        return (latLong.latitude, latLong.longitude);
      }
    } catch (_) {
    } finally {
      await exif?.close();
    }
    return null;
  }
}
