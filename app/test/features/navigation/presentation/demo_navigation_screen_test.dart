import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo/features/navigation/presentation/demo_navigation_screen.dart';
import 'package:halo/features/route_map/domain/map_geometry.dart';
import 'package:halo/features/search/domain/route_candidate.dart';

void main() {
  const route = RouteCandidate(
    id: 'test-route',
    name: 'Shaded route',
    durationMinutes: 7,
    distanceMiles: 0.42,
    wsi: 0.76,
  );

  testWidgets('shows selected route details and navigation controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DemoNavigationScreen(
          route: route,
          onEnd: () {},
          mapBuilder: _testMapBuilder,
        ),
      ),
    );

    expect(find.text('Continue straight'), findsOneWidget);
    expect(find.text('Follow shaded route'), findsOneWidget);
    expect(find.text('Current location'), findsOneWidget);
    expect(find.text('Destination · Shaded route'), findsOneWidget);
    expect(find.text('7 min'), findsOneWidget);
    expect(find.text('0.42 mi'), findsOneWidget);
    expect(find.byTooltip('Re-center'), findsOneWidget);
    expect(find.text('End navigation'), findsOneWidget);
  });

  testWidgets('map contains only selected demo route segments and endpoints', (
    tester,
  ) async {
    MapGeometry? capturedGeometry;

    await tester.pumpWidget(
      MaterialApp(
        home: DemoNavigationScreen(
          route: route,
          onEnd: () {},
          mapBuilder:
              ({
                required center,
                required geometry,
                required recenterGeneration,
              }) {
                capturedGeometry = geometry;
                return const ColoredBox(color: Colors.white);
              },
        ),
      ),
    );

    expect(capturedGeometry!.polylines.map((line) => line.id), [
      'navigation-green',
      'navigation-yellow',
      'navigation-red',
    ]);
    expect(capturedGeometry!.polylines.map((line) => line.colorValue), [
      greenWsiColor,
      yellowWsiColor,
      redWsiColor,
    ]);
    expect(capturedGeometry!.markers.map((marker) => marker.kind), [
      MapMarkerKind.origin,
      MapMarkerKind.destination,
    ]);
  });

  testWidgets(
    'different selected candidates produce different route geometry',
    (tester) async {
      MapGeometry? balancedGeometry;
      MapGeometry? shadedGeometry;

      Widget screen(
        RouteCandidate candidate,
        ValueChanged<MapGeometry> capture,
      ) => MaterialApp(
        home: DemoNavigationScreen(
          route: candidate,
          onEnd: () {},
          mapBuilder:
              ({
                required center,
                required geometry,
                required recenterGeneration,
              }) {
                capture(geometry);
                return const ColoredBox(color: Colors.white);
              },
        ),
      );

      await tester.pumpWidget(
        screen(
          mockEnvironmentRoutes.first,
          (value) => balancedGeometry = value,
        ),
      );
      await tester.pumpWidget(
        screen(mockEnvironmentRoutes[1], (value) => shadedGeometry = value),
      );

      expect(
        balancedGeometry!.polylines.expand((line) => line.points),
        isNot(equals(shadedGeometry!.polylines.expand((line) => line.points))),
      );
      expect(
        shadedGeometry!.markers.first.position,
        const MapCoordinate(34.0498, -118.2470),
      );
      expect(
        shadedGeometry!.markers.last.position,
        const MapCoordinate(34.0545, -118.2418),
      );
    },
  );

  testWidgets('recenter updates the map and End invokes its callback', (
    tester,
  ) async {
    var capturedGeneration = -1;
    var endCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: DemoNavigationScreen(
          route: route,
          onEnd: () => endCount++,
          mapBuilder:
              ({
                required center,
                required geometry,
                required recenterGeneration,
              }) {
                capturedGeneration = recenterGeneration;
                return const ColoredBox(color: Colors.white);
              },
        ),
      ),
    );

    expect(capturedGeneration, 0);
    await tester.tap(find.byTooltip('Re-center'));
    await tester.pump();
    expect(capturedGeneration, 1);

    await tester.tap(find.byKey(const Key('end-navigation-button')));
    expect(endCount, 1);
  });
}

Widget _testMapBuilder({
  required MapCoordinate center,
  required MapGeometry geometry,
  required int recenterGeneration,
}) => const ColoredBox(key: Key('test-map'), color: Colors.white);
