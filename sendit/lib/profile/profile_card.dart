import 'package:flutter/material.dart';

import 'driver_profile.dart';
import 'edit_profile_page.dart';

/// Shows the driver profile with a button that opens [EditProfilePage].
class ProfileCard extends StatelessWidget {
  const ProfileCard({super.key, required this.profile, required this.onSave});

  final DriverProfile profile;
  final SaveDriverProfile onSave;

  Future<void> _edit(BuildContext context) {
    return Navigator.of(context).push<DriverProfile>(
      MaterialPageRoute(
        builder: (_) => EditProfilePage(initial: profile, onSave: onSave),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mein Profil', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            _ProfileField(label: 'Name', value: profile.name),
            _ProfileField(label: 'Wohnort', value: profile.location),
            _ProfileField(label: 'Kurzbeschreibung', value: profile.bio),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: () => _edit(context),
                icon: const Icon(Icons.edit),
                label: const Text('Profil bearbeiten'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEmpty = value.isEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(height: 2),
          Text(
            isEmpty ? 'Noch nicht angegeben' : value,
            style: isEmpty
                ? theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  )
                : theme.textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}
