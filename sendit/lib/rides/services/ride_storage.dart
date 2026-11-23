import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ride.dart';

/// Speichert abgeschlossene Fahrten getrennt nach Benutzer.
class RideStorage {
  RideStorage({required String userId}) : _key = 'rides_$userId';

  final String _key;

  Future<List<Ride>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];

    try {
      final rides = jsonDecode(raw) as List<dynamic>;
      return rides
          .map((ride) => Ride.fromJson(ride as Map<String, dynamic>))
          .toList();
    } catch (error) {
      debugPrint('Gespeicherte Fahrten konnten nicht gelesen werden: $error');
      return [];
    }
  }

  Future<void> save(List<Ride> rides) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(rides.map((ride) => ride.toJson()).toList()),
    );
  }

  Future<void> add(Ride ride) async {
    final rides = await load();
    rides.insert(0, ride);
    await save(rides);
  }
}
