import 'package:dio/dio.dart';
import 'package:halo/core/network/api_client.dart';
import 'package:halo/features/incidents/domain/incident.dart';

class IncidentRepository {
  IncidentRepository({Dio? dio}) : _dio = dio ?? ApiClient.instance;

  final Dio _dio;

  Future<List<Incident>> fetchNearby({
    required double lat,
    required double lng,
    int radiusMeters = 3000,
  }) async {
    final response = await _dio.get<dynamic>(
      '/api/v1/incidents',
      queryParameters: {'lat': lat, 'lng': lng, 'radiusMeters': radiusMeters},
    );
    final body = response.data;
    final rawItems = body is Map<String, dynamic> ? body['data'] : null;
    if (rawItems is! List) return const [];

    return rawItems
        .whereType<Map>()
        .map((item) => Incident.tryFromJson(Map<String, dynamic>.from(item)))
        .whereType<Incident>()
        .toList();
  }
}
