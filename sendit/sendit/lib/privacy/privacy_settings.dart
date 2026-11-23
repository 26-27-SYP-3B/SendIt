import 'package:flutter/foundation.dart';

/// Wer darf etwas sehen?
enum Audience {
  public('Öffentlich'),
  friends('Nur Freunde'),
  private('Privat');

  const Audience(this.label);
  final String label;
}

/// Wer schaut zu? (für die Sichtbarkeitsprüfung)
enum Viewer { stranger, friend, self }

/// Privatsphäre-Einstellungen eines Fahrers.
///
/// Ist ein [ChangeNotifier]: jede Änderung benachrichtigt sofort alle
/// Listener, Änderungen wirken also ohne Speichern/Neustart.
class PrivacySettings extends ChangeNotifier {
  PrivacySettings._();

  /// Eine gemeinsame Instanz für die ganze App.
  static final PrivacySettings instance = PrivacySettings._();

  /// Für Tests: frische Instanz.
  @visibleForTesting
  factory PrivacySettings.forTest() => PrivacySettings._();

  Audience _profile = Audience.public;
  Audience _tours = Audience.friends;
  Audience _location = Audience.private;
  bool _locationConsent = false;

  Audience get profile => _profile;
  Audience get tours => _tours;

  /// Gewählte Sichtbarkeit für den Standort. Wirksam ist sie nur mit
  /// Zustimmung – siehe [effectiveLocation].
  Audience get location => _location;

  /// Hat der Fahrer dem Teilen des Standorts ausdrücklich zugestimmt?
  bool get locationConsent => _locationConsent;

  /// Ohne Zustimmung ist der Standort immer privat.
  Audience get effectiveLocation =>
      _locationConsent ? _location : Audience.private;

  set profile(Audience v) => _set(() => _profile = v);
  set tours(Audience v) => _set(() => _tours = v);
  set location(Audience v) => _set(() => _location = v);

  void giveLocationConsent() => _set(() => _locationConsent = true);

  /// Zustimmung widerrufen: Standort wird sofort nicht mehr geteilt.
  void revokeLocationConsent() => _set(() {
    _locationConsent = false;
    _location = Audience.private;
  });

  bool canSeeProfile(Viewer v) => _allows(_profile, v);
  bool canSeeTours(Viewer v) => _allows(_tours, v);
  bool canSeeLocation(Viewer v) => _allows(effectiveLocation, v);

  static bool _allows(Audience visibility, Viewer viewer) {
    if (viewer == Viewer.self) return true;
    return switch (visibility) {
      Audience.public => true,
      Audience.friends => viewer == Viewer.friend,
      Audience.private => false,
    };
  }

  void _set(VoidCallback change) {
    change();
    notifyListeners();
  }
}
