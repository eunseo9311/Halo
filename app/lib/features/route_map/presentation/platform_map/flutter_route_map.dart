import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:halo/features/route_map/domain/map_geometry.dart';
import 'package:latlong2/latlong.dart';

class FlutterRouteMap extends StatefulWidget {
  const FlutterRouteMap({
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
  State<FlutterRouteMap> createState() => _FlutterRouteMapState();
}

class _FlutterRouteMapState extends State<FlutterRouteMap> {
  final MapController _controller = MapController();

  @override
  void didUpdateWidget(covariant FlutterRouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recenterGeneration != widget.recenterGeneration ||
        oldWidget.center.latitude != widget.center.latitude ||
        oldWidget.center.longitude != widget.center.longitude) {
      _controller.move(
        LatLng(widget.center.latitude, widget.center.longitude),
        _controller.camera.zoom,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FlutterMap(
    mapController: _controller,
    options: MapOptions(
      initialCenter: LatLng(widget.center.latitude, widget.center.longitude),
      initialZoom: 15,
    ),
    children: [
      TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'com.safesoundla.halo',
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
      if (widget.showUserLocation)
        MarkerLayer(
          markers: [
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
