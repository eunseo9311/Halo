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
    durationMinutes: 5,
    distanceMiles: 0.30,
    wsi: 0.78,
    factors: {'unknown': 'hidden'},
  ),
  RouteCandidate(
    id: 'shaded',
    name: 'Balanced alternative',
    durationMinutes: 4,
    distanceMiles: 0.25,
    wsi: 0.58,
    factors: {'low_light': 'true', 'low_activity': 'true'},
  ),
  RouteCandidate(
    id: 'quiet',
    name: 'Fast alternative',
    durationMinutes: 3,
    distanceMiles: 0.18,
    wsi: 0.42,
    factors: {'no_safezone': 'true'},
  ),
];

const mockShortestRoutes = [
  RouteCandidate(
    id: 'shortest',
    name: 'Shortest route',
    durationMinutes: 3,
    distanceMiles: 0.18,
    wsi: 0.42,
    factors: {'no_safezone': 'true'},
  ),
];
