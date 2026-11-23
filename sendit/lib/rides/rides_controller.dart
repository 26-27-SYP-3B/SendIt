import 'package:flutter/foundation.dart';

import 'ride.dart';
import 'rides_api.dart';

class RidesController extends ChangeNotifier {
  RidesController(this.api);

  final RidesApi api;
  List<Ride> _rides = const [];
  int _refreshVersion = 0;
  bool _disposed = false;
  bool _loading = false;
  String? _error;

  List<Ride> get rides => _rides;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> refresh() async {
    if (_disposed) return;
    final version = ++_refreshVersion;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final rides = await api.rides();
      if (version != _refreshVersion) return;
      _rides = List.unmodifiable(rides);
    } catch (error) {
      if (version != _refreshVersion) return;
      _rides = const [];
      _error = error is RidesException
          ? error.message
          : 'Ausfahrten konnten nicht geladen werden.';
    } finally {
      if (version == _refreshVersion) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<Ride> publish(RideDraft draft) async {
    final ride = await api.createRide(draft);
    _updateRide(ride);
    return ride;
  }

  Future<void> join(String id) async {
    try {
      _updateRide(await api.joinRide(id));
    } on RidesException catch (error) {
      if (error.status == 404 || error.status == 409) await refresh();
      rethrow;
    }
  }

  void _updateRide(Ride ride) {
    if (_disposed) return;
    _refreshVersion++;
    _loading = false;
    _error = null;
    _rides = List.unmodifiable(
      [
        for (final current in rides)
          if (current.id != ride.id) current,
        ride,
      ]..sort((a, b) => a.departure.compareTo(b.departure)),
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _refreshVersion++;
    api.close();
    super.dispose();
  }
}
