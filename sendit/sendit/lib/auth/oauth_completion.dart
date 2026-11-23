import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';

/// Completes the sign-in/sign-up handoff omitted by Clerk 0.0.18-beta's
/// rotating-token OAuth callback. Clerk still handles any missing requirements.
class OAuthCompletion extends StatefulWidget {
  const OAuthCompletion({super.key, required this.auth, required this.child});

  final ClerkAuthState auth;
  final Widget child;

  @override
  State<OAuthCompletion> createState() => _OAuthCompletionState();
}

class _OAuthCompletionState extends State<OAuthCompletion> {
  bool _scheduled = false;
  bool _running = false;
  bool _failed = false;
  String? _attempted;

  @override
  void initState() {
    super.initState();
    widget.auth.addListener(_scheduleCompletion);
    _scheduleCompletion();
  }

  @override
  void didUpdateWidget(OAuthCompletion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.auth != widget.auth) {
      oldWidget.auth.removeListener(_scheduleCompletion);
      widget.auth.addListener(_scheduleCompletion);
      _attempted = null;
      _failed = false;
      _scheduleCompletion();
    }
  }

  void _scheduleCompletion() {
    if (_scheduled || _running) return;
    _scheduled = true;
    // Wait until Clerk's safelyCall has released its update lock, and avoid
    // changing auth state during a widget build.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _scheduled = false;
      if (!mounted || _running) return;
      final auth = widget.auth;
      if (auth.isSignedIn) return;
      final signIn = auth.signIn;
      final signUp = auth.signUp;
      final attempt = signIn?.isTransferable == true
          ? 'signIn:${signIn!.id}'
          : signUp?.isTransferable == true
          ? 'signUp:${signUp!.id}'
          : null;
      if (attempt == null || attempt == _attempted) return;
      _attempted = attempt;
      _running = true;
      await auth.safelyCall(
        context,
        auth.transfer,
        onError: (error) {
          auth.handleError(error);
          if (mounted) setState(() => _failed = true);
        },
      );
      _running = false;
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    widget.auth.removeListener(_scheduleCompletion);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_failed)
          TextButton(
            onPressed: () {
              setState(() => _failed = false);
              _attempted = null;
              _scheduleCompletion();
            },
            child: const Text('OAuth-Anmeldung erneut abschließen'),
          ),
        widget.child,
      ],
    );
  }
}
