import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo/core/config/halo_map_config.dart';
import 'package:halo/features/route_map/presentation/route_map_screen.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('map location provider uses the location loader', () async {
    const simulatorLocation = MapLocationState(
      center: LatLng(34.0219, -118.4814),
      hasLocationFix: true,
    );
    var loadCount = 0;
    final container = ProviderContainer(
      overrides: [
        mapLocationLoaderProvider.overrideWithValue(() async {
          loadCount++;
          return simulatorLocation;
        }),
      ],
    );
    addTearDown(container.dispose);

    final location = await container.read(mapLocationProvider.future);

    expect(loadCount, 1);
    expect(location.center, simulatorLocation.center);
    expect(location.hasLocationFix, isTrue);
  });

  test(
    'demo mode keeps demo scores and routes independent of location',
    () async {
      const simulatorLocation = MapLocationState(
        center: LatLng(34.0219, -118.4814),
        hasLocationFix: true,
      );
      final container = ProviderContainer(
        overrides: [
          mapLocationLoaderProvider.overrideWithValue(
            () async => simulatorLocation,
          ),
        ],
      );
      addTearDown(container.dispose);

      final location = await container.read(mapLocationProvider.future);
      final segments = await container.read(segmentScoresProvider.future);
      final routes = container.read(routeOverlaysProvider);

      expect(location.hasLocationFix, isTrue);
      expect(location.center, simulatorLocation.center);
      expect(segments, hasLength(200));
      expect(routes, hasLength(3));
    },
    skip: !haloMapDemo,
  );
}
