import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:halo/features/route_map/data/segment_repository.dart';
import 'package:latlong2/latlong.dart';

// ── Constants ───────────────────────────────────────────────────────────────

/// Downtown LA fallback when location is unavailable.
const _defaultCenter = LatLng(34.0522, -118.2437);

// ── Providers ────────────────────────────────────────────────────────────────

final _locationProvider = FutureProvider<LatLng>((ref) async {
  try {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return _defaultCenter;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return _defaultCenter;
    }

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );
    return LatLng(pos.latitude, pos.longitude);
  } catch (_) {
    return _defaultCenter;
  }
});

final _repositoryProvider = Provider<SegmentRepository>(
  (ref) => SegmentRepository(),
);

final segmentScoresProvider = FutureProvider.autoDispose<List<SegmentScore>>(
  (ref) async {
    final location = await ref.watch(_locationProvider.future);
    return ref.watch(_repositoryProvider).fetchNearby(
          lat: location.latitude,
          lng: location.longitude,
        );
  },
);

// ── Screen ───────────────────────────────────────────────────────────────────

class RouteMapScreen extends ConsumerWidget {
  const RouteMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationAsync = ref.watch(_locationProvider);
    final scoresAsync = ref.watch(segmentScoresProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Halo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Re-center',
            onPressed: () {
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
  const _HaloMap({required this.locationAsync, required this.scoresAsync});

  final AsyncValue<LatLng> locationAsync;
  final AsyncValue<List<SegmentScore>> scoresAsync;

  @override
  Widget build(BuildContext context) {
    final center = locationAsync.valueOrNull ?? _defaultCenter;
    final segments = scoresAsync.valueOrNull ?? [];

    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: 15,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.safesoundla.halo',
        ),
        PolylineLayer(
          polylines: segments.map(_buildPolyline).toList(),
        ),
        // User location marker
        if (locationAsync.valueOrNull != null)
          MarkerLayer(
            markers: [
              Marker(
                point: center,
                width: 20,
                height: 20,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 4),
                    ],
                  ),
                ),
              ),
            ],
          ),
        const RichAttributionWidget(
          attributions: [
            TextSourceAttribution('OpenStreetMap contributors'),
          ],
        ),
      ],
    );
  }

  Polyline _buildPolyline(SegmentScore segment) => Polyline(
        points: [
          LatLng(segment.startLat, segment.startLng),
          LatLng(segment.endLat, segment.endLng),
        ],
        color: _colorForBand(segment.colorBand),
        strokeWidth: 5.0,
      );

  Color _colorForBand(String band) => switch (band) {
        'GREEN' => const Color(0xFF4CAF50),
        'YELLOW' => const Color(0xFFFFC107),
        _ => const Color(0xFFF44336),
      };
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
