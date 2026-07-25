enum RoutePreference { environment, shortest }

class RouteCandidate {
  const RouteCandidate({
    required this.id,
    required this.name,
    required this.durationMinutes,
    required this.distanceMiles,
    required this.wsi,
    this.factors = const {},
  });

  final String id;
  final String name;
  final int durationMinutes;
  final double distanceMiles;
  final double wsi;
  final Map<String, String> factors;
}

const mockEnvironmentRoutes = [
  RouteCandidate(
    id: 'balanced',
    name: 'Best environment score',
    durationMinutes: 29,
    distanceMiles: 1.44,
    wsi: 0.82,
    factors: {'unknown': 'hidden'},
  ),
  RouteCandidate(
    id: 'shaded',
    name: 'Balanced alternative',
    durationMinutes: 27,
    distanceMiles: 1.32,
    wsi: 0.66,
    factors: {'low_light': 'true', 'low_activity': 'true'},
  ),
  RouteCandidate(
    id: 'quiet',
    name: 'Alternative route',
    durationMinutes: 26,
    distanceMiles: 1.30,
    wsi: 0.48,
    factors: {'no_safezone': 'true'},
  ),
];

const mockShortestRoutes = [
  RouteCandidate(
    id: 'shortest',
    name: 'Shortest route',
    durationMinutes: 26,
    distanceMiles: 1.29,
    wsi: 0.30,
    factors: {'no_safezone': 'true'},
  ),
];
