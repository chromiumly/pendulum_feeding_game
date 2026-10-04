import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pendulum_feeding_game/ranking/firestore_ranking_repository.dart';
import 'package:pendulum_feeding_game/ranking/ranking_models.dart';
import 'package:pendulum_feeding_game/ranking/ranking_repository.dart';

// The fake does not enforce firestore.rules; those are tested on the
// emulator in tool/firestore_rules.
/// Firestore where a game being written lands through an earlier send, so
/// that this write is refused as not new, as firestore.rules do.
class _EarlierSendLands extends FakeFirebaseFirestore {
  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    await super.runTransaction(transactionHandler);
    throw FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
    );
  }
}

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreRankingRepository repository;
  var plays = 0;

  PlayRecord play(String playerId, int score) => PlayRecord(
    playId: 'play-${plays++}-xxxxxxxx',
    playerId: playerId,
    score: score,
  );

  setUp(() async {
    db = FakeFirebaseFirestore();
    repository = FirestoreRankingRepository(() async => db);
    for (final id in ['aaaaaaaaaaaaaaaa', 'p1', 'p2', 'p3', 'p4', 'p5']) {
      await db.collection('players').doc(id).set({});
    }
  });

  Future<Map<String, dynamic>> player(String id) async =>
      (await db.collection('players').doc(id).get()).data()!;

  test('bestKey is the lowercase SHA-256 hex, as firestore.rules expects', () {
    const id = 'k7q2xm9pa4c8r3tw';
    expect(
      FirestoreRankingRepository.bestKey(id),
      sha256.convert(utf8.encode(id)).toString(),
    );
    expect(FirestoreRankingRepository.bestKey(id), matches(r'^[0-9a-f]{64}$'));
  });

  test('recordedGames is null for an unregistered ID', () async {
    expect(await repository.recordedGames('aaaaaaaaaaaaaaaa'), 0);
    expect(await repository.recordedGames('bbbbbbbbbbbbbbbb'), isNull);
  });

  test('a first game writes plays, scores and bests', () async {
    final record = play('p1', 1200);
    final result = await repository.record(record);

    final stored = (await db.collection('plays').doc(record.playId).get())
        .data()!;
    expect(stored['playerId'], 'p1');
    expect(stored['score'], 1200);
    expect(stored.keys, unorderedEquals(['playerId', 'score', 'createdAt']));
    expect((await db.collection('scores').doc(record.playId).get()).data(), {
      'score': 1200,
    });
    expect(
      (await db
              .collection('bests')
              .doc(FirestoreRankingRepository.bestKey('p1'))
              .get())
          .data(),
      {'best': 1200, 'playId': record.playId},
    );

    expect(result.score, 1200);
    expect((result.playRank, result.playCount), (1, 1));
    expect((result.best, result.isNewBest), (1200, true));
    expect((result.bestRank, result.playerCount), (1, 1));
  });

  test('ranks count higher scores, with ties sharing a rank', () async {
    await repository.record(play('p1', 2000));
    await repository.record(play('p2', 1500));
    await repository.record(play('p3', 1500));
    final result = await repository.record(play('p4', 1000));

    // All games: 2000, 1500, 1500, 1000.
    expect((result.playRank, result.playCount), (4, 4));
    // Bests: 2000, 1500, 1500, 1000.
    expect((result.bestRank, result.playerCount), (4, 4));

    final tie = await repository.record(play('p5', 1500));
    expect((tie.playRank, tie.playCount), (2, 5));
    expect((tie.bestRank, tie.playerCount), (2, 5));
  });

  test('a lower game keeps the best; every game counts in all games', () async {
    await repository.record(play('p1', 1800));
    await repository.record(play('p2', 1500));
    final result = await repository.record(play('p1', 900));

    expect((result.score, result.best, result.isNewBest), (900, 1800, false));
    expect((result.playRank, result.playCount), (3, 3));
    expect((result.bestRank, result.playerCount), (1, 2));
    expect(
      (await db
              .collection('bests')
              .doc(FirestoreRankingRepository.bestKey('p1'))
              .get())
          .data()!['best'],
      1800,
    );
  });

  test('a new best replaces the old one', () async {
    await repository.record(play('p1', 1000));
    final result = await repository.record(play('p1', 1300));
    expect((result.best, result.isNewBest), (1300, true));
    expect(result.playerCount, 1);
  });

  test('sending a recorded game again does not record it twice', () async {
    final record = play('p1', 1200);
    await repository.record(record);
    final again = await repository.record(record);

    expect((await db.collection('scores').get()).docs, hasLength(1));
    expect((await db.collection('plays').get()).docs, hasLength(1));
    // Still reported as the new best it was.
    expect((again.best, again.isNewBest), (1200, true));
    expect((again.playRank, again.playCount), (1, 1));
  });

  test('every new game counts in the player\'s games, once', () async {
    final first = play('p1', 1200);
    expect((await repository.record(first)).gamesPlayed, 1);
    expect(await player('p1'), {'gamesPlayed': 1, 'lastPlayId': first.playId});

    await repository.record(play('p2', 800));
    final second = play('p1', 900);
    expect((await repository.record(second)).gamesPlayed, 2);
    expect(await repository.recordedGames('p1'), 2);
    expect(await repository.recordedGames('p2'), 1);

    // A retry reports the count without adding to it.
    expect((await repository.record(first)).gamesPlayed, 2);
    expect(await player('p1'), {'gamesPlayed': 2, 'lastPlayId': second.playId});
  });

  test('an unregistered player\'s game is rejected', () async {
    await expectLater(
      repository.record(play('bbbbbbbbbbbbbbbb', 1200)),
      throwsA(isA<RecordRejectedException>()),
    );
    expect((await db.collection('plays').get()).docs, isEmpty);
  });

  test('a game refused because an earlier send of it landed meanwhile is '
      'recorded, not rejected', () async {
    final raced = _EarlierSendLands();
    await raced.collection('players').doc('p1').set({});
    final record = play('p1', 1500);

    final result = await FirestoreRankingRepository(() async => raced)
        .record(record);
    expect(result.score, 1500);
    expect(result.best, 1500);
    expect(result.isNewBest, isTrue);
    expect(result.gamesPlayed, 1);
  });

  test('a refused game that did not land is rejected', () async {
    final refusing = _Refusing();
    await refusing.collection('players').doc('p1').set({});
    expect(
      FirestoreRankingRepository(() async => refusing).record(play('p1', 1500)),
      throwsA(isA<RecordRejectedException>()),
    );
  });
}

/// Firestore that refuses every write, as firestore.rules do for a made-up
/// score.
class _Refusing extends FakeFirebaseFirestore {
  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    throw FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
    );
  }
}
