import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/collection_item.dart';
import '../services/api_service.dart';

/// Allows the user to link an unrecognised barcode to a game in their
/// collection that does not yet have a barcode (REQ-CM-043 through REQ-CM-048).
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

class _LinkBarcodeScreenState extends State<LinkBarcodeScreen> {
  final _searchController = TextEditingController();

  List<CollectionItem> _allUnlinked = [];
  List<CollectionItem> _filtered = [];
  bool _loading = true;
  String? _loadError;
  bool _linking = false;

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

  Future<void> _loadUnlinkedGames() async {
    try {
      final all = await ApiService(widget.apiKey).fetchCollection(limit: 200);
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
    final q = query.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _allUnlinked
          : _allUnlinked
              .where((c) => c.game.title.toLowerCase().contains(q))
              .toList();
    });
  }

  /// Shows confirmation dialog (REQ-CM-044) then calls the link endpoint.
  Future<void> _confirmAndLink(CollectionItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: const Text(
          'Confirm Barcode Link',
          style: TextStyle(color: Color(0xFFdddddd)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you absolutely sure this barcode belongs to this game?',
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
                    item.game.title,
                    style: const TextStyle(
                      color: Color(0xFFdddddd),
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  if (item.game.yearPublished != null)
                    Text(
                      '${item.game.yearPublished}',
                      style: const TextStyle(
                          color: Color(0xFF888888), fontSize: 12),
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
              'This will be submitted to GameUPC.com to help other users identify this game.',
              style: TextStyle(
                color: Color(0xFF7eb8f7),
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF888888))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7eb8f7),
              foregroundColor: const Color(0xFF0f0f0f),
            ),
            child: const Text('Yes, link it',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _linking = true);

    try {
      final result =
          await ApiService(widget.apiKey).linkBarcode(widget.upc, item.game.id);

      if (!mounted) return;

      final submittedMsg = result.submittedToGameUpc
          ? 'Barcode linked and submitted to GameUPC.com!'
          : 'Barcode linked. (GameUPC submission skipped — no BGG ID)';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(submittedMsg),
          backgroundColor: const Color(0xFF2e7d32),
        ),
      );

      Navigator.pop(context, true); // success
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _linking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Link failed: ${e.message}'),
          backgroundColor: const Color(0xFF5a1a1a),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _linking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link failed. Check your connection and try again.'),
          backgroundColor: Color(0xFF5a1a1a),
        ),
      );
    }
  }

  /// Discard the saved barcode and close (REQ-CM-048).
  Future<void> _discard() async {
    // Fire-and-forget — we don't block the UI on this
    ApiService(widget.apiKey).discardBarcode(widget.upc);
    if (mounted) Navigator.pop(context, false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) ApiService(widget.apiKey).discardBarcode(widget.upc);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0f0f0f),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1a1a2e),
          foregroundColor: const Color(0xFFdddddd),
          title: const Text('Link Barcode to Game'),
          actions: [
            TextButton(
              onPressed: _discard,
              child: const Text('Discard',
                  style: TextStyle(color: Color(0xFFe57373))),
            ),
          ],
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
                        const SizedBox(height: 8),
                        const Text(
                          'Select the game this barcode belongs to. '
                          'Your confirmed match will be submitted to GameUPC.com to help others.',
                          style: TextStyle(
                              color: Color(0xFFaaaaaa), fontSize: 13),
                        ),
                      ],
                    ),
                  ),

                  // ── Search ───────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Color(0xFFdddddd)),
                      decoration: InputDecoration(
                        hintText: 'Search your games…',
                        hintStyle:
                            const TextStyle(color: Color(0xFF555555)),
                        prefixIcon: const Icon(Icons.search,
                            color: Color(0xFF555555)),
                        filled: true,
                        fillColor: const Color(0xFF1e1e1e),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFF333333)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFF333333)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFF7eb8f7)),
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onChanged: _onSearchChanged,
                    ),
                  ),

                  // ── Game list ────────────────────────────────────────────
                  Expanded(child: _buildList()),
                ],
              ),
      ),
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF7eb8f7)),
      );
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
        child: Text('No matches',
            style: TextStyle(color: Color(0xFF888888))),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _filtered.length,
      itemBuilder: (_, i) {
        final item = _filtered[i];
        return InkWell(
          onTap: () => _confirmAndLink(item),
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
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: item.game.thumbnailUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: item.game.thumbnailUrl,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              const _PlaceholderThumb(),
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
                        style: const TextStyle(
                            color: Color(0xFF555555), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: Color(0xFF555555), size: 20),
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
      child: const Icon(Icons.casino_outlined,
          size: 22, color: Color(0xFF555555)),
    );
  }
}
