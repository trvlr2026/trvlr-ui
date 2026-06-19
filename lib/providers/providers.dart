import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api/health_service.dart' show HealthService, BackendStatus;
import '../core/api/trvlr_api_client.dart';
import '../core/geo/geofence.dart';
import '../core/location/location_service.dart';
import '../core/permissions/permission_service.dart';
import '../core/photos/photo_scan_cache.dart';
import '../core/photos/photo_scanner_service.dart';
import '../core/photos/processed_photo_store.dart';
import '../data/models/api_visit.dart';
import '../data/models/auth_state.dart';
import '../data/models/geo_tagged_photo.dart';
import '../data/models/leaderboard_entry.dart';
import '../data/models/place.dart';
import '../data/models/places_tree.dart';
import '../data/models/user.dart';
import '../data/models/visit.dart';
import '../data/repositories/trvlr_repository.dart';
import '../data/repositories/trvlr_repository_offline.dart';
import '../data/repositories/trvlr_repository_online.dart';
import 'auth_notifier.dart';

// ── Infra ─────────────────────────────────────────────────────────────────────

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be overridden in main');
});

final locationServiceProvider = Provider((_) => LocationService());
final permissionServiceProvider = Provider((_) => PermissionService());
final photoScannerProvider = Provider((_) => PhotoScannerService());
final healthServiceProvider = Provider((_) => HealthService());

final processedPhotoStoreProvider = Provider<ProcessedPhotoStore>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final store = ProcessedPhotoStore(prefs);
  store.load();
  return store;
});

final photoScanCacheProvider = Provider<PhotoScanCache>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return PhotoScanCache(prefs);
});

// ── Auth ──────────────────────────────────────────────────────────────────────

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AuthNotifier(prefs);
});

// ── Backend status ────────────────────────────────────────────────────────────

final backendStatusProvider = StreamProvider<BackendStatus>((ref) {
  return ref.watch(healthServiceProvider).healthStream();
});

// ── API client (token-aware + active-URL-aware) ───────────────────────────────

final apiClientProvider = Provider<TrvlrApiClient>((ref) {
  final auth = ref.watch(authNotifierProvider);
  final status = ref.watch(backendStatusProvider).valueOrNull ?? BackendStatus.offline;
  return TrvlrApiClient(token: auth?.token, baseUrl: status.activeBaseUrl);
});

// ── Repository ────────────────────────────────────────────────────────────────

final repositoryProvider = Provider<TrvlrRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final status = ref.watch(backendStatusProvider).valueOrNull ?? BackendStatus.offline;
  final auth = ref.watch(authNotifierProvider);
  return status.isOnline
      ? TrvlrRepositoryOnline(prefs,
          userId: auth?.userId ?? '',
          token: auth?.token,
          baseUrl: status.activeBaseUrl)
      : TrvlrRepositoryOffline(prefs);
});

// ── Current user (derived from auth state) ───────────────────────────────────

final currentUserProvider = Provider<User?>((ref) {
  final auth = ref.watch(authNotifierProvider);
  if (auth == null) return null;
  return User(
    id: auth.userId,
    displayName: auth.displayName,
    email: '',
    homeDistrict: '',
    homeState: '',
  );
});

// ── Data providers ────────────────────────────────────────────────────────────

final visitsProvider = FutureProvider<List<Visit>>((ref) async {
  return ref.watch(repositoryProvider).getMyVisits();
});

final visitedPlaceIdsProvider = FutureProvider<Set<String>>((ref) async {
  return ref.watch(repositoryProvider).getVisitedPlaceIds();
});

final userStatsProvider = FutureProvider<UserStats>((ref) async {
  final isOnline = ref.watch(backendStatusProvider).valueOrNull?.isOnline ?? false;
  final auth = ref.watch(authNotifierProvider);
  if (isOnline && auth != null) {
    final profile = await ref.watch(apiClientProvider).getProfile(userId: auth.userId);
    return profile.stats;
  }
  return ref.watch(repositoryProvider).getMyStats();
});

/// Email fetched from /profile — only available when online and signed in.
final userEmailProvider = FutureProvider<String>((ref) async {
  final isOnline = ref.watch(backendStatusProvider).valueOrNull?.isOnline ?? false;
  final auth = ref.watch(authNotifierProvider);
  if (isOnline && auth != null) {
    final profile = await ref.watch(apiClientProvider).getProfile(userId: auth.userId);
    return profile.email;
  }
  return '';
});

final placesProvider = FutureProvider<List<Place>>((ref) async {
  final position = await ref.read(locationServiceProvider).getCurrentPosition();
  return ref.read(repositoryProvider).getAllPlaces(
    lat: position?.latitude,
    lon: position?.longitude,
  );
});

final myPhotosScanProgressProvider = StateProvider<(int, int)?>((ref) => null);

final myPhotosProvider = FutureProvider<GalleryScanResult>((ref) async {
  final scanner = ref.read(photoScannerProvider);
  final places = await ref.read(placesProvider.future);

  final cache = ref.read(photoScanCacheProvider);
  ref.read(myPhotosScanProgressProvider.notifier).state = null;
  final result = await scanner.scanGalleryAll(
    onProgress: (scanned, total) {
      ref.read(myPhotosScanProgressProvider.notifier).state = (scanned, total);
    },
    cache: cache,
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
  }).toList()
    ..sort((a, b) => (b.takenAt ?? DateTime(0)).compareTo(a.takenAt ?? DateTime(0)));

  return GalleryScanResult(
    totalPhotos: result.totalPhotos,
    geotaggedCount: result.geotaggedCount,
    matchedPlacesCount: matched,
    photos: enriched,
    permissionDenied: result.permissionDenied,
  );
});

/// Fetches all visited entries from the backend (all pages) when online.
/// Returns an empty list when offline or not signed in.
final allVisitedPlacesProvider = FutureProvider<List<ApiVisit>>((ref) async {
  final isOnline = ref.watch(backendStatusProvider).valueOrNull?.isOnline ?? false;
  final auth = ref.watch(authNotifierProvider);
  if (!isOnline || auth == null) return [];

  final api = ref.watch(apiClientProvider);
  const pageSize = 100;
  final all = <ApiVisit>[];
  var page = 1;

  while (true) {
    final response = await api.getVisits(
      userId: auth.userId,
      page: page,
      pageSize: pageSize,
    );
    all.addAll(response.results);
    if (response.results.length < pageSize) break;
    page++;
  }

  return all;
});

// ── Spots ─────────────────────────────────────────────────────────────────────

final placesTreeProvider = FutureProvider<PlacesTree>((ref) async {
  return ref.watch(apiClientProvider).getPlacesTree();
});

class SpotsFilterParams {
  const SpotsFilterParams({required this.state, required this.district});
  final String state;
  final String district;

  @override
  bool operator ==(Object other) =>
      other is SpotsFilterParams && other.state == state && other.district == district;
  @override
  int get hashCode => Object.hash(state, district);
}

final spotsByFilterProvider = FutureProvider.family<List<Place>, SpotsFilterParams>((ref, params) async {
  return ref.watch(apiClientProvider).getSpotsByFilter(state: params.state, district: params.district);
});

// ── Leaderboard ───────────────────────────────────────────────────────────────

final leaderboardProvider = FutureProvider.family<List<LeaderboardEntry>, LeaderboardParams>((ref, params) async {
  return ref.watch(repositoryProvider).getLeaderboard(params.level, params.scope);
});

class LeaderboardFilterParams {
  const LeaderboardFilterParams({this.state, this.district});
  final String? state;
  final String? district;

  @override
  bool operator ==(Object other) =>
      other is LeaderboardFilterParams && other.state == state && other.district == district;
  @override
  int get hashCode => Object.hash(state, district);
}

final leaderboardByFilterProvider =
    FutureProvider.family<List<ApiLeaderboardEntry>, LeaderboardFilterParams>((ref, params) async {
  return ref.watch(apiClientProvider).getLeaderboard(
        state: params.state,
        district: params.district,
      );
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
