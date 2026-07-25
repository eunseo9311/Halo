import 'package:flutter/widgets.dart';
import 'package:halo/features/route_map/domain/map_geometry.dart';
import 'package:halo/features/route_map/presentation/platform_map/flutter_route_map.dart';
import 'package:halo/features/route_map/presentation/platform_map/map_interactions.dart';

class PlatformRouteMap extends StatelessWidget {
  const PlatformRouteMap({
    required this.center,
    required this.geometry,
    required this.showUserLocation,
    required this.recenterGeneration,
    this.onMapTap,
    this.onMarkerTap,
    this.onCameraMove,
    this.onCameraIdle,
    this.northResetGeneration = 0,
    super.key,
  });

  final MapCoordinate center;
  final MapGeometry geometry;
  final bool showUserLocation;
  final int recenterGeneration;
  final MapTapCallback? onMapTap;
  final MapMarkerTapCallback? onMarkerTap;
  final MapCameraCallback? onCameraMove;
  final MapCameraCallback? onCameraIdle;
  final int northResetGeneration;

  @override
  Widget build(BuildContext context) => FlutterRouteMap(
    center: center,
    geometry: geometry,
    showUserLocation: showUserLocation,
    recenterGeneration: recenterGeneration,
    onMapTap: onMapTap,
    onMarkerTap: onMarkerTap,
    onCameraMove: onCameraMove,
    onCameraIdle: onCameraIdle,
    northResetGeneration: northResetGeneration,
  );
}
