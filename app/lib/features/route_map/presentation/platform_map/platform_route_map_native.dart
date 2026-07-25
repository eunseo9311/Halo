import 'dart:async';
import 'dart:ui' as ui;

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
  State<PlatformRouteMap> createState() => _PlatformRouteMapState();
}

class _PlatformRouteMapState extends State<PlatformRouteMap> {
  GoogleMapController? _googleController;
  MapCameraView? _latestCamera;
  final Map<String, BitmapDescriptor> _incidentIcons = {};
  final Set<String> _loadingIncidentIcons = {};
  var _pendingNorthReset = false;

  @override
  void initState() {
    super.initState();
    _loadIncidentIcons();
  }

  @override
  void didUpdateWidget(covariant PlatformRouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadIncidentIcons();
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

  void _loadIncidentIcons() {
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    for (final marker in widget.geometry.markers) {
      if (marker.kind != MapMarkerKind.incident) continue;
      final emoji = incidentMarkerEmoji(marker.label);
      if (_incidentIcons.containsKey(emoji) ||
          !_loadingIncidentIcons.add(emoji)) {
        continue;
      }
      createIncidentMarkerDescriptor(emoji).then((descriptor) {
        _loadingIncidentIcons.remove(emoji);
        if (!mounted) return;
        setState(() => _incidentIcons[emoji] = descriptor);
      });
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
        onMarkerTap: widget.onMarkerTap,
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
            zIndex: line.zIndex,
          ),
      },
      markers: {
        for (final marker in widget.geometry.markers)
          if (marker.kind == MapMarkerKind.destination)
            Marker(
              markerId: MarkerId(marker.id),
              position: LatLng(
                marker.position.latitude,
                marker.position.longitude,
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueRose,
              ),
            ),
        for (final marker in widget.geometry.markers)
          if (marker.kind == MapMarkerKind.incident)
            if (_incidentIcons[incidentMarkerEmoji(marker.label)]
                case final icon?)
              Marker(
                markerId: MarkerId(marker.id),
                position: LatLng(
                  marker.position.latitude,
                  marker.position.longitude,
                ),
                icon: icon,
                infoWindow: InfoWindow(title: marker.label),
                onTap: () => widget.onMarkerTap?.call(marker),
              ),
      },
      circles: {
        for (final marker in widget.geometry.markers)
          if (marker.kind == MapMarkerKind.origin)
            Circle(
              circleId: CircleId(marker.id),
              center: LatLng(
                marker.position.latitude,
                marker.position.longitude,
              ),
              radius: 5,
              fillColor: const Color(0xFF3F91DF),
              strokeColor: const Color(0xFFFFFFFF),
              strokeWidth: 3,
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

@visibleForTesting
Future<BitmapDescriptor> createIncidentMarkerDescriptor(String emoji) async {
  const logicalSize = 44.0;
  const pixelRatio = 3.0;
  const pixelSize = logicalSize * pixelRatio;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const center = Offset(pixelSize / 2, pixelSize / 2);

  canvas.drawCircle(
    center,
    pixelSize / 2 - 3,
    Paint()..color = const Color(0xFFFFFFFF),
  );
  canvas.drawCircle(
    center,
    pixelSize / 2 - 5,
    Paint()
      ..color = const Color(0xFFD93025)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6,
  );
  switch (incidentMarkerSymbol(emoji)) {
    case IncidentMarkerSymbol.warning:
      _drawWarningSymbol(canvas, pixelSize);
    case IncidentMarkerSymbol.emergency:
      _drawEmergencySymbol(canvas, pixelSize);
  }

  final image = await recorder.endRecording().toImage(
    pixelSize.toInt(),
    pixelSize.toInt(),
  );
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (byteData == null) {
    throw StateError('Unable to render incident marker');
  }
  return BitmapDescriptor.bytes(
    byteData.buffer.asUint8List(),
    width: logicalSize,
    height: logicalSize,
  );
}

@visibleForTesting
String incidentMarkerEmoji(String? label) =>
    label?.trim().isNotEmpty ?? false ? label!.trim() : '⚠️';

enum IncidentMarkerSymbol { warning, emergency }

@visibleForTesting
IncidentMarkerSymbol incidentMarkerSymbol(String? label) =>
    label?.contains('🚨') ?? false
    ? IncidentMarkerSymbol.emergency
    : IncidentMarkerSymbol.warning;

void _drawWarningSymbol(Canvas canvas, double size) {
  final triangle = Path()
    ..moveTo(size * 0.5, size * 0.23)
    ..lineTo(size * 0.77, size * 0.72)
    ..lineTo(size * 0.23, size * 0.72)
    ..close();
  canvas.drawPath(
    triangle,
    Paint()
      ..color = const Color(0xFFFFC107)
      ..style = PaintingStyle.fill,
  );
  canvas.drawPath(
    triangle,
    Paint()
      ..color = const Color(0xFF3C2F00)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.045
      ..strokeJoin = StrokeJoin.round,
  );
  final ink = Paint()
    ..color = const Color(0xFF3C2F00)
    ..strokeCap = StrokeCap.round
    ..strokeWidth = size * 0.06;
  canvas.drawLine(
    Offset(size * 0.5, size * 0.4),
    Offset(size * 0.5, size * 0.56),
    ink,
  );
  canvas.drawCircle(Offset(size * 0.5, size * 0.64), size * 0.03, ink);
}

void _drawEmergencySymbol(Canvas canvas, double size) {
  final red = Paint()
    ..color = const Color(0xFFD93025)
    ..strokeCap = StrokeCap.round;
  final dark = Paint()
    ..color = const Color(0xFF6B1711)
    ..strokeCap = StrokeCap.round;

  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTRB(size * 0.32, size * 0.38, size * 0.68, size * 0.68),
      Radius.circular(size * 0.18),
    ),
    red,
  );
  canvas.drawRect(
    Rect.fromLTRB(size * 0.27, size * 0.67, size * 0.73, size * 0.74),
    dark,
  );
  red.strokeWidth = size * 0.045;
  for (final ray in [
    (Offset(size * 0.5, size * 0.18), Offset(size * 0.5, size * 0.3)),
    (Offset(size * 0.24, size * 0.27), Offset(size * 0.32, size * 0.35)),
    (Offset(size * 0.76, size * 0.27), Offset(size * 0.68, size * 0.35)),
    (Offset(size * 0.17, size * 0.48), Offset(size * 0.28, size * 0.48)),
    (Offset(size * 0.83, size * 0.48), Offset(size * 0.72, size * 0.48)),
  ]) {
    canvas.drawLine(ray.$1, ray.$2, red);
  }
}
