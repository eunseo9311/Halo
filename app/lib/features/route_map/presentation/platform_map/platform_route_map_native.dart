import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:halo/features/route_map/domain/map_geometry.dart';
import 'package:halo/features/route_map/presentation/platform_map/flutter_route_map.dart';
import 'package:halo/features/route_map/presentation/platform_map/map_interactions.dart';

const _androidMapId = String.fromEnvironment('GOOGLE_MAPS_ANDROID_MAP_ID');
const _iosMapId = String.fromEnvironment('GOOGLE_MAPS_IOS_MAP_ID');

class PlatformRouteMap extends StatefulWidget {
  const PlatformRouteMap({
    required this.center,
    required this.geometry,
    required this.showUserLocation,
    required this.recenterGeneration,
    this.onMapTap,
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
  final MapCameraCallback? onCameraMove;
  final MapCameraCallback? onCameraIdle;
  final int northResetGeneration;

  @override
  State<PlatformRouteMap> createState() => _PlatformRouteMapState();
}

class _PlatformRouteMapState extends State<PlatformRouteMap> {
  GoogleMapController? _googleController;
  MapCameraView? _latestCamera;
  var _pendingNorthReset = false;

  @override
  void didUpdateWidget(covariant PlatformRouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final recenterRequested =
        oldWidget.recenterGeneration != widget.recenterGeneration ||
        oldWidget.center.latitude != widget.center.latitude ||
        oldWidget.center.longitude != widget.center.longitude;
    final northResetRequested =
        oldWidget.northResetGeneration != widget.northResetGeneration;
    final controller = _googleController;
    if (controller == null) {
      _pendingNorthReset = _pendingNorthReset || northResetRequested;
    } else {
      if (northResetRequested) {
        final camera =
            _latestCamera ?? MapCameraView(center: widget.center, zoom: 15);
        final target = recenterRequested ? widget.center : camera.center;
        final resetCamera = northResetCameraPosition(
          MapCameraView(center: target, zoom: camera.zoom),
        );
        unawaited(
          controller.animateCamera(CameraUpdate.newCameraPosition(resetCamera)),
        );
      } else if (recenterRequested) {
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
        onMapTap: widget.onMapTap,
        onCameraMove: widget.onCameraMove,
        onCameraIdle: widget.onCameraIdle,
        northResetGeneration: widget.northResetGeneration,
      );
    }

    final mapCenter = LatLng(widget.center.latitude, widget.center.longitude);
    final configuredMapId = switch (defaultTargetPlatform) {
      TargetPlatform.android => _androidMapId,
      TargetPlatform.iOS => _iosMapId,
      _ => '',
    };
    return GoogleMap(
      onMapCreated: (controller) {
        _googleController = controller;
        final latestCenter = widget.center;
        _latestCamera = MapCameraView(center: latestCenter, zoom: 15);
        final pendingNorthReset = _pendingNorthReset;
        _pendingNorthReset = false;
        unawaited(
          controller.moveCamera(
            pendingNorthReset
                ? CameraUpdate.newCameraPosition(
                    northResetCameraPosition(_latestCamera!),
                  )
                : CameraUpdate.newLatLng(
                    LatLng(latestCenter.latitude, latestCenter.longitude),
                  ),
          ),
        );
      },
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
      onTap: (point) =>
          widget.onMapTap?.call(MapCoordinate(point.latitude, point.longitude)),
      onCameraMove: (position) {
        final camera = MapCameraView(
          center: MapCoordinate(
            position.target.latitude,
            position.target.longitude,
          ),
          zoom: position.zoom,
        );
        _latestCamera = camera;
        widget.onCameraMove?.call(camera);
      },
      onCameraIdle: () {
        final camera = _latestCamera;
        if (camera != null) widget.onCameraIdle?.call(camera);
      },
      // Use the native location puck so its size and accuracy indication remain
      // correct across zoom levels. Location permission is requested upstream.
      myLocationButtonEnabled: false,
      myLocationEnabled: widget.showUserLocation,
      zoomControlsEnabled: false,
    );
  }
}

CameraPosition northResetCameraPosition(MapCameraView camera) => CameraPosition(
  target: LatLng(camera.center.latitude, camera.center.longitude),
  zoom: camera.zoom,
  bearing: 0,
  tilt: 0,
);
