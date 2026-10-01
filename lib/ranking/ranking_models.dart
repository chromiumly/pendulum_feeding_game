/// One finished game, as sent to the ranking storage.
class PlayRecord {
  const PlayRecord({
    required this.playId,
    required this.playerId,
    required this.score,
  });

  factory PlayRecord.fromJson(Map<String, Object?> json) => PlayRecord(
    playId: json['playId']! as String,
    playerId: json['playerId']! as String,
    score: json['score']! as int,
  );

  /// Random, generated on the device. Re-sending the same record is
  /// recognised by it, so a retry never records a game twice.
  final String playId;
  final String playerId;
  final int score;

  Map<String, Object?> toJson() => {
    'playId': playId,
    'playerId': playerId,
    'score': score,
  };
}

/// Ranks after a game has been recorded. Ranks count strictly higher
/// scores plus one, so ties share a rank (1, 2, 2, 4).
class RankingResult {
  const RankingResult({
    required this.score,
    required this.playRank,
    required this.playCount,
    required this.best,
    required this.isNewBest,
    required this.bestRank,
    required this.playerCount,
    required this.gamesPlayed,
  });

  /// This game's score, and its rank among all recorded games.
  final int score;
  final int playRank;
  final int playCount;

  /// The player's best score, and its rank among all players' bests.
  final int best;
  final bool isNewBest;
  final int bestRank;
  final int playerCount;

  /// The player's recorded games, this one included.
  final int gamesPlayed;
}

/// What the result popup can say about the ranking.
sealed class RankingStatus {
  const RankingStatus();
}

/// Playing without a registered ID: nothing is recorded.
class RankingGuest extends RankingStatus {
  const RankingGuest();
}

/// The game is being recorded.
class RankingPending extends RankingStatus {
  const RankingPending();
}

/// Recording failed; the game is kept on the device and sent later.
class RankingFailed extends RankingStatus {
  const RankingFailed();
}

class RankingRecorded extends RankingStatus {
  const RankingRecorded(this.result);

  final RankingResult result;
}
