import 'dart:convert';

import 'package:halo/features/search/domain/recent_search.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class RecentSearchStore {
  Future<List<RecentSearch>> load();

  Future<void> save(List<RecentSearch> searches);
}

class SharedPreferencesRecentSearchStore implements RecentSearchStore {
  SharedPreferencesRecentSearchStore(this.preferences);

  static const storageKey = 'recent_searches';

  final SharedPreferences preferences;

  @override
  Future<List<RecentSearch>> load() async {
    try {
      final encoded = preferences.getString(storageKey);
      if (encoded == null) return const [];
      final decoded = jsonDecode(encoded);
      if (decoded is! List<Object?>) return const [];
      return decoded
          .map(RecentSearch.fromJson)
          .whereType<RecentSearch>()
          .toList();
    } catch (_) {
      await preferences.remove(storageKey);
      return const [];
    }
  }

  @override
  Future<void> save(List<RecentSearch> searches) async {
    final saved = await preferences.setString(
      storageKey,
      jsonEncode(searches.map((search) => search.toJson()).toList()),
    );
    if (!saved) {
      throw StateError('Recent searches could not be saved.');
    }
  }
}

class MemoryRecentSearchStore implements RecentSearchStore {
  List<RecentSearch> _searches = const [];

  @override
  Future<List<RecentSearch>> load() async => List.of(_searches);

  @override
  Future<void> save(List<RecentSearch> searches) async {
    _searches = List.of(searches);
  }
}

class RecentSearchRepository {
  RecentSearchRepository(this.store);

  static const maxSearches = 10;

  final RecentSearchStore store;

  Future<List<RecentSearch>> load() async => _normalize(await store.load());

  Future<List<RecentSearch>> add(RecentSearch search) async {
    final searches = await store.load();
    final identity = _identity(search);
    final updated = _normalize([
      search,
      ...searches.where((item) => _identity(item) != identity),
    ]);
    await store.save(updated);
    return updated;
  }

  List<RecentSearch> _normalize(List<RecentSearch> searches) {
    final seen = <String>{};
    return searches
        .where((search) => seen.add(_identity(search)))
        .take(maxSearches)
        .toList();
  }

  String _identity(RecentSearch search) => search.title.trim().toLowerCase();
}
