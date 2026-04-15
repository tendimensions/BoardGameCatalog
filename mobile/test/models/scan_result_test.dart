import 'package:flutter_test/flutter_test.dart';

import 'package:boardgamecatalog/models/game.dart';
import 'package:boardgamecatalog/models/scan_result.dart';

const _game = Game(
  id: 1,
  bggId: 13,
  upc: '012345678901',
  title: 'Catan',
  thumbnailUrl: '',
  imageUrl: '',
  playersDisplay: '3–4',
  playTimeDisplay: '90 min',
);

void main() {
  group('ScanResult.statusLabel — collection mode (no listName)', () {
    test('success + addedToCollection → "Added to collection"', () {
      final r = ScanResult(
        upc: '123', status: ScanStatus.success, addedToCollection: true,
      );
      expect(r.statusLabel, 'Added to collection');
    });

    test('success + not added → "Already in collection"', () {
      final r = ScanResult(
        upc: '123', status: ScanStatus.success, addedToCollection: false,
      );
      expect(r.statusLabel, 'Already in collection');
    });

    test('notFound label', () {
      final r = ScanResult(upc: '123', status: ScanStatus.notFound);
      expect(r.statusLabel, 'Not found in GameUPC');
    });

    test('awaitingLink label', () {
      final r = ScanResult(upc: '123', status: ScanStatus.awaitingLink);
      expect(r.statusLabel, 'Tap to link to a game');
    });

    test('error label', () {
      final r = ScanResult(upc: '123', status: ScanStatus.error);
      expect(r.statusLabel, 'Error');
    });

    test('duplicate label', () {
      final r = ScanResult(upc: '123', status: ScanStatus.duplicate);
      expect(r.statusLabel, 'Already scanned');
    });
  });

  group('ScanResult.statusLabel — list mode (listName set)', () {
    test('addedToList true → "Added to [listName]"', () {
      final r = ScanResult(
        upc: '123',
        status: ScanStatus.success,
        addedToList: true,
        alreadyOnList: false,
        listName: 'Party Games',
      );
      expect(r.statusLabel, 'Added to Party Games');
    });

    test('alreadyOnList true → "Already on [listName]"', () {
      final r = ScanResult(
        upc: '123',
        status: ScanStatus.success,
        addedToList: false,
        alreadyOnList: true,
        listName: 'Weekend Picks',
      );
      expect(r.statusLabel, 'Already on Weekend Picks');
    });

    test('listName null falls back to collection label', () {
      final r = ScanResult(
        upc: '123',
        status: ScanStatus.success,
        addedToCollection: true,
        addedToList: true,
        listName: null,
      );
      // Without listName, the list-aware branch should not trigger
      expect(r.statusLabel, 'Added to collection');
    });
  });

  group('ScanResult defaults', () {
    test('addedToCollection defaults to false', () {
      final r = ScanResult(upc: '123', status: ScanStatus.success);
      expect(r.addedToCollection, isFalse);
    });

    test('scannedAt is set automatically when not provided', () {
      final before = DateTime.now().subtract(const Duration(seconds: 1));
      final r = ScanResult(upc: '123', status: ScanStatus.success);
      expect(r.scannedAt.isAfter(before), isTrue);
    });

    test('scannedAt can be provided explicitly', () {
      final time = DateTime(2025, 6, 1, 12, 0);
      final r = ScanResult(upc: '123', status: ScanStatus.success, scannedAt: time);
      expect(r.scannedAt, time);
    });

    test('errorMessage is null by default', () {
      final r = ScanResult(upc: '123', status: ScanStatus.error);
      expect(r.errorMessage, isNull);
    });

    test('game is null by default', () {
      final r = ScanResult(upc: '123', status: ScanStatus.success);
      expect(r.game, isNull);
    });

    test('game can be provided', () {
      final r = ScanResult(upc: '123', status: ScanStatus.success, game: _game);
      expect(r.game, _game);
    });
  });
}
