import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo/features/search/data/recent_search_store.dart';
import 'package:halo/features/search/domain/recent_search.dart';
import 'package:halo/features/search/presentation/search_screen.dart';

void main() {
  Widget buildSearch({
    List<RecentSearch> searches = const [],
    bool demoMode = false,
    VoidCallback? onBack,
    SearchSelectionCallback? onSelected,
    _RecordingStore? store,
  }) {
    final effectiveStore = store ?? _RecordingStore(searches);
    return MaterialApp(
      home: SearchScreen(
        repository: RecentSearchRepository(effectiveStore),
        demoMode: demoMode,
        onBack: onBack ?? () {},
        onSelected: onSelected ?? (_) {},
      ),
    );
  }

  testWidgets('production empty state has no fake recent searches', (
    tester,
  ) async {
    await tester.pumpWidget(buildSearch());
    await tester.pumpAndSettle();

    expect(find.text('No recent searches'), findsOneWidget);
    expect(find.text('USC Village'), findsNothing);
  });

  testWidgets('demo mode shows deterministic rows without using persistence', (
    tester,
  ) async {
    final store = _RecordingStore(const []);
    await tester.pumpWidget(buildSearch(demoMode: true, store: store));
    await tester.pumpAndSettle();

    expect(find.text('USC Village'), findsOneWidget);
    expect(find.text('Cafe Dulce (USC Village)'), findsOneWidget);
    expect(find.text('Zumberge Hall of Science'), findsOneWidget);
    expect(find.text('Chipotle'), findsOneWidget);
    expect(store.loadCount, 0);
    expect(store.saveCount, 0);
  });

  testWidgets('search field autofocuses and back button invokes callback', (
    tester,
  ) async {
    var backCount = 0;
    await tester.pumpWidget(buildSearch(onBack: () => backCount++));
    await tester.pumpAndSettle();

    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.focusNode.hasFocus, isTrue);

    await tester.tap(find.byKey(const Key('search-back-button')));
    expect(backCount, 1);
  });

  testWidgets('microphone button shows placeholder message', (tester) async {
    await tester.pumpWidget(buildSearch());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('search-microphone-button')));
    await tester.pump();

    expect(find.text('Voice search is coming soon.'), findsOneWidget);
  });

  testWidgets('trimmed submit persists and selects while empty is ignored', (
    tester,
  ) async {
    final store = _RecordingStore(const []);
    final selections = <RecentSearch>[];
    await tester.pumpWidget(
      buildSearch(store: store, onSelected: selections.add),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('search-field')), '   ');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    expect(selections, isEmpty);

    await tester.enterText(
      find.byKey(const Key('search-field')),
      '  Union Station  ',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(selections, [
      const RecentSearch(title: 'Union Station', address: ''),
    ]);
    expect(store.saveCount, 1);
  });

  testWidgets('recent row tap selects the destination and updates MRU', (
    tester,
  ) async {
    const recent = RecentSearch(title: 'USC Village', address: 'Los Angeles');
    final store = _RecordingStore(const [recent]);
    RecentSearch? selected;
    await tester.pumpWidget(
      buildSearch(store: store, onSelected: (value) => selected = value),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('recent-search-USC Village')));
    await tester.pumpAndSettle();

    expect(selected, recent);
    expect(store.saveCount, 1);
  });

  testWidgets('interactive controls meet 48 point hit targets', (tester) async {
    await tester.pumpWidget(buildSearch(demoMode: true));
    await tester.pumpAndSettle();

    for (final key in const [
      Key('search-back-button'),
      Key('search-microphone-button'),
      ValueKey('recent-search-USC Village'),
    ]) {
      final size = tester.getSize(find.byKey(key));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
  });
}

class _RecordingStore implements RecentSearchStore {
  _RecordingStore(this.searches);

  List<RecentSearch> searches;
  var loadCount = 0;
  var saveCount = 0;

  @override
  Future<List<RecentSearch>> load() async {
    loadCount += 1;
    return List.of(searches);
  }

  @override
  Future<void> save(List<RecentSearch> values) async {
    saveCount += 1;
    searches = List.of(values);
  }
}
