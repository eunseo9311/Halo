import 'package:flutter/material.dart';
import 'package:halo/features/route_map/domain/map_geometry.dart';
import 'package:halo/features/route_map/presentation/platform_map/platform_route_map.dart';
import 'package:halo/features/search/domain/route_candidate.dart';

const _routeCenter = MapCoordinate(34.0522, -118.2437);

typedef NavigationMapBuilder =
    Widget Function({
      required MapCoordinate center,
      required MapGeometry geometry,
      required int recenterGeneration,
    });

class DemoNavigationScreen extends StatefulWidget {
  const DemoNavigationScreen({
    required this.route,
    required this.onEnd,
    this.mapBuilder,
    super.key,
  });

  final RouteCandidate route;
  final VoidCallback onEnd;
  final NavigationMapBuilder? mapBuilder;

  @override
  State<DemoNavigationScreen> createState() => _DemoNavigationScreenState();
}

class _DemoNavigationScreenState extends State<DemoNavigationScreen> {
  var _recenterGeneration = 0;

  static List<MapCoordinate> _routePointsFor(String routeId) =>
      switch (routeId) {
        'shaded' => const [
          MapCoordinate(34.0498, -118.2470),
          MapCoordinate(34.0507, -118.2448),
          MapCoordinate(34.0529, -118.2430),
          MapCoordinate(34.0545, -118.2418),
        ],
        'quiet' || 'shortest' => const [
          MapCoordinate(34.0498, -118.2470),
          MapCoordinate(34.0515, -118.2461),
          MapCoordinate(34.0537, -118.2440),
          MapCoordinate(34.0545, -118.2418),
        ],
        _ => const [
          MapCoordinate(34.0498, -118.2470),
          MapCoordinate(34.0512, -118.2454),
          MapCoordinate(34.0527, -118.2437),
          MapCoordinate(34.0545, -118.2418),
        ],
      };

  static MapGeometry _geometryFor(RouteCandidate route) {
    final routePoints = _routePointsFor(route.id);
    return MapGeometry(
      polylines: [
        MapPolyline(
          id: 'navigation-green',
          points: routePoints.sublist(0, 2),
          colorValue: greenWsiColor,
          strokeWidth: wsiStrokeWidth,
          zIndex: 1,
        ),
        MapPolyline(
          id: 'navigation-yellow',
          points: routePoints.sublist(1, 3),
          colorValue: yellowWsiColor,
          strokeWidth: wsiStrokeWidth,
          zIndex: 1,
        ),
        MapPolyline(
          id: 'navigation-red',
          points: routePoints.sublist(2, 4),
          colorValue: redWsiColor,
          strokeWidth: wsiStrokeWidth,
          zIndex: 1,
        ),
      ],
      markers: [
        MapMarker(
          id: 'navigation-origin',
          position: routePoints.first,
          kind: MapMarkerKind.origin,
        ),
        MapMarker(
          id: 'navigation-destination',
          position: routePoints.last,
          kind: MapMarkerKind.destination,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final mapBuilder = widget.mapBuilder ?? _buildPlatformMap;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          mapBuilder(
            center: _routeCenter,
            geometry: _geometryFor(widget.route),
            recenterGeneration: _recenterGeneration,
          ),
          SafeArea(
            minimum: const EdgeInsets.all(16),
            child: Column(
              children: [
                _InstructionCard(route: widget.route),
                const Spacer(),
                Align(
                  alignment: Alignment.centerRight,
                  child: _RecenterButton(
                    onPressed: () => setState(() => _recenterGeneration++),
                  ),
                ),
                const SizedBox(height: 12),
                _NavigationStatusCard(route: widget.route, onEnd: widget.onEnd),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildPlatformMap({
  required MapCoordinate center,
  required MapGeometry geometry,
  required int recenterGeneration,
}) => PlatformRouteMap(
  center: center,
  geometry: geometry,
  showUserLocation: false,
  recenterGeneration: recenterGeneration,
);

class _InstructionCard extends StatelessWidget {
  const _InstructionCard({required this.route});

  final RouteCandidate route;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    elevation: 4,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.straight, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Continue straight',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  'Follow ${route.name.toLowerCase()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _RecenterButton extends StatelessWidget {
  const _RecenterButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
    elevation: 3,
    color: Theme.of(context).colorScheme.surface,
    shape: const CircleBorder(),
    child: IconButton(
      key: const Key('navigation-recenter-button'),
      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
      tooltip: 'Re-center',
      onPressed: onPressed,
      icon: const Icon(Icons.my_location),
    ),
  );
}

class _NavigationStatusCard extends StatelessWidget {
  const _NavigationStatusCard({required this.route, required this.onEnd});

  final RouteCandidate route;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    elevation: 5,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.trip_origin, color: Color(0xFF3F91DF), size: 18),
              const SizedBox(width: 8),
              const Expanded(child: Text('Current location')),
              Text(
                '${route.durationMinutes} min',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(height: 18, child: VerticalDivider(width: 2)),
            ),
          ),
          Row(
            children: [
              const Icon(Icons.location_on, color: Color(0xFFE83E62), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Destination · ${route.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text('${route.distanceMiles.toStringAsFixed(2)} mi'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              key: const Key('end-navigation-button'),
              onPressed: onEnd,
              icon: const Icon(Icons.close),
              label: const Text('End navigation'),
            ),
          ),
        ],
      ),
    ),
  );
}
