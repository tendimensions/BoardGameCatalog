import 'bgg_candidate.dart';
import 'game.dart';

enum ScanStatus { success, notFound, awaitingLink, needsSelection, error, duplicate }

class ScanResult {
  final String upc;
  final ScanStatus status;
  final Game? game;
  final bool addedToCollection;
  final bool? addedToList;
  final bool? alreadyOnList;
  final String? listName;
  final String? errorMessage;
  final DateTime scannedAt;
  final List<BggCandidate>? suggestions;

  ScanResult({
    required this.upc,
    required this.status,
    this.game,
    this.addedToCollection = false,
    this.addedToList,
    this.alreadyOnList,
    this.listName,
    this.errorMessage,
    DateTime? scannedAt,
    this.suggestions,
  }) : scannedAt = scannedAt ?? DateTime.now();

  String get statusLabel {
    switch (status) {
      case ScanStatus.success:
        if (listName != null) {
          if (alreadyOnList == true) return 'Already on $listName';
          if (addedToList == true) return 'Added to $listName';
        }
        return addedToCollection ? 'Added to collection' : 'Already in collection';
      case ScanStatus.notFound:
        return 'Not found in GameUPC';
      case ScanStatus.awaitingLink:
        return 'Tap to link to a game';
      case ScanStatus.needsSelection:
        return 'Tap to identify game';
      case ScanStatus.error:
        return 'Error';
      case ScanStatus.duplicate:
        return 'Already scanned';
    }
  }
}
