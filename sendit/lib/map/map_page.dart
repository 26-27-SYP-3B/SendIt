import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'map_points_controller.dart';
import 'models/map_point.dart';
import 'services/connectivity_service.dart';
import 'services/location_service.dart';
import 'services/point_storage.dart';
import 'services/routing_service.dart';
import '../rides/controllers/ride_recording_controller.dart';
import '../rides/services/ride_location_source.dart';
import '../rides/services/ride_storage.dart';
import '../rides/widgets/ride_recording_panel.dart';

/// Kartenansicht: OSM-Karte, eigener Standort, gespeicherte Punkte, Routen.
class MapPage extends StatefulWidget {
  const MapPage({
    super.key,
    required this.userId,
    this.locationService = const LocationService(),
    this.connectivityService,
    this.routingService,
  });

  final String userId;
  final LocationService locationService;
  final ConnectivityService? connectivityService;
  final RoutingService? routingService;

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  /// Mitte von Österreich als Startansicht.
  static const _initialCenter = LatLng(47.6, 13.8);
  static const _initialZoom = 7.0;

  final _mapController = MapController();
  late final MapPointsController _points;
  late final ConnectivityService _connectivity;
  late final RoutingService _routing;
  late final RideRecordingController _rideRecording;
  StreamSubscription<bool>? _connectivitySub;

  bool _online = true;
  bool _tileError = false;
  int _tileReloadKey = 0;
  LatLng? _myLocation;
  RouteResult? _route;
  bool _routeLoading = false;

  @override
  void initState() {
    super.initState();
    _points = MapPointsController(PointStorage(userId: widget.userId))
      ..addListener(_onPointsChanged)
      ..load();
    _connectivity = widget.connectivityService ?? ConnectivityService();
    _routing = widget.routingService ?? RoutingService();
    _rideRecording = RideRecordingController(
      locationSource: const GeolocatorRideLocationSource(),
      storage: RideStorage(userId: widget.userId),
    );

    _connectivity.isOnline().then(_setOnline);
    _connectivitySub = _connectivity.onlineChanges.listen(
      _setOnline,
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _rideRecording.dispose();
    _points
      ..removeListener(_onPointsChanged)
      ..dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _onPointsChanged() {
    if (!mounted) return;
    setState(() {
      // Punkte haben sich geändert → alte Route passt nicht mehr.
      _route = null;
    });
  }

  void _setOnline(bool online) {
    if (!mounted || online == _online) return;
    setState(() {
      _online = online;
      if (online) _reloadTiles();
    });
  }

  void _reloadTiles() {
    _tileError = false;
    _tileReloadKey++;
  }

  void _onTileError(TileImage tile, Object error, StackTrace? stackTrace) {
    if (!mounted || _tileError) return;
    // Callback kann während eines Frames kommen → nach dem Frame setzen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_tileError) setState(() => _tileError = true);
    });
  }

  void _showSnack(String text, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), action: action));
  }

  // --- Mein Standort -------------------------------------------------------

  Future<void> _goToMyLocation() async {
    final result = await widget.locationService.getCurrentLocation();
    if (!mounted) return;

    if (result.isSuccess) {
      setState(() => _myLocation = result.position);
      _mapController.move(result.position!, 15);
      return;
    }

    switch (result.failure!) {
      case LocationFailure.serviceDisabled:
        _showSnack(
          'Standortdienste sind deaktiviert.',
          action: SnackBarAction(
            label: 'Aktivieren',
            onPressed: widget.locationService.openLocationSettings,
          ),
        );
      case LocationFailure.denied:
        _showSnack(
          'Ohne Standortberechtigung kann deine Position nicht angezeigt '
          'werden. Die Karte kannst du trotzdem nutzen.',
        );
      case LocationFailure.deniedForever:
        _showSnack(
          'Standortberechtigung wurde abgelehnt. Du kannst sie in den '
          'Einstellungen erlauben.',
          action: SnackBarAction(
            label: 'Einstellungen',
            onPressed: widget.locationService.openAppSettings,
          ),
        );
      case LocationFailure.unavailable:
        _showSnack('Dein Standort konnte gerade nicht ermittelt werden.');
    }
  }

  // --- Punkte --------------------------------------------------------------

  Future<String?> _askForName({String initial = '', required String title}) {
    return showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(title: title, initial: initial),
    );
  }

  Future<void> _onLongPress(TapPosition _, LatLng position) async {
    final name = await _askForName(title: 'Punkt hinzufügen');
    if (name == null || !mounted) return;
    await _points.add(name, position);
  }

  Future<void> _onPointTap(MapPoint point) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                point.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: Text(
                '${point.latitude.toStringAsFixed(5)}, '
                '${point.longitude.toStringAsFixed(5)}',
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Umbenennen'),
              onTap: () => Navigator.of(context).pop('rename'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Löschen'),
              onTap: () => Navigator.of(context).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;

    if (action == 'rename') {
      final name = await _askForName(
        title: 'Punkt umbenennen',
        initial: point.name,
      );
      if (name != null) await _points.rename(point.id, name);
    } else if (action == 'delete') {
      await _points.remove(point.id);
    }
  }

  // --- Route ---------------------------------------------------------------

  Future<void> _createRoute() async {
    if (!_points.canCreateRoute || _routeLoading) return;
    if (!_online) {
      _showSnack('Für die Routenberechnung wird Internet benötigt.');
      return;
    }

    setState(() => _routeLoading = true);
    try {
      final route = await _routing.route(
        _points.points.map((p) => p.position).toList(),
      );
      if (!mounted) return;
      setState(() => _route = route);
      if (route.points.length >= 2) {
        _mapController.fitCamera(
          CameraFit.coordinates(
            coordinates: route.points,
            padding: const EdgeInsets.fromLTRB(48, 96, 48, 200),
          ),
        );
      }
    } on RoutingException catch (e) {
      if (mounted) _showSnack(e.message);
    } finally {
      if (mounted) setState(() => _routeLoading = false);
    }
  }

  // --- UI ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final points = _points.points;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _initialCenter,
            initialZoom: _initialZoom,
            minZoom: 3,
            maxZoom: 19,
            onLongPress: _onLongPress,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            TileLayer(
              key: ValueKey(_tileReloadKey),
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'at.sendit.app',
              maxNativeZoom: 19,
              errorTileCallback: _onTileError,
            ),
            if (_route != null)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _route!.points,
                    strokeWidth: 5,
                    color: scheme.primary,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                for (final (i, p) in points.indexed)
                  Marker(
                    point: p.position,
                    width: 140,
                    height: 64,
                    alignment: Alignment.topCenter,
                    child: _PointMarker(
                      label: '${i + 1}. ${p.name}',
                      onTap: () => _onPointTap(p),
                    ),
                  ),
                if (_myLocation != null)
                  Marker(
                    point: _myLocation!,
                    width: 24,
                    height: 24,
                    child: const _MyLocationDot(),
                  ),
              ],
            ),
            RichAttributionWidget(
              alignment: AttributionAlignment.bottomLeft,
              attributions: const [
                TextSourceAttribution('OpenStreetMap-Mitwirkende'),
              ],
            ),
          ],
        ),

        if (!_online || _tileError)
          Positioned(
            top: 8,
            left: 8,
            right: 8,
            child: _ErrorBanner(
              message: !_online
                  ? 'Keine Internetverbindung. Die Karte kann nicht geladen '
                        'werden.'
                  : 'Kartenteile konnten nicht geladen werden.',
              onRetry: () async {
                final online = await _connectivity.isOnline();
                if (!mounted) return;
                setState(() {
                  _online = online;
                  if (online) _reloadTiles();
                });
              },
            ),
          ),

        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Teil der Spalte, damit er nie die Routen-Karte überdeckt.
                Align(
                  alignment: Alignment.centerRight,
                  child: FloatingActionButton(
                    heroTag: 'my_location',
                    tooltip: 'Mein Standort',
                    onPressed: _goToMyLocation,
                    child: const Icon(Icons.my_location),
                  ),
                ),
                const SizedBox(height: 12),
                RideRecordingPanel(controller: _rideRecording),
                const SizedBox(height: 8),
                if (_route != null) ...[
                  _RouteInfoCard(
                    route: _route!,
                    onClose: () => setState(() => _route = null),
                  ),
                  const SizedBox(height: 8),
                ],
                if (_points.isLoaded && points.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: _Hint(
                      'Lange auf die Karte drücken, um einen Punkt zu setzen.',
                    ),
                  ),
                FilledButton.icon(
                  key: const Key('create_route_button'),
                  onPressed: _points.canCreateRoute && !_routeLoading
                      ? _createRoute
                      : null,
                  icon: _routeLoading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.alt_route),
                  label: Text(
                    _points.canCreateRoute
                        ? 'Route erstellen'
                        : 'Route erstellen (mind. 2 Punkte)',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.title, required this.initial});

  final String title;
  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isNotEmpty) Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'Name',
          hintText: 'z. B. Lager Linz',
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Speichern')),
      ],
    );
  }
}

class _PointMarker extends StatelessWidget {
  const _PointMarker({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(6),
              boxShadow: const [
                BoxShadow(blurRadius: 2, color: Colors.black26),
              ],
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          Icon(Icons.location_on, color: scheme.error, size: 36),
        ],
      ),
    );
  }
}

class _MyLocationDot extends StatelessWidget {
  const _MyLocationDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black38)],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.errorContainer,
      borderRadius: BorderRadius.circular(12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          children: [
            Icon(Icons.wifi_off, color: scheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Erneut')),
          ],
        ),
      ),
    );
  }
}

class _RouteInfoCard extends StatelessWidget {
  const _RouteInfoCard({required this.route, required this.onClose});

  final RouteResult route;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
        child: Row(
          children: [
            const Icon(Icons.straighten),
            const SizedBox(width: 8),
            Text(route.formattedDistance, style: text.titleMedium),
            const SizedBox(width: 24),
            const Icon(Icons.schedule),
            const SizedBox(width: 8),
            Text('ca. ${route.formattedDuration}', style: text.titleMedium),
            const Spacer(),
            IconButton(
              tooltip: 'Route ausblenden',
              onPressed: onClose,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(text, textAlign: TextAlign.center),
      ),
    );
  }
}
