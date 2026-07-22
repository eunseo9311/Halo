import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo/features/route_map/data/segment_repository.dart';
import 'package:halo/features/route_map/domain/map_geometry.dart';
import 'package:halo/features/route_map/presentation/route_map_screen.dart';

void main() {
  const fallback = MapLocationState(
    center: defaultMapCenter,
    hasLocationFix: false,
  );

  testWidgets('shows map-first overlays and explicit LA fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapLocationProvider.overrideWith((ref) async => fallback),
          segmentScoresProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(
          home: RouteMapScreen(mapBuilder: _testMapBuilder),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('test-map')), findsOneWidget);
    expect(find.text('Environment Score'), findsOneWidget);
    expect(
      find.text('Location unavailable · Showing Downtown Los Angeles'),
      findsOneWidget,
    );
    expect(find.byTooltip('Re-center'), findsOneWidget);
    expect(tester.getSize(find.byType(IconButton)), const Size(48, 48));
  });

  testWidgets('recenter stays busy until refreshed scores move the map', (
    tester,
  ) async {
    final refresh = Completer<List<SegmentScore>>();
    var scoreLoads = 0;
    var latestGeneration = -1;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapLocationProvider.overrideWith((ref) async => fallback),
          segmentScoresProvider.overrideWith((ref) {
            scoreLoads++;
            return scoreLoads == 1
                ? Future.value(const <SegmentScore>[])
                : refresh.future;
          }),
        ],
        child: MaterialApp(
          home: RouteMapScreen(
            mapBuilder:
                ({
                  required center,
                  required geometry,
                  required showUserLocation,
                  required recenterGeneration,
                }) {
                  latestGeneration = recenterGeneration;
                  return const ColoredBox(
                    key: Key('test-map'),
                    color: Colors.white,
                  );
                },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Re-center'));
    await tester.pump();
    expect(find.byTooltip('Refreshing…'), findsOneWidget);
    expect(latestGeneration, 0);

    refresh.complete(const []);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Re-center'), findsOneWidget);
    expect(latestGeneration, 1);
  });

  testWidgets('failed recenter still moves the map and clears busy state', (
    tester,
  ) async {
    var scoreLoads = 0;
    var latestGeneration = -1;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapLocationProvider.overrideWith((ref) async => fallback),
          segmentScoresProvider.overrideWith((ref) {
            scoreLoads++;
            return scoreLoads == 1
                ? Future.value(const <SegmentScore>[])
                : Future<List<SegmentScore>>.error('refresh failed');
          }),
        ],
        child: MaterialApp(
          home: RouteMapScreen(
            mapBuilder:
                ({
                  required center,
                  required geometry,
                  required showUserLocation,
                  required recenterGeneration,
                }) {
                  latestGeneration = recenterGeneration;
                  return const ColoredBox(
                    key: Key('test-map'),
                    color: Colors.white,
                  );
                },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Re-center'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Re-center'), findsOneWidget);
    expect(find.byTooltip('Refreshing…'), findsNothing);
    expect(latestGeneration, 1);
  });

  testWidgets('shows a sanitized nonblocking error with retry', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapLocationProvider.overrideWith((ref) async => fallback),
          segmentScoresProvider.overrideWith(
            (ref) => Future.error('private backend details'),
          ),
        ],
        child: const MaterialApp(
          home: RouteMapScreen(mapBuilder: _testMapBuilder),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('test-map')), findsOneWidget);
    expect(find.text('Unable to load scores.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining('private backend details'), findsNothing);
  });
}

Widget _testMapBuilder({
  required MapCoordinate center,
  required MapGeometry geometry,
  required bool showUserLocation,
  required int recenterGeneration,
}) => const ColoredBox(key: Key('test-map'), color: Colors.white);
