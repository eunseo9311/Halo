import 'package:go_router/go_router.dart';
import 'package:halo/features/route_map/presentation/route_map_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const RouteMapScreen(),
    ),
    // Future routes:
    // GoRoute(path: '/score/:segmentId', builder: ...),
    // GoRoute(path: '/settings', builder: ...),
  ],
);
