import 'game_list_entry.dart';

class GameList {
  final int id;
  final String name;
  final String description;
  final int entryCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<GameListEntry> entries;

  const GameList({
    required this.id,
    required this.name,
    required this.description,
    required this.entryCount,
    required this.createdAt,
    required this.updatedAt,
    this.entries = const [],
  });

  factory GameList.fromJson(Map<String, dynamic> json) => GameList(
        id: json['id'] as int,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        entryCount: json['entry_count'] as int? ?? 0,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        entries: (json['entries'] as List<dynamic>?)
                ?.map((e) => GameListEntry.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}
