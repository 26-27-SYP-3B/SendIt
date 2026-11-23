import 'package:flutter/material.dart';

import 'privacy_settings.dart';

class PrivacySettingsPage extends StatelessWidget {
  const PrivacySettingsPage({super.key, PrivacySettings? settings})
    : _settings = settings;

  final PrivacySettings? _settings;

  @override
  Widget build(BuildContext context) {
    final settings = _settings ?? PrivacySettings.instance;

    return Scaffold(
      appBar: AppBar(title: const Text('Privatsphäre')),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _VisibilityTile(
              title: 'Profil',
              icon: Icons.person,
              value: settings.profile,
              onChanged: (v) => settings.profile = v,
            ),
            _VisibilityTile(
              title: 'Touren',
              icon: Icons.route,
              value: settings.tours,
              onChanged: (v) => settings.tours = v,
            ),
            const Divider(height: 32),
            SwitchListTile(
              key: const Key('locationConsent'),
              secondary: const Icon(Icons.location_on),
              title: const Text('Standort teilen'),
              subtitle: const Text(
                'Dein Standort wird nur mit deiner ausdrücklichen '
                'Zustimmung geteilt.',
              ),
              value: settings.locationConsent,
              onChanged: (on) async {
                if (!on) {
                  settings.revokeLocationConsent();
                } else if (await _askConsent(context)) {
                  settings.giveLocationConsent();
                }
              },
            ),
            if (settings.locationConsent)
              _VisibilityTile(
                title: 'Standort sichtbar für',
                icon: Icons.visibility,
                value: settings.location,
                onChanged: (v) => settings.location = v,
              ),
            const Divider(height: 32),
            _Preview(settings: settings),
          ],
        ),
      ),
    );
  }

  Future<bool> _askConsent(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Standort teilen?'),
        content: const Text(
          'Möchtest du deinen Standort mit anderen teilen? '
          'Du kannst das jederzeit wieder ausschalten.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Zustimmen'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }
}

class _VisibilityTile extends StatelessWidget {
  const _VisibilityTile({
    required this.title,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final IconData icon;
  final Audience value;
  final ValueChanged<Audience> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon),
              const SizedBox(width: 12),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 8),
          SegmentedButton<Audience>(
            segments: [
              for (final v in Audience.values)
                ButtonSegment(value: v, label: Text(v.label)),
            ],
            selected: {value},
            onSelectionChanged: (s) => onChanged(s.first),
          ),
        ],
      ),
    );
  }
}

/// Zeigt live, was Fremde und Freunde sehen.
class _Preview extends StatelessWidget {
  const _Preview({required this.settings});

  final PrivacySettings settings;

  @override
  Widget build(BuildContext context) {
    Widget row(String who, Viewer viewer) {
      String mark(bool b) => b ? '✓' : '✗';
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          '$who:  Profil ${mark(settings.canSeeProfile(viewer))}   '
          'Touren ${mark(settings.canSeeTours(viewer))}   '
          'Standort ${mark(settings.canSeeLocation(viewer))}',
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Vorschau', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        row('Fremde', Viewer.stranger),
        row('Freunde', Viewer.friend),
      ],
    );
  }
}
