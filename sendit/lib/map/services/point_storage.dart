import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/map_point.dart';

/// Speichert die Punkte eines Fahrers lokal auf dem Gerät,
/// damit sie nach einem Neustart der App wieder da sind.
class PointStorage {
  PointStorage({required String userId}) : _key = 'map_points_$userId';

  final String _key;

  Future<List<MapPoint>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => MapPoint.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // Beschädigte Daten sollen die App nicht zum Absturz bringen.
      debugPrint('Gespeicherte Punkte konnten nicht gelesen werden: $e');
      return [];
    }
  }

  Future<void> save(List<MapPoint> points) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(points.map((p) => p.toJson()).toList()),
    );
  }
}
