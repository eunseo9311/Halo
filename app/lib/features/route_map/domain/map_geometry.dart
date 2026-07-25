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
    this.zIndex = 0,
  });

  final String id;
  final List<MapCoordinate> points;
  final int colorValue;
  final double strokeWidth;
  final int zIndex;
}

class MapPolyline {
  const MapPolyline({
    required this.id,
    required this.points,
    required this.colorValue,
    required this.strokeWidth,
    this.zIndex = 0,
  });

  final String id;
  final List<MapCoordinate> points;
  final int colorValue;
  final double strokeWidth;
  final int zIndex;
}

enum MapMarkerKind { origin, destination, incident }

class MapMarker {
  const MapMarker({
    required this.id,
    required this.position,
    required this.kind,
    this.label,
  });

  final String id;
  final MapCoordinate position;
  final MapMarkerKind kind;
  final String? label;
}

class MapGeometry {
  const MapGeometry({required this.polylines, this.markers = const []});

  final List<MapPolyline> polylines;
  final List<MapMarker> markers;
}

class MapGeometryBuilder {
  const MapGeometryBuilder();

  MapGeometry build({
    required Iterable<SegmentScore> segments,
    Iterable<RouteOverlay> routes = const [],
    Iterable<MapMarker> markers = const [],
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
          zIndex: route.zIndex,
        ),
    ];

    return MapGeometry(
      polylines: List.unmodifiable(polylines),
      markers: List.unmodifiable(markers),
    );
  }
}

int colorValueForBand(String band) => switch (band) {
  'GREEN' => greenWsiColor,
  'YELLOW' => yellowWsiColor,
  _ => redWsiColor,
};
