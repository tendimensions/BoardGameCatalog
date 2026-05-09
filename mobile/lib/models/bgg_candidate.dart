class BggCandidate {
  final int bggId;
  final String title;
  final int? yearPublished;
  final String thumbnailUrl;
  final double confidence;

  const BggCandidate({
    required this.bggId,
    required this.title,
    this.yearPublished,
    required this.thumbnailUrl,
    required this.confidence,
  });

  factory BggCandidate.fromJson(Map<String, dynamic> json) {
    return BggCandidate(
      bggId: json['bgg_id'] as int,
      title: json['title'] as String,
      yearPublished: json['year_published'] as int?,
      thumbnailUrl: json['thumbnail_url'] as String? ?? '',
      confidence: (json['confidence'] as num).toDouble(),
    );
  }

  String get confidencePercent => '${(confidence * 100).round()}%';
}
