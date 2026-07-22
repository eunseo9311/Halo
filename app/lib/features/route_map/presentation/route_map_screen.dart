import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:halo/features/route_map/data/segment_repository.dart';
import 'package:halo/features/route_map/domain/map_geometry.dart';
import 'package:halo/features/route_map/presentation/platform_map/platform_route_map.dart';
import 'package:latlong2/latlong.dart';

// ── Constants ───────────────────────────────────────────────────────────────

/// Downtown LA fallback when location is unavailable.
const _defaultCenter = LatLng(34.0522, -118.2437);

class _LocationState {
  const _LocationState({required this.center, required this.hasLocationFix});

  final LatLng center;
  final bool hasLocationFix;
}

// ── Providers ────────────────────────────────────────────────────────────────

final _locationProvider = FutureProvider<_LocationState>((ref) async {
  try {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const _LocationState(
        center: _defaultCenter,
        hasLocationFix: false,
      );
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return const _LocationState(
        center: _defaultCenter,
        hasLocationFix: false,
      );
    }

    final pos =
        await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw TimeoutException('GPS timeout'),
        );
    return _LocationState(
      center: LatLng(pos.latitude, pos.longitude),
      hasLocationFix: true,
    );
  } catch (_) {
    return const _LocationState(center: _defaultCenter, hasLocationFix: false);
  }
});

final _recenterGenerationProvider = StateProvider<int>((ref) => 0);

final _repositoryProvider = Provider<SegmentRepository>(
  (ref) => SegmentRepository(),
);

final segmentScoresProvider = FutureProvider.autoDispose<List<SegmentScore>>((
  ref,
) async {
  final location = (await ref.watch(_locationProvider.future)).center;
  return ref
      .watch(_repositoryProvider)
      .fetchNearby(lat: location.latitude, lng: location.longitude);
});

// ── Screen ───────────────────────────────────────────────────────────────────

class RouteMapScreen extends ConsumerWidget {
  const RouteMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationAsync = ref.watch(_locationProvider);
    final scoresAsync = ref.watch(segmentScoresProvider);
    final recenterGeneration = ref.watch(_recenterGenerationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Halo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Re-center',
            onPressed: () {
              ref.read(_recenterGenerationProvider.notifier).state++;
              ref.invalidate(_locationProvider);
              ref.invalidate(segmentScoresProvider);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          _HaloMap(
            locationAsync: locationAsync,
            scoresAsync: scoresAsync,
            recenterGeneration: recenterGeneration,
          ),
          if (locationAsync.isLoading || scoresAsync.isLoading)
            const Center(child: CircularProgressIndicator()),
          if (scoresAsync.hasError)
            _ErrorBanner(message: scoresAsync.error.toString()),
        ],
      ),
    );
  }
}

// ── Map widget ────────────────────────────────────────────────────────────────

class _HaloMap extends StatelessWidget {
  const _HaloMap({
    required this.locationAsync,
    required this.scoresAsync,
    required this.recenterGeneration,
  });

  final AsyncValue<_LocationState> locationAsync;
  final AsyncValue<List<SegmentScore>> scoresAsync;
  final int recenterGeneration;

  @override
  Widget build(BuildContext context) {
    final location = locationAsync.valueOrNull;
    final center = location?.center ?? _defaultCenter;
    final segments = scoresAsync.valueOrNull ?? [];

    return PlatformRouteMap(
      center: MapCoordinate(center.latitude, center.longitude),
      geometry: const MapGeometryBuilder().build(segments: segments),
      showUserLocation: location?.hasLocationFix ?? false,
      recenterGeneration: recenterGeneration,
    );
  }
}

// ── Error banner ──────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Positioned(
    bottom: 16,
    left: 16,
    right: 16,
    child: Material(
      color: Colors.red.shade700,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          'Unable to load scores.\n$message',
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
    ),
  );
}
