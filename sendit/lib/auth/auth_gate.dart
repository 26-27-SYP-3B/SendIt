import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';

import 'oauth_completion.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SendIt')),
      body: SafeArea(
        child: ClerkErrorListener(
          child: ClerkAuthBuilder(
            builder: (context, auth) {
              if (auth.isNotAvailable) {
                return AuthUnavailable(
                  message:
                      'Die Anmeldung ist gerade nicht erreichbar. '
                      'Bitte prüfe deine Internetverbindung.',
                  onRetry: () => auth.safelyCall(context, () async {
                    await auth.refreshClient();
                    await auth.refreshEnvironment();
                  }),
                );
              }

              if (auth.isSignedIn) {
                return const _SignedInView();
              }

              return SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: OAuthCompletion(
                    auth: auth,
                    child: const ClerkAuthentication(),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SignedInView extends StatelessWidget {
  const _SignedInView();

  @override
  Widget build(BuildContext context) {
    final user = ClerkAuth.userOf(context)!;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ClerkUserButton(),
            const SizedBox(height: 24),
            Text(
              'Willkommen bei SendIt!',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(user.email ?? user.name, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class AuthUnavailable extends StatelessWidget {
  const AuthUnavailable({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onRetry,
                child: const Text('Erneut versuchen'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
