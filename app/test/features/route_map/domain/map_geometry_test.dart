import 'package:flutter_test/flutter_test.dart';
import 'package:halo/features/route_map/data/segment_repository.dart';
import 'package:halo/features/route_map/domain/map_geometry.dart';

void main() {
  const builder = MapGeometryBuilder();

  test('preserves WSI band colors and stroke width', () {
    final geometry = builder.build(
      segments: [
        _segment(0, 'GREEN'),
        _segment(1, 'YELLOW'),
        _segment(2, 'RED'),
      ],
    );

    expect(geometry.polylines.map((line) => line.colorValue), [
      greenWsiColor,
      yellowWsiColor,
      redWsiColor,
    ]);
    expect(
      geometry.polylines.map((line) => line.strokeWidth),
      everyElement(wsiStrokeWidth),
    );
  });

  test('builds 200 nearby segments and three route overlays', () {
    final segments = List.generate(
      200,
      (index) => _segment(index, index.isEven ? 'GREEN' : 'YELLOW'),
    );
    final routes = List.generate(
      3,
      (index) => RouteOverlay(
        id: '$index',
        colorValue: 0xFF000000 + index,
        points: [
          MapCoordinate(34 + index / 1000, -118),
          MapCoordinate(34 + index / 1000, -117.999),
        ],
      ),
    );

    final geometry = builder.build(segments: segments, routes: routes);

    expect(geometry.polylines, hasLength(203));
    expect(
      geometry.polylines.take(200).map((line) => line.id).toSet(),
      hasLength(200),
    );
    expect(geometry.polylines.skip(200).map((line) => line.id), [
      'route-0',
      'route-1',
      'route-2',
    ]);
  });
}

SegmentScore _segment(int index, String band) => SegmentScore(
  segmentId: '$index',
  wsiScore: 80,
  confidence: 0.9,
  colorBand: band,
  startLat: 34 + index / 10000,
  startLng: -118,
  endLat: 34 + index / 10000,
  endLng: -117.999,
);
