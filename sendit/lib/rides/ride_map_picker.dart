import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../map/models/saved_route.dart';
import '../map/services/routing_service.dart';
import '../map/widgets/map_tiles.dart';

class MeetingPointPage extends StatefulWidget {
  const MeetingPointPage({super.key, this.initial});

  final LatLng? initial;

  @override
  State<MeetingPointPage> createState() => _MeetingPointPageState();
}

class _MeetingPointPageState extends State<MeetingPointPage> {
  late LatLng? _selected = widget.initial;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Treffpunkt wählen')),
    body: _PickerMap(
      center: widget.initial,
      meetingPoint: _selected,
      onTap: (position) => setState(() => _selected = position),
    ),
    bottomNavigationBar: SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _selected == null
                ? 'Tippe auf die Karte, um den Treffpunkt zu setzen.'
                : formatCoordinates(_selected!),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _selected == null
                ? null
                : () => Navigator.of(context).pop(_selected),
            child: const Text('Treffpunkt übernehmen'),
          ),
        ],
      ),
    ),
  );
}

class RoutePlannerPage extends StatefulWidget {
  const RoutePlannerPage({super.key, this.meetingPoint, required this.routing});

  final LatLng? meetingPoint;
  final RoutingService routing;

  @override
  State<RoutePlannerPage> createState() => _RoutePlannerPageState();
}

class _RoutePlannerPageState extends State<RoutePlannerPage> {
  final _mapController = MapController();
  late final List<LatLng> _waypoints = [?widget.meetingPoint];
  RouteResult? _route;
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _updatePoints(VoidCallback change) {
    setState(() {
      change();
      _route = null;
      _error = null;
    });
  }

  Future<void> _calculate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final route = await widget.routing.route(List.of(_waypoints));
      if (!mounted) return;
      if (route.points.length < 2 || route.points.length > maxRideRoutePoints) {
        throw const RoutingException(
          'Die Route ist zu groß oder ungültig. Ändere die Wegpunkte.',
        );
      }
      setState(() => _route = route);
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: route.points,
          padding: const EdgeInsets.all(40),
          maxZoom: 16,
        ),
      );
    } on RoutingException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Route planen'),
      actions: [
        IconButton(
          icon: const Icon(Icons.undo),
          tooltip: 'Letzten Wegpunkt entfernen',
          onPressed: _loading || _waypoints.isEmpty
              ? null
              : () => _updatePoints(_waypoints.removeLast),
        ),
      ],
    ),
    body: _PickerMap(
      center: widget.meetingPoint,
      controller: _mapController,
      waypoints: _waypoints,
      route: _route,
      onTap: _loading || _waypoints.length >= 12
          ? null
          : (position) => _updatePoints(() => _waypoints.add(position)),
    ),
    bottomNavigationBar: SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            )
          else if (_route case final route?)
            Text('${route.formattedDistance} · ca. ${route.formattedDuration}')
          else
            Text(
              _waypoints.length == 12 ? '12 Wegpunkte erreicht.' : 'Tippe auf die Karte, um Wegpunkte in Fahrreihenfolge zu setzen.',
            ),
          const SizedBox(height: 8),
          if (_route case final route?)
            FilledButton(
              onPressed: () =>
                  Navigator.of(context)
                      .pop(SavedRoute(name: 'Geplante Route', result: route)),
              child: const Text('Route übernehmen'),
            )
          else
            FilledButton(
              onPressed: _loading || _waypoints.length < 2 ? null : _calculate,
              child: Text(
                _loading ? 'Route wird berechnet …' : 'Route berechnen',
              ),
            ),
        ],
      ),
    ),
  );
}

class _PickerMap extends StatefulWidget {
  const _PickerMap({
    this.center,
    this.controller,
    this.meetingPoint,
    this.waypoints = const [],
    this.route,
    this.onTap,
  });

  final LatLng? center;
  final MapController? controller;
  final LatLng? meetingPoint;
  final List<LatLng> waypoints;
  final RouteResult? route;
  final ValueChanged<LatLng>? onTap;

  @override
  State<_PickerMap> createState() => _PickerMapState();
}

class _PickerMapState extends State<_PickerMap> {
  int _tileVersion = 0;
  bool _tileError = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        FlutterMap(
          mapController: widget.controller,
          options: MapOptions(
            initialCenter: widget.center ?? mapInitialCenter,
            initialZoom: widget.center == null ? 7 : 14,
            minZoom: 3,
            maxZoom: 19,
            onTap: (_, position) => widget.onTap?.call(position),
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            openStreetMapTiles(
              key: ValueKey(_tileVersion),
              onError: (_, _, _) {
                if (_tileError || !mounted) return;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && !_tileError) setState(() => _tileError = true);
                });
              },
            ),
            if (widget.route case final route?)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: route.points,
                    strokeWidth: 5,
                    color: scheme.primary,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                if (widget.meetingPoint case final position?)
                  Marker(
                    point: position,
                    alignment: Alignment.topCenter,
                    width: 34,
                    height: 34,
                    child: Icon(
                      Icons.location_on,
                      size: 34,
                      color: scheme.error,
                    ),
                  ),
                for (final (i, point) in widget.waypoints.indexed)
                  Marker(
                    point: point,
                    width: 30,
                    height: 30,
                    child: CircleAvatar(
                      backgroundColor: scheme.primary,
                      foregroundColor: scheme.onPrimary,
                      child: Text('${i + 1}'),
                    ),
                  ),
              ],
            ),
            openStreetMapAttribution(),
          ],
        ),
        if (_tileError)
          Align(
            alignment: Alignment.topCenter,
            child: Card(
              child: ListTile(
                title: const Text('Kartenteile konnten nicht geladen werden.'),
                trailing: TextButton(
                  onPressed: () => setState(() {
                    _tileVersion++;
                    _tileError = false;
                  }),
                  child: const Text('Erneut'),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
