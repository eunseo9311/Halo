import 'package:flutter_test/flutter_test.dart';
import 'package:halo/features/search/data/demo_route_geometry.dart';
import 'package:halo/features/search/domain/route_candidate.dart';

void main() {
  test('every demo candidate has a detailed Valhalla path', () {
    final candidates = [...mockEnvironmentRoutes, ...mockShortestRoutes];

    for (final candidate in candidates) {
      final points = demoRoutePointsFor(candidate.id);
      expect(points.length, greaterThanOrEqualTo(8), reason: candidate.id);
      expect(points.first, same(demoRouteOrigin), reason: candidate.id);
      expect(points.last, same(demoRouteDestination), reason: candidate.id);
    }

    for (var first = 0; first < candidates.length; first++) {
      for (var second = first + 1; second < candidates.length; second++) {
        expect(
          demoRoutePointsFor(candidates[first].id),
          isNot(equals(demoRoutePointsFor(candidates[second].id))),
          reason: '${candidates[first].id} and ${candidates[second].id}',
        );
      }
    }
    expect(
      mockShortestRoutes.single.distanceMiles,
      lessThan(mockEnvironmentRoutes.last.distanceMiles),
    );
    expect(
      mockShortestRoutes.single.wsi,
      lessThan(mockEnvironmentRoutes.last.wsi),
    );
  });

  test('safety ranking increases distance and WSI', () {
    final routes = [
      ...mockEnvironmentRoutes.reversed,
      mockShortestRoutes.single,
    ];

    expect(
      mockEnvironmentRoutes.map((route) => route.distanceMiles),
      orderedEquals([1.44, 1.32, 1.30]),
    );
    expect(
      mockEnvironmentRoutes.map((route) => route.wsi),
      orderedEquals([0.82, 0.66, 0.48]),
    );
    expect(mockShortestRoutes.single.distanceMiles, 1.29);
    expect(mockShortestRoutes.single.wsi, 0.30);
    expect(routes, hasLength(4));
  });
}
