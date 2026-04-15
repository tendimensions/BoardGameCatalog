import 'game.dart';

class GameListEntry {
  final int id;
  final Game game;
  final String note;
  final String addedVia;
  final DateTime createdAt;
  final DateTime updatedAt;

  const GameListEntry({
    required this.id,
    required this.game,
    required this.note,
    required this.addedVia,
    required this.createdAt,
    required this.updatedAt,
  });

  factory GameListEntry.fromJson(Map<String, dynamic> json) => GameListEntry(
        id: json['id'] as int,
        game: Game.fromJson(json['game'] as Map<String, dynamic>),
        note: json['note'] as String? ?? '',
        addedVia: json['added_via'] as String? ?? 'manual',
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  GameListEntry copyWith({String? note}) => GameListEntry(
        id: id,
        game: game,
        note: note ?? this.note,
        addedVia: addedVia,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
