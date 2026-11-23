import 'package:clerk_auth/clerk_auth.dart' as clerk;
import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendit/auth/oauth_completion.dart';

class _Auth extends ChangeNotifier implements ClerkAuthState {
  @override
  clerk.SignIn? signIn;
  @override
  clerk.SignUp? signUp;
  @override
  bool isSignedIn = false;
  int transfers = 0;
  bool fail = false;

  @override
  Future<void> transfer() async {
    transfers++;
    if (fail) throw clerk.ClerkError.external(Exception('Test failure'));
    notifyListeners();
  }

  @override
  Future<T?> safelyCall<T>(
    BuildContext context,
    Future<T> Function() fn, {
    ClerkErrorCallback? onError,
  }) async {
    try {
      return await fn();
    } on clerk.ClerkError catch (error) {
      onError?.call(error);
      return null;
    }
  }

  @override
  void handleError(Object error) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TransferableSignUp implements clerk.SignUp {
  @override
  String get id => 'signup';
  @override
  bool get isTransferable => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

clerk.SignIn _signIn(clerk.Status status) => clerk.SignIn(
  id: 'signin',
  status: clerk.Status.needsFirstFactor,
  supportedIdentifiers: const [],
  supportedFirstFactors: const [],
  supportedSecondFactors: const [],
  firstFactorVerification: clerk.Verification(
    status: status,
    strategy: clerk.Strategy.oauthGoogle,
    attempts: 1,
    expireAt: DateTime(2030),
  ),
);

Future<void> _show(WidgetTester tester, _Auth auth) async {
  await tester.pumpWidget(
    MaterialApp(
      home: OAuthCompletion(auth: auth, child: const Text('Authentication')),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Transfers a new OAuth user once, after provider verification', (
    tester,
  ) async {
    final auth = _Auth()..signIn = _signIn(clerk.Status.unverified);
    await _show(tester, auth);
    expect(auth.transfers, 0);

    auth.signIn = _signIn(clerk.Status.transferable);
    auth.notifyListeners();
    await tester.pumpAndSettle();
    expect(auth.transfers, 1);

    auth.notifyListeners();
    await tester.pumpAndSettle();
    expect(auth.transfers, 1);
  });

  testWidgets('Transfers an existing OAuth account back to sign-in', (
    tester,
  ) async {
    final auth = _Auth()..signUp = _TransferableSignUp();
    await _show(tester, auth);
    expect(auth.transfers, 1);
  });

  testWidgets('Does not transfer an authenticated session', (tester) async {
    final auth = _Auth()
      ..signIn = _signIn(clerk.Status.transferable)
      ..isSignedIn = true;
    await _show(tester, auth);
    expect(auth.transfers, 0);
  });

  testWidgets('Allows explicit retry after a failed transfer', (tester) async {
    final auth = _Auth()
      ..signIn = _signIn(clerk.Status.transferable)
      ..fail = true;
    await _show(tester, auth);
    expect(auth.transfers, 1);
    auth.fail = false;
    await tester.tap(find.text('OAuth-Anmeldung erneut abschließen'));
    await tester.pumpAndSettle();
    expect(auth.transfers, 2);
    expect(find.text('OAuth-Anmeldung erneut abschließen'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
