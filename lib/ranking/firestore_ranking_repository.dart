/// The ranking storage on Cloud Firestore.
library;

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';

import 'ranking_models.dart';
import 'ranking_repository.dart';

/// [RankingRepository] on Cloud Firestore. The data layout and what clients
/// may read and write are described and enforced in firestore.rules.
class FirestoreRankingRepository implements RankingRepository {
  /// [firestore] is called for every operation. It may fail (e.g. Firebase
  /// could not be initialised offline); the operation then fails and can be
  /// retried later.
  FirestoreRankingRepository(this._firestore);

  final Future<FirebaseFirestore> Function() _firestore;

  /// The bests/ document of a player: the SHA-256 hex of the ID, so that
  /// the public bests do not reveal the ID. firestore.rules checks it.
  static String bestKey(String playerId) =>
      sha256.convert(utf8.encode(playerId)).toString();

  /// Returns the `gamesPlayed` of a players/ document; 0 before any game.
  static int _gamesPlayed(DocumentSnapshot<Map<String, dynamic>> player) =>
      (player.data()?['gamesPlayed'] as num?)?.toInt() ?? 0;

  @override
  Future<int?> recordedGames(String playerId) async {
    final db = await _firestore();
    final player = await db.collection('players').doc(playerId).get();
    return player.exists ? _gamesPlayed(player) : null;
  }

  @override
  Future<RankingResult> record(PlayRecord record) async {
    final db = await _firestore();
    final scores = db.collection('scores');
    final bests = db.collection('bests');
    final bestRef = bests.doc(bestKey(record.playerId));
    final playerRef = db.collection('players').doc(record.playerId);

    final written = await _writeOnce(db, record, bestRef, playerRef);

    final counts = await Future.wait([
      _count(scores.where('score', isGreaterThan: record.score)),
      _count(scores),
      _count(bests.where('best', isGreaterThan: written.best)),
      _count(bests),
    ]);
    return RankingResult(
      score: record.score,
      playRank: counts[0] + 1,
      playCount: counts[1],
      best: written.best,
      isNewBest: written.isNewBest,
      bestRank: counts[2] + 1,
      playerCount: counts[3],
      gamesPlayed: written.gamesPlayed,
    );
  }

  /// Writes [record] if it is not recorded yet, and returns the player's
  /// best and game count after it.
  Future<({int best, bool isNewBest, int gamesPlayed})> _writeOnce(
    FirebaseFirestore db,
    PlayRecord record,
    DocumentReference<Map<String, dynamic>> bestRef,
    DocumentReference<Map<String, dynamic>> playerRef,
  ) async {
    final scoreRef = db.collection('scores').doc(record.playId);
    try {
      return (await scoreRef.get()).exists
          ? await _recordedBefore(bestRef, playerRef, record)
          : await _write(db, record, bestRef, playerRef);
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
      // An earlier send of this game, given up on when it took too long, may
      // have landed in the meantime; firestore.rules then refuse this one as
      // not new. It is recorded all the same.
      if (!(await scoreRef.get()).exists) throw RecordRejectedException(e);
      return _recordedBefore(bestRef, playerRef, record);
    }
  }

  /// Records a new game: plays and scores, the player's game count, and
  /// bests when it is a new best, all in one transaction as firestore.rules
  /// requires.
  Future<({int best, bool isNewBest, int gamesPlayed})> _write(
    FirebaseFirestore db,
    PlayRecord record,
    DocumentReference<Map<String, dynamic>> bestRef,
    DocumentReference<Map<String, dynamic>> playerRef,
  ) {
    return db.runTransaction((transaction) async {
      final player = await transaction.get(playerRef);
      if (!player.exists) throw const RecordRejectedException();
      final previous = await transaction.get(bestRef);
      final previousBest = (previous.data()?['best'] as num?)?.toInt();
      final gamesPlayed = _gamesPlayed(player) + 1;
      transaction
        ..set(db.collection('plays').doc(record.playId), {
          'playerId': record.playerId,
          'score': record.score,
          'createdAt': FieldValue.serverTimestamp(),
        })
        ..set(db.collection('scores').doc(record.playId), {
          'score': record.score,
        })
        ..update(playerRef, {
          'gamesPlayed': gamesPlayed,
          'lastPlayId': record.playId,
        });
      if (previousBest != null && record.score <= previousBest) {
        return (best: previousBest, isNewBest: false, gamesPlayed: gamesPlayed);
      }
      transaction.set(bestRef, {'best': record.score, 'playId': record.playId});
      return (best: record.score, isNewBest: true, gamesPlayed: gamesPlayed);
    });
  }

  /// The best and game count of a player whose game was recorded before (a
  /// retry after a lost reply). It was a new best if the best still points
  /// at it.
  Future<({int best, bool isNewBest, int gamesPlayed})> _recordedBefore(
    DocumentReference<Map<String, dynamic>> bestRef,
    DocumentReference<Map<String, dynamic>> playerRef,
    PlayRecord record,
  ) async {
    final (best, player) = await (bestRef.get(), playerRef.get()).wait;
    final data = best.data();
    return (
      best: (data?['best'] as num?)?.toInt() ?? record.score,
      isNewBest: data?['playId'] == record.playId,
      gamesPlayed: _gamesPlayed(player),
    );
  }

  @override
  Future<void> reconnect() async {
    final db = await _firestore();
    await db.disableNetwork();
    await db.enableNetwork();
  }

  /// Returns how many documents [query] matches, counted on the server.
  static Future<int> _count(Query<Map<String, dynamic>> query) async =>
      (await query.count().get()).count ?? 0;
}
