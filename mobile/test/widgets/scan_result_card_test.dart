import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:boardgamecatalog/models/game.dart';
import 'package:boardgamecatalog/models/scan_result.dart';
import 'package:boardgamecatalog/widgets/scan_result_card.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Wraps the card in the minimal Material scaffolding required by widget tests.
Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(child: child),
    ),
  );
}

const _game = Game(
  id: 1,
  bggId: 13,
  upc: '012345678901',
  title: 'Catan',
  thumbnailUrl: '', // empty → placeholder thumb, no network call
  imageUrl: '',
  playersDisplay: '3–4',
  playTimeDisplay: '90 min',
);

const _gameWithThumb = Game(
  id: 2,
  bggId: 13,
  upc: '012345678901',
  title: 'Catan',
  thumbnailUrl: 'https://example.com/thumb.jpg',
  imageUrl: '',
  playersDisplay: '3–4',
  playTimeDisplay: '90 min',
);

ScanResult _success({bool added = true}) => ScanResult(
      upc: '012345678901',
      status: ScanStatus.success,
      addedToCollection: added,
      game: _game,
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ScanResultCard — title display', () {
    testWidgets('shows game title when game is present', (tester) async {
      await tester.pumpWidget(_wrap(ScanResultCard(result: _success())));
      expect(find.text('Catan'), findsOneWidget);
    });

    testWidgets('shows UPC when game is null', (tester) async {
      final result = ScanResult(
        upc: '012345678901',
        status: ScanStatus.error,
      );
      await tester.pumpWidget(_wrap(ScanResultCard(result: result)));
      expect(find.text('012345678901'), findsOneWidget);
    });
  });

  group('ScanResultCard — status label display', () {
    testWidgets('shows "Added to collection" for success + added', (tester) async {
      await tester.pumpWidget(_wrap(ScanResultCard(result: _success(added: true))));
      expect(find.text('Added to collection'), findsOneWidget);
    });

    testWidgets('shows "Already in collection" for success + not added', (tester) async {
      await tester.pumpWidget(_wrap(ScanResultCard(result: _success(added: false))));
      expect(find.text('Already in collection'), findsOneWidget);
    });

    testWidgets('shows "Not found in GameUPC" for notFound', (tester) async {
      final result = ScanResult(upc: '123', status: ScanStatus.notFound);
      await tester.pumpWidget(_wrap(ScanResultCard(result: result)));
      expect(find.text('Not found in GameUPC'), findsOneWidget);
    });

    testWidgets('shows "Tap to link to a game" for awaitingLink', (tester) async {
      final result = ScanResult(upc: '123', status: ScanStatus.awaitingLink);
      await tester.pumpWidget(_wrap(ScanResultCard(result: result)));
      expect(find.text('Tap to link to a game'), findsOneWidget);
    });

    testWidgets('shows "Error" for error status', (tester) async {
      final result = ScanResult(upc: '123', status: ScanStatus.error);
      await tester.pumpWidget(_wrap(ScanResultCard(result: result)));
      expect(find.text('Error'), findsOneWidget);
    });

    testWidgets('shows "Already scanned" for duplicate status', (tester) async {
      final result = ScanResult(upc: '123', status: ScanStatus.duplicate);
      await tester.pumpWidget(_wrap(ScanResultCard(result: result)));
      expect(find.text('Already scanned'), findsOneWidget);
    });

    testWidgets('shows "Added to Party Games" for list-mode success', (tester) async {
      final result = ScanResult(
        upc: '123',
        status: ScanStatus.success,
        addedToList: true,
        alreadyOnList: false,
        listName: 'Party Games',
        game: _game,
      );
      await tester.pumpWidget(_wrap(ScanResultCard(result: result)));
      expect(find.text('Added to Party Games'), findsOneWidget);
    });

    testWidgets('shows "Already on Weekend Picks" for list-mode already-on-list', (tester) async {
      final result = ScanResult(
        upc: '123',
        status: ScanStatus.success,
        addedToList: false,
        alreadyOnList: true,
        listName: 'Weekend Picks',
        game: _game,
      );
      await tester.pumpWidget(_wrap(ScanResultCard(result: result)));
      expect(find.text('Already on Weekend Picks'), findsOneWidget);
    });
  });

  group('ScanResultCard — errorMessage overrides statusLabel', () {
    testWidgets('shows errorMessage text instead of statusLabel', (tester) async {
      final result = ScanResult(
        upc: '123',
        status: ScanStatus.error,
        errorMessage: 'Network timeout',
      );
      await tester.pumpWidget(_wrap(ScanResultCard(result: result)));
      expect(find.text('Network timeout'), findsOneWidget);
      expect(find.text('Error'), findsNothing);
    });
  });

  group('ScanResultCard — status indicator icons', () {
    testWidgets('shows link icon for awaitingLink status', (tester) async {
      final result = ScanResult(upc: '123', status: ScanStatus.awaitingLink);
      await tester.pumpWidget(_wrap(ScanResultCard(result: result)));
      expect(find.byIcon(Icons.link), findsOneWidget);
    });

    testWidgets('no link icon shown for success status', (tester) async {
      await tester.pumpWidget(_wrap(ScanResultCard(result: _success())));
      expect(find.byIcon(Icons.link), findsNothing);
    });

    testWidgets('no link icon shown for error status', (tester) async {
      final result = ScanResult(upc: '123', status: ScanStatus.error);
      await tester.pumpWidget(_wrap(ScanResultCard(result: result)));
      expect(find.byIcon(Icons.link), findsNothing);
    });

    testWidgets('no link icon shown for notFound status', (tester) async {
      final result = ScanResult(upc: '123', status: ScanStatus.notFound);
      await tester.pumpWidget(_wrap(ScanResultCard(result: result)));
      expect(find.byIcon(Icons.link), findsNothing);
    });
  });

  group('ScanResultCard — thumbnail', () {
    testWidgets('shows placeholder thumb when thumbnailUrl is empty', (tester) async {
      await tester.pumpWidget(_wrap(ScanResultCard(result: _success())));
      // The placeholder renders a casino icon
      expect(find.byIcon(Icons.casino_outlined), findsOneWidget);
    });

    testWidgets('shows placeholder thumb when game is null', (tester) async {
      final result = ScanResult(upc: '123', status: ScanStatus.error);
      await tester.pumpWidget(_wrap(ScanResultCard(result: result)));
      expect(find.byIcon(Icons.casino_outlined), findsOneWidget);
    });

    testWidgets('no placeholder when thumbnailUrl is non-empty (CachedNetworkImage shown)', (tester) async {
      final result = ScanResult(
        upc: '123',
        status: ScanStatus.success,
        addedToCollection: true,
        game: _gameWithThumb,
      );
      await tester.pumpWidget(_wrap(ScanResultCard(result: result)));
      // CachedNetworkImage renders instead of placeholder; casino icon absent
      expect(find.byIcon(Icons.casino_outlined), findsNothing);
    });
  });

  group('ScanResultCard — status color', () {
    // We check by looking at the coloured Text widget's style rather than
    // digging into Container decoration (which is harder to introspect).
    testWidgets('success + added uses green colour', (tester) async {
      await tester.pumpWidget(_wrap(ScanResultCard(result: _success(added: true))));
      final text = tester.widget<Text>(find.text('Added to collection'));
      expect(text.style?.color, const Color(0xFF81c784));
    });

    testWidgets('success + not added uses blue colour', (tester) async {
      await tester.pumpWidget(_wrap(ScanResultCard(result: _success(added: false))));
      final text = tester.widget<Text>(find.text('Already in collection'));
      expect(text.style?.color, const Color(0xFF7eb8f7));
    });

    testWidgets('notFound uses orange colour', (tester) async {
      final result = ScanResult(upc: '123', status: ScanStatus.notFound);
      await tester.pumpWidget(_wrap(ScanResultCard(result: result)));
      final text = tester.widget<Text>(find.text('Not found in GameUPC'));
      expect(text.style?.color, const Color(0xFFffb74d));
    });

    testWidgets('awaitingLink uses purple colour', (tester) async {
      final result = ScanResult(upc: '123', status: ScanStatus.awaitingLink);
      await tester.pumpWidget(_wrap(ScanResultCard(result: result)));
      final text = tester.widget<Text>(find.text('Tap to link to a game'));
      expect(text.style?.color, const Color(0xFFce93d8));
    });

    testWidgets('error uses red colour', (tester) async {
      final result = ScanResult(upc: '123', status: ScanStatus.error);
      await tester.pumpWidget(_wrap(ScanResultCard(result: result)));
      final text = tester.widget<Text>(find.text('Error'));
      expect(text.style?.color, const Color(0xFFe57373));
    });

    testWidgets('duplicate uses red colour', (tester) async {
      final result = ScanResult(upc: '123', status: ScanStatus.duplicate);
      await tester.pumpWidget(_wrap(ScanResultCard(result: result)));
      final text = tester.widget<Text>(find.text('Already scanned'));
      expect(text.style?.color, const Color(0xFFe57373));
    });
  });
}
