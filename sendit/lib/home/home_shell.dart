import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';

import '../map/map_page.dart';

/// Hauptbereich nach dem Login mit Navigation zwischen Start und Karte.
///
/// [start] ist die bisherige Startansicht aus `auth_gate.dart`, damit andere
/// Features (Profil, Abmelden, ...) dort weiter ergänzt werden können.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.start});

  final Widget start;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final user = ClerkAuth.userOf(context)!;

    return Column(
      children: [
        Expanded(
          child: IndexedStack(
            index: _index,
            children: [
              widget.start,
              MapPage(userId: user.id),
            ],
          ),
        ),
        NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Start',
            ),
            NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map),
              label: 'Karte',
            ),
          ],
        ),
      ],
    );
  }
}
