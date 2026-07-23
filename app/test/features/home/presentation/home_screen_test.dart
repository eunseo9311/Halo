import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo/features/home/presentation/home_screen.dart';
import 'package:halo/features/route_map/domain/map_geometry.dart';
import 'package:halo/features/route_map/presentation/route_map_screen.dart';
import 'package:latlong2/latlong.dart';

void main() {
  const fixedLocation = MapLocationState(
    center: LatLng(34.0224, -118.2851),
    hasLocationFix: true,
  );

  Widget buildHome({
    MapLocationState location = fixedLocation,
    HomeMapBuilder? mapBuilder,
    VoidCallback? onSearch,
    VoidCallback? onDirections,
    SosLauncher? launcher,
  }) => ProviderScope(
    overrides: [mapLocationProvider.overrideWith((ref) async => location)],
    child: MaterialApp(
      home: HomeScreen(
        mapBuilder:
            mapBuilder ??
            ({
              required MapCoordinate center,
              required bool showUserLocation,
              required int northResetGeneration,
            }) => const ColoredBox(color: Colors.grey),
        onSearch: onSearch,
        onDirections: onDirections,
        sosLauncher: launcher ?? (_) async => true,
      ),
    ),
  );

  testWidgets('short SOS press shows the hold instruction', (tester) async {
    await tester.pumpWidget(buildHome());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('sos-button')));
    await tester.pump();

    expect(
      find.text('Press and hold for 2 seconds to activate SOS.'),
      findsOneWidget,
    );
  });

  testWidgets('SOS does not activate at 1999ms and activates once at 2000ms', (
    tester,
  ) async {
    await tester.pumpWidget(buildHome());
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('sos-button'))),
    );
    await tester.pump(const Duration(milliseconds: 1999));
    expect(find.text('Choose emergency service'), findsNothing);

    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('Choose emergency service'), findsOneWidget);
    expect(find.text('Fire & Rescue (119)'), findsOneWidget);
    expect(find.text('Police (112)'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Choose emergency service'), findsOneWidget);
    await gesture.up();
  });

  testWidgets('search and directions invoke their callbacks', (tester) async {
    var searchCount = 0;
    var directionsCount = 0;
    await tester.pumpWidget(
      buildHome(
        onSearch: () => searchCount++,
        onDirections: () => directionsCount++,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home-search-button')));
    await tester.tap(find.byKey(const Key('directions-button')));

    expect(searchCount, 1);
    expect(directionsCount, 1);
  });

  testWidgets('north button recreates the map at bearing zero', (tester) async {
    final resetGenerations = <int>[];
    await tester.pumpWidget(
      buildHome(
        mapBuilder:
            ({
              required MapCoordinate center,
              required bool showUserLocation,
              required int northResetGeneration,
            }) {
              resetGenerations.add(northResetGeneration);
              return const SizedBox.expand();
            },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('north-reset-button')));
    await tester.pump();

    expect(resetGenerations, containsAllInOrder([0, 1]));
  });

  testWidgets('confirmed SOS choice launches the selected telephone URI', (
    tester,
  ) async {
    Uri? launchedUri;
    await tester.pumpWidget(
      buildHome(
        launcher: (uri) async {
          launchedUri = uri;
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('sos-button'))),
    );
    await tester.pump(const Duration(seconds: 2));
    await gesture.up();
    await tester.tap(find.text('Fire & Rescue (119)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Call'));
    await tester.pumpAndSettle();

    expect(launchedUri, Uri(scheme: 'tel', path: '119'));
  });

  testWidgets('SOS reports when the Phone app cannot be opened', (
    tester,
  ) async {
    await tester.pumpWidget(buildHome(launcher: (_) async => false));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('sos-button'))),
    );
    await tester.pump(const Duration(seconds: 2));
    await gesture.up();
    await tester.tap(find.text('Police (112)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Call'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Unable to open the Phone app. Call emergency services manually.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('SOS catches launcher errors and reports failure', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildHome(launcher: (_) => Future<bool>.error(StateError('unavailable'))),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('sos-button'))),
    );
    await tester.pump(const Duration(seconds: 2));
    await gesture.up();
    await tester.tap(find.text('Fire & Rescue (119)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Call'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Unable to open the Phone app. Call emergency services manually.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('location fix controls native puck flag', (tester) async {
    bool? puckEnabled;
    await tester.pumpWidget(
      buildHome(
        mapBuilder:
            ({
              required MapCoordinate center,
              required bool showUserLocation,
              required int northResetGeneration,
            }) {
              puckEnabled = showUserLocation;
              return const SizedBox.expand();
            },
      ),
    );
    await tester.pumpAndSettle();

    expect(puckEnabled, isTrue);
    expect(
      find.text('Location unavailable — showing Los Angeles.'),
      findsNothing,
    );
  });

  testWidgets('fallback hides puck and shows a location banner', (
    tester,
  ) async {
    bool? puckEnabled;
    await tester.pumpWidget(
      buildHome(
        location: const MapLocationState(
          center: defaultMapCenter,
          hasLocationFix: false,
        ),
        mapBuilder:
            ({
              required MapCoordinate center,
              required bool showUserLocation,
              required int northResetGeneration,
            }) {
              puckEnabled = showUserLocation;
              return const SizedBox.expand();
            },
      ),
    );
    await tester.pumpAndSettle();

    expect(puckEnabled, isFalse);
    expect(
      find.text('Location unavailable — showing Los Angeles.'),
      findsOneWidget,
    );
  });

  testWidgets('all home controls provide at least 48 point hit targets', (
    tester,
  ) async {
    await tester.pumpWidget(buildHome());
    await tester.pumpAndSettle();

    for (final key in const [
      Key('home-search-button'),
      Key('sos-button'),
      Key('north-reset-button'),
      Key('directions-button'),
    ]) {
      final size = tester.getSize(find.byKey(key));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
  });
}
