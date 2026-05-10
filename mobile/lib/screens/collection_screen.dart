import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/collection_item.dart';
import '../models/game_list.dart';
import '../providers/auth_provider.dart';
import '../providers/collection_provider.dart';
import '../services/api_service.dart';
import 'game_detail_screen.dart';

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final apiKey = context.read<AuthProvider>().apiKey;
    if (apiKey != null) {
      await context.read<CollectionProvider>().load(apiKey);
    }
  }

  Future<void> _openFilterSheet() async {
    final col = context.read<CollectionProvider>();
    final apiKey = context.read<AuthProvider>().apiKey!;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1a1a2e),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (_) => _FilterSheet(
        apiKey: apiKey,
        initialUnlinked: col.filterUnlinked,
        initialListId: col.filterListId,
        onApply: ({required bool unlinked, int? listId, required bool clearList}) {
          col.setFilter(
            unlinked: unlinked,
            listId: listId,
            clearListFilter: clearList,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final col = context.watch<CollectionProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0f0f0f),
      body: SafeArea(
        child: Column(
          children: [
            // ── Search bar + filter icon ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Color(0xFFdddddd), fontSize: 14),
                      onChanged: col.setQuery,
                      decoration: InputDecoration(
                        hintText: 'Search games…',
                        hintStyle: const TextStyle(color: Color(0xFF555555)),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Color(0xFF555555),
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.clear,
                                  color: Color(0xFF555555),
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  col.setQuery('');
                                },
                              )
                            : null,
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
                          borderSide:
                              const BorderSide(color: Color(0xFF7eb8f7)),
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // ── Filter icon with active-filter badge ───────────────
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.filter_list,
                          color: col.hasActiveFilter
                              ? const Color(0xFF7eb8f7)
                              : const Color(0xFF555555),
                        ),
                        tooltip: 'Filter',
                        onPressed: _openFilterSheet,
                      ),
                      if (col.hasActiveFilter)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF7eb8f7),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Active filter chips ──────────────────────────────────────
            if (col.hasActiveFilter)
              _FilterChipsRow(col: col),

            // ── Status / count bar ───────────────────────────────────────
            if (col.loadState == LoadState.error && col.error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                color: const Color(0xFF2a1a00),
                child: Text(
                  col.error!,
                  style: const TextStyle(
                    color: Color(0xFFffb74d),
                    fontSize: 12,
                  ),
                ),
              )
            else if (col.loadState == LoadState.loaded)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${col.items.length} game${col.items.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 12,
                    ),
                  ),
                ),
              ),

            // ── Game list ────────────────────────────────────────────────
            Expanded(child: _buildBody(col)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(CollectionProvider col) {
    if (col.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF7eb8f7)),
      );
    }

    if (col.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.casino_outlined,
              size: 64,
              color: Color(0xFF333333),
            ),
            const SizedBox(height: 16),
            Text(
              col.loadState == LoadState.error
                  ? 'Could not load collection'
                  : col.hasActiveFilter
                      ? 'No games match the active filters'
                      : 'No games found',
              style: const TextStyle(color: Color(0xFF666666), fontSize: 16),
            ),
            if (col.loadState != LoadState.error) ...[
              const SizedBox(height: 8),
              Text(
                col.hasActiveFilter
                    ? 'Try adjusting or clearing the filters.'
                    : 'Sync your collection on the web app\nor scan a barcode to get started.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF444444), fontSize: 13),
              ),
            ],
            const SizedBox(height: 24),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF7eb8f7),
                side: const BorderSide(color: Color(0xFF7eb8f7)),
              ),
              onPressed: _load,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF7eb8f7),
      backgroundColor: const Color(0xFF1a1a2e),
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: col.items.length,
        itemBuilder: (_, i) =>
            _GameTile(item: col.items[i], onRefreshCollection: _load),
      ),
    );
  }
}


// ── Active filter chips row ───────────────────────────────────────────────────

class _FilterChipsRow extends StatelessWidget {
  final CollectionProvider col;
  const _FilterChipsRow({required this.col});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          if (col.filterUnlinked)
            _ActiveChip(
              label: 'Barcode Not Linked',
              onRemove: () => col.setFilter(unlinked: false),
            ),
          if (col.filterListId != null)
            _ActiveChip(
              label: col.filterListId == kAnyListId
                  ? 'In Any List'
                  : 'In a List',
              onRemove: () => col.setFilter(clearListFilter: true),
            ),
        ],
      ),
    );
  }
}

class _ActiveChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _ActiveChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1a2a3a),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF7eb8f7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF7eb8f7), fontSize: 12),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 14, color: Color(0xFF7eb8f7)),
          ),
        ],
      ),
    );
  }
}


// ── Filter bottom sheet ───────────────────────────────────────────────────────

typedef _ApplyFilter = void Function({
  required bool unlinked,
  int? listId,
  required bool clearList,
});

class _FilterSheet extends StatefulWidget {
  final String apiKey;
  final bool initialUnlinked;
  final int? initialListId;
  final _ApplyFilter onApply;

  const _FilterSheet({
    required this.apiKey,
    required this.initialUnlinked,
    required this.initialListId,
    required this.onApply,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late bool _unlinked;
  late int? _listId;

  List<GameList>? _lists;
  bool _listsLoading = true;
  String? _listsError;

  @override
  void initState() {
    super.initState();
    _unlinked = widget.initialUnlinked;
    _listId = widget.initialListId;
    _loadLists();
  }

  Future<void> _loadLists() async {
    try {
      final lists = await ApiService(widget.apiKey).fetchLists();
      if (mounted) {
        setState(() {
          _lists = lists;
          _listsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _listsError = 'Could not load lists.';
          _listsLoading = false;
        });
      }
    }
  }

  void _apply() {
    widget.onApply(
      unlinked: _unlinked,
      listId: _listId,
      clearList: _listId == null,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Handle ────────────────────────────────────────────────────
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF444444),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'FILTER COLLECTION',
                style: const TextStyle(
                  color: Color(0xFF7eb8f7),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Barcode not linked ────────────────────────────────────────
            SwitchListTile(
              value: _unlinked,
              onChanged: (v) => setState(() => _unlinked = v),
              title: const Text(
                'Barcode Not Linked',
                style: TextStyle(color: Color(0xFFdddddd), fontSize: 14),
              ),
              subtitle: const Text(
                'Show only games without a scanned barcode',
                style: TextStyle(color: Color(0xFF666666), fontSize: 12),
              ),
              activeThumbColor: const Color(0xFF7eb8f7),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            ),

            const Divider(color: Color(0xFF2a2a2a), height: 1),
            const SizedBox(height: 8),

            // ── In a List ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'IN A LIST',
                style: const TextStyle(
                  color: Color(0xFF555555),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            const SizedBox(height: 4),

            RadioGroup<int?>(
              groupValue: _listId,
              onChanged: (v) => setState(() => _listId = v),
              child: Column(
                children: [
                  // None (no list filter)
                  RadioListTile<int?>(
                    value: null,
                    title: const Text(
                      'None',
                      style: TextStyle(color: Color(0xFFdddddd), fontSize: 14),
                    ),
                    fillColor: WidgetStateProperty.resolveWith(
                      (s) => s.contains(WidgetState.selected)
                          ? const Color(0xFF7eb8f7)
                          : const Color(0xFF555555),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 20),
                    dense: true,
                  ),

                  // Any list
                  RadioListTile<int?>(
                    value: kAnyListId,
                    title: const Text(
                      'Any List',
                      style: TextStyle(color: Color(0xFFdddddd), fontSize: 14),
                    ),
                    fillColor: WidgetStateProperty.resolveWith(
                      (s) => s.contains(WidgetState.selected)
                          ? const Color(0xFF7eb8f7)
                          : const Color(0xFF555555),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 20),
                    dense: true,
                  ),

                  // Specific lists
                  if (_listsLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF7eb8f7),
                          ),
                        ),
                      ),
                    )
                  else if (_listsError != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      child: Text(
                        _listsError!,
                        style: const TextStyle(
                            color: Color(0xFFe57373), fontSize: 12),
                      ),
                    )
                  else if (_lists != null && _lists!.isNotEmpty)
                    ..._lists!.map(
                      (list) => RadioListTile<int?>(
                        value: list.id,
                        title: Text(
                          list.name,
                          style: const TextStyle(
                            color: Color(0xFFdddddd),
                            fontSize: 14,
                          ),
                        ),
                        subtitle: list.entryCount > 0
                            ? Text(
                                '${list.entryCount} game${list.entryCount == 1 ? '' : 's'}',
                                style: const TextStyle(
                                    color: Color(0xFF555555), fontSize: 11),
                              )
                            : null,
                        fillColor: WidgetStateProperty.resolveWith(
                          (s) => s.contains(WidgetState.selected)
                              ? const Color(0xFF7eb8f7)
                              : const Color(0xFF555555),
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 20),
                        dense: true,
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Apply / Clear ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _unlinked = false;
                          _listId = null;
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF888888),
                        side: const BorderSide(color: Color(0xFF333333)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Clear'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _apply,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7eb8f7),
                        foregroundColor: const Color(0xFF0f0f0f),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Apply',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}


// ── Game tile ─────────────────────────────────────────────────────────────────

class _GameTile extends StatelessWidget {
  final CollectionItem item;
  final Future<void> Function() onRefreshCollection;

  const _GameTile({required this.item, required this.onRefreshCollection});

  @override
  Widget build(BuildContext context) {
    final game = item.game;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a2e),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2a2a2a)),
      ),
      child: ListTile(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GameDetailScreen(
                item: item,
                onRefreshCollection: onRefreshCollection,
              ),
            ),
          );
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: game.thumbnailUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: game.thumbnailUrl,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorWidget: (ctx, url, err) => const _Thumb(),
                )
              : const _Thumb(),
        ),
        title: Text(
          game.title,
          style: const TextStyle(
            color: Color(0xFFdddddd),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          [
            if (game.yearPublished != null) '${game.yearPublished}',
            game.playersDisplay,
            game.playTimeDisplay,
          ].join(' · '),
          style: const TextStyle(color: Color(0xFF888888), fontSize: 12),
        ),
        trailing: game.upc.isEmpty
            ? const Tooltip(
                message: 'No barcode linked',
                child: Icon(Icons.qr_code, color: Color(0xFF444444), size: 18),
              )
            : const Icon(Icons.qr_code, color: Color(0xFF7eb8f7), size: 18),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      color: const Color(0xFF2a2a2a),
      child: const Icon(
        Icons.casino_outlined,
        size: 24,
        color: Color(0xFF444444),
      ),
    );
  }
}
