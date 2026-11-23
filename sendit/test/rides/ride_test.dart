import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:sendit/rides/models/ride.dart';
import 'package:sendit/rides/services/ride_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Ride JSON-Roundtrip', () {
    final startedAt = DateTime.utc(2026, 11, 23, 10);
    final ride = Ride(
      id: 'ride-1',
      startedAt: startedAt,
      endedAt: startedAt.add(const Duration(minutes: 15)),
      distanceMeters: 1250,
      durationSeconds: 900,
      points: [
        RideTrackPoint(
          latitude: 48.3,
          longitude: 14.28,
          timestamp: startedAt,
        ),
      ],
    );

    final restored = Ride.fromJson(ride.toJson());

    expect(restored.id, ride.id);
    expect(restored.distanceMeters, ride.distanceMeters);
    expect(restored.durationSeconds, ride.durationSeconds);
    expect(restored.points.single.position, const LatLng(48.3, 14.28));
    expect(restored.startedAt, startedAt);
  });

  test('Fahrten bleiben nach einem Neustart erhalten', () async {
    final startedAt = DateTime.utc(2026, 11, 23, 10);
    final ride = Ride(
      id: 'ride-1',
      startedAt: startedAt,
      endedAt: startedAt.add(const Duration(minutes: 10)),
      distanceMeters: 2000,
      durationSeconds: 600,
      points: [
        RideTrackPoint(
          latitude: 48.3,
          longitude: 14.28,
          timestamp: startedAt,
        ),
      ],
    );

    final firstStorage = RideStorage(userId: 'user-1');
    await firstStorage.add(ride);

    final secondStorage = RideStorage(userId: 'user-1');
    final rides = await secondStorage.load();

    expect(rides, hasLength(1));
    expect(rides.single.id, 'ride-1');
  });

  test('Fahrten sind pro Benutzer getrennt', () async {
    final storageA = RideStorage(userId: 'user-a');
    final storageB = RideStorage(userId: 'user-b');
    final startedAt = DateTime.utc(2026, 11, 23, 10);

    await storageA.add(
      Ride(
        id: 'ride-a',
        startedAt: startedAt,
        endedAt: startedAt.add(const Duration(minutes: 1)),
        distanceMeters: 100,
        durationSeconds: 60,
        points: [],
      ),
    );

    expect(await storageB.load(), isEmpty);
  });

  test('Beschädigte Fahrtdaten führen nicht zum Absturz', () async {
    SharedPreferences.setMockInitialValues({'rides_user-1': 'kein json'});

    expect(await RideStorage(userId: 'user-1').load(), isEmpty);
  });
}
