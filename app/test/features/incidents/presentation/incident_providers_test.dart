import 'package:flutter_test/flutter_test.dart';
import 'package:halo/features/incidents/domain/incident.dart';
import 'package:halo/features/incidents/presentation/incident_providers.dart';

void main() {
  test('production display preserves every returned coordinate', () {
    final displays = projectIncidentsForMap(
      incidents: [_incident],
      centerLatitude: 34.0522,
      centerLongitude: -118.2437,
      demo: false,
    );

    expect(displays, hasLength(1));
    expect(displays.single.latitude, _incident.latitude);
    expect(displays.single.longitude, _incident.longitude);
    expect(displays.single.markerId, _incident.incidentId);
    expect(displays.single.isDemoLocation, isFalse);
  });

  test('demo retains actual incident and adds four Downtown locations', () {
    final displays = projectIncidentsForMap(
      incidents: [_incident],
      centerLatitude: 34.0522,
      centerLongitude: -118.2437,
      demo: true,
    );

    expect(displays, hasLength(5));
    final actual = displays.first;
    expect(actual.markerId, _incident.incidentId);
    expect(actual.latitude, _incident.latitude);
    expect(actual.longitude, _incident.longitude);
    expect(actual.isDemoLocation, isFalse);

    final projected = displays.skip(1).toList();
    const expected = [
      (34.0534, -118.2447),
      (34.0507, -118.2424),
      (34.0567, -118.2512),
      (34.0442, -118.2472),
    ];
    for (var index = 0; index < projected.length; index++) {
      expect(projected[index].latitude, closeTo(expected[index].$1, 0.0000001));
      expect(
        projected[index].longitude,
        closeTo(expected[index].$2, 0.0000001),
      );
    }
    expect(projected.every((display) => display.isDemoLocation), isTrue);
    expect(displays.map((display) => display.markerId).toSet(), hasLength(5));
    expect(_incident.latitude, 33.9);
    expect(_incident.longitude, -118.4);
  });
}

final _incident = Incident(
  incidentId: 'incident-1',
  category: 'robbery',
  emoji: '🚨',
  title: 'Incident reported',
  description: 'A recent incident was reported.',
  locationType: 'Public space',
  areaName: 'Los Angeles',
  occurredAt: DateTime.utc(2026, 7, 26),
  latitude: 33.9,
  longitude: -118.4,
);
