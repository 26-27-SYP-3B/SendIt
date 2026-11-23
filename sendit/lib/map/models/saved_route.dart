import 'package:latlong2/latlong.dart';

import '../services/routing_service.dart';

const maxRideRoutePoints = 25000;

Map<String, double> positionToJson(LatLng position) => {
  'lat': position.latitude,
  'lng': position.longitude,
};

LatLng positionFromJson(Map<String, dynamic> json) =>
    LatLng((json['lat'] as num).toDouble(), (json['lng'] as num).toDouble());

String formatCoordinates(LatLng position) =>
    '${position.latitude.toStringAsFixed(5)}, '
    '${position.longitude.toStringAsFixed(5)}';

class SavedRoute {
  const SavedRoute({required this.name, required this.result});

  final String name;
  final RouteResult result;

  Map<String, Object> toJson() => {
    'name': name,
    'points': result.points.map(positionToJson).toList(),
    'distanceMeters': result.distanceMeters,
    'durationSeconds': result.durationSeconds,
  };

  factory SavedRoute.fromJson(Map<String, dynamic> json) => SavedRoute(
    name: json['name'] as String,
    result: RouteResult(
      points: [
        for (final point in json['points'] as List)
          positionFromJson(point as Map<String, dynamic>),
      ],
      distanceMeters: (json['distanceMeters'] as num).toDouble(),
      durationSeconds: (json['durationSeconds'] as num).toDouble(),
    ),
  );
}
