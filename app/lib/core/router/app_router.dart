import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:halo/core/config/halo_map_config.dart';
import 'package:halo/features/home/presentation/home_screen.dart';
import 'package:halo/features/search/data/recent_search_store.dart';
import 'package:halo/features/search/domain/recent_search.dart';
import 'package:halo/features/search/presentation/route_selection_placeholder_screen.dart';
import 'package:halo/features/search/presentation/search_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SharedPreferences>? _sharedPreferencesFuture;

Future<SharedPreferences> _loadSharedPreferences() =>
    _sharedPreferencesFuture ??= SharedPreferences.getInstance();

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
      builder: (context, state) {
        void goBack() => context.canPop() ? context.pop() : context.go('/');
        void select(RecentSearch destination) =>
            context.push('/route-selection', extra: destination);
        if (haloMapDemo) {
          return SearchScreen(
            repository: RecentSearchRepository(MemoryRecentSearchStore()),
            demoMode: true,
            onBack: goBack,
            onSelected: select,
          );
        }
        return FutureBuilder<SharedPreferences>(
          future: _loadSharedPreferences(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Scaffold(
                backgroundColor: Colors.white,
                body: Center(
                  child: TextButton(
                    onPressed: goBack,
                    child: const Text('Search unavailable. Go back'),
                  ),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Scaffold(
                backgroundColor: Colors.white,
                body: Center(child: CircularProgressIndicator()),
              );
            }
            return SearchScreen(
              repository: RecentSearchRepository(
                SharedPreferencesRecentSearchStore(snapshot.data!),
              ),
              onBack: goBack,
              onSelected: select,
            );
          },
        );
      },
    ),
    GoRoute(
      path: '/route-selection',
      builder: (context, state) {
        final destination = switch (state.extra) {
          final RecentSearch search => search,
          _ => const RecentSearch(title: 'Destination', address: ''),
        };
        return RouteSelectionPlaceholderScreen(destination: destination);
      },
    ),
    // Future routes:
    // GoRoute(path: '/score/:segmentId', builder: ...),
    // GoRoute(path: '/settings', builder: ...),
  ],
);
