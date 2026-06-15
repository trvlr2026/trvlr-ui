class GeoTaggedPhoto {
  const GeoTaggedPhoto({
    required this.assetId,
    this.latitude,
    this.longitude,
    this.takenAt,
    this.placeName,
    this.district,
    this.state,
  });

  final String assetId;
  final double? latitude;
  final double? longitude;
  final DateTime? takenAt;
  final String? placeName;
  final String? district;
  final String? state;

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
