import 'package:halo/features/route_map/domain/map_geometry.dart';

class MapCameraView {
  const MapCameraView({required this.center, required this.zoom});

  final MapCoordinate center;
  final double zoom;
}

typedef MapTapCallback = void Function(MapCoordinate coordinate);
typedef MapCameraCallback = void Function(MapCameraView camera);

/// Retains only the newest recenter request until a map controller is ready.
class PendingMapCenter {
  MapCoordinate? _center;

  void schedule(MapCoordinate center) => _center = center;

  MapCoordinate? take() {
    final center = _center;
    _center = null;
    return center;
  }
}
