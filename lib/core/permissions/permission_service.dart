import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:photo_manager/photo_manager.dart';

/// Shared options for gallery access + GPS metadata on Android.
const photoPermissionRequest = PermissionRequestOption(
  androidPermission: AndroidPermission(
    type: RequestType.image,
    mediaLocation: true,
  ),
);

class PermissionService {
  Future<bool> requestLocation() async {
    final status = await ph.Permission.locationWhenInUse.request();
    return status.isGranted;
  }

  /// Request gallery access via photo_manager (required for My Photos to work).
  Future<PermissionState> requestPhotos() async {
    return PhotoManager.requestPermissionExtend(requestOption: photoPermissionRequest);
  }

  Future<bool> hasPhotoAccess() async {
    final state = await PhotoManager.getPermissionState(requestOption: photoPermissionRequest);
    return state.hasAccess;
  }

  Future<bool> hasLocation() async {
    final status = await ph.Permission.locationWhenInUse.status;
    return status.isGranted;
  }

  Future<bool> openSettings() => ph.openAppSettings();
}

extension PhotoPermissionHelpers on PermissionState {
  bool get needsSettings => this == PermissionState.denied || this == PermissionState.restricted;
}
