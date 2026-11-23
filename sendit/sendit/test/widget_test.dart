import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendit/main.dart';

void main() {
  testWidgets('Starts without contacting Clerk when no key is configured', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp(publishableKey: ''));
    await tester.pumpAndSettle();

    expect(
      find.text('Die Anmeldung ist noch nicht eingerichtet.'),
      findsOneWidget,
    );
    expect(find.byType(ClerkAuth), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Does not initialize the client with a secret key', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp(publishableKey: 'sk_test_invalid'));
    await tester.pumpAndSettle();

    expect(find.byType(ClerkAuth), findsNothing);
    expect(find.byType(ClerkAuthentication), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
