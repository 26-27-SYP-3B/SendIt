import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:sendit/map/services/routing_service.dart';

const _a = LatLng(48.3, 14.28);
const _b = LatLng(48.2, 16.37);

void main() {
  test('liest Geometrie, Distanz und Dauer aus der OSRM-Antwort', () async {
    late Uri requested;
    final service = RoutingService(
      client: MockClient((req) async {
        requested = req.url;
        return http.Response(
          jsonEncode({
            'code': 'Ok',
            'routes': [
              {
                'distance': 185432.0,
                'duration': 6540.0,
                'geometry': {
                  'coordinates': [
                    [14.28, 48.3],
                    [16.37, 48.2],
                  ],
                },
              },
            ],
          }),
          200,
        );
      }),
    );

    final route = await service.route([_a, _b]);

    expect(requested.path, '/route/v1/driving/14.28,48.3;16.37,48.2');
    expect(route.points, [_a, _b]);
    expect(route.formattedDistance, '185,4 km');
    expect(route.formattedDuration, '1 h 49 min');
  });

  test('wirft RoutingException bei weniger als zwei Punkten', () {
    final service = RoutingService(
      client: MockClient((_) async => http.Response('', 500)),
    );
    expect(service.route([_a]), throwsA(isA<RoutingException>()));
  });

  test('wirft RoutingException wenn keine Route gefunden', () {
    final service = RoutingService(
      client: MockClient(
        (_) async => http.Response(jsonEncode({'code': 'NoRoute'}), 400),
      ),
    );
    expect(service.route([_a, _b]), throwsA(isA<RoutingException>()));
  });

  test('wirft RoutingException bei ungültigem JSON', () {
    final service = RoutingService(
      client: MockClient((_) async => http.Response('<html>', 200)),
    );
    expect(service.route([_a, _b]), throwsA(isA<RoutingException>()));
  });

  test('wirft RoutingException ohne Netzwerk', () {
    final service = RoutingService(
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    expect(service.route([_a, _b]), throwsA(isA<RoutingException>()));
  });

  test('wirft RoutingException bei Timeout', () {
    final service = RoutingService(
      timeout: const Duration(milliseconds: 10),
      client: MockClient((_) => Completer<http.Response>().future),
    );
    expect(service.route([_a, _b]), throwsA(isA<RoutingException>()));
  });

  test('Formatierung kurzer Strecken', () {
    const r = RouteResult(points: [], distanceMeters: 850, durationSeconds: 125);
    expect(r.formattedDistance, '850 m');
    expect(r.formattedDuration, '2 min');
  });
}
