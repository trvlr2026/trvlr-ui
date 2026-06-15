enum VisitSource { gps, photoImport }

class Visit {
  const Visit({
    required this.id,
    required this.placeId,
    required this.placeName,
    required this.district,
    required this.state,
    required this.pointsEarned,
    required this.visitedAt,
    required this.source,
  });

  final String id;
  final String placeId;
  final String placeName;
  final String district;
  final String state;
  final int pointsEarned;
  final DateTime visitedAt;
  final VisitSource source;

  Map<String, dynamic> toJson() => {
        'id': id,
        'placeId': placeId,
        'placeName': placeName,
        'district': district,
        'state': state,
        'pointsEarned': pointsEarned,
        'visitedAt': visitedAt.toIso8601String(),
        'source': source.name,
      };

  factory Visit.fromJson(Map<String, dynamic> json) => Visit(
        id: json['id'] as String,
        placeId: json['placeId'] as String,
        placeName: json['placeName'] as String,
        district: json['district'] as String,
        state: json['state'] as String,
        pointsEarned: json['pointsEarned'] as int,
        visitedAt: DateTime.parse(json['visitedAt'] as String),
        source: VisitSource.values.byName(json['source'] as String),
      );
}
