import 'package:connectivity_plus/connectivity_plus.dart';

/// Meldet, ob das Gerät eine Netzwerkverbindung hat.
class ConnectivityService {
  ConnectivityService([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  static bool _isOnline(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  Future<bool> isOnline() async {
    try {
      return _isOnline(await _connectivity.checkConnectivity());
    } catch (_) {
      // Im Zweifel versuchen wir es; Kachelfehler werden separat abgefangen.
      return true;
    }
  }

  Stream<bool> get onlineChanges =>
      _connectivity.onConnectivityChanged.map(_isOnline);
}
