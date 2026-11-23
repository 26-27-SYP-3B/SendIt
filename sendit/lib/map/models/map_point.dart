import 'package:latlong2/latlong.dart';

/// Ein vom Fahrer auf der Karte gesetzter, benannter Punkt.
class MapPoint {
  const MapPoint({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;

  LatLng get position => LatLng(latitude, longitude);

  MapPoint copyWith({String? name}) => MapPoint(
    id: id,
    name: name ?? this.name,
    latitude: latitude,
    longitude: longitude,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'lat': latitude,
    'lng': longitude,
  };

  factory MapPoint.fromJson(Map<String, dynamic> json) => MapPoint(
    id: json['id'] as String,
    name: json['name'] as String,
    latitude: (json['lat'] as num).toDouble(),
    longitude: (json['lng'] as num).toDouble(),
  );

  @override
  bool operator ==(Object other) =>
      other is MapPoint &&
      other.id == id &&
      other.name == name &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(id, name, latitude, longitude);
}
