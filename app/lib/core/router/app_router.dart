import 'package:go_router/go_router.dart';
import 'package:halo/features/home/presentation/home_screen.dart';
import 'package:halo/features/home/presentation/search_placeholder_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => HomeScreen(
        onSearch: () => context.push('/search'),
        onDirections: () => context.push('/search'),
      ),
    ),
    GoRoute(
      path: '/search',
      builder: (context, state) => const SearchPlaceholderScreen(),
    ),
    // Future routes:
    // GoRoute(path: '/score/:segmentId', builder: ...),
    // GoRoute(path: '/settings', builder: ...),
  ],
);
