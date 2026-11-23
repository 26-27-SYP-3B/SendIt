import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RouteResult {
  const RouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;

  /// z. B. "12,3 km" bzw. "850 m"
  String get formattedDistance {
    if (distanceMeters < 1000) return '${distanceMeters.round()} m';
    return '${(distanceMeters / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
  }

  /// z. B. "1 h 05 min" bzw. "12 min"
  String get formattedDuration {
    final minutes = (durationSeconds / 60).round();
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h h $m min';
  }
}

class RoutingException implements Exception {
  const RoutingException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Berechnet Auto-Routen über den öffentlichen OSRM-Server
/// (OpenStreetMap-Daten, kein API-Key nötig).
class RoutingService {
  RoutingService({
    http.Client? client,
    this.baseUrl = 'https://router.project-osrm.org',
    this.timeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;
  final Duration timeout;

  void close() => _client.close();

  Future<RouteResult> route(List<LatLng> waypoints) async {
    if (waypoints.length < 2) {
      throw const RoutingException(
        'Für eine Route braucht es mindestens zwei Punkte.',
      );
    }

    final coords = waypoints
        .map((p) => '${p.longitude},${p.latitude}')
        .join(';');
    final uri = Uri.parse(
      '$baseUrl/route/v1/driving/$coords?overview=full&geometries=geojson',
    );

    final http.Response response;
    try {
      response = await _client.get(uri).timeout(timeout);
    } on TimeoutException {
      throw const RoutingException('Der Routenserver antwortet nicht.');
    } catch (_) {
      throw const RoutingException(
        'Route konnte nicht geladen werden. Bitte Internetverbindung prüfen.',
      );
    }

    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || body['code'] != 'Ok') {
        throw const RoutingException(
          'Zwischen diesen Punkten wurde keine Route gefunden.',
        );
      }
      final route = (body['routes'] as List).first as Map<String, dynamic>;
      final coordinates =
          (route['geometry'] as Map<String, dynamic>)['coordinates'] as List;
      return RouteResult(
        points: coordinates.map((c) {
          final pair = c as List;
          return LatLng(
            (pair[1] as num).toDouble(),
            (pair[0] as num).toDouble(),
          );
        }).toList(),
        distanceMeters: (route['distance'] as num).toDouble(),
        durationSeconds: (route['duration'] as num).toDouble(),
      );
    } on RoutingException {
      rethrow;
    } catch (_) {
      throw const RoutingException('Ungültige Antwort vom Routenserver.');
    }
  }
}
