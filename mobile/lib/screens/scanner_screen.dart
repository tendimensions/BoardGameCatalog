import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../models/scan_result.dart';
import '../providers/auth_provider.dart';
import '../providers/collection_provider.dart';
import '../services/api_service.dart';
import '../widgets/scan_result_card.dart';
import 'link_barcode_screen.dart';

class ScannerScreen extends StatefulWidget {
  /// When [listId] is provided the scanner operates in Mode B (Add to List).
  final int? listId;
  final String? listName;

  const ScannerScreen({super.key, this.listId, this.listName});

  bool get isModeB => listId != null;

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with WidgetsBindingObserver {
  final MobileScannerController _scanner = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  final AudioPlayer _audio = AudioPlayer();
  final List<ScanResult> _history = [];

  bool _processing = false;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanner.dispose();
    _audio.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _scanner.stop();
    } else if (state == AppLifecycleState.resumed) {
      _scanner.start();
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;
    final upc = barcode!.rawValue!;

    // Don't re-scan the same code immediately
    if (_history.isNotEmpty && _history.first.upc == upc) return;

    setState(() => _processing = true);

    final apiKey = context.read<AuthProvider>().apiKey!;
    ScanResult result;

    try {
      final response = await ApiService(apiKey)
          .scanBarcode(upc, listId: widget.listId);
      await _audio.play(AssetSource('sounds/beep_success.mp3'), volume: 0.8);

      if (widget.isModeB) {
        result = ScanResult(
          upc: upc,
          status: ScanStatus.success,
          game: response.game,
          addedToCollection: response.addedToCollection,
          addedToList: response.addedToList,
          alreadyOnList: response.alreadyOnList,
          listName: response.activeListName ?? widget.listName,
        );
      } else {
        result = ScanResult(
          upc: upc,
          status: ScanStatus.success,
          game: response.game,
          addedToCollection: response.addedToCollection,
        );
      }
    } on ApiException catch (e) {
      await _audio.play(AssetSource('sounds/beep_error.mp3'), volume: 0.8);
      final isAwaitingLink = e.statusCode == 404;
      result = ScanResult(
        upc: upc,
        status: isAwaitingLink ? ScanStatus.awaitingLink : ScanStatus.error,
        errorMessage: isAwaitingLink ? null : e.message,
      );
    } catch (_) {
      await _audio.play(AssetSource('sounds/beep_error.mp3'), volume: 0.8);
      result = ScanResult(
        upc: upc,
        status: ScanStatus.error,
        errorMessage: 'Could not reach server. Check your connection.',
      );
    }

    setState(() {
      _history.insert(0, result);
      if (_history.length > 20) _history.removeLast();
      _processing = false;
    });

    // Brief cooldown before accepting the next scan
    _cooldownTimer = Timer(const Duration(seconds: 2), () {});
  }

  /// Opens the link-barcode screen for an awaiting-link result.
  /// On return, replaces the history entry with the outcome.
  Future<void> _openLinkScreen(ScanResult result) async {
    final apiKey = context.read<AuthProvider>().apiKey!;
    final linked = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => LinkBarcodeScreen(
          upc: result.upc,
          apiKey: apiKey,
        ),
      ),
    );

    if (!mounted) return;

    // Refresh collection if a link was made
    if (linked == true) {
      context.read<CollectionProvider>().load(apiKey);
      setState(() {
        final idx = _history.indexOf(result);
        if (idx != -1) {
          _history[idx] = ScanResult(
            upc: result.upc,
            status: ScanStatus.success,
            addedToCollection: false,
            errorMessage: null,
          );
        }
      });
    } else {
      // User dismissed — mark as notFound in history
      setState(() {
        final idx = _history.indexOf(result);
        if (idx != -1) {
          _history[idx] = ScanResult(
            upc: result.upc,
            status: ScanStatus.notFound,
            errorMessage: 'Not found in GameUPC — barcode discarded',
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f0f),
      body: Column(
        children: [
          // ── Camera viewfinder ────────────────────────────────────────────
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                MobileScanner(
                  controller: _scanner,
                  onDetect: _onDetect,
                ),

                // Scanning overlay
                Center(
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _processing
                            ? Colors.orange
                            : const Color(0xFF7eb8f7),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                // Processing indicator
                if (_processing)
                  const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF7eb8f7),
                    ),
                  ),

                // Top bar
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Back arrow (since scanner is always pushed as a route)
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: const Icon(Icons.arrow_back,
                                color: Colors.white, shadows: [
                              Shadow(blurRadius: 4, color: Colors.black)
                            ]),
                          ),
                          IconButton(
                            icon: const Icon(Icons.flash_on,
                                color: Colors.white),
                            onPressed: _scanner.toggleTorch,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Mode B active-list banner
                if (widget.isModeB)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      color: const Color(0xCC1a1a2e),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.list_alt_outlined,
                              color: Color(0xFF7eb8f7), size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Adding to: ${widget.listName}',
                              style: const TextStyle(
                                color: Color(0xFF7eb8f7),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                shadows: [
                                  Shadow(blurRadius: 4, color: Colors.black)
                                ],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Scan history ─────────────────────────────────────────────────
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    _history.isEmpty ? 'No scans yet' : 'Recent scans',
                    style: const TextStyle(
                      color: Color(0xFF888888),
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _history.length,
                    itemBuilder: (_, i) => Dismissible(
                      key: ValueKey('${_history[i].upc}_$i'),
                      direction: DismissDirection.startToEnd,
                      background: Container(
                        color: const Color(0xFF5a1a1a),
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 20),
                        child: const Icon(Icons.delete_outline,
                            color: Color(0xFFe57373)),
                      ),
                      onDismissed: (_) =>
                          setState(() => _history.removeAt(i)),
                      child: GestureDetector(
                        onTap: _history[i].status == ScanStatus.awaitingLink
                            ? () => _openLinkScreen(_history[i])
                            : null,
                        child: ScanResultCard(result: _history[i]),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
