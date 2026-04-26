import 'package:flutter_test/flutter_test.dart';

import 'package:boardgamecatalog/models/game.dart';

void main() {
  // ── fromJson ───────────────────────────────────────────────────────────────

  group('Game.fromJson', () {
    final fullJson = {
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

    test('parses all fields correctly', () {
      final game = Game.fromJson(fullJson);
      expect(game.id, 1);
      expect(game.bggId, 13);
      expect(game.upc, '012345678901');
      expect(game.title, 'Catan');
      expect(game.yearPublished, 1995);
      expect(game.minPlayers, 3);
      expect(game.maxPlayers, 4);
      expect(game.playingTime, 90);
      expect(game.thumbnailUrl, 'https://example.com/thumb.jpg');
      expect(game.imageUrl, 'https://example.com/image.jpg');
      expect(game.playersDisplay, '3–4');
      expect(game.playTimeDisplay, '90 min');
    });

    test('null bgg_id is accepted', () {
      final json = Map<String, dynamic>.from(fullJson);
      json['bgg_id'] = null;
      final game = Game.fromJson(json);
      expect(game.bggId, isNull);
    });

    test('missing upc defaults to empty string', () {
      final json = Map<String, dynamic>.from(fullJson);
      json.remove('upc');
      final game = Game.fromJson(json);
      expect(game.upc, '');
    });

    test('missing thumbnail_url defaults to empty string', () {
      final json = Map<String, dynamic>.from(fullJson);
      json['thumbnail_url'] = null;
      final game = Game.fromJson(json);
      expect(game.thumbnailUrl, '');
    });

    test('missing image_url defaults to empty string', () {
      final json = Map<String, dynamic>.from(fullJson);
      json['image_url'] = null;
      final game = Game.fromJson(json);
      expect(game.imageUrl, '');
    });

    test('missing players_display defaults to em-dash', () {
      final json = Map<String, dynamic>.from(fullJson);
      json['players_display'] = null;
      final game = Game.fromJson(json);
      expect(game.playersDisplay, '—');
    });

    test('missing play_time_display defaults to em-dash', () {
      final json = Map<String, dynamic>.from(fullJson);
      json['play_time_display'] = null;
      final game = Game.fromJson(json);
      expect(game.playTimeDisplay, '—');
    });

    test('null year_published is accepted', () {
      final json = Map<String, dynamic>.from(fullJson);
      json['year_published'] = null;
      final game = Game.fromJson(json);
      expect(game.yearPublished, isNull);
    });

    test('null player counts are accepted', () {
      final json = Map<String, dynamic>.from(fullJson);
      json['min_players'] = null;
      json['max_players'] = null;
      final game = Game.fromJson(json);
      expect(game.minPlayers, isNull);
      expect(game.maxPlayers, isNull);
    });
  });

  // ── toJson ─────────────────────────────────────────────────────────────────

  group('Game.toJson', () {
    const game = Game(
      id: 42,
      bggId: 174430,
      upc: '999000111222',
      title: 'Gloomhaven',
      yearPublished: 2017,
      minPlayers: 1,
      maxPlayers: 4,
      playingTime: 120,
      thumbnailUrl: 'https://example.com/t.jpg',
      imageUrl: 'https://example.com/i.jpg',
      playersDisplay: '1–4',
      playTimeDisplay: '120 min',
    );

    test('serializes all fields', () {
      final json = game.toJson();
      expect(json['id'], 42);
      expect(json['bgg_id'], 174430);
      expect(json['upc'], '999000111222');
      expect(json['title'], 'Gloomhaven');
      expect(json['year_published'], 2017);
      expect(json['min_players'], 1);
      expect(json['max_players'], 4);
      expect(json['playing_time'], 120);
      expect(json['thumbnail_url'], 'https://example.com/t.jpg');
      expect(json['image_url'], 'https://example.com/i.jpg');
      expect(json['players_display'], '1–4');
      expect(json['play_time_display'], '120 min');
    });

    test('null bgg_id serializes to null', () {
      const g = Game(
        id: 1,
        bggId: null,
        upc: '',
        title: 'Unnamed',
        thumbnailUrl: '',
        imageUrl: '',
        playersDisplay: '—',
        playTimeDisplay: '—',
      );
      expect(g.toJson()['bgg_id'], isNull);
    });

    test('round-trip fromJson → toJson preserves values', () {
      final json = game.toJson();
      final restored = Game.fromJson(json);
      expect(restored.id, game.id);
      expect(restored.title, game.title);
      expect(restored.bggId, game.bggId);
    });
  });
}
