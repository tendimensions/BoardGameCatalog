import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/scan_result.dart';

class ScanResultCard extends StatelessWidget {
  final ScanResult result;

  const ScanResultCard({super.key, required this.result});

  Color get _statusColor {
    switch (result.status) {
      case ScanStatus.success:
        return result.addedToCollection
            ? const Color(0xFF81c784)
            : const Color(0xFF7eb8f7);
      case ScanStatus.notFound:
        return const Color(0xFFffb74d);
      case ScanStatus.awaitingLink:
        return const Color(0xFFce93d8); // purple — action needed
      case ScanStatus.error:
      case ScanStatus.duplicate:
        return const Color(0xFFe57373);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a2e),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2a2a2a)),
      ),
      child: Row(
        children: [
          // Thumbnail
          if (result.game?.thumbnailUrl.isNotEmpty == true)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: CachedNetworkImage(
                imageUrl: result.game!.thumbnailUrl,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorWidget: (ctx, url, err) => const _PlaceholderThumb(),
              ),
            )
          else
            const _PlaceholderThumb(),
          const SizedBox(width: 12),

          // Title + status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.game?.title ?? result.upc,
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
                  result.errorMessage ?? result.statusLabel,
                  style: TextStyle(
                    color: _statusColor,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Status indicator — link icon for awaiting, dot for everything else
          if (result.status == ScanStatus.awaitingLink)
            Icon(Icons.link, color: _statusColor, size: 18)
          else
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _statusColor,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}

class _PlaceholderThumb extends StatelessWidget {
  const _PlaceholderThumb();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFF2a2a2a),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Icon(Icons.casino_outlined, size: 20, color: Color(0xFF555555)),
    );
  }
}
