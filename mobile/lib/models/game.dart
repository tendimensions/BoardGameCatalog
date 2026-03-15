class Game {
  final int id;
  final int? bggId;
  final String upc;
  final String title;
  final int? yearPublished;
  final int? minPlayers;
  final int? maxPlayers;
  final int? playingTime;
  final String thumbnailUrl;
  final String imageUrl;
  final String playersDisplay;
  final String playTimeDisplay;

  const Game({
    required this.id,
    this.bggId,
    required this.upc,
    required this.title,
    this.yearPublished,
    this.minPlayers,
    this.maxPlayers,
    this.playingTime,
    required this.thumbnailUrl,
    required this.imageUrl,
    required this.playersDisplay,
    required this.playTimeDisplay,
  });

  factory Game.fromJson(Map<String, dynamic> json) {
    return Game(
      id: json['id'] as int,
      bggId: json['bgg_id'] as int?,
      upc: json['upc'] as String? ?? '',
      title: json['title'] as String,
      yearPublished: json['year_published'] as int?,
      minPlayers: json['min_players'] as int?,
      maxPlayers: json['max_players'] as int?,
      playingTime: json['playing_time'] as int?,
      thumbnailUrl: json['thumbnail_url'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      playersDisplay: json['players_display'] as String? ?? '—',
      playTimeDisplay: json['play_time_display'] as String? ?? '—',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'bgg_id': bggId,
        'upc': upc,
        'title': title,
        'year_published': yearPublished,
        'min_players': minPlayers,
        'max_players': maxPlayers,
        'playing_time': playingTime,
        'thumbnail_url': thumbnailUrl,
        'image_url': imageUrl,
        'players_display': playersDisplay,
        'play_time_display': playTimeDisplay,
      };
}
