import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:halo/core/config/halo_map_config.dart';
import 'package:halo/features/incidents/data/incident_repository.dart';
import 'package:halo/features/incidents/domain/incident.dart';
import 'package:halo/features/route_map/presentation/route_map_screen.dart';

final incidentRepositoryProvider = Provider<IncidentRepository>(
  (ref) => IncidentRepository(),
);

final nearbyIncidentsProvider = FutureProvider.autoDispose<List<Incident>>((
  ref,
) async {
  final center = (await ref.watch(mapLocationProvider.future)).center;
  final queryCenter = haloMapDemo ? defaultMapCenter : center;
  try {
    return await ref
        .watch(incidentRepositoryProvider)
        .fetchNearby(
          lat: queryCenter.latitude,
          lng: queryCenter.longitude,
          radiusMeters: haloMapDemo ? 10000 : 3000,
        );
  } catch (_) {
    return const [];
  }
});

class DisplayedIncident {
  const DisplayedIncident({
    required this.markerId,
    required this.incident,
    required this.latitude,
    required this.longitude,
    required this.isDemoLocation,
  });

  final String markerId;
  final Incident incident;
  final double latitude;
  final double longitude;
  final bool isDemoLocation;
}

final displayedIncidentsProvider =
    FutureProvider.autoDispose<List<DisplayedIncident>>((ref) async {
      final incidents = await ref.watch(nearbyIncidentsProvider.future);
      final center = (await ref.watch(mapLocationProvider.future)).center;
      return projectIncidentsForMap(
        incidents: incidents,
        centerLatitude: haloMapDemo
            ? defaultMapCenter.latitude
            : center.latitude,
        centerLongitude: haloMapDemo
            ? defaultMapCenter.longitude
            : center.longitude,
        demo: haloMapDemo,
      );
    });

List<DisplayedIncident> projectIncidentsForMap({
  required List<Incident> incidents,
  required double centerLatitude,
  required double centerLongitude,
  required bool demo,
}) {
  if (!demo) {
    return [
      for (final incident in incidents)
        DisplayedIncident(
          markerId: incident.incidentId,
          incident: incident,
          latitude: incident.latitude,
          longitude: incident.longitude,
          isDemoLocation: false,
        ),
    ];
  }
  if (incidents.isEmpty) return const [];

  const offsets = [
    (0.0012, -0.0010),
    (-0.0015, 0.0013),
    (0.0045, -0.0075),
    (-0.0080, -0.0035),
  ];
  final displays = [
    for (final incident in incidents)
      DisplayedIncident(
        markerId: incident.incidentId,
        incident: incident,
        latitude: incident.latitude,
        longitude: incident.longitude,
        isDemoLocation: false,
      ),
  ];
  final markerIds = displays.map((display) => display.markerId).toSet();
  for (var index = 0; index < offsets.length; index++) {
    final incident = incidents[index % incidents.length];
    var markerId = 'demo-location-$index-${incident.incidentId}';
    while (!markerIds.add(markerId)) {
      markerId = 'demo-$markerId';
    }
    displays.add(
      DisplayedIncident(
        markerId: markerId,
        incident: incident,
        latitude: centerLatitude + offsets[index].$1,
        longitude: centerLongitude + offsets[index].$2,
        isDemoLocation: true,
      ),
    );
  }
  return displays;
}
