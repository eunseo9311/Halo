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
}
