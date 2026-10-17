/// The ranking as the presentation page shows it.
library;

/// One player's best score, from bests/.
class PlayerBest {
  const PlayerBest({required this.key, required this.best});

  /// The player key: the bests/ document ID (see `Roster.keyOf`).
  final String key;

  final int best;
}

/// The ranking at one moment: every player's best, and how many games were
/// played in all.
class Standings {
  const Standings({
    required this.bests,
    required this.playCount,
    this.isFromCache = false,
  });

  /// Every player with a recorded game, in any order.
  final List<PlayerBest> bests;

  /// All recorded games, of every player.
  final int playCount;

  /// Whether this was read from the device's cache, not the server: the
  /// connection is down, and newer games may be missing.
  final bool isFromCache;

  /// Players with at least one recorded game.
  int get playerCount => bests.length;

  /// Returns the rows of ranks 1 to [places]. Ranks count strictly higher
  /// bests plus one, as in the game, so players with the same best share a
  /// row, and the rank after them has none (1, 2, 2, 4: rank 3 is empty).
  List<PodiumRow> podium([int places = 3]) {
    final byScore = <int, List<String>>{};
    for (final best in bests) {
      (byScore[best.best] ??= []).add(best.key);
    }
    final scores = byScore.keys.toList()..sort((a, b) => b.compareTo(a));
    final rows = {
      for (var rank = 1; rank <= places; rank++) rank: PodiumRow(rank: rank),
    };
    var higher = 0;
    for (final score in scores) {
      final rank = higher + 1;
      if (rank > places) break;
      rows[rank] = PodiumRow(
        rank: rank,
        score: score,
        keys: List.unmodifiable(byScore[score]!..sort()),
      );
      higher += byScore[score]!.length;
    }
    return [for (var rank = 1; rank <= places; rank++) rows[rank]!];
  }
}

/// One rank of the podium: its score, and every player who has it.
class PodiumRow {
  const PodiumRow({required this.rank, this.score, this.keys = const []});

  final int rank;

  /// The best of the players at this rank, or null if no one is.
  final int? score;

  /// The player keys at this rank, in a fixed order; empty if no one is.
  final List<String> keys;

  bool get isEmpty => keys.isEmpty;
}
