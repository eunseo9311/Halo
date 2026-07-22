import 'package:halo/features/route_map/data/segment_repository.dart';
import 'package:halo/features/route_map/domain/map_geometry.dart';

class DemoMapData {
  const DemoMapData({required this.segments, required this.routes});

  final List<SegmentScore> segments;
  final List<RouteOverlay> routes;
}

/// Builds a stable LA-area dataset without accessing location services or APIs.
DemoMapData buildDemoMapData() {
  const centerLat = 34.0522;
  const centerLng = -118.2437;
  const bands = ['GREEN', 'YELLOW', 'RED'];

  final segments = List<SegmentScore>.unmodifiable(
    List.generate(200, (index) {
      final row = index ~/ 20;
      final column = index % 20;
      final startLat = centerLat - 0.009 + row * 0.002;
      final startLng = centerLng - 0.012 + column * 0.0012;
      return SegmentScore(
        segmentId: 'demo-$index',
        wsiScore: switch (index % 3) {
          0 => 0.82,
          1 => 0.56,
          _ => 0.28,
        },
        confidence: 0.9,
        colorBand: bands[index % bands.length],
        startLat: startLat,
        startLng: startLng,
        endLat: startLat + (index.isEven ? 0 : 0.0012),
        endLng: startLng + (index.isEven ? 0.0012 : 0),
      );
    }),
  );

  const routes = [
    RouteOverlay(
      id: 'quiet-west',
      colorValue: 0xFF1565C0,
      points: [
        MapCoordinate(34.0432, -118.2557),
        MapCoordinate(34.0522, -118.2461),
        MapCoordinate(34.0612, -118.2437),
      ],
    ),
    RouteOverlay(
      id: 'central',
      colorValue: 0xFF6A1B9A,
      points: [
        MapCoordinate(34.0452, -118.2521),
        MapCoordinate(34.0522, -118.2437),
        MapCoordinate(34.0592, -118.2341),
      ],
    ),
    RouteOverlay(
      id: 'quiet-east',
      colorValue: 0xFFEF6C00,
      points: [
        MapCoordinate(34.0432, -118.2389),
        MapCoordinate(34.0522, -118.2413),
        MapCoordinate(34.0612, -118.2317),
      ],
    ),
  ];

  return DemoMapData(segments: segments, routes: routes);
}
