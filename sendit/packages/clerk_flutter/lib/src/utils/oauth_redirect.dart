import 'package:clerk_auth/clerk_auth.dart' as clerk;

/// Recognizes the native callback without accepting URLs with a matching prefix.
/// WebKit can report the callback as a navigation, a URL change, or a failed
/// resource load. Only one of these events may complete the dialog.
class OAuthRedirect {
  bool completed = false;

  bool accept(String? url, {bool isMainFrame = true}) {
    if (completed || !isMainFrame || url == null) return false;
    final target = Uri.tryParse(url);
    final callback = Uri.parse(clerk.ClerkConstants.oauthRedirect);
    if (target == null ||
        target.scheme != callback.scheme ||
        target.host != callback.host ||
        target.path != callback.path ||
        target.hasPort ||
        target.userInfo.isNotEmpty) {
      return false;
    }
    completed = true;
    return true;
  }
}
