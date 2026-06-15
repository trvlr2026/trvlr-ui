import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/geo/geofence.dart';
import '../dummy/places.dart';
import '../dummy/users.dart';
import '../models/leaderboard_entry.dart';
import '../models/place.dart';
import '../models/user.dart';
import '../models/visit.dart';
import 'trvlr_repository.dart';

class MockTrvlrRepository implements TrvlrRepository {
  MockTrvlrRepository(this._prefs);

  final SharedPreferences _prefs;
  static const _userKey = 'current_user';
  static const _visitsKey = 'visits';
  static const _onboardingKey = 'onboarding_complete';

  User? _cachedUser;

  @override
  Future<User> login(String email, String password) async {
    final user = currentUserTemplate.copyWith(email: email, displayName: email.split('@').first);
    await _saveUser(user);
    return user;
  }

  @override
  Future<User> register(String name, String email, String password) async {
    final user = currentUserTemplate.copyWith(email: email, displayName: name);
    await _saveUser(user);
    return user;
  }

  @override
  Future<void> logout() async {
    _cachedUser = null;
    await _prefs.remove(_userKey);
  }

  @override
  Future<User?> getCurrentUser() async {
    if (_cachedUser != null) return _cachedUser;
    final raw = _prefs.getString(_userKey);
    if (raw == null) return null;
    _cachedUser = User.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    return _cachedUser;
  }

  @override
  Future<bool> isOnboardingComplete() async => _prefs.getBool(_onboardingKey) ?? false;

  @override
  Future<void> setOnboardingComplete(bool value) async {
    await _prefs.setBool(_onboardingKey, value);
  }

  @override
  Future<List<Place>> getAllPlaces() async => dummyPlaces;

  @override
  Future<List<Place>> getNearbyPlaces(double lat, double lng, {double radiusKm = 50}) async {
    return dummyPlaces.where((p) => distanceBetweenM(lat, lng, p.latitude, p.longitude) <= radiusKm * 1000).toList();
  }

  @override
  Future<CheckInResult> checkIn(double lat, double lng) async {
    final visited = await getVisitedPlaceIds();
    final match = findMatchingPlace(dummyPlaces, lat, lng);
    if (match == null) {
      return const CheckInResult(success: false, message: 'No place found nearby. Move closer to a landmark.');
    }
    if (visited.contains(match.id)) {
      return CheckInResult(success: false, place: match, message: 'You already visited ${match.name}.');
    }
    final visit = Visit(
      id: 'v_${DateTime.now().millisecondsSinceEpoch}',
      placeId: match.id,
      placeName: match.name,
      district: match.district,
      state: match.state,
      pointsEarned: match.pointsValue,
      visitedAt: DateTime.now(),
      source: VisitSource.gps,
    );
    await _addVisit(visit);
    return CheckInResult(success: true, place: match, pointsEarned: match.pointsValue, message: 'Visited ${match.name}!');
  }

  @override
  Future<ImportResult> importPhotoVisits(List<PhotoCoord> coords) async {
    final visited = await getVisitedPlaceIds();
    final clusters = clusterCoords(coords.map((c) => PhotoCoordInput(latitude: c.latitude, longitude: c.longitude, takenAt: c.takenAt)).toList());
    final newVisits = <Visit>[];

    for (final cluster in clusters) {
      final match = findMatchingPlace(dummyPlaces, cluster.latitude, cluster.longitude);
      if (match == null || visited.contains(match.id) || newVisits.any((v) => v.placeId == match.id)) continue;
      newVisits.add(Visit(
        id: 'v_${DateTime.now().millisecondsSinceEpoch}_${match.id}',
        placeId: match.id,
        placeName: match.name,
        district: match.district,
        state: match.state,
        pointsEarned: match.pointsValue,
        visitedAt: cluster.takenAt ?? DateTime.now(),
        source: VisitSource.photoImport,
      ));
      visited.add(match.id);
    }

    for (final v in newVisits) {
      await _addVisit(v);
    }

    return ImportResult(
      newVisits: newVisits,
      totalPointsEarned: newVisits.fold(0, (sum, v) => sum + v.pointsEarned),
      photosScanned: coords.length,
      coordsFound: clusters.length,
    );
  }

  @override
  Future<List<Visit>> getMyVisits() async {
    final raw = _prefs.getStringList(_visitsKey) ?? [];
    return raw.map((e) => Visit.fromJson(jsonDecode(e) as Map<String, dynamic>)).toList()
      ..sort((a, b) => b.visitedAt.compareTo(a.visitedAt));
  }

  @override
  Future<Set<String>> getVisitedPlaceIds() async {
    final visits = await getMyVisits();
    return visits.map((v) => v.placeId).toSet();
  }

  @override
  Future<List<LeaderboardEntry>> getLeaderboard(LeaderboardLevel level, String? scope) async {
    final user = await getCurrentUser();
    final myVisits = await getMyVisits();
    final myPoints = myVisits.fold(0, (s, v) => s + v.pointsEarned);
    final myVisitCount = myVisits.length;

    final entries = <LeaderboardEntry>[];

    for (final u in dummyLeaderboardUsers) {
      var points = dummyUserScores[u.id]?.points ?? 0;
      var visits = dummyUserScores[u.id]?.visits ?? 0;
      if (level == LeaderboardLevel.district && scope != null && u.homeDistrict != scope) {
        points = (points * 0.4).round();
        visits = (visits * 0.4).round();
      } else if (level == LeaderboardLevel.state && scope != null && u.homeState != scope) {
        points = (points * 0.6).round();
        visits = (visits * 0.6).round();
      }
      entries.add(LeaderboardEntry(userId: u.id, displayName: u.displayName, totalPoints: points, placesVisited: visits, rank: 0));
    }

    if (user != null) {
      entries.add(LeaderboardEntry(
        userId: user.id,
        displayName: user.displayName,
        totalPoints: myPoints,
        placesVisited: myVisitCount,
        rank: 0,
        isCurrentUser: true,
      ));
    }

    entries.sort((a, b) => b.totalPoints.compareTo(a.totalPoints));
    return entries.asMap().entries.map((e) => e.value.copyWith(rank: e.key + 1)).toList();
  }

  @override
  Future<UserStats> getMyStats() async {
    final visits = await getMyVisits();
    final byState = <String, int>{};
    for (final v in visits) {
      byState[v.state] = (byState[v.state] ?? 0) + v.pointsEarned;
    }
    return UserStats(
      totalPoints: visits.fold(0, (s, v) => s + v.pointsEarned),
      placesVisited: visits.length,
      pointsByState: byState,
    );
  }

  @override
  Future<List<String>> getDistrictsForState(String state) async {
    return dummyPlaces.where((p) => p.state == state).map((p) => p.district).toSet().toList()..sort();
  }

  @override
  Future<List<String>> getAllStates() async {
    return dummyPlaces.map((p) => p.state).toSet().toList()..sort();
  }

  Future<void> _saveUser(User user) async {
    _cachedUser = user;
    await _prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  Future<void> _addVisit(Visit visit) async {
    final visits = await getMyVisits();
    visits.add(visit);
    await _prefs.setStringList(_visitsKey, visits.map((v) => jsonEncode(v.toJson())).toList());
  }
}

extension on User {
  User copyWith({String? id, String? displayName, String? email, String? homeDistrict, String? homeState}) => User(
        id: id ?? this.id,
        displayName: displayName ?? this.displayName,
        email: email ?? this.email,
        homeDistrict: homeDistrict ?? this.homeDistrict,
        homeState: homeState ?? this.homeState,
      );
}
