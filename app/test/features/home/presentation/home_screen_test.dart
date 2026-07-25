import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo/features/home/presentation/home_screen.dart';
import 'package:halo/features/incidents/domain/incident.dart';
import 'package:halo/features/incidents/presentation/incident_providers.dart';
import 'package:halo/features/route_map/domain/map_geometry.dart';
import 'package:halo/features/route_map/presentation/platform_map/map_interactions.dart';
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
    Future<List<Incident>>? incidents,
    Future<List<DisplayedIncident>>? displayedIncidents,
    bool incidentFailure = false,
  }) => ProviderScope(
    overrides: [
      mapLocationProvider.overrideWith((ref) async => location),
      nearbyIncidentsProvider.overrideWith((ref) async {
        try {
          if (incidentFailure) throw StateError('offline');
          return await (incidents ?? Future.value(const []));
        } catch (_) {
          return const [];
        }
      }),
      if (displayedIncidents != null)
        displayedIncidentsProvider.overrideWith((ref) => displayedIncidents),
    ],
    child: MaterialApp(
      home: HomeScreen(
        mapBuilder:
            mapBuilder ??
            ({
              required MapCoordinate center,
              required MapGeometry geometry,
              required bool showUserLocation,
              required int northResetGeneration,
              required void Function(MapMarker) onMarkerTap,
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
              required MapGeometry geometry,
              required bool showUserLocation,
              required int northResetGeneration,
              required void Function(MapMarker) onMarkerTap,
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
              required MapGeometry geometry,
              required bool showUserLocation,
              required int northResetGeneration,
              required void Function(MapMarker) onMarkerTap,
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
              required MapGeometry geometry,
              required bool showUserLocation,
              required int northResetGeneration,
              required void Function(MapMarker) onMarkerTap,
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

  testWidgets('incident marker opens a privacy-safe detail sheet', (
    tester,
  ) async {
    MapMarkerTapCallback? markerTap;
    await tester.pumpWidget(
      buildHome(
        incidents: Future.value([_incident]),
        mapBuilder:
            ({
              required MapCoordinate center,
              required MapGeometry geometry,
              required bool showUserLocation,
              required int northResetGeneration,
              required MapMarkerTapCallback onMarkerTap,
            }) {
              markerTap = onMarkerTap;
              if (geometry.markers.isNotEmpty) {
                expect(
                  geometry.markers
                      .where((marker) => marker.id == 'incident-1')
                      .single
                      .label,
                  '🚨',
                );
              }
              return const SizedBox.expand();
            },
      ),
    );
    await tester.pumpAndSettle();

    markerTap!(
      const MapMarker(
        id: 'incident-1',
        position: MapCoordinate(34.02, -118.28),
        kind: MapMarkerKind.incident,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('incident-detail-sheet')), findsOneWidget);
    expect(find.text('🚨  Sidewalk hazard'), findsOneWidget);
    expect(find.text('Temporary obstruction reported nearby.'), findsOneWidget);
    expect(find.textContaining('Public space · South LA'), findsOneWidget);
    expect(find.textContaining('raw private factor'), findsNothing);
    expect(find.textContaining('34.02'), findsNothing);
    expect(find.textContaining('-118.28'), findsNothing);
    expect(find.text('Sample data'), findsNothing);
  });

  testWidgets('demo incident detail shows a subtle sample caption', (
    tester,
  ) async {
    MapMarkerTapCallback? markerTap;
    final display = DisplayedIncident(
      markerId: 'incident-1-demo-0',
      incident: _incident,
      latitude: 34.0546,
      longitude: -118.2465,
      isDemoLocation: true,
    );
    await tester.pumpWidget(
      buildHome(
        displayedIncidents: Future.value([display]),
        mapBuilder:
            ({
              required MapCoordinate center,
              required MapGeometry geometry,
              required bool showUserLocation,
              required int northResetGeneration,
              required MapMarkerTapCallback onMarkerTap,
            }) {
              markerTap = onMarkerTap;
              return const SizedBox.expand();
            },
      ),
    );
    await tester.pumpAndSettle();

    markerTap!(
      const MapMarker(
        id: 'incident-1-demo-0',
        position: MapCoordinate(34.0546, -118.2465),
        kind: MapMarkerKind.incident,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sample data'), findsOneWidget);
    final caption = tester.widget<Text>(find.text('Sample data'));
    expect(caption.style?.color, const Color(0xFF6B7472));
    expect(
      find.text('Demo location — not the reported location'),
      findsNothing,
    );
    expect(find.textContaining('34.0546'), findsNothing);
  });

  testWidgets('incident request failure leaves the home map usable', (
    tester,
  ) async {
    MapGeometry? renderedGeometry;
    await tester.pumpWidget(
      buildHome(
        incidentFailure: true,
        mapBuilder:
            ({
              required MapCoordinate center,
              required MapGeometry geometry,
              required bool showUserLocation,
              required int northResetGeneration,
              required MapMarkerTapCallback onMarkerTap,
            }) {
              renderedGeometry = geometry;
              return const SizedBox.expand();
            },
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(renderedGeometry?.markers, isEmpty);
    expect(find.byKey(const Key('home-search-button')), findsOneWidget);
    expect(find.textContaining('offline'), findsNothing);
  });
}

final _incident = Incident(
  incidentId: 'incident-1',
  category: 'robbery',
  emoji: '🚨',
  title: 'Sidewalk hazard',
  description: 'Temporary obstruction reported nearby.',
  locationType: 'Public space',
  areaName: 'South LA',
  occurredAt: DateTime(2026, 7, 26, 10, 30),
  latitude: 34.02,
  longitude: -118.28,
);
