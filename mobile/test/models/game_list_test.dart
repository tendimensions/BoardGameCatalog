import 'package:flutter_test/flutter_test.dart';

import 'package:boardgamecatalog/models/game_list.dart';
import 'package:boardgamecatalog/models/game_list_entry.dart';

Map<String, dynamic> _gameJson(int id) => {
      'id': id,
      'bgg_id': null,
      'upc': '',
      'title': 'Game $id',
      'year_published': null,
      'min_players': null,
      'max_players': null,
      'playing_time': null,
      'thumbnail_url': '',
      'image_url': '',
      'players_display': '—',
      'play_time_display': '—',
    };

Map<String, dynamic> _entryJson(int id) => {
      'id': id,
      'game': _gameJson(id),
      'note': '',
      'added_via': 'manual',
      'created_at': '2025-01-01T00:00:00Z',
      'updated_at': '2025-01-01T00:00:00Z',
    };

Map<String, dynamic> _listJson({
  int id = 1,
  String name = 'Test List',
  String description = '',
  int entryCount = 0,
  List<Map<String, dynamic>>? entries,
}) =>
    {
      'id': id,
      'name': name,
      'description': description,
      'entry_count': entryCount,
      'created_at': '2025-01-15T10:00:00Z',
      'updated_at': '2025-01-15T12:00:00Z',
      if (entries != null) 'entries': entries,
    };

void main() {
  group('GameList.fromJson', () {
    test('parses all scalar fields', () {
      final gl = GameList.fromJson(_listJson(
        id: 5,
        name: 'Party Games',
        description: 'Games for big groups',
        entryCount: 3,
      ));
      expect(gl.id, 5);
      expect(gl.name, 'Party Games');
      expect(gl.description, 'Games for big groups');
      expect(gl.entryCount, 3);
    });

    test('parses createdAt as DateTime', () {
      final gl = GameList.fromJson(_listJson());
      expect(gl.createdAt, isA<DateTime>());
      expect(gl.createdAt.year, 2025);
      expect(gl.createdAt.month, 1);
      expect(gl.createdAt.day, 15);
    });

    test('parses updatedAt as DateTime', () {
      final gl = GameList.fromJson(_listJson());
      expect(gl.updatedAt, isA<DateTime>());
    });

    test('missing description defaults to empty string', () {
      final json = _listJson();
      json.remove('description');
      final gl = GameList.fromJson(json);
      expect(gl.description, '');
    });

    test('missing entry_count defaults to 0', () {
      final json = _listJson();
      json.remove('entry_count');
      final gl = GameList.fromJson(json);
      expect(gl.entryCount, 0);
    });

    test('entries list is empty when key absent', () {
      final gl = GameList.fromJson(_listJson());
      expect(gl.entries, isEmpty);
    });

    test('entries list is empty when key is null', () {
      final json = _listJson();
      json['entries'] = null;
      final gl = GameList.fromJson(json);
      expect(gl.entries, isEmpty);
    });

    test('parses nested entries', () {
      final gl = GameList.fromJson(_listJson(
        entries: [_entryJson(10), _entryJson(11)],
      ));
      expect(gl.entries, hasLength(2));
      expect(gl.entries, everyElement(isA<GameListEntry>()));
    });

    test('entries game titles are correct', () {
      final gl = GameList.fromJson(_listJson(
        entries: [_entryJson(42)],
      ));
      expect(gl.entries.first.game.title, 'Game 42');
    });
  });

  group('GameList constructor defaults', () {
    test('entries defaults to empty list', () {
      final gl = GameList(
        id: 1,
        name: 'List',
        description: '',
        entryCount: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(gl.entries, isEmpty);
    });
  });
}
