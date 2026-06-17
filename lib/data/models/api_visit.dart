class ApiVisitLocation {
  const ApiVisitLocation({
    required this.id,
    required this.lat,
    required this.lon,
    required this.placeName,
    required this.district,
    required this.locationType,
    required this.score,
  });

  final int id;
  final double lat;
  final double lon;
  final String placeName;
  final String district;
  final String locationType;
  final int score;
}

class ApiVisit {
  const ApiVisit({
    required this.photoId,
    required this.score,
    required this.location,
    this.visitedAt,
  });

  final String photoId;
  final int score;
  final ApiVisitLocation location;
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
