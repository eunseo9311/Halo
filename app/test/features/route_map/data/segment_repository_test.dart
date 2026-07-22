import 'package:flutter_test/flutter_test.dart';
import 'package:halo/features/route_map/data/segment_repository.dart';

void main() {
  test('defaults omitted confidence to unknown', () {
    final score = SegmentScore.fromJson(_scoreJson());

    expect(score.confidence, SegmentScore.defaultConfidence);
  });

  test('preserves confidence supplied by the server', () {
    final score = SegmentScore.fromJson(_scoreJson(confidence: 0.84));

    expect(score.confidence, 0.84);
  });
}

Map<String, dynamic> _scoreJson({double? confidence}) => {
  'segmentId': 'segment-1',
  'wsiScore': 0.72,
  'confidence': ?confidence,
  'colorBand': 'GREEN',
  'startLat': 34.0522,
  'startLng': -118.2437,
  'endLat': 34.0523,
  'endLng': -118.2436,
};
