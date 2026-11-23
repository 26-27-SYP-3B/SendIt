import 'package:flutter/material.dart';

import '../map/models/saved_route.dart';
import 'ride.dart';
import 'ride_panel.dart';
import 'rides_api.dart';
import 'rides_controller.dart';

Future<void> showRideDetails(
  BuildContext context, {
  required Ride ride,
  required RidesController controller,
  VoidCallback? onShowOnMap,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  backgroundColor: Theme.of(context).colorScheme.surface,
  builder: (context) => _RideDetails(
    id: ride.id,
    controller: controller,
    onShowOnMap: onShowOnMap,
  ),
);

class _RideDetails extends StatefulWidget {
  const _RideDetails({
    required this.id,
    required this.controller,
    required this.onShowOnMap,
  });

  final String id;
  final RidesController controller;
  final VoidCallback? onShowOnMap;

  @override
  State<_RideDetails> createState() => _RideDetailsState();
}

class _RideDetailsState extends State<_RideDetails> {
  bool _joining = false;
  String? _error;

  Future<void> _join() async {
    if (_joining) return;
    setState(() {
      _joining = true;
      _error = null;
    });
    try {
      await widget.controller.join(widget.id);
    } catch (error) {
      if (mounted) {
        _error = error is RidesException
            ? error.message
            : 'Die Anmeldung konnte nicht gespeichert werden.';
      }
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final theme = Theme.of(context);
      final ride = widget.controller.rides
          .where((ride) => ride.id == widget.id)
          .firstOrNull;
      final route = ride?.route;
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (ride == null)
                const Text('Diese Ausfahrt ist nicht verfügbar.')
              else ...[
                Text(
                  ride.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                RidePanel(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.schedule),
                      title: Text(formatDeparture(ride.departure)),
                    ),
                    ListTile(
                      leading: const Icon(Icons.location_on_outlined),
                      title: const Text('Treffpunkt'),
                      subtitle: Text(formatCoordinates(ride.meetingPoint)),
                    ),
                    if (route != null)
                      ListTile(
                        leading: const Icon(Icons.alt_route),
                        title: Text(route.name),
                        subtitle: Text(
                          '${route.result.formattedDistance} · ca. ${route.result.formattedDuration}',
                        ),
                      ),
                    ListTile(
                      leading: const Icon(Icons.groups_outlined),
                      title: Text(ride.audienceLabel),
                      subtitle: Text('${ride.participantCount} angemeldet'),
                    ),
                  ],
                ),
                if (_error case final error?)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      error,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                if (!ride.isOwner || widget.onShowOnMap != null)
                  const SizedBox(height: 16),
                if (ride.joined)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Angemeldet',
                            style: theme.textTheme.labelLarge,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (!ride.isOwner)
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed:
                        _joining || !ride.departure.isAfter(DateTime.now())
                        ? null
                        : _join,
                    child: Text(_joining ? 'Anmeldung läuft …' : 'Mitfahren'),
                  ),
                if (!ride.isOwner && widget.onShowOnMap != null)
                  const SizedBox(height: 8),
                if (widget.onShowOnMap case final onShowOnMap?)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      onShowOnMap();
                    },
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Auf der Karte zeigen'),
                  ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
