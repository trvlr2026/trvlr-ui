import 'package:native_exif/native_exif.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../data/models/geo_tagged_photo.dart';
import '../../data/models/leaderboard_entry.dart';
import '../permissions/permission_service.dart';
import 'photo_scan_cache.dart';

class PhotoScannerService {
  static const batchSize = 50;

  Future<List<PhotoCoord>> scanGallery({void Function(int scanned, int total)? onProgress}) async {
    final result = await scanGalleryAll(onProgress: onProgress);
    return result.photos
        .where((p) => p.hasLocation)
        .map((p) => PhotoCoord(latitude: p.latitude!, longitude: p.longitude!, takenAt: p.takenAt))
        .toList();
  }

  Future<GalleryScanResult> scanGalleryAll({
    void Function(int scanned, int total)? onProgress,
    PhotoScanCache? cache,
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

    final lastScan = cache?.lastScanTimestamp;
    final cachedPhotos = cache?.loadCachedPhotos() ?? [];

    // asc: false → photo_manager returns newest first, giving correct display
    // order even when asset.createDateTime is unreliable (e.g. epoch zero on
    // some Android devices).
    final filterOption = lastScan != null
        ? FilterOptionGroup(
            createTimeCond: DateTimeCond(
              min: lastScan.add(const Duration(seconds: 1)),
              max: DateTime.now(),
            ),
            orders: [
              const OrderOption(type: OrderOptionType.createDate, asc: false),
            ],
          )
        : FilterOptionGroup(
            orders: [
              const OrderOption(type: OrderOptionType.createDate, asc: false),
            ],
          );

    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: true,
      filterOption: filterOption,
    );

    if (paths.isEmpty) {
      if (cachedPhotos.isNotEmpty) {
        cachedPhotos.sort(
          (a, b) => (b.takenAt ?? DateTime(0)).compareTo(a.takenAt ?? DateTime(0)),
        );
        final geotagged = cachedPhotos.where((p) => p.hasLocation).length;
        return GalleryScanResult(
          totalPhotos: cachedPhotos.length,
          geotaggedCount: geotagged,
          matchedPlacesCount: 0,
          photos: cachedPhotos,
        );
      }
      return const GalleryScanResult(
        totalPhotos: 0,
        geotaggedCount: 0,
        matchedPlacesCount: 0,
        photos: [],
      );
    }

    final album = paths.first;
    final newCount = await album.assetCountAsync;
    final newPhotos = <GeoTaggedPhoto>[];
    var geotagged = cachedPhotos.where((p) => p.hasLocation).length;

    for (var start = 0; start < newCount; start += batchSize) {
      final end = (start + batchSize).clamp(0, newCount);
      final batch = await album.getAssetListRange(start: start, end: end);

      for (var i = 0; i < batch.length; i++) {
        onProgress?.call(cachedPhotos.length + start + i + 1, cachedPhotos.length + newCount);
        final asset = batch[i];
        final coords = await _resolveLocation(asset);
        if (coords != null) geotagged++;
        newPhotos.add(GeoTaggedPhoto(
          assetId: asset.id,
          latitude: coords?.$1,
          longitude: coords?.$2,
          takenAt: asset.createDateTime,
        ));
      }
    }

    final allPhotos = [...cachedPhotos, ...newPhotos]
      ..sort((a, b) => (b.takenAt ?? DateTime(0)).compareTo(a.takenAt ?? DateTime(0)));

    if (cache != null && newPhotos.isNotEmpty) {
      await cache.save(photos: allPhotos, timestamp: DateTime.now());
    }

    return GalleryScanResult(
      totalPhotos: allPhotos.length,
      geotaggedCount: geotagged,
      matchedPlacesCount: 0,
      photos: allPhotos,
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
