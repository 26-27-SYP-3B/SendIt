# Local Clerk Flutter copy

Based on clerk_flutter 0.0.18-beta from the local pub cache, under the included
LICENSE. This copy is pinned through the application's path dependency so its
fixes survive dependency installation on another computer.

The cached version already contained guards against stale background client
refreshes in `clerk_auth_state.dart`; those are preserved.

SendIt changes:

- Complete the native OAuth callback from navigation requests, URL changes, or
  WebKit resource errors, exactly once. Match the callback URI structurally.
- Do not report errors for embedded resources or after an accepted callback.
  Other main-frame loading errors remain visible.
- Do not update a dismissed OAuth overlay's title.
- Add explicit types to four declarations for current Dart analyzer rules.

The application tests cover callback recognition and duplicate events. A live
provider authorization is still required to verify a complete OAuth round trip.
