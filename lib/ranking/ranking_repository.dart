/// The interface to the ranking storage, so that it can be swapped in tests.
library;

import 'ranking_models.dart';

/// Where finished games are recorded and ranked.
abstract interface class RankingRepository {
  /// The number of games recorded for [playerId], or null if it is not one
  /// of the registered player IDs.
  Future<int?> recordedGames(String playerId);

  /// Records [record], unless it has been recorded already (a retry), and
  /// returns its ranks.
  ///
  /// Throws [RecordRejectedException] when the storage refuses the record
  /// for good (e.g. an unregistered ID); other errors may pass on a retry.
  Future<RankingResult> record(PlayRecord record);

  /// Drops the connection to the storage and makes a new one, for when it
  /// has stopped answering. A connection can get stuck that way (seen on an
  /// iPhone's Safari), and then every call fails until the page is
  /// reloaded.
  Future<void> reconnect();
}

/// The storage refused a record; sending it again would not help.
class RecordRejectedException implements Exception {
  const RecordRejectedException([this.cause]);

  /// The underlying error, if any.
  final Object? cause;

  @override
  String toString() => 'RecordRejectedException($cause)';
}
