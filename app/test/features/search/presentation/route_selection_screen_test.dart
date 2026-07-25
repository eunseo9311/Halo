import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo/features/search/domain/recent_search.dart';
import 'package:halo/features/search/domain/route_candidate.dart';
import 'package:halo/features/search/presentation/route_selection_placeholder_screen.dart';
import 'package:halo/features/route_map/presentation/platform_map/platform_route_map.dart';
import 'package:halo/features/route_map/domain/map_geometry.dart';

void main() {
  const destination = RecentSearch(
    title: 'USC Village',
    address: '3301 S Hoover St',
  );

  Widget buildScreen({
    RouteSelectionMapBuilder? mapBuilder,
    VoidCallback? onBack,
    ValueChanged<RouteCandidate>? onStartNavigation,
  }) => MaterialApp(
    home: RouteSelectionPlaceholderScreen(
      destination: destination,
      mapBuilder: mapBuilder,
      onBack: onBack,
      onStartNavigation: onStartNavigation,
    ),
  );

  void usePhoneViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('shows locations, three environmental routes, and safe factors', (
    tester,
  ) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(buildScreen());
    await tester.dragFrom(const Offset(196, 500), const Offset(0, -240));
    await tester.pumpAndSettle();

    expect(find.text('Current location'), findsOneWidget);
    expect(find.text('USC Village'), findsOneWidget);
    expect(find.byKey(const ValueKey('route-balanced')), findsOneWidget);
    expect(find.byKey(const ValueKey('route-shaded')), findsOneWidget);
    expect(find.byKey(const ValueKey('route-quiet')), findsOneWidget);
    expect(find.text('Environment score 0.82'), findsOneWidget);
    expect(find.textContaining('raw private factor'), findsNothing);
    expect(find.textContaining('unknown'), findsNothing);
  });

  testWidgets('shortest mode has one route and keeps a selection', (
    tester,
  ) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(buildScreen());

    await tester.tap(find.byKey(const Key('shortest-distance-toggle')));
    await tester.pump();

    expect(find.byKey(const ValueKey('route-shortest')), findsOneWidget);
    expect(find.byKey(const ValueKey('route-balanced')), findsNothing);
    expect(find.byKey(const Key('selected-route-check')), findsOneWidget);
    expect(
      find.text('Environment score 0.30 · No nearby safety facility'),
      findsOneWidget,
    );
  });

  testWidgets('selection map always draws all four detailed routes', (
    tester,
  ) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(buildScreen());

    MapGeometry geometry() =>
        tester.widget<PlatformRouteMap>(find.byType(PlatformRouteMap)).geometry;

    expect(geometry().polylines, hasLength(4));
    expect(
      geometry().polylines.every((line) => line.points.length > 50),
      isTrue,
    );
    expect(geometry().polylines.last.id, 'route-balanced');
    expect(geometry().polylines.last.zIndex, 1);

    await tester.tap(find.byKey(const Key('shortest-distance-toggle')));
    await tester.pump();

    expect(geometry().polylines, hasLength(4));
    expect(geometry().polylines.last.id, 'route-shortest');
    expect(geometry().polylines.last.colorValue, redWsiColor);
    expect(
      geometry().polylines
          .take(3)
          .every((line) => (line.colorValue >> 24) == 0x59 && line.zIndex == 0),
      isTrue,
    );
  });

  testWidgets('card selection updates the injectable map builder', (
    tester,
  ) async {
    usePhoneViewport(tester);
    RouteCandidate? mapped;
    await tester.pumpWidget(
      buildScreen(
        mapBuilder: (context, selected) {
          mapped = selected;
          return const ColoredBox(color: Colors.blue);
        },
      ),
    );

    expect(mapped?.id, 'balanced');
    await tester.dragFrom(const Offset(196, 500), const Offset(0, -220));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('route-shaded')));
    await tester.tap(find.byKey(const ValueKey('route-shaded')));
    await tester.pump();
    expect(mapped?.id, 'shaded');
  });

  testWidgets('start button sends the selected route to navigation', (
    tester,
  ) async {
    usePhoneViewport(tester);
    RouteCandidate? startedRoute;
    await tester.pumpWidget(
      buildScreen(onStartNavigation: (route) => startedRoute = route),
    );
    await tester.dragFrom(const Offset(196, 500), const Offset(0, -260));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('route-shaded')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('start-route-button')));
    await tester.pumpAndSettle();

    final size = tester.getSize(find.byKey(const Key('start-route-button')));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));

    await tester.tap(find.byKey(const Key('start-route-button')));
    await tester.pump();
    expect(startedRoute?.id, 'shaded');
    expect(find.text('Navigation is coming soon.'), findsNothing);
  });

  testWidgets('back control invokes navigation without a home button', (
    tester,
  ) async {
    usePhoneViewport(tester);
    var backCount = 0;
    await tester.pumpWidget(buildScreen(onBack: () => backCount++));

    await tester.tap(find.byKey(const Key('route-back-button')));

    expect(backCount, 1);
    expect(find.byKey(const Key('route-home-button')), findsNothing);
    final backRect = tester.getRect(find.byKey(const Key('route-back-button')));
    final cardRect = tester.getRect(
      find.byKey(const Key('route-location-card')),
    );
    expect(cardRect.left - backRect.right, greaterThanOrEqualTo(8));
    expect(backRect.size, const Size(48, 48));
  });

  testWidgets('origin and destination can be edited in place', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(buildScreen());

    await tester.tap(find.byKey(const Key('edit-origin-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('origin-edit-field')),
      'USC Village Gate',
    );
    await tester.tap(find.byKey(const Key('save-origin-button')));
    await tester.pumpAndSettle();
    expect(find.text('USC Village Gate'), findsOneWidget);

    await tester.tap(find.byKey(const Key('edit-destination-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('destination-edit-field')),
      'Leavey Library',
    );
    await tester.tap(find.byKey(const Key('save-destination-button')));
    await tester.pumpAndSettle();
    expect(find.text('Leavey Library'), findsOneWidget);
  });
}
