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

  @override
  Future<bool> isRegistered(String playerId) async {
    final db = await _firestore();
    final player = await db.collection('players').doc(playerId).get();
    return player.exists;
  }

  @override
  Future<RankingResult> record(PlayRecord record) async {
    final db = await _firestore();
    final scores = db.collection('scores');
    final bests = db.collection('bests');
    final bestRef = bests.doc(bestKey(record.playerId));

    final ({int best, bool isNewBest}) best;
    try {
      final recorded = await scores.doc(record.playId).get();
      best = recorded.exists
          ? await _bestOf(bestRef, record)
          : await _write(db, record, bestRef);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') throw RecordRejectedException(e);
      rethrow;
    }

    final counts = await Future.wait([
      _count(scores.where('score', isGreaterThan: record.score)),
      _count(scores),
      _count(bests.where('best', isGreaterThan: best.best)),
      _count(bests),
    ]);
    return RankingResult(
      score: record.score,
      playRank: counts[0] + 1,
      playCount: counts[1],
      best: best.best,
      isNewBest: best.isNewBest,
      bestRank: counts[2] + 1,
      playerCount: counts[3],
    );
  }

  /// Records a new game: plays and scores, and bests when it is a new best,
  /// all in one transaction as firestore.rules requires.
  Future<({int best, bool isNewBest})> _write(
    FirebaseFirestore db,
    PlayRecord record,
    DocumentReference<Map<String, dynamic>> bestRef,
  ) {
    return db.runTransaction((transaction) async {
      final previous = await transaction.get(bestRef);
      final previousBest = (previous.data()?['best'] as num?)?.toInt();
      transaction
        ..set(db.collection('plays').doc(record.playId), {
          'playerId': record.playerId,
          'score': record.score,
          'createdAt': FieldValue.serverTimestamp(),
        })
        ..set(db.collection('scores').doc(record.playId), {
          'score': record.score,
        });
      if (previousBest != null && record.score <= previousBest) {
        return (best: previousBest, isNewBest: false);
      }
      transaction.set(bestRef, {'best': record.score, 'playId': record.playId});
      return (best: record.score, isNewBest: true);
    });
  }

  /// The best of a player whose game was recorded before (a retry after a
  /// lost reply). It was a new best if the best still points at it.
  Future<({int best, bool isNewBest})> _bestOf(
    DocumentReference<Map<String, dynamic>> bestRef,
    PlayRecord record,
  ) async {
    final data = (await bestRef.get()).data();
    final best = (data?['best'] as num?)?.toInt() ?? record.score;
    return (best: best, isNewBest: data?['playId'] == record.playId);
  }

  static Future<int> _count(Query<Map<String, dynamic>> query) async =>
      (await query.count().get()).count ?? 0;
}
