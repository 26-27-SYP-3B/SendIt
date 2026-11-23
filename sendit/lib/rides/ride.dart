import 'dart:math';

import 'package:latlong2/latlong.dart';

import '../map/models/saved_route.dart';

String _twoDigits(int value) => value.toString().padLeft(2, '0');

String formatRideDate(DateTime date) =>
    '${_twoDigits(date.day)}.${_twoDigits(date.month)}.${date.year}';

String formatRideTime(int hour, int minute) =>
    '${_twoDigits(hour)}:${_twoDigits(minute)}';

String formatDeparture(DateTime departure) =>
    '${formatRideDate(departure)} · ${formatRideTime(departure.hour, departure.minute)} Uhr';

enum RideVisibility {
  public('Öffentlich'),
  friends('Nur Freunde'),
  group('Nur eine Gruppe');

  const RideVisibility(this.label);

  final String label;
}

class RideDraft {
  RideDraft({
    required this.title,
    required this.departure,
    required this.meetingPoint,
    required this.route,
    required this.visibility,
    required this.groupId,
  });

  // Eine Wiederholung desselben Speicherversuchs behält diese ID.
  final String id = _newId();
  final String title;
  final DateTime departure;
  final LatLng meetingPoint;
  final SavedRoute? route;
  final RideVisibility visibility;
  final String? groupId;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'departure': departure.millisecondsSinceEpoch,
    'meetingPoint': positionToJson(meetingPoint),
    'route': route?.toJson(),
    'visibility': visibility.name,
    'groupId': groupId,
  };

  static String _newId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }
}

class Ride {
  const Ride({
    required this.id,
    required this.title,
    required this.departure,
    required this.meetingPoint,
    required this.route,
    required this.visibility,
    required this.groupName,
    required this.isOwner,
    required this.joined,
    required this.participantCount,
  });

  final String id;
  final String title;
  final DateTime departure;
  final LatLng meetingPoint;
  final SavedRoute? route;
  final RideVisibility visibility;
  final String? groupName;
  final bool isOwner;
  final bool joined;
  final int participantCount;

  String get audienceLabel =>
      groupName == null ? visibility.label : 'Nur Gruppe · $groupName';

  factory Ride.fromJson(Map<String, dynamic> json) => Ride(
    id: json['id'] as String,
    title: json['title'] as String,
    departure: DateTime.fromMillisecondsSinceEpoch(json['departure'] as int),
    meetingPoint: positionFromJson(
      json['meetingPoint'] as Map<String, dynamic>,
    ),
    route: json['route'] == null
        ? null
        : SavedRoute.fromJson(json['route'] as Map<String, dynamic>),
    visibility: RideVisibility.values.byName(json['visibility'] as String),
    groupName: json['groupName'] as String?,
    isOwner: json['isOwner'] as bool,
    joined: json['joined'] as bool,
    participantCount: json['participantCount'] as int,
  );
}

class RideGroup {
  const RideGroup({
    required this.id,
    required this.name,
    required this.isOwner,
  });

  final String id;
  final String name;
  final bool isOwner;

  factory RideGroup.fromJson(Map<String, dynamic> json) => RideGroup(
    id: json['id'] as String,
    name: json['name'] as String,
    isOwner: json['isOwner'] as bool,
  );
}

class RideFriend {
  const RideFriend({required this.id, required this.name});

  final String id;
  final String name;

  factory RideFriend.fromJson(Map<String, dynamic> json) =>
      RideFriend(id: json['id'] as String, name: json['name'] as String);
}
