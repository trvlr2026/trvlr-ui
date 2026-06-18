import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../data/models/api_visit.dart';
import '../../data/models/bulk_checkin.dart';
import '../../data/models/leaderboard_entry.dart';
import '../../data/models/place.dart';
import '../../data/models/places_tree.dart';
import 'api_config.dart';

class TrvlrApiClient {
  TrvlrApiClient({this.token, String? baseUrl})
      : _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final String? token;
  final String _baseUrl;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<List<Place>> getNearbyPlaces({
    required String userId,
    required double lat,
    required double lon,
    double radiusM = 5000,
  }) async {
    final uri = Uri.parse('$_baseUrl/nearby/').replace(
      queryParameters: {
        'user_id': userId,
        'lat': lat.toString(),
        'lon': lon.toString(),
        'radius': radiusM.toString(),
      },
    );

    final response = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('getNearbyPlaces failed: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final locations = (data['locations'] as List).cast<Map<String, dynamic>>();
    return locations.map(_placeFromJson).toList();
  }

  static Place _placeFromJson(Map<String, dynamic> json) {
    return Place(
      id: json['id'].toString(),
      name: json['place_name'] as String,
      latitude: (json['lat'] as num).toDouble(),
      longitude: (json['lon'] as num).toDouble(),
      district: json['district'] as String? ?? '',
      state: '',
      country: 'India',
      pointsValue: json['score'] as int? ?? 10,
      radiusM: _defaultRadius(json['location_type'] as String? ?? ''),
      category: _parseCategory(json['location_type'] as String? ?? 'landmark'),
    );
  }

  Future<BulkCheckInResult> bulkCheckIn({
    required String userId,
    required List<({double lat, double lon, String photoId})> coordinates,
  }) async {
    final uri = Uri.parse('$_baseUrl/checkin/');
    final response = await http
        .post(
          uri,
          headers: _headers,
          body: jsonEncode({
            'user_id': userId,
            'coordinates': coordinates
                .map((c) => {'lat': c.lat, 'lon': c.lon, 'photo_id': c.photoId})
                .toList(),
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('bulkCheckIn failed: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final scores = (data['scores'] as List)
        .cast<Map<String, dynamic>>()
        .map(
          (s) => BulkCheckInScore(
            lat: (s['lat'] as num).toDouble(),
            lon: (s['lon'] as num).toDouble(),
            name: s['name'] as String? ?? '',
            score: (s['score'] as num?)?.toInt() ?? 0,
            earnedScore: (s['earned_score'] as num?)?.toInt() ?? 0,
            reason: s['reason'] as String? ?? '',
          ),
        )
        .toList();

    return BulkCheckInResult(scores: scores);
  }

  Future<ApiVisitsPage> getVisits({
    required String userId,
    int page = 1,
    int pageSize = 100,
  }) async {
    final uri = Uri.parse('$_baseUrl/$userId/visits').replace(
      queryParameters: {
        'page': page.toString(),
        'page_size': pageSize.toString(),
      },
    );

    final response = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('getVisits failed: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final rawList = (data['results'] as List? ?? []).cast<Map<String, dynamic>>();
    final results = rawList.map((v) {
      final loc = v['location'] as Map<String, dynamic>;
      return ApiVisit(
        photoId: v['photo_id'] as String? ?? '',
        score: (v['score'] as num?)?.toInt() ?? 0,
        visitedAt: v['visited_at'] != null ? DateTime.tryParse(v['visited_at'] as String) : null,
        location: ApiVisitLocation(
          id: (loc['id'] as num?)?.toInt() ?? 0,
          lat: (loc['lat'] as num).toDouble(),
          lon: (loc['lon'] as num).toDouble(),
          placeName: loc['place_name'] as String? ?? '',
          district: loc['district'] as String? ?? '',
          locationType: loc['location_type'] as String? ?? '',
          score: (loc['score'] as num?)?.toInt() ?? 0,
        ),
      );
    }).toList();

    return ApiVisitsPage(
      results: results,
      page: (data['page'] as num?)?.toInt() ?? page,
      pageSize: (data['page_size'] as num?)?.toInt() ?? pageSize,
    );
  }

  Future<({UserStats stats, String email, String displayName})> getProfile({
    required String userId,
  }) async {
    final uri = Uri.parse('$_baseUrl/profile/$userId');
    final response = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('getProfile failed: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final pointsByState = <String, int>{};
    for (final entry in (data['points_by_state'] as List? ?? [])) {
      final e = entry as Map<String, dynamic>;
      pointsByState[e['state'] as String] = (e['score'] as num).toInt();
    }

    return (
      stats: UserStats(
        totalPoints: (data['total_score'] as num?)?.toInt() ?? 0,
        placesVisited: (data['total_places_visited_count'] as num?)?.toInt() ?? 0,
        pointsByState: pointsByState,
      ),
      email: data['user_email'] as String? ?? '',
      displayName: data['user_name'] as String? ?? '',
    );
  }

  Future<PlacesTree> getPlacesTree() async {
    final uri = Uri.parse('$_baseUrl/places-tree');
    final response = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('getPlacesTree failed: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final states = (data['states'] as List)
        .cast<Map<String, dynamic>>()
        .map(
          (s) => StateNode(
            state: s['state'] as String,
            districts: (s['districts'] as List).cast<String>(),
          ),
        )
        .toList();

    return PlacesTree(states: states);
  }

  /// Fetches a single page of spots. Returns the list for that page;
  /// caller decides whether more pages exist (length == pageSize).
  Future<List<Place>> getSpotsByFilter({
    required String state,
    required String district,
    int page = 1,
    int pageSize = 50,
  }) async {
    final uri = Uri.parse('$_baseUrl/locations/').replace(
      queryParameters: {
        'district': district,
        'page': page.toString(),
        'page_size': pageSize.toString(),
      },
    );

    final response = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('getSpotsByFilter failed: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final results = (data['results'] as List? ?? []).cast<Map<String, dynamic>>();
    return results.map(_placeFromLocationsJson).toList();
  }

  static Place _placeFromLocationsJson(Map<String, dynamic> json) {
    final locationType = json['location_type'] as String? ?? '';
    return Place(
      id: json['id'].toString(),
      name: json['place_name'] as String? ?? '',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      district: json['district'] as String? ?? '',
      state: json['state'] as String? ?? '',
      country: 'India',
      pointsValue: (json['score'] as num?)?.toInt() ?? 0,
      radiusM: _defaultRadius(locationType),
      category: locationType,
    );
  }

  Future<List<ApiLeaderboardEntry>> getLeaderboard({
    String? state,
    String? district,
    int pageSize = 50,
  }) async {
    final all = <ApiLeaderboardEntry>[];
    var page = 1;

    while (true) {
      final uri = Uri.parse('$_baseUrl/leaderboard/').replace(
        queryParameters: {
          'page': page.toString(),
          'page_size': pageSize.toString(),
          if (state != null) 'state': state,
          if (district != null) 'district': district,
        },
      );

      final response = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('getLeaderboard failed: ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = (data['results'] as List? ?? []).cast<Map<String, dynamic>>();
      all.addAll(
        results.map(
          (r) => ApiLeaderboardEntry(
            userId: r['user_id'] as String,
            userName: r['user_name'] as String? ?? r['user_id'] as String,
            score: (r['score'] as num).toInt(),
          ),
        ),
      );

      if (results.length < pageSize) break;
      page++;
    }

    return all;
  }

  // "leisure:playground" → "playground"
  static String _parseCategory(String locationType) {
    final parts = locationType.split(':');
    return parts.length > 1 ? parts.last : locationType;
  }

  static int _defaultRadius(String locationType) {
    final category = _parseCategory(locationType);
    return switch (category) {
      'park' || 'nature_reserve' || 'forest' => 300,
      'playground' => 100,
      'museum' || 'gallery' => 150,
      'beach' => 500,
      _ => 150,
    };
  }
}
