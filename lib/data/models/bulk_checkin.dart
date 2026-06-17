class BulkCheckInScore {
  const BulkCheckInScore({
    required this.lat,
    required this.lon,
    required this.name,
    required this.score,
    required this.earnedScore,
    required this.reason,
  });

  final double lat;
  final double lon;
  final String name;
  final int score;
  final int earnedScore;
  final String reason;

  bool get isNew => earnedScore > 0;
}

class BulkCheckInResult {
  const BulkCheckInResult({required this.scores});

  final List<BulkCheckInScore> scores;

  int get totalEarned => scores.fold(0, (sum, s) => sum + s.earnedScore);
  int get newPlacesCount => scores.where((s) => s.isNew).length;
}
