import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:halo/core/config/halo_map_config.dart';
import 'package:halo/features/route_map/data/demo_map_data.dart';
import 'package:halo/features/route_map/data/segment_repository.dart';
import 'package:halo/features/route_map/domain/map_geometry.dart';
import 'package:halo/features/route_map/presentation/platform_map/platform_route_map.dart';
import 'package:halo/features/wsi_score/presentation/wsi_legend_widget.dart';
import 'package:latlong2/latlong.dart';

/// Downtown LA fallback when location is unavailable.
const defaultMapCenter = LatLng(34.0522, -118.2437);

class MapLocationState {
  const MapLocationState({required this.center, required this.hasLocationFix});

  final LatLng center;
  final bool hasLocationFix;
}

final _demoData = buildDemoMapData();

final mapLocationProvider = FutureProvider<MapLocationState>((ref) async {
  if (haloMapDemo) {
    return const MapLocationState(
      center: defaultMapCenter,
      hasLocationFix: false,
    );
  }

  try {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const MapLocationState(
        center: defaultMapCenter,
        hasLocationFix: false,
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return const MapLocationState(
        center: defaultMapCenter,
        hasLocationFix: false,
      );
    }

    final position =
        await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw TimeoutException('GPS timeout'),
        );
    return MapLocationState(
      center: LatLng(position.latitude, position.longitude),
      hasLocationFix: true,
    );
  } catch (_) {
    return const MapLocationState(
      center: defaultMapCenter,
      hasLocationFix: false,
    );
  }
});

final segmentRepositoryProvider = Provider<SegmentRepository>(
  (ref) => SegmentRepository(),
);

final segmentScoresProvider = FutureProvider.autoDispose<List<SegmentScore>>((
  ref,
) async {
  if (haloMapDemo) return _demoData.segments;

  final location = (await ref.watch(mapLocationProvider.future)).center;
  return ref
      .watch(segmentRepositoryProvider)
      .fetchNearby(lat: location.latitude, lng: location.longitude);
});

final routeOverlaysProvider = Provider<List<RouteOverlay>>(
  (ref) => haloMapDemo ? _demoData.routes : const [],
);

typedef RouteMapBuilder =
    Widget Function({
      required MapCoordinate center,
      required MapGeometry geometry,
      required bool showUserLocation,
      required int recenterGeneration,
    });

class RouteMapScreen extends ConsumerStatefulWidget {
  const RouteMapScreen({super.key, this.mapBuilder});

  final RouteMapBuilder? mapBuilder;

  @override
  ConsumerState<RouteMapScreen> createState() => _RouteMapScreenState();
}

class _RouteMapScreenState extends ConsumerState<RouteMapScreen> {
  var _recenterGeneration = 0;
  var _isRecentering = false;

  Future<void> _recenter() async {
    if (_isRecentering) return;
    setState(() => _isRecentering = true);
    ref.invalidate(mapLocationProvider);
    try {
      final refreshedScores = ref.refresh(segmentScoresProvider.future);
      await refreshedScores;
    } catch (_) {
      // The existing map remains usable when refreshing scores fails.
    } finally {
      if (mounted) {
        setState(() {
          _recenterGeneration++;
          _isRecentering = false;
        });
      }
    }
  }

  void _retry() {
    ref.invalidate(mapLocationProvider);
    ref.invalidate(segmentScoresProvider);
  }

  @override
  Widget build(BuildContext context) {
    validateHaloMapConfiguration();
    final locationAsync = ref.watch(mapLocationProvider);
    final scoresAsync = ref.watch(segmentScoresProvider);
    final routes = ref.watch(routeOverlaysProvider);
    final location = locationAsync.valueOrNull;
    final center = location?.center ?? defaultMapCenter;
    final geometry = const MapGeometryBuilder().build(
      segments: scoresAsync.valueOrNull ?? const [],
      routes: routes,
    );
    final mapBuilder = widget.mapBuilder ?? _buildPlatformMap;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          mapBuilder(
            center: MapCoordinate(center.latitude, center.longitude),
            geometry: geometry,
            showUserLocation: location?.hasLocationFix ?? false,
            recenterGeneration: _recenterGeneration,
          ),
          SafeArea(
            minimum: const EdgeInsets.all(12),
            child: Stack(
              children: [
                const Align(
                  alignment: Alignment.topLeft,
                  child: WsiLegendWidget(),
                ),
                Align(
                  alignment: Alignment.topRight,
                  child: _RecenterButton(
                    isBusy: _isRecentering,
                    onPressed: _isRecentering ? null : _recenter,
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (scoresAsync.hasError) _ErrorBanner(onRetry: _retry),
                        if (scoresAsync.hasError &&
                            (locationAsync.isLoading || scoresAsync.isLoading))
                          const SizedBox(height: 8),
                        if (locationAsync.isLoading || scoresAsync.isLoading)
                          const _LoadingPill(),
                        if ((scoresAsync.hasError ||
                                locationAsync.isLoading ||
                                scoresAsync.isLoading) &&
                            locationAsync.hasValue &&
                            !(location?.hasLocationFix ?? false))
                          const SizedBox(height: 8),
                        if (locationAsync.hasValue &&
                            !(location?.hasLocationFix ?? false))
                          const _FallbackNotice(),
                      ],
                    ),
                  ),
                ),
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
  required bool showUserLocation,
  required int recenterGeneration,
}) => PlatformRouteMap(
  center: center,
  geometry: geometry,
  showUserLocation: showUserLocation,
  recenterGeneration: recenterGeneration,
);

class _RecenterButton extends StatelessWidget {
  const _RecenterButton({required this.isBusy, required this.onPressed});

  final bool isBusy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Material(
    elevation: 3,
    color: Theme.of(context).colorScheme.surface,
    shape: const CircleBorder(),
    child: Semantics(
      label: isBusy ? 'Refreshing map location' : 'Re-center map',
      button: true,
      child: IconButton(
        constraints: const BoxConstraints.tightFor(width: 48, height: 48),
        tooltip: isBusy ? 'Refreshing…' : 'Re-center',
        onPressed: onPressed,
        icon: isBusy
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : const Icon(Icons.my_location),
      ),
    ),
  );
}

class _LoadingPill extends StatelessWidget {
  const _LoadingPill();

  @override
  Widget build(BuildContext context) => Material(
    elevation: 2,
    borderRadius: BorderRadius.circular(20),
    child: const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text('Updating map…'),
        ],
      ),
    ),
  );
}

class _FallbackNotice extends StatelessWidget {
  const _FallbackNotice();

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.94),
    borderRadius: BorderRadius.circular(8),
    child: const Padding(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Text('Location unavailable · Showing Downtown Los Angeles'),
    ),
  );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.errorContainer,
    borderRadius: BorderRadius.circular(8),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Unable to load scores.'),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}
