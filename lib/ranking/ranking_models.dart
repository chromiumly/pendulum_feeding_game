/// The data the ranking records and reports.
library;

/// One finished game, as sent to the ranking storage.
class PlayRecord {
  const PlayRecord({
    required this.playId,
    required this.playerId,
    required this.score,
  });

  /// Reads a record written by [toJson].
  factory PlayRecord.fromJson(Map<String, Object?> json) => PlayRecord(
    playId: json['playId']! as String,
    playerId: json['playerId']! as String,
    score: json['score']! as int,
  );

  /// Random, generated on the device. Re-sending the same record is
  /// recognised by it, so a retry never records a game twice.
  final String playId;

  /// The registered player who played it (the secret ID from the QR code).
  final String playerId;

  final int score;

  /// Returns the record as JSON, for keeping it on the device.
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

  /// This game's score.
  final int score;

  /// This game's rank among all recorded games, from 1.
  final int playRank;

  /// All recorded games, of every player.
  final int playCount;

  /// The player's best score, this game included.
  final int best;

  /// Whether this game set [best].
  final bool isNewBest;

  /// [best]'s rank among all players' bests, from 1.
  final int bestRank;

  /// Players with at least one recorded game.
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

/// The game was recorded; [result] has its ranks.
class RankingRecorded extends RankingStatus {
  const RankingRecorded(this.result);

  final RankingResult result;
}
