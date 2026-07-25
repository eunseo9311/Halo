import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo/features/incidents/data/incident_repository.dart';

void main() {
  test(
    'requests nearby incidents and parses valid entries defensively',
    () async {
      RequestOptions? request;
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              request = options;
              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'data': [
                      _incidentJson(),
                      {'incidentId': 'incomplete'},
                      'not-an-object',
                    ],
                  },
                ),
              );
            },
          ),
        );

      final incidents = await IncidentRepository(
        dio: dio,
      ).fetchNearby(lat: 34.02, lng: -118.28);

      expect(request?.path, '/api/v1/incidents');
      expect(request?.queryParameters, {
        'lat': 34.02,
        'lng': -118.28,
        'radiusMeters': 3000,
      });
      expect(incidents, hasLength(1));
      expect(incidents.single.incidentId, 'incident-1');
      expect(
        incidents.single.occurredAt,
        DateTime.parse('2026-07-26T10:30:00Z'),
      );
      expect(incidents.single.latitude, 34.021);
    },
  );

  test('returns empty results for an unexpected response shape', () async {
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: {'data': 'unexpected'},
            ),
          ),
        ),
      );

    final incidents = await IncidentRepository(
      dio: dio,
    ).fetchNearby(lat: 34, lng: -118);

    expect(incidents, isEmpty);
  });
}

Map<String, dynamic> _incidentJson() => {
  'incidentId': 'incident-1',
  'category': 'robbery',
  'emoji': '🚨',
  'title': 'Sidewalk hazard',
  'description': 'Temporary obstruction reported nearby.',
  'locationType': 'Public space',
  'areaName': 'South LA',
  'occurredAt': '2026-07-26T10:30:00Z',
  'latitude': 34.021,
  'longitude': -118.281,
};
