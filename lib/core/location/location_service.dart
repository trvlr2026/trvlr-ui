import 'package:geolocator/geolocator.dart';

class LocationService {
  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  Future<LocationPermission> requestPermission() => Geolocator.requestPermission();

  Future<Position?> getCurrentPosition() async {
    final enabled = await isServiceEnabled();
    if (!enabled) return null;

    var permission = await checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return null;
    }

    return Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
  }
}
