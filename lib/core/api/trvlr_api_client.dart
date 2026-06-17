import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../data/models/api_visit.dart';
import '../../data/models/bulk_checkin.dart';
import '../../data/models/place.dart';
import '../../data/models/places_tree.dart';
import 'api_config.dart';

class TrvlrApiClient {
  Future<List<Place>> getNearbyPlaces({
    required String userId,
    required double lat,
    required double lon,
    double radiusM = 5000,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/nearby/').replace(
      queryParameters: {
        'user_id': userId,
        'lat': lat.toString(),
        'lon': lon.toString(),
        'radius': radiusM.toString(),
      },
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 10));

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
      // state is not returned by the API yet — will be empty until backend adds it
      state: '',
      country: 'India',
      pointsValue: json['score'] as int? ?? 10,
      // use a sensible default check-in radius per category
      radiusM: _defaultRadius(json['location_type'] as String? ?? ''),
      category: _parseCategory(json['location_type'] as String? ?? 'landmark'),
    );
  }

  Future<BulkCheckInResult> bulkCheckIn({
    required String userId,
    required List<({double lat, double lon, String photoId})> coordinates,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/checkin/');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
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
    final uri = Uri.parse('${ApiConfig.baseUrl}/$userId/visits').replace(
      queryParameters: {
        'page': page.toString(),
        'page_size': pageSize.toString(),
      },
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 10));

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

  Future<PlacesTree> getPlacesTree() async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/places-tree');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));

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

  Future<List<Place>> getSpotsByFilter({
    required String state,
    required String district,
    int pageSize = 50,
  }) async {
    final all = <Place>[];
    var page = 1;

    while (true) {
      final uri = Uri.parse('${ApiConfig.baseUrl}/locations/').replace(
        queryParameters: {
          'district': district,
          'page': page.toString(),
          'page_size': pageSize.toString(),
        },
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('getSpotsByFilter failed: ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = (data['results'] as List? ?? []).cast<Map<String, dynamic>>();
      all.addAll(results.map(_placeFromLocationsJson));

      if (results.length < pageSize) break;
      page++;
    }

    return all;
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
