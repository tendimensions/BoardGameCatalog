import 'game.dart';

class CollectionItem {
  final int id;
  final Game game;
  final String source;
  final bool isLent;
  final String lentTo;

  const CollectionItem({
    required this.id,
    required this.game,
    required this.source,
    required this.isLent,
    required this.lentTo,
  });

  factory CollectionItem.fromJson(Map<String, dynamic> json) {
    return CollectionItem(
      id: json['id'] as int,
      game: Game.fromJson(json['game'] as Map<String, dynamic>),
      source: json['source'] as String? ?? '',
      isLent: json['is_lent'] as bool? ?? false,
      lentTo: json['lent_to'] as String? ?? '',
    );
  }
}
