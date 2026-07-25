import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:halo/features/route_map/domain/map_geometry.dart';
import 'package:halo/features/route_map/presentation/platform_map/map_interactions.dart';
import 'package:latlong2/latlong.dart';

class FlutterRouteMap extends StatefulWidget {
  const FlutterRouteMap({
    required this.center,
    required this.geometry,
    required this.showUserLocation,
    required this.recenterGeneration,
    this.onMapTap,
    this.onCameraMove,
    this.onCameraIdle,
    this.mapController,
    this.tileProvider,
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
  final MapController? mapController;
  final TileProvider? tileProvider;
  final int northResetGeneration;

  @override
  State<FlutterRouteMap> createState() => _FlutterRouteMapState();
}

class _FlutterRouteMapState extends State<FlutterRouteMap> {
  late final MapController _controller;
  late final bool _ownsController;
  final _pendingCenter = PendingMapCenter();
  var _mapReady = false;
  var _pendingNorthReset = false;
  Timer? _idleTimer;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.mapController == null;
    _controller = widget.mapController ?? MapController();
  }

  @override
  void didUpdateWidget(covariant FlutterRouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recenterGeneration != widget.recenterGeneration ||
        oldWidget.center.latitude != widget.center.latitude ||
        oldWidget.center.longitude != widget.center.longitude) {
      final center = LatLng(widget.center.latitude, widget.center.longitude);
      if (_mapReady) {
        _controller.move(center, _controller.camera.zoom);
      } else {
        _pendingCenter.schedule(widget.center);
      }
    }
    if (oldWidget.northResetGeneration != widget.northResetGeneration) {
      if (_mapReady) {
        _controller.rotate(0);
      } else {
        _pendingNorthReset = true;
      }
    }
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  void _notifyCameraChanged(MapCamera camera) {
    final view = MapCameraView(
      center: MapCoordinate(camera.center.latitude, camera.center.longitude),
      zoom: camera.zoom,
    );
    widget.onCameraMove?.call(view);
    _idleTimer?.cancel();
    _idleTimer = Timer(
      const Duration(milliseconds: 100),
      () => widget.onCameraIdle?.call(view),
    );
  }

  @override
  Widget build(BuildContext context) => FlutterMap(
    mapController: _controller,
    options: MapOptions(
      initialCenter: LatLng(widget.center.latitude, widget.center.longitude),
      initialZoom: 15,
      onMapReady: () {
        _mapReady = true;
        final pendingCenter = _pendingCenter.take();
        if (pendingCenter != null) {
          _controller.move(
            LatLng(pendingCenter.latitude, pendingCenter.longitude),
            _controller.camera.zoom,
          );
        }
        if (_pendingNorthReset) {
          _pendingNorthReset = false;
          _controller.rotate(0);
        }
      },
      onTap: (_, point) =>
          widget.onMapTap?.call(MapCoordinate(point.latitude, point.longitude)),
      onPositionChanged: (camera, _) => _notifyCameraChanged(camera),
    ),
    children: [
      TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'com.safesoundla.halo',
        tileProvider: widget.tileProvider,
      ),
      PolylineLayer(
        polylines: [
          for (final line in widget.geometry.polylines)
            Polyline(
              points: [
                for (final point in line.points)
                  LatLng(point.latitude, point.longitude),
              ],
              color: Color(line.colorValue),
              strokeWidth: line.strokeWidth,
            ),
        ],
      ),
      if (widget.showUserLocation || widget.geometry.markers.isNotEmpty)
        MarkerLayer(
          markers: [
            for (final marker in widget.geometry.markers)
              Marker(
                point: LatLng(
                  marker.position.latitude,
                  marker.position.longitude,
                ),
                width: marker.kind == MapMarkerKind.destination ? 38 : 24,
                height: marker.kind == MapMarkerKind.destination ? 44 : 24,
                alignment: marker.kind == MapMarkerKind.destination
                    ? Alignment.bottomCenter
                    : Alignment.center,
                child: marker.kind == MapMarkerKind.destination
                    ? const Icon(
                        Icons.location_on,
                        size: 38,
                        color: Color(0xFF542323),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF3F91DF),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 4),
                          ],
                        ),
                      ),
              ),
            if (widget.showUserLocation)
              Marker(
                point: LatLng(widget.center.latitude, widget.center.longitude),
                width: 20,
                height: 20,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 4),
                    ],
                  ),
                ),
              ),
          ],
        ),
      const RichAttributionWidget(
        attributions: [TextSourceAttribution('OpenStreetMap contributors')],
      ),
    ],
  );
}
