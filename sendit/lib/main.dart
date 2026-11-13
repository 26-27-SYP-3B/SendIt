import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';

import 'auth/auth_gate.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    this.publishableKey = const String.fromEnvironment('CLERK_PUBLISHABLE_KEY'),
  });

  final String publishableKey;

  @override
  Widget build(BuildContext context) {
    final key = publishableKey.trim();
    final isConfigured =
        key.startsWith('pk_test_') || key.startsWith('pk_live_');

    return MaterialApp(
      title: 'SendIt',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      builder: isConfigured
          ? (context, child) => ClerkAuth(
              config: ClerkAuthConfig(
                publishableKey: key,
                loading: const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                ),
              ),
              child: child!,
            )
          : null,
      home: isConfigured
          ? const AuthGate()
          : const Scaffold(
              body: SafeArea(
                child: AuthUnavailable(
                  message: 'Die Anmeldung ist noch nicht eingerichtet.',
                ),
              ),
            ),
    );
  }
}
