import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:sendit/home/home_shell.dart';
import 'package:sendit/map/models/saved_route.dart';
import 'package:sendit/map/services/route_storage.dart';
import 'package:sendit/map/services/routing_service.dart';
import 'package:sendit/rides/create_ride_page.dart';
import 'package:sendit/rides/ride.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _userId = 'user_Test';
const _publicRide = 'Eine Runde mit anderen';

http.Response _json(Object payload, [int status = 200]) => http.Response(
  jsonEncode(payload),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

class _ApiFixture {
  final Map<String, dynamic> publicRide = {
    'id': 'another',
    'title': _publicRide,
    'departure': DateTime.now()
        .add(const Duration(days: 1))
        .millisecondsSinceEpoch,
    'meetingPoint': {'lat': 47.6, 'lng': 13.8},
    'route': null,
    'visibility': 'public',
    'groupName': null,
    'isOwner': false,
    'joined': false,
    'participantCount': 0,
  };
  Map<String, dynamic>? postedRide;
  Map<String, dynamic>? savedRide;
  bool failFirstSave = false;
  final List<String> publishAttempts = [];

  http.Client get client => MockClient((request) async {
    if (request.url.host == 'router.project-osrm.org') {
      return _json({
        'code': 'Ok',
        'routes': [
          {
            'distance': 7200,
            'duration': 626,
            'geometry': {
              'coordinates': [
                [13.8, 47.6],
                [14.2, 47.7],
              ],
            },
          },
        ],
      });
    }
    if (request.url.host != 'sendit.example') return http.Response('', 404);
    expect(request.headers['authorization'], 'Bearer session-token');
    switch ((request.method, request.url.path)) {
      case ('GET', '/rides'):
        return _json([publicRide, ?savedRide]);
      case ('GET', '/groups'):
        return _json([
          {'id': 'group-one', 'name': 'Mittwochsfahrer', 'isOwner': true},
          {'id': 'group-two', 'name': 'Donaurunde', 'isOwner': false},
        ]);
      case ('POST', '/rides'):
        final draft = jsonDecode(request.body) as Map<String, dynamic>;
        publishAttempts.add(draft['id'] as String);
        postedRide = draft;
        savedRide = {
          ...draft,
          'groupName': draft['groupId'] == 'group-two' ? 'Donaurunde' : null,
          'isOwner': true,
          'joined': false,
          'participantCount': 0,
        };
        if (failFirstSave && publishAttempts.length == 1) {
          return _json({'error': 'Verbindung unterbrochen.'}, 503);
        }
        return _json(savedRide!, 201);
      case ('POST', '/rides/another/join'):
        publicRide['joined'] = true;
        publicRide['participantCount'] = 1;
        return _json(publicRide);
      default:
        throw StateError('${request.method} ${request.url.path}');
    }
  });
}

Future<void> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(410, 850);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('de', 'AT'),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('de', 'AT')],
      home: Scaffold(
        body: HomeShell(
          start: const Text('Startseite'),
          userId: _userId,
          sessionToken: () async => 'session-token',
          ridesApiUrl: 'https://sendit.example',
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  final form = find.byType(CreateRidePage);
  if (finder.evaluate().isEmpty && form.evaluate().isNotEmpty) {
    await tester.scrollUntilVisible(
      finder,
      100,
      scrollable: find
          .descendant(of: form, matching: find.byType(Scrollable))
          .first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _openForm(WidgetTester tester) async {
  await _tap(tester, find.text('Ausfahrten'));
  await _tap(tester, find.text('Ausfahrt erstellen'));
}

List<FixedExtentScrollController> _pickerWheels(WidgetTester tester) => tester
    .widgetList<CupertinoPicker>(
      find.descendant(
        of: find.byType(CupertinoDatePicker),
        matching: find.byType(CupertinoPicker),
      ),
    )
    .map((wheel) => wheel.scrollController)
    .whereType<FixedExtentScrollController>()
    .toList();

Future<DateTime> _completeRequired(
  WidgetTester tester, {
  required String title,
}) async {
  await tester.enterText(find.byType(TextField), title);

  await _tap(tester, find.text('Datum *'));
  final tomorrow = DateUtils.addDaysToDate(DateTime.now(), 1);
  final dateWheels = _pickerWheels(tester);
  expect(dateWheels, hasLength(3));
  dateWheels[2].jumpToItem(tomorrow.year);
  dateWheels[1].jumpToItem(tomorrow.month - 1);
  dateWheels[0].jumpToItem(tomorrow.day - 1);
  await tester.pumpAndSettle();
  await _tap(tester, find.text('Fertig'));
  expect(find.text(formatRideDate(tomorrow)), findsOneWidget);

  await _tap(tester, find.text('Abfahrtszeit *'));
  final timeWheels = _pickerWheels(tester);
  expect(timeWheels, hasLength(2));
  timeWheels[0].jumpToItem(18);
  timeWheels[1].jumpToItem(45);
  await tester.pumpAndSettle();
  await _tap(tester, find.text('Fertig'));
  expect(find.text('18:45'), findsOneWidget);

  await _tap(tester, find.text('Treffpunkt auf der Karte *'));
  expect(
    tester
        .widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Treffpunkt übernehmen'),
        )
        .onPressed,
    isNull,
  );
  await tester.tapAt(
    tester.getCenter(find.byType(FlutterMap)) + const Offset(75, 0),
  );
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pumpAndSettle();
  await _tap(tester, find.text('Treffpunkt übernehmen'));
  expect(find.byType(CreateRidePage), findsOneWidget);
  return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 18, 45);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Pflichtfelder blockieren das Speichern', (tester) async {
    final api = _ApiFixture();
    await http.runWithClient(() async {
      await _pumpApp(tester);
      await _openForm(tester);
      await _tap(tester, find.text('Abfahrtszeit *'));
      final hour = _pickerWheels(tester).first;
      hour.jumpToItem(hour.selectedItem + 1);
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Abbrechen'));
      await _tap(tester, find.text('Ausfahrt speichern'));
      expect(
        find.text('Gib einen Titel mit bis zu 100 Zeichen ein.'),
        findsOneWidget,
      );
      expect(find.text('Wähle ein Datum.'), findsOneWidget);
      expect(find.text('Wähle eine Abfahrtszeit.'), findsOneWidget);
      expect(find.text('Wähle einen Treffpunkt.'), findsOneWidget);
      expect(api.postedRide, isNull);
    }, () => api.client);
  });

  testWidgets(
    'Ausfahrt mit Kartenroute und ausgewählter Gruppe erscheint in beiden Ansichten',
    (tester) async {
      final api = _ApiFixture();
      await http.runWithClient(() async {
        await _pumpApp(tester);
        await _openForm(tester);
        final selectedDeparture = await _completeRequired(
          tester,
          title: '  Mühlviertelrunde  ',
        );
        await _tap(tester, find.text('Route planen'));
        final map = find.byType(FlutterMap);
        await tester.tapAt(tester.getCenter(map) + const Offset(100, 65));
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();
        await _tap(tester, find.text('Route berechnen'));
        expect(find.byType(PolylineLayer), findsOneWidget);
        await _tap(tester, find.text('Route übernehmen'));
        expect(find.text('Geplante Route'), findsOneWidget);

        final visibility = find.byType(DropdownButtonFormField<RideVisibility>);
        await tester.ensureVisible(visibility);
        await tester.pumpAndSettle();
        final field = tester.getRect(visibility);
        expect(find.byIcon(Icons.check_rounded), findsNothing);
        await _tap(tester, find.text('Öffentlich'));
        expect(find.byIcon(Icons.check_rounded), findsOneWidget);
        final menu = tester.getRect(
          find.ancestor(
            of: find.text('Nur Freunde').last,
            matching: find.byType(ListView),
          ),
        );
        expect(menu.left, closeTo(field.left, 1));
        expect(menu.right, closeTo(field.right, 1));
        await _tap(tester, find.text('Nur eine Gruppe').last);
        expect(find.byIcon(Icons.check_rounded), findsNothing);
        await _tap(tester, find.text('Gruppe *'));
        await _tap(tester, find.text('Donaurunde').last);
        await _tap(tester, find.text('Ausfahrt speichern'));

        expect(api.postedRide!['title'], 'Mühlviertelrunde');
        expect(api.postedRide!['visibility'], 'group');
        expect(api.postedRide!['groupId'], 'group-two');
        expect(api.postedRide!['route']['distanceMeters'], 7200);
        final departure = DateTime.fromMillisecondsSinceEpoch(
          api.postedRide!['departure'] as int,
        );
        expect(departure, selectedDeparture);
        expect(find.text('Mühlviertelrunde'), findsOneWidget);
        await _tap(tester, find.text('Mühlviertelrunde'));
        await _tap(tester, find.text('Auf der Karte zeigen'));
        expect(find.byTooltip('Mühlviertelrunde'), findsOneWidget);
        expect(find.byType(PolylineLayer), findsOneWidget);
      }, () => api.client);
    },
  );

  testWidgets(
    'gespeicherte Route ist kontogebunden und Speichern nach Verbindungsfehler wiederholbar',
    (tester) async {
      final api = _ApiFixture()..failFirstSave = true;
      const route = SavedRoute(
        name: 'Meine Hausrunde',
        result: RouteResult(
          points: [LatLng(47.6, 13.8), LatLng(47.7, 14.2)],
          distanceMeters: 1560,
          durationSeconds: 310,
        ),
      );
      await RouteStorage(userId: _userId).save(route);
      expect(await RouteStorage(userId: 'user_Other').load(), isEmpty);

      await http.runWithClient(() async {
        await _pumpApp(tester);
        await _openForm(tester);
        await _completeRequired(tester, title: 'Ausfahrt mit Hausrunde');
        await _tap(tester, find.text('Gespeicherte wählen'));
        await _tap(tester, find.text(route.name));
        await _tap(tester, find.text('Ausfahrt speichern'));
        expect(find.text('Verbindung unterbrochen.'), findsOneWidget);
        await _tap(tester, find.text('Ausfahrt speichern'));
        expect(api.publishAttempts.length, 2);
        expect(api.publishAttempts.toSet(), hasLength(1));
        expect(api.postedRide!['route'], route.toJson());
        expect(find.text('Ausfahrt mit Hausrunde'), findsOneWidget);
      }, () => api.client);
    },
  );

  testWidgets(
    'Kartenmarker öffnet Details und Anmeldung erscheint auch in der Übersicht',
    (tester) async {
      final api = _ApiFixture();
      await http.runWithClient(() async {
        await _pumpApp(tester);
        await _tap(tester, find.text('Karte'));
        final marker = find.byTooltip(_publicRide);
        expect(marker, findsOneWidget);
        await _tap(tester, marker);
        await _tap(tester, find.text('Mitfahren'));
        expect(find.text('1 angemeldet'), findsOneWidget);
        expect(find.text('Angemeldet'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        await _tap(tester, find.text('Ausfahrten'));
        expect(find.textContaining('Öffentlich · Angemeldet'), findsOneWidget);
      }, () => api.client);
    },
  );
}
