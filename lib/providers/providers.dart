import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/geo/geofence.dart';
import '../core/location/location_service.dart';
import '../core/permissions/permission_service.dart';
import '../core/photos/photo_scanner_service.dart';
import '../data/models/geo_tagged_photo.dart';
import '../data/models/leaderboard_entry.dart';
import '../data/models/place.dart';
import '../data/models/user.dart';
import '../data/models/visit.dart';
import '../data/repositories/mock_trvlr_repository.dart';
import '../data/repositories/trvlr_repository.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be overridden in main');
});

final repositoryProvider = Provider<TrvlrRepository>((ref) {
  return MockTrvlrRepository(ref.watch(sharedPreferencesProvider));
});

final locationServiceProvider = Provider((_) => LocationService());
final permissionServiceProvider = Provider((_) => PermissionService());
final photoScannerProvider = Provider((_) => PhotoScannerService());

final currentUserProvider = FutureProvider<User?>((ref) async {
  return ref.watch(repositoryProvider).getCurrentUser();
});

final visitsProvider = FutureProvider<List<Visit>>((ref) async {
  return ref.watch(repositoryProvider).getMyVisits();
});

final visitedPlaceIdsProvider = FutureProvider<Set<String>>((ref) async {
  return ref.watch(repositoryProvider).getVisitedPlaceIds();
});

final userStatsProvider = FutureProvider<UserStats>((ref) async {
  return ref.watch(repositoryProvider).getMyStats();
});

final placesProvider = FutureProvider<List<Place>>((ref) async {
  return ref.watch(repositoryProvider).getAllPlaces();
});

final myPhotosScanProgressProvider = StateProvider<(int, int)?>((ref) => null);

final myPhotosProvider = FutureProvider<GalleryScanResult>((ref) async {
  final scanner = ref.read(photoScannerProvider);
  final places = await ref.read(placesProvider.future);

  ref.read(myPhotosScanProgressProvider.notifier).state = null;
  final result = await scanner.scanGalleryAll(
    onProgress: (scanned, total) {
      ref.read(myPhotosScanProgressProvider.notifier).state = (scanned, total);
    },
  );

  var matched = 0;
  final enriched = result.photos.map((photo) {
    if (!photo.hasLocation) return photo;
    final place = findMatchingPlace(places, photo.latitude!, photo.longitude!);
    if (place != null) matched++;
    return GeoTaggedPhoto(
      assetId: photo.assetId,
      latitude: photo.latitude,
      longitude: photo.longitude,
      takenAt: photo.takenAt,
      placeName: place?.name,
      district: place?.district,
      state: place?.state,
    );
  }).toList();

  return GalleryScanResult(
    totalPhotos: result.totalPhotos,
    geotaggedCount: result.geotaggedCount,
    matchedPlacesCount: matched,
    photos: enriched,
    permissionDenied: result.permissionDenied,
  );
});

final leaderboardProvider = FutureProvider.family<List<LeaderboardEntry>, LeaderboardParams>((ref, params) async {
  return ref.watch(repositoryProvider).getLeaderboard(params.level, params.scope);
});

class LeaderboardParams {
  const LeaderboardParams({required this.level, this.scope});
  final LeaderboardLevel level;
  final String? scope;

  @override
  bool operator ==(Object other) => other is LeaderboardParams && other.level == level && other.scope == scope;
  @override
  int get hashCode => Object.hash(level, scope);
}
