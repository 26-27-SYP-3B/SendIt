import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ride.dart';

class RidesException implements Exception {
  const RidesException(this.message, [this.status]);

  final String message;
  final int? status;
}

class RidesApi {
  RidesApi({
    required String baseUrl,
    required this.sessionToken,
    http.Client? client,
  }) : _baseUri = Uri.tryParse(baseUrl.trim()),
       _client = client ?? http.Client();

  final Uri? _baseUri;
  // Der Token wird vor jeder Anfrage aus der aktiven Clerk-Sitzung geladen.
  final Future<String> Function() sessionToken;
  final http.Client _client;

  bool get isConfigured {
    final uri = _baseUri;
    return uri != null &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        !uri.hasQuery &&
        !uri.hasFragment &&
        (uri.scheme == 'https' ||
            (uri.scheme == 'http' &&
                {'localhost', '127.0.0.1', '::1'}.contains(uri.host)));
  }

  void close() => _client.close();

  Future<List<Ride>> rides() async => [
    for (final item in await _send('GET', 'rides') as List)
      Ride.fromJson(item as Map<String, dynamic>),
  ];

  Future<Ride> createRide(RideDraft draft) async => Ride.fromJson(
    await _send('POST', 'rides', draft.toJson()) as Map<String, dynamic>,
  );

  Future<Ride> joinRide(String id) async => Ride.fromJson(
    await _send('POST', 'rides/$id/join') as Map<String, dynamic>,
  );

  Future<List<RideGroup>> groups() async => [
    for (final item in await _send('GET', 'groups') as List)
      RideGroup.fromJson(item as Map<String, dynamic>),
  ];

  Future<List<RideFriend>> friends() async => [
    for (final item in await _send('GET', 'friends') as List)
      RideFriend.fromJson(item as Map<String, dynamic>),
  ];

  Future<void> createGroup(String name) =>
      _send('POST', 'groups', {'name': name});

  Future<void> leaveGroup(String id) => _send('DELETE', 'groups/$id');

  Future<void> removeFriend(String id) => _send('DELETE', 'friends/$id');

  Future<String> createInvitation({String? groupId}) async {
    final result = await _send('POST', 'invites', {'groupId': groupId});
    return (result as Map<String, dynamic>)['code'] as String;
  }

  Future<void> redeemInvitation(String code) =>
      _send('POST', 'invites/redeem', {'code': code.trim()});

  Future<Object?> _send(
    String method,
    String path, [
    Map<String, Object?>? body,
  ]) async {
    if (!isConfigured) {
      throw const RidesException(
        'Der Ausfahrten-Dienst ist noch nicht eingerichtet.',
      );
    }

    final String token;
    try {
      token = await sessionToken().timeout(const Duration(seconds: 12));
    } catch (_) {
      throw const RidesException(
        'Deine Anmeldung konnte nicht bestätigt werden. Bitte versuche es erneut.',
      );
    }

    final uri = _baseUri!.replace(
      pathSegments: [
        ..._baseUri.pathSegments.where((part) => part.isNotEmpty),
        ...path.split('/'),
      ],
    );
    try {
      final request = http.Request(method, uri)
        ..followRedirects = false
        ..headers['Authorization'] = 'Bearer $token';
      if (body != null) {
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode(body);
      }
      final response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 15));
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = data is Map ? data['error'] as String? : null;
        throw RidesException(
          message ?? 'Die Anfrage konnte nicht abgeschlossen werden.',
          response.statusCode,
        );
      }
      return data;
    } on RidesException {
      rethrow;
    } catch (_) {
      throw const RidesException(
        'Der Ausfahrten-Dienst ist gerade nicht erreichbar. Bitte versuche es erneut.',
      );
    }
  }
}
