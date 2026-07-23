import 'package:flutter/material.dart';
import 'package:halo/features/search/data/recent_search_store.dart';
import 'package:halo/features/search/domain/recent_search.dart';

typedef SearchSelectionCallback = void Function(RecentSearch search);

const demoRecentSearches = [
  RecentSearch(title: 'USC Village', address: '3301 S Hoover St, Los Angeles'),
  RecentSearch(
    title: 'Cafe Dulce (USC Village)',
    address: '3096 McClintock Ave, Los Angeles',
  ),
  RecentSearch(
    title: 'Zumberge Hall of Science',
    address: '3651 Trousdale Pkwy, Los Angeles',
  ),
  RecentSearch(title: 'Chipotle', address: '3748 S Figueroa St, Los Angeles'),
];

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    required this.repository,
    required this.onSelected,
    required this.onBack,
    this.demoMode = false,
    super.key,
  });

  final RecentSearchRepository repository;
  final SearchSelectionCallback onSelected;
  final VoidCallback onBack;
  final bool demoMode;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late Future<List<RecentSearch>> _searches;
  var _isSelecting = false;

  @override
  void initState() {
    super.initState();
    _searches = widget.demoMode
        ? Future.value(demoRecentSearches)
        : widget.repository.load();
  }

  Future<void> _select(RecentSearch search) async {
    if (_isSelecting) return;
    _isSelecting = true;
    if (!widget.demoMode) {
      try {
        final updated = await widget.repository.add(search);
        if (!mounted) return;
        setState(() {
          _searches = Future.value(updated);
        });
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Could not save this recent search.')),
          );
      }
    }
    if (mounted) widget.onSelected(search);
    _isSelecting = false;
  }

  void _submit(String value) {
    final query = value.trim();
    if (query.isEmpty) return;
    _select(RecentSearch(title: query, address: ''));
  }

  void _showMicrophoneMessage() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Voice search is coming soon.')),
      );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 60,
                  height: 56,
                  child: Center(
                    child: IconButton(
                      key: const Key('search-back-button'),
                      onPressed: widget.onBack,
                      tooltip: 'Back',
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 22,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 56,
                    margin: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F3F2),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: TextField(
                      key: const Key('search-field'),
                      autofocus: true,
                      cursorColor: const Color(0xFF087F73),
                      textInputAction: TextInputAction.search,
                      onSubmitted: _submit,
                      decoration: InputDecoration(
                        hintText: 'Where to?',
                        hintStyle: const TextStyle(color: Color(0xFF60716D)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 17,
                        ),
                        suffixIcon: IconButton(
                          key: const Key('search-microphone-button'),
                          onPressed: _showMicrophoneMessage,
                          tooltip: 'Voice search',
                          icon: const Icon(Icons.mic_none),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 28, 20, 10),
              child: Text(
                'Recent',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<RecentSearch>>(
                future: _searches,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final searches = snapshot.data!;
                  if (searches.isEmpty) {
                    return const Align(
                      alignment: Alignment.topLeft,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
                        child: Text(
                          'No recent searches',
                          style: TextStyle(color: Color(0xFF697572)),
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: searches.length,
                    itemBuilder: (context, index) {
                      final search = searches[index];
                      return _RecentSearchRow(
                        search: search,
                        onTap: () => _select(search),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _RecentSearchRow extends StatelessWidget {
  const _RecentSearchRow({required this.search, required this.onTap});

  final RecentSearch search;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 72,
    child: Stack(
      children: [
        Positioned.fill(
          child: InkWell(
            key: ValueKey('recent-search-${search.title}'),
            onTap: onTap,
            child: Row(
              children: [
                const SizedBox(width: 20),
                const SizedBox.square(
                  dimension: 48,
                  child: Icon(Icons.history, color: Color(0xFF596562)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        search.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (search.address.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          search.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF697572),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 20),
              ],
            ),
          ),
        ),
        const Positioned(
          left: 80,
          right: 20,
          bottom: 0,
          child: Divider(height: 1, thickness: 0.5, color: Color(0xFFE7EAE9)),
        ),
      ],
    ),
  );
}
