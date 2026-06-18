import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/trvlr_api_client.dart';
import '../models/bulk_checkin.dart';
import '../models/leaderboard_entry.dart';
import '../models/place.dart';
import '../models/user.dart';
import '../models/visit.dart';
import 'trvlr_repository.dart';
import 'trvlr_repository_offline.dart';

/// Online repository — delegates every method to [TrvlrRepositoryOffline]
/// except those that have a real backend endpoint.
class TrvlrRepositoryOnline implements TrvlrRepository {
  TrvlrRepositoryOnline(SharedPreferences prefs, {required this.userId, this.token})
      : _offline = TrvlrRepositoryOffline(prefs),
        _api = TrvlrApiClient(token: token);

  final String userId;
  final String? token;
  final TrvlrRepositoryOffline _offline;
  final TrvlrApiClient _api;

  // ── API-backed methods ──────────────────────────────────────────────────

  @override
  Future<List<Place>> getAllPlaces({double? lat, double? lon, double radiusM = 5000}) async {
    if (lat == null || lon == null) return _offline.getAllPlaces();
    return _api.getNearbyPlaces(
      userId: userId,
      lat: lat,
      lon: lon,
      radiusM: radiusM,
    );
  }

  // ── Delegated to offline ────────────────────────────────────────────────

  @override
  Future<User> login(String email, String password) => _offline.login(email, password);

  @override
  Future<User> register(String name, String email, String password) =>
      _offline.register(name, email, password);

  @override
  Future<void> logout() => _offline.logout();

  @override
  Future<User?> getCurrentUser() => _offline.getCurrentUser();

  @override
  Future<bool> isOnboardingComplete() => _offline.isOnboardingComplete();

  @override
  Future<void> setOnboardingComplete(bool value) => _offline.setOnboardingComplete(value);

  @override
  Future<List<Place>> getNearbyPlaces(double lat, double lng, {double radiusKm = 50}) =>
      _offline.getNearbyPlaces(lat, lng, radiusKm: radiusKm);

  @override
  Future<CheckInResult> checkIn(double lat, double lng) => _offline.checkIn(lat, lng);

  @override
  Future<ImportResult> importPhotoVisits(List<PhotoCoord> coords) =>
      _offline.importPhotoVisits(coords);

  @override
  Future<List<Visit>> getMyVisits() => _offline.getMyVisits();

  @override
  Future<Set<String>> getVisitedPlaceIds() => _offline.getVisitedPlaceIds();

  @override
  Future<List<LeaderboardEntry>> getLeaderboard(LeaderboardLevel level, String? scope) =>
      _offline.getLeaderboard(level, scope);

  @override
  Future<UserStats> getMyStats() => _offline.getMyStats();

  @override
  Future<List<String>> getDistrictsForState(String state) =>
      _offline.getDistrictsForState(state);

  @override
  Future<List<String>> getAllStates() => _offline.getAllStates();

  @override
  Future<BulkCheckInResult> bulkCheckIn(List<({double lat, double lon, String photoId})> coordinates) async {
    return _api.bulkCheckIn(
      userId: userId,
      coordinates: coordinates,
    );
  }
}
