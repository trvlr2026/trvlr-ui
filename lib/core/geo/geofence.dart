import 'package:geolocator/geolocator.dart';

import '../../data/models/place.dart';

double distanceBetweenM(double lat1, double lng1, double lat2, double lng2) {
  return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
}

bool isWithinGeofence(Place place, double lat, double lng) {
  return distanceBetweenM(lat, lng, place.latitude, place.longitude) <= place.radiusM;
}

Place? findMatchingPlace(List<Place> places, double lat, double lng) {
  Place? best;
  var bestDistance = double.infinity;

  for (final place in places) {
    if (!isWithinGeofence(place, lat, lng)) continue;
    final d = distanceBetweenM(lat, lng, place.latitude, place.longitude);
    if (d < bestDistance) {
      bestDistance = d;
      best = place;
    }
  }
  return best;
}

List<PhotoCoordCluster> clusterCoords(List<PhotoCoordInput> coords, {double radiusM = 50}) {
  final clusters = <PhotoCoordCluster>[];
  for (final coord in coords) {
    var merged = false;
    for (final cluster in clusters) {
      if (distanceBetweenM(coord.latitude, coord.longitude, cluster.latitude, cluster.longitude) <= radiusM) {
        cluster.add(coord);
        merged = true;
        break;
      }
    }
    if (!merged) {
      clusters.add(PhotoCoordCluster.fromCoord(coord));
    }
  }
  return clusters;
}

class PhotoCoordInput {
  const PhotoCoordInput({required this.latitude, required this.longitude, this.takenAt});
  final double latitude;
  final double longitude;
  final DateTime? takenAt;
}

class PhotoCoordCluster {
  PhotoCoordCluster({required this.latitude, required this.longitude, required this.takenAt});
  final double latitude;
  final double longitude;
  final DateTime? takenAt;

  factory PhotoCoordCluster.fromCoord(PhotoCoordInput coord) => PhotoCoordCluster(
        latitude: coord.latitude,
        longitude: coord.longitude,
        takenAt: coord.takenAt,
      );

  void add(PhotoCoordInput coord) {
    // centroid update not needed for matching; keep first coord
  }
}
