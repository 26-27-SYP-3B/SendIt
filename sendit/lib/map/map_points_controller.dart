import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import 'models/map_point.dart';
import 'services/point_storage.dart';

/// Hält die Punkte des Fahrers und speichert jede Änderung sofort.
class MapPointsController extends ChangeNotifier {
  MapPointsController(this._storage);

  final PointStorage _storage;
  List<MapPoint> _points = [];
  bool _loaded = false;

  List<MapPoint> get points => List.unmodifiable(_points);
  bool get isLoaded => _loaded;
  bool get canCreateRoute => _points.length >= 2;

  Future<void> load() async {
    _points = await _storage.load();
    _loaded = true;
    notifyListeners();
  }

  Future<MapPoint> add(String name, LatLng position) async {
    final point = MapPoint(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      latitude: position.latitude,
      longitude: position.longitude,
    );
    _points = [..._points, point];
    await _persist();
    return point;
  }

  Future<void> rename(String id, String name) async {
    _points = [
      for (final p in _points) p.id == id ? p.copyWith(name: name) : p,
    ];
    await _persist();
  }

  Future<void> remove(String id) async {
    _points = _points.where((p) => p.id != id).toList();
    await _persist();
  }

  Future<void> _persist() async {
    notifyListeners();
    await _storage.save(_points);
  }
}
