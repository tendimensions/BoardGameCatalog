import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/collection_item.dart';
import '../providers/auth_provider.dart';
import '../providers/collection_provider.dart';

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

  @override
  Widget build(BuildContext context) {
    final col = context.watch<CollectionProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0f0f0f),
      body: SafeArea(
        child: Column(
          children: [
            // ── Search bar ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Color(0xFFdddddd), fontSize: 14),
                onChanged: col.setQuery,
                decoration: InputDecoration(
                  hintText: 'Search games…',
                  hintStyle: const TextStyle(color: Color(0xFF555555)),
                  prefixIcon:
                      const Icon(Icons.search, color: Color(0xFF555555)),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear,
                              color: Color(0xFF555555)),
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
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),

            // ── Status / count bar ───────────────────────────────────────
            if (col.loadState == LoadState.error && col.error != null)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                color: const Color(0xFF2a1a00),
                child: Text(
                  col.error!,
                  style: const TextStyle(
                      color: Color(0xFFffb74d), fontSize: 12),
                ),
              )
            else if (col.loadState == LoadState.loaded)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${col.items.length} game${col.items.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                        color: Color(0xFF666666), fontSize: 12),
                  ),
                ),
              ),

            // ── Game list ────────────────────────────────────────────────
            Expanded(
              child: _buildBody(col),
            ),
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
            const Icon(Icons.casino_outlined,
                size: 64, color: Color(0xFF333333)),
            const SizedBox(height: 16),
            Text(
              col.loadState == LoadState.error
                  ? 'Could not load collection'
                  : 'No games found',
              style:
                  const TextStyle(color: Color(0xFF666666), fontSize: 16),
            ),
            if (col.loadState != LoadState.error) ...[
              const SizedBox(height: 8),
              const Text(
                'Sync your collection on the web app\nor scan a barcode to get started.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF444444), fontSize: 13),
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
        itemBuilder: (_, i) => _GameTile(item: col.items[i]),
      ),
    );
  }
}

class _GameTile extends StatelessWidget {
  final CollectionItem item;
  const _GameTile({required this.item});

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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
              fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          [
            if (game.yearPublished != null) '${game.yearPublished}',
            game.playersDisplay,
            game.playTimeDisplay,
          ].join(' · '),
          style:
              const TextStyle(color: Color(0xFF888888), fontSize: 12),
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
      child: const Icon(Icons.casino_outlined,
          size: 24, color: Color(0xFF444444)),
    );
  }
}
