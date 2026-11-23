
import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';

import '../profile/driver_profile.dart';
import '../profile/profile_card.dart';
import 'oauth_completion.dart';
import '../home/home_shell.dart';

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
                final userId = auth.user!.id;
                return HomeShell(
                  key: ValueKey(userId),
                  start: const _SignedInView(),
                  userId: userId,
                  sessionToken: () async {
                    if (auth.user?.id != userId) {
                      throw StateError('Die aktive Sitzung wurde gewechselt.');
                    }
                    final token = await auth.sessionToken();
                    if (auth.user?.id != userId) {
                      throw StateError('Die aktive Sitzung wurde gewechselt.');
                    }
                    return token.jwt;
                  },
                );
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
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
    final auth = ClerkAuth.of(context);
    final user = auth.user!;

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
            const SizedBox(height: 24),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ProfileCard(
                profile: DriverProfile.fromUser(user),
                onSave: (profile) => saveDriverProfile(auth, profile),
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const SettingsView(),
                  ),
                );
              },
              icon: const Icon(Icons.settings),
              label: const Text('Einstellungen'),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  bool _isSigningOut = false;

  Future<void> _signOut() async {
    setState(() {
      _isSigningOut = true;
    });

    final auth = ClerkAuth.of(context);
    bool failed = false;

    await auth.safelyCall(
      context,
      auth.signOut,
      onError: (error) {
        auth.handleError(error);
        failed = true;
      },
    );

    if (!mounted) return;

    if (failed) {
      setState(() {
        _isSigningOut = false;
      });
      return;
    }

    Navigator.of(context).popUntil(
          (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Einstellungen'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const ListTile(
              leading: Icon(Icons.person),
              title: Text('Konto'),
              subtitle: Text('Kontoeinstellungen'),
            ),
            const Divider(),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSigningOut ? null : _signOut,
                icon: const Icon(Icons.logout),
                label: Text(
                  _isSigningOut ? 'Abmelden...' : 'Abmelden',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthUnavailable extends StatelessWidget {
  const AuthUnavailable({
    super.key,
    required this.message,
    this.onRetry,
  });

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
