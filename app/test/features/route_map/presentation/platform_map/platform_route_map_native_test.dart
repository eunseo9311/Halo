import 'package:flutter_test/flutter_test.dart';
import 'package:halo/features/route_map/domain/map_geometry.dart';
import 'package:halo/features/route_map/presentation/platform_map/map_interactions.dart';
import 'package:halo/features/route_map/presentation/platform_map/platform_route_map_native.dart';

void main() {
  test('north reset camera preserves center and zoom', () {
    final position = northResetCameraPosition(
      const MapCameraView(
        center: MapCoordinate(34.0522, -118.2437),
        zoom: 17.5,
      ),
    );

    expect(position.target.latitude, 34.0522);
    expect(position.target.longitude, -118.2437);
    expect(position.zoom, 17.5);
    expect(position.bearing, 0);
    expect(position.tilt, 0);
  });

  test('incident marker uses its emoji with a clear warning fallback', () {
    expect(incidentMarkerEmoji('🚨'), '🚨');
    expect(incidentMarkerEmoji('  ⚠️  '), '⚠️');
    expect(incidentMarkerEmoji(''), '⚠️');
    expect(incidentMarkerEmoji(null), '⚠️');
  });

  test('incident marker symbol classification is deterministic', () {
    expect(incidentMarkerSymbol('🚨'), IncidentMarkerSymbol.emergency);
    expect(incidentMarkerSymbol('⚠️'), IncidentMarkerSymbol.warning);
    expect(incidentMarkerSymbol(''), IncidentMarkerSymbol.warning);
    expect(incidentMarkerSymbol(null), IncidentMarkerSymbol.warning);
  });
}
