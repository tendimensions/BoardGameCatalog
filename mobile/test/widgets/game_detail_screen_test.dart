import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:boardgamecatalog/models/collection_item.dart';
import 'package:boardgamecatalog/models/game.dart';
import 'package:boardgamecatalog/screens/game_detail_screen.dart';

void main() {
  CollectionItem makeItem({required String upc}) {
    return CollectionItem(
      id: 1,
      game: Game(
        id: 10,
        bggId: 13,
        upc: upc,
        title: 'Catan',
        yearPublished: 1995,
        minPlayers: 3,
        maxPlayers: 4,
        playingTime: 90,
        minAge: 10,
        description: 'Trade and build.',
        thumbnailUrl: '',
        imageUrl: '',
        playersDisplay: '3–4',
        playTimeDisplay: '90 min',
      ),
      source: 'manual',
      notes: 'Family favorite',
      isLent: false,
      lentTo: '',
    );
  }

  Future<void> pumpScreen(
    WidgetTester tester, {
    required CollectionItem item,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GameDetailScreen(item: item, onRefreshCollection: () async {}),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows scan barcode button when no barcode is linked', (
    tester,
  ) async {
    await pumpScreen(tester, item: makeItem(upc: ''));

    final scanButton = find.text('Scan barcode');
    await tester.scrollUntilVisible(
      scanButton,
      300,
      scrollable: find.byType(Scrollable),
    );
    expect(scanButton, findsOneWidget);
    expect(find.text('No barcode linked'), findsOneWidget);
  });

  testWidgets('hides scan barcode button when a barcode is already linked', (
    tester,
  ) async {
    await pumpScreen(tester, item: makeItem(upc: '012345678901'));

    final barcodeLinked = find.text('Barcode linked');
    await tester.scrollUntilVisible(
      barcodeLinked,
      300,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Scan barcode'), findsNothing);
    expect(find.text('Barcode linked'), findsOneWidget);
    expect(find.text('012345678901'), findsOneWidget);
  });
}
