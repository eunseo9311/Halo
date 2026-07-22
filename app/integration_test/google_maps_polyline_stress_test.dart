import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo/features/route_map/data/segment_repository.dart';
import 'package:halo/features/route_map/domain/map_geometry.dart';
import 'package:halo/features/route_map/presentation/platform_map/platform_route_map.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders and refreshes 200 WSI segments with three routes', (
    tester,
  ) async {
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      markTestSkipped('Google Maps stress test requires Android or iOS.');
      return;
    }

    final geometries = <MapGeometry>[];

    for (var generation = 0; generation < 10; generation++) {
      final geometry = const MapGeometryBuilder().build(
        segments: List.generate(200, (index) => _segment(generation, index)),
        routes: List.generate(3, (index) => _route(generation, index)),
      );
      geometries.add(geometry);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlatformRouteMap(
              center: MapCoordinate(34.0522 + generation / 100000, -118.2437),
              geometry: geometry,
              showUserLocation: false,
              recenterGeneration: generation,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
    }

    expect(find.byType(PlatformRouteMap), findsOneWidget);
    expect(
      geometries.map((geometry) => geometry.polylines.length),
      everyElement(203),
    );
    expect(
      geometries.map((geometry) => geometry.polylines.first.id).toSet(),
      hasLength(10),
    );
    expect(
      geometries
          .map((geometry) => geometry.polylines.first.points.first.latitude)
          .toSet(),
      hasLength(10),
    );
  });
}

SegmentScore _segment(int generation, int index) => SegmentScore(
  segmentId: 'stress-$generation-$index',
  wsiScore: 80,
  confidence: 0.9,
  colorBand: switch ((index + generation) % 3) {
    0 => 'GREEN',
    1 => 'YELLOW',
    _ => 'RED',
  },
  startLat: 34.04 + index / 100000 + generation / 1000000,
  startLng: -118.25,
  endLat: 34.04 + index / 100000 + generation / 1000000,
  endLng: -118.24,
);

RouteOverlay _route(int generation, int index) => RouteOverlay(
  id: 'stress-$generation-$index',
  colorValue: const [greenWsiColor, yellowWsiColor, redWsiColor][index],
  strokeWidth: 7,
  points: [
    MapCoordinate(34.045 + index / 1000 + generation / 1000000, -118.25),
    MapCoordinate(34.055 + index / 1000 + generation / 1000000, -118.24),
  ],
);
