import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:sendit/map/map_page.dart';
import 'package:sendit/map/services/connectivity_service.dart';
import 'package:sendit/map/services/location_service.dart';
import 'package:sendit/map/services/routing_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeConnectivity implements ConnectivityService {
  _FakeConnectivity({this.online = true});

  bool online;
  final _changes = StreamController<bool>.broadcast();

  @override
  Future<bool> isOnline() async => online;

  @override
  Stream<bool> get onlineChanges => _changes.stream;
}

class _FakeLocation implements LocationService {
  _FakeLocation(this.result);

  final LocationResult result;

  @override
  Future<LocationResult> getCurrentLocation() async => result;

  @override
  Future<void> openAppSettings() async {}

  @override
  Future<void> openLocationSettings() async {}
}

RoutingService _routing() => RoutingService(
  client: MockClient(
    (_) async => http.Response(
      jsonEncode({
        'code': 'Ok',
        'routes': [
          {
            'distance': 1234.0,
            'duration': 300.0,
            'geometry': {
              'coordinates': [
                [14.28, 48.3],
                [14.29, 48.31],
              ],
            },
          },
        ],
      }),
      200,
    ),
  ),
);

Future<void> _pump(
  WidgetTester tester, {
  ConnectivityService? connectivity,
  LocationService? location,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MapPage(
          userId: 'test',
          connectivityService: connectivity ?? _FakeConnectivity(),
          locationService:
              location ??
              _FakeLocation(
                const LocationResult.failure(LocationFailure.denied),
              ),
          routingService: _routing(),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _addPoint(WidgetTester tester, String name) async {
  await tester.longPress(find.byType(FlutterMap));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), name);
  await tester.tap(find.text('Speichern'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Punkte setzen und Route erstellen', (tester) async {
    await _pump(tester);
    expect(find.textContaining('Lange auf die Karte drücken'), findsOneWidget);

    final button = find.byKey(const Key('create_route_button'));
    ButtonStyleButton routeButton() => tester.widget<ButtonStyleButton>(button);

    await _addPoint(tester, 'Lager');
    expect(find.text('1. Lager'), findsOneWidget);
    expect(routeButton().onPressed, isNull);

    await _addPoint(tester, 'Kunde');
    expect(find.text('2. Kunde'), findsOneWidget);
    expect(routeButton().onPressed, isNotNull);

    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('1,2 km'), findsOneWidget);
    expect(find.text('ca. 5 min'), findsOneWidget);
    expect(find.byType(PolylineLayer), findsOneWidget);
  });

  testWidgets('Punkt umbenennen und löschen', (tester) async {
    await _pump(tester);
    await _addPoint(tester, 'Alt');

    await tester.tap(find.text('1. Alt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Umbenennen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Neu');
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(find.text('1. Neu'), findsOneWidget);

    await tester.tap(find.text('1. Neu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Löschen'));
    await tester.pumpAndSettle();
    expect(find.text('1. Neu'), findsNothing);
  });

  testWidgets('zeigt Hinweis ohne Internetverbindung', (tester) async {
    await _pump(tester, connectivity: _FakeConnectivity(online: false));
    await tester.pump();
    expect(find.textContaining('Keine Internetverbindung'), findsOneWidget);
  });

  testWidgets('Standort abgelehnt zeigt Meldung, Karte bleibt nutzbar', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.byTooltip('Mein Standort'));
    await tester.pump();
    expect(find.textContaining('Ohne Standortberechtigung'), findsOneWidget);
  });

  testWidgets('Standort gefunden zeigt Positionspunkt', (tester) async {
    await _pump(
      tester,
      location: _FakeLocation(
        const LocationResult.success(LatLng(48.3, 14.28)),
      ),
    );
    final markersBefore = tester
        .widget<MarkerLayer>(find.byType(MarkerLayer))
        .markers
        .length;
    await tester.tap(find.byTooltip('Mein Standort'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers.length,
      markersBefore + 1,
    );
  });
}
