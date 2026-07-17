import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:halo/features/route_map/data/segment_repository.dart';
import 'package:latlong2/latlong.dart';

// ── Providers ──────────────────────────────────────────────────────────────

final _repositoryProvider = Provider<SegmentRepository>(
  (ref) => SegmentRepository(),
);

/// Downtown LA coordinates (default center)
const _defaultCenter = LatLng(34.0522, -118.2437);

final segmentScoresProvider = FutureProvider.autoDispose<List<SegmentScore>>(
  (ref) => ref.watch(_repositoryProvider).fetchNearby(
        lat: _defaultCenter.latitude,
        lng: _defaultCenter.longitude,
      ),
);

// ── Screen ─────────────────────────────────────────────────────────────────

class RouteMapScreen extends ConsumerWidget {
  const RouteMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scoresAsync = ref.watch(segmentScoresProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Halo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(segmentScoresProvider),
          ),
        ],
      ),
      body: Stack(
        children: [
          _HaloMap(scoresAsync: scoresAsync),
          if (scoresAsync.isLoading)
            const Center(child: CircularProgressIndicator()),
          if (scoresAsync.hasError)
            _ErrorBanner(message: scoresAsync.error.toString()),
        ],
      ),
    );
  }
}

// ── Map widget ─────────────────────────────────────────────────────────────

class _HaloMap extends StatelessWidget {
  const _HaloMap({required this.scoresAsync});

  final AsyncValue<List<SegmentScore>> scoresAsync;

  @override
  Widget build(BuildContext context) {
    final segments = scoresAsync.valueOrNull ?? _dummySegments();

    return FlutterMap(
      options: const MapOptions(
        initialCenter: _defaultCenter,
        initialZoom: 15,
      ),
      children: [
        // OSM tile layer — no API key required
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.safesoundla.halo',
        ),
        // WSI color-coded segment overlays
        PolylineLayer(
          polylines: segments.map(_buildPolyline).toList(),
        ),
        // Attribution (required by OSM usage policy)
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
        strokeWidth: 6.0,
      );

  Color _colorForBand(String band) => switch (band) {
        'GREEN' => const Color(0xFF4CAF50),
        'YELLOW' => const Color(0xFFFFC107),
        _ => const Color(0xFFF44336), // RED
      };
}

// ── Error banner ───────────────────────────────────────────────────────────

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
              'Unable to load scores — showing demo data.\n$message',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),
      );
}

// ── Dummy data (used when API is unreachable) ───────────────────────────────

List<SegmentScore> _dummySegments() => [
      const SegmentScore(
        segmentId: 'demo-green',
        wsiScore: 0.82,
        confidence: 0.9,
        colorBand: 'GREEN',
        startLat: 34.0522, startLng: -118.2437,
        endLat: 34.0532, endLng: -118.2427,
      ),
      const SegmentScore(
        segmentId: 'demo-yellow',
        wsiScore: 0.50,
        confidence: 0.6,
        colorBand: 'YELLOW',
        startLat: 34.0532, startLng: -118.2427,
        endLat: 34.0542, endLng: -118.2417,
      ),
      const SegmentScore(
        segmentId: 'demo-red',
        wsiScore: 0.21,
        confidence: 0.4,
        colorBand: 'RED',
        startLat: 34.0542, startLng: -118.2417,
        endLat: 34.0552, endLng: -118.2407,
      ),
    ];
