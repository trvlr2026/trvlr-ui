import '../models/bulk_checkin.dart';
import '../models/leaderboard_entry.dart';
import '../models/place.dart';
import '../models/user.dart';
import '../models/visit.dart';

abstract class TrvlrRepository {
  Future<User> login(String email, String password);
  Future<User> register(String name, String email, String password);
  Future<void> logout();
  Future<User?> getCurrentUser();
  Future<bool> isOnboardingComplete();
  Future<void> setOnboardingComplete(bool value);
  Future<List<Place>> getAllPlaces({double? lat, double? lon, double radiusM = 5000});
  Future<List<Place>> getNearbyPlaces(double lat, double lng, {double radiusKm = 50});
  Future<CheckInResult> checkIn(double lat, double lng);
  Future<ImportResult> importPhotoVisits(List<PhotoCoord> coords);
  Future<List<Visit>> getMyVisits();
  Future<Set<String>> getVisitedPlaceIds();
  Future<List<LeaderboardEntry>> getLeaderboard(LeaderboardLevel level, String? scope);
  Future<UserStats> getMyStats();
  Future<List<String>> getDistrictsForState(String state);
  Future<List<String>> getAllStates();
  Future<BulkCheckInResult> bulkCheckIn(List<({double lat, double lon, String photoId})> coordinates);
}
