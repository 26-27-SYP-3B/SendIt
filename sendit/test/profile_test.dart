import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendit/profile/driver_profile.dart';
import 'package:sendit/profile/profile_card.dart';

const _old = DriverProfile(
  name: 'Max Muster',
  location: 'Linz',
  bio: 'Fahre jeden Tag nach Wien.',
);

/// Holds the profile like the Clerk user would and counts save calls.
class _Host extends StatefulWidget {
  const _Host({this.succeed = true});

  final bool succeed;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  DriverProfile profile = _old;
  final saved = <DriverProfile>[];

  Future<bool> _save(DriverProfile value) async {
    saved.add(value);
    if (widget.succeed) setState(() => profile = value);
    return widget.succeed;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ProfileCard(profile: profile, onSave: _save),
        ),
      ),
    );
  }
}

Future<_HostState> _openEditor(
  WidgetTester tester, {
  bool succeed = true,
}) async {
  await tester.pumpWidget(_Host(succeed: succeed));
  await tester.tap(find.text('Profil bearbeiten'));
  await tester.pumpAndSettle();
  return tester.state<_HostState>(find.byType(_Host));
}

void main() {
  testWidgets('Saving applies name, place and bio and shows them at once', (
    tester,
  ) async {
    final host = await _openEditor(tester);

    await tester.enterText(
      find.byKey(const Key('profile-name')),
      ' Anna Berg ',
    );
    await tester.enterText(find.byKey(const Key('profile-location')), 'Graz');
    await tester.enterText(
      find.byKey(const Key('profile-bio')),
      'Pünktlich und freundlich.',
    );
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    expect(host.saved, const [
      DriverProfile(
        name: 'Anna Berg',
        location: 'Graz',
        bio: 'Pünktlich und freundlich.',
      ),
    ]);
    expect(find.text('Profil bearbeiten'), findsOneWidget);
    expect(find.text('Anna Berg'), findsOneWidget);
    expect(find.text('Graz'), findsOneWidget);
    expect(find.text('Pünktlich und freundlich.'), findsOneWidget);
  });

  testWidgets('Bio stops at 300 characters and shows a counter', (
    tester,
  ) async {
    await _openEditor(tester);
    final bio = find.byKey(const Key('profile-bio'));

    await tester.enterText(bio, '');
    await tester.pump();
    expect(find.text('0/300'), findsOneWidget);

    await tester.enterText(bio, 'a' * 350);
    await tester.pump();

    final field = tester.widget<TextField>(bio);
    expect(field.controller!.text, 'a' * DriverProfile.maxBioLength);
    expect(find.text('300/300'), findsOneWidget);
  });

  testWidgets('Cancelling keeps the old data', (tester) async {
    final host = await _openEditor(tester);

    await tester.enterText(find.byKey(const Key('profile-name')), 'Anderer');
    await tester.enterText(find.byKey(const Key('profile-location')), 'Wels');
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();

    expect(host.saved, isEmpty);
    expect(host.profile, _old);
    expect(find.text('Max Muster'), findsOneWidget);
    expect(find.text('Linz'), findsOneWidget);
    expect(find.text('Anderer'), findsNothing);

    await tester.tap(find.text('Profil bearbeiten'));
    await tester.pumpAndSettle();
    final name = tester.widget<TextField>(
      find.byKey(const Key('profile-name')),
    );
    expect(name.controller!.text, 'Max Muster');
  });

  testWidgets('A failed save keeps the form open and the old data', (
    tester,
  ) async {
    final host = await _openEditor(tester, succeed: false);

    await tester.enterText(find.byKey(const Key('profile-location')), 'Wels');
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    expect(host.saved, hasLength(1));
    expect(host.profile, _old);
    expect(
      find.textContaining('konnte nicht gespeichert werden'),
      findsOneWidget,
    );
    expect(find.text('Speichern'), findsOneWidget);
  });

  test('Profile is merged into existing metadata', () {
    final metadata = _old.mergeInto({'other': 1});

    expect(metadata['other'], 1);
    expect(metadata[DriverProfile.metadataKey], {
      'name': 'Max Muster',
      'location': 'Linz',
      'bio': 'Fahre jeden Tag nach Wien.',
    });
  });
}
