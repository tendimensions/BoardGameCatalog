import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game_list.dart';
import '../models/game_list_entry.dart';
import '../providers/auth_provider.dart';
import '../providers/list_provider.dart';

class ListDetailScreen extends StatefulWidget {
  final int listId;
  final String listName;

  const ListDetailScreen({
    super.key,
    required this.listId,
    required this.listName,
  });

  @override
  State<ListDetailScreen> createState() => _ListDetailScreenState();
}

class _ListDetailScreenState extends State<ListDetailScreen> {
  GameList? _detail;
  bool _loading = true;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final apiKey = context.read<AuthProvider>().apiKey!;
    final detail =
        await context.read<ListProvider>().fetchDetail(apiKey, widget.listId);
    if (!mounted) return;
    setState(() {
      _detail = detail;
      _loading = false;
      if (detail == null) {
        _error = context.read<ListProvider>().error ?? 'Failed to load list';
      }
    });
  }

  List<GameListEntry> get _filteredEntries {
    if (_detail == null) return [];
    if (_query.isEmpty) return _detail!.entries;
    final q = _query.toLowerCase();
    return _detail!.entries
        .where((e) => e.game.title.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _editNote(GameListEntry entry) async {
    final ctrl = TextEditingController(text: entry.note);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: Text(
          entry.game.title,
          style: const TextStyle(color: Color(0xFFdddddd), fontSize: 15),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Color(0xFFdddddd)),
          decoration: InputDecoration(
            hintText: 'Add a note…',
            hintStyle: const TextStyle(color: Color(0xFF555555)),
            filled: true,
            fillColor: const Color(0xFF0f0f0f),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFF333333)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFF333333)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFF7eb8f7)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF666666))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save',
                style: TextStyle(color: Color(0xFF7eb8f7))),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (ok != true || !mounted) return;

    final apiKey = context.read<AuthProvider>().apiKey!;
    final saved = await context.read<ListProvider>().updateEntryNote(
          apiKey,
          widget.listId,
          entry.id,
          ctrl.text,
        );
    if (!saved && mounted) {
      _showError(context.read<ListProvider>().error ?? 'Error');
    } else if (mounted) {
      // Update local state without a full reload
      setState(() {
        _detail = GameList(
          id: _detail!.id,
          name: _detail!.name,
          description: _detail!.description,
          entryCount: _detail!.entryCount,
          createdAt: _detail!.createdAt,
          updatedAt: _detail!.updatedAt,
          entries: [
            for (final e in _detail!.entries)
              e.id == entry.id ? e.copyWith(note: ctrl.text) : e
          ],
        );
      });
    }
  }

  Future<void> _confirmRemove(GameListEntry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: const Text('Remove game?',
            style: TextStyle(color: Color(0xFFdddddd))),
        content: Text(
          'Remove "${entry.game.title}" from this list?',
          style: const TextStyle(color: Color(0xFF888888)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF666666))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove',
                style: TextStyle(color: Color(0xFFe57373))),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final apiKey = context.read<AuthProvider>().apiKey!;
    final removed = await context.read<ListProvider>().removeFromList(
          apiKey,
          widget.listId,
          entry.id,
        );
    if (!removed && mounted) {
      _showError(context.read<ListProvider>().error ?? 'Error');
    } else if (mounted) {
      setState(() {
        _detail = GameList(
          id: _detail!.id,
          name: _detail!.name,
          description: _detail!.description,
          entryCount: _detail!.entryCount - 1,
          createdAt: _detail!.createdAt,
          updatedAt: _detail!.updatedAt,
          entries:
              _detail!.entries.where((e) => e.id != entry.id).toList(),
        );
      });
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFF5a1a1a),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f0f),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0f0f0f),
        foregroundColor: const Color(0xFFdddddd),
        title: Text(
          _detail?.name ?? widget.listName,
          style: const TextStyle(fontSize: 17),
        ),
        elevation: 0,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child:
                    CircularProgressIndicator(color: Color(0xFF7eb8f7)),
              )
            : _error != null
                ? _buildError()
                : _buildContent(),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline,
              size: 48, color: Color(0xFF555555)),
          const SizedBox(height: 12),
          Text(_error!,
              style:
                  const TextStyle(color: Color(0xFF666666), fontSize: 14)),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: _load,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF7eb8f7),
              side: const BorderSide(color: Color(0xFF7eb8f7)),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final entries = _filteredEntries;

    return Column(
      children: [
        // ── Search ───────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            style: const TextStyle(color: Color(0xFFdddddd), fontSize: 14),
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search this list…',
              hintStyle: const TextStyle(color: Color(0xFF555555)),
              prefixIcon:
                  const Icon(Icons.search, color: Color(0xFF555555)),
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
          ),
        ),

        // ── Count ────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${entries.length} game${entries.length == 1 ? '' : 's'}',
              style:
                  const TextStyle(color: Color(0xFF555555), fontSize: 12),
            ),
          ),
        ),

        // ── Entry list ───────────────────────────────────────────────────
        Expanded(
          child: entries.isEmpty
              ? Center(
                  child: Text(
                    _query.isEmpty
                        ? 'No games in this list yet.'
                        : 'No games matching "$_query".',
                    style: const TextStyle(
                        color: Color(0xFF555555), fontSize: 14),
                  ),
                )
              : RefreshIndicator(
                  color: const Color(0xFF7eb8f7),
                  backgroundColor: const Color(0xFF1a1a2e),
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    itemCount: entries.length,
                    itemBuilder: (_, i) => _EntryTile(
                      entry: entries[i],
                      onEditNote: () => _editNote(entries[i]),
                      onRemove: () => _confirmRemove(entries[i]),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _EntryTile extends StatelessWidget {
  final GameListEntry entry;
  final VoidCallback onEditNote;
  final VoidCallback onRemove;

  const _EntryTile({
    required this.entry,
    required this.onEditNote,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final game = entry.game;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a2e),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2a2a2a)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: game.thumbnailUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: game.thumbnailUrl,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const _Thumb(),
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
              ].join(' · '),
              style:
                  const TextStyle(color: Color(0xFF666666), fontSize: 12),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: Color(0xFF5a2a2a), size: 20),
              onPressed: onRemove,
              tooltip: 'Remove from list',
            ),
          ),
          // Note row
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: GestureDetector(
              onTap: onEditNote,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.note.isEmpty ? 'Add a note…' : entry.note,
                      style: TextStyle(
                        color: entry.note.isEmpty
                            ? const Color(0xFF444444)
                            : const Color(0xFF888888),
                        fontSize: 12,
                        fontStyle: entry.note.isEmpty
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.edit_outlined,
                      size: 14, color: Color(0xFF444444)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      color: const Color(0xFF2a2a2a),
      child: const Icon(Icons.casino_outlined,
          size: 22, color: Color(0xFF444444)),
    );
  }
}
