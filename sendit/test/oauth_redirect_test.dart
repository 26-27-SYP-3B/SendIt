import 'package:clerk_flutter/src/utils/oauth_redirect.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Completes a native callback once across WebKit event races', () {
    final redirect = OAuthRedirect();
    const url = 'com.clerk.flutter://callback?rotating_token_nonce=test-token';
    expect(redirect.accept(url), isTrue);
    expect(redirect.accept(url), isFalse);
    expect(redirect.completed, isTrue);
  });

  test('Rejects callback lookalikes without consuming the real callback', () {
    final redirect = OAuthRedirect();
    for (final url in [
      null,
      'https://github.com/login/oauth/authorize',
      'https://callback',
      'com.clerk.flutter://callback.evil',
      'com.clerk.flutter://callback/another-path',
      'com.clerk.flutter://user@callback',
      'com.clerk.flutter://callback:1234',
    ]) {
      expect(redirect.accept(url), isFalse, reason: url);
    }
    expect(redirect.accept('com.clerk.flutter://callback'), isTrue);
  });

  test('Does not complete OAuth from an embedded frame', () {
    final redirect = OAuthRedirect();
    expect(
      redirect.accept('com.clerk.flutter://callback', isMainFrame: false),
      isFalse,
    );
    expect(redirect.completed, isFalse);
    expect(redirect.accept('com.clerk.flutter://callback'), isTrue);
  });
}
