import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_android/geolocator_android.dart';

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
    final LocationSettings settings;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      settings = const AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: 'SendIt – Fahrt läuft',
          notificationText: 'Deine GPS-Fahrt wird aufgezeichnet.',
          notificationChannelName: 'Fahrtenaufzeichnung',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    } else {
      settings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      );
    }

    return Geolocator.getPositionStream(
      locationSettings: settings,
    ).map(
      (position) => RideTrackPoint(
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: position.timestamp,
      ),
    );
  }
}
