import 'game.dart';

class CollectionItem {
  final int id;
  final Game game;
  final String source;
  final String? acquisitionDate;
  final String notes;
  final bool isLent;
  final String lentTo;
  final String? lentDate;

  const CollectionItem({
    required this.id,
    required this.game,
    required this.source,
    this.acquisitionDate,
    this.notes = '',
    required this.isLent,
    required this.lentTo,
    this.lentDate,
  });

  factory CollectionItem.fromJson(Map<String, dynamic> json) {
    return CollectionItem(
      id: json['id'] as int,
      game: Game.fromJson(json['game'] as Map<String, dynamic>),
      source: json['source'] as String? ?? '',
      acquisitionDate: json['acquisition_date'] as String?,
      notes: json['notes'] as String? ?? '',
      isLent: json['is_lent'] as bool? ?? false,
      lentTo: json['lent_to'] as String? ?? '',
      lentDate: json['lent_date'] as String?,
    );
  }

  CollectionItem copyWith({
    int? id,
    Game? game,
    String? source,
    String? acquisitionDate,
    String? notes,
    bool? isLent,
    String? lentTo,
    String? lentDate,
  }) {
    return CollectionItem(
      id: id ?? this.id,
      game: game ?? this.game,
      source: source ?? this.source,
      acquisitionDate: acquisitionDate ?? this.acquisitionDate,
      notes: notes ?? this.notes,
      isLent: isLent ?? this.isLent,
      lentTo: lentTo ?? this.lentTo,
      lentDate: lentDate ?? this.lentDate,
    );
  }
}
