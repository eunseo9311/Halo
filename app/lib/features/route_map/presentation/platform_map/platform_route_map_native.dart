import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:halo/features/route_map/domain/map_geometry.dart';
import 'package:halo/features/route_map/presentation/platform_map/flutter_route_map.dart';

const _androidMapId = String.fromEnvironment('GOOGLE_MAPS_ANDROID_MAP_ID');
const _iosMapId = String.fromEnvironment('GOOGLE_MAPS_IOS_MAP_ID');

class PlatformRouteMap extends StatefulWidget {
  const PlatformRouteMap({
    required this.center,
    required this.geometry,
    required this.showUserLocation,
    required this.recenterGeneration,
    super.key,
  });

  final MapCoordinate center;
  final MapGeometry geometry;
  final bool showUserLocation;
  final int recenterGeneration;

  @override
  State<PlatformRouteMap> createState() => _PlatformRouteMapState();
}

class _PlatformRouteMapState extends State<PlatformRouteMap> {
  GoogleMapController? _googleController;

  @override
  void didUpdateWidget(covariant PlatformRouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recenterGeneration != widget.recenterGeneration ||
        oldWidget.center.latitude != widget.center.latitude ||
        oldWidget.center.longitude != widget.center.longitude) {
      final controller = _googleController;
      if (controller != null) {
        unawaited(
          controller.animateCamera(
            CameraUpdate.newLatLng(
              LatLng(widget.center.latitude, widget.center.longitude),
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _googleController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return FlutterRouteMap(
        center: widget.center,
        geometry: widget.geometry,
        showUserLocation: widget.showUserLocation,
        recenterGeneration: widget.recenterGeneration,
      );
    }

    final mapCenter = LatLng(widget.center.latitude, widget.center.longitude);
    final configuredMapId = switch (defaultTargetPlatform) {
      TargetPlatform.android => _androidMapId,
      TargetPlatform.iOS => _iosMapId,
      _ => '',
    };
    return GoogleMap(
      onMapCreated: (controller) => _googleController = controller,
      initialCameraPosition: CameraPosition(target: mapCenter, zoom: 15),
      mapId: configuredMapId.isEmpty ? null : configuredMapId,
      polylines: {
        for (final line in widget.geometry.polylines)
          Polyline(
            polylineId: PolylineId(line.id),
            points: [
              for (final point in line.points)
                LatLng(point.latitude, point.longitude),
            ],
            color: Color(line.colorValue),
            width: line.strokeWidth.round(),
          ),
      },
      // Use the native location puck so its size and accuracy indication remain
      // correct across zoom levels. Location permission is requested upstream.
      myLocationButtonEnabled: false,
      myLocationEnabled: widget.showUserLocation,
      zoomControlsEnabled: false,
    );
  }
}
