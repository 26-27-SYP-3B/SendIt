import 'package:flutter/material.dart';

import '../map/services/route_storage.dart';
import '../map/services/routing_service.dart';
import 'create_ride_page.dart';
import 'ride.dart';
import 'ride_panel.dart';
import 'ride_social_page.dart';
import 'rides_controller.dart';

class RidesPage extends StatelessWidget {
  const RidesPage({
    super.key,
    required this.controller,
    required this.routeStorage,
    required this.routing,
    required this.onRideTap,
    required this.onRideCreated,
  });

  final RidesController controller;
  final RouteStorage routeStorage;
  final RoutingService routing;
  final ValueChanged<Ride> onRideTap;
  final ValueChanged<Ride> onRideCreated;

  Future<void> _create(BuildContext context) async {
    final ride = await Navigator.of(context).push<Ride>(
      MaterialPageRoute(
        builder: (_) => CreateRidePage(
          rides: controller,
          routeStorage: routeStorage,
          routing: routing,
        ),
      ),
    );
    if (context.mounted && ride != null) {
      onRideCreated(ride);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Ausfahrt gespeichert.')));
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final theme = Theme.of(context);
      final configured = controller.api.isConfigured;
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Ausfahrten',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Freunde und Gruppen',
                      icon: const Icon(Icons.group_outlined),
                      onPressed: !configured
                          ? null
                          : () async {
                              await Navigator.of(context).push<void>(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      RideSocialPage(api: controller.api),
                                ),
                              );
                              await controller.refresh();
                            },
                    ),
                    IconButton(
                      tooltip: 'Ausfahrten aktualisieren',
                      icon: const Icon(Icons.refresh),
                      onPressed: configured && !controller.loading
                          ? controller.refresh
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                  onPressed: configured ? () => _create(context) : null,
                  icon: const Icon(Icons.add),
                  label: const Text('Ausfahrt erstellen'),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 2,
            child: controller.loading ? const LinearProgressIndicator() : null,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: controller.refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                children: [
                  if (!configured)
                    const ListTile(
                      title: Text(
                        'Der Ausfahrten-Dienst ist noch nicht eingerichtet.',
                      ),
                    )
                  else if (controller.error case final error?)
                    ListTile(title: Text(error))
                  else if (controller.rides.isEmpty && !controller.loading)
                    const RidePanel(
                      children: [
                        ListTile(
                          leading: Icon(Icons.event_available_outlined),
                          title: Text('Keine bevorstehenden Ausfahrten'),
                        ),
                      ],
                    ),
                  if (controller.rides.isNotEmpty)
                    RidePanel(
                      children: [
                        for (final ride in controller.rides)
                          _RideRow(ride: ride, onTap: () => onRideTap(ride)),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _RideRow extends StatelessWidget {
  const _RideRow({required this.ride, required this.onTap});

  final Ride ride;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return ListTile(
      contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 10, 12, 10),
      title: Text(
        ride.title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(formatDeparture(ride.departure)),
            const SizedBox(height: 4),
            Text(
              '${ride.audienceLabel}${ride.joined ? ' · Angemeldet' : ''}',
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ],
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: muted, size: 20),
      onTap: onTap,
    );
  }
}
