import 'dart:async';
import 'dart:math' as math;

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
class RankingService {
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

  /// Storage operations run one at a time, so that a game is never sent
  /// twice at once.
  Future<void> _queue = Future.value();

  /// Whether games are recorded. False until [start] has found the ID.
  bool get hasPlayer => _playerId != null;

  /// The games this player has finished, recorded or still to be sent; 0
  /// for a guest. Known offline too, from what was recorded when last
  /// heard. A game counts as soon as [recordGame] is called for it.
  int get gamesPlayed => hasPlayer ? _recordedGames + _pendingGames : 0;

  /// Picks up the player ID from the launch URL (remembering it for later
  /// launches) or from an earlier launch, checks that it is registered, and
  /// sends games left over from before. Safe to call more than once.
  Future<void> start() => _started;

  Future<void> _start() async {
    final fromUrl = playerIdFromUri(_launchUri);
    String? id = fromUrl;
    try {
      // The device may refuse storage (e.g. private browsing); the ID from
      // the URL still works for this visit.
      if (fromUrl != null) await _storage.savePlayerId(fromUrl);
      id ??= await _storage.loadPlayerId();
    } on Object {
      // Keep the ID from the URL, if any.
    }
    if (id == null || !isValidPlayerId(id)) return;
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
  Future<RankingStatus> recordGame(int score) async {
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
        return const RankingFailed();
      }
    });
  }

  /// Sends the games kept on the device, oldest first, until one fails.
  Future<void> _sendPending({String? except}) async {
    for (final record in await _storage.loadPending()) {
      if (record.playId == except) continue;
      try {
        final result = await _repository.record(record).timeout(timeout);
        if (record.playerId == _playerId) {
          await _setRecordedGames(result.gamesPlayed);
        }
      } on RecordRejectedException {
        // Refused for good (e.g. an unregistered ID); sending it again
        // would not help.
      } on Object {
        return; // Still offline: keep the rest for later.
      }
      await _removePending(record.playId);
    }
  }

  Future<void> _removePending(String playId) async {
    final pending = await _storage.loadPending();
    await _savePending([
      for (final record in pending)
        if (record.playId != playId) record,
    ]);
  }

  Future<void> _savePending(List<PlayRecord> pending) async {
    await _storage.savePending(pending);
    _countPending(pending);
  }

  void _countPending(List<PlayRecord> pending) {
    _pendingGames = pending.where((r) => r.playerId == _playerId).length;
  }

  /// [count] comes from the storage, which is always right; it is
  /// remembered for offline launches.
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

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final result = _queue.then((_) => operation());
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  static const _playIdChars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

  String _newPlayId() => String.fromCharCodes([
    for (var i = 0; i < 20; i++)
      _playIdChars.codeUnitAt(_random.nextInt(_playIdChars.length)),
  ]);
}
