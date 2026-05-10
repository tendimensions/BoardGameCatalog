import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../models/collection_item.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class GameDetailScreen extends StatefulWidget {
  final CollectionItem item;
  final Future<void> Function() onRefreshCollection;

  const GameDetailScreen({
    super.key,
    required this.item,
    required this.onRefreshCollection,
  });

  @override
  State<GameDetailScreen> createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends State<GameDetailScreen> {
  late CollectionItem _item;
  bool _linkingBarcode = false;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
  }

  Future<void> _scanAndLinkBarcode() async {
    final scannedUpc = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => _BarcodeLinkScannerScreen(gameTitle: _item.game.title),
      ),
    );

    if (!mounted || scannedUpc == null || scannedUpc.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: const Text(
          'Link barcode?',
          style: TextStyle(color: Color(0xFFdddddd)),
        ),
        content: Text(
          'Link barcode $scannedUpc to "${_item.game.title}"?',
          style: const TextStyle(color: Color(0xFF888888)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF666666)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Link',
              style: TextStyle(color: Color(0xFF7eb8f7)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _linkingBarcode = true);
    final apiKey = context.read<AuthProvider>().apiKey!;

    try {
      final result = await ApiService(
        apiKey,
      ).assignBarcodeToGame(_item.game.id, scannedUpc);

      if (!mounted) return;

      await widget.onRefreshCollection();

      setState(() {
        _item = _item.copyWith(game: result.game);
        _linkingBarcode = false;
      });

      final message = result.submittedToGameUpc
          ? 'Barcode linked and submitted to GameUPC.com.'
          : 'Barcode linked to this game.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF2e7d32),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _linkingBarcode = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: const Color(0xFF5a1a1a),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _linkingBarcode = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not reach the server while linking this barcode. '
            'Check your connection. If the problem persists, the server '
            'may not have this feature deployed yet.',
          ),
          backgroundColor: Color(0xFF5a1a1a),
        ),
      );
    }
  }

  String get _sourceLabel {
    return switch (_item.source) {
      'bgg_sync' => 'BoardGameGeek sync',
      'barcode' => 'Barcode scan',
      'manual' => 'Manual entry',
      _ => _item.source.isEmpty ? 'Unknown' : _item.source,
    };
  }

  @override
  Widget build(BuildContext context) {
    final game = _item.game;

    return Scaffold(
      backgroundColor: const Color(0xFF0f0f0f),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0f0f0f),
        foregroundColor: const Color(0xFFdddddd),
        title: Text(game.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _HeroCard(item: _item),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Collection Details',
              child: Column(
                children: [
                  _DetailRow(label: 'Source', value: _sourceLabel),
                  _DetailRow(
                    label: 'Acquired',
                    value: _item.acquisitionDate ?? '—',
                  ),
                  _DetailRow(
                    label: 'Lending',
                    value: _item.isLent
                        ? 'Lent to ${_item.lentTo.isEmpty ? 'someone' : _item.lentTo}'
                        : 'In collection',
                  ),
                  if (_item.lentDate != null)
                    _DetailRow(label: 'Lent date', value: _item.lentDate!),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Barcode',
              child: _linkingBarcode
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF7eb8f7),
                        ),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DetailRow(
                          label: 'Status',
                          value: game.upc.isEmpty
                              ? 'No barcode linked'
                              : 'Barcode linked',
                        ),
                        if (game.upc.isNotEmpty)
                          _DetailRow(label: 'UPC', value: game.upc),
                        if (game.upc.isEmpty) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Scan a barcode to associate it with this specific record.',
                            style: TextStyle(
                              color: Color(0xFF888888),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _scanAndLinkBarcode,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7eb8f7),
                              foregroundColor: const Color(0xFF0f0f0f),
                            ),
                            icon: const Icon(Icons.qr_code_scanner),
                            label: const Text('Scan barcode'),
                          ),
                        ],
                      ],
                    ),
            ),
            if (_item.notes.isNotEmpty) ...[
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Notes',
                child: Text(
                  _item.notes,
                  style: const TextStyle(color: Color(0xFFcccccc), height: 1.4),
                ),
              ),
            ],
            if (game.description.isNotEmpty) ...[
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Description',
                child: Text(
                  game.description,
                  style: const TextStyle(color: Color(0xFFcccccc), height: 1.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final CollectionItem item;

  const _HeroCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final game = item.game;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a2e),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2a2a2a)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: game.imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: game.imageUrl,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          const _ImagePlaceholder(height: 200),
                    )
                  : game.thumbnailUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: game.thumbnailUrl,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          const _ImagePlaceholder(height: 200),
                    )
                  : const _ImagePlaceholder(height: 200),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            game.title,
            style: const TextStyle(
              color: Color(0xFFdddddd),
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FactChip(
                icon: Icons.calendar_today_outlined,
                label: game.yearPublished?.toString() ?? '—',
              ),
              _FactChip(icon: Icons.group_outlined, label: game.playersDisplay),
              _FactChip(
                icon: Icons.schedule_outlined,
                label: game.playTimeDisplay,
              ),
              _FactChip(
                icon: Icons.child_care_outlined,
                label: game.minAge != null ? '${game.minAge}+' : 'Age —',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a2e),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2a2a2a)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF7eb8f7),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF666666), fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Color(0xFFdddddd), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _FactChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FactChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0f0f0f),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF2a2a2a)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF7eb8f7)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Color(0xFFdddddd), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  final double height;

  const _ImagePlaceholder({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      color: const Color(0xFF2a2a2a),
      child: const Icon(
        Icons.casino_outlined,
        color: Color(0xFF444444),
        size: 56,
      ),
    );
  }
}

class _BarcodeLinkScannerScreen extends StatefulWidget {
  final String gameTitle;

  const _BarcodeLinkScannerScreen({required this.gameTitle});

  @override
  State<_BarcodeLinkScannerScreen> createState() =>
      _BarcodeLinkScannerScreenState();
}

class _BarcodeLinkScannerScreenState extends State<_BarcodeLinkScannerScreen> {
  final MobileScannerController _scanner = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _processing = false;

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_processing) return;
    final barcode = capture.barcodes.firstOrNull;
    final rawValue = barcode?.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    _processing = true;
    Navigator.pop(context, rawValue);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f0f),
      body: Stack(
        children: [
          MobileScanner(controller: _scanner, onDetect: _onDetect),
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF7eb8f7), width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Scan barcode',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            widget.gameTitle,
                            style: const TextStyle(
                              color: Color(0xFFcccccc),
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _scanner.toggleTorch,
                      icon: const Icon(Icons.flash_on, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
