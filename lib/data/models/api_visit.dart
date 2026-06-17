class ApiVisit {
  const ApiVisit({
    required this.locationId,
    required this.placeName,
    required this.district,
    required this.locationType,
    required this.lat,
    required this.lon,
    required this.photoId,
    required this.score,
    this.visitedAt,
  });

  final int locationId;
  final String placeName;
  final String district;
  final String locationType;
  final double lat;
  final double lon;
  final String photoId;
  final int score;
  final DateTime? visitedAt;
}

class ApiVisitsPage {
  const ApiVisitsPage({
    required this.results,
    required this.page,
    required this.pageSize,
  });

  final List<ApiVisit> results;
  final int page;
  final int pageSize;
}
