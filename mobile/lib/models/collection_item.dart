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
  /// IDs of the user's GameLists that contain this game (populated by the API).
  final List<int> listIds;

  const CollectionItem({
    required this.id,
    required this.game,
    required this.source,
    this.acquisitionDate,
    this.notes = '',
    required this.isLent,
    required this.lentTo,
    this.lentDate,
    this.listIds = const [],
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
      listIds: (json['list_ids'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
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
    List<int>? listIds,
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
      listIds: listIds ?? this.listIds,
    );
  }
}
