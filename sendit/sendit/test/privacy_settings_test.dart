import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendit/privacy/privacy_settings.dart';
import 'package:sendit/privacy/privacy_settings_page.dart';

void main() {
  test('Sichtbarkeit öffentlich / nur Freunde / privat', () {
    final s = PrivacySettings.forTest();

    s.profile = Audience.public;
    expect(s.canSeeProfile(Viewer.stranger), isTrue);

    s.profile = Audience.friends;
    expect(s.canSeeProfile(Viewer.stranger), isFalse);
    expect(s.canSeeProfile(Viewer.friend), isTrue);

    s.profile = Audience.private;
    expect(s.canSeeProfile(Viewer.friend), isFalse);
    expect(s.canSeeProfile(Viewer.self), isTrue);
  });

  test('Standort wird ohne Zustimmung nie geteilt', () {
    final s = PrivacySettings.forTest()..location = Audience.public;
    expect(s.canSeeLocation(Viewer.friend), isFalse);

    s.giveLocationConsent();
    s.location = Audience.public;
    expect(s.canSeeLocation(Viewer.stranger), isTrue);

    s.revokeLocationConsent();
    expect(s.canSeeLocation(Viewer.stranger), isFalse);
  });

  test('Änderungen benachrichtigen sofort', () {
    final s = PrivacySettings.forTest();
    var calls = 0;
    s.addListener(() => calls++);
    s.tours = Audience.public;
    expect(calls, 1);
  });

  testWidgets('Standort erst nach Bestätigung im Dialog geteilt', (
    tester,
  ) async {
    final s = PrivacySettings.forTest();
    await tester.pumpWidget(
      MaterialApp(home: PrivacySettingsPage(settings: s)),
    );

    await tester.tap(find.byKey(const Key('locationConsent')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(s.locationConsent, isFalse);

    await tester.tap(find.byKey(const Key('locationConsent')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zustimmen'));
    await tester.pumpAndSettle();
    expect(s.locationConsent, isTrue);
    expect(find.text('Standort sichtbar für'), findsOneWidget);
  });
}
