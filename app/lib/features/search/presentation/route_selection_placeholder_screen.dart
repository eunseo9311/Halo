import 'package:flutter/material.dart';
import 'package:halo/features/route_map/domain/map_geometry.dart';
import 'package:halo/features/route_map/presentation/platform_map/platform_route_map.dart';
import 'package:halo/features/search/domain/recent_search.dart';
import 'package:halo/features/search/domain/route_candidate.dart';

typedef RouteSelectionMapBuilder =
    Widget Function(BuildContext context, RouteCandidate selectedRoute);

class RouteSelectionPlaceholderScreen extends StatefulWidget {
  const RouteSelectionPlaceholderScreen({
    required this.destination,
    this.mapBuilder,
    this.onBack,
    this.onStartNavigation,
    super.key,
  });

  final RecentSearch destination;
  final RouteSelectionMapBuilder? mapBuilder;
  final VoidCallback? onBack;
  final ValueChanged<RouteCandidate>? onStartNavigation;

  @override
  State<RouteSelectionPlaceholderScreen> createState() =>
      _RouteSelectionPlaceholderScreenState();
}

class _RouteSelectionPlaceholderScreenState
    extends State<RouteSelectionPlaceholderScreen> {
  static const _origin = MapCoordinate(34.02240, -118.28510);
  static const _destination = MapCoordinate(34.02515, -118.28405);
  // Google Maps centers against the full platform view, including the area
  // covered by the bottom sheet. Shift the camera target south so the USC
  // route remains centered in the visible map region above the sheet.
  static const _mapCenter = MapCoordinate(34.00985, -118.28455);

  var _preference = RoutePreference.environment;
  RouteCandidate _selected = mockEnvironmentRoutes.first;
  late String _originLabel;
  late String _destinationLabel;

  @override
  void initState() {
    super.initState();
    _originLabel = 'Current location';
    _destinationLabel = widget.destination.title;
  }

  List<RouteCandidate> get _routes => _preference == RoutePreference.environment
      ? mockEnvironmentRoutes
      : mockShortestRoutes;

  void _setPreference(RoutePreference value) {
    setState(() {
      _preference = value;
      _selected = _routes.first;
    });
  }

  Future<void> _editLocation({
    required bool origin,
    required String currentValue,
  }) async {
    var draft = currentValue;
    final updated = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              origin ? 'Change starting point' : 'Change destination',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: Key(origin ? 'origin-edit-field' : 'destination-edit-field'),
              initialValue: draft,
              autofocus: true,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: origin ? 'Starting point' : 'Destination',
                prefixIcon: Icon(
                  origin ? Icons.my_location : Icons.location_on_outlined,
                ),
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) => draft = value,
              onFieldSubmitted: (value) {
                final label = value.trim();
                if (label.isNotEmpty) Navigator.pop(context, label);
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: FilledButton(
                key: Key(
                  origin ? 'save-origin-button' : 'save-destination-button',
                ),
                onPressed: () {
                  final label = draft.trim();
                  if (label.isNotEmpty) Navigator.pop(context, label);
                },
                child: const Text('Apply'),
              ),
            ),
          ],
        ),
      ),
    );
    if (!mounted || updated == null) return;
    setState(() {
      if (origin) {
        _originLabel = updated;
      } else {
        _destinationLabel = updated;
      }
    });
  }

  Widget _buildDefaultMap(BuildContext context, RouteCandidate selectedRoute) {
    final routes = _preference == RoutePreference.environment
        ? mockEnvironmentRoutes
        : mockShortestRoutes;
    final selectedLast = [
      ...routes.where((route) => route.id != selectedRoute.id),
      selectedRoute,
    ];
    return PlatformRouteMap(
      center: _mapCenter,
      geometry: const MapGeometryBuilder().build(
        segments: const [],
        routes: [
          for (final route in selectedLast)
            RouteOverlay(
              id: route.id,
              points: _pointsForRoute(route.id),
              colorValue: _routeColor(
                route,
                selected: route.id == selectedRoute.id,
              ),
              strokeWidth: wsiStrokeWidth,
              zIndex: route.id == selectedRoute.id ? 1 : 0,
            ),
        ],
        markers: const [
          MapMarker(
            id: 'route-origin',
            position: _origin,
            kind: MapMarkerKind.origin,
          ),
          MapMarker(
            id: 'route-destination',
            position: _destination,
            kind: MapMarkerKind.destination,
          ),
        ],
      ),
      showUserLocation: false,
      recenterGeneration: 0,
    );
  }

  static List<MapCoordinate> _pointsForRoute(String id) => switch (id) {
    'balanced' => const [
      _origin,
      MapCoordinate(34.02305, -118.28510),
      MapCoordinate(34.02410, -118.28490),
      _destination,
    ],
    'shaded' => const [
      _origin,
      MapCoordinate(34.02325, -118.28430),
      MapCoordinate(34.02445, -118.28380),
      _destination,
    ],
    _ => const [
      _origin,
      MapCoordinate(34.02240, -118.28435),
      MapCoordinate(34.02340, -118.28385),
      _destination,
    ],
  };

  static int _routeColor(RouteCandidate route, {required bool selected}) {
    final color = switch (route.wsi) {
      >= 0.7 => greenWsiColor,
      >= 0.5 => yellowWsiColor,
      _ => redWsiColor,
    };
    return selected ? color : (color & 0x00FFFFFF) | 0x59000000;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      children: [
        Positioned.fill(
          child:
              widget.mapBuilder?.call(context, _selected) ??
              _buildDefaultMap(context, _selected),
        ),
        SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MapNavigationButton(
                key: const Key('route-back-button'),
                icon: Icons.arrow_back_ios_new_rounded,
                tooltip: 'Back to search',
                onPressed: widget.onBack,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _LocationCard(
                  originLabel: _originLabel,
                  destinationLabel: _destinationLabel,
                  onEditOrigin: () =>
                      _editLocation(origin: true, currentValue: _originLabel),
                  onEditDestination: () => _editLocation(
                    origin: false,
                    currentValue: _destinationLabel,
                  ),
                ),
              ),
            ],
          ),
        ),
        DraggableScrollableSheet(
          key: const Key('route-bottom-sheet'),
          initialChildSize: 0.46,
          minChildSize: 0.43,
          maxChildSize: 0.88,
          builder: (context, controller) => Material(
            color: Colors.white,
            elevation: 12,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4D9D7),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                _PreferenceToggle(
                  preference: _preference,
                  onChanged: _setPreference,
                ),
                const SizedBox(height: 10),
                for (final route in _routes)
                  _RouteCard(
                    route: route,
                    selected: route.id == _selected.id,
                    onTap: () => setState(() => _selected = route),
                  ),
                const SizedBox(height: 2),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    key: const Key('start-route-button'),
                    onPressed: () => widget.onStartNavigation?.call(_selected),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0F7C66),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.navigation_outlined, size: 25),
                          SizedBox(width: 10),
                          Text(
                            'Start navigation',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _MapNavigationButton extends StatelessWidget {
  const _MapNavigationButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: SizedBox.square(
        dimension: 48,
        child: Center(
          child: Material(
            color: Colors.white,
            elevation: 4,
            shape: const CircleBorder(),
            child: SizedBox.square(
              dimension: 40,
              child: Icon(icon, size: 20, color: const Color(0xFF0F7C66)),
            ),
          ),
        ),
      ),
    ),
  );
}

class _PreferenceToggle extends StatelessWidget {
  const _PreferenceToggle({required this.preference, required this.onChanged});

  final RoutePreference preference;
  final ValueChanged<RoutePreference> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    height: 48,
    padding: const EdgeInsets.symmetric(horizontal: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFF0F0F2),
      borderRadius: BorderRadius.circular(22),
    ),
    child: Row(
      children: [
        _PreferenceOption(
          key: const Key('environment-score-toggle'),
          label: 'Environment score',
          selected: preference == RoutePreference.environment,
          onTap: () => onChanged(RoutePreference.environment),
        ),
        _PreferenceOption(
          key: const Key('shortest-distance-toggle'),
          label: 'Shortest distance',
          selected: preference == RoutePreference.shortest,
          onTap: () => onChanged(RoutePreference.shortest),
        ),
      ],
    ),
  );
}

class _PreferenceOption extends StatelessWidget {
  const _PreferenceOption({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0F7C66) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF68686F),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    ),
  );
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.originLabel,
    required this.destinationLabel,
    required this.onEditOrigin,
    required this.onEditDestination,
  });

  final String originLabel;
  final String destinationLabel;
  final VoidCallback onEditOrigin;
  final VoidCallback onEditDestination;

  @override
  Widget build(BuildContext context) => Material(
    key: const Key('route-location-card'),
    color: Colors.white,
    elevation: 4,
    borderRadius: BorderRadius.circular(18),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LocationRow(
            key: const Key('edit-origin-button'),
            icon: Icons.my_location,
            label: originLabel,
            onTap: onEditOrigin,
          ),
          const Divider(height: 8),
          _LocationRow(
            key: const Key('edit-destination-button'),
            icon: Icons.location_on,
            label: destinationLabel,
            onTap: onEditDestination,
          ),
        ],
      ),
    ),
  );
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: SizedBox(
      height: 32,
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF0F7C66)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF66736F)),
        ],
      ),
    ),
  );
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.route,
    required this.selected,
    required this.onTap,
  });

  static const factorLabels = {
    'low_light': 'Low lighting',
    'outage_reported': 'Streetlight outage reported',
    'low_activity': 'Low-activity area',
    'no_safezone': 'No nearby safety facility',
  };

  final RouteCandidate route;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final conditions = route.factors.keys
        .map((code) => factorLabels[code])
        .whereType<String>()
        .toList();
    final rankColor = switch (route.wsi) {
      >= 0.7 => const Color(0xFF16866A),
      >= 0.5 => const Color(0xFFE6A700),
      _ => const Color(0xFFD94A3A),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? const Color(0xFFE1F5EE) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? const Color(0xFF0F7C66) : const Color(0xFFDDE3E1),
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          key: ValueKey('route-${route.id}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 68,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Container(
                    key: ValueKey('route-rank-${route.id}'),
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: rankColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.directions_walk, size: 20),
                            const SizedBox(width: 5),
                            Text(
                              '${route.durationMinutes} min',
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              '· ${route.distanceMiles.toStringAsFixed(2)} mi',
                              style: const TextStyle(
                                color: Color(0xFF73737B),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Environment score ${route.wsi.toStringAsFixed(2)}'
                          '${conditions.isEmpty ? '' : ' · ${conditions.first}'}',
                          key: ValueKey('route-score-${route.id}'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: rankColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (selected)
                    const Icon(
                      Icons.check,
                      key: Key('selected-route-check'),
                      color: Color(0xFF0F7C66),
                      size: 24,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
