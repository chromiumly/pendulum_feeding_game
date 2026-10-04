/// The ranking as the game sees it: recording games and the play count.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'player_id.dart';
import 'ranking_models.dart';
import 'ranking_repository.dart';
import 'ranking_storage.dart';

/// Records finished games for the player whose ID came with the launch URL,
/// and reports their ranks.
///
/// Without a registered ID the player is a guest, and nothing is recorded.
/// Every game of a player is kept on the device until it has been recorded,
/// and sent again later if recording fails.
///
/// When recording fails other than by being refused, the connection may be
/// stuck rather than the network down: it is then made anew, and the games
/// kept on the device are sent again at once, in the background.
class RankingService {
  /// [repository] records and ranks games; [storage] keeps them on the
  /// device until then. [launchUri] is the URL the app was opened with,
  /// whose `id` names the player. [random] makes play IDs (secure by
  /// default).
  RankingService({
    required this._repository,
    required this._storage,
    required this._launchUri,
    this.timeout = const Duration(seconds: 10),
    math.Random? random,
  }) : _random = random ?? math.Random.secure();

  final RankingRepository _repository;
  final RankingStorage _storage;
  final Uri _launchUri;
  final math.Random _random;

  /// Longest wait for the storage in one operation.
  final Duration timeout;

  String? _playerId;
  late final Future<void> _started = _start();

  /// The player's games in the storage when last heard, and those kept on
  /// the device until they are recorded.
  int _recordedGames = 0;
  int _pendingGames = 0;

  /// Who to tell when a game that failed to record is recorded later, by
  /// its play ID.
  final _lateResults = <String, void Function(RankingStatus status)>{};

  /// The reconnection and resending after a failure, while it runs.
  Future<void>? _recovering;

  /// Storage operations run one at a time, so that a game is never sent
  /// twice at once.
  Future<void> _queue = Future.value();

  /// Whether games are recorded. False until [start] has found the ID.
  bool get hasPlayer => _playerId != null;

  /// The games this player has finished, recorded or still to be sent; 0
  /// for a guest. Known offline too, from what was recorded when last
  /// heard. A game counts as soon as [recordGame] is called for it.
  int get gamesPlayed => hasPlayer ? _recordedGames + _pendingGames : 0;

  /// Picks up the player ID from the launch URL, checks that it is
  /// registered, and sends games left over from before. Safe to call more
  /// than once.
  ///
  /// The ID is not remembered on the device: a URL without it plays as a
  /// guest, so that the URL always tells who is playing. Reloads and
  /// bookmarks keep it.
  Future<void> start() => _started;

  /// Does the work of [start], once.
  Future<void> _start() async {
    final id = playerIdFromUri(_launchUri);
    if (id == null) return;
    _playerId = id;

    try {
      _recordedGames = await _storage.loadRecordedGames(id) ?? 0;
      _countPending(await _storage.loadPending());
    } on Object {
      // Counted from 0; the storage tells the real count when reachable.
    }
    try {
      final recorded = await _repository.recordedGames(id).timeout(timeout);
      if (recorded == null) {
        _playerId = null; // Unregistered: play as a guest.
        return;
      }
      await _setRecordedGames(recorded);
    } on Object {
      // Offline: keep the ID; recording will tell whether it is registered.
    }
    await _serialized(_sendPending);
  }

  /// Records a finished game with [score] and returns what to show.
  ///
  /// If it fails, it is tried again in the background; should that succeed,
  /// [onLateResult] is called with the ranks to show instead.
  Future<RankingStatus> recordGame(
    int score, {
    void Function(RankingStatus status)? onLateResult,
  }) async {
    // Counted at once, so that the next game, which may start before this
    // one is saved, already draws with it.
    if (hasPlayer) _pendingGames++;
    await start();
    final playerId = _playerId;
    if (playerId == null) return const RankingGuest();

    final record = PlayRecord(
      playId: _newPlayId(),
      playerId: playerId,
      score: score,
    );
    return _serialized(() async {
      await _savePending([...await _storage.loadPending(), record]);
      // Older games first, so that ranks include them.
      await _sendPending(except: record.playId);
      try {
        final result = await _repository.record(record).timeout(timeout);
        await _removePending(record.playId);
        await _setRecordedGames(result.gamesPlayed);
        return RankingRecorded(result);
      } on RecordRejectedException {
        await _removePending(record.playId);
        return await _stillRegistered(playerId)
            ? const RankingFailed()
            : const RankingGuest();
      } on Object {
        if (onLateResult != null) _lateResults[record.playId] = onLateResult;
        _recoverLater();
        return const RankingFailed();
      }
    });
  }

  /// Makes the connection anew and sends the kept games again, in the
  /// background; once at a time.
  void _recoverLater() {
    _recovering ??= _recover().whenComplete(() => _recovering = null);
  }

  Future<void> _recover() async {
    try {
      await _repository.reconnect().timeout(timeout);
    } on Object {
      // Sent all the same: the connection may be fine after all.
    }
    await _serialized(_sendPending);
  }

  /// Completes when the reconnection and resending after a failure, if any,
  /// has finished.
  @visibleForTesting
  Future<void> get recovered => _recovering ?? Future.value();

  /// Sends the games kept on the device, oldest first, until one fails.
  Future<void> _sendPending({String? except}) async {
    for (final record in await _storage.loadPending()) {
      if (record.playId == except) continue;
      try {
        final result = await _repository.record(record).timeout(timeout);
        if (record.playerId == _playerId) {
          await _setRecordedGames(result.gamesPlayed);
        }
        _lateResults.remove(record.playId)?.call(RankingRecorded(result));
      } on RecordRejectedException {
        _lateResults.remove(record.playId);
        // Refused for good (e.g. an unregistered ID); sending it again
        // would not help.
      } on Object {
        return; // Still offline: keep the rest for later.
      }
      await _removePending(record.playId);
    }
  }

  /// Drops the kept game [playId], once recorded or refused for good.
  Future<void> _removePending(String playId) async {
    final pending = await _storage.loadPending();
    await _savePending([
      for (final record in pending)
        if (record.playId != playId) record,
    ]);
  }

  /// Keeps [pending] on the device and counts this player's among them.
  Future<void> _savePending(List<PlayRecord> pending) async {
    await _storage.savePending(pending);
    _countPending(pending);
  }

  /// Counts this player's games among [pending].
  void _countPending(List<PlayRecord> pending) {
    _pendingGames = pending.where((r) => r.playerId == _playerId).length;
  }

  /// Sets the player's recorded games to [count]. It comes from the storage,
  /// which is always right; it is remembered for offline launches.
  Future<void> _setRecordedGames(int count) async {
    final playerId = _playerId;
    if (playerId == null) return;
    _recordedGames = count;
    try {
      await _storage.saveRecordedGames(playerId, count);
    } on Object {
      // Only needed offline; the storage tells it again next time.
    }
  }

  /// After a rejected record: whether the player is still registered. If
  /// not, the player continues as a guest.
  Future<bool> _stillRegistered(String playerId) async {
    try {
      if (await _repository.recordedGames(playerId).timeout(timeout) != null) {
        return true;
      }
      _playerId = null;
      return false;
    } on Object {
      return true;
    }
  }

  /// Runs [operation] after every earlier one has finished, and returns its
  /// result.
  Future<T> _serialized<T>(Future<T> Function() operation) {
    final result = _queue.then((_) => operation());
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  static const _playIdChars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

  /// Returns a new random play ID of 20 letters and digits.
  String _newPlayId() => String.fromCharCodes([
    for (var i = 0; i < 20; i++)
      _playIdChars.codeUnitAt(_random.nextInt(_playIdChars.length)),
  ]);
}
