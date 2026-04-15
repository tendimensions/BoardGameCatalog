import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game_list.dart';
import '../providers/auth_provider.dart';
import '../providers/list_provider.dart';
import 'scanner_screen.dart';

/// Shown when the user taps the Scan tab.
/// Presents two modes: Add to Collection (Mode A) or Add to List (Mode B).
class ScanModeScreen extends StatefulWidget {
  const ScanModeScreen({super.key});

  @override
  State<ScanModeScreen> createState() => _ScanModeScreenState();
}

class _ScanModeScreenState extends State<ScanModeScreen> {
  bool _loadingLists = false;

  Future<void> _startModeA() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );
  }

  Future<void> _startModeB() async {
    final apiKey = context.read<AuthProvider>().apiKey!;
    final listProvider = context.read<ListProvider>();

    setState(() => _loadingLists = true);
    await listProvider.load(apiKey);
    setState(() => _loadingLists = false);

    if (!mounted) return;

    if (listProvider.lists.isEmpty) {
      _showNoListsDialog();
      return;
    }

    _showListPicker(listProvider.lists, apiKey);
  }

  void _showNoListsDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: const Text(
          'No Lists',
          style: TextStyle(color: Color(0xFFdddddd)),
        ),
        content: const Text(
          'Create a list on the Lists tab before scanning in Add to List mode.',
          style: TextStyle(color: Color(0xFF888888)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Color(0xFF7eb8f7))),
          ),
        ],
      ),
    );
  }

  void _showListPicker(List<GameList> lists, String apiKey) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a1a2e),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                'Select a list to scan into',
                style: TextStyle(
                  color: Color(0xFFdddddd),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Divider(color: Color(0xFF2a2a2a)),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: lists.length,
                itemBuilder: (_, i) {
                  final list = lists[i];
                  return ListTile(
                    title: Text(
                      list.name,
                      style: const TextStyle(color: Color(0xFFdddddd)),
                    ),
                    subtitle: Text(
                      '${list.entryCount} game${list.entryCount == 1 ? '' : 's'}',
                      style: const TextStyle(
                          color: Color(0xFF666666), fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right,
                        color: Color(0xFF555555)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ScannerScreen(
                            listId: list.id,
                            listName: list.name,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
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
        title: const Text('Scan', style: TextStyle(fontSize: 18)),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              const Text(
                'What would you like to scan?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF888888),
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 32),

              // ── Mode A: Add to Collection ──────────────────────────────
              _ModeCard(
                icon: Icons.casino_outlined,
                title: 'Add to Collection',
                subtitle: 'Scan a game to add it to your collection.',
                onTap: _startModeA,
              ),

              const SizedBox(height: 16),

              // ── Mode B: Add to List ────────────────────────────────────
              _ModeCard(
                icon: Icons.list_alt_outlined,
                title: 'Add to List',
                subtitle:
                    'Scan games and add them directly to one of your lists.',
                onTap: _loadingLists ? null : _startModeB,
                loading: _loadingLists,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool loading;

  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1a1a2e),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2a2a2a)),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFF7eb8f7).withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: loading
                    ? const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF7eb8f7),
                          ),
                        ),
                      )
                    : Icon(icon, color: const Color(0xFF7eb8f7), size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFFdddddd),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF666666),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF444444)),
            ],
          ),
        ),
      ),
    );
  }
}
