import 'dart:math';
import 'dart:typed_data';

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
    Widget map(MapCoordinate center, int generation) => MaterialApp(
      home: FlutterRouteMap(
        center: center,
        geometry: const MapGeometry(polylines: []),
        showUserLocation: false,
        recenterGeneration: generation,
        mapController: controller,
        tileProvider: _TransparentTileProvider(),
      ),
    );

    await tester.pumpWidget(map(initialCenter, 0));
    controller.move(
      const LatLng(34.0522, -118.2437),
      17,
    );
    await tester.pumpWidget(map(const MapCoordinate(34.06, -118.25), 1));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(controller.camera.center, const LatLng(34.06, -118.25));
    expect(controller.camera.zoom, 17);
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
  static final _transparentPixel = Uint8List.fromList([
    0x89,
    0x50,
    0x4e,
    0x47,
    0x0d,
    0x0a,
    0x1a,
    0x0a,
    0x00,
    0x00,
    0x00,
    0x0d,
    0x49,
    0x48,
    0x44,
    0x52,
    0x00,
    0x00,
    0x00,
    0x01,
    0x00,
    0x00,
    0x00,
    0x01,
    0x08,
    0x06,
    0x00,
    0x00,
    0x00,
    0x1f,
    0x15,
    0xc4,
    0x89,
    0x00,
    0x00,
    0x00,
    0x0d,
    0x49,
    0x44,
    0x41,
    0x54,
    0x08,
    0xd7,
    0x63,
    0xf8,
    0xcf,
    0xc0,
    0x00,
    0x00,
    0x04,
    0x00,
    0x01,
    0x5c,
    0xcd,
    0xff,
    0x55,
    0x00,
    0x00,
    0x00,
    0x00,
    0x49,
    0x45,
    0x4e,
    0x44,
    0xae,
    0x42,
    0x60,
    0x82,
  ]);

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(_transparentPixel);
}
