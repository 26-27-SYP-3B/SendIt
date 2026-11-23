import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

enum LocationFailure { serviceDisabled, denied, deniedForever, unavailable }

class LocationResult {
  const LocationResult.success(LatLng this.position) : failure = null;
  const LocationResult.failure(LocationFailure this.failure) : position = null;

  final LatLng? position;
  final LocationFailure? failure;

  bool get isSuccess => position != null;
}

/// Kapselt Berechtigung und Positionsabfrage, damit die UI testbar bleibt.
class LocationService {
  const LocationService();

  Future<LocationResult> getCurrentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationResult.failure(LocationFailure.serviceDisabled);
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        return const LocationResult.failure(LocationFailure.denied);
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationResult.failure(LocationFailure.deniedForever);
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return LocationResult.success(LatLng(pos.latitude, pos.longitude));
    } catch (_) {
      return const LocationResult.failure(LocationFailure.unavailable);
    }
  }

  Future<void> openAppSettings() => Geolocator.openAppSettings();

  Future<void> openLocationSettings() => Geolocator.openLocationSettings();
}
