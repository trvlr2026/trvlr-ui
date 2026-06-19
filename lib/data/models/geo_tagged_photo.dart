class GeoTaggedPhoto {
  const GeoTaggedPhoto({
    required this.assetId,
    this.latitude,
    this.longitude,
    this.takenAt,
    this.placeName,
    this.district,
    this.state,
    this.earnedScore,
    this.locationType,
  });

  final String assetId;
  final double? latitude;
  final double? longitude;
  final DateTime? takenAt;
  final String? placeName;
  final String? district;
  final String? state;
  final int? earnedScore;
  final String? locationType;

  bool get hasLocation => latitude != null && longitude != null;

  bool get hasMatchedPlace => placeName != null;

  String get displayTitle {
    if (placeName != null) return placeName!;
    if (hasLocation) {
      return '${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}';
    }
    return 'No location data';
  }

  String? get coordinatesLabel => hasLocation
      ? 'Lat ${latitude!.toStringAsFixed(6)}, Long ${longitude!.toStringAsFixed(6)}'
      : null;

  Map<String, dynamic> toJson() => {
        'assetId': assetId,
        'latitude': latitude,
        'longitude': longitude,
        'takenAt': takenAt?.toIso8601String(),
        'earnedScore': earnedScore,
        'locationType': locationType,
      };

  factory GeoTaggedPhoto.fromJson(Map<String, dynamic> json) => GeoTaggedPhoto(
        assetId: json['assetId'] as String,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        takenAt: json['takenAt'] != null ? DateTime.parse(json['takenAt'] as String) : null,
        earnedScore: json['earnedScore'] as int?,
        locationType: json['locationType'] as String?,
      );
}

class GalleryScanResult {
  const GalleryScanResult({
    required this.totalPhotos,
    required this.geotaggedCount,
    required this.matchedPlacesCount,
    required this.photos,
    this.permissionDenied = false,
  });

  final int totalPhotos;
  final int geotaggedCount;
  final int matchedPlacesCount;
  final List<GeoTaggedPhoto> photos;
  final bool permissionDenied;
}
