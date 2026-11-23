import 'package:latlong2/latlong.dart';

/// Ein einzelner GPS-Punkt einer aufgezeichneten Fahrt.
class RideTrackPoint {
  const RideTrackPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  final double latitude;
  final double longitude;
  final DateTime timestamp;

  LatLng get position => LatLng(latitude, longitude);

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'timestamp': timestamp.toIso8601String(),
  };

  factory RideTrackPoint.fromJson(Map<String, dynamic> json) =>
      RideTrackPoint(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

/// Eine abgeschlossene GPS-Fahrt.
class Ride {
  const Ride({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.points,
  });

  final String id;
  final DateTime startedAt;
  final DateTime endedAt;
  final double distanceMeters;
  final int durationSeconds;
  final List<RideTrackPoint> points;

  String get formattedDistance {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m';
    }
    return '${(distanceMeters / 1000).toStringAsFixed(2)} km';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'startedAt': startedAt.toIso8601String(),
    'endedAt': endedAt.toIso8601String(),
    'distanceMeters': distanceMeters,
    'durationSeconds': durationSeconds,
    'points': points.map((point) => point.toJson()).toList(),
  };

  factory Ride.fromJson(Map<String, dynamic> json) => Ride(
    id: json['id'] as String,
    startedAt: DateTime.parse(json['startedAt'] as String),
    endedAt: DateTime.parse(json['endedAt'] as String),
    distanceMeters: (json['distanceMeters'] as num).toDouble(),
    durationSeconds: json['durationSeconds'] as int,
    points: (json['points'] as List<dynamic>)
        .map((point) => RideTrackPoint.fromJson(point as Map<String, dynamic>))
        .toList(),
  );
}
