import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo/features/route_map/domain/map_geometry.dart';
import 'package:halo/features/route_map/presentation/platform_map/flutter_route_map.dart';
import 'package:halo/features/route_map/presentation/platform_map/map_interactions.dart';
import 'package:latlong2/latlong.dart';

void main() {
  const initialCenter = MapCoordinate(34.0522, -118.2437);

  testWidgets('forwards tap, camera move, and camera idle callbacks', (
    tester,
  ) async {
    MapCoordinate? tapped;
    MapCameraView? moved;
    MapCameraView? idle;
    var idleCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: FlutterRouteMap(
          center: initialCenter,
          geometry: const MapGeometry(polylines: []),
          showUserLocation: false,
          recenterGeneration: 0,
          tileProvider: _TransparentTileProvider(),
          onMapTap: (coordinate) => tapped = coordinate,
          onCameraMove: (camera) => moved = camera,
          onCameraIdle: (camera) {
            idle = camera;
            idleCount++;
          },
        ),
      ),
    );

    final options = tester.widget<FlutterMap>(find.byType(FlutterMap)).options;
    const tapPoint = LatLng(34.05, -118.24);
    options.onTap!(const TapPosition(Offset.zero, Offset.zero), tapPoint);

    final camera = MapCamera(
      crs: const Epsg3857(),
      center: const LatLng(34.051, -118.241),
      zoom: 16,
      rotation: 0,
      nonRotatedSize: const Point(400, 800),
    );
    options.onPositionChanged!(
      MapCamera(
        crs: const Epsg3857(),
        center: const LatLng(34.0505, -118.2405),
        zoom: 15.5,
        rotation: 10,
        nonRotatedSize: const Point(400, 800),
      ),
      true,
    );
    options.onPositionChanged!(camera, true);
    await tester.pump(const Duration(milliseconds: 101));

    expect(tapped?.latitude, tapPoint.latitude);
    expect(tapped?.longitude, tapPoint.longitude);
    expect(moved?.center.latitude, camera.center.latitude);
    expect(moved?.zoom, camera.zoom);
    expect(idle?.center.longitude, camera.center.longitude);
    expect(idle?.zoom, camera.zoom);
    expect(idleCount, 1);
  });

  testWidgets('ready recenter preserves current zoom', (tester) async {
    final controller = MapController();
    Widget map(MapCoordinate center, int generation, {int northReset = 0}) =>
        MaterialApp(
          home: FlutterRouteMap(
            center: center,
            geometry: const MapGeometry(polylines: []),
            showUserLocation: false,
            recenterGeneration: generation,
            northResetGeneration: northReset,
            mapController: controller,
            tileProvider: _TransparentTileProvider(),
          ),
        );

    await tester.pumpWidget(map(initialCenter, 0));
    controller.move(const LatLng(34.0522, -118.2437), 17);
    await tester.pumpWidget(map(const MapCoordinate(34.06, -118.25), 1));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(controller.camera.center, const LatLng(34.06, -118.25));
    expect(controller.camera.zoom, 17);
    controller.rotate(42);

    await tester.pumpWidget(
      map(const MapCoordinate(34.06, -118.25), 1, northReset: 1),
    );
    await tester.pump();

    expect(controller.camera.center, const LatLng(34.06, -118.25));
    expect(controller.camera.zoom, 17);
    expect(controller.camera.rotation, 0);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  test('pending recenter keeps only the latest center', () {
    final pending = PendingMapCenter()
      ..schedule(initialCenter)
      ..schedule(const MapCoordinate(34.06, -118.25));

    final latest = pending.take();

    expect(latest?.latitude, 34.06);
    expect(latest?.longitude, -118.25);
    expect(pending.take(), isNull);
  });
}

class _TransparentTileProvider extends TileProvider {
  static final _transparentPixel = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
    '+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  );

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(_transparentPixel);
}
