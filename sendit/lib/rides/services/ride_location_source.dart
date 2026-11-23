import 'package:geolocator/geolocator.dart';

import '../models/ride.dart';

/// Liefert GPS-Positionen für eine laufende Fahrtenaufzeichnung.
abstract class RideLocationSource {
  Future<bool> requestPermission();

  Stream<RideTrackPoint> get positions;
}

/// Geolocator-Anbindung für die Fahrtenaufzeichnung.
class GeolocatorRideLocationSource implements RideLocationSource {
  const GeolocatorRideLocationSource();

  @override
  Future<bool> requestPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  @override
  Stream<RideTrackPoint> get positions {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).map(
      (position) => RideTrackPoint(
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: position.timestamp,
      ),
    );
  }
}
