import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/bgg_candidate.dart';
import '../services/api_service.dart';

/// Modal bottom sheet for Case 2 (ambiguous barcode).
///
/// Presents candidates in confidence-descending order.  Tapping a candidate
/// shows a confirmation dialog, then calls POST /api/v1/scan/confirm.
/// "None of these" shows a discard confirmation dialog.
///
/// Returns true if the user confirmed a selection, false/null if discarded.
class CandidateSelectionSheet extends StatefulWidget {
  final String upc;
  final List<BggCandidate> candidates;
  final String apiKey;

  const CandidateSelectionSheet({
    super.key,
    required this.upc,
    required this.candidates,
    required this.apiKey,
  });

  @override
  State<CandidateSelectionSheet> createState() => _CandidateSelectionSheetState();
}

class _CandidateSelectionSheetState extends State<CandidateSelectionSheet> {
  bool _confirming = false;

  Future<void> _onCandidateTap(BggCandidate candidate) async {
    // Step 1: game confirmation dialog
    final confirmed = await _showGameConfirmDialog(candidate);
    if (confirmed != true || !mounted) return;

    setState(() => _confirming = true);

    try {
      await ApiService(widget.apiKey).confirmScan(widget.upc, candidate.bggId);
      if (!mounted) return;
      Navigator.pop(context, true); // success
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _confirming = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not confirm: ${e.message}'),
          backgroundColor: const Color(0xFF5a1a1a),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _confirming = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not confirm. Check your connection.'),
          backgroundColor: Color(0xFF5a1a1a),
        ),
      );
    }
  }

  Future<bool?> _showGameConfirmDialog(BggCandidate candidate) {
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
                    candidate.title,
                    style: const TextStyle(
                      color: Color(0xFFdddddd),
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  if (candidate.yearPublished != null)
                    Text(
                      '${candidate.yearPublished}',
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
              'Your selection will be submitted to GameUPC.com to help other users.',
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

  Future<void> _onNoneOfThese() async {
    final discard = await showDialog<bool>(
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

    if (discard == true && mounted) {
      // Call discard endpoint (no-op for Case 2 — no UnlinkedBarcode was saved,
      // but consistent with the API surface).
      ApiService(widget.apiKey).discardBarcode(widget.upc);
      Navigator.pop(context, false);
    }
    // If "Keep looking" or dismissed, stay on the sheet.
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) {
        if (_confirming) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF7eb8f7)),
          );
        }

        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1a1a2e),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF444444),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Which game is this?',
                      style: TextStyle(
                        color: Color(0xFFdddddd),
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
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
                      'GameUPC found multiple possible games. Pick the correct one or dismiss.',
                      style: TextStyle(color: Color(0xFFaaaaaa), fontSize: 13),
                    ),
                  ],
                ),
              ),

              const Divider(color: Color(0xFF2a2a2a), height: 24),

              // Candidate list
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    ...widget.candidates.map((c) => _CandidateTile(
                          candidate: c,
                          onTap: () => _onCandidateTap(c),
                        )),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _onNoneOfThese,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF888888),
                        side: const BorderSide(color: Color(0xFF444444)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('None of these'),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CandidateTile extends StatelessWidget {
  final BggCandidate candidate;
  final VoidCallback onTap;

  const _CandidateTile({required this.candidate, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF0f0f0f),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF2a2a2a)),
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: candidate.thumbnailUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: candidate.thumbnailUrl,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const _PlaceholderThumb(),
                    )
                  : const _PlaceholderThumb(),
            ),
            const SizedBox(width: 12),

            // Title + year
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    candidate.title,
                    style: const TextStyle(
                      color: Color(0xFFdddddd),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (candidate.yearPublished != null)
                    Text(
                      '${candidate.yearPublished}',
                      style: const TextStyle(color: Color(0xFF555555), fontSize: 12),
                    ),
                ],
              ),
            ),

            // Confidence percentage
            Text(
              candidate.confidencePercent,
              style: const TextStyle(
                color: Color(0xFF7eb8f7),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderThumb extends StatelessWidget {
  const _PlaceholderThumb();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF2a2a2a),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Icon(Icons.casino_outlined, size: 24, color: Color(0xFF555555)),
    );
  }
}
