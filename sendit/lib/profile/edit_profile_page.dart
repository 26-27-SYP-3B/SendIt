import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'driver_profile.dart';

/// Saves a profile and reports whether saving succeeded.
typedef SaveDriverProfile = Future<bool> Function(DriverProfile profile);

/// Form for editing the driver profile. Pops with the saved profile, or with
/// `null` when editing is cancelled. Nothing is saved on cancel.
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({
    super.key,
    required this.initial,
    required this.onSave,
  });

  final DriverProfile initial;
  final SaveDriverProfile onSave;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final _name = TextEditingController(text: widget.initial.name);
  late final _location = TextEditingController(text: widget.initial.location);
  late final _bio = TextEditingController(text: widget.initial.bio);
  bool _saving = false;
  bool _failed = false;

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    _bio.dispose();
    super.dispose();
  }

  void _cancel() => Navigator.of(context).pop();

  Future<void> _save() async {
    final profile = DriverProfile(
      name: _name.text,
      location: _location.text,
      bio: _bio.text,
    ).trimmed();
    setState(() {
      _saving = true;
      _failed = false;
    });
    final saved = await widget.onSave(profile);
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop(profile);
    } else {
      setState(() {
        _saving = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Profil bearbeiten'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Abbrechen',
            onPressed: _saving ? null : _cancel,
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                key: const Key('profile-name'),
                controller: _name,
                enabled: !_saving,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('profile-location'),
                controller: _location,
                enabled: !_saving,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Wohnort',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('profile-bio'),
                controller: _bio,
                enabled: !_saving,
                minLines: 3,
                maxLines: 6,
                maxLength: DriverProfile.maxBioLength,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Kurzbeschreibung',
                  hintText: 'Erzähl anderen kurz, wer du bist.',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              if (_failed) ...[
                const SizedBox(height: 8),
                Text(
                  'Das Profil konnte nicht gespeichert werden. '
                  'Bitte versuche es erneut.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : _cancel,
                      child: const Text('Abbrechen'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Speichern'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
