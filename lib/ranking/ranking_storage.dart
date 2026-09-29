import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'ranking_models.dart';

/// What the ranking keeps on the device: the player ID, and finished games
/// not yet recorded (so that none is lost when the network is down).
abstract interface class RankingStorage {
  Future<String?> loadPlayerId();
  Future<void> savePlayerId(String playerId);
  Future<List<PlayRecord>> loadPending();
  Future<void> savePending(List<PlayRecord> records);
}

/// [RankingStorage] in shared_preferences (localStorage on the web).
class SharedPreferencesRankingStorage implements RankingStorage {
  SharedPreferencesRankingStorage([SharedPreferencesAsync? preferences])
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  static const _playerIdKey = 'ranking.playerId';
  static const _pendingKey = 'ranking.pending';

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
}

/// [RankingStorage] in memory, for tests.
class MemoryRankingStorage implements RankingStorage {
  String? playerId;
  List<PlayRecord> pending = [];

  @override
  Future<String?> loadPlayerId() async => playerId;

  @override
  Future<void> savePlayerId(String playerId) async => this.playerId = playerId;

  @override
  Future<List<PlayRecord>> loadPending() async => List.of(pending);

  @override
  Future<void> savePending(List<PlayRecord> records) async =>
      pending = List.of(records);
}
