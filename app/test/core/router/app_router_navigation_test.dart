import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo/core/router/app_router.dart';
import 'package:halo/features/search/domain/recent_search.dart';

void main() {
  testWidgets('selected route starts navigation and End returns to selection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.reset();
      appRouter.go('/');
    });

    appRouter.go(
      '/route-selection',
      extra: const RecentSearch(
        title: 'USC Village',
        address: '3301 S Hoover St',
      ),
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: appRouter));
    await tester.pumpAndSettle();

    await tester.dragFrom(const Offset(196, 500), const Offset(0, -220));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('route-shaded')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('start-route-button')));
    await tester.tap(find.byKey(const Key('start-route-button')));
    await tester.pumpAndSettle();

    expect(find.text('Follow balanced alternative'), findsOneWidget);
    expect(find.byKey(const Key('end-navigation-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('end-navigation-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('start-route-button')), findsOneWidget);
    expect(find.text('USC Village'), findsOneWidget);
  });
}
