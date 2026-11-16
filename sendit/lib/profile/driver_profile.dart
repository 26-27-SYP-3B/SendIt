import 'package:clerk_auth/clerk_auth.dart' as clerk;
import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/foundation.dart';

/// Public profile of a driver: name, place of residence and a short bio.
///
/// Stored in the Clerk user's unsafe metadata under [metadataKey], because
/// that is the only user data the app may write without a backend.
@immutable
class DriverProfile {
  const DriverProfile({this.name = '', this.location = '', this.bio = ''});

  /// Builds the profile from [user]. Before the first save, the name falls
  /// back to the name from the Clerk account.
  factory DriverProfile.fromUser(clerk.User user) {
    final data = user.unsafeMetadata?[metadataKey];
    final stored = data is Map ? data : const {};
    String read(String key) {
      final value = stored[key];
      return value is String ? value : '';
    }

    final name = stored[_nameKey];
    return DriverProfile(
      name: name is String ? name : user.name,
      location: read(_locationKey),
      bio: read(_bioKey),
    );
  }

  static const metadataKey = 'driverProfile';
  static const maxBioLength = 300;
  static const _nameKey = 'name';
  static const _locationKey = 'location';
  static const _bioKey = 'bio';

  final String name;
  final String location;
  final String bio;

  /// Returns a copy without surrounding whitespace.
  DriverProfile trimmed() => DriverProfile(
    name: name.trim(),
    location: location.trim(),
    bio: bio.trim(),
  );

  /// Returns [existing] metadata with this profile added. Clerk replaces the
  /// unsafe metadata as a whole, so other entries must be sent along.
  Map<String, dynamic> mergeInto(Map<String, dynamic>? existing) => {
    ...?existing,
    metadataKey: {_nameKey: name, _locationKey: location, _bioKey: bio},
  };

  @override
  bool operator ==(Object other) =>
      other is DriverProfile &&
      other.name == name &&
      other.location == location &&
      other.bio == bio;

  @override
  int get hashCode => Object.hash(name, location, bio);
}

/// Saves [profile] for the signed-in user and reports whether Clerk accepted
/// it. Errors reach the [ClerkErrorListener] through [ClerkAuthState].
Future<bool> saveDriverProfile(
  ClerkAuthState auth,
  DriverProfile profile,
) async {
  final user = auth.user;
  if (user == null) return false;
  if (DriverProfile.fromUser(user) == profile) return true;
  try {
    await auth.updateUser(metadata: profile.mergeInto(user.unsafeMetadata));
  } catch (error, stack) {
    debugPrint('Profil konnte nicht gespeichert werden: $error\n$stack');
    return false;
  }
  final updated = auth.user;
  return updated != null && DriverProfile.fromUser(updated) == profile;
}
