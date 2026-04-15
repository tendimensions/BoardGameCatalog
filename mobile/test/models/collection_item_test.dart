import 'package:flutter_test/flutter_test.dart';

import 'package:boardgamecatalog/models/collection_item.dart';
import 'package:boardgamecatalog/models/game.dart';

Map<String, dynamic> _gameJson({int id = 1, String title = 'Catan'}) => {
      'id': id,
      'bgg_id': 13,
      'upc': '012345678901',
      'title': title,
      'year_published': 1995,
      'min_players': 3,
      'max_players': 4,
      'playing_time': 90,
      'thumbnail_url': 'https://example.com/thumb.jpg',
      'image_url': 'https://example.com/image.jpg',
      'players_display': '3–4',
      'play_time_display': '90 min',
    };

Map<String, dynamic> _itemJson({
  int id = 10,
  String source = 'bgg_sync',
  bool isLent = false,
  String lentTo = '',
}) =>
    {
      'id': id,
      'game': _gameJson(),
      'source': source,
      'is_lent': isLent,
      'lent_to': lentTo,
    };

void main() {
  group('CollectionItem.fromJson', () {
    test('parses id and source', () {
      final item = CollectionItem.fromJson(_itemJson(id: 7, source: 'barcode'));
      expect(item.id, 7);
      expect(item.source, 'barcode');
    });

    test('deserializes nested game', () {
      final item = CollectionItem.fromJson(_itemJson());
      expect(item.game, isA<Game>());
      expect(item.game.title, 'Catan');
    });

    test('is_lent false by default', () {
      final item = CollectionItem.fromJson(_itemJson());
      expect(item.isLent, isFalse);
    });

    test('is_lent true is reflected', () {
      final item = CollectionItem.fromJson(_itemJson(isLent: true, lentTo: 'Alice'));
      expect(item.isLent, isTrue);
      expect(item.lentTo, 'Alice');
    });

    test('missing is_lent defaults to false', () {
      final json = _itemJson();
      json.remove('is_lent');
      final item = CollectionItem.fromJson(json);
      expect(item.isLent, isFalse);
    });

    test('missing lent_to defaults to empty string', () {
      final json = _itemJson();
      json.remove('lent_to');
      final item = CollectionItem.fromJson(json);
      expect(item.lentTo, '');
    });

    test('missing source defaults to empty string', () {
      final json = _itemJson();
      json.remove('source');
      final item = CollectionItem.fromJson(json);
      expect(item.source, '');
    });
  });
}
