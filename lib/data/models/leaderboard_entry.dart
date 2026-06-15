import 'place.dart';
import 'visit.dart';

enum LeaderboardLevel { district, state, national }

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.userId,
    required this.displayName,
    required this.totalPoints,
    required this.placesVisited,
    required this.rank,
    this.isCurrentUser = false,
  });

  final String userId;
  final String displayName;
  final int totalPoints;
  final int placesVisited;
  final int rank;
  final bool isCurrentUser;

  LeaderboardEntry copyWith({
    String? userId,
    String? displayName,
    int? totalPoints,
    int? placesVisited,
    int? rank,
    bool? isCurrentUser,
  }) =>
      LeaderboardEntry(
        userId: userId ?? this.userId,
        displayName: displayName ?? this.displayName,
        totalPoints: totalPoints ?? this.totalPoints,
        placesVisited: placesVisited ?? this.placesVisited,
        rank: rank ?? this.rank,
        isCurrentUser: isCurrentUser ?? this.isCurrentUser,
      );
}

class UserStats {
  const UserStats({
    required this.totalPoints,
    required this.placesVisited,
    required this.pointsByState,
  });

  final int totalPoints;
  final int placesVisited;
  final Map<String, int> pointsByState;
}

class CheckInResult {
  const CheckInResult({
    required this.success,
    this.place,
    this.pointsEarned = 0,
    this.message = '',
  });

  final bool success;
  final Place? place;
  final int pointsEarned;
  final String message;
}

class ImportResult {
  const ImportResult({
    required this.newVisits,
    required this.totalPointsEarned,
    required this.photosScanned,
    required this.coordsFound,
  });

  final List<Visit> newVisits;
  final int totalPointsEarned;
  final int photosScanned;
  final int coordsFound;
}

class PhotoCoord {
  const PhotoCoord({
    required this.latitude,
    required this.longitude,
    this.takenAt,
  });

  final double latitude;
  final double longitude;
  final DateTime? takenAt;
}
