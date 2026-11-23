import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/ride.dart';
import '../services/ride_location_source.dart';
import '../services/ride_storage.dart';

enum RideRecordingState { idle, recording, paused }

/// Steuert Start, Pause, Fortsetzen und Beenden einer GPS-Fahrt.
class RideRecordingController extends ChangeNotifier {
  RideRecordingController({
    required this._locationSource,
    required this._storage,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final RideLocationSource _locationSource;
  final RideStorage _storage;
  final DateTime Function() _now;
  final List<RideTrackPoint> _points = [];

  StreamSubscription<RideTrackPoint>? _positionSubscription;
  RideRecordingState _state = RideRecordingState.idle;
  DateTime? _startedAt;
  DateTime? _segmentStartedAt;
  Duration _recordedDuration = Duration.zero;
  double _distanceMeters = 0;
  bool _beginNewSegment = true;
  bool _isStopping = false;
  bool _disposed = false;
  String? _errorMessage;

  RideRecordingState get state => _state;
  List<RideTrackPoint> get points => List.unmodifiable(_points);
  DateTime? get startedAt => _startedAt;
  double get distanceMeters => _distanceMeters;
  String? get errorMessage => _errorMessage;
  bool get isStopping => _isStopping;

  Duration get duration {
    if (_state == RideRecordingState.recording &&
        _segmentStartedAt != null) {
      return _recordedDuration + _now().difference(_segmentStartedAt!);
    }
    return _recordedDuration;
  }

  Future<bool> start() async {
    if (_state != RideRecordingState.idle) return false;

    _errorMessage = null;
    try {
      final permitted = await _locationSource.requestPermission();
      if (!permitted) {
        _errorMessage = 'Standortberechtigung oder GPS ist nicht verfügbar.';
        notifyListeners();
        return false;
      }

      _points.clear();
      _distanceMeters = 0;
      _beginNewSegment = true;
      _recordedDuration = Duration.zero;
      _startedAt = _now();
      _segmentStartedAt = _startedAt;
      _state = RideRecordingState.recording;
      _listenToPositions();
      notifyListeners();
      return true;
    } catch (_) {
      _errorMessage = 'Die GPS-Aufzeichnung konnte nicht gestartet werden.';
      notifyListeners();
      return false;
    }
  }

  void _listenToPositions() {
    _positionSubscription = _locationSource.positions.listen(
      _addPosition,
      onError: (_) {
        _errorMessage = 'Die GPS-Verbindung wurde unterbrochen.';
        notifyListeners();
      },
    );
  }

  void _addPosition(RideTrackPoint point) {
    if (_state != RideRecordingState.recording) return;
    if (point.latitude < -90 ||
        point.latitude > 90 ||
        point.longitude < -180 ||
        point.longitude > 180) {
      return;
    }

    if (_points.isNotEmpty && !_beginNewSegment) {
      final previous = _points.last;
      if (!point.timestamp.isAfter(previous.timestamp)) return;

      _distanceMeters += const Distance().as(
        LengthUnit.Meter,
        previous.position,
        point.position,
      );
    }

    _points.add(point);
    _beginNewSegment = false;
    notifyListeners();
  }

  Future<void> pause() async {
    if (_state != RideRecordingState.recording) return;

    _recordedDuration += _now().difference(_segmentStartedAt!);
    _segmentStartedAt = null;
    _state = RideRecordingState.paused;
    _beginNewSegment = true;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    notifyListeners();
  }

  Future<void> resume() async {
    if (_state != RideRecordingState.paused || _isStopping) return;

    _segmentStartedAt = _now();
    _state = RideRecordingState.recording;
    _listenToPositions();
    notifyListeners();
  }

  Future<Ride?> stop() async {
    if (_state == RideRecordingState.idle || _isStopping) return null;
    _isStopping = true;
    _errorMessage = null;

    if (_state == RideRecordingState.recording) {
      _recordedDuration += _now().difference(_segmentStartedAt!);
    }

    _state = RideRecordingState.paused;
    _segmentStartedAt = null;
    _beginNewSegment = true;
    final subscription = _positionSubscription;
    _positionSubscription = null;
    notifyListeners();

    final start = _startedAt!;
    final ride = _points.isEmpty
        ? null
        : Ride(
            id: _now().microsecondsSinceEpoch.toString(),
            startedAt: start,
            endedAt: _now(),
            distanceMeters: _distanceMeters,
            durationSeconds: _recordedDuration.inSeconds,
            points: List.unmodifiable(_points),
          );

    try {
      await subscription?.cancel();
      if (ride != null) await _storage.add(ride);
      _reset();
      return ride;
    } catch (_) {
      _errorMessage = 'Die Fahrt konnte nicht gespeichert werden.';
      return null;
    } finally {
      _isStopping = false;
      if (!_disposed) notifyListeners();
    }
  }

  void _reset() {
    _state = RideRecordingState.idle;
    _startedAt = null;
    _segmentStartedAt = null;
    _recordedDuration = Duration.zero;
    _distanceMeters = 0;
    _beginNewSegment = true;
    _points.clear();
    _errorMessage = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _positionSubscription?.cancel();
    super.dispose();
  }
}
