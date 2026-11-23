import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ride.dart';
import 'rides_api.dart';

class RideSocialPage extends StatefulWidget {
  const RideSocialPage({super.key, required this.api});

  final RidesApi api;

  @override
  State<RideSocialPage> createState() => _RideSocialPageState();
}

class _RideSocialPageState extends State<RideSocialPage> {
  Future<(List<RideFriend>, List<RideGroup>)>? _contacts;
  bool _busy = false;

  Future<(List<RideFriend>, List<RideGroup>)> _load() =>
      (widget.api.friends(), widget.api.groups()).wait;

  void _refresh() => setState(() => _contacts = null);

  void _message(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  Future<void> _run(Future<void> Function() action) async {
    if (!mounted || _busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        _message(
          error is RidesException
              ? error.message
              : 'Die Aktion konnte nicht abgeschlossen werden.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _enterCode() async {
    final code = await _prompt('Einladung annehmen', 'Einladungscode', 64);
    if (code == null) return;
    await _run(() async {
      await widget.api.redeemInvitation(code);
      if (!mounted) return;
      _refresh();
      _message('Einladung angenommen.');
    });
  }

  Future<void> _createGroup() async {
    final name = await _prompt('Gruppe erstellen', 'Gruppenname', 60);
    if (name == null) return;
    await _run(() async {
      await widget.api.createGroup(name);
      if (mounted) _refresh();
    });
  }

  Future<void> _invite([RideGroup? group]) => _run(() async {
    final code = await widget.api.createInvitation(groupId: group?.id);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          group == null ? 'Freund einladen' : 'Zu ${group.name} einladen',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Der Code ist 24 Stunden gültig und einmal einlösbar.'),
            const SizedBox(height: 16),
            SelectableText(code),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (context.mounted) Navigator.of(context).pop();
              if (mounted) _message('Einladungscode kopiert.');
            },
            child: const Text('Code kopieren'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
  });

  Future<void> _remove(String title, Future<void> Function() action) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Bestätigen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() async {
      await action();
      if (mounted) _refresh();
    });
  }

  Future<String?> _prompt(String title, String label, int maxLength) =>
      showDialog<String>(
        context: context,
        builder: (context) {
          String value = '';
          return StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: Text(title),
              content: TextField(
                autofocus: true,
                maxLength: maxLength,
                decoration: InputDecoration(labelText: label),
                onChanged: (text) => setDialogState(() => value = text.trim()),
                onSubmitted: (_) {
                  if (value.isNotEmpty) Navigator.of(context).pop(value);
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Abbrechen'),
                ),
                FilledButton(
                  onPressed: value.isEmpty
                      ? null
                      : () => Navigator.of(context).pop(value),
                  child: const Text('Weiter'),
                ),
              ],
            ),
          );
        },
      );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Freunde und Gruppen')),
    body: SafeArea(
      child: FutureBuilder<(List<RideFriend>, List<RideGroup>)>(
        future: _contacts ??= _load(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Freunde und Gruppen konnten nicht geladen werden.',
                    ),
                    TextButton(
                      onPressed: _refresh,
                      child: const Text('Erneut versuchen'),
                    ),
                  ],
                ),
              ),
            );
          }
          final (friends, groups) = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              FilledButton.icon(
                onPressed: _busy ? null : _enterCode,
                icon: const Icon(Icons.vpn_key_outlined),
                label: const Text('Einladungscode eingeben'),
              ),
              const SizedBox(height: 20),
              Text('Freunde', style: Theme.of(context).textTheme.titleLarge),
              if (friends.isEmpty)
                const Text('Du hast noch keine Freunde hinzugefügt.'),
              for (final friend in friends)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_outline),
                  title: Text(friend.name),
                  trailing: IconButton(
                    tooltip: 'Freundschaft entfernen',
                    onPressed: _busy
                        ? null
                        : () => _remove(
                            'Freundschaft mit ${friend.name} entfernen?',
                            () => widget.api.removeFriend(friend.id),
                          ),
                    icon: const Icon(Icons.person_remove_outlined),
                  ),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _invite(),
                icon: const Icon(Icons.person_add_alt),
                label: const Text('Freund einladen'),
              ),
              const SizedBox(height: 24),
              Text('Gruppen', style: Theme.of(context).textTheme.titleLarge),
              if (groups.isEmpty) const Text('Du bist noch in keiner Gruppe.'),
              for (final group in groups)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.group_outlined),
                  title: Text(group.name),
                  trailing: group.isOwner
                      ? IconButton(
                          tooltip: 'Mitglied einladen',
                          onPressed: _busy ? null : () => _invite(group),
                          icon: const Icon(Icons.person_add_alt),
                        )
                      : IconButton(
                          tooltip: 'Gruppe verlassen',
                          onPressed: _busy
                              ? null
                              : () => _remove(
                                  '${group.name} verlassen?',
                                  () => widget.api.leaveGroup(group.id),
                                ),
                          icon: const Icon(Icons.logout),
                        ),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busy ? null : _createGroup,
                icon: const Icon(Icons.group_add_outlined),
                label: const Text('Gruppe erstellen'),
              ),
              if (_busy) const LinearProgressIndicator(),
            ],
          );
        },
      ),
    ),
  );
}
