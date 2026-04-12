import 'game.dart';

enum ScanStatus { success, notFound, awaitingLink, error, duplicate }

class ScanResult {
  final String upc;
  final ScanStatus status;
  final Game? game;
  final bool addedToCollection;
  final String? errorMessage;
  final DateTime scannedAt;

  ScanResult({
    required this.upc,
    required this.status,
    this.game,
    this.addedToCollection = false,
    this.errorMessage,
    DateTime? scannedAt,
  }) : scannedAt = scannedAt ?? DateTime.now();

  String get statusLabel {
    switch (status) {
      case ScanStatus.success:
        return addedToCollection ? 'Added' : 'Already in collection';
      case ScanStatus.notFound:
        return 'Not found in GameUPC';
      case ScanStatus.awaitingLink:
        return 'Tap to link to a game';
      case ScanStatus.error:
        return 'Error';
      case ScanStatus.duplicate:
        return 'Already scanned';
    }
  }
}
