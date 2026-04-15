import 'package:flutter_test/flutter_test.dart';

import 'package:boardgamecatalog/models/game_list_entry.dart';
import 'package:boardgamecatalog/models/game.dart';

Map<String, dynamic> _gameJson() => {
      'id': 1,
      'bgg_id': 13,
      'upc': '012345678901',
      'title': 'Catan',
      'year_published': 1995,
      'min_players': 3,
      'max_players': 4,
      'playing_time': 90,
      'thumbnail_url': 'https://example.com/thumb.jpg',
      'image_url': 'https://example.com/image.jpg',
      'players_display': '3–4',
      'play_time_display': '90 min',
    };

Map<String, dynamic> _entryJson({
  int id = 1,
  String note = 'Great game',
  String addedVia = 'barcode',
}) =>
    {
      'id': id,
      'game': _gameJson(),
      'note': note,
      'added_via': addedVia,
      'created_at': '2025-03-01T08:00:00Z',
      'updated_at': '2025-03-01T09:00:00Z',
    };

void main() {
  group('GameListEntry.fromJson', () {
    test('parses id, note, and added_via', () {
      final entry = GameListEntry.fromJson(_entryJson(id: 7, note: 'Fun', addedVia: 'manual'));
      expect(entry.id, 7);
      expect(entry.note, 'Fun');
      expect(entry.addedVia, 'manual');
    });

    test('deserializes nested game', () {
      final entry = GameListEntry.fromJson(_entryJson());
      expect(entry.game, isA<Game>());
      expect(entry.game.title, 'Catan');
    });

    test('parses createdAt as DateTime', () {
      final entry = GameListEntry.fromJson(_entryJson());
      expect(entry.createdAt, isA<DateTime>());
      expect(entry.createdAt.year, 2025);
      expect(entry.createdAt.month, 3);
    });

    test('missing note defaults to empty string', () {
      final json = _entryJson();
      json['note'] = null;
      final entry = GameListEntry.fromJson(json);
      expect(entry.note, '');
    });

    test('missing added_via defaults to manual', () {
      final json = _entryJson();
      json['added_via'] = null;
      final entry = GameListEntry.fromJson(json);
      expect(entry.addedVia, 'manual');
    });
  });

  group('GameListEntry.copyWith', () {
    late GameListEntry original;

    setUp(() {
      original = GameListEntry.fromJson(_entryJson(note: 'original note'));
    });

    test('returns new instance with updated note', () {
      final updated = original.copyWith(note: 'new note');
      expect(updated.note, 'new note');
    });

    test('preserves other fields', () {
      final updated = original.copyWith(note: 'changed');
      expect(updated.id, original.id);
      expect(updated.game.title, original.game.title);
      expect(updated.addedVia, original.addedVia);
      expect(updated.createdAt, original.createdAt);
      expect(updated.updatedAt, original.updatedAt);
    });

    test('null note argument keeps original note', () {
      final updated = original.copyWith();
      expect(updated.note, original.note);
    });

    test('original is not mutated', () {
      original.copyWith(note: 'changed');
      expect(original.note, 'original note');
    });

    test('returns a different object instance', () {
      final updated = original.copyWith(note: 'different');
      expect(identical(original, updated), isFalse);
    });
  });
}
