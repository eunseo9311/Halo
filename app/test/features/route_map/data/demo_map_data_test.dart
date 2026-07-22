import 'package:flutter_test/flutter_test.dart';
import 'package:halo/features/route_map/data/demo_map_data.dart';
import 'package:halo/features/route_map/domain/map_geometry.dart';

void main() {
  test('demo data is deterministic and complete', () {
    final first = buildDemoMapData();
    final second = buildDemoMapData();

    expect(first.segments, hasLength(200));
    expect(first.routes, hasLength(3));
    expect(
      first.segments.map((segment) => segment.segmentId),
      second.segments.map((segment) => segment.segmentId),
    );
    expect(first.segments.map((segment) => segment.colorBand).toSet(), {
      'GREEN',
      'YELLOW',
      'RED',
    });

    final geometry = const MapGeometryBuilder().build(
      segments: first.segments,
      routes: first.routes,
    );
    expect(geometry.polylines, hasLength(203));
    expect(
      geometry.polylines.map((line) => line.strokeWidth),
      everyElement(wsiStrokeWidth),
    );
  });
}
