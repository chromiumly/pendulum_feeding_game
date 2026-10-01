import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'ranking_models.dart';

/// What the ranking keeps on the device: the player ID, finished games not
/// yet recorded (so that none is lost when the network is down), and how
/// many games of a player were recorded when last heard (to know it
/// offline).
abstract interface class RankingStorage {
  Future<String?> loadPlayerId();
  Future<void> savePlayerId(String playerId);
  Future<List<PlayRecord>> loadPending();
  Future<void> savePending(List<PlayRecord> records);
  Future<int?> loadRecordedGames(String playerId);
  Future<void> saveRecordedGames(String playerId, int count);
}

/// [RankingStorage] in shared_preferences (localStorage on the web).
class SharedPreferencesRankingStorage implements RankingStorage {
  SharedPreferencesRankingStorage([SharedPreferencesAsync? preferences])
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  static const _playerIdKey = 'ranking.playerId';
  static const _pendingKey = 'ranking.pending';
  static String _recordedGamesKey(String playerId) =>
      'ranking.recordedGames.$playerId';

  @override
  Future<String?> loadPlayerId() => _preferences.getString(_playerIdKey);

  @override
  Future<void> savePlayerId(String playerId) =>
      _preferences.setString(_playerIdKey, playerId);

  @override
  Future<List<PlayRecord>> loadPending() async {
    final json = await _preferences.getString(_pendingKey);
    if (json == null) return [];
    try {
      return [
        for (final item in jsonDecode(json) as List)
          PlayRecord.fromJson((item as Map).cast<String, Object?>()),
      ];
    } on Object {
      return []; // Unreadable, e.g. from an older version: start afresh.
    }
  }

  @override
  Future<void> savePending(List<PlayRecord> records) => _preferences.setString(
    _pendingKey,
    jsonEncode([for (final record in records) record.toJson()]),
  );

  @override
  Future<int?> loadRecordedGames(String playerId) =>
      _preferences.getInt(_recordedGamesKey(playerId));

  @override
  Future<void> saveRecordedGames(String playerId, int count) =>
      _preferences.setInt(_recordedGamesKey(playerId), count);
}

/// [RankingStorage] in memory, for tests.
class MemoryRankingStorage implements RankingStorage {
  String? playerId;
  List<PlayRecord> pending = [];
  final recordedGames = <String, int>{};

  @override
  Future<String?> loadPlayerId() async => playerId;

  @override
  Future<void> savePlayerId(String playerId) async => this.playerId = playerId;

  @override
  Future<List<PlayRecord>> loadPending() async => List.of(pending);

  @override
  Future<void> savePending(List<PlayRecord> records) async =>
      pending = List.of(records);

  @override
  Future<int?> loadRecordedGames(String playerId) async =>
      recordedGames[playerId];

  @override
  Future<void> saveRecordedGames(String playerId, int count) async =>
      recordedGames[playerId] = count;
}
