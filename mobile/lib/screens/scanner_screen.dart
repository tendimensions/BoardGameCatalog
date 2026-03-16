import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../models/scan_result.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/scan_result_card.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

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
      final response = await ApiService(apiKey).scanBarcode(upc);
      await _audio.play(AssetSource('sounds/beep_success.mp3'), volume: 0.8);
      result = ScanResult(
        upc: upc,
        status: ScanStatus.success,
        game: response.game,
        addedToCollection: response.addedToCollection,
      );
    } on ApiException catch (e) {
      await _audio.play(AssetSource('sounds/beep_error.mp3'), volume: 0.8);
      result = ScanResult(
        upc: upc,
        status: e.statusCode == 404 ? ScanStatus.notFound : ScanStatus.error,
        errorMessage: e.message,
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

                // Top bar with torch toggle
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
                          const Text(
                            'Scan a barcode',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              shadows: [
                                Shadow(blurRadius: 4, color: Colors.black)
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.flash_on, color: Colors.white),
                            onPressed: _scanner.toggleTorch,
                          ),
                        ],
                      ),
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
                      child: ScanResultCard(result: _history[i]),
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
