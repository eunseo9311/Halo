import 'package:dio/dio.dart';
import 'package:halo/core/network/api_client.dart';

/// Data model matching the Spring Boot SegmentScoreResponse DTO.
class SegmentScore {
  /// Used when the server does not report confidence; `0.0` means unknown.
  static const double defaultConfidence = 0.0;

  const SegmentScore({
    required this.segmentId,
    required this.wsiScore,
    required this.confidence,
    required this.colorBand,
    required this.startLat,
    required this.startLng,
    required this.endLat,
    required this.endLng,
  });

  final String segmentId;
  final double wsiScore;
  final double confidence;
  final String colorBand; // 'GREEN' | 'YELLOW' | 'RED'
  final double startLat;
  final double startLng;
  final double endLat;
  final double endLng;

  factory SegmentScore.fromJson(Map<String, dynamic> json) => SegmentScore(
    segmentId: json['segmentId'] as String,
    wsiScore: (json['wsiScore'] as num).toDouble(),
    confidence: (json['confidence'] as num?)?.toDouble() ?? defaultConfidence,
    colorBand: json['colorBand'] as String,
    startLat: (json['startLat'] as num).toDouble(),
    startLng: (json['startLng'] as num).toDouble(),
    endLat: (json['endLat'] as num).toDouble(),
    endLng: (json['endLng'] as num).toDouble(),
  );
}

class SegmentRepository {
  final Dio _dio;

  SegmentRepository({Dio? dio}) : _dio = dio ?? ApiClient.instance;

  Future<List<SegmentScore>> fetchNearby({
    required double lat,
    required double lng,
    int radiusMeters = 200,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/segments/scores',
      queryParameters: {'lat': lat, 'lng': lng, 'radiusMeters': radiusMeters},
    );
    final data = response.data?['data'] as List<dynamic>? ?? [];
    return data
        .cast<Map<String, dynamic>>()
        .map(SegmentScore.fromJson)
        .toList();
  }
}
