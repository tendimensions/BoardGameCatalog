import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/collection_item.dart';
import '../services/api_service.dart';

/// Allows the user to link an unrecognised barcode to a game (REQ-CM-043 through REQ-CM-048).
///
/// Two tabs:
///   "My Collection" — searchable list of collection games without a barcode.
///   "Search BGG"    — BGG name search for games not yet in the collection.
///
/// Returns true if a link was successfully made, false/null if dismissed.
/// Always calls discardBarcode() on the server before popping false/null.
class LinkBarcodeScreen extends StatefulWidget {
  final String upc;
  final String apiKey;

  const LinkBarcodeScreen({
    super.key,
    required this.upc,
    required this.apiKey,
  });

  @override
  State<LinkBarcodeScreen> createState() => _LinkBarcodeScreenState();
}

class _LinkBarcodeScreenState extends State<LinkBarcodeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // ── Shared search query (Issue #21) ─────────────────────────────────────
  String _sharedQuery = '';
  final _collectionKey = GlobalKey<_CollectionTabState>();
  final _bggKey = GlobalKey<_BggSearchTabState>();
  int _lastTabIndex = 0;

  bool _linking = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    // indexIsChanging is true during the swipe/animation; we only act once settled.
    if (_tabController.indexIsChanging) return;
    if (_tabController.index == _lastTabIndex) return;
    _lastTabIndex = _tabController.index;

    if (_tabController.index == 1) {
      // Switching to Search BGG — propagate current query and auto-search.
      _bggKey.currentState?.setQuery(_sharedQuery);
    } else {
      // Switching to My Collection — propagate current query and re-filter.
      _collectionKey.currentState?.setQuery(_sharedQuery);
    }
  }

  void _onQueryChanged(String query) {
    _sharedQuery = query;
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _discard() async {
    ApiService(widget.apiKey).discardBarcode(widget.upc);
    if (mounted) Navigator.pop(context, false);
  }

  Future<bool?> _showGameConfirmDialog({
    required String title,
    required int? yearPublished,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: const Text('Confirm game',
            style: TextStyle(color: Color(0xFFdddddd))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure this is the correct game?',
              style: TextStyle(color: Color(0xFFaaaaaa), fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0f0f0f),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF333333)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFFdddddd),
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  if (yearPublished != null)
                    Text(
                      '$yearPublished',
                      style: const TextStyle(color: Color(0xFF888888), fontSize: 12),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Barcode: ${widget.upc}',
              style: const TextStyle(
                color: Color(0xFF888888),
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'This will be submitted to GameUPC.com to help other users.',
              style: TextStyle(color: Color(0xFF7eb8f7), fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF888888))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7eb8f7),
              foregroundColor: const Color(0xFF0f0f0f),
            ),
            child: const Text("Yes, that's it",
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndLinkByGameId(CollectionItem item) async {
    final confirmed = await _showGameConfirmDialog(
      title: item.game.title,
      yearPublished: item.game.yearPublished,
    );
    if (confirmed != true || !mounted) return;

    setState(() => _linking = true);

    try {
      final result = await ApiService(widget.apiKey)
          .linkBarcode(widget.upc, gameId: item.game.id);

      if (!mounted) return;

      final msg =
          result.message ??
          (result.submittedToGameUpc
              ? 'Barcode linked and submitted to GameUPC.com!'
              : 'Barcode linked. (GameUPC submission skipped — no BGG ID)');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: const Color(0xFF2e7d32)),
      );
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _linking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Link failed: ${e.message}'),
            backgroundColor: const Color(0xFF5a1a1a)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _linking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Link failed. Check your connection and try again.'),
            backgroundColor: Color(0xFF5a1a1a)),
      );
    }
  }

  Future<void> _confirmAndLinkByBggId(BggSearchResult item) async {
    final confirmed = await _showGameConfirmDialog(
      title: item.title,
      yearPublished: item.yearPublished,
    );
    if (confirmed != true || !mounted) return;

    setState(() => _linking = true);

    try {
      final result = await ApiService(widget.apiKey)
          .linkBarcode(widget.upc, bggId: item.bggId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.message ??
                (result.submittedToGameUpc
                    ? 'Game added and submitted to GameUPC.com!'
                    : 'Game added. (GameUPC submission failed — will retry later)'),
          ),
          backgroundColor: const Color(0xFF2e7d32),
        ),
      );
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _linking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Link failed: ${e.message}'),
            backgroundColor: const Color(0xFF5a1a1a)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _linking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Link failed. Check your connection and try again.'),
            backgroundColor: Color(0xFF5a1a1a)),
      );
    }
  }

  Future<bool?> _confirmDiscard() {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: const Text('Discard this scan?',
            style: TextStyle(color: Color(0xFFdddddd))),
        content: const Text(
          'The barcode will not be saved and no game will be added to your collection.',
          style: TextStyle(color: Color(0xFF888888)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep looking',
                style: TextStyle(color: Color(0xFF7eb8f7))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard',
                style: TextStyle(color: Color(0xFFe57373))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await _confirmDiscard();
        if (discard == true && mounted) {
          _discard();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0f0f0f),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1a1a2e),
          foregroundColor: const Color(0xFFdddddd),
          title: const Text('Link Barcode to Game'),
          actions: [
            TextButton(
              onPressed: () async {
                final discard = await _confirmDiscard();
                if (discard == true && mounted) _discard();
              },
              child: const Text('Discard',
                  style: TextStyle(color: Color(0xFFe57373))),
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF7eb8f7),
            unselectedLabelColor: const Color(0xFF555555),
            indicatorColor: const Color(0xFF7eb8f7),
            tabs: const [
              Tab(text: 'My Collection'),
              Tab(text: 'Search BGG'),
            ],
          ),
        ),
        body: _linking
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF7eb8f7)),
              )
            : Column(
                children: [
                  // ── Header ───────────────────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    color: const Color(0xFF1a1a2e),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Barcode not found in GameUPC',
                          style: TextStyle(
                            color: Color(0xFFffb74d),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Barcode: ${widget.upc}',
                          style: const TextStyle(
                            color: Color(0xFF888888),
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Tabs ─────────────────────────────────────────────────
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _CollectionTab(
                          key: _collectionKey,
                          upc: widget.upc,
                          apiKey: widget.apiKey,
                          onLink: _confirmAndLinkByGameId,
                          onQueryChanged: _onQueryChanged,
                        ),
                        _BggSearchTab(
                          key: _bggKey,
                          upc: widget.upc,
                          apiKey: widget.apiKey,
                          onLink: _confirmAndLinkByBggId,
                          onQueryChanged: _onQueryChanged,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}


// ── My Collection tab ─────────────────────────────────────────────────────────

class _CollectionTab extends StatefulWidget {
  final String upc;
  final String apiKey;
  final Future<void> Function(CollectionItem) onLink;
  /// Called whenever the search text changes so the parent can sync to the BGG tab.
  final void Function(String) onQueryChanged;

  const _CollectionTab({
    super.key,
    required this.upc,
    required this.apiKey,
    required this.onLink,
    required this.onQueryChanged,
  });

  @override
  State<_CollectionTab> createState() => _CollectionTabState();
}

class _CollectionTabState extends State<_CollectionTab>
    with AutomaticKeepAliveClientMixin {
  final _searchController = TextEditingController();
  List<CollectionItem> _allUnlinked = [];
  List<CollectionItem> _filtered = [];
  bool _loading = true;
  String? _loadError;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadUnlinkedGames();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Called by the parent when the BGG tab's query changes and the user switches here.
  void setQuery(String q) {
    if (_searchController.text == q) return;
    _searchController.text = q;
    _onSearchChanged(q);
  }

  Future<void> _loadUnlinkedGames() async {
    try {
      // fetchAllCollection() pages automatically — no 200-game truncation (Issue #16).
      final all = await ApiService(widget.apiKey).fetchAllCollection();
      final unlinked = all.where((c) => c.game.upc.isEmpty).toList();
      setState(() {
        _allUnlinked = unlinked;
        _filtered = unlinked;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loadError = 'Could not load your collection. Check your connection.';
        _loading = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    widget.onQueryChanged(query);
    final q = query.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _allUnlinked
          : _allUnlinked
              .where((c) => c.game.title.toLowerCase().contains(q))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Color(0xFFdddddd)),
            decoration: InputDecoration(
              hintText: 'Search your games…',
              hintStyle: const TextStyle(color: Color(0xFF555555)),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF555555)),
              filled: true,
              fillColor: const Color(0xFF1e1e1e),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF333333)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF333333)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF7eb8f7)),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onChanged: _onSearchChanged,
          ),
        ),
        Expanded(child: _buildList()),
      ],
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF7eb8f7)));
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_loadError!,
              style: const TextStyle(color: Color(0xFFe57373)),
              textAlign: TextAlign.center),
        ),
      );
    }
    if (_allUnlinked.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'All games in your collection already have a barcode linked.',
            style: TextStyle(color: Color(0xFF888888)),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_filtered.isEmpty) {
      return const Center(
        child: Text('No matches', style: TextStyle(color: Color(0xFF888888))),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _filtered.length,
      itemBuilder: (_, i) {
        final item = _filtered[i];
        return InkWell(
          onTap: () => widget.onLink(item),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1a1a2e),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF2a2a2a)),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: item.game.thumbnailUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: item.game.thumbnailUrl,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => const _PlaceholderThumb(),
                        )
                      : const _PlaceholderThumb(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.game.title,
                        style: const TextStyle(
                          color: Color(0xFFdddddd),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.game.playersDisplay != '—'
                            ? '${item.game.yearPublished ?? '—'}  ·  ${item.game.playersDisplay} players'
                            : '${item.game.yearPublished ?? '—'}',
                        style: const TextStyle(color: Color(0xFF555555), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFF555555), size: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}


// ── Search BGG tab ────────────────────────────────────────────────────────────

class _BggSearchTab extends StatefulWidget {
  final String upc;
  final String apiKey;
  final Future<void> Function(BggSearchResult) onLink;
  /// Called whenever the search text changes so the parent can sync to the Collection tab.
  final void Function(String) onQueryChanged;

  const _BggSearchTab({
    super.key,
    required this.upc,
    required this.apiKey,
    required this.onLink,
    required this.onQueryChanged,
  });

  @override
  State<_BggSearchTab> createState() => _BggSearchTabState();
}

class _BggSearchTabState extends State<_BggSearchTab>
    with AutomaticKeepAliveClientMixin {
  final _searchController = TextEditingController();
  Timer? _debounce;
  List<BggSearchResult> _results = [];
  bool _searching = false;
  String? _searchError;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  /// Called by the parent when the Collection tab's query changes and the user
  /// switches here. Populates the field and triggers a debounced BGG search.
  void setQuery(String q) {
    if (_searchController.text == q) return;
    _searchController.text = q;
    _onQueryChanged(q);
  }

  void _onQueryChanged(String query) {
    widget.onQueryChanged(query);
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _searchError = null;
        _searching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () => _doSearch(query.trim()));
  }

  Future<void> _doSearch(String query) async {
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final results = await ApiService(widget.apiKey).searchBgg(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _searching = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _searchError = e.message;
        _searching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searchError = 'Search failed. Check your connection.';
        _searching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Color(0xFFdddddd)),
            decoration: InputDecoration(
              hintText: 'Search by game name…',
              hintStyle: const TextStyle(color: Color(0xFF555555)),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF555555)),
              filled: true,
              fillColor: const Color(0xFF1e1e1e),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF333333)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF333333)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF7eb8f7)),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onChanged: _onQueryChanged,
          ),
        ),
        Expanded(child: _buildResults()),
      ],
    );
  }

  Widget _buildResults() {
    if (_searching) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF7eb8f7)));
    }
    if (_searchError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, color: Color(0xFFe57373), size: 36),
              const SizedBox(height: 12),
              Text(
                _searchError!,
                style: const TextStyle(color: Color(0xFFe57373), fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Try again'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF7eb8f7),
                  side: const BorderSide(color: Color(0xFF7eb8f7)),
                ),
                onPressed: () => _doSearch(_searchController.text.trim()),
              ),
            ],
          ),
        ),
      );
    }
    if (_searchController.text.trim().isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Type a game name to search BoardGameGeek',
            style: TextStyle(color: Color(0xFF555555)),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_results.isEmpty) {
      return const Center(
        child: Text('No results found', style: TextStyle(color: Color(0xFF888888))),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _results.length,
      itemBuilder: (_, i) {
        final item = _results[i];
        return InkWell(
          onTap: () => widget.onLink(item),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1a1a2e),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF2a2a2a)),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: item.thumbnailUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: item.thumbnailUrl,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => const _PlaceholderThumb(),
                        )
                      : const _PlaceholderThumb(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          color: Color(0xFFdddddd),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.yearPublished != null ? '${item.yearPublished}' : '—',
                        style: const TextStyle(color: Color(0xFF555555), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (item.alreadyOwned)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1a3a1a),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF2e7d32)),
                    ),
                    child: const Text(
                      'Already owned',
                      style: TextStyle(color: Color(0xFF81c784), fontSize: 10),
                    ),
                  )
                else
                  const Icon(Icons.chevron_right, color: Color(0xFF555555), size: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}


class _PlaceholderThumb extends StatelessWidget {
  const _PlaceholderThumb();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF2a2a2a),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Icon(Icons.casino_outlined, size: 22, color: Color(0xFF555555)),
    );
  }
}
