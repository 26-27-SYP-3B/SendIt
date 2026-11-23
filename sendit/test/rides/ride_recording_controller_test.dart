import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendit/rides/controllers/ride_recording_controller.dart';
import 'package:sendit/rides/models/ride.dart';
import 'package:sendit/rides/services/ride_location_source.dart';
import 'package:sendit/rides/services/ride_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeRideLocationSource implements RideLocationSource {
  final StreamController<RideTrackPoint> _controller =
      StreamController<RideTrackPoint>.broadcast();

  bool permissionGranted = true;

  @override
  Future<bool> requestPermission() async => permissionGranted;

  @override
  Stream<RideTrackPoint> get positions => _controller.stream;

  void add(RideTrackPoint point) => _controller.add(point);

  Future<void> close() => _controller.close();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Starten, GPS-Punkte erfassen und Fahrt speichern', () async {
    final source = FakeRideLocationSource();
    var now = DateTime.utc(2026, 11, 23, 10);
    final controller = RideRecordingController(
      locationSource: source,
      storage: RideStorage(userId: 'test'),
      now: () => now,
    );

    expect(await controller.start(), isTrue);
    expect(controller.state, RideRecordingState.recording);

    source.add(
      RideTrackPoint(
        latitude: 48.3,
        longitude: 14.28,
        timestamp: now,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    now = now.add(const Duration(seconds: 10));
    source.add(
      RideTrackPoint(
        latitude: 48.31,
        longitude: 14.29,
        timestamp: now,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    final pendingRide = controller.stop();
    expect(await controller.stop(), isNull);
    final ride = await pendingRide;

    expect(ride, isNotNull);
    expect(ride!.points, hasLength(2));
    expect(ride.distanceMeters, greaterThan(0));
    expect(ride.durationSeconds, 10);
    expect(controller.state, RideRecordingState.idle);

    final stored = await RideStorage(userId: 'test').load();
    expect(stored.single.id, ride.id);
    await source.close();
    controller.dispose();
  });

  test('Pause zählt nicht zur Aufzeichnungsdauer', () async {
    final source = FakeRideLocationSource();
    var now = DateTime.utc(2026, 11, 23, 10);
    final controller = RideRecordingController(
      locationSource: source,
      storage: RideStorage(userId: 'pause-test'),
      now: () => now,
    );

    expect(await controller.start(), isTrue);
    source.add(
      RideTrackPoint(
        latitude: 48.3,
        longitude: 14.28,
        timestamp: now,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    now = now.add(const Duration(seconds: 10));
    await controller.pause();
    expect(controller.state, RideRecordingState.paused);
    expect(controller.duration, const Duration(seconds: 10));

    now = now.add(const Duration(minutes: 5));
    await controller.resume();
    now = now.add(const Duration(seconds: 20));

    final ride = await controller.stop();
    expect(ride!.durationSeconds, 30);
    await source.close();
    controller.dispose();
  });

  test('Bewegung während der Pause wird nicht zur Strecke gerechnet', () async {
    final source = FakeRideLocationSource();
    var now = DateTime.utc(2026, 11, 23, 10);
    final controller = RideRecordingController(
      locationSource: source,
      storage: RideStorage(userId: 'pause-distance-test'),
      now: () => now,
    );

    await controller.start();
    source.add(
      RideTrackPoint(latitude: 48.3, longitude: 14.28, timestamp: now),
    );
    await Future<void>.delayed(Duration.zero);

    now = now.add(const Duration(seconds: 10));
    await controller.pause();

    now = now.add(const Duration(minutes: 5));
    await controller.resume();
    source.add(
      RideTrackPoint(latitude: 48.4, longitude: 14.38, timestamp: now),
    );
    await Future<void>.delayed(Duration.zero);

    final ride = await controller.stop();
    expect(ride, isNotNull);
    expect(ride!.points, hasLength(2));
    expect(ride.distanceMeters, 0);
    await source.close();
    controller.dispose();
  });

  test('Start wird ohne Standortberechtigung abgelehnt', () async {
    final source = FakeRideLocationSource()..permissionGranted = false;
    final controller = RideRecordingController(
      locationSource: source,
      storage: RideStorage(userId: 'denied-test'),
    );

    expect(await controller.start(), isFalse);
    expect(controller.state, RideRecordingState.idle);
    expect(controller.errorMessage, isNotNull);
    await source.close();
    controller.dispose();
  });
}
