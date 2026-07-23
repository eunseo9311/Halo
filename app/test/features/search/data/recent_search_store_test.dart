import 'package:flutter_test/flutter_test.dart';
import 'package:halo/features/search/data/recent_search_store.dart';
import 'package:halo/features/search/domain/recent_search.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const first = RecentSearch(title: 'First', address: '1 Main St');
  const second = RecentSearch(title: 'Second', address: '2 Main St');

  test('shared preferences store safely round-trips searches', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesRecentSearchStore(preferences);

    await store.save([first, second]);

    expect(await store.load(), [first, second]);
  });

  test('shared preferences store returns empty for corrupt data', () async {
    SharedPreferences.setMockInitialValues({
      SharedPreferencesRecentSearchStore.storageKey: '{not valid json',
    });
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesRecentSearchStore(preferences);

    expect(await store.load(), isEmpty);
  });

  test('repository moves duplicate search to the front', () async {
    final store = _MemoryRecentSearchStore([first, second]);
    final repository = RecentSearchRepository(store);

    final searches = await repository.add(first);

    expect(searches, [first, second]);
    expect(store.saved, [first, second]);
  });

  test('repository keeps at most ten most recent searches', () async {
    final existing = List.generate(
      10,
      (index) => RecentSearch(title: 'Place $index', address: '$index'),
    );
    final store = _MemoryRecentSearchStore(existing);
    final repository = RecentSearchRepository(store);
    const newest = RecentSearch(title: 'Newest', address: 'New address');

    final searches = await repository.add(newest);

    expect(searches, hasLength(10));
    expect(searches.first, newest);
    expect(searches, isNot(contains(existing.last)));
  });
}

class _MemoryRecentSearchStore implements RecentSearchStore {
  _MemoryRecentSearchStore(this.values);

  List<RecentSearch> values;
  List<RecentSearch>? saved;

  @override
  Future<List<RecentSearch>> load() async => List.of(values);

  @override
  Future<void> save(List<RecentSearch> searches) async {
    saved = List.of(searches);
    values = List.of(searches);
  }
}
