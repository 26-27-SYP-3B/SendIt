import 'package:flutter/material.dart';

import '../map/map_page.dart';
import '../map/services/route_storage.dart';
import '../map/services/routing_service.dart';
import '../rides/ride.dart';
import '../rides/ride_details.dart';
import '../rides/rides_api.dart';
import '../rides/rides_controller.dart';
import '../rides/rides_page.dart';

enum _Tab { start, rides, map }

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.start,
    required this.userId,
    required this.sessionToken,
    this.ridesApiUrl = const String.fromEnvironment('SENDIT_API_URL'),
  });

  final Widget start;
  final String userId;
  final Future<String> Function() sessionToken;
  final String ridesApiUrl;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  _Tab _tab = _Tab.start;
  String? _focusedRideId;
  int _focusRequest = 0;

  late final RouteStorage _routes = RouteStorage(userId: widget.userId);
  final _routing = RoutingService();
  late final RidesController _rides;
  AppLifecycleListener? _lifecycle;

  @override
  void initState() {
    super.initState();
    final api = RidesApi(
      baseUrl: widget.ridesApiUrl,
      sessionToken: widget.sessionToken,
    );
    _rides = RidesController(api);
    if (api.isConfigured) {
      _rides.refresh();
      _lifecycle = AppLifecycleListener(onResume: _rides.refresh);
    }
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    _rides.dispose();
    _routing.close();
    super.dispose();
  }

  void _selectTab(_Tab tab) {
    setState(() => _tab = tab);
    if (tab != _Tab.start && _rides.api.isConfigured && !_rides.loading) {
      _rides.refresh();
    }
  }

  void _focusRide(Ride ride, {bool showMap = true}) {
    setState(() {
      if (showMap) _tab = _Tab.map;
      _focusedRideId = ride.id;
      _focusRequest++;
    });
  }

  Future<void> _refreshMapRides() async {
    if (_rides.loading) return;
    await _rides.refresh();
    final error = _rides.error;
    if (!mounted || error == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  Future<void> _selectMapRide(List<Ride> rides) async {
    final Ride? selected;
    if (rides.length == 1) {
      selected = rides.single;
    } else {
      final ids = rides.map((ride) => ride.id).toSet();
      selected = await showModalBottomSheet<Ride>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (context) => FractionallySizedBox(
          heightFactor: .6,
          child: SafeArea(
            child: ListenableBuilder(
              listenable: _rides,
              builder: (context, _) => ListView(
                children: [
                  const ListTile(
                    title: Text('Ausfahrten an diesem Treffpunkt'),
                  ),
                  for (final ride in _rides.rides)
                    if (ids.contains(ride.id))
                      ListTile(
                        title: Text(ride.title),
                        subtitle: Text(formatDeparture(ride.departure)),
                        onTap: () => Navigator.of(context).pop(ride),
                      ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    if (!mounted || selected == null) return;
    _focusRide(selected);
    await showRideDetails(context, ride: selected, controller: _rides);
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: IndexedStack(
          index: _tab.index,
          children: [
            widget.start,
            RidesPage(
              controller: _rides,
              routeStorage: _routes,
              routing: _routing,
              onRideCreated: (ride) => _focusRide(ride, showMap: false),
              onRideTap: (ride) => showRideDetails(
                context,
                ride: ride,
                controller: _rides,
                onShowOnMap: () => _focusRide(ride),
              ),
            ),
            ListenableBuilder(
              listenable: _rides,
              builder: (context, _) => MapPage(
                userId: widget.userId,
                routeStorage: _routes,
                routingService: _routing,
                rides: _rides.rides,
                onRidesAtPoint: _selectMapRide,
                onRefreshRides: _rides.api.isConfigured
                    ? _refreshMapRides
                    : null,
                focusedRideId: _focusedRideId,
                focusRequest: _focusRequest,
              ),
            ),
          ],
        ),
      ),
      NavigationBar(
        selectedIndex: _tab.index,
        onDestinationSelected: (index) => _selectTab(_Tab.values[index]),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Start',
          ),
          NavigationDestination(
            icon: Icon(Icons.two_wheeler_outlined),
            selectedIcon: Icon(Icons.two_wheeler),
            label: 'Ausfahrten',
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
