import 'package:halo/features/route_map/data/segment_repository.dart';

const int greenWsiColor = 0xFF4CAF50;
const int yellowWsiColor = 0xFFFFC107;
const int redWsiColor = 0xFFF44336;
const double wsiStrokeWidth = 5;

class MapCoordinate {
  const MapCoordinate(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

class RouteOverlay {
  const RouteOverlay({
    required this.id,
    required this.points,
    required this.colorValue,
    this.strokeWidth = 5,
  });

  final String id;
  final List<MapCoordinate> points;
  final int colorValue;
  final double strokeWidth;
}

class MapPolyline {
  const MapPolyline({
    required this.id,
    required this.points,
    required this.colorValue,
    required this.strokeWidth,
  });

  final String id;
  final List<MapCoordinate> points;
  final int colorValue;
  final double strokeWidth;
}

class MapGeometry {
  const MapGeometry({required this.polylines});

  final List<MapPolyline> polylines;
}

class MapGeometryBuilder {
  const MapGeometryBuilder();

  MapGeometry build({
    required Iterable<SegmentScore> segments,
    Iterable<RouteOverlay> routes = const [],
  }) {
    final polylines = <MapPolyline>[
      for (final segment in segments)
        MapPolyline(
          id: 'segment-${segment.segmentId}',
          points: [
            MapCoordinate(segment.startLat, segment.startLng),
            MapCoordinate(segment.endLat, segment.endLng),
          ],
          colorValue: colorValueForBand(segment.colorBand),
          strokeWidth: wsiStrokeWidth,
        ),
      for (final route in routes)
        MapPolyline(
          id: 'route-${route.id}',
          points: route.points,
          colorValue: route.colorValue,
          strokeWidth: route.strokeWidth,
        ),
    ];

    return MapGeometry(polylines: List.unmodifiable(polylines));
  }
}

int colorValueForBand(String band) => switch (band) {
  'GREEN' => greenWsiColor,
  'YELLOW' => yellowWsiColor,
  _ => redWsiColor,
};
