import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:sendit/map/map_points_controller.dart';
import 'package:sendit/map/models/map_point.dart';
import 'package:sendit/map/services/point_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('MapPoint JSON-Roundtrip', () {
    const point = MapPoint(
      id: '1',
      name: 'Lager',
      latitude: 48.3,
      longitude: 14.28,
    );
    expect(MapPoint.fromJson(point.toJson()), point);
  });

  test('Punkte bleiben nach "Neustart" erhalten', () async {
    final first = MapPointsController(PointStorage(userId: 'u1'));
    await first.load();
    await first.add('Lager', const LatLng(48.3, 14.28));
    await first.add('Kunde', const LatLng(48.2, 16.37));

    // Neuer Controller = App neu gestartet
    final second = MapPointsController(PointStorage(userId: 'u1'));
    await second.load();
    expect(second.points.map((p) => p.name), ['Lager', 'Kunde']);
  });

  test('Punkte sind pro Benutzer getrennt', () async {
    final a = MapPointsController(PointStorage(userId: 'a'));
    await a.load();
    await a.add('Nur A', const LatLng(1, 1));

    final b = MapPointsController(PointStorage(userId: 'b'));
    await b.load();
    expect(b.points, isEmpty);
  });

  test('Route erst ab zwei Punkten möglich', () async {
    final c = MapPointsController(PointStorage(userId: 'u'));
    await c.load();
    expect(c.canCreateRoute, isFalse);
    await c.add('A', const LatLng(1, 1));
    expect(c.canCreateRoute, isFalse);
    await c.add('B', const LatLng(2, 2));
    expect(c.canCreateRoute, isTrue);
  });

  test('Umbenennen und Löschen werden gespeichert', () async {
    final c = MapPointsController(PointStorage(userId: 'u'));
    await c.load();
    final p = await c.add('Alt', const LatLng(1, 1));
    await c.rename(p.id, 'Neu');
    expect(c.points.single.name, 'Neu');
    await c.remove(p.id);

    final reloaded = MapPointsController(PointStorage(userId: 'u'));
    await reloaded.load();
    expect(reloaded.points, isEmpty);
  });

  test('Kaputte gespeicherte Daten führen nicht zum Absturz', () async {
    SharedPreferences.setMockInitialValues({'map_points_u': 'kein json'});
    expect(await PointStorage(userId: 'u').load(), isEmpty);
  });
}
