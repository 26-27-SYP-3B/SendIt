import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/saved_route.dart';

class RouteStorage {
  RouteStorage({required String userId}) : _key = 'saved_routes_$userId';

  final String _key;

  Future<List<SavedRoute>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final entries = preferences.getStringList(_key) ?? [];
    final routes = <SavedRoute>[];
    for (final entry in entries) {
      try {
        routes.add(
          SavedRoute.fromJson(jsonDecode(entry) as Map<String, dynamic>),
        );
      } on FormatException {
        // Eine beschädigte Route soll die übrigen Einträge nicht verdecken.
      } on TypeError {
        // Ein unvollständiger Eintrag kann nicht als Route angezeigt werden.
      }
    }
    return routes;
  }

  Future<void> save(SavedRoute route) async {
    final preferences = await SharedPreferences.getInstance();
    final entries = preferences.getStringList(_key) ?? [];
    final saved = await preferences.setStringList(_key, [
      jsonEncode(route.toJson()),
      ...entries,
    ]);
    if (!saved) {
      await preferences.reload();
      throw StateError('Gespeicherte Routen konnten nicht geschrieben werden.');
    }
  }
}
